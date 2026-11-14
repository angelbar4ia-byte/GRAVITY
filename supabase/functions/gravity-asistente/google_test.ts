// Pruebas sin red de Gmail y Calendar: Google falso, proveedor de IA falso.
// node --experimental-strip-types --test supabase/functions/gravity-asistente/google_test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { responder, type Dependencias, type FilaBitacoraGoogle } from "./asistente.ts";
import { cifrar, descifrar, firmarEstado, verificarEstado } from "./cifrado.ts";
import { type ContextoIa } from "./contexto.ts";
import { armarMime } from "./google.ts";
import { CATALOGO_GOOGLE, type CuentaGoogleGuardada } from "./herramientas_google.ts";
import type { ProveedorIa } from "./proveedores.ts";

const catalogo = JSON.parse(readFileSync(new URL("./catalogo.json", import.meta.url), "utf8")).herramientas;
const SESION = "11111111-1111-4111-8111-111111111111";
const HOGAR = "h1";
const CLAVE = Buffer.alloc(32, 7).toString("base64");
const CFG = { clientId: "id-de-prueba", clientSecret: "secreto-de-prueba", redirectUri: "https://ejemplo.test/cb" };
const SECRETO_CORREO = "Transferencia de $12,500 y tu dosis de 500 mg";

const PERSONAS: Record<string, { id: string; rol: string }> = {
  ana: { id: "p-ana", rol: "dueno" },
  alex: { id: "p-alex", rol: "coadministrador" },
  carla: { id: "p-carla", rol: "familiar" },
  diana: { id: "p-diana", rol: "cuidador" },
  casa: { id: "p-casa", rol: "casa" },
};

/** Google falso: guarda cada llamada y responde por URL. Cada refresh token identifica al dueño de la cuenta. */
function googleFalso() {
  const llamadas: Array<{ url: string; metodo: string; auth: string; cuerpo: string }> = [];
  const f = async (url: string, init: { method?: string; headers?: Record<string, string>; body?: string } = {}) => {
    const auth = init.headers?.Authorization ?? "";
    llamadas.push({ url, metodo: init.method ?? "GET", auth, cuerpo: init.body ?? "" });
    const j = (o: unknown, status = 200) => Response.json(o, { status });
    if (url.startsWith("https://oauth2.googleapis.com/token")) {
      const q = new URLSearchParams(init.body);
      if (q.get("grant_type") === "authorization_code") {
        return q.get("code") === "sin-refresh"
          ? j({ access_token: "acc-nuevo", scope: "x" })
          : j({ access_token: "acc-nuevo", refresh_token: "refresh-nuevo", scope: "a b" });
      }
      if (q.get("refresh_token") === "refresh-caducado") return j({ error: "invalid_grant" }, 400);
      return j({ access_token: "acc-de-" + q.get("refresh_token") });
    }
    if (url.includes("userinfo")) return j({ email: "nueva@gmail.test" });
    const dueno = auth.replace("Bearer acc-de-", "");
    if (url.includes("/messages?")) return j({ messages: [{ id: "m1" }] });
    if (url.includes("/messages/m1")) {
      return j({ snippet: SECRETO_CORREO, payload: { headers: [{ name: "From", value: `${dueno}@gmail.test` }, { name: "Subject", value: `Asunto de ${dueno}` }] } });
    }
    if (url.endsWith("/drafts")) return j({ id: "borrador_1" });
    if (url.endsWith("/drafts/send")) return j({ id: "enviado_1" });
    if (url.includes("/calendar/v3/") && (init.method ?? "GET") === "GET") {
      return j({ items: [{ id: "e1", summary: `Evento de ${dueno}`, start: { dateTime: "2026-11-10T10:00:00-06:00" }, end: { dateTime: "2026-11-10T11:00:00-06:00" } }] });
    }
    if (url.includes("/calendar/v3/")) return j({ id: "e2" });
    return j({}, 404);
  };
  return { f, llamadas };
}

