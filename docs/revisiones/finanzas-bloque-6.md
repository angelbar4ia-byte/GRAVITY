# Revisión de calidad — Finanzas, Fase 8, bloque 6

Revisor: agente calidad (independiente) · Fecha: 20/nov/2026 · Rama `claude/zen-pasteur-b0jblz`
Alcance: commits `a9352eb`, `8f7a341` (fugas y deuda buena o mala), `8627264`, `4d64062`, `8e3ad4e` (movimientos y pagos), `0e48e95`, `44082d1`, `70fb303` (dispersión de ingresos), `820328a` (Realtime), `3b0f0e3` (deslizar y mínimo de 20 s), `767e0ea` (cambiar reparto) y `6bf5d8e` (monto cero). Migraciones `20261146` a `20261149`.
Método: leí las cuatro migraciones completas, el dominio (`fugas.dart`, `deuda_calidad.dart`, `dispersion.dart`), la sincronía, el repositorio de repartos y las pantallas nuevas; corrí todas las pruebas; y escribí pruebas nuevas para lo que sospeché. No usé los reportes de los agentes como prueba. No modifiqué código de la app, del dominio ni migraciones; no hice commit ni apliqué nada a Supabase.

## 1. Resumen

El bloque está bien hecho en lo que más importa. **No encontré hallazgos críticos ni altos.** La privacidad (D3, D6, D20), los permisos por rol en el servidor y el libro solo-agregar resisten el examen adversarial: ninguna ruta edita ni borra movimientos, ninguna RPC sale del libro autorizado, todas las funciones nuevas fijan `search_path`, y nada del bloque llega a IA, bocinas, FCM ni al mensaje de Realtime.

Encontré **3 hallazgos medios, 8 bajos y 3 observaciones**. Los medios son: (H-01) con los montos ocultos, «Editar» en «Repartir ingreso» muestra los montos de cada renglón; (H-02) un corte de tarjeta sin pagos capturados se lee como «pagó cero» y acusa falsamente al vampiro V-D y al semáforo B6b; (H-03) anular un ingreso ya repartido deja vigentes los abonos y el ahorro que el reparto creó, sin avisar a la persona. Hay **3 pruebas nuevas que demuestran defectos** (H-01, H-02, H-04); fallan a propósito hasta que se corrijan.

| Severidad | Cantidad | Con prueba nueva que falla |
|---|---|---|
| Crítico | 0 | — |
| Alto | 0 | — |
| Medio | 3 | H-01, H-02 |
| Bajo | 8 | H-04 |
| Observación | 3 | — |

## 2. Qué pasó al correr las pruebas

| Comando | Resultado |
|---|---|
| `bash supabase/tests/correr.sh` | 4683 afirmaciones correctas; **1 archivo con fallas: `99_cuidados_recordatorios.sql`** (depende de la hora; conocido, ajeno). Pasan `117` (fugas y deudas), `118` (dispersión, 196), `119` (Realtime, 51) y `120` (cambiar reparto, 103). |
| `dart test` en `paquetes/finanzas_dominio` | 485 pruebas pasan, antes de agregar las mías. Con `revision_bloque6_calidad_test.dart`: las 2 pruebas nuevas fallan (H-04 y H-02 de este informe; ver nota de numeración). |
| `flutter analyze` (app) | 7 avisos `info`, ninguno en archivos tocados por el bloque (`ajustes_avisos.dart:272` es anterior; el resto es de Alimentación y de `f4_alimentacion_test`). Sin errores ni advertencias. |
| `flutter test test/modulos/finanzas test/nucleo test/diseno test/revision_calidad` | `+2187 ~14 -3`. Los 3 fallos son los conocidos y ajenos: `f1b_bandeja B2`, `f4_alimentacion A5` y `A6`. Confirmado. |
| Pruebas nuevas mías | `app/test/revision_calidad/f8_b6_editar_con_montos_ocultos_test.dart` (falla: H-01). `paquetes/finanzas_dominio/test/revision_bloque6_calidad_test.dart` (2 pruebas; ambas fallan: H-04 y H-02). |

