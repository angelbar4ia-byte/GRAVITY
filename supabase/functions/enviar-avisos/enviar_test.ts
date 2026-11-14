// Pruebas de la Edge Function (criterios 32 y 50). Corren con Deno (`deno test`) o con Node 22+
// (`node --experimental-strip-types --test supabase/functions/enviar-avisos/enviar_test.ts`):
// usan solo node:test y node:assert, y un FCM simulado.
import { test } from "node:test";
import assert from "node:assert/strict";
import { enviarLote, mensajeFcm, type Dependencias, type Fila } from "./enviar.ts";
import { firmarJwt } from "./fcm.ts";

const A1 = "11111111-1111-4111-8111-111111111111";
const A2 = "22222222-2222-4222-8222-222222222222";

function crear(filas: Fila[], respuestas: Array<{ status: number; cuerpo?: unknown }>) {
  const llamadas: Array<{ nombre: string; args: any }> = [];
  const enviados: Array<{ url: string; cuerpo: any; cabeceras: any }> = [];
  let i = 0;
  const dep: Dependencias = {
    proyectoFcm: "proyecto-ejemplo",
    tokenAcceso: async () => "token-de-acceso-falso",
    rpc: async (nombre, args) => {
      llamadas.push({ nombre, args });
      return nombre === "avisos_reclamar" ? filas : null;
    },
    fetch: (async (url: string, init: any) => {
      enviados.push({ url, cuerpo: JSON.parse(init.body), cabeceras: init.headers });
      const r = respuestas[Math.min(i++, respuestas.length - 1)];
      return new Response(JSON.stringify(r.cuerpo ?? {}), { status: r.status });
    }) as unknown as typeof fetch,
  };
  return { dep, llamadas, enviados };
}

test("criterio 32: el cuerpo enviado es exactamente {v, id} con prioridad alta", async () => {
  const { dep, enviados } = crear([{ aviso_id: A1, intentos: 0, dispositivo_id: "d1", token: "tok1" }], [{ status: 200 }]);
  await enviarLote(dep);
  assert.equal(enviados.length, 1);
  const m = enviados[0].cuerpo.message;
  assert.deepEqual(m.data, { v: "1", id: A1 });
  assert.deepEqual(Object.keys(m).sort(), ["android", "data", "token"]);
  assert.equal(m.android.priority, "HIGH");
  assert.equal("notification" in m, false);
  // Ni tipo, ni libro, ni persona, ni texto: nada fuera de {v, id} (el collapse_key es el mismo id opaco).
  assert.deepEqual(Object.keys(m.data).sort(), ["id", "v"]);
  assert.equal(m.android.collapse_key, A1);
  assert.deepEqual(mensajeFcm("t", A1).message.data, { v: "1", id: A1 });
  assert.match(enviados[0].url, /fcm\.googleapis\.com\/v1\/projects\/proyecto-ejemplo\/messages:send$/);
});

test("Cuidados: un aviso de cambio urgente viaja igual, solo {v, id}, sin texto ni nada clínico (D6)", async () => {
  const { dep, enviados } = crear([{ aviso_id: A2, intentos: 0, dispositivo_id: "d9", token: "tok9" }], [{ status: 200 }]);
  await enviarLote(dep);
  const m = enviados[0].cuerpo.message;
  assert.deepEqual(m.data, { v: "1", id: A2 });
  assert.equal("notification" in m, false);
  assert.doesNotMatch(JSON.stringify(enviados[0].cuerpo), /cuidados|toma|comida|turno|urgente/i);
});

test("registra la entrega y el resultado; un solo aviso a varios dispositivos", async () => {
  const filas: Fila[] = [
    { aviso_id: A1, intentos: 0, dispositivo_id: "d1", token: "tok1" },
    { aviso_id: A1, intentos: 0, dispositivo_id: "d2", token: "tok2" },
  ];
  const { dep, llamadas } = crear(filas, [{ status: 200 }, { status: 200 }]);
  const r = await enviarLote(dep);
  assert.deepEqual(r, { avisos: 1, entregas: 2, ok: 2, tokenInvalido: 0, error: 0 });
  assert.equal(llamadas.filter((l) => l.nombre === "avisos_registrar_entrega").length, 2);
  const fin = llamadas.filter((l) => l.nombre === "avisos_resultado_envio");
  assert.equal(fin.length, 1);
  assert.equal(fin[0].args.p_ok, true);
});

