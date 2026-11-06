# Revisión de calidad — Fase 3 (Hábitos MVP)

Revisor: agente calidad · Fecha: 1/nov/2026 · Árbol: `8ae6768` más los archivos de calidad de la sección 9.
Alcance: spec `fase-3-habitos.md` v0.2, D13, D14, D17 a D21, migraciones `20261105` y `20261106`, `app/lib/nucleo/sensibles`, `app/lib/app/sensibles`, `app/lib/modulos/habitos`, recordatorios de Hábitos, `mis_datos_habitos.dart`, `paquetes/habitos_dominio` y `herramientas/biblia`.

## 1. Veredicto

**Aprobada con condiciones. Sin bloqueantes.** Lo que más importaba aguanta: el cifrado es correcto (AES-256-GCM con nonce aleatorio y datos asociados, HKDF por tipo, ids opacos), el servidor nunca ve texto claro ni fechas de registro, el aislamiento por persona resiste a dueño, pareja, maestra, familiar, cuidador, Hogar, otro hogar y `anon`, y los recordatorios son discretos. No encontré dinero ni datos de salud en claro en base local, cola, notificaciones ni semántica.

Pero la **nube cifrada no está terminada de punta a punta** y hoy no funcionaría si se encendiera: la app no tiene el flujo de activarla (frase, confirmación, `hab_guardar_llave`, `hab_cambiar_modo`), y los dos contratos que sí existen chocan con el servidor (F3-2 y F3-3). Como el valor por omisión es `solo_telefono` y nada sube, **no hay fuga ni pérdida de datos hoy**; el riesgo es entregar la fase creyendo que la nube ya sirve. Recomiendo cerrarla con la nube declarada como "servidor listo, flujo de la app pendiente" (pregunta 1) y corregir F3-2 a F3-5 y F3-12 antes de activarla.

Límites (honestidad): no corrí Deno ni un teléfono real; no probé `pg_cron`; los criterios 1 a 60 los asigné leyendo nombres y ejemplos de pruebas, y solo re-probé por mi cuenta los marcados "(re-probado)".

## 2. Pruebas corridas

| Comando | Resultado |
|---|---|
| `flutter analyze` (app) | Sin problemas |
| `flutter test --exclude-tags hallazgo` | 1988 pasan (más 27 guardias nuevas mías) |
| `paquetes/habitos_dominio`: `dart test` | 35 pasan (también con `TZ=America/New_York`, `Pacific/Auckland` y `America/Sao_Paulo`) |
| `paquetes/finanzas_dominio`: `dart test` | 283 pasan |
| `bash supabase/tests/correr.sh` | 35 archivos, 2106 afirmaciones, todo pasa (+21 de `91_calidad_fase3.sql`) |
| `probar_respaldo.sh` | 44 comprobaciones, todo pasa |
| `api`: `npm run verificar` y `npm run validar` | Al día / válido |

## 3. Hallazgos bloqueantes

Ninguno.

## 4. Hallazgos importantes

### F3-2. La segunda subida de sobres siempre se rechaza (salto de revisión) y la cola lo toma por permanente
- Cada edición local sube la revisión del sobre en 1 y la subida diferida solo encola la última. Tras una primera subida (revisión 1), si la persona registra tres consumos más, la segunda lleva revisión 4; el servidor exige +1 (`hab_subir_sobres`: "La revisión de un sobre sube de 1 en 1", 22023) y aborta **todo el lote de hasta 50 sobres**. La cola trata 22023 como permanente: la nube deja de sincronizar. La revisión va en los datos asociados, así que el cliente tampoco puede renumerar.
- Reproducir: `app/test/revision_calidad/f3_cripto_test.dart` (F3-2, etiqueta `hallazgo`: sube `[1, 4]`); en SQL, `supabase/tests/hallazgos_fase3.sql` (F3-2, la nota sale 22023).
- Corrige: **backend** (aceptar `revision > actual`, gana la mayor; conserva "menor o igual = conflicto"). Alternativa: plataforma sube cada revisión intermedia, que pesa más. Hay que ajustar la spec 4.2 ("de 1 en 1").

