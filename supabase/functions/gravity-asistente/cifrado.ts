// Cifrado de los tokens de Google (AES-256-GCM) y firma del "estado" de OAuth. Usa WebCrypto (Deno y Node 22+).
// La clave (GOOGLE_TOKEN_KEY) es un secreto del servidor: 32 bytes en base64. Nunca en la base ni en la app.
// Formato guardado: v1:<iv en base64>:<texto cifrado en base64>. El dato adicional autenticado (AAD) es el id de la
// persona dueña: un token copiado a la fila de otra persona no descifra.

const enc = new TextEncoder();
const dec = new TextDecoder();

export class ErrorCifrado extends Error {
  constructor(m: string) {
    super(m);
    this.name = "ErrorCifrado";
  }
}

function aBytes(b64: string): Uint8Array {
  const limpio = b64.replace(/-/g, "+").replace(/_/g, "/");
  const bin = atob(limpio);
  return Uint8Array.from(bin, (c) => c.charCodeAt(0));
}
function aB64(bytes: Uint8Array): string {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s);
}

async function claveAes(claveB64: string | undefined): Promise<CryptoKey> {
  if (!claveB64) throw new ErrorCifrado("Falta GOOGLE_TOKEN_KEY en el servidor.");
  let crudo: Uint8Array;
  try {
    crudo = aBytes(claveB64);
  } catch {
    throw new ErrorCifrado("GOOGLE_TOKEN_KEY no es base64 válido.");
  }
  if (crudo.length !== 32) throw new ErrorCifrado("GOOGLE_TOKEN_KEY debe ser de 32 bytes (base64).");
  return crypto.subtle.importKey("raw", crudo as BufferSource, "AES-GCM", false, ["encrypt", "decrypt"]);
}

export async function cifrar(texto: string, claveB64: string | undefined, aad: string): Promise<string> {
  const k = await claveAes(claveB64);
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ct = new Uint8Array(
    await crypto.subtle.encrypt({ name: "AES-GCM", iv: iv as BufferSource, additionalData: enc.encode(aad) as BufferSource }, k, enc.encode(texto) as BufferSource),
  );
  return `v1:${aB64(iv)}:${aB64(ct)}`;
}

export async function descifrar(guardado: string, claveB64: string | undefined, aad: string): Promise<string> {
  const k = await claveAes(claveB64);
  const m = /^v1:([^:]+):([^:]+)$/.exec(guardado);
  if (!m) throw new ErrorCifrado("Formato de token desconocido.");
  try {
    const claro = await crypto.subtle.decrypt(
      { name: "AES-GCM", iv: aBytes(m[1]) as BufferSource, additionalData: enc.encode(aad) as BufferSource },
      k,
      aBytes(m[2]) as BufferSource,
    );
    return dec.decode(claro);
  } catch {
    throw new ErrorCifrado("No se pudo descifrar el token.");
  }
}

async function hmac(claveB64: string | undefined, texto: string): Promise<string> {
  if (!claveB64) throw new ErrorCifrado("Falta GOOGLE_TOKEN_KEY en el servidor.");
  const k = await crypto.subtle.importKey("raw", enc.encode("estado-oauth|" + claveB64) as BufferSource, { name: "HMAC", hash: "SHA-256" }, false, ["sign", "verify"]);
  const firma = new Uint8Array(await crypto.subtle.sign("HMAC", k, enc.encode(texto) as BufferSource));
  return aB64(firma).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/** Estado de OAuth firmado: `<persona>.<hogar>.<ámbito>.<expira>.<firma>`; evita que otra persona use un código ajeno. */
export async function firmarEstado(claveB64: string | undefined, e: { personaId: string; hogarId: string; ambito: string; expira: number }): Promise<string> {
  const cuerpo = `${e.personaId}.${e.hogarId}.${e.ambito}.${e.expira}`;
  return `${cuerpo}.${await hmac(claveB64, cuerpo)}`;
}

export async function verificarEstado(
  claveB64: string | undefined,
  estado: string,
  ahora = Date.now(),
): Promise<{ personaId: string; hogarId: string; ambito: string } | null> {
  const partes = estado.split(".");
  if (partes.length !== 5) return null;
  const [personaId, hogarId, ambito, expira, firma] = partes;
  const esperada = await hmac(claveB64, `${personaId}.${hogarId}.${ambito}.${expira}`);
  if (firma.length !== esperada.length) return null;
  let dif = 0;
  for (let i = 0; i < firma.length; i++) dif |= firma.charCodeAt(i) ^ esperada.charCodeAt(i);
  if (dif !== 0 || !(Number(expira) > ahora)) return null;
  return { personaId, hogarId, ambito };
}
