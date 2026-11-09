// Pruebas sin red de la acción sugerir_recetas (proveedor falso).
// node --experimental-strip-types --test supabase/functions/gravity-asistente/sugerir_recetas_test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { responder, type Dependencias, type FilaBitacora } from "./asistente.ts";
import type { ContextoIa } from "./contexto.ts";
import type { ProveedorIa } from "./proveedores.ts";

const catalogo = JSON.parse(readFileSync(new URL("./catalogo.json", import.meta.url), "utf8")).herramientas;
const PERSONA = "22222222-2222-4222-8222-222222222222";

const RECETA = { titulo: "Arroz con huevo", porciones: 2, pasos: ["Cuece el arroz.", "Fríe el huevo."], ingredientes: [{ nombre: "Arroz", cantidad: 200, unidad: "g", pasillo: "Granos" }, { nombre: "Huevo", cantidad: 2, unidad: "pza" }] };

function falso(texto: string) {
  const vistos: Array<{ contexto: ContextoIa; clave: string }> = [];
  const p: ProveedorIa = { id: "falso", async generar(contexto, clave) { vistos.push({ contexto, clave }); return { texto, herramienta: null }; } };
  return { p, vistos };
}

function deps(texto: string, extra: Partial<Dependencias> = {}, rol = "dueno") {
  const filas: FilaBitacora[] = [];
  const f = falso(texto);
  const d: Dependencias = {
    catalogo, proveedor: f.p, clave: "clave-de-prueba", limiteDiario: 30,
    identidad: async () => ({ personaId: PERSONA, hogarId: "h", rol }),
    usoHoy: async () => 0,
    bitacora: async (fila) => void filas.push(fila),
    ...extra,
  };
  return { d, filas, vistos: f.vistos };
}

const contexto = (extra: Record<string, unknown> = {}) => ({
  ingredientes: [{ nombre: "Arroz", cantidad_aprox: 500, unidad: "g" }, { nombre: "Huevo", cantidad_aprox: 6, unidad: "pza" }],
  preferencias: "algo rápido, sin picante",
  ...extra,
});
const pide = (c: unknown) => ({ accion: "sugerir_recetas", contexto: c });

test("acepta la petición válida y devuelve las recetas", async () => {
  const { d, vistos, filas } = deps(JSON.stringify({ recetas: [RECETA] }));
  const r = await responder(pide(contexto()), d);
  assert.equal(r.estado, 200);
  assert.deepEqual(r.cuerpo, { recetas: [RECETA] });
  assert.equal(vistos.length, 1);
  assert.equal(vistos[0].clave, "clave-de-prueba");
  assert.equal(filas.length, 1);
  assert.equal(filas[0].detalle.resultado, "ok");
  assert.equal(JSON.stringify(filas).includes("Arroz"), false, "la bitácora no lleva texto");
});

test("tolera que el modelo envuelva el JSON en un bloque de código", async () => {
  const { d } = deps("```json\n" + JSON.stringify({ recetas: [RECETA] }) + "\n```");
  assert.equal((await responder(pide(contexto()), d)).estado, 200);
});

test("campos clínicos o desconocidos se descartan: el contexto enviado no lleva perfil ni alergias", async () => {
  const { d, vistos } = deps(JSON.stringify({ recetas: [RECETA] }));
  const sucio = contexto({
    perfil_clinico: { diagnostico: "diabetes" },
    alergias: ["cacahuate"],
    textura: "puré",
    dieta: "sin sal",
    paciente: "Papá",
  });
  (sucio.ingredientes[0] as Record<string, unknown>).alergia = "gluten";
  const r = await responder(pide(sucio), d);
  assert.equal(r.estado, 200);
  const enviado = JSON.stringify(vistos[0].contexto).toLowerCase();
  for (const palabra of ["diabetes", "cacahuate", "puré", "sin sal", "papá", "perfil", "alergia", "gluten", "textura", "dieta"]) {
    assert.equal(enviado.includes(palabra), false, palabra);
  }
  assert.match(vistos[0].contexto.mensaje, /Arroz: 500 g/);
  assert.match(vistos[0].contexto.mensaje, /sin picante/);
  assert.deepEqual(vistos[0].contexto.herramientas, []);
});