### F3-3. El nombre del KDF del cliente no lo acepta el servidor
- `LlaveEnvuelta.kdfPbkdf2 = 'pbkdf2-sha256'`; `hab_llaves.kdf` solo admite `pbkdf2-hmac-sha256` o `argon2id` (también el OpenAPI). `hab_guardar_llave` daría 23514 al activar la nube. Hoy no se nota porque la app nunca llama a esa función.
- Reproducir: `f3_cripto_test.dart` (F3-3) y `hallazgos_fase3.sql` (nota 23514).
- Corrige: **plataforma** (usar `pbkdf2-hmac-sha256`). De paso, acotar `vueltas` al desenvolver: hoy lo manda el servidor sin tope y un valor enorme congelaría el hilo (solo el respaldo local acota a 5 000 000); lo leí en el código, sin prueba.

### F3-4. La bitácora se puede llenar sin límite desde Hábitos (regresión del N1 de la Fase 1b)
- `hab_borrar_mis_datos`, `hab_reiniciar_nube` y `hab_cambiar_modo` escriben una constancia con `hab_nota` (definer, así que el trigger del tope sale temprano) y el tope además excluye las acciones `habitos*`. Una familiar llamó 600 veces `hab_borrar_mis_datos('sensibles')` y quedaron 600 filas.
- Reproducir: `hallazgos_fase3.sql` (F3-4, ABIERTO).
- Corrige: **backend** (límite por persona y día para `habitos.*` dentro de `hab_nota`, o no registrar si la última constancia igual es de hace menos de un minuto).

### F3-5. `hab_limpiar` no borra a los 90 días a quien se dio de baja con `activa = false` (la forma más común)
- Se limpia solo con `activa = false` **y** `hasta` de hace más de 90 días. Con `activa = false` y `hasta` nulo (lo que deja un simple UPDATE), o con `activa = true` y `hasta` vencido, los datos de Hábitos (incluidos sobres y llave envuelta) **se conservan para siempre**. Con 89 días no borra y con 91 sí (probado), pero solo en el caso que cubre la prueba existente.
- Reproducir: `hallazgos_fase3.sql` (F3-5 y F3-5b, ABIERTO).
- Corrige: **backend** (guardar la fecha de baja, p. ej. `membresias.baja_en` puesta por trigger al pasar a `activa = false`, y contar los 90 días desde ahí). Decisión del dueño en la pregunta 3.

### F3-12. La fila de Hoy no le dice al lector de pantalla su estado
- El nodo de cada objetivo en Hoy lleva solo el título: sin "pendiente" ni "hecho", sin estado de casilla y sin ser botón. Incumple el criterio 57 ("cada fila anuncia su estado").
- Reproducir: `f3_letra_grande_test.dart` (F3-12, etiqueta `hallazgo`).
- Corrige: **diseno** (`FilaHabito` en `app/lib/diseno/habitos/hoy.dart`: `Semantics` con estado, casilla y acción de marcar).

## 5. Hallazgos menores

