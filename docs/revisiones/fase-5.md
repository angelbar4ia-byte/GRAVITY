# Revisión de calidad — Fase 5 (Cuidados)

Revisor: agente calidad · Fecha: 8/nov/2026 · Rama `claude/zen-pasteur-b0jblz`.
Alcance: `docs/specs/fase-5-cuidados.md` v1.6 (todas las secciones), D2, D3, D4, D5, D6, D13, D19, D24, D28; migraciones `20261113` a `20261122` (Cuidados); `supabase/README.md` (sección Cuidados); `app/lib/modulos/cuidados`, `app/lib/nucleo/cuidados`, `app/lib/app/avisos` (recordatorios, posponer), `app/lib/modulos/finanzas/casos_uso/gasto_cuidado.dart`, `app/lib/app/pantalla_segura.dart` y las pruebas de servidor `95_` a `98_`.

## 1. Veredicto

**No aprobada hasta cerrar F5-B1 (1 bloqueante); con ese arreglo, aprobada con condiciones. 1 bloqueante, 5 importantes, 9 menores y 2 decisiones pendientes.**

La base del servidor es sólida: cada tabla `cui_*` tiene RLS, las columnas que pone el servidor no se pueden mandar, bitácora, comidas, entregas y citas son solo-agregar, las RPC devuelven el mismo 42501 exista o no el registro, Casa, otro hogar, `anon` y el cuidador sin turnos no ven nada, la baja corta el acceso en la misma consulta y cancela los avisos pendientes, y la bitácora de auditoría no guarda nombre de medicamento, dosis, notas, texto de cambios urgentes ni concepto de gastos. La cuidadora no ve lo ajeno, la pareja sin consentimiento solo ve turnos y conteos del día, las instrucciones son solo-escribir, y los horarios de comida los cambia solo el dueño.

**El hueco que bloquea** es la cuenta maestra: el servidor la trata como "pareja" y le deja (a) darse a sí misma el consentimiento con `cui_cambiar_consentimiento` y con eso leer medicamentos, tomas, comidas, bitácora y citas, y (b) registrar gastos. D19 dice que la maestra "no registra nada", y el README de Fase 1b prometía que las notas clínicas de Cuidados seguirían sin ser leídas por ella. La interfaz lo bloquea (`esMaestra`), el servidor no, y ninguna prueba de servidor lo intenta.

Lo demás no filtra datos, pero deja funciones a medias en la app: la toma pospuesta no llega a quien sigue, los recordatorios dependen de abrir la app el mismo día, un gasto confirmado puede quedar fuera de Finanzas sin forma de reintentar, y el servidor deja a la cuidadora registrar gastos de la casa.

Límites (honestidad): no tuve teléfono, FCM real, Windows, TalkBack ni Narrator, y `pg_cron` no existe en la base de pruebas (la migración lo avisa con un NOTICE). Lo de entrega real de avisos y de pantalla segura en dispositivo queda manual. Revisé el diseño de accesibilidad solo en lo que toca a avisos y a pantalla segura; no hice pasada visual.

## 2. Pruebas corridas

| Comando | Resultado |
|---|---|
| `bash supabase/tests/correr.sh` | 47 archivos, 2711 afirmaciones, todo pasa (Cuidados: `95_cuidados_roles` 140, `95_cuidados_turnos` 72, `95_cuidados_resumen` 43, `95_cuidados_baja` 42, `96` 23, `97` 58, `98` 30) |
| `flutter test` de Cuidados: `test/modulos/cuidados`, `test/nucleo/cuidados`, `test/app/recordatorios_cuidados_test.dart`, `horarios_comida_recordatorios_test.dart`, `cuidados_instrucciones_acceso_test.dart`, `cuidadora_solicitudes_test.dart`, `pantalla_segura_test.dart` | 167 pasan, 0 fallan (no corrí la suite completa) |
| Sondas propias contra la base local (no entran al repositorio; reproducción en cada hallazgo) | F5-B1, F5-I1 y F5-M1 a F5-M3 confirmados |

## 3. Hallazgo bloqueante

