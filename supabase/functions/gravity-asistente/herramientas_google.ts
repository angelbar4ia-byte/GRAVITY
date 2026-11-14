// Herramientas de Gmail y Google Calendar del asistente (Fase 6, parte 2). Sin Deno ni red directa.
//
// Decisión D3 (documentada en README.md): el contenido de correos y eventos NUNCA vuelve al modelo.
// El modelo solo elige el NOMBRE de la herramienta (catálogo genérico); el servidor la ejecuta con el token de la
// persona y devuelve el resultado SOLO a la app (campo `local`), que lo muestra en su pantalla. Ni el cuerpo, ni los
// asuntos, ni el número de resultados vuelven al proveedor de IA. Así no hay filtro que pueda fallar: lo que contenga
// montos, salud o Cuidados no tiene camino hacia el modelo. Lo que la persona escribe en los formularios (destinatario,
// asunto, cuerpo, título del evento) va de la app al servidor y a Google; no pasa por el modelo.
//
// Escrituras: gmail.redactar solo crea un BORRADOR en la cuenta de la persona; gmail.enviar y calendario.crear exigen
// confirmado === true, que solo manda la app tras la pantalla de confirmación. Sin eso no se llama a Google.
import type { FilaBitacoraGoogle, Identidad, Resultado } from "./asistente.ts";
import { cifrar, descifrar, ErrorCifrado, firmarEstado, verificarEstado } from "./cifrado.ts";
import type { HerramientaCatalogo } from "./contexto.ts";
import {
  ClienteGoogle,
  CORREO_VALIDO,
  correoDeLaCuenta,
  ErrorGoogle,
  intercambiarCodigo,
  renovarAcceso,
  urlAutorizacion,
  type ConfigGoogle,
  type Fetch,
} from "./google.ts";

/** Roles que tienen cuenta de Google propia (la cuidadora y Casa, no). "Hermana" es un familiar (D5). */
export const ROLES_GOOGLE_PERSONAL = ["dueno", "coadministrador", "familiar"];

export interface CuentaGoogleGuardada {
  hogarId: string;
  personaId: string;
  ambito: "personal" | "casa";
  correo: string;
  alcances: string[];
  tokenCifrado: string;
  accesoCasa: boolean;
}

export interface AlmacenGoogle {
  /** Personal: la fila de `personaId`. Casa: la única de la casa. Nunca por un id que mande la app. */
  obtener(q: { hogarId: string; personaId: string; ambito: "personal" | "casa" }): Promise<CuentaGoogleGuardada | null>;
  guardar(c: CuentaGoogleGuardada): Promise<void>;
}

export interface DepsGoogle {
  /** null = faltan GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET / GOOGLE_REDIRECT_URI. */
  cfg: ConfigGoogle | null;
  /** GOOGLE_TOKEN_KEY (32 bytes en base64). */
  claveToken: string | undefined;
  fetch: Fetch;
  almacen: AlmacenGoogle;
  bitacora: (fila: FilaBitacoraGoogle) => Promise<void>;
  ahora?: () => number;
}

interface Definicion {
  roles: string[];
  escribe: boolean;
  /** Interna: la app la llama tras confirmar; el modelo no la ve. */
  interna?: boolean;
  descripcion: string;
}

export const DEFINICIONES: Record<string, Definicion> = {
  "gmail.leer": {
    roles: ROLES_GOOGLE_PERSONAL,
    escribe: false,
    descripcion: "Muestra en tu pantalla los correos recientes de tu bandeja de entrada. GRAVITY no los ve.",
  },
  "gmail.redactar": {
    roles: ROLES_GOOGLE_PERSONAL,
    escribe: true,
    descripcion: "Abre un formulario para redactar un correo y lo deja como borrador; no se envía sin tu confirmación.",
  },
  "gmail.enviar": { roles: ROLES_GOOGLE_PERSONAL, escribe: true, interna: true, descripcion: "Envía un borrador ya confirmado." },
  "calendario.ver": {
    roles: [...ROLES_GOOGLE_PERSONAL, "casa"],
    escribe: false,
    descripcion: "Muestra en tu pantalla los próximos eventos de tu calendario de Google. GRAVITY no los ve.",
  },
  "calendario.crear": {
    roles: ROLES_GOOGLE_PERSONAL,
    escribe: true,
    descripcion: "Abre un formulario para crear un evento en tu calendario; no se crea sin tu confirmación.",
  },
};

/**
 * Lo que ve el modelo: solo nombre y descripción genérica de las no internas, para los roles personales.
 * Casa no conversa (D5), así que su calendario no se ofrece al modelo.
 */