async function montar(opts: { rol?: keyof typeof PERSONAS; cuentas?: string[]; sinCfg?: boolean; accesoCasa?: boolean; sinClave?: boolean } = {}) {
  const quien = PERSONAS[opts.rol ?? "ana"];
  const g = googleFalso();
  const bitacora: FilaBitacoraGoogle[] = [];
  const guardadas: CuentaGoogleGuardada[] = [];
  const almacenCuentas = new Map<string, CuentaGoogleGuardada>();
  for (const n of opts.cuentas ?? []) {
    const p = PERSONAS[n];
    const ambito = n === "casa" ? "casa" : "personal";
    almacenCuentas.set(`${ambito}:${n === "casa" ? HOGAR : p.id}`, {
      hogarId: HOGAR,
      personaId: p.id,
      ambito,
      correo: `${n}@gmail.test`,
      alcances: [],
      tokenCifrado: await cifrar(`refresh-${n}`, CLAVE, `${p.id}:${ambito}`),
      accesoCasa: n === "casa" ? opts.accesoCasa ?? true : false,
    });
  }
  const vistos: ContextoIa[] = [];
  const proveedor: ProveedorIa = {
    id: "falso",
    async generar(c) {
      vistos.push(c);
      return { texto: "Listo.", herramienta: "gmail.leer" };
    },
  };
  const d: Dependencias = {
    catalogo,
    proveedor,
    clave: "k",
    limiteDiario: 0,
    identidad: async () => ({ personaId: quien.id, hogarId: HOGAR, rol: quien.rol }),
    usoHoy: async () => 0,
    bitacora: async () => {},
    google: {
      cfg: opts.sinCfg ? null : CFG,
      claveToken: opts.sinClave ? undefined : CLAVE,
      fetch: g.f as never,
      bitacora: async (fila) => void bitacora.push(fila),
      almacen: {
        // Como en el servidor: la fila sale de la identidad, no de un id de la petición.
        obtener: async ({ personaId, ambito }) => almacenCuentas.get(`${ambito}:${ambito === "casa" ? HOGAR : personaId}`) ?? null,
        guardar: async (c) => void guardadas.push(c),
      },
    },
  };
  const llamar = (p: Record<string, unknown>) => responder({ sesion: SESION, ...p }, d);
  return { llamar, g, bitacora, guardadas, vistos, d };
}

const redactar = { para: "luis@ejemplo.test", asunto: "Hola", cuerpo: "Nos vemos mañana." };
const evento = { titulo: "Cena", inicio: "2026-11-12T19:00:00-06:00", fin: "2026-11-12T21:00:00-06:00" };
const escribio = (g: ReturnType<typeof googleFalso>) => g.llamadas.some((l) => l.metodo !== "GET" && !l.url.includes("oauth2") );

// --- Cifrado ---------------------------------------------------------------------------------------------------

test("el token se cifra, no se ve en claro y solo descifra para su dueño", async () => {
  const c = await cifrar("refresh-secreto", CLAVE, "p-ana:personal");
  assert.match(c, /^v1:[^:]+:[^:]+$/);
  assert.ok(!c.includes("refresh-secreto"));
  assert.equal(await descifrar(c, CLAVE, "p-ana:personal"), "refresh-secreto");
  await assert.rejects(descifrar(c, CLAVE, "p-alex:personal"), /descifrar/);
  await assert.rejects(descifrar(c, Buffer.alloc(32, 9).toString("base64"), "p-ana:personal"));
  await assert.rejects(cifrar("x", undefined, "a"), /GOOGLE_TOKEN_KEY/);
  await assert.rejects(cifrar("x", "corta", "a"));
});

test("el estado de OAuth está firmado, caduca y no se puede cambiar", async () => {
  const e = await firmarEstado(CLAVE, { personaId: "p-ana", hogarId: HOGAR, ambito: "personal", expira: 2000 });
  assert.deepEqual(await verificarEstado(CLAVE, e, 1000), { personaId: "p-ana", hogarId: HOGAR, ambito: "personal" });
  assert.equal(await verificarEstado(CLAVE, e, 3000), null);
  assert.equal(await verificarEstado(CLAVE, e.replace("p-ana", "p-alex"), 1000), null);
  assert.equal(await verificarEstado(CLAVE, e.replace("personal", "casa"), 1000), null);
});

// --- Sin cuenta o sin configurar -------------------------------------------------------------------------------

test("sin cuenta conectada responde que falta conectarla y no llama a Google", async () => {
  const { llamar, g } = await montar({ cuentas: [] });
  for (const herramienta of ["gmail.leer", "calendario.ver"]) {
    const r = await llamar({ accion: "herramienta", herramienta });
    assert.equal(r.estado, 409);
    assert.equal(r.cuerpo.error, "sin_cuenta_google");
    assert.match(String(r.cuerpo.mensaje), /Falta conectar tu cuenta de Google/);
  }
  assert.equal(g.llamadas.length, 0);
});

