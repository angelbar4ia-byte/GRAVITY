// Token de acceso OAuth2 de la cuenta de servicio de Firebase (JWT RS256 con WebCrypto).
// La cuenta de servicio llega por la variable de entorno FCM_SERVICE_ACCOUNT; no hay secretos en el repositorio.

export interface CuentaServicio {
  client_email: string;
  private_key: string;
  project_id: string;
  token_uri?: string;
}

function base64url(datos: Uint8Array | string): string {
  const bytes = typeof datos === "string" ? new TextEncoder().encode(datos) : datos;
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemABytes(pem: string): Uint8Array {
  const cuerpo = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const bin = atob(cuerpo);
  return Uint8Array.from(bin, (c) => c.charCodeAt(0));
}

export async function firmarJwt(cuenta: CuentaServicio, ahoraSegundos: number): Promise<string> {
  const cabecera = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const reclamos = base64url(JSON.stringify({
    iss: cuenta.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: cuenta.token_uri ?? "https://oauth2.googleapis.com/token",
    iat: ahoraSegundos,
    exp: ahoraSegundos + 3600,
  }));
  const llave = await crypto.subtle.importKey(
    "pkcs8",
    pemABytes(cuenta.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const firma = new Uint8Array(
    await crypto.subtle.sign("RSASSA-PKCS1-v1_5", llave, new TextEncoder().encode(`${cabecera}.${reclamos}`)),
  );
  return `${cabecera}.${reclamos}.${base64url(firma)}`;
}

export async function tokenAcceso(
  cuenta: CuentaServicio,
  fetchFn: typeof fetch,
  ahoraSegundos = Math.floor(Date.now() / 1000),
): Promise<string> {
  const jwt = await firmarJwt(cuenta, ahoraSegundos);
  const r = await fetchFn(cuenta.token_uri ?? "https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: jwt }),
  });
  if (!r.ok) throw new Error(`OAuth2 respondió ${r.status}`);
  const cuerpo = await r.json();
  return String(cuerpo.access_token);
}
