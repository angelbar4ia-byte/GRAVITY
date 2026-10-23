# Revisión de calidad — Fase 1: Finanzas MVP 1

> Agente **calidad** · 23/oct/2026 · rama `claude/zen-pasteur-b0jblz`, commit `1bb5ed7` (sobre `473b690`, que ya corrige el `SelectorLibro` y los alcances transitorios del resumen).
> Base: `CLAUDE.md`, `docs/DECISIONES.md` (D3, D5, D6, D13, D14, D17, D18, D19), `docs/specs/fase-1-finanzas.md` v0.3 (sección 7, criterios 1 a 44), `docs/revisiones/fase-0.md` y `supabase/README.md` (sección "Finanzas (Fase 1)").
> Revisé la migración `20261021000000_finanzas_mvp1.sql` línea por línea, la probé con un clúster PostgreSQL 16 real intentando romperla desde cada rol, y probé la app (pantallas, cola, tablets, herramientas, dominio) con pruebas de widget y de unidad. Cada hallazgo de este informe se reprodujo antes de listarlo y tiene una prueba que lo demuestra.

## 1. Veredicto

**La Fase 1 se puede cerrar sin bloqueantes, pero no se debe poner a trabajar con datos reales de la familia (ni con la pareja ni con papá) hasta corregir los importantes I1 a I5.**

El servidor es sólido donde más importa: ningún rol sin Finanzas ve una sola fila (23 tablas y vistas, bitácora y funciones, comprobado tabla por tabla), la pareja no ve ni escribe en el libro personal de la dueña ni al revés, los libros solo-agregar resisten `UPDATE`, `DELETE` y `TRUNCATE` (también en cascada y con `service_role`), la idempotencia del mismo `id` funciona, no hay escalada de privilegios (la pareja no se vuelve albacea, maestra ni dueña) y las funciones `SECURITY DEFINER` fijan su `search_path`. El dinero y los datos de papá no llegan a la IA, a las bocinas ni al modo Casa: no existe ningún cliente de IA en el código, toda herramienta de Finanzas es `soloLocal`, la barra de órdenes no ofrece dinero a familiar, cuidador ni Casa, y OpenAPI marca todo lo de Finanzas como solo local.

Lo que falta se reparte en tres grupos:

- **Salvaguardas de D19 que hoy dependen de que el cliente se porte bien** (I1 a I5): el servidor deja que un coadministrador saque a la dueña de un libro compartido, que la cuenta maestra lea sin dejar rastro, que el albacea registre en el libro de papá sin motivo ni "en nombre de", que un albacea dado de baja deje el libro de papá bloqueado y que cualquier miembro falsifique entradas de la bitácora.
- **La primera impresión en el teléfono y la laptop** (I6 a I10): con letra grande el botón Guardar de (+) Gasto se corta; en el teléfono Guardar ni siquiera se ve sin desplazar la hoja; el asistente de arranque se desborda en laptops de 1366 px al 125 %; "Hoy" muestra cifras de ejemplo con una sesión real; y una carga fallida se queda 40 segundos en "Cargando".
- **Privacidad en pantalla** (I11): sigue sin `FLAG_SECURE` (M9 de la Fase 0), y desde la Fase 1 hay dinero en pantalla.

| Gravedad | Cuántos | Con prueba que lo demuestra |
|---|---|---|
| Bloqueante | 0 | — |
| Importante | 11 (I1 a I11) | 11 de 11 (I3 y I11 con dos y una prueba) |
| Menor | 13 (M1 a M13) | 8 con prueba (M1 a M8); M9 a M13 son de decisión, de datos o de documentación |

## 2. Pruebas corridas

| Comando | Resultado |
|---|---|
| `cd app && flutter analyze` | Sin problemas (también con las pruebas nuevas) |
| `cd app && flutter test --exclude-tags hallazgo` (lo entregado más las guardias de calidad) | **830 pasan, 0 fallan** |
| `cd app && flutter test --tags hallazgo` | **+25 −20**: las 25 regresiones de la Fase 0 pasan y las 20 pruebas nuevas con la etiqueta `hallazgo` fallan a propósito (I6 ×4, I7/M7 ×2, I8 ×3, I9, I10, M1 a M4 y M8 ×5, I11, M5 ×3) |
| `cd paquetes/finanzas_dominio && dart test` | **194 pasan** |
| `bash supabase/tests/correr.sh` | **17 archivos, 964 afirmaciones, todo pasa** (el archivo nuevo `80_calidad_fase1.sql` aporta 125) |
| `bash supabase/tests/correr.sh hallazgos_fase1.sql` | Falla a propósito: **7 abiertos** (I1, I2, I3a, I3b, I4, I5 y M6) |
| `cd api && npm run verificar` | Al día (`fnv1a32:bd1d5844`) |
| `cd api && npm run validar` | `openapi.yaml` válido (Redocly) |

Además corrí las guías de accesibilidad de Flutter (zona táctil de 48 dp, botones con etiqueta y contraste del texto) sobre **todas** las pantallas de Finanzas en teléfono y laptop, de día (10 h) y de noche (22 h), y sobre las dos hojas del (+): **pasan** (`f1_g2_guias_accesibilidad_finanzas_test.dart`). Lo que falla es la maquetación con letra grande y en ventanas angostas (I6, I7, M7, M8).

## 3. Criterios de aceptación (especificación, sección 7)

"Sí" quiere decir que hay una prueba que pasa y cubre lo que dice la columna "Cómo se comprueba" de la especificación. "Parcial" nombra lo que falta. "Manual" necesita el proyecto real de Supabase o el teléfono.