export const CATALOGO_GOOGLE: HerramientaCatalogo[] = Object.entries(DEFINICIONES)
  .filter(([, d]) => !d.interna)
  .map(([nombre, d]) => ({ nombre, modulo: "google", roles: ROLES_GOOGLE_PERSONAL, descripcion: d.descripcion }));

export interface PeticionGoogle {
  accion?: unknown;
  herramienta?: unknown;
  parametros?: unknown;
  confirmado?: unknown;
  sesion?: unknown;
  ambito?: unknown;
  codigo?: unknown;
  estado?: unknown;
}

const err = (estado: number, codigo: string, mensaje: string): Resultado => ({ estado, cuerpo: { error: codigo, mensaje } });
const ISO = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:\d{2})$/;
const TEXTO = (v: unknown, min: number, max: number): string | null =>
  typeof v === "string" && v.trim().length >= min && v.length <= max ? v : null;

export function esAccionGoogle(p: PeticionGoogle): boolean {
  return p.accion === "herramienta" || p.accion === "google_url" || p.accion === "google_codigo";
}

async function bitacorear(d: DepsGoogle, yo: Identidad, p: PeticionGoogle, herramienta: string, ambito: string, resultado: string) {
  // Solo quién, cuándo, qué herramienta y cómo terminó. Jamás asuntos, cuerpos ni títulos.
  await d.bitacora({
    hogar_id: yo.hogarId,
    persona_id: yo.personaId,
    accion: "gravity.google",
    detalle: { sesion: typeof p.sesion === "string" ? p.sesion : null, herramienta, ambito, resultado },
  }).catch(() => {});
}

export async function atenderGoogle(p: PeticionGoogle, yo: Identidad, d: DepsGoogle): Promise<Resultado> {
  if (!d.cfg) return err(503, "google_sin_configurar", "Google aún no está configurado en el servidor.");
  if (p.accion === "google_url") return urlConexion(p, yo, d);
  if (p.accion === "google_codigo") return guardarConexion(p, yo, d);
  return ejecutar(p, yo, d);
}

// --- Conectar la cuenta ------------------------------------------------------------------------------------------

function ambitoPermitido(p: PeticionGoogle, yo: Identidad): "personal" | "casa" | null {
  const ambito = p.ambito === "casa" ? "casa" : "personal";
  if (ambito === "casa") return yo.rol === "dueno" ? "casa" : null; // la cuenta de la casa la conecta el dueño
  return ROLES_GOOGLE_PERSONAL.includes(yo.rol) ? "personal" : null;
}

async function urlConexion(p: PeticionGoogle, yo: Identidad, d: DepsGoogle): Promise<Resultado> {
  const ambito = ambitoPermitido(p, yo);
  if (!ambito) return err(403, "rol_sin_google", "Tu perfil no conecta una cuenta de Google.");
  try {
    const expira = (d.ahora?.() ?? Date.now()) + 10 * 60_000;
    const estado = await firmarEstado(d.claveToken, { personaId: yo.personaId, hogarId: yo.hogarId, ambito, expira });
    return { estado: 200, cuerpo: { url: urlAutorizacion(d.cfg!, ambito, estado) } };
  } catch (e) {
    if (e instanceof ErrorCifrado) return err(503, "google_sin_clave", "Falta la clave de cifrado de Google en el servidor.");
    throw e;
  }
}

