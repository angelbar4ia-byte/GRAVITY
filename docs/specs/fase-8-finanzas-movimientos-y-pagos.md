# Fase 8 · Finanzas: registrar pagos y ver movimientos por tipo

> Borrador v1.0 (19/nov/2026) para aprobación del dueño. Nace de su petición: *«el celular y la laptop deben tener cómo registrar un pago a una cuenta, también debe ver movimientos por tipo, o sea cuánto ha ingresado»*. Base: D5, D19, D3/D6, diseño de FINANZAS 5.0 bis (libro solo-agregar), `fase-2-finanzas.md` (deudas) y `docs/DISENO_UX_UI.md` (voz y estilos).

## Alcance

1. **Registrar un pago a una deuda o tarjeta desde el teléfono y desde la laptop**, con la misma hoja corta que ya existe (`HojaPagarDeuda`): monto sugerido, cuenta de origen y Guardar.
2. **Resumen por tipo de movimiento** de un periodo: cuánto ingresó, cuánto se gastó, cuánto se pagó a deudas, cuánto se movió entre cuentas, cuánto se ahorró y cuánto costaron los intereses y cargos, con el neto.
3. **Filtro por tipo y por periodo en el teléfono** y **tira de totales** encima de la lista, en el teléfono y en la laptop.

Fuera de alcance: gráficas, exportar el resumen, comparar contra el periodo anterior, pagos a una cuenta que no sea deuda (para mover dinero entre cuentas propias ya existen las transferencias).

## Estado actual (verificado)

- La hoja corta de pago (`pantallas/fase2/hoja_pago.dart`) ya funciona y llama a `ServicioFase2.pagarDeuda`, que registra un movimiento `pagoDeuda` (cuenta líquida → cuenta pasivo de la deuda).
- En la laptop, el botón «Registrar pago» está en cada tarjeta de deuda. En el teléfono solo se abre tocando la tarjeta, sin botón visible: **no se descubre**. Este bloque agrega el botón visible.
- La laptop ya filtra movimientos por fecha, cuenta, categoría, tipo y estado, pero no muestra totales. El teléfono muestra una lista simple de 100 movimientos, sin filtros ni totales.

## Reglas

- **Dinero en centavos (`int`)**, sin redondeos: los totales son sumas exactas.
- **Semana de lunes a domingo**; el mes es el mes natural; el rango lo escribe la persona (inclusivo en ambos extremos).
- **Libro solo-agregar.** Pagar agrega un movimiento; nunca edita ni borra. Corregir un pago se hace con la anulación existente.
- **Permisos por rol (D5, D19).** La hoja de pago y su botón solo aparecen para quien puede registrar en ese libro (`puedeEscribir`, ya resuelto por la matriz de roles y el rol en el libro). Quien solo lee ve la deuda y los totales, sin botón. El servidor (RLS) vuelve a verificarlo: la interfaz no es la barrera. En el libro de Papá, el albacea registra con motivo obligatorio y el movimiento lleva «en nombre de» (regla de la Fase 1; sin cambios).
- **Cada persona ve solo sus libros.** Los totales se calculan sobre la vista del libro activo y no mezclan libros.
- **El pago de deuda no es gasto de categoría.** Es capital que baja el pasivo; el gasto ya ocurrió al comprar. Los intereses y cargos sí son gasto, pero se muestran aparte.
- **Solo cuenta lo confirmado y no anulado.** Se excluyen los movimientos pendientes, rechazados, los anulados y los contraasientos (anulaciones). Una anulación pendiente aún no descuenta el original.
- **Sin IA ni bocinas (D3, D6).** Ningún total sale del dispositivo hacia IA, bocinas ni tablet pública. Con el modo privado activo, los montos se ocultan igual que en el resto de Finanzas.
- **Voz:** de tú, breve y sin culpa. Ejemplos: «Pagar Tarjeta Azul», «Listo: registré el pago de $1,500», «Aún no hay movimientos en este periodo».

## Clasificación del resumen

Cada movimiento cae en **un solo** grupo (los grupos no se solapan):

| Grupo | Qué incluye |
|---|---|
| Ingresos | Movimientos de tipo ingreso (sueldo, extras). |
| Gastos | Gastos hacia cuentas de gasto por rubro. |
| Reembolsos | Devoluciones de un gasto (bajan el gasto; no son ingreso). |
| Pagos de deuda | Pago de capital a tarjeta, préstamo o deuda. |
| Transferencias | Entre cuentas propias y aportaciones entre libros, sin lo que va a ahorro. |
| Ahorro | Lo que entra a cuentas de ahorro desde una cuenta que no es de ahorro. |
| Intereses y cargos | Gasto hacia la cuenta de gasto financiero. |

No cuentan: saldos iniciales, ajustes, reclasificaciones y anulaciones.

**Neto** = ingresos + reembolsos − gastos − intereses y cargos. Los pagos de deuda, las transferencias y el ahorro no entran al neto porque mueven dinero entre cuentas, no lo gastan. Coincide con el estado de resultados del libro (`EstadoResultados.resultado`).

## Diseño de pantallas

### Registrar pago

- **Teléfono (Deudas):** cada tarjeta de deuda con saldo muestra el botón «Registrar pago» (alto táctil de 48 dp o más) además de tocar la tarjeta. Abre la misma hoja de abajo hacia arriba: chips de monto sugerido (para no generar intereses, mínimo, abono planeado), teclado de monto, chips de cuenta de origen y Guardar.
- **Laptop (Deudas):** sin cambio; el botón ya existe y abre la misma hoja.
- La hoja no se duplica: ambas plataformas llaman a `mostrarHojaPago`.
- Meta: de abrir la hoja a guardar, en menos de 10 s con un monto sugerido.

### Totales y filtros

