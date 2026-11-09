// Núcleo de la función gravity-asistente, sin Deno ni red directa: todo lo externo entra por
// Dependencias, así se prueba con un proveedor falso (asistente_test.ts).
import { armarContexto, ContextoSensibleError, type HerramientaCatalogo, ROLES_QUE_CONVERSAN, type Turno } from "./contexto.ts";
import type { ProveedorIa } from "./proveedores.ts";
import { armarContextoRecetas, PeticionRecetasError, RespuestaRecetasError, validarContextoRecetas, validarRespuestaRecetas } from "./sugerir_recetas.ts";
import { atenderGoogle, CATALOGO_GOOGLE, esAccionGoogle, type DepsGoogle, type PeticionGoogle } from "./herramientas_google.ts";

export interface Identidad {
  personaId: string;
  hogarId: string;
  /** Rol vigente en la base (membresías), NUNCA el que diga la app. */
  rol: string;
}

export interface FilaBitacora {
  hogar_id: string;
  persona_id: string;
  accion: "gravity.asistente";
  /** Solo quién, cuándo y qué herramienta. Jamás el texto de la conversación. */
  detalle: { sesion: string; proveedor: string; herramienta: string | null; resultado: string };
}

/** Fila de bitácora de las herramientas de Google: sin asuntos, cuerpos ni títulos. */
export interface FilaBitacoraGoogle {
  hogar_id: string;
  persona_id: string;
  accion: "gravity.google";
  detalle: { sesion: string | null; herramienta: string; ambito: string; resultado: string };
}

export interface Dependencias {
  /** Gmail y Calendar (Fase 6, parte 2). Ausente = no se ofrecen. */
  google?: DepsGoogle;
  catalogo: HerramientaCatalogo[];
  /** Proveedor elegido (GRAVITY_IA_PROVEEDOR); null si el nombre no existe. */
  proveedor: ProveedorIa | null;
  /** Clave del secreto del servidor; vacía o ausente = sin configurar. */
  clave: string | undefined;
  /** Mensajes por persona y por día; 0 o menos = sin límite. */
  limiteDiario: number;
  identidad: () => Promise<Identidad | null>;
  usoHoy: (personaId: string) => Promise<number>;
  bitacora: (fila: FilaBitacora) => Promise<void>;
}

export interface Peticion extends PeticionGoogle {
  /** `sugerir_recetas` (Alimentación) o las acciones de Google. */
  contexto?: unknown;
  mensaje?: unknown;
  sesion?: unknown;
  historial?: unknown;
  /** La app lo manda por comodidad; el servidor lo ignora y usa el de la base. */
  rol?: unknown;
}