| # | Criterio | Estado | Evidencia y observaciones |
|---|---|---|---|
| 1 | 5.6 bis-1 (cascada y techo) | **Sí** | `presupuesto_test.dart` (grupo "prueba 1") |
| 2 | 5.6 bis-2 (sobregasto) | **Sí** | `presupuesto_test.dart` ("prueba 2") |
| 3 | 5.6 bis-3 (sueldo del sábado, alerta de flujo) | **Parcial** | Dominio: `flujo_test.dart`. **La pantalla Semana no tiene prueba de la alerta**; con los datos de ejemplo del 20/oct la tarjeta `finanzas-alerta-flujo` ni aparece (verificado) |
| 4 | 5.6 bis-4 (quincena) | **Sí** | `presupuesto_test.dart`, `semana_test.dart` |
| 5 | 5.6 bis-5 (ingreso incierto) | **Sí** | `presupuesto_test.dart` |
| 6 | 5.6 bis-6 (abono bajo el mínimo, alerta roja) | **Parcial** | Dominio: `presupuesto_test.dart`. **Falta la "prueba de widget"** que pide la especificación (no hay ninguna de la alerta en pantalla) |
| 7 | 5.6 bis-7 (protegidos fuera de recortes) | **Sí** | `presupuesto_test.dart` |
| 8 | 5.6 bis-8 (remanente a la tarjeta, familiares al final) | **Sí** | `presupuesto_test.dart`, `proyeccion_deuda_test.dart`, SQL 22 y 26 (bitácora) |
| 9 | 5.6 bis-9 (corregir gasto de semana cerrada) | **Sí** | `libro_test.dart`, SQL 22 |
| 10 | 5.6 bis-10 (salida de deuda) | **Sí** | `proyeccion_deuda_test.dart` |
| 11 | Rendimiento (< 2 s con un año de datos) | **Manual** | No hay prueba ni medición documentada; necesita el Galaxy A52 y la laptop |
| 12 | 5.0 bis 2-1 (activos, pasivos, patrimonio) | **Sí** | `libro_test.dart` |
| 13 | 5.0 bis 2-2 a 2-4 y 2-7 | **Sí** | `libro_test.dart` |
| 14 | 5.0 bis 2-5 (conciliación con ajuste) | **Sí** | `libro_test.dart`, SQL 25 |
| 15 | 5.0 bis 2-6 (no se borra cuenta con movimientos) | **Sí** | `libro_test.dart`, SQL 24 |
| 16 | 5.0 bis 2-8 (el balance cerrado no cambia) | **Sí** | `libro_test.dart`, SQL 22 y 26 |
| 17 | IN1 (equivalentes semanales) | **Sí** | `frecuencia_test.dart` |
| 18 | IN2 (quincena del 31/oct) | **Sí** | `calendario_test.dart` |
| 19 | IN8 (reembolso) | **Sí** | `libro_test.dart` |
| 20 | IN9 (tres catorcenas no es extra) | **Parcial** | Dominio: `calendario_test.dart`. **El texto de la pantalla Ingresos (`ingresos.dart:84`) no tiene prueba** |
| 21 | IN10 (peor caso de −$1,350) | **Sí** | `flujo_test.dart` |
| 22 | T1 y T2 (remanente 20.58 % y 16.52 %) | **Sí** | `presupuesto_test.dart`, `diseno/finanzas/indicador_y_aviso_test.dart` |
| 23 | T8 (mes de 5 lunes por semanas) | **Parcial** | Dominio: `seguimiento_test.dart` (T8). **La tabla mensual de la pantalla (`laptop/semana.dart:533`) no tiene prueba de widget**, que es lo que pide la especificación |
| 24 | T9 (cierre a los 3 días, reabrir) | **Sí (con prueba nueva)** | Dominio `debeCerrarseSola`, cerrar y reabrir en `casos_de_uso_test.dart`, SQL 26. **`ServicioFinanzas.cerrarSemanasVencidas`, la rutina que sí escribe, no tenía ninguna prueba**: la agrego en `f1_g6_cierre_automatico_test.dart` (pasa) |
| 25 | Libro solo-agregar | **Sí** | SQL 22 y 80 (UPDATE, DELETE, TRUNCATE y TRUNCATE en cascada, con `postgres`, `service_role` y la dueña) |
| 26 | Roles (D19), comprobado en el servidor | **Sí** | SQL 20, 21, 70 y 80; `libros_test.dart`, `finanzas_por_rol_test.dart`, `cuenta_maestra_test.dart` |
| 27 | Sin conexión: se sube al volver, sin duplicar | **Sí** | `cola_contrato_servidor_test.dart`, `cola_sin_conexion_test.dart`, SQL 27 |
| 28 | F1 en menos de 10 s | **Parcial / Manual** | `pantallas_test.dart` recorre el flujo pero no cuenta pasos ni tiempo. Medición en el A52 pendiente. **Además I8: Guardar no se ve sin desplazar la hoja** |
| 29 | Importación de la hoja Categorías | **Sí** | `casos_de_uso_test.dart` y `pantallas_test.dart` con `data/DATOS_SEMILLA_PRESUPUESTO.xlsx` |
| 30 | D3: herramientas `soloLocal` | **Sí** | `registro_herramientas_test.dart`, `f1_g5_d3_finanzas_test.dart` |
| 31 | Libros: pareja y dueño separados; compartido sí | **Sí** | `libros_test.dart`, `casos_de_uso_test.dart`, SQL 20 |
| 32 | Aportación entre libros y cuadre | **Sí** | `cuadre_entre_libros_test.dart`, `casos_de_uso_test.dart` |
| 33 | Solo cruzan transferencia y pago de deuda | **Sí** | `cuadre_entre_libros_test.dart`, SQL 23 y 80 |
| 34 | Albacea (motivo, en nombre de, suplente) | **Parcial** | Cliente: `libros_test.dart`, `casos_de_uso_test.dart`. **El servidor no lo exige** (I3): un movimiento sin `en_nombre_de` ni motivo entra |
| 35 | Cuenta maestra (lee, no escribe, consulta en bitácora) | **Parcial** | Pantalla y cliente: `pantallas_test.dart`, `casos_de_uso_test.dart`, `contrato_servidor_test.dart`; SQL 28. **La consulta en bitácora solo la registra la app** (I2) |
| 36 | Grupo de deudas prioritarias | **Sí (con prueba nueva)** | `grupo_prioritario_test.dart`; la casilla y el orden en la pantalla no tenían prueba: `f1_g7_grupo_prioritario_pantalla_test.dart` (pasa) |
| 37 | Ingresos de papá (1 y 11, apoyo 60+) | **Sí** | `calendario_d19_test.dart`, `pantallas_test.dart`, `f1_g4_dominio_bordes_test.dart` |
| 38 | Día inhábil por origen | **Sí** | `calendario_d19_test.dart`, `contrato_servidor_test.dart` |
| 39 | Ids estables | **Sí** | `casos_de_uso_test.dart`, `pantallas_test.dart` |
| 40 | Cierre en el servidor (versión, ids) | **Sí** | `seguimiento_test.dart`, `casos_de_uso_test.dart`, `contrato_servidor_test.dart` |
| 41 | Contrato de columnas | **Sí (ampliado)** | `contrato_servidor_test.dart`, `cola/contrato_servidor_test.dart` (6 tablas); `f1_g3_filas_caben_en_los_permisos_test.dart` cubre las otras 14 que se guardan por `upsert` |
| 42 | Libro de papá y compartidos, RPC | **Sí** | `casos_de_uso_test.dart`, `contrato_servidor_test.dart`, `pantallas_test.dart` |
| 43 | Ajustes de Finanzas | **Sí** | `pantallas_test.dart` |
| 44 | Rutas y dispositivos | **Sí** | `pantallas_test.dart` |