- **Tira de totales** (componente nuevo, compartido): fila de chips o tarjeta compacta con Ingresos, Gastos, Pagos de deuda, Transferencias, Ahorro, Intereses y cargos, y Neto. En el teléfono se desplaza en horizontal y cada chip es tocable (filtra la lista por ese tipo). En la laptop va encima de la tabla.
- **Filtro de periodo en el teléfono:** Esta semana, Semana pasada, Este mes y Todo (el rango libre queda en la laptop; ver pregunta 2).
- **Filtro por tipo en el teléfono:** Todos, Ingresos, Gastos, Pagos de deuda, Transferencias, Ahorro, Intereses y cargos.
- **Laptop:** los totales respetan el filtro de fecha, cuenta y categoría, **pero no el de tipo ni el de estado** (si no, solo se vería un total y los demás saldrían en cero). El filtro de tipo de la laptop no cambia.
- Estado vacío: «Aún no hay movimientos en este periodo.»
- Los montos usan el widget `Monto` y respetan el modo privado.

## Criterios de aceptación

1. En el teléfono, una deuda con saldo mayor a cero y permiso de registro muestra «Registrar pago»; al pulsarlo se abre la hoja corta con monto, cuentas de origen y Guardar.
2. La laptop y el teléfono usan la misma hoja: guardar el mismo pago en ambos agrega el mismo movimiento `pagoDeuda` (origen = cuenta de pago, destino = cuenta pasivo de la deuda, monto en centavos).
3. Sin permiso de escritura en el libro (lectura o libro ajeno) no aparece el botón en ninguna plataforma; si se forzara la llamada, el servicio la rechaza.
4. Una deuda liquidada (saldo cero) no ofrece «Registrar pago».
5. Pagar no edita movimientos previos: el libro solo crece en un asiento. Anular el pago lo saca de los totales.
6. Los totales por tipo de un periodo suman exactamente los movimientos confirmados y no anulados de ese periodo, en centavos, sin redondeos.
7. Un movimiento anulado y su contraasiento no suman en ningún grupo. Un contraasiento pendiente no descuenta todavía.
8. Un movimiento pendiente o rechazado no suma.
9. El pago de deuda no suma en Gastos; los intereses suman en «Intereses y cargos» y no en Gastos.
10. Lo que entra a una cuenta de ahorro suma en Ahorro; retirar de ahorro suma en Transferencias.
11. El neto es ingresos + reembolsos − gastos − intereses, y coincide con el estado de resultados del libro.
12. Los bordes del periodo cuentan: el lunes y el domingo de la semana entran; el domingo anterior y el lunes siguiente no. «Todo» no filtra por fecha.
13. El filtro por tipo del teléfono muestra solo los movimientos de ese grupo y el filtro de periodo solo los de ese periodo; la tira de totales no cambia al filtrar por tipo.
14. Los totales de la laptop cambian con el filtro de fecha, cuenta y categoría, y no con el de tipo ni el de estado.
15. Con el modo privado activo, ningún monto de la tira ni de la lista se ve.
16. Los totales no mezclan libros: cada libro muestra solo los suyos.
17. Con letra grande no se corta ningún total (la tira se desplaza o se parte en líneas).

## Casos de prueba

**Dominio (`paquetes/finanzas_dominio/test/totales_por_tipo_test.dart`)**

- Suma por tipo de una semana con ingreso, gastos, intereses, pago de deuda, transferencia, ahorro y reembolso (criterios 6, 9, 10).
- Neto = 755,500 centavos con el ejemplo; coincide con `estadoResultados` (11).
- Bordes lunes y domingo y movimientos fuera del periodo (12).
- Anulado, contraasiento pendiente y movimiento pendiente (7, 8).
- «Todo» (periodo nulo), mes y acotar con un filtro adicional (12, 14).
- Periodo vacío da ceros.

**App (`app/test/modulos/finanzas/movimientos_y_pagos_test.dart`)**

- Teléfono: botón «Registrar pago» visible con permiso y saldo; ausente sin permiso o sin saldo; abre la hoja (1, 3, 4).
- Guardar desde el teléfono agrega un `pagoDeuda` con los centavos y cuentas correctos (2, 5).
- Teléfono: la tira muestra los totales del libro de demostración, el filtro por tipo y por periodo reduce la lista, el estado vacío aparece (13).
- Laptop: la tira aparece encima de la tabla y cambia con el filtro de fecha (14).
- Modo privado oculta los montos de la tira (15).

## Preguntas abiertas para el dueño

1. **Neto y ahorro.** El neto no descuenta pagos de deuda ni ahorro (mueven dinero, no lo gastan). ¿Prefieres también ver un «flujo de efectivo» (todo lo que salió de cuentas líquidas), o con este neto basta?
2. **Rango libre en el teléfono.** Se propone solo semana, semana pasada, mes y todo, para mantenerlo simple en el celular. ¿Quieres escoger fechas a mano también ahí?
3. **Pago a cuentas que no son deuda.** Se entiende «pago a una cuenta» como pago a una tarjeta, préstamo o deuda. Mover dinero a otra cuenta propia (ahorro, efectivo) ya se hace con transferencias. ¿Falta algún otro caso (por ejemplo pagar a un servicio)?
4. **Pagos con intereses.** La hoja registra el capital como pago de deuda; los intereses del estado de cuenta se registran aparte como gasto financiero (comportamiento actual). ¿Quieres una casilla en la hoja para capturar capital e intereses juntos?

## Trabajo por agente

- **finanzas:** `totalesPorTipo` en el paquete de dominio, tira de totales, filtros del teléfono y botón de pago del teléfono.
- **calidad:** revisión al cierre (D3, D5, D19).
- **backend:** sin cambios (el pago de deuda y sus permisos ya existen).