### F5-B1. La cuenta maestra se da consentimiento a sí misma y lee lo clínico; además escribe gastos
- **Dónde:**
  - `supabase/migrations/20261114000000_cuidados_esquema.sql:221-225` (`cui_perfil`): todo `coadministrador` es `pareja`, o `pareja_consentida` si tiene fila de consentimiento; no distingue `es_maestra`.
  - `supabase/migrations/20261115000000_cuidados_operaciones.sql:194-216` (`cui_cambiar_consentimiento`): deja a cualquier miembro vigente poner `concedido = true` sobre su propia `persona_id`, sin revisar `es_maestra`.
  - `20261114…sql:275` (`cui_puede(…, 'gastos', 'escribir')` es `true` para todo perfil) y `:632-633` (política `cui_gastos_agregar`): la maestra (perfil `pareja`) inserta gastos.
- **Qué pasa:** probado contra la base local, como `marta@ejemplo.test` (maestra):
  - Antes: 0 medicamentos y 0 notas de bitácora.
  - Tras `select public.cui_cambiar_consentimiento(hogar, <su persona>, true)`: lee 2 medicamentos, 3 tomas y 1 nota de bitácora; también citas y comidas.
  - `insert into cui_gastos …` como maestra: 1 fila insertada (queda pendiente en la cola del dueño).
  - Contradice D19 ("solo lectura total: no registra nada, ni propio"), el README de Fase 1b (línea 133) y el cuidado de D3 sobre datos clínicos.
- **Por qué las pruebas no lo ven:** `95_cuidados_roles.sql:140-144` prueba a la maestra solo antes de que se dé consentimiento, y nunca prueba que escriba. La interfaz sí la frena (`permisos_cuidados.dart:98-100`, `daConsentimiento => _pareja && !esMaestra`), por eso la app "se ve bien".
- **Reproducción mínima (SQL, como maestra):** `select public.cui_cambiar_consentimiento('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('marta@ejemplo.test'), true); select count(*) from public.cui_medicamentos;` devuelve 2 (esperado: error 42501 o 0).
- **Arreglo propuesto (backend, migración nueva):**
  1. `cui_cambiar_consentimiento`: rechazar con 42501 si la sesión es `es_maestra` y no es dueño (la maestra que además es la dueña conserva su rol).
  2. `cui_perfil`: la maestra que no es dueño nunca es `pareja_consentida`, aunque exista la fila.
  3. `cui_puede(…, 'gastos', 'escribir')` y los demás `escribir`: falso para la maestra (hoy solo `gastos` lo permite). Opción más simple: perfil nuevo `maestra` con lectura de turnos y de nada más, escritura nula.
  4. Pruebas: la maestra, ya "consentida" a la fuerza por postgres, sigue sin leer; no inserta gastos ni cambia su consentimiento; la dueña-maestra sí.

## 4. Hallazgos importantes

### F5-I1. El servidor deja a la cuidadora (y a la pareja) registrar gastos del ámbito `casa`
- `20261114…sql:662` concede `ambito` en el INSERT y `:632-633` solo pide `cui_puede(gastos, escribir)`. Probado: Diana (cuidadora) inserta `ambito = 'casa'`, y lo lee de vuelta. La spec (§2) le da "solo los gastos de cuidado que registra"; la interfaz lo bloquea (`servicio_cuidados.dart:408`, `registraGastoCasa`), el servidor no. Un teléfono modificado o un error de cliente mete gastos de casa de la cuidadora a la cola del dueño y al resumen mensual.
- Arreglo (backend): `with check` en `cui_gastos_agregar`: `ambito = 'cuidado' or cui_perfil in ('dueno','hermana','pareja','pareja_consentida')`. La pareja sí puede (el gasto de la casa es compartido, §8h).