export interface Resultado {
  estado: number;
  cuerpo: Record<string, unknown>;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const MAX_MENSAJE = 1000;

function error(estado: number, codigo: string, mensaje: string): Resultado {
  return { estado, cuerpo: { error: codigo, mensaje } };
}

function turnos(valor: unknown): Turno[] {
  if (!Array.isArray(valor)) return [];
  const salida: Turno[] = [];
  for (const t of valor.slice(-6)) {
    if (t && (t.de === "persona" || t.de === "asistente") && typeof t.texto === "string") {
      salida.push({ de: t.de, texto: t.texto });
    }
  }
  return salida;
}

export async function responder(p: Peticion, d: Dependencias): Promise<Resultado> {
  // Ejecutar una herramienta de Google (o conectar la cuenta): lo pide la app, nunca el modelo. El resultado va a la
  // app y no pasa por el proveedor de IA.
  if (esAccionGoogle(p)) {
    if (!d.google) return error(503, "google_sin_configurar", "Google aún no está configurado en el servidor.");
    const quien = await d.identidad();
    if (!quien) return error(401, "no_autorizado", "Inicia sesión para usar Google.");
    return atenderGoogle(p, quien, d.google);
  }
  if (p.accion === "sugerir_recetas") return sugerirRecetas(p, d);
  const mensaje = typeof p.mensaje === "string" ? p.mensaje.trim() : "";
  if (!mensaje) return error(400, "mensaje_vacio", "Escribe un mensaje.");
  if (mensaje.length > MAX_MENSAJE) return error(400, "mensaje_largo", `El mensaje pasa de ${MAX_MENSAJE} caracteres.`);
  const sesion = typeof p.sesion === "string" && UUID.test(p.sesion) ? p.sesion.toLowerCase() : null;
  if (!sesion) return error(400, "sesion_invalida", "Falta el identificador de la conversación.");

  const yo = await d.identidad();
  if (!yo) return error(401, "no_autorizado", "Inicia sesión para hablar con GRAVITY.");
  if (!ROLES_QUE_CONVERSAN.has(yo.rol)) {
    return error(403, "rol_sin_conversacion", "Tu perfil no conversa con GRAVITY; usa tus solicitudes y recordatorios.");
  }

  // Sin clave: error claro y nada sale hacia el proveedor.
  if (!d.proveedor) return error(503, "proveedor_desconocido", "El proveedor de IA configurado no existe.");
  if (!d.clave) return error(503, "sin_clave", "El asistente aún no está configurado: falta la clave del proveedor en el servidor.");

  if (d.limiteDiario > 0 && (await d.usoHoy(yo.personaId)) >= d.limiteDiario) {
    return error(429, "limite_diario", "Llegaste al límite de mensajes de hoy. Vuelve a intentarlo mañana.");
  }

  let contexto;
  try {
    contexto = armarContexto({ catalogo: d.google ? [...d.catalogo, ...CATALOGO_GOOGLE] : d.catalogo, rol: yo.rol, mensaje, historial: turnos(p.historial) });
  } catch (e) {
    if (e instanceof ContextoSensibleError) return error(500, "contexto_sensible", "No se pudo preparar la consulta.");
    throw e;
  }

  const registrar = (herramienta: string | null, resultado: string) =>
    d.bitacora({
      hogar_id: yo.hogarId,
      persona_id: yo.personaId,
      accion: "gravity.asistente",
      detalle: { sesion, proveedor: d.proveedor!.id, herramienta, resultado },
    });

  try {
    const r = await d.proveedor.generar(contexto, d.clave);
    // El modelo solo puede elegir lo que se le ofreció; cualquier otra cosa se descarta.
    const permitidas = new Set(contexto.herramientas.map((h) => h.nombre));
    const herramienta = r.herramienta && permitidas.has(r.herramienta) ? r.herramienta : null;
    const texto = r.texto || (herramienta ? "Listo." : "No supe cómo ayudarte con eso.");
    await registrar(herramienta, "ok");
    return { estado: 200, cuerpo: { respuesta: texto, herramienta } };
  } catch {
    await registrar(null, "error_proveedor").catch(() => {});
    return error(502, "proveedor_no_disponible", "GRAVITY no pudo consultar a la IA ahora. Inténtalo más tarde.");
  }
}

/** Sugerir recetas con la despensa. No guarda nada: la app guarda solo si la persona confirma. */
async function sugerirRecetas(p: Peticion, d: Dependencias): Promise<Resultado> {
  let contexto;
  try {
    contexto = armarContextoRecetas(validarContextoRecetas(p.contexto));
  } catch (e) {
    if (e instanceof PeticionRecetasError) return error(e.codigo === "contexto_sensible" ? 500 : 400, e.codigo, e.message);
    throw e;
  }
  const yo = await d.identidad();
  if (!yo) return error(401, "no_autorizado", "Inicia sesión para pedir sugerencias.");
  if (!ROLES_QUE_CONVERSAN.has(yo.rol)) return error(403, "rol_sin_conversacion", "Tu perfil no puede pedir sugerencias de recetas.");
  if (!d.proveedor) return error(503, "proveedor_desconocido", "El proveedor de IA configurado no existe.");
  if (!d.clave) return error(503, "sin_clave", "El asistente aún no está configurado: falta la clave del proveedor en el servidor.");
  if (d.limiteDiario > 0 && (await d.usoHoy(yo.personaId)) >= d.limiteDiario) {
    return error(429, "limite_diario", "Llegaste al límite de mensajes de hoy. Vuelve a intentarlo mañana.");
  }
  const registrar = (resultado: string) =>
    d.bitacora({
      hogar_id: yo.hogarId,
      persona_id: yo.personaId,
      accion: "gravity.asistente",
      detalle: { sesion: "sugerir_recetas", proveedor: d.proveedor!.id, herramienta: "sugerir_recetas", resultado },
    });
  try {
    const r = await d.proveedor.generar(contexto, d.clave);
    const recetas = validarRespuestaRecetas(r.texto);
    await registrar("ok");
    return { estado: 200, cuerpo: { recetas } };
  } catch (e) {
    if (e instanceof RespuestaRecetasError) {
      await registrar("respuesta_invalida").catch(() => {});
      return error(502, "respuesta_invalida", "La IA devolvió recetas que no se pueden usar. Inténtalo otra vez.");
    }
    await registrar("error_proveedor").catch(() => {});
    return error(502, "proveedor_no_disponible", "GRAVITY no pudo consultar a la IA ahora. Inténtalo más tarde.");
  }
}
