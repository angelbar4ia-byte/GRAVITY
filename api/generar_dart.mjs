// Genera, a partir de api/openapi.yaml:
//   - app/lib/modulos/ajustes/desarrollador/operaciones.g.dart (Ajustes › Desarrollador)
//   - api/swagger/especificacion.js (la especificación para abrir Swagger UI con doble clic)
//
// Uso (desde api/):
//   npm run generar     escribe los dos archivos
//   npm run verificar   solo comprueba que estén al día (sale con 1 si no)
//
// Ambos archivos llevan la huella FNV-1a de 32 bits de openapi.yaml (con los saltos de
// línea normalizados). La prueba de Flutter
// app/test/modulos/ajustes/desarrollador/operaciones_generadas_test.dart falla si no
// coincide.

import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parse } from 'yaml';

const raiz = dirname(fileURLToPath(import.meta.url));
const rutaYaml = join(raiz, 'openapi.yaml');
const rutaDart = join(raiz, '..', 'app', 'lib', 'modulos', 'ajustes', 'desarrollador', 'operaciones.g.dart');
const rutaJs = join(raiz, 'swagger', 'especificacion.js');

const ROLES = ['dueno', 'coadministrador', 'familiar', 'cuidador', 'casa'];
const METODOS = ['get', 'post', 'put', 'patch', 'delete'];
const SEGUN_HERRAMIENTA = 'segun-herramienta';