- **F3-6. La frase se rechaza si la "á" llega descompuesta (a + U+0301) o sin acento.** Se compara tal cual (sin NFC). Teclados que no normalizan o quien escribe sin acentos no puede recuperar su llave. `f3_cripto_test.dart` (F3-6). Corrige: plataforma (normalizar a NFC y comparar sin acentos al validar).
- **F3-7. Recordatorio con minutos negativos.** Un bloque que empieza a las 00:10 con aviso a 30 min se programa a las 00:40 del mismo día (después de empezar), no a las 23:40; igual el cierre del día si "dormir" es antes de la 1:00. `f3_recordatorios_test.dart` (F3-7). Corrige: habitos (`fuentes_plataforma.dart`).
- **F3-8. El nombre opcional en el aviso se recorta partiendo emojis.** `substring(0, 40)` deja medio sustituto UTF-16 en el título. `f3_recordatorios_test.dart` (F3-8). Corrige: plataforma (`tituloDeRecordatorio`, recortar por runas).
- **F3-9. `hab_hogar_de(persona)` la puede llamar cualquier sesión** y devuelve el hogar de cualquier persona (de otro hogar también), y por tanto si tiene Hábitos. Hace falta conocer el UUID. `hallazgos_fase3.sql` (F3-9). Corrige: backend (devolver solo el hogar de la sesión o revocar el permiso; las políticas no lo necesitan con argumento ajeno).
- **F3-10. Sin cuota en las tablas en claro.** Un miembro inserta miles de objetivos de ~10 KB; solo los sobres tienen cuota (25 MB). `hallazgos_fase3.sql` (F3-10). Corrige: backend (tope de filas por persona).
- **F3-11. La lista de Objetivos pinta siempre 0 % de avance** (`avance: 0` fijo en `objetivos.dart`). `f3_letra_grande_test.dart` (F3-11). Corrige: habitos.
- **F3-13. Se puede exportar lo sensible en claro** dejando la frase vacía (con el aviso de la spec 95). Es lo que pide la spec, pero el camino fácil es el inseguro. Sugerencia: pedir la frase siempre o una segunda confirmación explícita. Corrige: habitos o plataforma, si el dueño lo decide (pregunta 2).
- **F3-14. El importador de la Biblia acepta casi todo.** Con entrada hostil: `TypeError` (no `FormatException`) con elementos nulos o no-mapa; acepta versículos vacíos, capítulos sin versículos, caracteres de control y de inversión de texto, un versículo de 5 MB, y `version`, `licencia` y `origen` vacíos o cualquiera. Reproducido con un guion fuera del repo (entradas listadas arriba). Es herramienta del dueño, no del usuario. Corrige: habitos.
- **F3-15. "Mis datos de Hábitos" no está tras la puerta reservada** (regla 100 la lista). Pide PIN en cada acción pero sin FLAG_SECURE ni modo privado; solo muestra botones. Corrige: habitos.
- **Otras observaciones (sin prueba, de lectura):** `generarPlan` con máscara de días 0 se cicla (la interfaz no lo permite y el servidor exige ≥ 1); el servidor puede devolver una revisión vieja de un sobre sin que se detecte (aceptable con un servidor honesto pero curioso, D13); borrar en la nube sin señal borra lo local pero no deja un reintento persistente.

## 6. Revisado y sin hallazgo