async function guardarConexion(p: PeticionGoogle, yo: Identidad, d: DepsGoogle): Promise<Resultado> {
  const codigo = TEXTO(p.codigo, 1, 2000);
  const estadoTxt = TEXTO(p.estado, 1, 1000);
  if (!codigo || !estadoTxt) return err(400, "conexion_invalida", "Falta el código de Google.");
  const estado = await verificarEstado(d.claveToken, estadoTxt, d.ahora?.() ?? Date.now()).catch(() => null);
  // El estado liga el código a ESTA persona: nadie conecta una cuenta a nombre de otra.
  if (!estado || estado.personaId !== yo.personaId || estado.hogarId !== yo.hogarId) {
    return err(400, "estado_invalido", "La conexión caducó o no es tuya. Vuelve a empezar.");
  }
  const ambito = estado.ambito === "casa" ? "casa" : "personal";
  if (ambitoPermitido({ ambito }, yo) !== ambito) return err(403, "rol_sin_google", "Tu perfil no conecta esa cuenta de Google.");
  try {
    const t = await intercambiarCodigo(d.fetch, d.cfg!, codigo);
    if (!t.refreshToken) {
      return err(400, "sin_renovacion", "Google no entregó permiso de renovación. Quita el acceso de GRAVITY en tu cuenta de Google y vuelve a conectar.");
    }
    const correo = await correoDeLaCuenta(d.fetch, t.accessToken);
    const tokenCifrado = await cifrar(t.refreshToken, d.claveToken, `${yo.personaId}:${ambito}`);
    await d.almacen.guardar({ hogarId: yo.hogarId, personaId: yo.personaId, ambito, correo, alcances: t.alcances, tokenCifrado, accesoCasa: false });
    await bitacorear(d, yo, p, "google.conectar", ambito, "ok");
    return { estado: 200, cuerpo: { ok: true, correo, ambito } };
  } catch (e) {
    if (e instanceof ErrorCifrado) return err(503, "google_sin_clave", "Falta la clave de cifrado de Google en el servidor.");
    await bitacorear(d, yo, p, "google.conectar", ambito, "error_google");
    return err(502, "google_no_disponible", "No pude conectar con Google. Inténtalo más tarde.");
  }
}

// --- Ejecutar una herramienta -----------------------------------------------------------------------------------