### F5-I2. Un gasto confirmado que no llega a Finanzas queda confirmado para siempre, sin reintento
- `servicio_cuidados.dart:457-473`: primero `cui_confirmar_gasto` (irreversible, 55000 al repetir; probado) y después el paso a Finanzas; si falla (el dueño no es albacea vigente de Papá, no hay cuenta de pago, libro archivado, cierre de la app), solo devuelve `avisoGastoSinFinanzas`, que promete "inténtalo de nuevo más tarde". No existe ese camino: la tarjeta (`pantallas/bitacora.dart:185-263`) solo ofrece Confirmar/Rechazar si está pendiente, y repetir `resolverGasto` choca con el 55000. El gasto cuenta en `cui_resumen_mensual` (confirmado) pero no existe en el libro. La parte de "una sola vez" sí está bien: el id del movimiento es UUID v5 del gasto y `confirmarGastoCuidado` no duplica (`gasto_cuidado.dart`, probado en `cuidados_finanzas_test.dart`).
- Arreglo (cuidados + finanzas): en la lista de gastos, para el dueño, mostrar "Pasar a Finanzas" en los confirmados cuyo movimiento (`idEstable(ClavesId.gastoCuidado(id))`) no esté en el libro, y llamar a `confirmarGastoCuidado` (ya es idempotente). Alternativa: dejar el estado en el servidor como `confirmado` solo después del paso (más grande; no recomendada). Prueba: falla Finanzas, se reintenta, queda un solo movimiento.

### F5-I3. La toma pospuesta no le llega a quien sigue (la app no lee `pospuesta_a`)
- El servidor está completo (`cui_posponer_toma`, `cui_marcar_toma` respeta `pospuesta_a`; `97_cuidados_pendientes.sql`). La app no: ninguna parte de `app/lib` lee `pospuesta_a`/`pospuesta_turno_en` (`repositorio_supabase.dart:328-364` arma `Toma` sin ellas) y `FuenteCuidadosRepositorio.proximos` (`app/lib/app/avisos/recordatorios_cuidados.dart:27`) pone el aviso en `programada`, que cae en el turno de quien la pospuso; para el que sigue, `cuidadorDeTurno(e.cuando)` nunca es él. Resultado: quien recibe la toma no recibe recordatorio ni la ve como suya; la spec 8g ("quien entre a turno recibe la toma pospuesta") no se cumple de punta a punta. Si el siguiente turno es otro día, además `tomas(hoy)` ni la lista.
- Arreglo (cuidados/plataforma): leer `pospuesta_a` y `pospuesta_turno_en`; para esas tomas, el recordatorio va a `pospuesta_a` a la hora `pospuesta_turno_en`, y se incluyen al listar el día del nuevo turno. Prueba de app: posponer, y el sucesor programa el aviso.

### F5-I4. Los recordatorios solo cubren "hoy" y solo se programan al abrir la app
- `FuenteCuidadosRepositorio.proximos` ignora `dias` y solo mira `tomas(hoy)` y `comidas(hoy)` (`recordatorios_cuidados.dart:27-69`). Se reprograma al abrir, al cambiar la persona o la versión de Cuidados, y cada 12 h con la app viva (`con_avisos.dart:192`); no hay tarea en segundo plano. Si la cuidadora no abre la app antes de las 8:00, esa toma no suena; las del día siguiente tampoco existen hasta que abra. D20 dijo que "bastan los recordatorios locales que hay" para el teléfono sin señal, pero eso no cubre un teléfono sin abrir. El criterio 1 (no recibir fuera de turno) sí se cumple; lo que falla es recibir a tiempo dentro del turno.
- Arreglo (plataforma): programar 2 a 7 días con las tomas ya generadas (el cron las crea de hoy y mañana) y reprogramar al sincronizar; o empujar la toma desde el servidor (aviso `recordatorio_toma` con `objeto_id`, como ya se hace con el cambio urgente). Confirmar con el dueño cuál prefiere.

### F5-I5. La generación automática de tomas depende de una acción que no queda documentada en Cuidados
- `20261121000000_cuidados_pendientes.sql:46-52` programa `cui-generar-tomas` solo si `pg_cron` ya existe al aplicar la migración (aquí no existe). La spec §8h dice "las tomas se generan solas una vez activado"; es falso si el dueño activa `pg_cron` después de aplicar. Mientras tanto solo el dueño crea tomas (`repositorio_supabase.dart:333`, al abrir la app); la cuidadora que abre su teléfono sin que el dueño haya abierto el suyo ve un día vacío. El README general lo dice para Avisos (línea 303: volver a correr el bloque final), pero la sección Cuidados no.
- Arreglo (backend, documentación y una función): en `supabase/README.md` (Cuidados) agregar la línea exacta para programar el trabajo después de activar `pg_cron` (`select cron.schedule('cui-generar-tomas', '0 10 * * *', 'select public.cui_generar_tomas_todas()')`) o una función `cui_programar_tareas()` que lo haga idempotente.