test("sin secretos de Google en el servidor: 503 claro", async () => {
  const { llamar } = await montar({ sinCfg: true, cuentas: ["ana"] });
  const r = await llamar({ accion: "herramienta", herramienta: "gmail.leer" });
  assert.equal(r.estado, 503);
  assert.equal(r.cuerpo.error, "google_sin_configurar");
});

test("cuenta caducada o revocada: pide reconectar", async () => {
  const { llamar, d } = await montar({ cuentas: ["ana"] });
  const almacen = d.google!.almacen;
  const cuenta = (await almacen.obtener({ hogarId: HOGAR, personaId: "p-ana", ambito: "personal" }))!;
  cuenta.tokenCifrado = await cifrar("refresh-caducado", CLAVE, "p-ana:personal");
  const r = await llamar({ accion: "herramienta", herramienta: "gmail.leer" });
  assert.equal(r.cuerpo.error, "cuenta_google_caducada");
});

// --- Cada persona solo ve lo suyo ------------------------------------------------------------------------------

test("cada persona solo ve su correo y su calendario", async () => {
  for (const [rol, esperado] of [["ana", "ana"], ["alex", "alex"], ["carla", "carla"]] as const) {
    const { llamar, g } = await montar({ rol, cuentas: ["ana", "alex", "carla"] });
    const r = await llamar({ accion: "herramienta", herramienta: "gmail.leer", persona_id: "p-ana", parametros: { persona_id: "p-ana", cuenta: "ana" } });
    assert.equal(r.estado, 200);
    const lineas = (r.cuerpo.local as any).lineas.join("|");
    assert.ok(lineas.includes(`Asunto de refresh-${esperado}`), lineas);
    assert.ok(g.llamadas.every((l) => !l.auth.includes("refresh-ana") || esperado === "ana"));
    const c = await llamar({ accion: "herramienta", herramienta: "calendario.ver" });
    assert.ok((c.cuerpo.local as any).lineas.join("|").includes(`Evento de refresh-${esperado}`));
  }
});

test("la cuidadora no usa Gmail ni Calendar; Casa no usa Gmail ni escribe", async () => {
  const dian = await montar({ rol: "diana", cuentas: ["ana", "casa"] });
  for (const herramienta of ["gmail.leer", "gmail.redactar", "calendario.ver", "calendario.crear"]) {
    const r = await dian.llamar({ accion: "herramienta", herramienta, parametros: redactar });
    assert.equal(r.estado, 403, herramienta);
  }
  const casa = await montar({ rol: "casa", cuentas: ["ana", "casa"] });
  for (const herramienta of ["gmail.leer", "gmail.redactar", "gmail.enviar", "calendario.crear"]) {
    const r = await casa.llamar({ accion: "herramienta", herramienta, confirmado: true, parametros: { ...redactar, ...evento, borrador_id: "b" } });
    assert.equal(r.estado, 403, herramienta);
  }
  assert.equal(dian.g.llamadas.length + casa.g.llamadas.length, 0);
});

test("Casa ve solo el calendario de la casa, y solo si el dueño lo aprobó", async () => {
  const sin = await montar({ rol: "casa", cuentas: ["casa", "ana"], accesoCasa: false });
  const r0 = await sin.llamar({ accion: "herramienta", herramienta: "calendario.ver" });
  assert.equal(r0.estado, 403);
  assert.equal(r0.cuerpo.error, "casa_sin_aprobacion");
  assert.equal(sin.g.llamadas.length, 0);

  const con = await montar({ rol: "casa", cuentas: ["casa", "ana"], accesoCasa: true });
  const r = await con.llamar({ accion: "herramienta", herramienta: "calendario.ver", parametros: { persona_id: "p-ana" } });
  assert.equal(r.estado, 200);
  assert.ok((r.cuerpo.local as any).lineas.join("|").includes("Evento de refresh-casa"));
  assert.ok(con.g.llamadas.every((l) => !l.auth.includes("refresh-ana")));
});

// --- Confirmación explícita -------------------------------------------------------------------------------------

test("redactar solo crea un borrador; enviar exige confirmación", async () => {
  const { llamar, g } = await montar({ cuentas: ["ana"] });
  const r = await llamar({ accion: "herramienta", herramienta: "gmail.redactar", parametros: redactar });
  assert.equal(r.estado, 200);
  assert.equal(r.cuerpo.requiere_confirmacion, true);
  const conf = r.cuerpo.confirmacion as any;
  assert.equal(conf.herramienta, "gmail.enviar");
  assert.equal(g.llamadas.some((l) => l.url.endsWith("/drafts/send")), false, "no se envió");

  for (const confirmado of [undefined, false, "true", 1]) {
    const x = await llamar({ accion: "herramienta", herramienta: "gmail.enviar", parametros: conf.parametros, confirmado });
    assert.equal(x.estado, 409);
    assert.equal(x.cuerpo.error, "confirmacion_requerida");
  }
  assert.equal(g.llamadas.some((l) => l.url.endsWith("/drafts/send")), false, "sigue sin enviarse");

  const ok = await llamar({ accion: "herramienta", herramienta: "gmail.enviar", parametros: conf.parametros, confirmado: true });
  assert.equal(ok.estado, 200);
  assert.equal(g.llamadas.filter((l) => l.url.endsWith("/drafts/send")).length, 1);
});