Nota de numeración: en el archivo de pruebas del dominio las etiquetas de los `test(...)` dicen «H-04» y «H-05»; corresponden a **H-04 (doble conteo)** y **H-02 (pagos en cero)** de este informe. Se renombran al corregir.

## 3. Hallazgos

### H-01 · MEDIO · Con los montos ocultos, «Editar» muestra los montos de los renglones

- **Evidencia.** `app/lib/modulos/finanzas/pantallas/registro/hoja_repartir_ingreso.dart`: `_campo()` rellena cada campo con `textoDeCentavos(centavos)` (líneas 95-98); la fila editable se dibuja con ese campo (305-322); el botón «Editar» alterna `_editando` sin mirar `montosOcultosProvider` (373, 629, 646). La hoja sí lo cuida al **cambiar** un reparto (`_editando = cambiando && !ref.read(montosOcultosProvider)`, línea 277), pero no al repartir un ingreso nuevo.
- **Escenario.** La persona deja los montos ocultos (o en modo privado), abre «Repartir» y toca «Editar» mientras alguien mira la pantalla. Los campos muestran, por ejemplo, `9000.00`. «Mostrar montos» exige PIN o huella; este camino lo evita. La prueba existente (`cambiar_reparto_test.dart:1021`) solo revisa la hoja **antes** de tocar «Editar».
- **Prueba que lo demuestra.** `app/test/revision_calidad/f8_b6_editar_con_montos_ocultos_test.dart` falla con «los campos de “Editar” muestran cifras: [9000.00]».
- **Corrección propuesta.** Con `montosOcultosProvider` en verdadero, dejar los campos vacíos con un texto de ayuda («Monto»), o pedir `revelarMontosProvider` antes de entrar a editar; y que «Editar» use el mismo criterio que la línea 277.

### H-02 · MEDIO · Un corte sin pagos capturados se lee como «pagó cero» (V-D y B6b)

- **Evidencia.** `paquetes/finanzas_dominio/lib/src/deuda_calidad.dart:227-235`: `CorteDeTarjeta.pagosAlCorteCentavos` es `int` con valor por omisión 0 (no admite «no se sabe»). `clasificarPago` (503-506) trata 0 como «solo el mínimo». `fugas.dart:1328-1336` usa `prev.pagosAlCorteCentavos` (nunca nulo) para V-D. En el servidor, `fin_estados_cuenta.pagos_al_corte_centavos` es `not null default 0` (migración `20261146`, líneas 61-62), así que **todos los estados de cuenta que ya existen** quedarían con «pagó 0». El campo `pagosCicloAnteriorCentavos` sí es nulo, lo que muestra que el diseño quería distinguir «sin dato».
- **Escenario.** Se conecta la app a la tabla. Una tarjeta con dos estados importados (sin pagos capturados) y el último con intereses: el dominio acusa V-D «por pagar solo el mínimo» y B6b marca rojo en los MSI de esa tarjeta, aunque la persona pagó todo. Hoy no sale en pantalla porque la app todavía no arma `CorteDeTarjeta` desde la base; saldrá al conectarlo. Es solo aviso (la deuda mala no bloquea), pero acusa en falso a quien paga bien.
- **Prueba que lo demuestra.** `paquetes/finanzas_dominio/test/revision_bloque6_calidad_test.dart`, prueba «H-05 … no se lee como “pagó cero”»: falla con `Expected: not 'VD' / Actual: 'VD'`.
- **Corrección propuesta.** Hacer `pagosAlCorteCentavos` nulo en el dominio y en la columna (sin `default 0`; filas viejas en nulo); con nulo, V-D y B6b dan «sin dato» y no acusan. Requiere una migración hacia adelante (no editar la 20261146).

### H-03 · MEDIO · Anular un ingreso ya repartido deja vivos el abono extra y el ahorro, sin avisar

> **RESUELTA (20/nov/2026, paquete F8-6.9).** Decisión del dueño: opción B con alternativa A. La app no deshace nada sola al anular el ingreso: avisa («Anulaste un ingreso que ya estaba repartido…») y la persona elige «Deshacer reparto» o «Dejarlo así». Migración `20261151`, pruebas `121_finanzas_ingreso_anulado_con_reparto.sql`; ver «Ingreso anulado con reparto» en `docs/specs/fase-8-finanzas-dispersion.md`.