## 5. Hallazgos menores

- **F5-M1. Funciones auxiliares como oráculo entre hogares.** `cui_autor_pareja`, `cui_autor_visible_cuidadora` y `cui_en_circulo` son `SECURITY DEFINER`, se conceden a `authenticated` (`20261117…sql:31`, `20261120…sql:35`) y no verifican que quien llama pertenezca al hogar. Probado: Elena (otro hogar) pregunta por el UUID de Alex y recibe `true` ("es la pareja"). Exige conocer el UUID. Arreglo: devolver falso si `rol_en_hogar(p_hogar_id)` es nulo, o no concederlas (las políticas las llaman con el rol del usuario, así que se necesita un `security invoker` envolvente o conservar el grant con esa guarda).
- **F5-M2. Cualquier miembro (incluida Casa) puede escribir su propia fila de consentimiento.** Probado con `casa@`. Sin efecto hoy, pero ensucia `cui_consentimientos`. Se resuelve junto con F5-B1 (solo dueño, pareja y albacea por Papá).
- **F5-M3. El consentimiento de Papá (firmado por el albacea) no gobierna nada.** `cui_cambiar_consentimiento` lo guarda, pero ninguna política ni función lo consulta; la spec §4 lo pide "sobre sus datos". Aclarar qué abre o quitar la promesa.
- **F5-M4. El seed y las pruebas modelan a la hermana como `familiar`, pero D5 la define "Cuidador (familiar)" y el espejo de la app niega Cuidados al rol `familiar`** (`permisos.dart:147`, migración `20261119`). Si el dueño la invita como `familiar`, el servidor le da acceso y la app no la deja entrar. Aclarar con el dueño qué rol real tendrá y probar la combinación (servidor + espejo) con ese rol.
- **F5-M5. `estadoConsentimientos` elige "la pareja" como el primer `coadministrador` activo** (`repositorio_supabase.dart:185`), sin excluir la maestra. Con maestra y pareja en el hogar, la pantalla de consentimientos puede mostrar a la maestra como pareja. Arreglo: excluir `es_maestra`.
- **F5-M6. Los títulos de los recordatorios dicen "Papá"** (`catalogo_avisos.dart:74-75`: "Hora de la toma de Papá"). La spec §8.4 pide recordatorios en voz alta "sin nombre de medicamento ni de persona" y D20 pide títulos sin nombres. Hoy es solo pantalla del teléfono (las bocinas son de la Fase 6), pero el mismo catálogo servirá a la voz. Proponer "Hora de la toma" y "Hora de la comida" (decisión del dueño).
- **F5-M7. Los recordatorios locales de Cuidados no consultan si el equipo es tablet pública** (`reprogramarCuidadosDeEsteEquipo`, `con_avisos.dart:90`), mientras que `ServicioAvisos` sí lo hace (D14/D20). Con la cuidadora dentro por PIN, la tablet pública programa y suena sus tomas; al salir se cancelan salvo que el servidor no responda (`recordatorios_cuidados.dart:142` deja lo ya programado). Sin prueba. Decidir si D14 ("turno de cuidados con recordatorios genéricos") lo quiere así y, si sí, probarlo con títulos genéricos.
- **F5-M8. Textos de "Fase 5" que ya no aplican** en la tablet: `registro_tablet_casa.dart:317` ("Algo de Cuidados: llega en la Fase 5.") y las tarjetas de `pantalla_modo_casa.dart:26-40`. Cuidados no aparece en el modo Casa aunque D14 lo describe; no hay fuga, solo una función prometida sin hacer.
- **F5-M9. La interfaz y el servidor difieren en la bitácora de la hermana.** El espejo (`permisos_cuidados.dart:111`, "decisión pendiente (c)") le muestra solo lo suyo; el servidor le deja leer toda (`20261117…sql:33-38`, probado en `95_cuidados_roles.sql`). Menor porque el servidor es más amplio solo para un rol con permiso de lectura, pero hay que decidirlo. Relacionado: durante una visita de la hermana, `cui_quien_en_turno` deja de devolver al dueño como turno residual (`20261117…sql:75`), y la spec §3 dice que las visitas no cambian el turno; confirmar con el dueño.