**Resumen:** 36 cubiertos por una prueba que pasa (3 de ellos gracias a las guardias nuevas: 24, 36 y 41), 7 parciales (3, 6, 20, 23, 28, 34 y 35; los dos últimos por un hueco del servidor y no por falta de prueba), 1 manual (11) y 0 sin ninguna prueba. Las pruebas del dominio están en `paquetes/finanzas_dominio/test/`, las de la app en `app/test/` y las de SQL en `supabase/tests/`.

**Pruebas que pasan en vacío o son frágiles:** no encontré ninguna nueva. Las 55 llamadas a `pruebas.falla` que revisé en la Fase 0 siguen exigiendo el código de error; en el SQL nuevo (`80_calidad_fase1.sql`) también.

## 4. Hallazgos bloqueantes

Ninguno. Revisé específicamente si algún camino lleva dinero, cuentas o datos de papá a la IA en la nube, a las bocinas, al modo Casa, a la tablet pública o a un rol que no corresponde, y no lo hay (sección 7).

## 5. Hallazgos importantes

### I1. Un coadministrador saca a la dueña de un libro compartido
- **Dónde:** `supabase/migrations/20261021000000_finanzas_mvp1.sql:2044` (`fin_libro_miembros_editar` deja actualizar a quien `administrar`), `:2191` (permiso de UPDATE sobre `hasta`) y `fin_libro_miembros_validar` (`:1151`), que no exige 2 o más miembros vigentes.
- **Reproducir:** `bash supabase/tests/correr.sh hallazgos_fase1.sql`, hallazgo **I1**. A mano: como `alex@ejemplo.test`, `update fin_libro_miembros set hasta = now() where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = <Ana>` afecta 1 fila.
- **Escenario:** en "Gastos de la casa" cualquier miembro "administra" (regla 45). Alex cierra la membresía de Ana: ella deja de ver el libro y sus aportaciones allí (lo que aportó sigue en su libro personal, pero el compartido desaparece de su selector) y nadie puede devolverla salvo Alex. La especificación pide 2 o más miembros; ni el servidor ni la app (`Libro.validar` no se llama en ninguna parte) lo hacen cumplir. Con tres miembros, dos pueden dejar fuera al tercero.
- **Esperado:** nadie cierra la membresía de otra persona salvo quien creó el libro (o el dueño del hogar), y un compartido no baja de 2 miembros vigentes.
- **Agente:** backend. **Decisión del dueño** (pregunta 2).

### I2. La cuenta maestra lee todo sin dejar rastro: el registro de consultas es voluntario
- **Dónde:** `:2130` (`fin_movimientos_leer`) y todas las reglas de lectura llaman `fin_puede(libro, 'leer')`, que da verdadero a la maestra en cualquier libro (`:768`); `fin_registrar_consulta_maestra` (`:932`) solo escribe la bitácora si alguien la llama, y quien la llama es la app (`consultaMaestraProvider`, `comunes.dart`).
- **Reproducir:** hallazgo **I2** de `hallazgos_fase1.sql`. A mano: `marta@ejemplo.test` hace `select * from fin_movimientos` y ve 21 movimientos de todos los libros; `select count(*) from bitacora where accion = 'finanzas.consulta_maestra'` da 0.
- **Escenario:** D19 promete "cada consulta a lo de otra persona queda en la bitácora" y la pantalla *Ajustes › Privacidad* se lo dice a la pareja. Pero con cualquier cliente que no sea la app (la propia API REST con el token de la cuenta maestra), la lectura es invisible. Además la dueña puede asignarse a sí misma como cuenta maestra (comprobado: `asignar_cuenta_maestra(hogar, ana)` funciona, y entonces ve los 4 movimientos del libro de Alex sin registro), aunque el diseño recomienda una cuenta aparte, y el cambio de maestra tampoco avisa a nadie (M10).
- **Esperado:** que el servidor lo haga cumplir: p. ej. que la lectura de un libro ajeno por la maestra exija una consulta registrada y vigente (unos minutos) para ese libro, o que las lecturas ajenas pasen por una función que registre. La prueba exige "sin consulta registrada, el libro ajeno no se lee"; si se elige otra forma, se adapta.
- **Agente:** backend. **Decisión del dueño** (pregunta 1).

### I3. El albacea registra en el libro de papá sin "en nombre de" ni motivo
- **Dónde:** `fin_movimientos_validar` (`:1417-1436`): `en_nombre_de` es opcional y el check `fin_movimientos_en_nombre_de_con_motivo` (`:266`) solo pide motivo *si* `en_nombre_de` viene puesto.
- **Reproducir:** hallazgos **I3a** (gasto) e **I3b** (transferencia a su banco personal) de `hallazgos_fase1.sql`. Como `ana@ejemplo.test`: `pruebas.registrar('transferencia', <cuenta de pensión de papá>, <banco de Ana>, 100000)` entra con `en_nombre_de` nulo, `motivo` nulo y `realizado_por` = Ana.
- **Escenario:** regla 50 y criterio 34: "cada movimiento del libro lleva `en_nombre_de` = papá, `realizado_por` = papá y un motivo obligatorio". Hoy lo cumple la app, no el servidor: una versión vieja de la app, la cola o un cliente propio saltan la salvaguarda, y la transferencia de la pensión al banco personal del albacea es la forma más obvia de mal uso (queda en la bitácora con el nombre de Ana, pero sin motivo ni aviso al suplente). La anulación también debe ir en su nombre.
- **Esperado:** un trigger: todo movimiento que toque un libro `representado` exige `en_nombre_de` = su titular y motivo no vacío (incluidas las anulaciones). Opcional: que una salida del libro de papá hacia un libro personal avise al suplente.
- **Agente:** backend (el criterio 34 pasa a "Sí").

