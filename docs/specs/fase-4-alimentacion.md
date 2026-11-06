# Fase 4 · Alimentación (versión mínima): dos menús de la semana y lista de compras

Agente: alimentacion. Origen: `docs/specs/fase-4-pulido.md`, sección 15 (P9). Diseño de fondo: `docs/modulos/finanzas/ESTRUCTURA_APP_PRESUPUESTO_SEMANAL.md`, sección 6. Decisión: D23. **Versión 0.3:** incorpora las respuestas y el ajuste del dueño (al final de este documento); manda lo de esta parte, ya actualizada.

## 1. Alcance

**Entra (datos de ejemplo inventados):**

1. **Dos menús por hogar:** "Menú de Papá" y "Menú de la pareja y del dueño". Cada uno: 7 días (lunes a domingo) por 4 tiempos (desayuno, comida, cena y colación), con platillos de un catálogo de ejemplo, editable.
2. **Perfil por menú.** El de Papá es "Adulto mayor con Alzheimer" (80 años, alta en proteínas y aminoácidos, textura blanda): al elegir un platillo con alimentos duros se advierte y se pide confirmar.
3. **Suplementos** en ambos menús: nombre, dosis y horario de ejemplo, editables.
4. **Lista de compras** por menú, generada desde el menú, agrupada por sección, con "comprado". Sin precios.
5. Sin dinero, sin IA, sin red. El perfil de Papá es dato clínico (D3).

**Queda para la Fase 7:** recetas paso a paso, catálogo propio y base con precios, costeo y monto semanal, historial de precios, asistente de menús, inventario, porciones por persona, entrega del plan a Hábitos y Cuidados, lector de código de barras.

## 2. Convenciones

Las de la Fase 0, sección 4: semana en lunes, UUID, identificadores en español sin acentos, nada de colores ni medidas fijas (todo de `ValoresDiseno`), personalidad cálida y práctica, objetivos táctiles de 48 dp o más.

## 3. Modelo

- `MenuId`: `papa`, `pareja`. `TiempoComida`: desayuno, comida, cena, colacion.
- `Platillo`: id, nombre, ingredientes, `duros` (alimentos duros o crudos, para advertir en el menú de Papá). `Ingrediente`: nombre, cantidad, unidad, sección.
- `EntradaMenu`: (menú, semana-lunes, día 0 a 6, tiempo, platillo).
- `Suplemento`: id, nombre, dosis, horario; uno por fila, por menú.
- `PerfilMenu`: título, líneas, `texturaBlanda`. Vive solo en `datos/perfiles.dart`.
- Lista de compras: derivada de un menú; suma por nombre y unidad. Se guarda solo el conjunto de "comprados" por (menú, semana, clave `nombre|unidad`).

## 4. Permisos (D23 y ajuste del 6/nov)

| Quién | Menú de Papá | Menú pareja y dueño | Suplementos | Marcar "comprado" | Lista de compras |
|---|---|---|---|---|---|
| Dueño y pareja | ve y edita | ve y edita | edita | sí | ambas |
| Familiar | **ve y edita** | no ve | solo ve | no | ninguna (propuesta, por confirmar) |
| Cuidadora | solo ve | no ve | solo ve | no | la de Papá, solo ve |
| Cuenta maestra (D19) | solo ve | solo ve | solo ve | no | ambas, solo ve |
| Cuenta Casa (tablet) | no ve | no ve | no | no | ninguna |

- La interfaz oculta lo que no corresponde y el servicio rechaza (`PermisoDenegado`) aunque se llame directo. La verdad está en el servidor (RLS).
- La cuenta Casa no ve ningún menú porque el de Papá lleva su perfil clínico y la tablet es pública (propuesta; por confirmar).
- Los suplementos los editan solo dueño y pareja, aunque el familiar edite los platillos de Papá (interpretación, porque la dosis es sensible; por confirmar).
- **Dato clínico (D3):** el perfil de Papá y sus suplementos no salen a la IA ni a las bocinas. El módulo no ofrece herramientas del asistente ni avisos con ese texto.

## 5. Criterios de aceptación

1. Hay dos menús; cada uno muestra 7 días por 4 tiempos, con celdas vacías "Sin platillo".
2. Quien edita un menú asigna, cambia y quita un platillo por celda, con "Deshacer".
3. Dueño y pareja alternan entre los dos menús; los demás ven solo los que les tocan y sin selector si es uno.
4. El familiar edita el menú de Papá y no ve el otro. La cuidadora ve el de Papá sin controles de edición. Cuenta maestra y cuenta Casa: sin edición; Casa no ve menús.
5. En el menú de Papá, elegir un platillo con alimento duro muestra advertencia y pide confirmar; las celdas con ese platillo llevan aviso con icono y texto. En el menú de la pareja no hay advertencia.
6. Los suplementos de cada menú se agregan, editan y quitan solo por dueño y pareja.
7. La lista suma el mismo ingrediente y unidad, no mezcla unidades, agrupa por sección, vacío con mensaje.
8. "Comprado" solo lo marcan dueño y pareja; se indica con texto además del color; avance "X de Y comprados"; las marcas son por menú y sobreviven a cambios del menú.
9. La cuidadora ve la lista de Papá en solo lectura; el familiar no ve listas.
10. El servicio rechaza toda escritura o lectura fuera de permiso aunque la interfaz no lo ofrezca.
11. Sin precios, dinero, IA, red ni servidor en el código; el perfil clínico solo existe en `datos/perfiles.dart` y el módulo no importa asistente, voz ni herramientas.
12. La semana arranca en lunes; cada menú y semana se guardan por separado.
13. Datos de ejemplo inventados; ninguna prueba abre `data/personal/`.
14. Letra 2.0 en 360 dp sin desbordes.
15. `flutter analyze` sin avisos y `flutter test --exclude-tags hallazgo` en verde.