## 6. Decisiones pendientes

1. **D13 (cifrado) y Cuidados.** D13 aplica solo a los datos sensibles de Hábitos. La especificación de la Fase 5 no pide cifrado para ningún dato de Cuidados y D2 los sincroniza en la nube con reglas por rol: medicamentos, tomas, comidas, bitácora, entregas, citas y cambios urgentes quedan en claro en Supabase (los lee quien administre el proyecto), y las escrituras sin señal pasan por la cola local sin cifrar (no verifiqué su almacenamiento). Está dentro de lo decidido, pero no hay una decisión escrita: **anotarlo como pendiente del dueño** (¿notas de la bitácora y citas con cifrado de extremo a extremo, como el diario de oración? ¿solo local?). No bloquea esta fase.
2. **Quién puede ver "Cuidados" desde la tablet pública** (F5-M7/M8): confirmar el alcance de D14 antes de la Fase 6.

## 7. Criterios de aceptación (sección 7 de la spec)

| # | Criterio | Estado | Prueba o motivo |
|---|---|---|---|
| 1 | Un cuidador fuera de turno no recibe recordatorios de medicamentos ni comidas | **Cumplido con prueba** | `95_cuidados_turnos.sql` (`cui_quien_en_turno`, residual al dueño); `test/nucleo/cuidados/avisos_cuidados_test.dart`, `test/app/recordatorios_cuidados_test.dart`, `horarios_comida_recordatorios_test.dart`. Salvedad: F5-I3 y F5-I4 son de recibir a tiempo, no de recibir de más |
| 2 | La cuidadora no ve la bitácora ni los datos de la familia fuera de Cuidados | **Cumplido con prueba** | `95_cuidados_roles.sql` (ve solo lo suyo y lo del dueño y la hermana, v1.1; no ve Finanzas, Hábitos, miembros ni auditoría ajena); app: `cuidadora_solicitudes_test.dart`, `pantalla_segura_test.dart`. La spec 8c redefine "no ve la bitácora" como "ve lo suyo y lo que planean para ella" |
| 3 | La hermana ve el resumen mensual sin montos de la pareja ni del dueño, solo con autorización del albacea | **Cumplido con prueba** | `95_cuidados_resumen.sql` (control de 76 900 contra 42 000; 42501 sin autorización o retirada). Se agrega F5-I1 (gastos de casa de la cuidadora) como riesgo de contenido del resumen |
| 4 | Un cambio urgente del dueño avisa a la cuidadora de turno al instante | **Cumplido con prueba (servidor); entrega real manual** | `95_cuidados_turnos.sql` (aviso crítico inmediato, sin texto, a todos los de turno, la pareja no lo ve). La entrega por FCM al teléfono no se pudo probar aquí |
| 5 | Dar de baja a un cuidador corta su acceso de inmediato | **Cumplido con prueba** | `95_cuidados_baja.sql` (42 afirmaciones: lecturas a 0, RPC 42501, deja de estar de turno, avisos cancelados, auditoría) |
| 6 | Ningún dato de Cuidados sale a IA, bocinas ni tablet pública (D3) | **Parcial** | Con prueba: `registro_herramientas_test.dart` (Cuidados solo local), `95_cuidados_roles.sql` (Casa sin nada), avisos y bitácora de auditoría sin texto clínico, el módulo no importa red ni IA. Falta prueba: recordatorios locales en tablet pública (F5-M7), títulos con "Papá" (F5-M6) y las bocinas (Fase 6). **Manual** para el resto |

Otros puntos pedidos en la tarea:

| Punto | Estado |
|---|---|
| Reglas por rol en servidor (`cui_puede`, `cui_perfil`, `cui_quien_en_turno`, bitácora, citas, gastos, consentimientos, autorización, resúmenes, instrucciones, posponer, horarios de comida y RPC) | Cumple con prueba, **salvo la cuenta maestra (F5-B1)** y el ámbito `casa` de la cuidadora (F5-I1) |
| Recordatorios al cuidador de turno (dueño en huecos); hermana solo en sus tramos | Servidor y lógica local con prueba; a tiempo y pospuestas, ver F5-I3/F5-I4 |
| Horarios de comida editables solo por el dueño | Cumplido con prueba (`98_cuidados_horarios.sql`: pareja, hermana, maestra y Casa reciben 42501; el cambio queda en auditoría con tiempo y hora) |
| Pareja: turnos y resumen del día sin consentimiento; bitácora solo con consentimiento; instrucciones solo escribir; no edita horarios | Cumplido con prueba (`95_cuidados_roles.sql`, `96_cuidados_instrucciones.sql`, `98_cuidados_horarios.sql`; sondas Q5 propias) |
| Gastos: confirmar pasa a Finanzas una sola vez; la cuidadora no ve el ámbito casa; el libro de la casa lo elige el dueño | Una sola vez: cumplido (id estable + 55000). Reintento: F5-I2. Ámbito casa de la cuidadora: solo en la interfaz (F5-I1). Libro: lo elige el dueño de sus libros compartidos vigentes, probado en `horarios_y_libro_casa_test.dart` |

## 8. Pruebas adicionales que recomiendo

Escribirlas en `supabase/tests/` (backend) y `app/test/` (cuidados/plataforma) cuando se arreglen los hallazgos; yo no modifiqué pruebas ni código en esta revisión.

- `95_cuidados_maestra.sql`: la maestra, consentida o no, no lee medicamentos, tomas, comidas, bitácora ni citas; `cui_cambiar_consentimiento` y `insert into cui_gastos` dan 42501; la dueña que además es maestra conserva su acceso (F5-B1).
- Gastos: la cuidadora no inserta `ambito = 'casa'`; la pareja sí (F5-I1).
- App: posponer una toma programa el aviso del sucesor a la hora de su turno (F5-I3); falla de Finanzas y reintento con un solo movimiento (F5-I2); el hueco de recordatorios con la app cerrada (F5-I4).
- App: tablet pública con la cuidadora dentro; el catálogo de títulos de Cuidados no contiene "Papá" ni nombres (F5-M6, F5-M7).

## 9. Preguntas para el dueño

1. ¿Qué rol tendrá la hermana en la membresía real, `cuidador` (D5) o `familiar` (como el seed)? (F5-M4)
2. ¿Los recordatorios deben salir con "Papá" en el título, o genéricos sin persona? (F5-M6)
3. ¿Prefieres recordatorios programados varios días por adelantado en el teléfono, o un aviso empujado por el servidor al llegar la hora? (F5-I4)
4. ¿Quieres cifrado de extremo a extremo para bitácora, citas o notas de Papá, como el diario de Hábitos (D13)? (Sección 6)
5. ¿Las visitas de la hermana deben quitar al dueño del turno residual? (F5-M9)

---

# Segunda vuelta

Revisor: agente calidad · Fecha: 8/nov/2026 · Alcance: migración `20261123000000_cuidados_revision.sql`, `supabase/tests/95_cuidados_maestra.sql`, `app/lib/modulos/cuidados`, `app/lib/app/avisos/recordatorios_cuidados.dart`, `app/lib/nucleo/avisos/catalogo_avisos.dart`, `app/test/modulos/cuidados/correcciones_f5_test.dart`, `app/test/app/recordatorios_cuidados_test.dart`. No modifiqué código ni pruebas.

## Veredicto final: **APROBADA CON CONDICIONES**

El bloqueante F5-B1 está cerrado en el servidor y con prueba. Quedan abiertos F5-I4 (recordatorios solo de hoy) y los menores no incluidos en esta ronda. Ninguno filtra dinero ni datos clínicos.

## Pruebas corridas