/** Huella FNV-1a de 32 bits del texto en UTF-8, con saltos de línea \n. */
export function huella(texto) {
  const bytes = Buffer.from(texto.replace(/\r\n/g, '\n'), 'utf8');
  let h = 0x811c9dc5;
  for (const b of bytes) {
    h ^= b;
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return `fnv1a32:${h.toString(16).padStart(8, '0')}`;
}

function fallar(mensaje) {
  console.error(`Error en openapi.yaml: ${mensaje}`);
  process.exit(1);
}

/** true, false o null ("según la herramienta"). */
function marca(valor, donde, nombre) {
  if (valor === true || valor === false) return valor;
  if (valor === SEGUN_HERRAMIENTA) return null;
  fallar(`${donde}: ${nombre} debe ser true, false o ${SEGUN_HERRAMIENTA}`);
}

/** Lee las operaciones agrupadas por la primera etiqueta, en el orden de `tags`. */
export function leerGrupos(doc) {
  if (!String(doc.openapi ?? '').startsWith('3.1')) fallar('se espera OpenAPI 3.1');
  const etiquetas = doc.tags ?? [];
  const grupos = etiquetas.map((t) => ({
    nombre: t.name,
    descripcion: String(t.description ?? '').trim(),
    operaciones: [],
  }));
  const porNombre = new Map(grupos.map((g) => [g.nombre, g]));
  const ids = new Set();

  for (const [ruta, item] of Object.entries(doc.paths ?? {})) {
    for (const metodo of METODOS) {
      const op = item[metodo];
      if (!op) continue;
      const donde = `${metodo.toUpperCase()} ${ruta}`;
      const etiqueta = op.tags?.[0];
      const grupo = porNombre.get(etiqueta);
      if (!grupo) fallar(`${donde}: su primera etiqueta debe estar en tags`);
      if (!op.operationId) fallar(`${donde}: falta operationId`);
      if (ids.has(op.operationId)) fallar(`${donde}: operationId repetido`);
      ids.add(op.operationId);
      const roles = op['x-roles'];
      if (!Array.isArray(roles) || roles.length === 0) fallar(`${donde}: falta x-roles`);
      for (const r of roles) {
        if (!ROLES.includes(r)) fallar(`${donde}: rol desconocido "${r}"`);
      }
      const fase = op['x-fase'];
      if (!Number.isInteger(fase) || fase < 0) fallar(`${donde}: x-fase debe ser un entero`);
      grupo.operaciones.push({
        id: op.operationId,
        metodo,
        ruta,
        resumen: String(op.summary ?? '').trim(),
        descripcion: String(op.description ?? '').trim().replace(/\s+/g, ' '),
        roles: ROLES.filter((r) => roles.includes(r)),
        escribe: marca(op['x-escribe'], donde, 'x-escribe'),
        soloLocal: marca(op['x-solo-local'], donde, 'x-solo-local'),
        fase,
      });
    }
  }
  return grupos;
}

/** Literal de texto de Dart entre comillas simples. */
function textoDart(s) {
  return `'${s
    .replace(/\\/g, '\\\\')
    .replace(/'/g, "\\'")
    .replace(/\$/g, '\\$')
    .replace(/\n/g, '\\n')}'`;
}

function marcaDart(v) {
  return v === null ? 'null' : String(v);
}

export function generarDart(doc, huellaYaml) {
  const grupos = leerGrupos(doc);
  const l = [];
  l.push('// GENERADO por api/generar_dart.mjs a partir de api/openapi.yaml.');
  l.push('// No se edita a mano: cambia openapi.yaml y corre `npm run generar` en api/.');
  l.push('');
  l.push("import '../../../nucleo/contratos/roles.dart';");
  l.push("import 'operacion_api.dart';");
  l.push('');
  l.push('/// Huella de api/openapi.yaml con la que se generó este archivo.');
  l.push(`const huellaEspecificacion = ${textoDart(huellaYaml)};`);
  l.push('');
  l.push('/// Versión de la especificación (info.version).');
  l.push(`const versionEspecificacion = ${textoDart(String(doc.info?.version ?? ''))};`);
  l.push('');
  l.push('/// Operaciones de la especificación, por grupo.');
  l.push('const gruposOperaciones = <GrupoOperaciones>[');
  for (const g of grupos) {
    l.push('  GrupoOperaciones(');
    l.push(`    nombre: ${textoDart(g.nombre)},`);
    l.push(`    descripcion: ${textoDart(g.descripcion.replace(/\s+/g, ' '))},`);
    l.push('    operaciones: [');
    for (const o of g.operaciones) {
      l.push('      OperacionApi(');
      l.push(`        id: ${textoDart(o.id)},`);
      l.push(`        metodo: MetodoHttp.${o.metodo},`);
      l.push(`        ruta: ${textoDart(o.ruta)},`);
      l.push(`        resumen: ${textoDart(o.resumen)},`);
      l.push(`        descripcion: ${textoDart(o.descripcion)},`);
      l.push(`        roles: {${o.roles.map((r) => `Rol.${r}`).join(', ')}},`);
      l.push(`        escribe: ${marcaDart(o.escribe)},`);
      l.push(`        soloLocal: ${marcaDart(o.soloLocal)},`);
      l.push(`        fase: ${o.fase},`);
      l.push('      ),');
    }
    l.push('    ],');
    l.push('  ),');
  }
  l.push('];');
  l.push('');
  return l.join('\n');
}

export function generarJs(doc, huellaYaml) {
  return [
    '// GENERADO por api/generar_dart.mjs a partir de api/openapi.yaml. No se edita a mano.',
    '// Permite abrir Swagger UI con doble clic (file://), donde el navegador no deja leer',
    '// ../openapi.yaml. Servida por http, la página lee openapi.yaml directamente.',
    `// huella: ${huellaYaml}`,
    `window.ESPECIFICACION_GRAVITY = ${JSON.stringify(doc, null, 2)};`,
    `window.HUELLA_ESPECIFICACION_GRAVITY = '${huellaYaml}';`,
    '',
  ].join('\n');
}

function huellaEn(ruta) {
  if (!existsSync(ruta)) return null;
  return readFileSync(ruta, 'utf8').match(/fnv1a32:[0-9a-f]{8}/)?.[0] ?? null;
}

function formatearDart(ruta) {
  const r = spawnSync('dart', ['format', ruta], {
    stdio: 'inherit',
    shell: process.platform === 'win32',
  });
  if (r.status !== 0) {
    console.warn('Aviso: no se pudo correr `dart format`; el archivo queda sin formato.');
  }
}

function principal() {
  const texto = readFileSync(rutaYaml, 'utf8');
  const doc = parse(texto);
  const h = huella(texto);
  const grupos = leerGrupos(doc);

  if (process.argv.includes('--verificar')) {
    const atrasados = [rutaDart, rutaJs].filter((r) => huellaEn(r) !== h);
    if (atrasados.length > 0) {
      for (const r of atrasados) console.error(`Desactualizado: ${relative(raiz, r)}`);
      console.error('Corre `npm run generar` en api/.');
      process.exit(1);
    }
    console.log(`Al día (${h}).`);
    return;
  }

  writeFileSync(rutaDart, generarDart(doc, h));
  formatearDart(rutaDart);
  writeFileSync(rutaJs, generarJs(doc, h));
  const total = grupos.reduce((n, g) => n + g.operaciones.length, 0);
  console.log(`Generado (${h}): ${total} operaciones en ${grupos.length} grupos.`);
  console.log(`  ${relative(raiz, rutaDart)}`);
  console.log(`  ${relative(raiz, rutaJs)}`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) principal();