## 6. Contrato para backend

Hoy la app usa `RepositorioAlimentacionEnMemoria` detrás de `RepositorioAlimentacion`; al haber tablas solo cambia `repositorioAlimentacionProvider`.

```
ali_platillos(id uuid pk, hogar_id uuid, nombre text, ingredientes jsonb, duros text[], creado_en timestamptz)
  ingredientes: [{nombre, cantidad numeric, unidad text, seccion text}]
ali_menus(hogar_id uuid, menu text check (menu in ('papa','pareja')), perfil jsonb,   -- perfil: dato clinico (D3)
          primary key (hogar_id, menu))
ali_menu(id uuid pk, hogar_id uuid, menu text check (menu in ('papa','pareja')),
         semana date check (extract(isodow from semana)=1),
         dia smallint check (dia between 0 and 6),
         tiempo text check (tiempo in ('desayuno','comida','cena','colacion')),
         platillo_id uuid references ali_platillos, actualizado_por uuid, actualizado_en timestamptz,
         unique (hogar_id, menu, semana, dia, tiempo))
ali_suplementos(id uuid pk, hogar_id uuid, menu text check (menu in ('papa','pareja')),
         nombre text, dosis text, horario text, actualizado_por uuid, actualizado_en timestamptz)
ali_compras_marcas(hogar_id uuid, menu text, semana date, clave text, marcado_por uuid, marcado_en timestamptz,
         primary key (hogar_id, menu, semana, clave))   -- fila presente = comprado
```

RLS por rol (la verdad de los permisos, D5):

| Tabla | Leer | Escribir |
|---|---|---|
| `ali_platillos` | dueño, coadministrador, familiar, cuidador, maestra | dueño y coadministrador |
| `ali_menus` (perfil) y `ali_suplementos` con `menu='papa'` | dueño, coadministrador, familiar, cuidador, maestra | dueño y coadministrador (suplementos); el perfil, solo dueño |
| `ali_menus` y `ali_suplementos` con `menu='pareja'` | dueño, coadministrador, maestra | dueño y coadministrador |
| `ali_menu` con `menu='papa'` | dueño, coadministrador, familiar, cuidador, maestra | dueño, coadministrador y **familiar** (nunca maestra) |
| `ali_menu` con `menu='pareja'` | dueño, coadministrador, maestra | dueño y coadministrador |
| `ali_compras_marcas` | `papa`: dueño, coadministrador, cuidador, maestra; `pareja`: dueño, coadministrador, maestra | dueño y coadministrador |

La cuenta Casa no lee ninguna de estas tablas. La matriz `permisos_rol` actual de `alimentacion` (familiar: "su parte", casa: leer, cuidador: leer) no distingue menús: hace falta una función tipo `ali_puede(menu, accion)` que use el rol y el menú, y escribir para familiar solo con `menu='papa'` en `ali_menu`. Sin columnas de precio ni dinero. El perfil y los suplementos de Papá no entran a ninguna función ni vista que use la IA o las bocinas.

## 7. Conexión en la app (pide al arquitecto)

En `app/lib/app/pantallas_externas.dart`: `List<RouteBase> rutasAlimentacion() => alimentacion.rutasAlimentacion();` y montarlo en `router.dart` en lugar de `_modulo(Rutas.alimentacion, Modulo.alimentacion)` con `montarRutasDeModulo`. Rutas relativas a `/alimentacion`: raíz = menú, `compras` = lista. El router hoy deja entrar a los roles que `matrizPermisos` permite; la restricción por menú vive en el servicio. La fila de `matrizPermisos` de alimentación (familiar "Leer su parte") conviene ajustarla a "Edita el menú de Papá" (pertenece a `nucleo/permisos`, no a este agente).

## 8. Preguntas abiertas para el dueño (con propuesta)

| # | Pregunta | Propuesta |
|---|---|---|
| P1 | ¿El familiar ve la lista de compras de Papá? | No; solo menú. Si hace las compras, se le da permiso de marcar |
| P2 | ¿La cuenta Casa (tablet pública) debe ver algo de Alimentación? | Nada, por el perfil clínico de Papá. Un "menú del día" sin perfil puede ir en la Fase 7 |
| P3 | ¿El familiar edita también los suplementos de Papá? | No, solo platillos |
| P4 | ¿La cuenta maestra ve los dos menús? | Sí, solo lectura (D19) |
| P5 | ¿Los platillos de ejemplo son catálogo base? | Sí, editable en la Fase 7 |

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

### Ajuste del dueño (6/nov/2026): el familiar también edita el menú de Papá

- **Familiar:** ve **y edita** el menú de Papá. No ve ni edita el menú de la pareja y del dueño.
- **Cuidadora:** ve el menú de Papá (solo lectura, como antes).
- **Marcar "comprado":** sigue siendo del dueño y la pareja (no cambia con este ajuste).