async function ejecutar(p: PeticionGoogle, yo: Identidad, d: DepsGoogle): Promise<Resultado> {
  const nombre = typeof p.herramienta === "string" ? p.herramienta : "";
  const def = DEFINICIONES[nombre];
  if (!def) return err(400, "herramienta_desconocida", "Esa herramienta no existe.");
  if (!def.roles.includes(yo.rol)) return err(403, "rol_sin_herramienta", "Tu perfil no puede usar esa herramienta.");
  const ambito: "personal" | "casa" = yo.rol === "casa" ? "casa" : "personal";
  const par = (p.parametros && typeof p.parametros === "object" ? p.parametros : {}) as Record<string, unknown>;
  const confirmado = p.confirmado === true;

  // Validación y vista previa ANTES de tocar la cuenta: una escritura sin confirmar nunca llama a Google para escribir.
  let entrada: Record<string, unknown> = {};
  if (nombre === "gmail.redactar") {
    const para = TEXTO(par.para, 3, 254), asunto = TEXTO(par.asunto, 1, 200), cuerpo = TEXTO(par.cuerpo, 1, 5000);
    if (!para || !CORREO_VALIDO.test(para) || !asunto || /[\r\n]/.test(asunto) || !cuerpo) {
      return err(400, "parametros_invalidos", "Revisa el destinatario, el asunto y el mensaje.");
    }
    entrada = { para, asunto, cuerpo };
  } else if (nombre === "gmail.enviar") {
    const id = typeof par.borrador_id === "string" && /^[A-Za-z0-9_-]{1,100}$/.test(par.borrador_id) ? par.borrador_id : null;
    if (!id) return err(400, "parametros_invalidos", "Falta el borrador.");
    if (!confirmado) return err(409, "confirmacion_requerida", "Falta tu confirmación para enviar el correo.");
    entrada = { borrador_id: id };
  } else if (nombre === "calendario.crear") {
    const titulo = TEXTO(par.titulo, 1, 200);
    const inicio = typeof par.inicio === "string" && ISO.test(par.inicio) ? par.inicio : null;
    const fin = typeof par.fin === "string" && ISO.test(par.fin) ? par.fin : null;
    const descripcion = par.descripcion === undefined || par.descripcion === "" ? undefined : TEXTO(par.descripcion, 0, 1000);
    const lugar = par.lugar === undefined || par.lugar === "" ? undefined : TEXTO(par.lugar, 0, 200);
    const t0 = inicio ? Date.parse(inicio) : NaN, t1 = fin ? Date.parse(fin) : NaN;
    if (!titulo || !inicio || !fin || Number.isNaN(t0) || Number.isNaN(t1) || t1 <= t0 || t1 - t0 > 7 * 86_400_000 || descripcion === null || lugar === null) {
      return err(400, "parametros_invalidos", "Revisa el título y que el evento termine después de empezar.");
    }
    entrada = { titulo, inicio, fin, ...(descripcion ? { descripcion } : {}), ...(lugar ? { lugar } : {}) };
  } else if (nombre === "calendario.ver") {
    const dias = par.dias === undefined ? 7 : Number(par.dias);
    if (!Number.isInteger(dias) || dias < 1 || dias > 14) return err(400, "parametros_invalidos", "Pide entre 1 y 14 días.");
    entrada = { dias };
  }

  // Cuenta: SIEMPRE la de quien pregunta (la identidad sale de la base, no de la app). Casa: solo la de la casa.
  const cuenta = await d.almacen.obtener({ hogarId: yo.hogarId, personaId: yo.personaId, ambito });
  if (!cuenta) {
    return err(409, "sin_cuenta_google", ambito === "casa" ? "Falta conectar la cuenta de Google de la casa." : "Falta conectar tu cuenta de Google.");
  }
  if (ambito === "casa" && !cuenta.accesoCasa) {
    await bitacorear(d, yo, p, nombre, ambito, "casa_sin_aprobacion");
    return err(403, "casa_sin_aprobacion", "El dueño aún no aprobó que Casa vea el calendario de la casa.");
  }

  // Vista previa de las escrituras: no se llama a Google hasta que la app manda confirmado.
  if (nombre === "calendario.crear" && !confirmado) {
    return {
      estado: 200,
      cuerpo: {
        requiere_confirmacion: true,
        confirmacion: {
          herramienta: "calendario.crear",
          parametros: entrada,
          titulo: "¿Crear este evento?",
          lineas: [String(entrada.titulo), `Desde: ${entrada.inicio}`, `Hasta: ${entrada.fin}`, ...(entrada.lugar ? [`Lugar: ${entrada.lugar}`] : [])],
          boton: "Crear evento",
        },
      },
    };
  }

  try {
    const acceso = await renovarAcceso(d.fetch, d.cfg!, await descifrar(cuenta.tokenCifrado, d.claveToken, `${cuenta.personaId}:${cuenta.ambito}`));
    const g = new ClienteGoogle(d.fetch, acceso);
    switch (nombre) {
      case "gmail.leer": {
        const correos = await g.listarCorreos(10);
        await bitacorear(d, yo, p, nombre, ambito, "ok");
        return {
          estado: 200,
          cuerpo: {
            ok: true,
            local: {
              titulo: correos.length ? "Tu bandeja de entrada" : "No hay correos recientes en tu bandeja.",
              lineas: correos.map((c) => `${c.asunto || "(sin asunto)"} · ${c.de}${c.fragmento ? ` · ${c.fragmento}` : ""}`),
            },
          },
        };
      }
      case "gmail.redactar": {
        const borradorId = await g.crearBorrador(entrada as never);
        await bitacorear(d, yo, p, nombre, ambito, "borrador");
        return {
          estado: 200,
          cuerpo: {
            requiere_confirmacion: true,
            confirmacion: {
              herramienta: "gmail.enviar",
              parametros: { borrador_id: borradorId },
              titulo: "¿Enviar este correo?",
              lineas: [`Para: ${entrada.para}`, `Asunto: ${entrada.asunto}`, String(entrada.cuerpo).slice(0, 300)],
              boton: "Enviar correo",
            },
          },
        };
      }
      case "gmail.enviar": {
        await g.enviarBorrador(String(entrada.borrador_id));
        await bitacorear(d, yo, p, nombre, ambito, "enviado");
        return { estado: 200, cuerpo: { ok: true, local: { titulo: "Correo enviado.", lineas: [] } } };
      }
      case "calendario.ver": {
        const desde = new Date(d.ahora?.() ?? Date.now());
        const hasta = new Date(desde.getTime() + Number(entrada.dias) * 86_400_000);
        const eventos = await g.verEventos(desde.toISOString(), hasta.toISOString());
        await bitacorear(d, yo, p, nombre, ambito, "ok");
        return {
          estado: 200,
          cuerpo: {
            ok: true,
            local: {
              titulo: eventos.length ? "Próximos eventos" : "No hay eventos en ese tiempo.",
              lineas: eventos.map((e) => `${e.inicio} · ${e.titulo}${e.lugar ? ` · ${e.lugar}` : ""}`),
            },
          },
        };
      }
      default: {
        await g.crearEvento(entrada as never);
        await bitacorear(d, yo, p, nombre, ambito, "creado");
        return { estado: 200, cuerpo: { ok: true, local: { titulo: "Evento creado.", lineas: [] } } };
      }
    }
  } catch (e) {
    if (e instanceof ErrorGoogle && e.caducada) {
      await bitacorear(d, yo, p, nombre, ambito, "cuenta_caducada");
      return err(409, "cuenta_google_caducada", "Google pide que vuelvas a conectar tu cuenta.");
    }
    await bitacorear(d, yo, p, nombre, ambito, "error_google");
    return err(502, "google_no_disponible", "No pude consultar Google ahora. Inténtalo más tarde.");
  }
}