test("crear un evento solo muestra la vista previa hasta que la app confirma", async () => {
  const { llamar, g } = await montar({ cuentas: ["ana"] });
  const r = await llamar({ accion: "herramienta", herramienta: "calendario.crear", parametros: evento });
  assert.equal(r.cuerpo.requiere_confirmacion, true);
  assert.equal(escribio(g), false);
  assert.equal(g.llamadas.length, 0, "ni siquiera consulta a Google");
  const conf = r.cuerpo.confirmacion as any;
  const ok = await llamar({ accion: "herramienta", herramienta: "calendario.crear", parametros: conf.parametros, confirmado: true });
  assert.equal(ok.estado, 200);
  assert.equal(g.llamadas.filter((l) => l.metodo === "POST" && l.url.includes("/events")).length, 1);
});

test("parámetros inválidos se rechazan antes de llamar a Google", async () => {
  const { llamar, g } = await montar({ cuentas: ["ana"] });
  const malos: Array<[string, Record<string, unknown>]> = [
    ["gmail.redactar", { ...redactar, para: "no es correo" }],
    ["gmail.redactar", { ...redactar, asunto: "Hola\r\nBcc: otro@x.test" }],
    ["gmail.redactar", { ...redactar, cuerpo: "" }],
    ["gmail.enviar", { borrador_id: "../x" }],
    ["calendario.crear", { ...evento, fin: evento.inicio }],
    ["calendario.crear", { ...evento, inicio: "mañana" }],
    ["calendario.ver", { dias: 400 }],
  ];
  for (const [herramienta, parametros] of malos) {
    const r = await llamar({ accion: "herramienta", herramienta, parametros, confirmado: true });
    assert.equal(r.estado, 400, herramienta + JSON.stringify(parametros));
  }
  assert.equal(g.llamadas.length, 0);
  assert.throws(() => armarMime({ ...redactar, asunto: "a\nBcc: x@x.test" }));
});

// --- D3: el contenido no llega al modelo -----------------------------------------------------------------------

test("D3: el modelo solo ve nombres genéricos y el contenido de Google no vuelve a él", async () => {
  const { llamar, vistos, g, bitacora } = await montar({ cuentas: ["ana"] });
  // 1. El modelo elige la herramienta (solo el nombre) …
  const r = await llamar({ mensaje: "revisa mi correo" });
  assert.equal(r.estado, 200);
  assert.equal(r.cuerpo.herramienta, "gmail.leer");
  // … 2. la app la ejecuta contra el servidor y recibe el contenido …
  const leido = await llamar({ accion: "herramienta", herramienta: "gmail.leer" });
  assert.ok(JSON.stringify(leido.cuerpo).includes("12,500"));
  assert.ok(g.llamadas.length > 0);
  // … 3. y nada de eso aparece en lo que el modelo recibió, ni en la respuesta de la conversación, ni en la bitácora.
  const todo = JSON.stringify(vistos);
  assert.ok(!todo.includes("12,500") && !todo.includes("500 mg") && !todo.includes("Asunto de"));
  assert.ok(!JSON.stringify(r.cuerpo).includes("Asunto de"));
  assert.ok(!JSON.stringify(bitacora).includes("12,500") && !JSON.stringify(bitacora).includes("Asunto"));
  const herr = vistos[0].herramientas.map((h) => h.nombre);
  assert.ok(herr.includes("gmail.leer") && herr.includes("calendario.crear"));
  assert.ok(!herr.includes("gmail.enviar"), "enviar es interna: el modelo no la elige");
});