| Comando | Resultado |
|---|---|
| `bash supabase/tests/correr.sh` | **48 archivos, 2752 afirmaciones, todo pasa** (nuevo `95_cuidados_maestra.sql`: 41; los demás de Cuidados sin cambio) |
| `flutter test` de `test/modulos/cuidados`, `test/nucleo/cuidados`, `test/app/recordatorios_cuidados_test.dart`, `horarios_comida_recordatorios_test.dart`, `cuidados_instrucciones_acceso_test.dart`, `cuidadora_solicitudes_test.dart`, `pantalla_segura_test.dart` | **176 pasan, 0 fallan** (antes 167; no corrí la suite completa) |

## Bloqueante F5-B1: CERRADO

Rehice el criterio con la base de pruebas y con los archivos:
- **Migración.** `cui_es_maestra_ajena` (maestra vigente que no es dueña). `cui_perfil` la devuelve como `pareja` aunque exista una fila de consentimiento concedida. `cui_puede` le responde verdadero solo a `turnos`/`leer`; todo lo demás, falso. `cui_cambiar_consentimiento` da 42501 si la sesión es maestra ajena (a sí misma, para retirar o para otra persona). Un `update` retira los consentimientos que ya tuviera.
- **Prueba (`95_cuidados_maestra.sql`).** Reproduce el peor caso, que es el que usé la primera vez: postgres le inserta a Marta un consentimiento concedido, y aun así ve 0 medicamentos, 0 tomas, 0 comidas, 0 bitácora, 0 citas, 0 gastos y 0 horarios de comida; ve los 11 turnos; los tres intentos de cambiar consentimiento dan 42501; insertar gastos (cuidado y casa), bitácora, citas, entregas, comidas, medicamentos y turnos da 42501; marcar toma, dejar instrucción, crear cambio urgente y fijar horario dan 42501. Contraprueba: la pareja sigue dando su consentimiento y leyendo (2 medicamentos), y la dueña que además es maestra conserva el perfil `dueno`, lee y registra gastos.
- **Puertas laterales.** Revisé que las demás RPC (marcar, posponer, atender cambio, confirmar gasto, horarios, instrucciones) comparan contra `cui_perfil` o `cui_puede`; con el perfil `pareja` fijo de la maestra, ninguna le abre algo que la pareja sin consentimiento no tenga, y las que son de dueño/cuidadora/hermana la rechazan. La política de instrucciones ya excluía `es_maestra` (`20261120:30`).
- **Observación (no bloquea).** La maestra sigue con perfil `pareja`, así que cualquier función que solo pregunte `cui_perfil is not null` (por ejemplo, el resumen del día con conteos, `operaciones.sql:300` y `v11.sql:53`) la trata como pareja sin consentimiento. Son conteos, no contenido; D19 dice "solo lectura total", así que no contradice. Si se quiere que no vea ni los conteos, hace falta una prueba y una guarda más (propuesta menor, ver F5-M10).

## Estado de cada hallazgo