- **Evidencia.** `supabase/migrations/20261147000000_finanzas_dispersion.sql:227-257` (redefinido en `20261149…:428-455`): el disparador pasa el reparto a «anulada» y deja solo una entrada de bitácora (`finanzas.dispersion_anulada`, con `movimientos_vigentes`). La especificación lo reconoce como lectura por confirmar: «el diseño decía “se avisa”» (`docs/specs/fase-8-finanzas-dispersion.md`, línea 261, punto 4). La app no lee esa entrada (`grep` de `movimientos_vigentes` en `app/lib`: nada).
- **Escenario.** La persona se equivoca de ingreso, lo anula desde Movimientos. El reparto confirmado se marca «anulado», pero el pago a la deuda y la transferencia al ahorro siguen vigentes: la cuenta del ingreso queda con menos dinero del que hay (puede quedar negativa) y nadie se entera hasta que no cuadra una conciliación.
- **Prueba.** No agregué una: el comportamiento es el documentado; la corrección es de diseño.
- **Corrección propuesta.** (a) Mostrar en la app, al anular un ingreso con reparto aplicado, un diálogo previo: «Este ingreso ya está repartido; también se deshará el reparto» y llamar a `fin_deshacer_dispersion` en la misma operación; o (b) emitir un aviso genérico («Revisa un reparto anulado») y una tarjeta en «Por repartir» con los movimientos huérfanos. Pedir al dueño que confirme cuál.

### H-04 · BAJO · Un mismo gasto puede sostener una hormiga y un fantasma a la vez

- **Evidencia.** `paquetes/finanzas_dominio/lib/src/fugas.dart:462` (`PatronCobro.automatico` es «cualquiera de sus cobros») y `1360-1372` (`_hormigas` solo excluye los gastos con `cobroAutomatico`, no los que ya sostienen otra fuga). La especificación dice «un gasto, una sola fuga» (`FugaDetectada.gastoIds`, línea 689).
- **Escenario.** Un cobro mensual de Netflix: tres cargos automáticos y el de noviembre pagado a mano. La persona responde que no lo reconoce (F3 confirmada) y, además, hay siete compras chicas en la misma categoría. El gasto de noviembre sale en `gastoIdsEnFugas` dos veces (hormiga y fantasma) y su monto se suma a ambos totales.
- **Prueba que lo demuestra.** `revision_bloque6_calidad_test.dart`, prueba «H-04 … UNA sola fuga»: falla con `Expected: <12> / Actual: <11>` y el id repetido `g3`.
- **Corrección propuesta.** En `_hormigas`, omitir los gastos que ya están en `gastoIds` de un patrón clasificado como fuga confirmada (o al revés, según la prioridad de la sección 4.1 de la spec).

### H-05 · BAJO · Carrera entre una recarga automática y una escritura propia

- **Evidencia.** `app/lib/modulos/finanzas/datos/repositorio_supabase.dart:388-389`: `_cargar` lee la cola **primero** y después hace varias lecturas al servidor; al terminar, `_publicar(carga)` reemplaza lo que se ve. `recargarEnSegundoPlano` (`estado/proveedores.dart:153`) y el servicio de sincronía no tienen un número de secuencia ni descartan respuestas viejas.
- **Escenario.** Una recarga por Realtime empieza; la persona registra un gasto mientras las lecturas siguen en vuelo. El gasto se publica, y luego la recarga (con la cola y el servidor de antes del gasto) lo pisa: el gasto desaparece de la lista. Se corrige solo cuando llega el eco de Realtime (≈1.5 s) o con la siguiente recarga; si Realtime no está activo, queda así hasta recargar a mano. No se pierde ningún dato guardado.
- **Corrección propuesta.** Un contador de carga en `CargaFinanzasNotifier` (descartar la respuesta si empezó antes que otra publicación), o volver a leer la cola justo antes de armar la carga.

