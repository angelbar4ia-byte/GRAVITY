# Fase 4 · Alimentación (versión mínima): menú de la semana y lista de compras

Agente: alimentacion. Origen: `docs/specs/fase-4-pulido.md`, sección 15 (P9). Diseño de fondo: `docs/modulos/finanzas/ESTRUCTURA_APP_PRESUPUESTO_SEMANAL.md`, sección 6.

## 1. Alcance

**Entra (mínimo útil, con datos de ejemplo inventados):**

1. Menú de la semana: 7 días (lunes a domingo) por 3 tiempos (desayuno, comida, cena), con platillos tomados de un catálogo de ejemplo. Editable: asignar, cambiar y quitar un platillo.
2. Lista de compras generada desde el menú: ingredientes sumados, agrupados por sección del súper, con marca de "comprado". Sin precios.
3. Permisos: dueño y coadministrador (la pareja) leen y editan; familiar, cuidador y cuenta Casa solo leen (matriz de permisos de `nucleo/permisos`, D5; en el servidor, RLS).
4. Sin dinero, sin datos clínicos, sin IA, sin red.

**Queda para la Fase 7:** recetas paso a paso, catálogo propio y base con precios, costeo y monto semanal, historial de precios, asistente de menús, inventario, porciones por persona, lector de código de barras, entrega del plan a Hábitos y Cuidados, filtros por alergia o dieta.

## 2. Convenciones

Las de la Fase 0, sección 4: semana que inicia en lunes (fecha `AAAA-MM-DD` del lunes), UUID para ids en el servidor, español sin acentos en identificadores, nada de colores ni medidas fijas (todo sale de `ValoresDiseno`), `Modulo.alimentacion` con personalidad cálida y práctica. Letra grande para cocinar: objetivos táctiles de 48 dp o más.

## 3. Modelo

- `Platillo`: id, nombre, lista de `Ingrediente`.
- `Ingrediente`: nombre, cantidad (número), unidad (`pza`, `g`, `ml`, `lata`...), sección.
- `SeccionCompra`: frutas y verduras, carnes y pescados, lácteos y huevo, abarrotes, panadería y tortillería, otros.
- `EntradaMenu`: semana (lunes), día (0 = lunes ... 6 = domingo), tiempo, platillo. Una por celda.
- Lista de compras (derivada, no se guarda): suma de ingredientes de las entradas de la semana, uniendo por nombre y unidad, ordenada por sección y nombre. Lo único que se guarda es el conjunto de "comprados" de la semana, por clave `nombre|unidad`.
- Si el menú cambia, un ingrediente comprado que sigue en la lista sigue marcado; uno que ya no está se ignora.

## 4. Permisos

- Leer: todo rol con acceso al módulo.
- Escribir (menú y marcas de compra): `puede(rol, Modulo.alimentacion, Accion.escribir)`. Hoy son dueño y coadministrador.
- La cuenta maestra (D19) es solo lectura: no edita.
- La interfaz oculta los controles de edición para quien solo lee y el servicio rechaza la escritura aunque se llame (defensa en profundidad). La verdad está en el servidor.
- Nota del familiar: la matriz dice "Leer su parte". En esta versión mínima el menú del hogar es uno solo y el familiar lo ve completo; ver P2.

## 5. Criterios de aceptación

1. El menú muestra 7 días por 3 tiempos, de lunes a domingo, con los platillos de ejemplo; las celdas vacías dicen "Sin platillo".
2. Quien puede editar asigna, cambia y quita un platillo en una celda; el cambio se ve de inmediato y se puede deshacer en el aviso.
3. Un lector (familiar, cuidador, Casa o cuenta maestra) ve el menú sin ningún control de edición y su intento de escribir por el servicio falla con `PermisoDenegado`.
4. La lista de compras suma las cantidades del mismo ingrediente y unidad (dos platillos con 2 jitomates dan 4), no mezcla unidades distintas y agrupa por sección con encabezados.
5. Un menú vacío da una lista vacía con mensaje que explica cómo llenarla.
6. Marcar "comprado" tacha el renglón y además lo indica con texto o icono (no solo color); se puede desmarcar; el avance dice "X de Y comprados".
7. Cambiar el menú recalcula la lista y conserva las marcas de lo que sigue en ella.
8. Nada de la lista ni del menú lleva precios, montos ni datos de salud, y el módulo no importa nada de IA ni de red (prueba de guardia sobre el código fuente).
9. La semana arranca en lunes; navegar a la semana anterior y siguiente conserva cada menú por separado.
10. Los datos de ejemplo son inventados y ninguna prueba abre `data/personal/`.
11. Con letra a 2.0 en 360 dp no hay desbordes en menú ni en lista.
12. `flutter analyze` sin avisos y `flutter test --exclude-tags hallazgo` en verde.