### I4. Si el albacea se va del hogar, el libro de papá queda bloqueado para todos
- **Dónde:** `fin_puede` (`:774`): el albacea "vigente" se calcula solo con `fin_libro_miembros` (`desde`/`hasta`); no mira si esa persona sigue activa en el hogar ni con rol de Finanzas.
- **Reproducir:** hallazgo **I4**. Escenario: Alex es albacea y Ana suplente; Ana da de baja a Alex (`update membresias set activa = false`). `fin_puede(libro de papá, 'escribir')` da falso para Ana; tampoco puede cerrar el cargo de Alex (`administrar` también falla) ni registrar un gasto (42501).
- **Escenario:** D17: el suplente "escribe si no hay albacea vigente"; D5: la baja quita el acceso de inmediato. El albacea sin acceso sigue siendo "vigente" y el dinero de papá (pensión, medicinas) no se puede mover hasta que alguien con `service_role` corrija la tabla. En el diseño por omisión el albacea es la dueña, así que el caso no es el más probable, pero es justo el que la figura del suplente debe cubrir.
- **Esperado:** el albacea es vigente solo si su membresía del hogar está activa y su rol tiene Finanzas (misma condición que `fin_es_miembro`), y/o un trigger sobre `membresias` que cierre sus filas de `fin_libro_miembros` al dar de baja o cambiar el rol.
- **Agente:** backend.

### I5. Cualquier miembro falsifica la bitácora de Finanzas
- **Dónde:** `20261020000000_base.sql:678` (`bitacora_agregar`) y `:722` (permiso de INSERT sobre `accion`, `tabla`, `registro_id`, `detalle`): solo prohíbe `insertar`, `actualizar` y `borrar`. Está en "Pendientes conocidos" del README, pero ahora es explotable.
- **Reproducir:** hallazgo **I5**. Como `carla@ejemplo.test` (familiar, sin Finanzas): `insert into bitacora (hogar_id, accion, tabla, registro_id, detalle) values (…, 'finanzas.consulta_maestra', 'fin_libros', <libro de Ana>, '{"libro_id": "<libro de Ana>"}')`. Ana lo ve en su bitácora con el autor "Carla Ejemplo".
- **Escenario:** la bitácora es la herramienta de transparencia de D19 (consultas de la cuenta maestra, quién registró en nombre de papá). Si cualquiera puede escribir entradas `finanzas.*` o de tablas `fin_*` con el `libro_id` de otra persona, el rastro deja de ser confiable ("Carla consultó tu libro"). Además cada miembro puede llenar la base con entradas de hasta 32 KB (M2 de la Fase 0, segunda parte).
- **Esperado:** las acciones `finanzas.*` y las tablas `fin_*` quedan reservadas al servidor (triggers y funciones `SECURITY DEFINER`), y un límite por persona.
- **Agente:** backend.

### I6. Con letra grande, las pantallas del teléfono se desbordan
- **Dónde y prueba:** `app/test/revision_calidad/f1_i6_letra_grande_telefono_test.dart`. Teléfono de 360 dp:
  - letra 1.3 (el "grande" habitual de Android): el encabezado de la tarjeta de la semana se desborda 1.9 px y a 1.5 son 40 px (`diseno/componentes/tarjeta_modulo.dart:49`, la acción —el semáforo "Remanente 33.9 %"— va fuera de un `Flexible`; `pantallas_telefono.dart:65-73`);
  - letra 1.3: la fila **Cancelar · Guardar** de (+) Gasto y de (+) Ingreso extra se desborda 25 px (`registro/hoja_gasto.dart:317`, `registro/hoja_ingreso_extra.dart:155`: un `Row` rígido con `Spacer`); con letra 2.0 son 150 px y el botón principal queda cortado;
  - letra 2.0: la fila de un movimiento no deja lugar al monto (`pantallas/fila_movimiento.dart:87`: el `trailing` del `ListTile` ocupa todo el ancho; en depuración Flutter lo declara error).
- **Esperado:** acciones en `Wrap` o `Flexible`, botones apilados con letra grande, `trailing` con ancho acotado. La letra normal y los 412 dp de un A52 con letra 1.0 a 1.5 sí caben (control que pasa).
- **Agentes:** finanzas (hojas y fila) y diseno (`TarjetaModulo`).

### I7. El asistente de arranque se desborda en ventanas de hasta unos 1100 dp
- **Dónde y prueba:** `f1_i7_laptop_ventana_estrecha_test.dart`. En `/finanzas/arranque` (laptop/arranque.dart:398) la línea "Remanente 20.58 % (meta 20 %) · techo $…" es un `Row` sin `Flexible`: se desborda 19 px a 1100 dp, 95 px a 1024 dp y 219 px a 900 dp **con la letra normal**; una laptop de 1366 px al 125 % mide 1093 dp. Es la primera pantalla que usa el dueño: en la versión de lanzamiento el techo queda cortado.
- **Esperado:** que la línea haga salto de línea (`Wrap`) o el monto vaya en su propia línea.
- **Agente:** finanzas.

### I8. En (+) Gasto, Guardar no se ve sin desplazar la hoja
- **Dónde y prueba:** `f1_i8_guardar_a_la_vista_test.dart`. La hoja arma teclado, monto, categorías, cuentas, fecha y nota antes del botón: Guardar queda en y = 971 dp en una pantalla de 850 dp (en 360 × 800, 1075 dp). `hitTestable()` da 0 widgets en 360 × 800 y 411 × 850; (+) Ingreso extra tampoco se ve en 360 × 800. `pantallas_test.dart` lo esconde con `ensureVisible`.
- **Escenario:** el flujo F1 es "teclado → categoría → cuenta → Guardar" en menos de 10 s (criterio 28). Hay que arrastrar la hoja para alcanzar el botón principal.
- **Esperado:** acciones fijas al pie de la hoja (fuera del desplazamiento) o teclado más compacto.
- **Agentes:** finanzas, diseno.