| Hallazgo | Estado | Evidencia |
|---|---|---|
| **F5-B1** maestra se da consentimiento y escribe | **Cerrado** | Migración `20261123` y `95_cuidados_maestra.sql` (ver arriba) |
| **F5-I1** cuidadora registra gastos de casa | **Cerrado** | Política `cui_gastos_agregar` con `ambito = 'cuidado' or perfil in (dueno, hermana, pareja, pareja_consentida)`. Prueba: Diana recibe 42501 en `casa` y puede en `cuidado`; Carla y Alex sí registran `casa` |
| **F5-I2** gasto confirmado sin reintento a Finanzas | **Cerrado** | `bitacora.dart:249` ofrece "Pasar a Finanzas" solo al dueño en confirmados que no constan en el libro (`proveedores.dart:215`). `correcciones_f5_test.dart`: falla Finanzas, se reintenta y queda un solo movimiento; si el reintento falla se sigue ofreciendo; solo el dueño y un pendiente no se pasa; prueba de widget de la tarjeta |
| **F5-I3** toma pospuesta no llega a quien sigue | **Cerrado** | `repositorio_supabase.dart:349-365` lee `pospuesta_a` y `pospuesta_turno_en`; `Toma.recordarEn` es la hora del turno que la recibe; `servicio_cuidados.dart:223` la lista el día del nuevo turno; `FuenteCuidadosRepositorio` programa con `recordarEn`. Pruebas: la cuidadora recibe el aviso a las 7:30 del día siguiente, el dueño que la pospuso ya no; la toma se ve como "Pospuesta por otra persona de turno" |
| **F5-I4** recordatorios solo de hoy y solo al abrir | **Abierto** | `FuenteCuidadosRepositorio.proximos` sigue ignorando `dias` y leyendo solo `tomas(hoy)` y `comidas(hoy)` (`recordatorios_cuidados.dart:23-69`); sin tarea en segundo plano; la prueba de "hueco con la app cerrada" que recomendé no existe. La pregunta 3 al dueño sigue sin respuesta. Sigue siendo de recibir a tiempo, no de recibir de más |
| **F5-I5** cron de tomas no documentado | **Cerrado (con límite)** | `cui_programar_cron_tomas()` (solo dueño o servidor; idempotente; `false` sin `pg_cron`) y párrafo nuevo en `supabase/README.md:610`. Prueba: la cuidadora y `anon` reciben 42501 y la dueña la invoca. Límite: sin `pg_cron` en la base de pruebas no se probó el `true` ni que el trabajo quede programado; verificar a mano al activar la extensión |
| **F5-M2** cualquiera escribe su fila de consentimiento | **Parcial** | Maestra cerrada con prueba. Falta: el rol Casa (y cualquier miembro vigente) todavía puede guardar su propia fila (`cui_cambiar_consentimiento` solo exige `rol_en_hogar is not null` y `persona = yo`). Sin efecto, porque `cui_perfil` solo lee la fila para `coadministrador`; sin prueba. Se deja como menor |
| **F5-M5** "la pareja" puede ser la maestra | **Abierto** | `repositorio_supabase.dart:185` sigue tomando el primer `coadministrador` activo (`parejaId ??= …`) sin excluir `es_maestra`; ninguna prueba lo cubre. La pantalla de consentimientos podría mostrar a la maestra como pareja si aparece antes. Arreglo de una línea |
| **F5-M6** títulos con "Papá" | **Cerrado** | `catalogo_avisos.dart:74-75`: "Hora de un recordatorio de cuidado" y "Hora de la comida". Prueba `correcciones_f5_test.dart` (ninguno de los cuatro tipos de Cuidados contiene "Papá") |
| **F5-M7** recordatorios en tablet pública | **Cerrado** | `reprogramarRecordatoriosCuidados(tabletPublica: true)` cancela y no programa; `con_avisos.dart:110` pasa el tipo de equipo. Prueba: primero se programa en el teléfono y, con la misma persona en tablet pública, `programadas` queda vacío |

No se pidió revisar de nuevo y siguen como estaban: F5-M1 (oráculo entre hogares en funciones auxiliares), F5-M3 (consentimiento de Papá sin efecto), F5-M4 (rol real de la hermana), F5-M8 (textos de "Fase 5"), F5-M9 (bitácora de la hermana y turno residual en visitas).

## Hallazgo nuevo

- **F5-M10 (menor).** La maestra ajena mantiene perfil `pareja`; ve turnos (correcto) y, por funciones que solo piden perfil no nulo, conteos del día. Decidir si D19 también excluye eso y, si sí, agregar la guarda con prueba.

## Condiciones para cerrar la fase

1. **F5-I4:** que el dueño elija (recordatorios locales de 2 a 7 días o aviso empujado por el servidor) y se implemente con prueba; mientras tanto, documentar en la guía de la cuidadora que debe abrir la app antes de su turno.
2. **F5-M5:** excluir `es_maestra` al elegir a la pareja, con una prueba.
3. **Manual al activar `pg_cron`:** correr `select public.cui_programar_cron_tomas();` y confirmar que devuelve `true` y que el trabajo `cui-generar-tomas` existe.
4. Mantener como pendientes con dueño asignado: F5-M1 a M4, M8, M9, M10, y las decisiones de cifrado (D13) y de tablet pública (D14) de la sección 6.
5. Sin cambios: la entrega real de avisos (FCM) y la pantalla segura en dispositivo siguen como verificación manual.