test("el texto libre pasa por el filtro D3: montos ocultos", async () => {
  const { d, vistos } = deps(JSON.stringify({ recetas: [RECETA] }));
  const r = await responder(pide(contexto({ preferencias: "gastar menos de $200 pesos" })), d);
  assert.equal(r.estado, 200);
  assert.equal(vistos[0].contexto.mensaje.includes("$200"), false);
  assert.match(vistos[0].contexto.mensaje, /\[dato oculto\]/);
});

test("valida la forma: límites y tipos", async () => {
  const mal = [
    undefined, "texto", [], {}, { ingredientes: "x" }, { ingredientes: [] },
    contexto({ ingredientes: Array.from({ length: 61 }, () => ({ nombre: "a", cantidad_aprox: 1, unidad: "g" })) }),
    contexto({ preferencias: "x".repeat(301) }),
    contexto({ preferencias: 5 }),
    contexto({ ingredientes: [{ nombre: "", cantidad_aprox: 1, unidad: "g" }] }),
    contexto({ ingredientes: [{ nombre: "a", cantidad_aprox: "mucho", unidad: "g" }] }),
  ];
  for (const m of mal) {
    const { d, vistos } = deps(JSON.stringify({ recetas: [RECETA] }));
    const r = await responder(pide(m), d);
    assert.equal(r.estado, 400, JSON.stringify(m)?.slice(0, 60));
    assert.equal(vistos.length, 0);
  }
  // 60 ingredientes y 300 caracteres exactos sí valen.
  const { d } = deps(JSON.stringify({ recetas: [RECETA] }));
  const ok = contexto({ ingredientes: Array.from({ length: 60 }, () => ({ nombre: "a", cantidad_aprox: 1, unidad: "g" })), preferencias: "x".repeat(300) });
  assert.equal((await responder(pide(ok), d)).estado, 200);
});

test("respuesta mal formada: error claro, sin receta inventada", async () => {
  const malas = [
    "Claro, aquí tienes una receta de arroz", "{", JSON.stringify({ recetas: [] }), JSON.stringify({ otra: 1 }),
    JSON.stringify({ recetas: [{ ...RECETA, pasos: [] }] }),
    JSON.stringify({ recetas: [{ ...RECETA, porciones: "dos" }] }),
    JSON.stringify({ recetas: [{ ...RECETA, ingredientes: [{ nombre: "Arroz", cantidad: -1, unidad: "g" }] }] }),
    JSON.stringify({ recetas: [{ titulo: "x" }] }),
  ];
  for (const m of malas) {
    const { d, filas } = deps(m);
    const r = await responder(pide(contexto()), d);
    assert.equal(r.estado, 502);
    assert.equal(r.cuerpo.error, "respuesta_invalida");
    assert.equal("recetas" in r.cuerpo, false);
    assert.equal(filas[0].detalle.resultado, "respuesta_invalida");
  }
});

test("sin clave: 503 y no se llama al proveedor", async () => {
  const { d, vistos } = deps("{}", { clave: undefined });
  const r = await responder(pide(contexto()), d);
  assert.equal(r.estado, 503);
  assert.equal(r.cuerpo.error, "sin_clave");
  assert.equal(vistos.length, 0);
});

test("sin sesión 401, cuidador 403, límite diario 429; el proveedor no se llama", async () => {
  const a = deps("{}", { identidad: async () => null });
  assert.equal((await responder(pide(contexto()), a.d)).estado, 401);
  const b = deps("{}", {}, "cuidador");
  assert.equal((await responder(pide(contexto()), b.d)).estado, 403);
  const c = deps("{}", { usoHoy: async () => 30 });
  assert.equal((await responder(pide(contexto()), c.d)).estado, 429);
  assert.equal(a.vistos.length + b.vistos.length + c.vistos.length, 0);
});

test("si el proveedor falla: 502 sin detalle", async () => {
  const p: ProveedorIa = { id: "falso", async generar() { throw new Error("secreto: $500"); } };
  const { d } = deps("{}", { proveedor: p });
  const r = await responder(pide(contexto()), d);
  assert.equal(r.estado, 502);
  assert.equal(JSON.stringify(r.cuerpo).includes("secreto"), false);
});