- **Cifrado (re-probado):** 3 000 cifrados del mismo texto sin un nonce repetido; alterar cualquiera de los bytes de un sobre, o cambiar persona, tipo, id o revisión, impide abrirlo; sobre truncado o vacío da `null` sin lanzar. Lista de 2 048 palabras sin espacios ni marcas combinantes, frases de 12 palabras válidas, verificación cambiada rechazada. Vectores NIST, RFC 5869 y BIP-39 ya en las pruebas de plataforma.
- **Qué ve el servidor (re-probado):** `hab_sobres` solo tiene tipo, revisión, texto cifrado, versión de llave y horas del servidor; máximo 50 por llamada, solo base64url, tope de 64 KB y 25 MB de cuota, solo en modo `nube_cifrada`; un sobre ajeno se rechaza (`91_calidad_fase3.sql` G11 a G17).
- **Nada sensible en claro:** el almacén, la cola y las pruebas de plataforma buscan una cadena marcada y no la encuentran; la notificación lleva cuerpo vacío y título "Recordatorio" para todo lo sensible, por el canal reservado, solo con Posponer, aunque traiga nombre. Las pantallas reservadas están tras `PuertaReservada` (PIN, 2 minutos, FLAG_SECURE, modo privado, nada en la tablet pública).
- **Servidor (PostgreSQL real, re-probado):** `hab_limpiar`, `hab_borrar_datos_de`, `hab_nota`, `hab_iniciar_persona` y `hab_miembro_activo` no las puede llamar un usuario; `anon` no lee ni borra; la pareja no lee, cambia ni borra un objetivo de Ana ni registra sobre él (llave compuesta con persona); entradas `habitos.*` de la bitácora ocultas al dueño y a la maestra; la app no puede escribir `habitos.*`; la familiar, con preferencias de Hábitos, **no** es destinataria de avisos de dinero; a los 89 días no se borra y a los 91 sí (con baja completa).
- **Dominio (re-probado, tres zonas horarias):** fases de Día D con las fechas del criterio 12, porcentajes 25/50/75, promedio de línea base (12.00, 10.00, 11.86), límites 9/6/3 y 8/5/3, ahorro $90.00, racha libre y recaída (5/5/5, 0/5/5, 1/5/6), apoyo en el borde de 14 días, semáforo, carga 50/85 % en los bordes exactos, planes de 260 y 1 189 capítulos, solo lunes a viernes, semana en lunes con bisiesto y año nuevo, 29 de febrero.
- **Accesibilidad:** Hoy y Objetivos a letra 200 % en 360 dp y 900 dp sin desbordes, botones de 48 dp o más.
- **Texto bíblico:** no hay texto de ninguna edición en el repositorio (solo fuentes en `assets`); el lector arranca vacío hasta que el dueño entregue una fuente de dominio público (P10).
- **Secretos:** ninguno; el PEM de `enviar_test.ts` se genera en la prueba. Sin cambios en `data/`.
- **Aserciones:** `git diff dad5d92..HEAD` sobre `app/test/revision_calidad` sin cambios y sobre `supabase/tests` solo `82_avisos_rls.sql`: la familiar ahora tiene preferencias (Hábitos) y `teo` pasa a cuidador para seguir probando "pierde las preferencias". Ninguna prueba debilitada.

## 7. Criterios de aceptación 1 a 60

Sí = con prueba que pasa · Parcial = parte con prueba, parte pendiente · Manual = solo con equipo real.