### H-06 · BAJO · Reconectar el canal respeta el mínimo de 20 s y puede dejar datos viejos

- **Evidencia.** `app/lib/modulos/finanzas/estado/sincronia_finanzas.dart:131-132` y `146-151`: `CanalReconectado` llama a `_refrescarConMinimo`.
- **Escenario.** Último refresco hace 5 s; el Wi-Fi cae 10 s; otro dispositivo registra un gasto; el canal vuelve a los 15 s. Se omite el refresco y el mensaje perdido no se recupera hasta el siguiente aviso, entrar o volver.
- **Corrección propuesta.** Que la reconexión recargue siempre (el riesgo de bucle es bajo: una por reconexión), o que use un mínimo de 2 a 3 s.

### H-07 · BAJO · La especificación de Realtime dice 10 s; el código usa 20 s

- **Evidencia.** `docs/specs/fase-8-finanzas-realtime.md` líneas 16, 23, 37 y 55 dicen «10 s»; `sincronia_finanzas.dart:31` usa 20 s desde `3b0f0e3`.
- **Corrección propuesta.** Actualizar la especificación (y el criterio de aceptación 7).

### H-08 · BAJO · Los 4 avisos de fugas y deuda no están en el catálogo de la app

- **Evidencia.** `app/lib/nucleo/avisos/catalogo_avisos.dart`: `titulosDeAviso` y `severidadDeAviso` incluyen `ingreso_por_repartir` pero no `fuga_por_reconocer`, `fuga_revision_mensual`, `deuda_en_vigilancia` ni `deuda_se_volvio_mala`, que el servidor ya acepta y emite (migración `20261146`, líneas 925-967). La pantalla de preferencias lista solo lo que está en `titulosDeAviso` (`pantalla_notificaciones.dart:34`).
- **Escenario.** Hoy no pasa nada porque la app aún no emite esos avisos. Cuando se emitan: el título cae al genérico (bien: sin cifras), pero `deuda_se_volvio_mala`, crítica en el servidor, se muestra con severidad informativa y la persona no puede silenciar ninguno de los cuatro (el servidor sí lo permite).
- **Corrección propuesta.** Agregarlos al catálogo, con las mismas severidades que `avisos_severidad`, y ajustar el conteo de `avisos_test.dart` (hoy 30).

### H-09 · BAJO · `fin_patron_crear` no usa bloqueo asesor

- **Evidencia.** Migración `20261146…:150-187`: busca por id y por clave y luego inserta, sin `pg_advisory_xact_lock` (todas las demás RPC del bloque lo usan).
- **Escenario.** Dos dispositivos detectan el mismo patrón a la vez: el segundo recibe 23505 («Ya existe») en lugar del id existente, aunque la RPC promete ser idempotente. El reintento funciona.
- **Corrección propuesta.** Tomar `pg_advisory_xact_lock(hashtextextended('fin_patron:' || p_libro || ':' || v_clave, 0))` antes de buscar.

### H-10 · BAJO · «Deslizar para actualizar»: sin retroalimentación y sin alternativa

- **Evidencia.** `sincronia_finanzas.dart:115` y `171-175`: `actualizarAhora()` regresa de inmediato si ya hay una recarga en marcha (solo marca `_otraVez`), y `recargar` no lanza al fallar, así que el indicador se cierra sin decir si salió bien. En teléfono y tablet el único camino manual es el gesto (`pantallas_telefono.dart:34`, `237`; `fase2_telefono.dart:44`); la laptop sí tiene botón y F5.
- **Escenario.** Una persona que usa TalkBack no tiene cómo actualizar a mano; y sin señal el gesto «termina» sin avisar que no actualizó.
- **Corrección propuesta.** Un elemento de menú «Actualizar» en la barra del teléfono y un aviso breve («Sin señal, no se pudo actualizar») cuando falle.

### H-11 · BAJO · El cliente deja pasar un `$` que el servidor rechaza