test("UNREGISTERED se registra como token_invalido (el servidor borra el token)", async () => {
  const { dep, llamadas } = crear([{ aviso_id: A1, intentos: 0, dispositivo_id: "d1", token: "tok1" }],
    [{ status: 404, cuerpo: { error: { status: "NOT_FOUND", details: [{ errorCode: "UNREGISTERED" }] } } }]);
  const r = await enviarLote(dep);
  assert.equal(r.tokenInvalido, 1);
  const e = llamadas.find((l) => l.nombre === "avisos_registrar_entrega")!;
  assert.equal(e.args.p_resultado, "token_invalido");
});

test("un error del servidor de FCM es error (se reintenta a los 5, 15 y 60 minutos en SQL)", async () => {
  const { dep, llamadas } = crear([{ aviso_id: A1, intentos: 1, dispositivo_id: "d1", token: "tok1" }],
    [{ status: 503, cuerpo: { error: { status: "UNAVAILABLE" } } }]);
  const r = await enviarLote(dep);
  assert.equal(r.error, 1);
  assert.equal(llamadas.find((l) => l.nombre === "avisos_resultado_envio")!.args.p_ok, false);
});

test("un fallo de red no rompe el lote", async () => {
  const llamadas: string[] = [];
  const dep: Dependencias = {
    proyectoFcm: "p",
    tokenAcceso: async () => "t",
    rpc: async (n) => { llamadas.push(n); return n === "avisos_reclamar" ? [{ aviso_id: A1, intentos: 0, dispositivo_id: "d", token: "x" }] : null; },
    fetch: (async () => { throw new Error("sin red"); }) as unknown as typeof fetch,
  };
  const r = await enviarLote(dep);
  assert.equal(r.error, 1);
  assert.ok(llamadas.includes("avisos_resultado_envio"));
});

test("criterio 50: sin avisos reclamados no envía nada (ni pide token de acceso)", async () => {
  let pidioToken = false;
  const { dep, enviados } = crear([], []);
  dep.tokenAcceso = async () => { pidioToken = true; return "x"; };
  const r = await enviarLote(dep);
  assert.equal(r.avisos, 0);
  assert.equal(enviados.length, 0);
  assert.equal(pidioToken, false);
});

test("reclama como máximo 200 por corrida", async () => {
  const { dep, llamadas } = crear([], []);
  await enviarLote(dep, 5000);
  assert.equal(llamadas[0].args.p_limite, 200);
});

test("dos avisos distintos generan dos mensajes con su propio id", async () => {
  const { dep, enviados } = crear([
    { aviso_id: A1, intentos: 0, dispositivo_id: "d1", token: "tok1" },
    { aviso_id: A2, intentos: 0, dispositivo_id: "d1", token: "tok1" },
  ], [{ status: 200 }]);
  await enviarLote(dep);
  assert.deepEqual(enviados.map((e) => e.cuerpo.message.data.id), [A1, A2]);
});

test("el JWT de la cuenta de servicio es RS256 con el alcance de mensajería", async () => {
  const par = await crypto.subtle.generateKey(
    { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
    true, ["sign", "verify"]);
  const pkcs8 = new Uint8Array(await crypto.subtle.exportKey("pkcs8", par.privateKey));
  let b64 = ""; for (const b of pkcs8) b64 += String.fromCharCode(b);
  const pem = `-----BEGIN PRIVATE KEY-----\n${btoa(b64)}\n-----END PRIVATE KEY-----`;
  const jwt = await firmarJwt({ client_email: "cuenta@proyecto.iam.gserviceaccount.com", private_key: pem, project_id: "p" }, 1000);
  const [h, c, f] = jwt.split(".");
  const dec = (s: string) => JSON.parse(atob(s.replace(/-/g, "+").replace(/_/g, "/")));
  assert.deepEqual(dec(h), { alg: "RS256", typ: "JWT" });
  const reclamos = dec(c);
  assert.equal(reclamos.scope, "https://www.googleapis.com/auth/firebase.messaging");
  assert.equal(reclamos.exp - reclamos.iat, 3600);
  assert.ok(f.length > 100);
});
