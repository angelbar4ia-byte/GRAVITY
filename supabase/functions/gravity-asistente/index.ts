// Edge Function gravity-asistente (Deno): conversación de texto de GRAVITY (Fase 6, parte 1).
// La invoca la app con la sesión de la persona (Authorization: Bearer <JWT del usuario>).
//
// Secretos y ajustes del servidor (nunca en la app ni en el repositorio):
//   supabase secrets set GEMINI_API_KEY=...            # proveedor por defecto
//   supabase secrets set ANTHROPIC_API_KEY=...         # opcional, clave del dueño
//   supabase secrets set OPENAI_API_KEY=...            # opcional, clave del dueño
//   GRAVITY_IA_PROVEEDOR   gemini (por omisión) | claude | chatgpt
//   GRAVITY_IA_MODELO      modelo del proveedor (por omisión, el de proveedores.ts)
//   GRAVITY_IA_LIMITE_DIARIO  mensajes por persona y día (por omisión 30; 0 = sin límite)
// (SUPABASE_URL, SUPABASE_ANON_KEY y SUPABASE_SERVICE_ROLE_KEY las pone Supabase.)
import catalogo from "./catalogo.json" with { type: "json" };
import { responder } from "./asistente.ts";
import { crearProveedor, SECRETO_DE } from "./proveedores.ts";

const CABECERAS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
};

function respuesta(estado: number, cuerpo: unknown): Response {
  return Response.json(cuerpo, { status: estado, headers: CABECERAS });
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CABECERAS });
  if (req.method !== "POST") return respuesta(405, { error: "metodo", mensaje: "Usa POST." });

  const base = Deno.env.get("SUPABASE_URL") ?? "";
  const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const servicio = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");

  const rest = (ruta: string, init: RequestInit = {}, bearer = servicio) =>
    fetch(`${base}/rest/v1/${ruta}`, {
      ...init,
      headers: { apikey: bearer === token ? anon : servicio, Authorization: `Bearer ${bearer}`, "Content-Type": "application/json", ...(init.headers ?? {}) },
    });

  let cuerpo: Record<string, unknown> = {};
  try {
    cuerpo = await req.json();
  } catch {
    return respuesta(400, { error: "cuerpo", mensaje: "El cuerpo debe ser JSON." });
  }

  const idProveedor = (Deno.env.get("GRAVITY_IA_PROVEEDOR") ?? "gemini").toLowerCase();
  const limite = Number(Deno.env.get("GRAVITY_IA_LIMITE_DIARIO") ?? "30");
  const proveedor = crearProveedor(idProveedor, fetch as never, Deno.env.get("GRAVITY_IA_MODELO") ?? undefined);

  const r = await responder(cuerpo, {
    catalogo: catalogo.herramientas,
    proveedor,
    clave: Deno.env.get(SECRETO_DE[idProveedor] ?? "") || undefined,
    limiteDiario: Number.isFinite(limite) ? limite : 30,
    // El rol sale de la base con la sesión de la persona (RLS), no de lo que mande la app.
    identidad: async () => {
      if (!token || !anon) return null;
      const u = await fetch(`${base}/auth/v1/user`, { headers: { apikey: anon, Authorization: `Bearer ${token}` } });
      if (!u.ok) return null;
      const usuario = await u.json();
      const m = await rest(
        `membresias?select=hogar_id,rol,persona_id,personas!inner(usuario_id)&activa=eq.true&personas.usuario_id=eq.${encodeURIComponent(usuario.id)}&limit=1`,
        {},
        token,
      );
      if (!m.ok) return null;
      const filas = await m.json();
      const f = filas?.[0];
      return f ? { personaId: f.persona_id, hogarId: f.hogar_id, rol: f.rol } : null;
    },
    usoHoy: async (personaId) => {
      const inicio = new Date();
      inicio.setUTCHours(0, 0, 0, 0);
      const c = await rest(
        `bitacora?select=id&persona_id=eq.${personaId}&accion=eq.gravity.asistente&registrado_en=gte.${inicio.toISOString()}`,
        { method: "HEAD", headers: { Prefer: "count=exact" } },
      );
      const total = (c.headers.get("content-range") ?? "").split("/")[1];
      return Number(total) || 0;
    },
    bitacora: async (fila) => {
      const i = await rest("bitacora", { method: "POST", body: JSON.stringify(fila), headers: { Prefer: "return=minimal" } });
      if (!i.ok) throw new Error(`bitacora: ${i.status}`);
    },
  });
  return respuesta(r.estado, r.cuerpo);
});