### I9. "Hoy" y la pantalla principal muestran cifras de ejemplo con una sesión real
- **Dónde y prueba:** `app/lib/modulos/gravity/pantalla/resumen_gravity.dart:334` (`datosResumenGravityProvider` devuelve `ResumenGravity.ejemplo`) y `f1_i9_hoy_sin_cifras_de_ejemplo_test.dart`. Nadie sobrescribe el proveedor aunque desde la Fase 1 existen los datos reales de la semana.
- **Escenario:** el dueño abre el teléfono y ve "Quedan $1,330", "Presupuesto usado 62 %", "Vence la tarjeta de crédito", la agenda de hábitos y un medicamento de las 20:00, todo inventado, al lado de la pantalla Finanzas con cifras reales distintas. No es una fuga (el filtro por rol B1 funciona), pero rompe "no se inventan datos" y la confianza en la primera pantalla.
- **Esperado:** conectar el resumen a la semana activa del libro propio (cálculo local, sin IA) o, mientras tanto, no mostrar el panel con una sesión real.
- **Agentes:** diseno (proveedor y pantallas) con finanzas (la fuente).

### I10. Una carga fallida de Finanzas se queda ~40 s en "Cargando"
- **Dónde y prueba:** `f1_i10_error_sin_reintentos_automaticos_test.dart`; `app/lib/modulos/finanzas/estado/proveedores.dart:84` (`cargaFinanzasProvider`). Riverpod 3 reintenta solo los proveedores que fallan (11 intentos, espera de 200 ms a 6.4 s) y mientras tanto el estado es de carga; nadie configura `retry`. Sin señal y sin copia local (primer uso, o teléfono nuevo) se ven 40 s de "Cargando Finanzas…" y 11 consultas al servidor antes de "Sin conexión… Reintentar". Medido: a los 20 s siguen cargando; a los 40 s aparece el error.
- **Esperado:** `retry: (_, _) => null` en ese proveedor (ya existe el botón *Reintentar*).
- **Agente:** finanzas.

### I11. Sin `FLAG_SECURE` ni cubierta al pasar a segundo plano (M9 de la Fase 0)
- **Dónde y prueba:** `app/android/app/src/main/kotlin/mx/segundocerebro/gravity/MainActivity.kt` (solo extiende `FlutterFragmentActivity`); `f1_menores_test.dart`, caso **I11**. La parte de ciclo de vida de M9 sí se resolvió (`app/tablet/detector_inactividad.dart` mira `resumed` y cuenta los toques de hojas y diálogos); lo que falta es impedir la captura.
- **Escenario:** la miniatura de "recientes" de Android muestra las pantallas de Finanzas, también en la tablet de la casa, donde "recientes" no pide PIN. Los montos se abren ocultos por omisión, pero nombres de cuentas, conceptos de movimientos y el libro de papá se ven; y todo se ve si la persona tocó "Mostrar".
- **Esperado:** `FLAG_SECURE` cuando hay pantallas de Finanzas o Cuidados (o siempre) y una cubierta al pasar a segundo plano.
- **Agente:** plataforma.

## 6. Hallazgos menores

| # | Dónde | Escenario | Propuesta | Agente | Prueba |
|---|---|---|---|---|---|
| M1 | `paquetes/finanzas_dominio/lib/src/libros.dart:32` (`vigenteEn`) frente a `fin_puede` y `filas.dart` (`horaDeFecha`) | `hasta` es *inclusivo* en la app y *exclusivo* en el servidor (`hasta > now()`; la app lo manda como el inicio del día local). El día del cambio de albacea la app ofrece escribir al que ya no puede y niega al suplente que ya puede; el registro rechazado cae en "requiere atención" | Tratar `hasta` como exclusivo en el espejo | finanzas | `f1_menores_test.dart` M1 |
| M2 | `pantallas/comunes.dart:585` (`centavosDeTexto`) | "12,5" se lee como $125.00 y "85,50" como $8,550.00: la coma se borra siempre. Error de diez veces sin aviso | Aceptar la coma solo como separador de miles (seguida de 3 dígitos) o rechazarla | finanzas | M2 |
| M3 | `nucleo/cola/cola_sin_conexion.dart:265` (`encolar`) | Acepta cualquier `tipo` con origen "tablet de la casa" (nombre sin PIN). Hoy nadie lo usa con dinero y el servidor lo rechazaría (42501), pero la regla de D14 ("nombre + PIN para lo personal") debe estar también en la cola | Rechazar tipos de Finanzas y Cuidados con ese origen | plataforma | M3 |
| M4 | `calendario.dart` (`fechasNominales`, rama mensual) | Dos días fijos que caen el mismo día (30 y último en febrero) se funden en uno: `fechasNominales` da 1 pago aunque `vecesAlAnio` cuenta 24. No afecta a la pensión (1 y 11) | Permitir dos pagos el mismo día o rechazar esa combinación al configurar | finanzas | M4 |
| M5 | `repositorio_supabase.dart:46` (`CopiaLocalFinanzas`) | La copia local (libros, miembros, cuentas con su límite, categorías, sobres con su monto semanal, nombres de personas, quién es la maestra) se guarda por persona en el almacenamiento seguro y **nada la borra**: ni `salir()`, ni la baja detectada al abrir, ni `quitarUsuario` de la tablet. La Fase 0, I3, pedía borrar "la copia local". No guarda saldos ni movimientos | Borrar `finanzas.copia.<persona>` en esos tres caminos | plataforma, finanzas | `f1_m5_copia_local_finanzas_test.dart` (3 casos) |
| M6 | Reglas de `fin_cuentas`, `fin_categorias` y `fin_dias_inhabiles` (`:2049-2079`) | Lo del hogar lo administra cualquier adulto con Finanzas, **también la cuenta maestra**: puede congelar todas las cuentas de gasto (nadie registra gastos: 55000), archivar todas las categorías o desactivar los festivos de los demás. Es lo que dice la especificación (6.3), pero contradice "la maestra nunca escribe en lo ajeno" y no avisa a nadie | Decidir si solo el dueño configura lo del hogar; al menos, que la maestra no lo cambie | backend; decisión del dueño | `hallazgos_fase1.sql` M6 |
| M7 | `laptop/semana.dart:213`, `laptop/ingresos.dart:140`, `laptop/marco_laptop.dart:183` | Con la letra al 150 %, Semana, Ingresos, Categorías, Compromisos, Asistente y Ajustes se desbordan (1100 dp); a 800 dp, hasta 68 px | `Wrap`/`Flexible` en esos encabezados | finanzas | `f1_i7_laptop_ventana_estrecha_test.dart` M7 |
| M8 | `gravity/pantalla/hoy_telefono.dart:233` (`_ChipHabito`) | "Hoy" del teléfono con la letra al 200 % se desborda 8.5 px | `Flexible` en el texto del chip | diseno | `f1_menores_test.dart` M8 |
| M9 | `nucleo/seguridad/pin.dart` | El PIN de la tablet es de 4 a 6 dígitos con PBKDF2 de 10 000 vueltas, y con él se cifra la credencial de la persona (que ahora abre dinero): extraído el almacenamiento (equipo con root), un PIN de 4 dígitos cae en minutos. Además el tiempo sin uso se puede subir hasta 30 min (`regresoModoCasaMaximo`) | PIN de 6 dígitos para roles con dinero, más vueltas (en un aislado), tope de 5 min en la pública | plataforma; dueño | — |
| M10 | `asignar_cuenta_maestra` y `puede_ver_entrada_bitacora` | Asignar o cambiar la cuenta maestra no avisa a la pareja: la entrada de `membresias` solo la ve el dueño (comprobado: Alex ve 0 entradas) y *Privacidad* muestra solo quién es hoy | Entrada `finanzas.maestra_asignada` visible para todo adulto con Finanzas | backend | — |
| M11 | `data/` y `docs/modulos/finanzas/…` | **Datos reales.** (a) `data/PRESUPUESTO_DE_ALIMENTOS.xlsx` lleva el nombre completo del dueño en las propiedades del documento (autor y último en modificarlo); (b) la hoja `DATOS_SEMILLA_PRESUPUESTO.xlsx` y el diseño de FINANZAS nombran la ciudad y comercios de la zona, y el diseño nombra instituciones y tarjetas reales (Banamex, BBVA, Costco, Joy, Azul…); (c) `FICHA_DEUDAS_Y_TARJETAS.xlsx` ya está en `data/personal/` (ignorada: `git check-ignore` ✔, no versionada) pero **sigue en el historial** (se creó en `9aa9e8b` y se movió a `data/personal/` en `62c3d53`). No hay llaves, tokens, correos ni teléfonos reales: lo único con forma de correo ajeno es el de la licencia de swagger-ui | Quitar las propiedades del xlsx; decidir si limpiar el historial | arquitecto; dueño | — |
| M12 | `nucleo/herramientas/herramienta.dart` (`ContextoHerramienta`) | `rol`, `confirmado` y `esMaestra` los pone quien llama (M14 de la Fase 0, parte restante). Sin riesgo hoy: todas las herramientas de Finanzas solo navegan | Tomarlos de la sesión dentro del registro antes de la Fase 6 | asistente (Fase 6) | `f1_g5_d3_finanzas_test.dart` vigila lo demás |
| M13 | Triggers de `fin_movimientos`, `fin_cierres`… | "Solo agregar" vale contra todo rol de la API, incluidos `postgres` y `service_role`, pero el dueño de las tablas puede deshabilitar los triggers o borrar la tabla. No es un defecto; conviene decirlo en el README y apoyarse en la copia diaria | Documentar | backend | — |

