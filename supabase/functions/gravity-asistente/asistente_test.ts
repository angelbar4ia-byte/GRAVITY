// Pruebas sin red del adaptador y del filtro de contexto (D3). Corren con Deno (`deno test`) o con
// Node 22+: node --experimental-strip-types --test supabase/functions/gravity-asistente/asistente_test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { responder, type Dependencias, type FilaBitacora } from "./asistente.ts";
import { armarContexto, ContextoSensibleError, herramientasParaRol, redactar, tieneDatoSensible, verificarContextoLimpio, type ContextoIa } from "./contexto.ts";
import { chatgpt, claude, crearProveedor, ErrorProveedor, gemini, type ProveedorIa } from "./proveedores.ts";

const catalogo = JSON.parse(readFileSync(new URL("./catalogo.json", import.meta.url), "utf8")).herramientas;
const SESION = "11111111-1111-4111-8111-111111111111";
const PERSONA = "22222222-2222-4222-8222-222222222222";

/** Proveedor falso: guarda todo lo que recibe y responde lo que se le indique. */
function falso(respuesta = { texto: "Hola", herramienta: null as string | null }) {
  const vistos: Array<{ contexto: ContextoIa; clave: string }> = [];
  const p: ProveedorIa = {
    id: "falso",
    async generar(contexto, clave) {
      vistos.push({ contexto, clave });
      return respuesta;
    },
  };
  return { p, vistos };
}

function deps(rol: string, extra: Partial<Dependencias> = {}) {
  const filas: FilaBitacora[] = [];
  const f = falso();
  const d: Dependencias = {
    catalogo,
    proveedor: f.p,
    clave: "clave-de-prueba",
    limiteDiario: 30,
    identidad: async () => ({ personaId: PERSONA, hogarId: "h", rol }),
    usoHoy: async () => 0,
    bitacora: async (fila) => void filas.push(fila),
    ...extra,
  };
  return { d, filas, vistos: f.vistos };
}

const pide = (mensaje: string, extra: Record<string, unknown> = {}) => ({ mensaje, sesion: SESION, ...extra });

// --- Filtro de contexto -----------------------------------------------------------------------

test("el catálogo y sus descripciones no contienen montos ni datos de salud", () => {
  for (const h of catalogo) {
    assert.equal(tieneDatoSensible(h.nombre + " " + h.descripcion), false, h.nombre);
    assert.ok(["finanzas", "habitos", "cuidados", "alimentacion"].includes(h.modulo), `${h.nombre}: módulo fuera de la lista`);
  }
});

test("el contexto nunca contiene montos ni datos de salud", () => {
  const sucios = [
    "Gasté $1,200.50 en el súper",
    "pagué 3 mil pesos de renta",
    "tengo 500 pesos",
    "MXN 800 de ahorro",
    "mi papá toma 500 mg de metformina",
    "su presión es 140/90",
    "azúcar 180 mg/dL",
  ];
  for (const frase of sucios) {
    assert.equal(tieneDatoSensible(frase), true, `debía detectar: ${frase}`);
    const c = armarContexto({
      catalogo,
      rol: "dueno",
      mensaje: frase,
      historial: [{ de: "persona", texto: frase }, { de: "asistente", texto: frase }],
    });
    const todo = JSON.stringify(c);
    assert.equal(tieneDatoSensible(todo), false, `se coló: ${frase}`);
    assert.equal(tieneDatoSensible(c.mensaje), false);
  }
  assert.match(redactar("pagué $99 hoy"), /\[dato oculto\]/);
});

test("la fecha y los números sin unidad no se ocultan", () => {
  assert.equal(redactar("la cita es el 25/10 a las 8"), "la cita es el 25/10 a las 8");
});

test("red de seguridad: un contexto con dato sensible no se acepta", () => {
  const malo: ContextoIa = { sistema: "x", historial: [], mensaje: "hola", herramientas: [{ nombre: "finanzas.abrir", descripcion: "Abre. Quedan $1,330" }] };
  assert.throws(() => verificarContextoLimpio(malo), ContextoSensibleError);
});