## 6. Contrato para backend (cuando se pase del repositorio en memoria al servidor)

Hoy no hay tablas de Alimentación; la app usa `RepositorioAlimentacionEnMemoria` (datos de ejemplo) detrás de la interfaz `RepositorioAlimentacion`. Se pide:

```
ali_platillos(id uuid pk, hogar_id uuid, nombre text, ingredientes jsonb, creado_en timestamptz)
  ingredientes: [{nombre, cantidad numeric, unidad text, seccion text}]
ali_menu(id uuid pk, hogar_id uuid, semana date check (extract(isodow from semana)=1),
         dia smallint check (dia between 0 and 6), tiempo text check (tiempo in ('desayuno','comida','cena')),
         platillo_id uuid references ali_platillos, actualizado_por uuid, actualizado_en timestamptz,
         unique (hogar_id, semana, dia, tiempo))
ali_compras_marcas(hogar_id uuid, semana date, clave text, marcado_por uuid, marcado_en timestamptz,
         primary key (hogar_id, semana, clave))   -- fila presente = comprado; borrar = desmarcar
```

RLS: leer si `tiene_permiso(auth.uid(), 'alimentacion', 'leer')` en el hogar; insertar, actualizar y borrar si el permiso es `escribir` y la cuenta no es solo maestra. La matriz `permisos_rol` ya tiene las filas de `alimentacion`. Sin columnas de precio, de salud ni de dinero. Si se prefiere un RPC: `ali_asignar(semana, dia, tiempo, platillo_id|null)` y `ali_marcar(semana, clave, marcado)`.

## 7. Conexión en la app (pide al arquitecto)

En `app/lib/app/pantallas_externas.dart` agregar `List<RouteBase> rutasAlimentacion() => alimentacion.rutasAlimentacion();` y montarlo en `router.dart` en lugar de `_modulo(Rutas.alimentacion, Modulo.alimentacion)`, con el patrón de `montarRutasDeModulo`. Rutas relativas a `/alimentacion`: raíz = menú, `compras` = lista de compras.

## 8. Preguntas al dueño (con propuesta)

| # | Pregunta | Propuesta |
|---|---|---|
| P1 | ¿Tiempos de comida: solo desayuno, comida y cena? El Excel usa cuatro (almuerzo, comida, merienda, cena) | Tres ahora; la merienda como cuarto tiempo en la Fase 7 si la usan |
| P2 | ¿El familiar ve el menú completo o solo "su parte"? | Completo (es un menú del hogar); "su parte" llega con porciones por persona en la Fase 7 |
| P3 | ¿Quién marca "comprado": solo quien edita, o también un lector que va al súper? | Solo quien edita; si un familiar hace las compras se le da el permiso de escribir en Alimentación |
| P4 | ¿Un menú por hogar o uno por persona? | Uno por hogar |
| P5 | ¿Los platillos de ejemplo se quedan como catálogo base? | Sí, como punto de partida editable en la Fase 7; hoy son inventados |

---

## Respuestas del dueño (6/nov/2026) — v0.2

| # | Pregunta | Respuesta |
|---|---|---|
| 1 | Tiempos de comida | **Cuatro**, como en el Excel (desayuno, comida, cena y colación/merienda) |
| 2 | Qué ve el familiar | **Solo el menú de Papá**, igual que la cuidadora |
| 3 | Quién marca "comprado" | **El dueño y su pareja** |
| 4 | Cuántos menús | **Dos**: el **menú de Papá** (en el hogar) y el **menú de la pareja y del dueño** |
| 5 | Perfil de Papá | Adulto de 80 años con Alzheimer. **Dieta alta en proteínas y aminoácidos. No puede comer alimentos duros; de preferencia blandos.** |
| - | Suplementos | Se contemplan en **ambos menús** |

### Reglas nuevas

1. **Dos menús por hogar.** Cada menú tiene su perfil. El menú de Papá usa el perfil "Adulto mayor con Alzheimer": alta en proteínas y aminoácidos, textura blanda; los platillos con alimentos duros se advierten al elegirlos.
2. **Permisos:**
   - Dueño y pareja: ven y editan los dos menús y marcan "comprado".
   - Cuidador y familiar: solo ven el menú de Papá (solo lectura). Cuidador: también la lista de compras de Papá.
   - Cuenta maestra: no edita (D19).
3. **Suplementos:** cada menú tiene su lista de suplementos (nombre, dosis y horario de ejemplo), editable por el dueño y la pareja.
4. **Datos clínicos (D3):** el perfil de Papá (Alzheimer, dieta) es **dato clínico**: no sale a la IA ni a las bocinas, y solo lo ven las personas con permiso.
5. **Sin precios**, como antes.

Pendiente de confirmar por el dueño: si el familiar debe ver también la lista de compras de Papá (propuesta: no; solo el menú).