## 7. Revisión por tema

**7.1 RLS y permisos** (`supabase/tests/80_calidad_fase1.sql`, 125 afirmaciones que pasan, y `hallazgos_fase1.sql`).
- *Fugas entre libros:* Alex no ve el libro personal de Ana ni al revés; el compartido sí; papá solo albacea y suplente (más la maestra); la maestra lee todo; ni familiar, cuidador ni Casa ven una fila de las 21 tablas, 2 vistas, la bitácora de Finanzas ni las funciones (comprobado uno por uno, con `fin_puede`, `fin_es_miembro` y `fin_puede_hogar` en falso).
- *Escalada:* la pareja no puede agregarse como albacea, cambiar su papel, cerrar el cargo de la dueña, entrar al libro de Ana, ponerse `es_maestra` (sin permiso de columna), llamar `asignar_cuenta_maestra`, subirse de rol ni crear libros representados o personales ajenos. Familiar, cuidador, Casa, una persona de otro hogar y papá (sin cuenta) no entran a un libro; la maestra no puede ser familiar ni Casa. Las funciones de reglas tienen `search_path` fijo (`10_esquema.sql`).
- *Solo agregar:* UPDATE, DELETE, TRUNCATE y TRUNCATE en cascada (por `fin_cuentas`, `fin_libros` y `hogares`) fallan con `postgres`, `service_role` y la dueña; `ON CONFLICT DO UPDATE` también.
- *Idempotencia:* el mismo `id` con el mismo contenido no hace nada; otra persona que lo reenvía no puede (42501 o 23505).
- *`en_nombre_de`:* solo lo usa quien escribe en el libro de papá (albacea vigente, o suplente sin albacea), con motivo cuando viene puesto; **faltan las dos salvaguardas inversas (I3, I4)**.
- *Bitácora de `finanzas.consulta_maestra`:* la escribe la función, la ve quien lleva el libro; **pero es falsificable (I5) y voluntaria (I2)**.
- *Vistas `fin_v_*`:* `security_invoker`, respetan la RLS (Alex no ve la cuenta personal de Ana aunque su aportación aparezca en el compartido).
- *Cruce entre libros:* solo transferencia y pago de deuda, y con permiso de escritura en los dos libros (Alex no anula la aportación de Ana, no saca dinero del compartido hacia el banco de Ana, no paga su tarjeta).

**7.2 D3: dinero y datos de papá** (`f1_g5_d3_finanzas_test.dart`, pasa). El código de la app no contiene ningún cliente de IA en la nube; toda herramienta de Finanzas y Cuidados es `soloLocal`, ninguna devuelve `paraIa`, y sus textos no llevan cifras; Finanzas no usa `print`, `debugPrint`, portapapeles ni notificaciones; OpenAPI marca `x-solo-local: true` en las más de 30 operaciones de Finanzas, la bitácora y las RPC; la barra de órdenes no ofrece dinero a familiar, cuidador ni Casa (ni con "presupuesto", "dinero", "gasto", "cuánto me queda"), y la cuenta maestra solo recibe lo que lee de lo ajeno. La tablet pública no tiene ruta a Finanzas; lo personal pide nombre y PIN. **Pendiente:** I11 (capturas), M12.