- **Evidencia.** `deuda_calidad.dart:82-90` (`validarObjetivoTexto` solo rechaza dígitos) contra `fin_deuda_declarar` (migración `20261146…:760`: `v_texto ~ '[0-9$]'` → 22023) y el check de la tabla.
- **Escenario.** «Casa $» pasa la validación local y falla en el servidor con un mensaje de regla.
- **Corrección propuesta.** Rechazar también `$` en el dominio (y contar caracteres como Postgres, por `runes`).

### Observaciones (no son defectos)

- **O-1 · Hormiga y datos importados.** `gastosVigentesParaFugas` marca como «cobro automático» todo movimiento con `via == importacion` (`fugas.dart:240-246`) y `_hormigas` excluye los automáticos (H1). Un libro alimentado solo por importación no verá hormigas. Es lo que dice la especificación (tabla de términos, línea 39 y regla F2), pero conviene avisarlo al dueño.
- **O-2 · Monto cero (`6bf5d8e`).** El arreglo es correcto y está probado (`avisos_app_test.dart`): `Vencimiento.evento` solo se usa en `proyectarFlujoDelLibro` (`seguimiento.dart:540, 544`) y ahí se filtra `v.monto != 0`. El getter `evento` sigue lanzando con cero; si alguien lo usa en otro lado, volverá el fallo. Valdría que `evento` devuelva nulo con cero. Un vencimiento de deuda con monto cero sí sigue generando el aviso de pago próximo (`proveedores_fase2.dart:61`); es razonable (hay fecha límite).
- **O-3 · El servicio de sincronía depende de `Navigator.canPop` para saber si hay una hoja.** Hoy es correcto porque toda la navegación usa `go` y ningún `push` (no hay ninguno en `app/lib`). Si Finanzas se abriera con `push` (por ejemplo, desde un aviso), la recarga se aplazaría para siempre.

## 4. Lo revisado que está bien, y en qué me baso

**1. Privacidad (D3, D6, D20).**
- Realtime: `fin_realtime_avisar` manda siempre `jsonb_build_object('v', 1)` por `finanzas:libro:<uuid>`, evento `cambio` (migración `20261148…:76`); el cliente nunca lee el cuerpo (`fuente_cambios_finanzas.dart:64-69`). Las 51 pruebas SQL de `119` lo verifican contra un stub.
- Avisos: los 5 tipos nuevos (`fuga_*`, `deuda_*`, `ingreso_por_repartir`) no tienen columnas de texto ni de monto; los títulos genéricos no llevan dígitos ni `$` (`fin_fugas_aviso_titulo`, `fin_dispersion_aviso_titulo`, `avisos_texto_valido`). La función de FCM manda solo `{v, id}` (`supabase/functions/enviar-avisos/enviar_test.ts:41`).
- Bitácora: los triggers de las tablas nuevas omiten comercio, clave, motivo, folio, objetivo, etiqueta y montos de umbral (`20261146…:314-325`, `20261147…:220-223`); `fin_movimientos` ya no copia `comercio` (línea 47-49). La entrada `dispersion_cambiada` no lleva cifras ni etiquetas.
- IA y bocinas: `git diff` de los 12 commits no toca `supabase/functions`, `app/lib/modulos/gravity` ni Casa; el catálogo del asistente (`catalogo.json`) no tiene herramientas de fugas ni de reparto.