| # | Estado | Nota |
|---|---|---|
| 1 | Sí | Suites de fases anteriores en verde |
| 2 a 6 | Sí | Rachas, gracia, pausas, global (probado el ejemplo de gracia y la semana de lunes) |
| 7 | Parcial | Estados del día con cantidad cubiertos en el servicio, sin `registro_test` aparte |
| 8, 9 | Sí | Orden de Hoy y carga (9 re-probado) |
| 10 | Parcial | Sin `cola_hab_test`; la cola general sí |
| 11 | Parcial | Asistente SMART en dominio; sin `objetivo_smart_test` con los ejemplos de redondeo |
| 12 a 19 | Sí | Fases, línea base, límites, recaída, semáforo, ahorro, hitos (12 a 18 re-probados) |
| 20 | Parcial | SOS en dominio y pantalla; el funcionamiento sin conexión es manual |
| 21, 22 | Parcial / Manual | Atajo y 1 toque sin medir en el A52 |
| 23 | Parcial | Mensajes sin culpa en dominio; no hay rojo en las pantallas (revisado); falta la revisión visual |
| 24 | Sí | Agenda |
| 25 | Parcial | Asistente de configuración sin los 8 pasos probados de punta a punta |
| 26 a 28 | Sí | Referencias y planes (26 y 27 re-probados; 28 por prueba existente) |
| 29 | Parcial | Lector y versiones: sin texto bíblico; subrayados y notas pendientes |
| 30 | Parcial | "Acerca del texto" no se puede revisar sin texto; no hay RVR1960 ni NVI |
| 31, 32 | Parcial | Devocional, oración y revisión semanal con pruebas; sin la revisión de hitos y motivos/disparadores completa |
| 33 | Sí | Progreso |
| 34 | Sí | Cifrado (re-probado) |
| 35 | Parcial | Frase y envoltura sí; cambiar y verificar la frase, no (F3-6) |
| 36 | Parcial | Modos por omisión sí; **sin flujo de activar la nube** ni de volver; épocas sin consumir (F3-2, F3-3) |
| 37 | Sí | Fusión |
| 38 | Sí | Nada en claro en almacén y cola; los registros de fallas no los verifiqué |
| 39 | Sí | Con la excepción F3-2 |
| 40, 41 | Sí | RLS y último gana |
| 42 | Sí | Con la excepción F3-4 |
| 43 | Parcial | Borrar y exportar sí; el equipo no detecta `epoca_nube`; exportar sin frase en claro (F3-13) |
| 44 | Parcial | Respaldo hostil rechazado; sin pantalla de revisión con conteos ni importar/exportar respaldo en la app |
| 45 | Sí | Preferencias |
| 46 | Sí | Discreción (re-probado) |
| 47 | Parcial | Siete días, silencio, foco y claves sí; reinicio y bordes manuales; F3-7 |
| 48, 49 | Manual | Acciones de la notificación con la app cerrada; pulsera |
| 50 | Parcial | Tablet pública sin llave ni recordatorios, personal como el teléfono (pruebas de plataforma); sesión de 2 minutos sin medir |
| 51 | Sí | Roles y pantallas |
| 52 | Parcial | Puerta reservada sí; Mis datos sin ella (F3-15); aviso de Windows no revisado |
| 53 | Parcial | Faltan `habitos.resumen_hoy`, `abrir_revision`, `abrir_pausa`; las que hay son locales |
| 54 | No | No existe "Orden de Hábitos reservada" ni el historial |
| 55 | Sí | El módulo no importa `finanzas_dominio` |
| 56 | Manual | Tres toques y 2 s en el A52 |
| 57 | Parcial | Letra 200 % bien; la fila no anuncia estado (F3-12) |
| 58 | Parcial | No manda `persona_id`, `hogar_id` ni `actualizado_en`; ids estables con UUID v5, no verificado |
| 59 | Parcial | Sin hitos de salud (solo cifras); no encontré `contenido_verificado_test` |
| 60 | Sí | Esquema y RLS |

## 8. Revisión por tema

- **Cripto y llaves:** correctos. Riesgos de diseño aceptados: el servidor puede servir una revisión anterior (la revisión viaja en el sobre, pero la fija quien lo guarda); no se hace NFC de la frase; el nombre del KDF y el salto de revisión (F3-2, F3-3). Nonces de 96 bits al azar son seguros hasta ~2^32 sobres por llave.
- **Aislamiento:** sin fugas entre personas; fallos de limpieza y de bitácora (F3-4, F3-5, F3-9, F3-10).
- **Tablets:** la pública nunca recibe llave ni recordatorios ni Hábitos; la cuenta maestra no tiene Hábitos; cubierto por SQL y pruebas de plataforma.
- **Avisos locales:** discretos; ver F3-7 y F3-8.
- **Diseño:** sin rojo ni culpa; letra grande bien; F3-12.

## 9. Pruebas agregadas por calidad

- `supabase/tests/91_calidad_fase3.sql` (21 afirmaciones, pasan).
- `supabase/tests/hallazgos_fase3.sql` (no entra en la corrida normal): F3-4, F3-5, F3-5b, F3-9, F3-10 salen ABIERTO; F3-2 y F3-3 se reproducen como error (22023 y 23514 en la nota).
- `app/test/revision_calidad/f3_cripto_test.dart` (F3-2, F3-3, F3-6 con etiqueta `hallazgo`; 4 guardias).
- `app/test/revision_calidad/f3_recordatorios_test.dart` (F3-7 y F3-8 con etiqueta `hallazgo`; 4 guardias).
- `app/test/revision_calidad/f3_dominio_test.dart` (15 guardias de bordes).
- `app/test/revision_calidad/f3_letra_grande_test.dart` (4 guardias; F3-11 y F3-12 con etiqueta `hallazgo`).
- Sin dependencias nuevas. Guion de la Biblia (no entregado): `scratchpad/hostil_biblia.dart`, reproducible con las entradas de F3-14.