**7.3 Tablets y sesiones** (pruebas de Fase 0 que siguen en verde: `tablet_test.dart`, `tablet_tipos_test.dart`, `controlador_tablet_test.dart`, `i4_cola_sin_sesion_test.dart`, `i6_tablet_cuenta_casa_test.dart`; más lectura del código). Tablet pública: el modo Casa no muestra dinero; "solo nombre" solo existe para lo de la casa (`accionesDeLaCasa`: lista de compras y recordatorios), y un gasto pide nombre y PIN (`registrarAlgoPersonal`) y se sube con la sesión de esa persona; la cola con origen "tablet de la casa" solo sube con la cuenta Casa (SQL de la cola en `cola_finanzas_y_tablet_test.dart`); la tablet personal solo admite dueño y pareja permitidas; el regreso a los 2 minutos cuenta los toques de hojas y diálogos y comprueba al volver de segundo plano; la sesión de cada persona se guarda cifrada con su PIN. Huecos: M3, M5, M9, I11.

**7.4 Cola sin conexión** (`cola_contrato_servidor_test.dart`, `contrato_servidor_test.dart`, `f1_g3_…`). Idempotencia del id y del contenido, orden de subida por dependencia (cuentas → movimientos → conciliaciones → cierres), 23503 reintentable hasta 100 veces sin detener la ronda, errores permanentes (23505, 23514, 22023, 55000, 42501) a "requiere atención", columnas del servidor nunca enviadas (comprobado contra las migraciones y, con `f1_g3`, para las 14 tablas que se guardan por `upsert`), y reabrir una semana **no** se encola (`cambiarEstadoSemana` va directo y pide señal). Sin hallazgos nuevos en la cola; M3 es defensa en profundidad.

**7.5 Dominio** (`f1_g4_dominio_bordes_test.dart`, pasa). Dinero siempre `int` en centavos (no hay `double` en el dinero: solo en aritmética de fechas), R1 con medios centavos que se alejan de cero con cualquier signo, R2 con 500 repartos aleatorios que suman exacto, semanas en lunes (incluida la 53 de 2026 y el cruce de año), bisiestos, día 31, festivos de 2026 y 2027 (LFT art. 74), pensión de los días 1 y 11 con siguiente día hábil (11/oct y 1/nov caen en domingo; 1/ene/2027 y 1/feb/2027 son festivo), `cada_meses` con ancla en 31 y en febrero, semáforos en sus límites exactos, montos cero o negativos sin excepciones, y el grupo prioritario con deuda liquidada, remanente cero y ahorro mínimo del 100 %. Hallazgo: M4. Nota: el cambio de horario no afecta (México ya no lo usa y `Fecha` calcula en UTC).

**7.6 Pantallas y accesibilidad.** Las guías de Flutter pasan (sección 2). Montos ocultos: todas las cifras de Finanzas pasan por `MontoOcultable`, `textoConMonto` o los gadgets con `montosOcultos`; el lector de pantalla dice "Monto oculto"; el monto que la persona está escribiendo sí se ve (razonable). Estados vacío, cargando, sin conexión y error: existen y ahora tienen prueba (`f1_g1_…`, 10 casos); **pero el de error tarda 40 s (I10)**. Maquetación: I6, I7, I8, M7, M8.

## 8. Lo que está bien (y conviene conservar)

- **Servidor:** RLS en las 21 tablas; privilegios por columna y triggers `fin_a_columnas_fijas` que impiden cambiar llaves; `fin_una_vez` con candado por id para la idempotencia; `fin_movimientos_validar` revisa el permiso en cada libro antes de decir nada más; los errores no revelan datos de otros libros; las vistas respetan la RLS; el cierre exige guardar antes el cierre de la versión correcta (55000 si no).
- **Cola y contrato:** una prueba lee las migraciones y falla si cambian los permisos de columna o las llaves foráneas; ahora otra revisa todas las filas de la app.
- **Dominio:** 194 pruebas del paquete más 18 de bordes; los ejemplos numéricos del diseño cuadran.
- **D3:** el registro de herramientas impone `soloLocal` y la matriz al registrar y al ejecutar; un error de una herramienta solo local no filtra su mensaje.
- **Secretos:** `git grep` no encuentra llaves, tokens, JWT, `google-services.json`, almacenes de llaves, contraseñas ni teléfonos; los correos de ejemplo son todos `@ejemplo.test`; `data/personal/` está ignorada y en el repositorio solo está versionado su `.gitkeep` (`git ls-files data/personal`); la llave de servicio no está en la app. Ver M11 para lo demás.
- **Accesibilidad base:** zonas táctiles de 48 dp, botones con etiqueta, contraste en los tres estilos, de día y de noche.

## 9. Pruebas agregadas por calidad

Las que llevan la etiqueta `hallazgo` (declarada en `app/dart_test.yaml`) fallan hoy a propósito; los controles y las guardias pasan. Línea base: `flutter test --exclude-tags hallazgo`.