**2. Permisos por rol (D5, D19, D24).**
- Todas las funciones nuevas fijan `set search_path = ''` (revisión automática de las cuatro migraciones). El único SQL dinámico es DDL con nombres fijos y `%I`/`quote_literal` (`20261146…:306-310`; `20261148…:122-133`).
- Lectura con `fin_fugas_puede_ver` y `fin_dispersion_puede_ver`: exigen `fin_puede(libro,'leer')` más rol dueño o coadministrador. Como solo el rol `familiar` puede tener la vista temporal de Papá (`fin_pedir_vista_papa`, `20261110…:353-358`), excluir por rol equivale a excluir la vista; familiar, cuidador, Casa y tablet pública no leen ni escriben. La cuenta maestra solo lee con consulta vigente (`fin_puede`) y nunca escribe.
- Escritura: las 12 tablas/vistas nuevas tienen solo `grant select`; las columnas nuevas de `fin_movimientos` solo se pueden **insertar**. Las RPC revocan `public` y `anon`; las internas (`fin_dispersion_json`, `_ingreso`, `_registrar`, `_anular_movimientos`, `fin_fugas_exigir`, etc.) también a `authenticated`.
- Sin escalada por `p_libro` ajeno: cada RPC deriva el libro del objeto (`fin_dispersion_ingreso`, `fin_fugas_patron`, deuda) y exige el permiso en **ese** libro; las deudas, cuentas y objetos de los renglones se acotan con `libro_id = v_libro.id`, y las llaves foráneas compuestas (`hogar_id, libro_id`) impiden mezclar hogares. La idempotencia por id devuelve error 23505 si el id es de otro objeto; no devuelve datos ajenos (solo confirma que un UUID existe).
- Realtime: `fin_realtime_puede_suscribir` valida el formato del tema, exige `fin_puede(leer)` y excluye la vista de Papá; solo `authenticated` ejecuta; `fin_realtime_instalar_politica()` está revocada a todos y es tolerante a que no exista Realtime. No hay política de `insert` en `realtime.messages`: los clientes no pueden escribir en el canal.

**3. Libro solo-agregar.**
- Las 6 tablas de fugas tienen `fin_solo_agregar` (update/delete) y `fin_sin_truncate`; «lo vigente» sale de `reemplaza_a` con índices únicos parciales (una raíz, un reemplazo).
- `fin_dispersiones` solo cambia de estado por transiciones (`fin_dispersiones_proteger`, `20261149…:62-89`); los renglones no se editan y solo se reemplazan mientras el reparto es propuesta (`fin_dispersion_lineas_proteger`). Un índice único parcial garantiza un reparto vigente por ingreso. Ningún camino toca `fin_movimientos` fuera de insertar anulaciones con ids estables.
- Atomicidad: `fin_cambiar_dispersion` y `fin_corregir_tipo_ingreso` son una sola función (una transacción); si `fin_dispersion_registrar` falla tras anular, todo se revierte (probado en `120`: suma mal, ahorro sin cuenta, deuda ajena). La suma de renglones se valida dos veces: en la RPC y en un disparador diferido (`fin_dispersion_cuadra`).
- Carreras: todas las RPC toman `pg_advisory_xact_lock` por ingreso, patrón, deuda o libro (la excepción es H-09); `fin_cambiar_dispersion` además bloquea el reparto anterior `for update` y compara versión: el segundo dispositivo recibe 40001 «El reparto cambió, vuelve a cargar.». La app reconoce ese caso por código y mensaje (`fuente_tablas.dart:54-60`) y recarga.

**4. Dominio.** Dinero siempre en `int` de centavos: no hay `double`, `toDouble` ni `.round()` en `fugas.dart`, `deuda_calidad.dart`, `dispersion.dart` ni `totales_por_tipo.dart`; los umbrales se comparan con fracción exacta (`compararProporcion`) y los repartos con el método del mayor resto. Semana en lunes (`periodoLunes` exige lunes, ventana de 4 semanas terminadas). Una fuga principal por patrón, «la persona gana a la regla» (`_aplicarDecision`), la deuda mala nunca bloquea (`bloquea` es constante `false`, `deuda_calidad.dart:373, 980`). La cascada de la dispersión (partidas, deuda, remanente) y sus invariantes (renglones no negativos, suma = monto) están probadas con el ejemplo de Ana y Alex; la suma exacta en un servidor con 190 pruebas.

**5. App.** Sincronía: debounce de 1.5 s con una sola recarga por ráfaga, aplazamiento con hoja abierta, mínimo de 20 s, sin temporizador periódico (el único vivo es el del aplazamiento), y `liberar()` cancela suscripción y temporizadores (`sincronia_finanzas.dart:192-210`). Lo pendiente de la cola se mezcla al cargar (`repositorio_supabase.dart:281, 191-195`); cambiar, deshacer y corregir tipo no usan la cola y piden señal (documentado). Montos ocultos: las pantallas nuevas usan `Monto`/`MontoOcultable` y tienen pruebas de «sin `$`» (salvo H-01). Letra grande: pruebas de 2.0 sin desbordes en la hoja y las tiras de totales.