test("el catálogo de Google es genérico y por rol", async () => {
  for (const h of CATALOGO_GOOGLE) {
    assert.deepEqual(h.roles, ["dueno", "coadministrador", "familiar"], h.nombre);
    assert.doesNotMatch(h.descripcion, /\d/, h.nombre);
  }
  const { vistos, llamar } = await montar({ rol: "carla", cuentas: [] });
  await llamar({ mensaje: "hola" });
  assert.ok(vistos[0].herramientas.some((h) => h.nombre === "calendario.ver"));
  // Cuidadora y Casa no conversan: ni siquiera llega al modelo.
  const dian = await montar({ rol: "diana" });
  assert.equal((await dian.llamar({ mensaje: "hola" })).estado, 403);
  assert.equal(dian.vistos.length, 0);
});

test("sin sesión no hay Google", async () => {
  const { llamar, d } = await montar({ cuentas: ["ana"] });
  d.identidad = async () => null;
  const r = await llamar({ accion: "herramienta", herramienta: "gmail.leer" });
  assert.equal(r.estado, 401);
});

test("la bitácora guarda quién y qué herramienta, nunca el contenido", async () => {
  const { llamar, bitacora } = await montar({ cuentas: ["ana"] });
  await llamar({ accion: "herramienta", herramienta: "gmail.redactar", parametros: redactar });
  await llamar({ accion: "herramienta", herramienta: "calendario.ver" });
  assert.equal(bitacora.length, 2);
  assert.deepEqual(bitacora.map((b) => b.detalle.herramienta), ["gmail.redactar", "calendario.ver"]);
  const t = JSON.stringify(bitacora);
  assert.ok(!t.includes("luis@ejemplo") && !t.includes("Nos vemos") && !t.includes("Hola"));
});

// --- Conectar la cuenta -----------------------------------------------------------------------------------------

test("conectar: el token de renovación se guarda cifrado y ligado a la persona", async () => {
  const { llamar, guardadas } = await montar({ rol: "alex" });
  const u = await llamar({ accion: "google_url", ambito: "personal" });
  const url = new URL(String(u.cuerpo.url));
  assert.equal(url.searchParams.get("access_type"), "offline");
  assert.equal(url.searchParams.get("client_id"), CFG.clientId);
  assert.ok(!url.search.includes(CFG.clientSecret));
  const estado = url.searchParams.get("state")!;
  const r = await llamar({ accion: "google_codigo", codigo: "codigo-bueno", estado });
  assert.equal(r.estado, 200);
  assert.equal(guardadas.length, 1);
  assert.equal(guardadas[0].personaId, "p-alex");
  assert.ok(!guardadas[0].tokenCifrado.includes("refresh-nuevo"));
  assert.equal(await descifrar(guardadas[0].tokenCifrado, CLAVE, "p-alex:personal"), "refresh-nuevo");
  assert.equal(guardadas[0].accesoCasa, false);
});

test("conectar: un estado ajeno o sin permiso de renovación se rechaza", async () => {
  const ana = await montar({ rol: "ana" });
  const estadoAna = new URL(String((await ana.llamar({ accion: "google_url" })).cuerpo.url)).searchParams.get("state")!;
  const alex = await montar({ rol: "alex" });
  const r = await alex.llamar({ accion: "google_codigo", codigo: "c", estado: estadoAna });
  assert.equal(r.estado, 400);
  assert.equal(alex.guardadas.length, 0);
  const sin = await ana.llamar({ accion: "google_codigo", codigo: "sin-refresh", estado: estadoAna });
  assert.equal(sin.cuerpo.error, "sin_renovacion");
  assert.equal(ana.guardadas.length, 0);
});

test("conectar la cuenta de la casa solo lo hace el dueño; cuidadora y Casa no conectan", async () => {
  assert.equal((await (await montar({ rol: "alex" })).llamar({ accion: "google_url", ambito: "casa" })).estado, 403);
  assert.equal((await (await montar({ rol: "diana" })).llamar({ accion: "google_url" })).estado, 403);
  assert.equal((await (await montar({ rol: "casa" })).llamar({ accion: "google_url" })).estado, 403);
  const ana = await montar({ rol: "ana" });
  const u = await ana.llamar({ accion: "google_url", ambito: "casa" });
  const url = new URL(String(u.cuerpo.url));
  assert.ok(!url.searchParams.get("scope")!.includes("gmail"), "la cuenta de la casa no pide Gmail");
  assert.ok(url.searchParams.get("scope")!.includes("calendar.events.readonly"));
  const r = await ana.llamar({ accion: "google_codigo", codigo: "c", estado: url.searchParams.get("state") });
  assert.equal(r.estado, 200);
  assert.equal(ana.guardadas[0].ambito, "casa");
  assert.equal(ana.guardadas[0].accesoCasa, false, "Casa no ve nada hasta que el dueño apruebe");
});