| Archivo | Cubre | Hoy |
|---|---|---|
| `supabase/tests/80_calidad_fase1.sql` | Escalada, roles sin Finanzas, solo agregar (con TRUNCATE en cascada), cruce entre libros, reenvío de otra persona | 125 afirmaciones, pasan (en la corrida normal) |
| `supabase/tests/hallazgos_fase1.sql` | I1, I2, I3a, I3b, I4, I5, M6 (no entra en la corrida normal: `correr.sh hallazgos_fase1.sql`) | 7 abiertos |
| `app/test/revision_calidad/f1_i6_letra_grande_telefono_test.dart` | I6 (4 casos `hallazgo` y 1 control) | 4 fallan, el control pasa |
| `f1_i7_laptop_ventana_estrecha_test.dart` | I7 y M7 (2 `hallazgo`, 1 control) | 2 fallan, el control pasa |
| `f1_i8_guardar_a_la_vista_test.dart` | I8 (3 casos) | 3 fallan |
| `f1_i9_hoy_sin_cifras_de_ejemplo_test.dart` | I9 | falla |
| `f1_i10_error_sin_reintentos_automaticos_test.dart` | I10 | falla |
| `f1_menores_test.dart` | M1, M2, M3, M4, M8 e I11 (FLAG_SECURE) | 6 fallan (5 de ellos con la etiqueta `hallazgo`; I11 también) |
| `f1_m5_copia_local_finanzas_test.dart` | M5 (salir, baja, quitar de la tablet) | 3 fallan |
| `f1_g1_estados_de_finanzas_test.dart` | Cargando, sin conexión (con y sin copia), error y sin libros, en teléfono y laptop | 10 pasan |
| `f1_g2_guias_accesibilidad_finanzas_test.dart` | Guías de Flutter sobre todas las pantallas y las dos hojas | 5 pasan |
| `f1_g3_filas_caben_en_los_permisos_test.dart` | Las 14 tablas que se guardan por `upsert` usan solo columnas con permiso de INSERT | 1 pasa |
| `f1_g4_dominio_bordes_test.dart` | Casos borde del dominio (sección 7.5) | 18 pasan |
| `f1_g5_d3_finanzas_test.dart` | D3 (sección 7.2) | 9 pasan |
| `f1_g6_cierre_automatico_test.dart` | Criterio 24: `cerrarSemanasVencidas` | 3 pasan |
| `f1_g7_grupo_prioritario_pantalla_test.dart` | Criterio 36: casilla y orden en la pantalla | 1 pasa |
| `ayuda_calidad.dart` | Ayudas comunes (recolector de desbordes, montaje con tamaño y letra) | — |

Los archivos `b1` a `i6` de la Fase 0 siguen como pruebas de regresión y pasan.

## 10. Pedidos por agente

| Agente | Qué |
|---|---|
| **backend** | I1, I2 (con la decisión del dueño), I3, I4, I5, M6, M10, M13. Mover las afirmaciones de `hallazgos_fase1.sql` a archivos `NN_*.sql` al corregir |
| **finanzas** | I6 (hojas y fila de movimiento), I7, I8, I10, M1, M2, M4, M5, M7 |
| **diseno** | I6 (`TarjetaModulo`), I8, I9, M8 |
| **plataforma** | I11, M3, M5, M9 |
| **asistente** | M12 (Fase 6) |
| **arquitecto** | Integrar (en `git status` las pruebas de calidad de `1bb5ed7` aparecen borradas y las `f1_*` como nuevas: son un renombrado, súbanlo junto); decisiones 1 a 6 (sección 11) con el dueño; M11 con el dueño; **el commit `473b690` incluyó por accidente un archivo de exploración (`x_explora_a11y_test.dart`) que ya no existe en el árbol** |

## 11. Decisiones propuestas (para el dueño; no editan `DECISIONES.md`)

1. **D19 (detalle):** la lectura de un libro ajeno por la cuenta maestra solo es posible con una consulta registrada y vigente, impuesta por el servidor. *Por qué:* hoy el registro depende del cliente (I2).
2. **D19 (detalle):** en un libro compartido solo quien lo creó (o el dueño del hogar) cierra la membresía de otro, y nunca quedan menos de 2 miembros. *Por qué:* un miembro puede dejar fuera a otro (I1).
3. **D17 (detalle):** el albacea o el suplente es "vigente" solo si su membresía del hogar sigue activa y con Finanzas; la baja cierra sus cargos. *Por qué:* I4.
4. **D17 (detalle):** el servidor exige `en_nombre_de` y motivo en todo movimiento de un libro representado, y las salidas hacia un libro personal avisan al suplente. *Por qué:* I3.
5. **D17 (detalle):** la bitácora reserva `finanzas.*` y las tablas `fin_*` al servidor. *Por qué:* I5.
6. **D14/D13 (detalle):** `FLAG_SECURE` en las pantallas de Finanzas y Cuidados y cubierta al pasar a segundo plano. *Por qué:* I11.

## 12. Preguntas para el dueño

1. ¿Te basta con que la app registre cada consulta de la cuenta maestra (hoy), o quieres que el servidor lo obligue? Y: ¿prohibimos que la dueña se asigne a sí misma como maestra (el diseño recomienda una cuenta aparte)? (I2, M10)
2. ¿Puede un adulto de un libro compartido sacar a otro? Propuesta: solo quien lo creó. (I1)
3. En el libro de papá: ¿toda salida hacia un libro personal debe pedir motivo y avisar al suplente? (I3)
4. ¿Hasta qué tamaño de letra y de pantalla quieres que funcione sin cortes? Propuesta: letra 2.0 en 360 dp en el teléfono y ventana de 900 dp en la laptop. (I6 a I8)
5. ¿Quitamos las propiedades del xlsx con tu nombre y limpiamos el historial de git para `FICHA_DEUDAS_Y_TARJETAS.xlsx` (que se escribió en dos commits)? (M11)
6. ¿Tomamos el tiempo del flujo F1 y de arranque en tu Galaxy A52 y en la laptop? Es manual (criterios 11 y 28).
7. ¿PIN de 6 dígitos para quienes ven dinero? (M9)
8. Al crear el proyecto de Supabase, sigue pendiente dejar activa la confirmación de correo (M15 de la Fase 0).

## 13. Estado de los pendientes de la Fase 0

| Hallazgo | Estado hoy | Nota |
|---|---|---|
| M9 (FLAG_SECURE, ciclo de vida) | **Parcial** | Ciclo de vida y toques en hojas: resuelto (`detector_inactividad.dart`). `FLAG_SECURE`: pendiente, ahora **I11** |
| M12 (`finanzas_muestra` editable) | **Resuelto** | La migración borra la tabla; los libros nuevos usan `impedir_cambios_solo_agregar` (SQL 22 y 80) |
| M13 (token de avisos en varias personas) | **Pendiente (Fase 2)** | Sin cambios: `dispositivos_token_por_persona` sigue siendo único solo por persona |
| M14 (herramientas) | **Parcial** | `FalloHerramienta` sanea los errores; `rol`/`confirmado` los pone quien llama: **M12** (Fase 6) |
| M15 (confirmación de correo) | **Del dueño** | No verificable aquí |
| M17 (tablet por tamaño) | **Mitigado** | El tipo (personal o pública) se elige en Ajustes › Dispositivos (D14/D18); la detección sigue siendo por lado corto ≥ 600 dp (`dispositivo.dart`) |
| I7 (datos reales en el repositorio) | **Parcial** | La ficha ya está en `data/personal/` (ignorada), pero sigue en el historial; ver M11 |