test("un rol sin acceso a una herramienta no la recibe", () => {
  const nombres = (rol: string) => herramientasParaRol(catalogo, rol).map((h: { nombre: string }) => h.nombre);
  assert.ok(nombres("dueno").includes("finanzas.resumen_semana"));
  assert.equal(nombres("familiar").some((n: string) => n.startsWith("finanzas.")), false);
  assert.equal(nombres("familiar").some((n: string) => n.startsWith("cuidados.")), false);
  assert.deepEqual(nombres("cuidador"), []);
  assert.deepEqual(nombres("casa"), []);
  const c = armarContexto({ catalogo, rol: "familiar", mensaje: "hola" });
  assert.equal(c.herramientas.some((h) => h.nombre.startsWith("finanzas.")), false);
  assert.ok(c.herramientas.some((h) => h.nombre.startsWith("habitos.")));
});

test("ninguna herramienta de otro módulo (alimentación, casa, ajustes) llega al modelo", () => {
  const extra = [...catalogo, { nombre: "ajustes.abrir", modulo: "ajustes", roles: ["dueno"], descripcion: "x" }];
  assert.equal(herramientasParaRol(extra, "dueno").some((h) => h.modulo === "ajustes"), false);
});

// --- Función (con proveedor falso) -------------------------------------------------------------

test("sin clave responde error claro y no llama al proveedor", async () => {
  for (const clave of [undefined, ""]) {
    const { d, vistos, filas } = deps("dueno", { clave });
    const r = await responder(pide("hola"), d);
    assert.equal(r.estado, 503);
    assert.equal(r.cuerpo.error, "sin_clave");
    assert.match(String(r.cuerpo.mensaje), /clave/);
    assert.equal(vistos.length, 0);
    assert.equal(filas.length, 0);
  }
});

test("proveedor desconocido: error y nada sale", async () => {
  const { d } = deps("dueno", { proveedor: crearProveedor("otro", fetch as never) });
  assert.equal((await responder(pide("hola"), d)).cuerpo.error, "proveedor_desconocido");
});

test("cuidador y casa no conversan; sin sesión, 401", async () => {
  for (const rol of ["cuidador", "casa"]) {
    const { d, vistos } = deps(rol);
    assert.equal((await responder(pide("hola"), d)).estado, 403);
    assert.equal(vistos.length, 0);
  }
  const { d, vistos } = deps("dueno", { identidad: async () => null });
  assert.equal((await responder(pide("hola"), d)).estado, 401);
  assert.equal(vistos.length, 0);
});

test("el rol que manda la app se ignora: manda el de la base", async () => {
  const { d, vistos } = deps("familiar");
  await responder(pide("abre finanzas", { rol: "dueno" }), d);
  assert.equal(vistos[0].contexto.herramientas.some((h) => h.nombre.startsWith("finanzas.")), false);
});

test("entrada inválida", async () => {
  const { d } = deps("dueno");
  assert.equal((await responder({ mensaje: "  ", sesion: SESION }, d)).estado, 400);
  assert.equal((await responder({ mensaje: "hola", sesion: "no-es-uuid" }, d)).estado, 400);
  assert.equal((await responder(pide("x".repeat(1001)), d)).estado, 400);
});

test("el proveedor recibe la clave y solo contexto limpio", async () => {
  const { d, vistos } = deps("dueno");
  const r = await responder(pide("cuánto me queda, tengo $5,000"), d);
  assert.equal(r.estado, 200);
  assert.equal(vistos.length, 1);
  assert.equal(vistos[0].clave, "clave-de-prueba");
  assert.equal(tieneDatoSensible(JSON.stringify(vistos[0].contexto)), false);
});

test("la herramienta elegida se devuelve solo si se le ofreció; si no, se descarta", async () => {
  const buena = deps("dueno", { proveedor: falso({ texto: "", herramienta: "finanzas.resumen_semana" }).p });
  const r1 = await responder(pide("cómo voy"), buena.d);
  assert.deepEqual(r1.cuerpo, { respuesta: "Listo.", herramienta: "finanzas.resumen_semana" });

  const mala = deps("familiar", { proveedor: falso({ texto: "ok", herramienta: "finanzas.resumen_semana" }).p });
  const r2 = await responder(pide("cómo voy"), mala.d);
  assert.equal(r2.cuerpo.herramienta, null);
  const inventada = deps("dueno", { proveedor: falso({ texto: "ok", herramienta: "borrar.todo" }).p });
  assert.equal((await responder(pide("hola"), inventada.d)).cuerpo.herramienta, null);
});