## 10. Pedidos por agente

- **backend:** F3-2, F3-4, F3-5, F3-9, F3-10.
- **plataforma:** F3-3, F3-6, F3-8, tope de `vueltas`.
- **diseno:** F3-12.
- **habitos:** F3-7, F3-11, F3-13, F3-14, F3-15; flujo de activar/volver de la nube y época (criterios 36, 43).
- **asistente:** criterios 53 y 54.

## 11. Preguntas para el dueño

1. ¿Cierro la Fase 3 con la nube cifrada declarada "servidor listo, flujo de la app pendiente", o debe quedar completa (activar con frase, volver a solo teléfono, reiniciar, añadir equipo) antes de cerrar?
2. Al exportar lo reservado, ¿exigimos siempre la frase (archivo siempre cifrado) o dejamos que se pueda guardar en claro con el aviso?
3. Para la baja a 90 días: ¿cuenta desde el momento en que se desactiva la membresía? (propongo guardar esa fecha en la membresía).
4. ¿Qué edición de RVR1909 y de KJV de dominio público usamos, y quién la revisa? Sin ella el lector está vacío (P10).
5. ¿Aceptamos escribir la frase sin acentos y en mayúsculas?

---

## Estado de los hallazgos al cierre de la Fase 3 (6/nov/2026)

| Hallazgo | Estado | Quién | Nota |
|---|---|---|---|
| F3-2 (segunda subida rechazada) | Cerrado | backend | El servidor acepta cualquier revisión mayor; un conflicto no aborta el lote |
| F3-3 (nombre del KDF) | Cerrado | plataforma + backend | El cliente manda `pbkdf2-hmac-sha256`; el servidor acepta también el alias antiguo |
| F3-4 (bitácora sin tope) | Cerrado | backend | Una constancia por acción, persona y minuto |
| F3-5 (baja a 90 días) | Cerrado | backend | `membresias.desactivada_en` por trigger; probado a 89 y 91 días |
| F3-6 (frase con acentos) | Cerrado | plataforma | Se acepta sin acentos, en mayúsculas y con teclados que descomponen (decisión del dueño por confirmar) |
| F3-7 (recordatorio a medianoche) | Cerrado | habitos | |
| F3-8 (emoji partido) | Cerrado | plataforma + habitos | Recorte por grafemas |
| F3-9 (`hab_hogar_de`) | Cerrado | backend | Solo contesta por la propia sesión |
| F3-10 (cuota de filas) | Cerrado | backend | Topes por tabla; 54000 sin reintento |
| F3-11 (0 % de avance) | Cerrado | habitos | |
| F3-12 (lector de pantalla en Hoy) | Cerrado | diseno | |
| F3-13 (exportar reservado en claro) | Cerrado | habitos + plataforma | Sin frase, solo lo no sensible |
| F3-14 (importador de la Biblia) | Cerrado | habitos | `FormatException` clara y límites |
| F3-15 (Mis datos fuera de la puerta) | Cerrado | habitos | Posible doble PIN |
| Criterios 53 y 54 | Cerrado | asistente | Herramientas y historial reservado |
| Flujo para activar la nube (36, 43) | **Pendiente** | plataforma + habitos | Servidor listo; el flujo de la app queda para la siguiente ronda |
| Texto bíblico (criterio 29) | **Pendiente** | dueño | Faltan los archivos de RVR1909 y KJV |

**Veredicto de cierre:** 0 bloqueantes y 0 importantes abiertos.