## 5. Lo que NO se pudo verificar aquí (supuestos sin comprobar)

No hay Supabase real; las pruebas SQL corren en Postgres 16 puro con un **stub** de `realtime`. Sin comprobar:

1. **Firma de `realtime.send(payload jsonb, event text, topic text, private boolean)`.** Si cambia, el disparador solo avisa (`warning`) y no bloquea, pero no habría Realtime. *Cómo probar:* en el proyecto, `select pg_get_function_arguments('realtime.send'::regproc);`, y registrar un gasto con el `select * from realtime.messages order by id desc limit 1;` en la mano.
2. **Política de `realtime.messages`.** Que `fin_realtime_instalar_politica()` devuelva `instalada` y no `sin_permiso`, y que `realtime.topic()` y la columna `extension` existan con esos nombres. *Cómo probar:* `select public.fin_realtime_instalar_politica();` y `select * from pg_policies where tablename='messages';`.
3. **Realtime solo privado.** Que «Allow public access» esté desactivado en los ajustes de Realtime del proyecto, y que un cliente que se una con `private: false` al mismo tema **no** reciba el mensaje.
4. **Evaluación de la política por Realtime.** Que Realtime corra `fin_realtime_puede_suscribir` como `authenticated` con `auth.uid()` de quien se suscribe (las funciones de Finanzas dependen de él), y que `realtime.topic()` devuelva `finanzas:libro:<uuid>` sin el prefijo `realtime:`. Además, la política se evalúa al unirse: quien pierde el acceso (se revoca una consulta, termina una vista) sigue recibiendo avisos sin datos hasta que se reconecte o venza su token.
5. **Error 40001 por PostgREST.** Que el cuerpo del error traiga `code: "40001"` y el mensaje «El reparto cambió, vuelve a cargar.» (el HTTP puede ser 500), y que el cliente de Supabase lo exponga como `PostgrestException.code`. *Cómo probar:* ver el punto siguiente.
6. **Reintento automático del canal** y el estado `subscribed` tras una caída (la API Dart se comprobó solo contra `realtime_client 2.13.2` en caché).

**Prueba con dos dispositivos reales** (laptop y teléfono con la misma cuenta, más la pareja en un compartido):
1. Registrar un gasto en uno y ver que aparece en el otro en 2 a 4 s, sin tocar nada.
2. **Dos dispositivos cambian el mismo reparto:** abrir «Cambiar reparto» en ambos, guardar en A y luego en B. B debe ver «El reparto cambió en otro dispositivo…», recargar y quedar con la versión de A; revisar que A no tenga movimientos duplicados.
3. Abrir una hoja de gasto en la laptop y registrar desde el teléfono: la hoja no se cierra ni se pisa; al cerrarla, se actualiza.
4. Apagar el Wi-Fi de un dispositivo 10 s, registrar en el otro y volver a encender: debe actualizarse (ver H-06).
5. Registrar sin señal: el movimiento sigue visible tras recargar y sube al volver la señal.
6. Con la cuenta maestra (con y sin consulta vigente) y con la vista temporal de Papá, intentar suscribirse: no deben recibir avisos.
7. Con una cuenta de familiar, cuidador y de otro hogar: confirmar que `select * from realtime.messages` y una suscripción manual al tema de un libro ajeno no devuelven nada.
8. Con los montos ocultos, tocar «Editar» en «Repartir» (H-01), y con TalkBack recorrer «Por repartir» y «Movimientos».

## 6. Archivos nuevos de esta revisión

- `/home/user/gravity/docs/revisiones/finanzas-bloque-6.md` (este informe).
- `/home/user/gravity/app/test/revision_calidad/f8_b6_editar_con_montos_ocultos_test.dart` (falla: H-01).
- `/home/user/gravity/paquetes/finanzas_dominio/test/revision_bloque6_calidad_test.dart` (2 pruebas que fallan: H-04 y H-02).

Las tres pruebas fallan a propósito; si el arquitecto prefiere que la suite quede en verde mientras se corrige, puede marcarlas con `skip:` y el número de hallazgo.