test("la bitácora guarda quién, cuándo y herramienta; nunca el texto", async () => {
  const { d, filas } = deps("dueno", { proveedor: falso({ texto: "Respuesta secreta", herramienta: "finanzas.abrir" }).p });
  await responder(pide("mensaje privado de prueba"), d);
  assert.equal(filas.length, 1);
  assert.equal(filas[0].persona_id, PERSONA);
  assert.equal(filas[0].accion, "gravity.asistente");
  assert.equal(filas[0].detalle.herramienta, "finanzas.abrir");
  const texto = JSON.stringify(filas[0]);
  assert.equal(texto.includes("privado"), false);
  assert.equal(texto.includes("secreta"), false);
});

test("límite diario configurable: al llegar, 429 y no se llama al proveedor", async () => {
  const { d, vistos } = deps("dueno", { limiteDiario: 5, usoHoy: async () => 5 });
  const r = await responder(pide("hola"), d);
  assert.equal(r.estado, 429);
  assert.equal(vistos.length, 0);
  const sin = deps("dueno", { limiteDiario: 0, usoHoy: async () => 9999 });
  assert.equal((await responder(pide("hola"), sin.d)).estado, 200);
});

test("si el proveedor falla: 502 sin el detalle y queda en bitácora sin texto", async () => {
  const roto: ProveedorIa = { id: "roto", generar: async () => { throw new ErrorProveedor(500); } };
  const { d, filas } = deps("dueno", { proveedor: roto });
  const r = await responder(pide("hola"), d);
  assert.equal(r.estado, 502);
  assert.equal(filas[0].detalle.resultado, "error_proveedor");
});

// --- Adaptadores (fetch falso) -----------------------------------------------------------------

const contexto = (): ContextoIa => armarContexto({ catalogo, rol: "dueno", mensaje: "abre finanzas" });

function fetchFalso(cuerpo: unknown, status = 200) {
  const llamadas: Array<{ url: string; init: any }> = [];
  const f = (async (url: string, init: any) => {
    llamadas.push({ url, init });
    return new Response(JSON.stringify(cuerpo), { status });
  }) as never;
  return { f, llamadas };
}

test("Gemini: la clave va en un encabezado, no en la URL; entiende la llamada a herramienta", async () => {
  const { f, llamadas } = fetchFalso({ candidates: [{ content: { parts: [{ functionCall: { name: "finanzas__abrir" } }] } }] });
  const r = await gemini(f).generar(contexto(), "K-GEMINI");
  assert.equal(r.herramienta, "finanzas.abrir");
  assert.equal(llamadas[0].init.headers["x-goog-api-key"], "K-GEMINI");
  assert.equal(llamadas[0].url.includes("K-GEMINI"), false);
  const cuerpo = JSON.parse(llamadas[0].init.body);
  assert.ok(cuerpo.tools[0].functionDeclarations.every((x: any) => !x.name.includes(".")));
});

test("Claude y ChatGPT: formato propio y herramienta de vuelta", async () => {
  const a = fetchFalso({ content: [{ type: "text", text: "Abriendo" }, { type: "tool_use", name: "habitos__abrir_hoy" }] });
  const ra = await claude(a.f).generar(contexto(), "K-CLAUDE");
  assert.deepEqual(ra, { texto: "Abriendo", herramienta: "habitos.abrir_hoy" });
  assert.equal(a.llamadas[0].init.headers["x-api-key"], "K-CLAUDE");

  const o = fetchFalso({ choices: [{ message: { content: "", tool_calls: [{ function: { name: "cuidados__abrir" } }] } }] });
  const ro = await chatgpt(o.f).generar(contexto(), "K-GPT");
  assert.equal(ro.herramienta, "cuidados.abrir");
  assert.equal(o.llamadas[0].init.headers.authorization, "Bearer K-GPT");
});

test("un error del proveedor no repite el cuerpo de la respuesta", async () => {
  const { f } = fetchFalso({ error: { message: "eco de $1,200" } }, 429);
  await assert.rejects(() => gemini(f).generar(contexto(), "K"), (e: Error) => e instanceof ErrorProveedor && !e.message.includes("1,200"));
});

test("sin herramientas (rol sin acceso) no se declaran tools al proveedor", async () => {
  const { f, llamadas } = fetchFalso({ candidates: [{ content: { parts: [{ text: "hola" }] } }] });
  await gemini(f).generar(armarContexto({ catalogo, rol: "cuidador", mensaje: "hola" }), "K");
  assert.equal("tools" in JSON.parse(llamadas[0].init.body), false);
});
