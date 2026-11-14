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
// Gmail y Google Calendar (Fase 6, parte 2; ver README.md). Sin estos secretos las herramientas responden 503:
//   supabase secrets set GOOGLE_CLIENT_ID=...       # cliente OAuth de Google Cloud (tipo "Aplicación web")
//   supabase secrets set GOOGLE_CLIENT_SECRET=...
//   supabase secrets set GOOGLE_REDIRECT_URI=...    # la misma URI registrada en Google Cloud
//   supabase secrets set GOOGLE_TOKEN_KEY=...       # 32 bytes en base64: openssl rand -base64 32
// (SUPABASE_URL, SUPABASE_ANON_KEY y SUPABASE_SERVICE_ROLE_KEY las pone Supabase.)
import catalogo from "./catalogo.json" with { type: "json" };
import { responder } from "./asistente.ts";
import type { CuentaGoogleGuardada } from "./herramientas_google.ts";
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

  const clienteId = Deno.env.get("GOOGLE_CLIENT_ID") ?? "";
  const clienteSecreto = Deno.env.get("GOOGLE_CLIENT_SECRET") ?? "";
  const redireccion = Deno.env.get("GOOGLE_REDIRECT_URI") ?? "";
  const insertarBitacora = async (fila: unknown) => {
    const i = await rest("bitacora", { method: "POST", body: JSON.stringify(fila), headers: { Prefer: "return=minimal" } });
    if (!i.ok) throw new Error(`bitacora: ${i.status}`);
  };

  const r = await responder(cuerpo, {
    google: {
      cfg: clienteId && clienteSecreto && redireccion ? { clientId: clienteId, clientSecret: clienteSecreto, redirectUri: redireccion } : null,
      claveToken: Deno.env.get("GOOGLE_TOKEN_KEY") || undefined,
      fetch: fetch as never,
      bitacora: insertarBitacora,
      almacen: {
        // Con la llave de servicio, pero siempre filtrando por la identidad que salió de la base, nunca por la app.
        obtener: async ({ hogarId, personaId, ambito }) => {
          const filtro = ambito === "casa" ? `ambito=eq.casa&hogar_id=eq.${hogarId}` : `ambito=eq.personal&persona_id=eq.${personaId}&hogar_id=eq.${hogarId}`;
          const g = await rest(`google_cuentas?select=*&${filtro}&limit=1`);
          if (!g.ok) return null;
          const f = (await g.json())?.[0];
          return f
            ? ({ hogarId: f.hogar_id, personaId: f.persona_id, ambito: f.ambito, correo: f.correo, alcances: f.alcances, tokenCifrado: f.token_cifrado, accesoCasa: f.acceso_casa } as CuentaGoogleGuardada)
            : null;
        },
        guardar: async (c) => {
          // Reconectar reemplaza la fila (los índices únicos son parciales, sin upsert). Y quita la aprobación de Casa:
          // si cambia la cuenta de la casa, el dueño la vuelve a aprobar.
          const filtro = c.ambito === "casa" ? `ambito=eq.casa&hogar_id=eq.${c.hogarId}` : `ambito=eq.personal&persona_id=eq.${c.personaId}`;
          const borrar = await rest(`google_cuentas?${filtro}`, { method: "DELETE" });
          if (!borrar.ok) throw new Error(`google_cuentas: ${borrar.status}`);
          const w = await rest("google_cuentas", {
            method: "POST",
            body: JSON.stringify({ hogar_id: c.hogarId, persona_id: c.personaId, ambito: c.ambito, correo: c.correo, alcances: c.alcances, token_cifrado: c.tokenCifrado }),
            headers: { Prefer: "return=minimal" },
          });
          if (!w.ok) throw new Error(`google_cuentas: ${w.status}`);
        },
      },
    },
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
    bitacora: insertarBitacora,
  });
  return respuesta(r.estado, r.cuerpo);
});
