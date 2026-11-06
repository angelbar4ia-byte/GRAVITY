// Edge Function enviar-avisos (Deno). La invoca pg_cron + pg_net cada 5 minutos con la clave de
// servicio guardada en el Vault de Supabase. Secretos (nunca en el repositorio):
//   supabase secrets set FCM_SERVICE_ACCOUNT='<JSON de la cuenta de servicio de Firebase>'
//   (SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY las pone Supabase.)
// Sin FCM_SERVICE_ACCOUNT la función no envía y no falla: la app sigue con recordatorios locales y bandeja.
import { enviarLote } from "./enviar.ts";
import { type CuentaServicio, tokenAcceso } from "./fcm.ts";

function iguales(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}

Deno.serve(async (req: Request): Promise<Response> => {
  const claveServicio = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const presentada = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  // Solo quien tiene la clave de servicio (no basta una clave anon válida).
  if (!claveServicio || !iguales(presentada, claveServicio)) {
    return new Response(JSON.stringify({ error: "no autorizado" }), { status: 401 });
  }
  const secreto = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!secreto) {
    return Response.json({ enviados: 0, motivo: "sin_secreto" });
  }
  let cuenta: CuentaServicio;
  try {
    cuenta = JSON.parse(secreto);
  } catch {
    return Response.json({ enviados: 0, motivo: "secreto_ilegible" });
  }
  const base = Deno.env.get("SUPABASE_URL") ?? "";
  try {
    const resumen = await enviarLote({
      fetch,
      proyectoFcm: cuenta.project_id,
      tokenAcceso: () => tokenAcceso(cuenta, fetch),
      rpc: async (nombre, args) => {
        const r = await fetch(`${base}/rest/v1/rpc/${nombre}`, {
          method: "POST",
          headers: { apikey: claveServicio, Authorization: `Bearer ${claveServicio}`, "Content-Type": "application/json" },
          body: JSON.stringify(args),
        });
        if (!r.ok) throw new Error(`${nombre}: ${r.status}`);
        const texto = await r.text();
        return texto ? JSON.parse(texto) : null;
      },
    });
    return Response.json(resumen);
  } catch (e) {
    // La base sigue bien: lo reclamado se libera solo a los 3 minutos.
    return Response.json({ enviados: 0, motivo: "error", detalle: String((e as Error).message).slice(0, 120) }, { status: 200 });
  }
});
