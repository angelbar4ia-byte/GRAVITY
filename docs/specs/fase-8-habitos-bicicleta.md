# Fase 8 · Hábitos: Bicicleta de los sábados (planear, salir, registrar y cuidar la bici)

> **Versión 0.1** (23/nov/2026), **propuesta** para el dueño. Es **solo especificación**: no hay código, ni SQL, ni pruebas, ni cambios en ningún `pubspec.yaml` ni en el manifiesto de Android. Escribe el agente `habitos`. El número de bloque lo asigna el arquitecto.
>
> **Base:** `CLAUDE.md`; `docs/DECISIONES.md` (D3, D5, D6, D13, D15, D21 y D29 para el estilo); `docs/ROADMAP.md` (11.1, 11.2, 11.4 y el control de cambios 3.0 sobre paquetes aprobados); `docs/specs/fase-0-cimientos.md` (sección 4); `docs/DISENO_UX_UI.md` (secciones 2, 4, 5, 6, 9, 11, 12, 20 y 21); el diseño de Hábitos v1.18 (`docs/modulos/habitos/diseno-app-habitos.md`: 5.2 «Ruta en bicicleta», 7.1 Agenda y día tipo, 9, 10, Anexo E, G.3.9, G.8, G.10.1, G.10.2 y Anexo H, etapa 7); `docs/specs/fase-8-habitos-gimnasio.md` (completa; es la referencia de estructura y de convenciones `hab_ent_*`, cola `habitos.*`, ids v5, local primero); `docs/specs/fase-8-habitos-ampliaciones.md` (formato); y el código real de `paquetes/habitos_dominio/`, `app/lib/modulos/habitos/`, `app/lib/nucleo/`, `app/lib/diseno/`, `app/pubspec.yaml`, `app/android/` y `supabase/migrations/`.
>
> **Contexto que dio el dueño y que esta especificación respeta (no lo cambia):** bicicleta propia; rutas mixtas de calle y terreno; sábados a las 8:00; unas 4 horas; a veces en pareja (pregunta abierta 6 del diseño, `diseno-app-habitos.md:718`); el sábado también tiene revisión semanal a las 14:30. Ordenó construir el gimnasio (`fase-8-habitos-gimnasio.md`, secciones 20 y 21) y pidió «además también bici».
>
> **Cómo se marca lo que se afirma.**
> - **VERIFICADO**: lo leí en el repositorio, con `archivo:línea`, o lo consulté en pub.dev el 23/nov/2026 (se dice).
> - **PROPUESTO (PB-nn)**: lo resuelvo yo en este documento; el dueño puede vetarlo. Se reúnen en la sección 12.1.
> - **Decisión del dueño, no aprobado**: depende de un paquete, un servicio o un dato personal que solo el dueño puede aprobar. **Esta especificación no recomienda instalar nada sin esa aprobación** (ROADMAP, control de cambios 3.0: los paquetes se aprueban uno por uno, con versión exacta).
> - **[no verificado]**: no pude comprobarlo en esta sesión.
>
> No hay datos personales reales: todo ejemplo (bicicleta, kilómetros, rutas, personas) es **inventado** y está marcado como ejemplo.

---

## 0. Resumen en una página

**Qué se propone.** Construir la bicicleta **en dos tiempos**:

1. **Versión 1 (B1 a B7), sin ningún paquete ni permiso nuevo.** Planear la salida del sábado como bloque de agenda, lista de preparación la noche anterior, texto fijo de seguridad, registro manual de la salida (hora, duración, distancia que escribe la persona, tipo de ruta, esfuerzo percibido), rutas guardadas **a mano** y solo en el teléfono, mantenimiento por kilómetros acumulados, enlaces a la música, al mapa y al clima de **las apps que la persona ya tiene**, y llamar o escribir al contacto de emergencia con el botón de siempre. Todo funciona sin red y sin que nada de ubicación entre a la app.
2. **Versión 2 en adelante (B8 en adelante), solo con aprobación del dueño.** GPS y grabación de la ruta, mapa y visor en vivo, pantalla encendida, importar y exportar GPX, mapas sin conexión, Health Connect con ruta, Spotify con cuenta, sensores Bluetooth y ubicación en vivo con la pareja. Cada uno necesita un paquete o un servicio que **hoy no existe** en `app/pubspec.yaml` y se presenta en la sección 3 con su licencia, costo, permisos y los datos que saldrían del teléfono.

**Lo que más pesa en el diseño.**

- **La ubicación y las rutas son datos personales sensibles**: nunca a la IA ni a la nube de IA y, en esta propuesta, **tampoco a Supabase**. Las rutas, el contacto de emergencia y cualquier punto viven en un **tipo local** del almacén de sobres (como las molestias del gimnasio, PG-03 de esa especificación), y el servidor lo rechaza por diseño. Lo que sí sube a tu hogar (con RLS, solo tú) son números sin lugar: fecha, duración, distancia, esfuerzo.
- **La regla de 48 horas no se cumple con la sesión C el jueves a las 19:15 y la ruta el sábado a las 8:00**: son 36 h 45 min, faltan 10 h 15 min (sección 4.6, **verificado con cálculo**). Además, «C corta» **no** quita el aviso, porque la regla mide de inicio a inicio. Se dan cuatro salidas y una recomendación: **A el lunes, C el martes, B el miércoles**, o bien declarar la ruta como carga ligera si así la percibe el dueño. Esta especificación **no cambia la regla del gimnasio**; pide un cambio mínimo y vetable al dominio del gimnasio (sección 12).
- **La revisión de las 14:30 sí cabe**: con la salida de 8:00 a 12:00 quedan 2 h 30 min; con un margen de 90 minutos para comer y descansar, la salida puede regresar hasta las 13:00 (sección 4.7).
- **La bicicleta no debe tener una racha que castigue el mal clima** (PB-06): el objetivo es una meta mensual de salidas, no una racha semanal.

**Qué necesito del dueño** (sección 13, con recomendación en cada una): qué parte primero; si sales en pareja; cómo sientes la carga de piernas de la ruta (decide el choque de 48 h); si mapa y visor van ahora o después, y si autorizas a `plataforma` a **medir** paquetes en una rama de prueba; Spotify o solo un enlace; cómo quieres el clima; quién es tu contacto y cómo avisarle; y los datos de tu bicicleta.

---

## 1. Resultado buscado y alcance

### 1.1 Qué entrega este bloque, por versiones

**Resultado de la versión 1.** Abrir Hábitos el viernes en la noche y saber **qué falta preparar**; el sábado, saber **a qué hora sales, cuándo regresas y si te alcanza el tiempo para la revisión**; marcar la salida como hecha en un toque, o registrarla con tres datos; ver **cuántos kilómetros lleva la bici y qué mantenimiento toca**; y abrir tu música, tu ruta o tu clima **en la app que ya usas**. Sin culpa, sin IA y sin que ninguna ubicación salga del teléfono.

| Versión | Qué entra | Paquete o servicio nuevo | Estado |
|---|---|---|---|
| **V1** (B1 a B7) | Salida del sábado como bloque de agenda; preparación del viernes; lista de preparación y seguridad por tipo de ruta; registro manual de la salida; rutas guardadas a mano (locales); mantenimiento por kilómetros escritos; carga de piernas y 48 h; revisión de las 14:30; enlaces a música, mapa y clima; llamar o escribir al contacto; Hoy, historial y ajustes | **Ninguno.** Usa `url_launcher`, `flutter_local_notifications`, `http` (sin llamarlo), `file_picker` y `flutter_tts` que **ya están** (`app/pubspec.yaml:47`, `:54`, `:62`, `:71`, `:88`) | Se puede construir al aprobar esta especificación |
| **V1.1** | Pronóstico del clima dentro de la app | Un servicio de clima (3.2) | **Decisión del dueño, no aprobado** |
| **V2** (B8 a B11) | Grabar la ruta con GPS en segundo plano; mapa y visor en vivo; pantalla encendida; modo ahorro; recuperar la salida; SOS con ubicación | Paquetes de GPS, servicio en primer plano, mapa y pantalla encendida; proveedor de teselas (3.3 a 3.6) | **Decisión del dueño, no aprobado** |
| **V2.1** | Importar y exportar GPX; mapas sin conexión; rutas favoritas con trazo | `gpx`, teselas sin conexión (3.7, 3.8) | **Decisión del dueño, no aprobado** |
| **V2.2** | Escribir la salida (con ruta) en Health Connect | `health` (3.9) | **Decisión del dueño, no aprobado** |
| **V3** | Spotify con cuenta; monitor cardiaco Bluetooth; ubicación en vivo con la pareja; reloj Wear OS | Varios (3.10 a 3.13) | **Decisión del dueño, no aprobado** |

La V1 es una **primera entrega útil sin riesgo**: no pide el permiso de ubicación (CA-B-26), no agrega paquetes y deja la bici lista para el GPS si el dueño lo aprueba. **C-1 (sección 1.6):** el diseño pone el GPS y el visor básico en su primera etapa (`diseno-app-habitos.md:1471`); esta especificación los pasa a V2 porque exigen decisiones de paquetes, batería y privacidad que no deben bloquear lo demás.

**Dónde vive cada cosa** (carpetas del agente `habitos`, `docs/ROADMAP.md` 11.2):

| Pieza | Carpeta | Estado |
|---|---|---|
| Dominio puro (reglas, tiempos, mantenimiento, carga) | `paquetes/habitos_dominio/lib/src/bicicleta/` (el paquete no tiene dependencias) | Por escribir (B1) |
| Casos de uso, estado y pantallas | `app/lib/modulos/habitos/bicicleta/` (carpeta nueva dentro de las propias) | Por escribir (B5) |
| Tablas `hab_bici_*` y `hab_musica_listas`, RLS y pruebas SQL | `supabase/migrations/` y `supabase/tests/` (agente `backend`) | Por escribir (B2) |
| Tipo local de ubicación, cola, recordatorios, `<queries>` | `app/lib/nucleo/` (agente `plataforma`) y `app/android/` | Por escribir (B3) |
| Componentes y gadgets | `app/lib/diseno/` (agente `diseno`); ya existen la personalidad `Submodulo.bici` y el gadget `Velocimetro` (HB-12) | Por escribir (B4) |

### 1.2 Qué NO es (límites que se dicen en la app)

| No es | Cómo se dice y se cumple |
|---|---|
| **Un entrenador de ciclismo ni consejo médico** | Línea fija: «Esta guía no sustituye tu prudencia, las reglas de tránsito ni a un profesional. Ajusta la salida a cómo te sientes, al clima y al camino.» Se muestra al abrir por primera vez (se pide «Entendido» y se guarda la fecha) y bajo la lista de preparación. **No diagnostica, no recomienda tratamientos ni medicamentos, no da cifras de líquidos ni de comida** (el diseño lo fija: `diseno-app-habitos.md:1399`). Una prueba automática impide esas palabras (CA-B-01) |
| **Una navegación** | La V1 no calcula rutas ni guía. En la V2 muestra el trazo y avisa del desvío; no da instrucciones giro a giro |
| **Un sistema de vigilancia ni de rescate** | **Nadie recibe un aviso automático si no regresas.** La app lo dice con esas palabras donde se comparte la hora de regreso. La V1 no sabe dónde estás. El SOS de la V1 es **llamar o escribir** a tu contacto con el botón del teléfono (no envía ubicación) |
| **Una competencia** | Sin clasificaciones, sin comparación con otras personas, sin segmentos |
| **Un plan de dieta** | La salida solo recuerda «lleva agua y algo fácil de comer»; sin gramos, sin calorías, sin litros |
| **Una IA** | Ninguna función de este bloque llama a una IA (CA-B-27) |

### 1.3 Queda fuera de este bloque

| Queda fuera | Va a |
|---|---|
| **La lista de música como módulo** (listas por persona, controles) | Bloque de música; aquí solo se guarda un enlace por lista y se abre con el botón (3.12, `hab_musica_listas`). **El botón «Abrir mi lista» del gimnasio** (`fase-8-habitos-gimnasio.md:703`) usa la misma tabla |
| **Sueño** (registro y plan de transición) | Etapa 6 del diseño; aquí solo se lee la hora de dormir y se usa «¿Cómo amaneciste?» (4.8) |
| **Ejercicio de fuerza** | `fase-8-habitos-gimnasio.md`; aquí solo la regla de piernas y 48 h (4.6) |
| **Compartir con la pareja** (ruta, avance, ubicación) | V3 y solo con decisión del dueño (7.4); la V1 no comparte nada por el servidor |
| **IA** (coach de ruta, resumen) | No existe en este bloque; si algún día se propone, **la ubicación y las rutas nunca se envían** (sección 7) |
| **Personas bajo cuidado** | No usan Hábitos (D5) |
| **Ciclocomputador, relojes y sensores propios del dueño** | V3; la V1 acepta que la persona escriba lo que su aparato marque |

### 1.4 Reglas que no se rompen

| # | Regla | De dónde sale | Cómo se cumple aquí |
|---|---|---|---|
| RB1 | **Ubicación, rutas y salud nunca a la IA en la nube ni a las bocinas** | D3, D6; diseño `:1466` («privados por defecto, sin enviarse a la IA ni a la app de Presupuesto, y borrables») | Ninguna función de este bloque llama a una IA; ninguna herramienta de GRAVITY devuelve rutas, puntos, contacto ni cifras de salidas; nada se dice por bocinas (sección 7) |
| RB2 | **Hábitos es personal**: cada persona ve solo lo suyo; la cuenta maestra no lo lee | D5, D21, `fase-3-habitos.md:66` | Las tablas usan la misma regla que `hab_*`: `persona_id = persona_actual()` y `hab_activa(hogar_id)` |
| RB3 | **Sin bitácora, prefijo reservado** | D21; `20261105000000_habitos.sql:426-455` (HB-09 de la especificación del gimnasio) | Tablas `hab_bici_*` y `hab_musica_listas`: ya las cubre el prefijo `hab_` |
| RB4 | **Sin contadores guardados**: el kilometraje de la bici, la semana, lo vencido, el promedio y la progresión **se calculan** | `fase-3-habitos.md:68` (convención 3) | El servidor guarda hechos (salidas, mantenimientos, lecturas del odómetro); el dominio calcula (5.3) |
| RB5 | **Semana en lunes, UUID del dispositivo, enteros** | `fase-0-cimientos.md:61-72` | Distancia en **metros** enteros, desnivel en metros enteros, minutos enteros; ninguna cifra es `double` |
| RB6 | **Tono sin culpa; acción diaria en 3 toques o menos** | `.claude/agents/habitos.md`; `fase-3-habitos.md:73` | Marcar la salida como hecha es **1 toque** y no obliga a registrar nada más (6.2); catálogo de mensajes con revisión automática (CA-B-08) |
| RB7 | **La app funciona completa sin IA, sin red y sin las otras apps** | `.claude/agents/habitos.md` | La V1 es local; los enlaces dicen «no se pudo abrir» si la app no está instalada y no se rompe nada |
| RB8 | **Nada fijo en el código de las pantallas**: horarios, intervalos y reglas son datos editables | Diseño `:72`; `fase-3-habitos.md:74` | Los valores de 4 viven en `ReglasBicicleta` y se editan en Ajustes |
| RB9 | **Sin secretos ni datos reales en el repositorio** | `CLAUDE.md` | Los ejemplos de este documento son inventados |
| RB10 | **No se instala ningún paquete sin aprobación del dueño** | ROADMAP, control de cambios 3.0 | La V1 no agrega ninguno (CA-B-26); todo lo demás está marcado «decisión del dueño, no aprobado» |

### 1.5 Lo verificado en el repositorio y en el diseño

| # | Hallazgo | Fuente |
|---|---|---|
| HB-01 | El diseño define la ruta del sábado: 8:00 (editable), unas 4 h, recordatorio de preparación (agua, casco, luces y clima) la noche anterior o 30 min antes; planificador de rutas con distancia, desnivel y tiempo; seguimiento por GPS; progresión gradual «sin saltos bruscos»; seguridad (casco, luces, hidratación, revisión, clima, contacto de emergencia); rutas mixtas con superficie por tramo y dificultad; recordatorio de mantenimiento «según kilómetros recorridos»; opcional en pareja | `diseno-app-habitos.md:266-277` |
| HB-02 | El Anexo E detalla la salida: noche anterior (preparación), ~7:15 (aviso de salida: desayuno ligero, cargar el teléfono, compartir hora estimada de regreso), 8:00 (inicio), durante (hidratación y comida a intervalos), ~12:00 (cierre), después comida, descanso y revisión a las 14:30 con aviso a las 14:15. La app **no fija montos de comida ni de líquidos**. Tras una salida larga reduce la carga del sábado y sugiere un domingo ligero | `diseno-app-habitos.md:1385-1399` |
| HB-03 | El visor (E.2) pide mapa, ruta planeada y recorrida, datos en vivo, elevación, superficie por tramo, favoritas, **mapas sin conexión («imprescindible en 4 horas y tramos sin señal»)**, GPX, puntos útiles, clima, ubicación en vivo con la pareja, contacto de emergencia, modo ahorro y resumen. Nota técnica: OpenStreetMap con un proveedor de teselas adecuado **«el servidor público de OSM no está pensado para uso intensivo»**; GPS en segundo plano con servicio en primer plano y notificación | `diseno-app-habitos.md:1401-1425` |
| HB-04 | Música (E.3): etapa 1 sin integración (enlaces y controles de medios de Android, sirve con Spotify, **Amazon Music** y otras); etapa 2 Spotify con cuenta. El diseño recuerda que Spotify en modo desarrollo exige Premium al dueño de la app, limita a 5 usuarios y cambió endpoints en febrero de 2026, y manda **verificar lo vigente antes de programar**. La pareja usa Amazon Music: solo etapa 1 | `diseno-app-habitos.md:1427-1446` |
| HB-05 | Seguridad (E.4): casco, luces, ropa visible, frenos y llantas; **audífonos con escucha exterior en tramos de calle**; aviso de hora de regreso a una persona de confianza; alerta de calor y clima; si el usuario se siente mal, «detenerse y buscar ayuda»; ante una caída o inactividad, opción de enviar la ubicación al contacto | `diseno-app-habitos.md:1448-1454` |
| HB-06 | Modelo de datos del diseño: `RutaBici`, `SalidaBici`, `PuntoRuta`, `ListaMusica`, `SesionMusica`. **Los puntos de ruta son datos de ubicación sensibles**: privados por defecto, sin IA, sin Presupuesto, borrables | `diseno-app-habitos.md:1456-1466` |
| HB-07 | La pantalla G.3.9 y la ficha P21 (G.10.2): tres fases (Planear, En vivo, Resumen); **Terminar exige mantener 2 s**; bloqueo táctil; SOS; modo ahorro con pantalla atenuada; recuperar la salida si la app se cierra; permisos de ubicación precisa, segundo plano, notificaciones y Health Connect; criterios (4 h grabadas con pantalla apagada y sin conexión, batería razonable, música baja cuando la app habla) | `diseno-app-habitos.md:1942-1957`, `:2233-2299` |
| HB-08 | La accesibilidad de la bici: «pantalla atenuada y botones grandes; el mapa no pide interacción en movimiento» y «nunca se exige leer ni tocar la pantalla mientras se maneja» | `diseno-app-habitos.md:2168-2172`; `DISENO_UX_UI.md:194`, `:363` |
| HB-09 | **Hoy** muestra la «tarjeta de ruta a las 8:00 y de revisión semanal a las 14:30 (con aviso a las 14:15)» el sábado. Health Connect: en Android 13 o anterior es una app aparte; verificar antes de ofrecerlo | `diseno-app-habitos.md:2200`, `:844` |
| HB-10 | La hoja de ruta del diseño pone «ruta en bicicleta con visor de ruta» en v1.1; el Anexo H la pone en la **etapa 7 «Bicicleta y música»** (tras la etapa 6 de Salud) y su aceptación es «una salida de 4 horas se graba completa; la música baja cuando la app habla» | `diseno-app-habitos.md:674`, `:2418`, `:2454-2456`; `docs/ROADMAP.md:173` |
| HB-11 | **No hay en `app/pubspec.yaml` ningún paquete de mapas, GPS, Spotify, pantalla encendida, Bluetooth ni Health Connect.** Sí hay `url_launcher` (47), `flutter_local_notifications` 22.3.2 (54), `http` (62), `file_picker` (71), `connectivity_plus` (74), `flutter_tts` 4.2.5 (88) y `audioplayers` 6.8.1 (98), aprobados para el motor de voz. El manifiesto **no declara permisos de ubicación**: solo `INTERNET`, `USE_BIOMETRIC`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `VIBRATE`, `CAMERA` y `RECORD_AUDIO`; **no hay `FOREGROUND_SERVICE`** y `<queries>` solo declara tres intents (texto, reconocimiento de voz, `TTS_SERVICE`) | `app/pubspec.yaml`; `app/android/app/src/main/AndroidManifest.xml:3-19`, `:80-95` |
| HB-12 | **Ya existen la personalidad y un gadget estático:** `Submodulo.bici` usa la personalidad Sport y «siempre alto contraste»; el gadget `Velocimetro` (número enorme, arco de apoyo, texto para lector de pantalla) está construido con datos de ejemplo; la tira de la semana del gimnasio ya dibuja la bicicleta del sábado con aviso | `app/lib/diseno/personalidad_modulo.dart:4`, `:17`, `:208`; `app/lib/diseno/gadgets/futuros.dart:547-590`; `app/lib/diseno/gimnasio/linea_semana.dart:2`, `maquetas.dart:140-150` |
| HB-13 | **Recordatorios locales de Hábitos:** siete tipos con títulos de máximo 40 caracteres, sin dígitos ni nombres; lo sensible sale como «Recordatorio» por el canal Reservados. Un bloque trae `recordar_min` (0 a 1440) y la pareja de tipos de bloque es `actividad`, `trabajo`, `traslado`, `revision`, `cita`; el área `salud` existe | `app/lib/nucleo/avisos/recordatorios_habitos.dart:25-45`; `supabase/migrations/20261105000000_habitos.sql:134-157` |
| HB-14 | **La revisión semanal y la hora de dormir ya son datos editables:** `hab_ajustes.revision_dia` (6), `revision_hora` (`14:30`), `revision_aviso_min` (15), `despertar` y `dormir` | `20261105000000_habitos.sql:67-72` |
| HB-15 | **La regla de 48 horas del gimnasio ya cuenta la bicicleta como piernas** (`gruposDeTipo` da `{cuadriceps, gluteo}` a `bici`), mide **de inicio a inicio** (`b.inicio.difference(a.inicio)`) con un mínimo de `48 h − 60 min` (`minimoEntreSesionesMin`), y con la sesión C propone mover al jueves (solo si C es viernes), `versionCorta` o `dejarComoEsta`. La bicicleta es un tipo de día del plan (`TipoDia.bici`) sin ninguna otra lógica | `paquetes/habitos_dominio/lib/src/gimnasio/plan_semana.dart:14`, `:101-105`, `:121`, `:150-171`; `reglas.dart:185` |
| HB-16 | **Los tipos sensibles son dos y el servidor solo acepta sobres de esos dos** (`check (tipo in ('habitos_sensibles','diario_oracion'))`); el enum de la app tiene los mismos dos valores. El tercer tipo local `salud_local` que propone el gimnasio (PG-03) **aún no está construido** (G3 sin hacer). La base local y el respaldo automático de Android están apagados (`allowBackup="false"`) | `supabase/migrations/20261106000000_habitos_sensibles.sql:17`; `app/lib/nucleo/sensibles/llaves_habitos.dart:31-37`; `AndroidManifest.xml:24-31`; `fase-8-habitos-gimnasio.md:999-1010` |
| HB-17 | **Cola sin conexión:** los prefijos `habitos.`, `finanzas.` y `cuidados.` son personales; Hábitos hoy escribe directo con `upsert` y la cola no conoce sus tablas (el gimnasio pide a `plataforma` agregarlas) | `app/lib/nucleo/cola/cola_sin_conexion.dart:61-69`; `fase-8-habitos-gimnasio.md:724` (HB-12 de esa especificación) |
| HB-18 | **El modo foco no está conectado a Hoy ni a los recordatorios** y el gimnasio define una interfaz sin causa `ModoFocoActivo.para(fecha) → bool` que implementará G5 | `fase-8-habitos-gimnasio.md:689-691` (HB-13 de esa especificación) |
| HB-19 | **El único uso actual de `url_launcher`** es abrir una página con el navegador (`launchUrl(..., externalApplication)`); ningún código lo usa para abrir música, mapas, llamadas ni mensajes | `app/lib/modulos/ajustes/desarrollador/abrir_swagger.dart:20-22` |
| HB-20 | **Las metas semanales rompen la racha** («una semana incompleta rompe y no hay día de gracia») y existen **pausas declaradas** (`hab_pausas`); los tipos de objetivo son `construir`, `meta` y `proyecto` y las frecuencias `diaria`, `diasSemana`, `nPorSemana`, `semanal`, `total` | `fase-8-habitos-gimnasio.md:597`; `20261105000000_habitos.sql:179`; `paquetes/habitos_dominio/lib/src/objetivos.dart:1-3` |
| HB-21 | **Pantalla encendida en el gimnasio:** quedó «sin hacer hasta que `plataforma` lo evalúe y el dueño apruebe el paquete o el canal nativo» | `fase-8-habitos-gimnasio.md:995` |

**Lo verificado hoy en pub.dev (23/nov/2026, versión más reciente, fecha de publicación y licencia):**

| Paquete | Versión | Publicada | Licencia | Plataformas |
|---|---|---|---|---|
| `geolocator` | 14.1.2 | 19/oct/2026 | no aparece como etiqueta en pub.dev **[no verificado en el repositorio del paquete]** | Android, iOS, Windows, Linux, macOS, web |
| `flutter_foreground_task` | 11.0.3 | 7/sep/2026 | MIT | Android, iOS |
| `wakelock_plus` | 1.8.2 | 22/oct/2026 | no aparece como etiqueta **[no verificado]** | Android, iOS, Windows, Linux, macOS, web |
| `flutter_map` | 8.3.2 | 27/ago/2026 | BSD-3-Clause | Android, iOS, Windows, Linux, macOS, web |
| `latlong2` | 0.10.1 | 27/abr/2026 | Apache-2.0 | todas |
| `maplibre_gl` | 0.28.0 | 3/nov/2026 | BSD-3-Clause | **Android, iOS y web (no Windows)** |
| `gpx` | 2.5.0 | 8/jul/2026 | Apache-2.0 | todas |
| `health` | 14.0.0 | **20/nov/2026 (3 días)** | MIT | Android, iOS |
| `spotify_sdk` | 4.3.4 | 23/oct/2026 | Apache-2.0 | Android, iOS, web |
| `flutter_blue_plus` | 2.3.15 | 5/nov/2026 | **licencia propia** (`LICENSE.md` 1.6: libre para uso personal, de investigación, sin fines de lucro y educativo; **requiere licencia comercial el uso con fines de lucro**) | todas |
| `flutter_background_geolocation` | 5.10.0 | 23/nov/2026 | Apache-2.0 en pub.dev, pero **la página del paquete dice que requiere licencia de pago para compilaciones de producción (release) en Android e iOS** | Android, iOS |

Cada versión de pub.dev que se vaya a fijar debe cumplir la regla de `app/pubspec.yaml` (más de dos semanas de publicada): hoy `health` 14.0.0 **no** la cumple. No pude consultar en esta sesión las políticas de teselas de OpenStreetMap ni los términos de Open-Meteo (el acceso estaba bloqueado): **[no verificado]**.

### 1.6 Conflictos y desajustes con otras decisiones (para el arquitecto)

| # | Conflicto | Propuesta |
|---|---|---|
| CB-1 | El diseño pone el GPS y el visor en la primera etapa (`:1471`) y la hoja de ruta en v1.1 | V1 sin paquetes; GPS y visor en V2, con aprobación (sección 3). Actualizar `diseno-app-habitos.md:1468-1473` |
| CB-2 | **48 horas:** con C el jueves a las 19:15 el intervalo es 36 h 45 min (2205 min) contra un mínimo de 47 h (2820 min): faltan 615 min. El jueves **no** cierra el choque (`fase-8-habitos-gimnasio.md:1004`) y **«C corta» no lo cierra** porque la regla es de inicio a inicio (HB-15). Además, con C el jueves la propuesta `moverAlJueves` ya no aparece (solo si C es viernes: `plan_semana.dart:158`) y quedan solo `versionCorta` y `dejarComoEsta` | Sección 4.6: cuatro salidas y una recomendación (C el martes). **No se cambia la regla a escondidas**; se pide un cambio mínimo y vetable al dominio del gimnasio (sección 12) |
| CB-3 | El Anexo E dice «la sesión de fuerza del viernes se ajusta si el usuario reporta cansancio» (`:1398`); con la decisión del dueño la sesión C ya no es el viernes | Actualizar la frase del diseño; la regla de cansancio se aplica a la última sesión de piernas, sea cual sea el día (4.6) |
| CB-4 | El Anexo E.4 lista síntomas («mareo, dolor en el pecho, confusión», `:1453`); la especificación del gimnasio prohíbe en su contenido diagnósticos, tratamientos y nombres de lesión (CA-G-03) | Texto genérico: «Si te sientes mal durante la salida, detente en un lugar seguro y pide ayuda. Si el malestar es fuerte o no cede, llama a emergencias o consulta a un médico» (PB-19). El dueño puede restaurar la lista |
| CB-5 | D21 fija **dos** tipos sensibles; el gimnasio propone un tercero local (`salud_local`) y todavía no está construido (HB-16). La ubicación necesita otro tipo local | Que G3 construya los tipos locales como **una sola lista con una marca «solo local»**, de modo que `salud_local` y `ubicacion_local` sean datos y no dos desarrollos (PB-03). Ampliación de D21: requiere visto bueno |
| CB-6 | La regla 109 de la Fase 3 dice que **no se comparte nada con la pareja**; el diseño pide ubicación en vivo con la pareja (`:1415`) y el compartir de la ruta (`:276`) | V1 no comparte por el servidor; V3 solo con la decisión del dueño y el mecanismo de consentimiento (7.4) |
| CB-7 | La pantalla encendida quedó sin decidir en el gimnasio (HB-21) | Una sola decisión para los dos bloques (3.5) |
| CB-8 | Una meta semanal «Bicicleta» rompería la racha con la lluvia o el calor (HB-20), contra el tono sin culpa y contra la seguridad | PB-06: meta mensual de salidas, sin racha semanal |
| CB-9 | El Anexo E.3 supone Spotify; la pareja usa Amazon Music y el diseño dice que se vuelva a revisar si Amazon abre su API (`:1445`) | V1: solo enlaces (cubre las dos); V3: Spotify solo para quien lo tenga |

---

## 2. Convenciones y palabras

Se aplican las convenciones de `fase-0-cimientos.md` (sección 4) y las de la Fase 3 y del gimnasio. Identificadores en español sin acentos (`Salida`, `Ruta`, `Bicicleta`, `Mantenimiento`); textos de la interfaz en español de México con acentos y de tú.

| Palabra | Significa aquí |
|---|---|
| **Salida** | Una vez que sales en la bici: fecha, duración, distancia, tipo de ruta, esfuerzo |
| **Ruta** | Un recorrido guardado **solo en el teléfono**: nombre, distancia, desnivel, tramos por superficie, enlace que la persona pegó. En la V2, además, el trazo |
| **Superficie** | `calle`, `ciclovia`, `terreno` (por tramo) y, para la salida completa, `calle`, `terreno` o `mixta` |
| **Preparación** | La lista de lo que se revisa y se lleva; hay una **del viernes en la noche** y una **antes de salir** |
| **Odómetro** | Los kilómetros de la bici: **se calcula** (5.3); no es un contador guardado |
| **Lectura** | Un dato que la persona escribe de su ciclocomputador o de su app: «hoy marca X km»; fija el odómetro de ese día |
| **Mantenimiento** | Una tarea de cuidado de la bici (lubricar la cadena, limpiar, revisar frenos y llantas, revisión general) con su intervalo en kilómetros y en semanas |
| **Esfuerzo percibido** | 1 a 5 (el mismo del gimnasio, PG-12): 1 muy ligero, 2 ligero, 3 moderado, 4 duro, 5 al límite |
| **Carga de piernas de la ruta** | Si la salida cuenta como trabajo de cuádriceps y glúteo para la regla de 48 h: `normal`, `ligera` o `por_esfuerzo` (4.6) |
| **Contacto de confianza** | La persona a quien se avisa la hora de regreso y se llama en una emergencia; vive solo en el teléfono |
| **Tipo local de ubicación** (`ubicacion_local`) | El documento del almacén de sobres que guarda rutas, contacto y, en la V2, trazos; nunca sale del equipo (7.1) |

**Convenciones propias de este bloque**

1. **El dominio es Dart puro, sin dependencias y sin reloj propio:** recibe `hoy`; usa `soloDia`, `lunesDe`, `mascaraDia`, `diasEntre` y `redondearMitadArriba` de `paquetes/habitos_dominio/lib/src/fecha.dart`; minutos, metros y kilómetros-por-diez como `int`.
2. **Distancias en metros enteros**; en pantalla se muestran en kilómetros con un decimal (`62,4 km`). Nunca `double` en dominio ni en servidor.
3. **Ids:** UUID v5 para lo que no debe duplicarse al reintentar (la salida de un día por su número del día, el mantenimiento por bicicleta, tarea y fecha), v4 para lo demás (`fase-3-habitos.md:70`).
4. **Último cambio gana** (`modificado_en`) en lo editable; **sin filas solo-agregar** (para que «Borrar mis datos» funcione sin variante especial).
5. **Cada cifra de reglas vive en un solo lugar** (`ReglasBicicleta`) y se edita en Ajustes donde dice 4.
6. **Los textos salen de un catálogo cerrado** con revisión automática (CA-B-01, CA-B-08, CA-B-31); el dominio devuelve **códigos** de aviso, no texto.

---

## 3. Qué entra sin paquetes y qué necesita paquetes o servicios (decisiones del dueño)

### 3.1 La V1 sin paquetes nuevos

La V1 usa solo lo que **ya existe** (HB-11, HB-19):

| Necesidad | Cómo se resuelve sin paquete nuevo |
|---|---|
| Bloques de agenda y recordatorios | `hab_bloques` con `recordar_min` y los recordatorios locales existentes (HB-13) |
| Abrir música, mapa o clima | `url_launcher` (`launchUrl`, modo `externalApplication`) con una dirección `https` que la persona guardó. Si la app no está instalada, abre el navegador o dice «No se pudo abrir» |
| Llamar o escribir al contacto | `url_launcher` con `tel:` y `sms:` (el teléfono abre su marcador o su aplicación de mensajes; **la persona toca Enviar**; la app **no** pide permiso de SMS ni de contactos) |
| Cronómetro de la salida | Instantes guardados (como el temporizador del gimnasio): sobrevive a cerrar la app; no requiere pantalla encendida ni servicio en primer plano |
| Importar un GPX o una lista | `file_picker` (ya está): **no se usa en la V1**; el GPX no se interpreta hasta la V2.1 |
| Voz | `flutter_tts` (ya aprobado para el motor de voz): solo V2, para recordatorios de hidratación |

**Cambios que sí necesita la V1 fuera del `pubspec`** (los hace `plataforma`, sección 12; ninguno pide un permiso nuevo ni sale del teléfono): `<queries>` en el manifiesto para poder comprobar si una app puede abrir `https`, `tel`, `sms` y `geo` (Android 11 o más); títulos nuevos en el catálogo de recordatorios; y el tipo local de ubicación (7.1).

### 3.2 Clima (V1.1)

| Opción | Qué sale del teléfono | Costo y licencia | Estado |
|---|---|---|---|
| **A. Casillas y enlace (V1, recomendada)** | **Nada.** La persona abre su app de clima (enlace que ella guardó) y marca «Despejado, Nublado, Posible lluvia, Mucho calor, Frío». La app responde con un texto fijo (4.3) | Ninguno | Entra en la V1 |
| **B. Pronóstico dentro de la app con un servicio gratuito** (por ejemplo Open-Meteo, que no pide clave para uso no comercial **[no verificado en esta sesión: términos y límites]**) | Una petición HTTPS con **coordenadas** del lugar de salida (se redondean a una décima, unos 11 km, antes de enviarlas) y la IP. No usa ningún paquete nuevo (`http` ya está), pero **es un servicio externo** | Gratuito según el proveedor **[no verificado]**; sin clave | **Decisión del dueño, no aprobado** |
| **C. Servicio con clave** | Igual que B, más una clave que no puede ir dentro de la app (D7: iría en la función del servidor) | Depende del proveedor | No se recomienda |

El clima **nunca se pide sin que la persona toque «Ver el clima»** y nunca se guarda la consulta (PB-09).

### 3.3 GPS y grabación de la ruta (V2) — **decisión del dueño, no aprobado**

| | |
|---|---|
| **Qué haría falta** | Un paquete de ubicación (candidato: `geolocator` 14.1.2) y un **servicio en primer plano con notificación visible** para que Android no detenga el GPS con la pantalla apagada (candidatos: `flutter_foreground_task` 11.0.3, MIT, solo Android; o la propia configuración de notificación de `geolocator` **[no verificado]**) |
| **Descartado** | `flutter_background_geolocation` 5.10.0: **licencia de pago para compilaciones de producción** (verificado en su página de pub.dev, 23/nov/2026). Contradice el costo cero de D7 |
| **Costo y licencia** | Sin costo; licencias de `flutter_foreground_task` verificada (MIT); la de `geolocator` **no verificada** |
| **Permisos de Android** (`plataforma` confirma los nombres exactos y si hace falta el de segundo plano) | Ubicación precisa y aproximada (`ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`); servicio en primer plano de tipo ubicación (`FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, Android 14 o más); notificaciones (`POST_NOTIFICATIONS`, **ya declarado**); y, solo si lo exige la medición, ubicación en segundo plano |
| **Qué datos salen del teléfono** | **Ninguno por parte de GRAVITY**: el trazo se guarda en el tipo local (7.1). Aviso honesto: en Android, el sistema de ubicación (que usa los servicios de Google Play cuando están) puede tratar la posición según las políticas de Google; no depende de la app **[no verificado cómo se comporta `geolocator` con `forceLocationManager`]** |
| **Riesgos** | Batería en 4 h (R-B-1); señal débil (R-B-2); el sistema puede cerrar la app (recuperar la salida, CA-B-41) |
| **Antes de decidir** | `plataforma` mide en el Galaxy A52 una salida simulada de 4 h con la pantalla apagada (B8); el dueño decide con las mediciones |

### 3.4 Mapa y visor en vivo (V2) — **decisión del dueño, no aprobado**

| Opción | Licencia | Plataformas | Datos que salen | Comentario |
|---|---|---|---|---|
| **`flutter_map` 8.3.2 + `latlong2` 0.10.1** (teselas raster) | BSD-3 y Apache-2.0 (verificado) | **Android y Windows** (y el resto) | Cada tesela pedida revela **la zona que miras** (coordenadas de la tesela), la IP y el agente al **proveedor de teselas** | Es la única opción verificada que también corre en la **laptop** |
| **`maplibre_gl` 0.28.0** (teselas vectoriales) | BSD-3 (verificado) | **Android, iOS y web; no Windows** | Igual, al proveedor de teselas | Mejor para mapas sin conexión; no sirve para ver la ruta en la laptop |
| **SDK comercial de mapas** (el diseño lo menciona: `:1421`) | Propia | — | A un tercero con cuenta | No se evaluó; contradice el costo cero salvo plan gratuito **[no verificado]** |

**Proveedor de teselas (decisión aparte).** El diseño (HB-03) avisa que el servidor público de OpenStreetMap no es para uso intensivo; su política **no pude consultarla hoy** **[no verificado]**. Opciones: (a) un proveedor comercial con plan gratuito y clave (la clave **no** puede ir dentro de la app: se pediría una función en el servidor o un proxy, decisión de `asistente` y `backend`, costo **[no verificado]**); (b) un archivo de teselas de **la región** (por ejemplo PMTiles) alojado en el Storage de Supabase: cabe en el plan gratuito solo si ocupa una fracción del **1 GB** de D7 (el tamaño de la región se mide, **[no verificado]**), y lo que se descarga es un mapa público, no un dato personal. Se recomienda **medir (b) antes de elegir**.

### 3.5 Pantalla encendida y pantalla atenuada (V2) — **decisión del dueño, no aprobado**

| | |
|---|---|
| **Qué haría falta** | Un paquete de pantalla encendida (candidato: `wakelock_plus` 1.8.2, licencia **[no verificado]**) o un canal nativo. **Es la misma decisión que el gimnasio dejó sin tomar** (HB-21): aprobar una sola vez sirve a los dos |
| **Atenuar la pantalla** | Cambiar el brillo del sistema pide otro paquete **[no evaluado]**. **Propuesta PB-16 sin paquete:** un **modo ahorro en la propia interfaz** (fondo negro, números grandes, sin animaciones, sin mapa) que gasta menos en pantallas OLED **[no verificado en el A52]**; el brillo real lo baja la persona con el sistema |
| **Permisos** | `WAKE_LOCK` (permiso normal, sin ventana de aviso) **[plataforma confirma]** |
| **Datos que salen** | Ninguno |

### 3.6 Música con Spotify (V3) — **decisión del dueño, no aprobado**

| | |
|---|---|
| **Qué haría falta** | `spotify_sdk` 4.3.4 (Apache-2.0, verificado) y una app registrada en el panel de desarrolladores de Spotify (con la cuenta Premium del dueño; los límites vigentes del modo desarrollo —Premium para quien registra, 5 usuarios— los **dice el diseño** y manda **verificarlos antes de programar**, `:1442`) |
| **Permisos y cambios de manifiesto** | `<queries>` del paquete de Spotify y el esquema de retorno de la autenticación (`plataforma`) |
| **Datos que salen** | La autenticación y el estado de reproducción van a **Spotify**; GRAVITY solo guarda el enlace de cada lista. **El diseño prohíbe enviar datos de música a la IA** (`:1446`) |
| **Pareja** | Usa Amazon Music, cuya API el diseño da por cerrada (`:1445`): solo enlaces |
| **Recomendación** | **No integrar.** Los enlaces de la V1 (3.12) dan lo mismo para elegir la lista, y los controles de medios de Android dan pausa y salto sin ningún paquete. La integración solo agrega «ver lo que suena dentro del visor» |

### 3.7 Importar y exportar GPX (V2.1) — **decisión del dueño, no aprobado**

| | |
|---|---|
| **Qué haría falta** | `gpx` 2.5.0 (Apache-2.0, verificado) para leer y escribir; `file_picker` (ya está) para elegir el archivo y para guardarlo |
| **Datos que salen** | Ninguno mientras el archivo se queda en el teléfono. **Al exportar o compartir un GPX el trazo sale por lo que la persona elija** (otra app, un correo): **riesgo de revelar el domicilio** si la ruta empieza y termina en casa. **PB-17:** al exportar se **recortan por omisión los primeros y últimos 200 m** (editable) y se avisa antes de compartir (el diseño ya pide avisar antes de compartir datos de salud: `:663`) |
| **Compartir con la hoja de Android** | Pide otro paquete **[no evaluado]**; mientras tanto el GPX se guarda en una carpeta que elige la persona con `file_picker` |

### 3.8 Mapas sin conexión (V2.1) — **decisión del dueño, no aprobado**

Imprescindibles en 4 horas y con tramos sin señal (HB-03). Necesitan un almacén de teselas (con `flutter_map`, un paquete de caché de teselas **[no evaluado]**; con `maplibre_gl`, paquetes de región propios del proveedor **[no verificado]**), espacio en el teléfono y la decisión del proveedor de 3.4. Se descargan **antes de salir con Wi-Fi** (`connectivity_plus`, ya está) y la app **avisa antes de salir si faltan** (CA-B-44).

### 3.9 Health Connect con ruta (V2.2) — **decisión del dueño, no aprobado**

| | |
|---|---|
| **Qué haría falta** | `health` (MIT, verificado). La versión más reciente (14.0.0) tiene 3 días: **no cumple la regla de dos semanas de `pubspec.yaml`**; `plataforma` fija la última que sí la cumpla |
| **Capacidades verificadas hoy en su página** | Escribe sesiones de ejercicio y **rutas GPS** en Android (`startWorkoutRoute`, `insertWorkoutRouteData`). **El permiso de «Rutas de ejercicio» no lo pide el paquete:** la persona tiene que darlo en la app de Health Connect («Permitir siempre»), así que hace falta una pantalla de ayuda |
| **Permisos** | Los de escritura de ejercicio y de ruta de Health Connect, más la actividad que explica su uso (`plataforma` confirma los nombres). En Android 13 o anterior Health Connect es una app aparte que debe estar instalada (HB-09) |
| **Qué datos salen del teléfono** | Hacia **Health Connect**, que vive en el teléfono; otras apps que la persona autorice allí podrán leerlo y sincronizarlo a su propia nube: eso lo decide la persona en Health Connect, no GRAVITY |
| **Reglas** | Solo con permiso explícito pedido en el momento; solo **tipo bicicleta, hora de inicio y fin, distancia y ruta**; **nunca** esfuerzo, notas, contacto ni mantenimiento; un interruptor por tipo de dato y por persona; ruta solo si la persona activa «Incluir la ruta» (apagado por omisión) |
| **Consecuencia** | El trazo, que vivía solo en el almacén local de la app, pasa también a Health Connect: **es una decisión de privacidad**, no solo técnica |

### 3.10 Monitor de frecuencia cardiaca por Bluetooth (V3) — **decisión del dueño, no aprobado**

Candidato `flutter_blue_plus` 2.3.15 con **licencia propia** (verificado): libre para uso personal y sin fines de lucro; **un uso con fines de lucro exige licencia comercial**. GRAVITY es una app familiar; la decisión de si cae en el uso personal es del dueño. Permisos de Bluetooth de Android 12 o más (`BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`). **La frecuencia cardiaca es un dato de salud:** viviría en el tipo local de salud del gimnasio (`salud_local`), nunca en el servidor ni en la IA. No hay alternativa evaluada.

### 3.11 Ubicación en vivo con la pareja y SOS con ubicación (V3 y V2) — **decisión del dueño, no aprobado**

El SOS con ubicación de la V2 **compone un texto con la última posición** que la persona envía con su aplicación de mensajes (sin permiso de SMS). Compartir la ubicación **en vivo** con la pareja exige un servicio que envíe posiciones a otra persona (Supabase Realtime u otro): pasa por los datos del hogar, rompe la regla 109 de la Fase 3 y es **ubicación sensible fuera del teléfono**. Se describe el consentimiento en 7.4; **no se recomienda hasta que el dueño lo decida** (pregunta 2).

### 3.12 Música en la V1: enlaces

Una lista de música es **un enlace `https`** (de Spotify, de Amazon Music o de otra app) guardado con su nombre y su actividad (`bicicleta`, `fuerza`, `regenerativo`, `traslado`, `devocional`). El botón **«Abrir mi lista»** abre el enlace con `url_launcher`; Android lo entrega a la app de música si está instalada. **Los controles de medios de Android** (la cortina de notificaciones y los audífonos) dan pausa y salto sin ningún código. La app **no baja el volumen de la música al hablar** en la V1 (no habla).

### 3.13 Reloj (D15)

Con la pulsera actual (nivel 1) llegan los avisos del teléfono con su título discreto. La app de reloj («bici en vivo») solo existe con un reloj Wear OS y queda fuera (D15).

---

## 4. Reglas (sin IA)

Todas son **funciones puras del dominio** (`paquetes/habitos_dominio/lib/src/bicicleta/`) con valores en `ReglasBicicleta` (RB8). Donde dice «valor inicial» se edita en Ajustes › Bicicleta.

### 4.1 La salida del sábado como bloque de agenda (PB-08)

El plan de la semana del gimnasio ya trata el sábado como `bici` (HB-15). Aquí se completa con **dos bloques recurrentes** en `hab_bloques` (sin columnas nuevas, HB-13), creados con **«Poner en mi agenda»** y editables como cualquier bloque:

| Bloque | Tipo y área | Cuándo (valor inicial) | Duración | Aviso |
|---|---|---|---|---|
| **Salida en bicicleta** | `actividad`, `salud`, ligado al objetivo «Bicicleta» (4.11) | Sábado a las **8:00** (`diseno-app-habitos.md:267`) | **240 min** (la salida prevista de unas 4 h, `:1386`), editable | `recordar_min = 45`: el aviso de salida de ~7:15 (HB-02) |
| **Preparar la bici** | `actividad`, `salud` | **Viernes**, el primer hueco libre de **15 min** a partir de las 19:30 y antes de `dormir − 60 min`; si no hay hueco, el sábado 45 min antes de la salida | 15 min | `recordar_min = 0` |

**Cómo se encuentra el hueco.** `huecosLibres` y `conflictos` (HB-17 de la especificación del gimnasio: `agenda.dart:45`, `:70`) con el día de la semana, el horario laboral y las demás sesiones. **Un conflicto avisa y no impide guardar** (`fase-3-habitos.md:496`, criterio 24). Con la sesión C el viernes (el plan original del diseño), la preparación de las 19:30 choca con la de las 19:15: el aviso lo dice y propone el hueco siguiente.

**Por qué dos bloques y no un recordatorio nuevo.** Los recordatorios de bloque ya existen, funcionan sin red y no exigen tipos de aviso nuevos (HB-13). El título que ve la persona en la notificación es el del catálogo existente («Tu siguiente actividad empieza pronto»), discreto. *Si se veta:* un tipo `hab_bici_*` en el catálogo con los títulos de 4.12.

**Hora de regreso.** `regreso = inicio + duración prevista`. Con los valores iniciales: **12:00**. La duración prevista de una salida concreta sale, en este orden: la duración de la ruta elegida (si la persona la escribió), el promedio de sus últimas cuatro salidas redondeado a 15 min, y por último 240.

### 4.2 Preparación la noche anterior (PB-08)

La lista es un **catálogo cerrado editable** (la persona agrega hasta 10 puntos propios de 60 caracteres y apaga los que no usa). Se guarda en `hab_bici_perfil.preparacion` (5.2). Hay **dos momentos**:

| Momento | Puntos (id → texto) |
|---|---|
| **Viernes en la noche** (la preparación del bloque) | `bici_revisada` → «Bici revisada: frenos, llantas y cadena»; `luces_cargadas` → «Luces cargadas»; `telefono_cargando` → «Teléfono y luces a cargar»; `agua_lista` → «Agua lista»; `comida_lista` → «Algo fácil de comer»; `herramientas` → «Bomba o inflador, parche y cámara de repuesto» (el diseño: `:274`); `ropa_lista` → «Casco y ropa visible listos»; `clima_visto` → «Revisé el clima» |
| **Antes de salir** (sábado) | `casco_puesto` → «Casco»; `luces_puestas` → «Luces puestas»; `frenos_probados` → «Probé los frenos»; `presion_llantas` → «Llantas en buen estado»; `protector_solar` → «Protector solar»; `escucha_exterior` → «Audífonos en escucha exterior o a volumen bajo» (`:1450`); `aviso_regreso` → «Avisé mi hora de regreso» |
| **Solo en ruta de calle o mixta** | `ropa_visible`, `luces_siempre` → «En calle, luces encendidas y ropa visible» (`:273`) |
| **Solo en ruta de terreno o mixta** | `llantas_frenos_terreno` → «Llantas y frenos revisados para terreno»; `herramientas` (ya arriba) (`:274`) |

Reglas: marcar un punto es un toque y se puede deshacer; **un punto sin marcar no bloquea nada** (RB6). La lista **no es una garantía de seguridad**: debajo va la línea fija de 1.2. El tipo de ruta sale de la ruta elegida o de la última salida; si no hay, se muestran todos.

### 4.3 Clima (PB-09)

| Qué | Regla |
|---|---|
| **Fuente en la V1** | Ninguna dentro de la app. El botón **«Ver el clima»** abre el enlace que la persona guardó (su app o su página de clima). Después, **cinco casillas** de un toque: «Despejado», «Nublado», «Posible lluvia», «Mucho calor», «Frío» |
| **Respuesta** | Texto fijo por casilla: **Posible lluvia** → «Con lluvia el piso resbala y se ve menos. Considera dejarlo para otro día o salir en calle por un rato corto.»; **Mucho calor** → «Con mucho calor, sal más temprano o acorta la salida, y lleva agua.»; **Frío** → «Con frío, abrígate por capas y calienta con calma.»; las otras dos, solo un «Buen día para salir. Cuídate en las calles». Ninguna casilla bloquea nada |
| **Se guarda** | La casilla elegida se guarda en la salida (`clima`, 5.2) para el historial; el enlace de clima, **no** (puede incluir un lugar) |
| **V1.1** | Si el dueño aprueba un servicio (3.2, opción B): una petición **solo cuando la persona toca «Ver el clima»**, con coordenadas **redondeadas a una décima**, sin guardar la respuesta ni las coordenadas; si no hay señal, vuelve a las casillas |
| **Sin red** | Las casillas funcionan siempre |

### 4.4 Seguridad (textos fijos, sin diagnóstico)

El catálogo de textos de seguridad es **cerrado y revisado** (CA-B-01):

1. **Línea fija** (1.2): «Esta guía no sustituye tu prudencia, las reglas de tránsito ni a un profesional. Ajusta la salida a cómo te sientes, al clima y al camino.»
2. **Si te sientes mal** (PB-19, CB-4): «Si te sientes mal durante la salida, detente en un lugar seguro y pide ayuda. Si el malestar es fuerte o no cede, llama a emergencias o consulta a un médico.» **No nombra síntomas ni enfermedades.**
3. **Calle:** «En calle, usa casco, luces y ropa visible, y respeta las señales. Con audífonos, deja pasar el sonido del entorno.» (HB-05)
4. **Terreno:** «En terreno, revisa llantas y frenos antes de salir y lleva herramientas básicas.»
5. **Hora de regreso (sin vigilancia):** «Avisa a alguien de confianza tu hora de regreso. GRAVITY no vigila tu salida: si no regresas, nadie recibe un aviso automático.»
6. **Calor y agua:** «Lleva agua y algo fácil de comer, y bebe con regularidad desde el inicio.» **Sin litros, sin gramos, sin calorías** (RB: HB-02).
7. **Contacto de emergencia:** «Para una emergencia, llama a emergencias (el número del país está en Ajustes; por omisión 911 en México **[confirmar]**) o a tu contacto.»

**Contacto de confianza (PB-10).** Vive **solo en el teléfono** (7.1). Dos botones: **«Llamar»** (`tel:`) y **«Avisar mi hora de regreso»**, que arma el mensaje «Salgo a las 8:00 y regreso hacia las 12:00. No me vigila nadie: si no sé de ti, llámame.» y abre la aplicación de mensajes con `sms:`; **la persona toca Enviar**. No se pide permiso de SMS ni de contactos; la app **nunca** envía un mensaje por sí sola (CA-B-33). En la V2 el SOS agrega la última posición conocida al mismo texto (3.11).

### 4.5 Registro de la salida

| Qué | Cómo | Toques |
|---|---|---|
| **Marcar la salida como hecha** (sin detalles) | En Hoy, *Salí* o deslizar sobre el bloque; guarda `hecho` en `hab_registros` | **1** |
| **Cronómetro** | *Empezar* guarda la hora de inicio; *Terminar* abre la hoja de registro; sobrevive a cerrar la app; se hace **parado**, nunca en movimiento | 1 + 1 |
| **Registrar lo que hice** | Hoja con: duración (propuesta = prevista o la del cronómetro, con − y +), distancia (opcional, se escribe o se deja vacía), desnivel (opcional), superficie (`calle`, `terreno`, `mixta`), esfuerzo 1 a 5 (opcional), clima (opcional), bicicleta (la activa), «Salí acompañado» (casilla) | 3 con todo como se planeó |
| **Otro día** | Si la salida fue el domingo (por lluvia), la persona la registra con su fecha | 3 |
| **Terminé una parte** | Igual que el gimnasio (PG-13): «Terminé la salida» o «Terminé una parte»; sin umbral ni juicio | 2 |

Escribe `hab_registros` como cualquier bloque (HB-19 del gimnasio) y, si hay datos, una fila en `hab_bici_salidas`. **La distancia la escribe la persona** (de su ciclocomputador, su app o su estimación); la app **no la valida contra un mapa**.

### 4.6 Carga de piernas, las 48 horas y la bicicleta

**Lo que pasa hoy (VERIFICADO con cálculo).** La regla del gimnasio exige entre dos sesiones que comparten un grupo muscular **al menos 47 h de inicio a inicio** (`48 h − 60 min`, `reglas.dart:185`). La bicicleta cuenta como cuádriceps y glúteo (`plan_semana.dart:101-105`). La ruta empieza el **sábado 28/nov/2026 a las 8:00** (ejemplo de calendario). Para cumplir, la sesión de piernas debe empezar **a más tardar el jueves a las 9:00**.

| Caso (ejemplo) | Intervalo inicio a inicio | Resultado |
|---|---|---|
| C el **viernes a las 20:00** (el diseño original) | 12 h 0 min | **Avisa:** faltan 35 h |
| C el **jueves a las 19:15** (la decisión del dueño) | **36 h 45 min** (2205 min) | **Avisa:** faltan **10 h 15 min** (615 min). Aunque se hiciera en versión corta, el aviso **sigue**: la regla mide el inicio |
| C el **jueves a las 9:00** | 47 h 0 min | Cumple (no es posible: el dueño trabaja de 8:00 a 18:00) |
| C el **miércoles a las 19:15** | 60 h 45 min | Cumple |
| C el **martes a las 19:15** | 84 h 45 min | Cumple |

**Las cuatro salidas (se presentan todas; la recomendación va después).**

| Opción | Qué cambia | Costo | Cumple la regla |
|---|---|---|---|
| **1. C el martes y B el miércoles** («A lunes, C martes, B miércoles») | El orden de las tres sesiones de fuerza. A y B siguen separadas **48 h exactas** (lunes 19:15 a miércoles 19:15, comparten `hombro`); C no comparte grupos con A ni con B | Cambia la tabla del plan; en los planes de 4 y 5 días las regenerativas pasan a jueves y viernes. **Pide un cambio al dominio del gimnasio** (`planSemanal` con C el martes, hoy solo existe `cEnViernes`) | **Sí** (84 h 45 min con la ruta; 83 h 15 min de la ruta a la siguiente C) |
| **2. Dejar C el jueves y aceptar el aviso** | Nada. El aviso aparecería cada semana; la persona lo cierra con «Dejarlo así» | Ruido semanal; riesgo de que el aviso pierda valor | **No** (es la persona quien decide) |
| **3. Tratar la ruta como carga ligera de piernas** | Un valor por persona `carga_piernas`: `normal` (cuenta como piernas, como hoy), **`ligera`** (no cuenta) o **`por_esfuerzo`** (cuenta solo si el esfuerzo de las últimas tres salidas fue 3 o más; sin salidas registradas, cuenta). **Pide un cambio al dominio del gimnasio** (`gruposDeTipo` recibe ese valor) | Depende de cómo la perciba el dueño (**pregunta 3**). Es una **declaración de la persona**, no un cálculo médico | Sí, por decisión de la persona |
| **4. Mover la ruta** | A las 18:15 del sábado o al domingo: C del jueves 19:15 + 47 h = sábado 18:15 | Choca con la revisión de las 14:30, con la luz y con el domingo de iglesia (`diseno-app-habitos.md:581`) | Sí, pero no se recomienda |

**Recomendación (PB-07).** **Opción 1 por omisión** (cumple la regla del propio dueño sin excepciones) **y opción 3 disponible en Ajustes**, para que el dueño la use si la ruta le resulta ligera. Mientras el dueño no responda, **no se cambia nada** en el gimnasio: el plan por omisión sigue como está y el aviso se muestra, con las propuestas existentes. **Un hallazgo para el arquitecto:** las propuestas actuales (`moverAlJueves`, `versionCorta`, `dejarComoEsta`, `plan_semana.dart:158-160`) **no incluyen «mover C al martes»** y la `versionCorta` no cierra el aviso (HB-15, CB-2); si el dueño elige la opción 1, hace falta la propuesta nueva.

**Después de la salida.** Tras una salida con esfuerzo 4 o 5, el resto del sábado se trata como día saturado (el medidor de carga ya cuenta los minutos del bloque, `carga_dia.dart:12`) y la app sugiere un domingo de descanso con el mensaje existente «Hoy hay mucho. ¿Dejamos solo lo esencial?» (`MensajesHabitos.saturado`) y el de 4.12. **No agrega series ni cargas.** Si la persona reporta cansancio acumulado, se aplica a la **última sesión de piernas**, sea cual sea el día (CB-3).

### 4.7 Sueño y la revisión del sábado a las 14:30

**¿Alcanza el tiempo tras 4 horas de ruta?** (VERIFICADO con cálculo.) La salida de 8:00 a 12:00 deja **2 h 30 min** hasta la revisión de las 14:30 (HB-02, HB-14). Regla (PB-18):

> **regreso estimado + margen (90 min por omisión: llegar, bañarse, comer, descansar) ≤ hora de la revisión.**

| Caso (ejemplo) | Regreso | + margen | Revisión | Resultado |
|---|---|---|---|---|
| Salida de 4 h | 12:00 | 13:30 | 14:30 | **Cabe** (sobran 60 min) |
| Salida de 5 h | 13:00 | 14:30 | 14:30 | **Cabe justo** (0 min de sobra) |
| Salida de 5 h 30 min | 13:30 | 15:00 | 14:30 | **No cabe:** faltan 30 min |

**Qué hace la app cuando no cabe** (siempre una propuesta, **nunca mueve la revisión sola**): acortar la salida; hacer la revisión más tarde (se cambia en Ajustes › Revisión); o hacerla el domingo. Con la salida en curso, si pasan las 13:15 (la revisión menos 75 min), la tarjeta de Hoy ofrece *Pasar mi revisión a más tarde* (un toque, estado `pospuesto` del bloque de revisión). El aviso previo de las 14:15 llega como siempre.

**Sueño.** El sábado empieza con el aviso de las 7:15 (45 min antes). La noche anterior depende de `hab_ajustes.dormir` (HB-14): el aviso de «cerca de dormir» del gimnasio **no aplica** (no hay sesión de fuerza el viernes), pero la preparación del viernes se ofrece **antes de `dormir − 60 min`**. Cuando exista el módulo de sueño (etapa 6, no construido), la calidad de la noche anterior podrá sugerir una salida más corta; hoy se usa la pregunta de un toque del gimnasio (3.5 de esa especificación) **«¿Cómo amaneciste? Descansado · Normal · Cansado»**: con **Cansado** propone «una ruta más corta o de calle plana» y no bloquea nada.

### 4.8 Mantenimiento por kilómetros (PB-05, PB-11)

**Kilometraje.** Se calcula (RB4):

> **odómetro de la bici = última lectura (o el odómetro inicial, si no hay) + suma de las distancias de las salidas con esa bici posteriores a esa lectura.**

| Ejemplo inventado | Cálculo | Resultado |
|---|---|---|
| Odómetro inicial **350 km** (lo escribió la persona), sin lecturas; salidas de 62 km y 58 km | 350 + 62 + 58 | **470 km** |
| El ciclocomputador marca **480 km** el 12/dic (lectura); después hay una salida de 60 km | 480 + 60 | **540 km** |
| Dos bicis; una salida de la bici A | Se suma solo a la A | Cada bici lleva el suyo |

**Tareas (catálogo cerrado) y valores iniciales.** El diseño pide recordatorio de «limpieza, lubricación de cadena y revisión según kilómetros recorridos» (`:275`). Los intervalos **no tienen fuente verificada**: son un **punto de partida editable**, marcados `borrador` (como todo el catálogo del gimnasio, PG-25), y la pantalla dice «Confirma los intervalos con el manual de tu bici o con tu taller». El terreno con lodo los acorta.

| Tarea | Cada (km) | O cada (semanas) | Origen |
|---|---|---|---|
| `lubricar_cadena` | 150 | 4 | **Propuesta sin fuente** |
| `limpiar_transmision` | 400 | 12 | **Propuesta sin fuente** |
| `revisar_frenos_llantas` | 300 | 8 | **Propuesta sin fuente**; además se revisan antes de cada salida (4.2) |
| `revision_general` (taller) | 2 000 | 26 | **Propuesta sin fuente** |

**Reglas.** Una tarea **toca** cuando se cumple **lo primero** de: los km desde su último registro llegan al intervalo, o las semanas llegan al intervalo. **Sin ningún registro de la tarea** el estado es «sin registro» y **no «vencida»** (sin culpa, RB6). **No bloquea nada.** Aparece como una línea en la preparación del viernes y en la pantalla Bici › Mantenimiento; **no genera notificaciones** propias (PB-13: menos avisos); marcar «Hecho» guarda el mantenimiento con la fecha y el odómetro de ese día. La persona puede cambiar los intervalos o dejarlos en blanco para una tarea.

### 4.9 Progresión de la salida (informativa, PB-12)

El diseño pide «aumento gradual de distancia o tiempo semana a semana (sin saltos bruscos)» (`:270`). La app **no propone una meta**: **informa** cuánto cambió la salida respecto al **promedio de las últimas cuatro salidas** y, si el aumento pasa de `tope_aumento_pct` (valor inicial **20 %**, **sin fuente**, editable de 5 a 50), muestra una nota: «Esta salida fue bastante más larga que tus últimas. Si te sientes bien, adelante; si no, acórtala.» Sin historial (menos de cuatro salidas) **no hay nota**. No bloquea, no tiene colores de alarma y **no se muestra en modo foco** (4.10). No es consejo de entrenamiento: es una comparación de números.

### 4.10 Modo foco

Dentro del modo foco de un hábito a eliminar, la bicicleta **no sugiere aumentos** (4.9), el recordatorio de la salida sigue disponible y la tarjeta dice «Hoy puedes salir o dejarlo: ambos están bien». Se usa la interfaz sin causa del gimnasio `ModoFocoActivo.para(fecha) → bool` (HB-18): la bicicleta **nunca sabe qué hábito lo causó**. La preparación y los textos de seguridad **no se ocultan** (son seguridad, no incremento). El diseño sugiere «bicicleta moderada» como apoyo ante un antojo (`diseno-app-habitos.md:1588`, `:1680`); eso **no cambia** el SOS existente.

### 4.11 Objetivo «Bicicleta»: meta mensual, sin racha semanal (PB-06)

Una salida de unas 4 horas depende del clima y del camino. Un objetivo semanal rompería la racha cada vez que llueve (HB-20, CB-8) y empujaría a salir en mal clima. Propuesta: el objetivo es de **tipo `meta`** (`salidas del mes`, por omisión 3, editable), sin racha semanal; una salida que **no** sale por clima o seguridad se marca `omitido` con el motivo «clima» o «seguridad» y **no genera mensaje de ruptura**. El dueño puede cambiarlo a un objetivo semanal si lo prefiere.

### 4.12 Mensajes y avisos (catálogo)

Sin signos de exclamación, de tú, sin las palabras de `MensajesHabitos.prohibidas` (`mensajes.dart:25`). Ejemplos del catálogo: «Hoy toca tu salida en bici. ¿Todo listo?», «Salida registrada. Gracias por avisar.», «Hoy no salió la ruta. Cuando quieras, la retomamos.», «Tu revisión semanal puede esperar un rato más si lo necesitas.», «Un domingo tranquilo ayuda a recuperar.».

**Títulos de recordatorio nuevos (solo si se veta el uso de bloques, 4.1)**, máximo 40 caracteres, sin dígitos ni nombres, cuerpo vacío: «Prepara tu bici para mañana» (27), «Hora de tu salida en bici» (25). El canal es el existente *Hábitos · Recordatorios*.

---

## 5. Modelo de datos

### 5.1 Qué se guarda y dónde

| Dato | Dónde vive | ¿Sale del teléfono? | Quién lo ve |
|---|---|---|---|
| **Bicicletas, lecturas y mantenimientos** | `hab_bici_bicicletas`, `hab_bici_mantenimientos` | Sí, a **tu hogar** (Supabase con RLS) | Solo tú |
| **Salidas** (fecha, duración, distancia, desnivel, superficie, esfuerzo, clima, bicicleta) | `hab_bici_salidas` | Sí, a tu hogar | Solo tú |
| **Perfil de bicicleta** (lista de preparación, valores de 4) | `hab_bici_perfil` | Sí, a tu hogar | Solo tú |
| **Enlaces de música** | `hab_musica_listas` (compartida con el gimnasio, PB-14) | Sí, a tu hogar | Solo tú |
| **Rutas** (nombre, distancia, desnivel, tramos, enlace pegado, y en V2 el trazo), **contacto de confianza**, **enlaces de mapa y clima**, **vínculo salida↔ruta** | Tipo local `ubicacion_local` del almacén de sobres (7.1) | **Nunca** | Solo tú, solo en ese equipo |
| **Odómetro, mantenimiento vencido, promedio, progresión, hora de regreso, encaje con la revisión, carga de piernas** | **No se guardan: se calculan** | — | — |
| **Datos para una IA** | **No existe** | — | — |

**Por qué las salidas van en claro y sin ruta.** Son números sin lugar (como `hab_registros`, `fase-3-habitos.md:114`); la laptop debe poder mostrar el historial y el mantenimiento; y el dueño pidió que la ubicación no salga. Una fecha, una duración y un esfuerzo **no revelan un lugar**. **Riesgo residual aceptado por quedar bajo RLS:** un sábado a las 8:00 todas las semanas muestra un hábito de ausencia de casa; solo tú lo ves (sección 11, R-B-9).

### 5.2 Tablas del servidor (backend, B2)

**Propuesta PB-02 · Prefijos `hab_bici_` y `hab_musica_`**: ambos empiezan con `hab_`, así que heredan las protecciones sin ampliar la bitácora (HB-09 del gimnasio) y son editables con último-gana. Todas llevan `hogar_id`, `persona_id` (los pone el servidor con `hab_propio()`), `modificado_en` (el dispositivo; tope de 5 minutos en el futuro) y `actualizado_en`; RLS `persona_id = persona_actual()` y `hab_activa(hogar_id)`; privilegios por columna; **sin trigger de bitácora**; claves compuestas `(persona_id, id)` únicas.

**`hab_bici_perfil`** · una fila por persona

| Columna | Tipo | Notas |
|---|---|---|
| `persona_id` | uuid | **PK** |
| `bicicleta_activa_id` | uuid | nulo; llave `(persona_id, id) → hab_bici_bicicletas`, `on delete set null` |
| `duracion_prevista_min` | smallint | de 30 a 720; por omisión 240 |
| `margen_revision_min` | smallint | de 0 a 240; por omisión 90 (PB-18) |
| `carga_piernas` | text | `normal`, `ligera` o `por_esfuerzo`; por omisión `normal` (PB-07) |
| `tope_aumento_pct` | smallint | de 5 a 50; por omisión 20 (PB-12) |
| `preparacion` | jsonb | hasta 4 KB: lista de `{id, activo}` del catálogo y hasta 10 puntos propios (`{texto}` de 60 caracteres) |
| `intervalo_agua_min`, `intervalo_comida_min` | smallint | nulos, o de 10 a 120. **Solo V2**; por omisión **vacío** y la app **no sugiere un valor** (el diseño: la app no fija montos de líquidos ni de comida, `:1399`) |
| `aviso_visto_en` | timestamptz | nulo hasta que la persona toca «Entendido» (1.2) |

**`hab_bici_bicicletas`**

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid | **PK**, v4 |
| `nombre` | text | de 1 a 40 caracteres (lo escribe la persona) |
| `tipo` | text | nulo, o `montana`, `ruta`, `gravel`, `urbana`, `otra` (no se supone ninguno) |
| `odometro_inicial_m` | integer | de 0 a 200 000 000 (200 000 km); lo que ya tenía al registrarla |
| `intervalos` | jsonb | hasta 1 KB: `{tarea: {km, semanas}}` (4.8); nulo = los valores iniciales |
| `activa` | boolean | por omisión `true` |

**`hab_bici_mantenimientos`** · hechos

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid | **PK**, v5 de la persona, la bicicleta, la tarea y la fecha |
| `bicicleta_id` | uuid | llave compuesta a `hab_bici_bicicletas`, `on delete cascade` |
| `tarea` | text | `lubricar_cadena`, `limpiar_transmision`, `revisar_frenos_llantas`, `revision_general`, **`lectura_odometro`** (una lectura, 4.8) u `otra` |
| `fecha` | date | |
| `odometro_m` | integer | nulo, o de 0 a 200 000 000; en `lectura_odometro` es **obligatorio** |
| `nota` | text | hasta 120 caracteres; **sin lugares ni nombres de talleres** (la pantalla lo recomienda; no se puede validar) |

**`hab_bici_salidas`**

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid | **PK**, v5 de la persona, la fecha y el número del día (1 a 3) |
| `fecha` | date | único `(persona_id, fecha, n)` |
| `n` | smallint | de 1 a 3 |
| `bloque_id` | uuid | nulo; llave compuesta a `hab_bloques`, `on delete set null` |
| `bicicleta_id` | uuid | nulo; llave compuesta a `hab_bici_bicicletas`, `on delete set null` |
| `inicio` | time | nulo |
| `duracion_min` | smallint | nulo, o de 1 a 1 440 |
| `distancia_m` | integer | nulo, o de 0 a 1 000 000 |
| `desnivel_m` | smallint | nulo, o de 0 a 20 000 |
| `superficie` | text | nulo, `calle`, `terreno` o `mixta` |
| `esfuerzo` | smallint | nulo, o de 1 a 5 |
| `clima` | text | nulo, `despejado`, `nublado`, `lluvia`, `calor`, `frio` |
| `acompanado` | boolean | por omisión `false` (**sin identificar a nadie**) |
| `estado` | text | `hecha`, `parcial` u `omitida` (con el motivo `clima` o `seguridad` en `motivo`, nulo en las demás) |
| `motivo` | text | nulo, `clima`, `seguridad` u `otra` |

**Qué NO existe en el servidor, nunca:** ninguna columna de latitud, longitud, trazo, nombre de ruta, enlace de ruta, domicilio, contacto ni teléfono; **la salida no se enlaza con ninguna ruta** (el vínculo vive solo en el equipo, PB-04). Una prueba revisa el esquema (CA-B-18).

**`hab_musica_listas`** (compartida con el gimnasio, PB-14)

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid | **PK**, v4 |
| `nombre` | text | de 1 a 60 caracteres |
| `actividad` | text | `bicicleta`, `fuerza`, `regenerativo`, `traslado`, `devocional` (HB-04) |
| `app` | text | `spotify`, `amazon_music`, `otra` |
| `enlace` | text | de 10 a 300 caracteres; **debe empezar por `https://`**; el dominio no se restringe, el esquema sí (CA-B-14) |
| `orden` | smallint | de 1 a 20 |

**Qué debe ampliar backend en lo existente** (H-10 del gimnasio: las listas están escritas a mano): agregar las cinco tablas a `hab_borrar_datos_de` (alcance `todo` y alcance nuevo `bicicleta`), a `hab_cuota_filas` (sugerido: salidas 1 500, mantenimientos 2 000, bicicletas 20, listas 100, perfil 1), a la política de RLS y a los `grant` por columna, y confirmar que la baja con borrado a los 90 días (D21) las cubre.

### 5.3 Lo que se calcula y no se guarda

- **Odómetro** (4.8), **mantenimiento que toca**, **promedio de las últimas cuatro salidas**, **progresión** (4.9), **regreso estimado** y **encaje con la revisión** (4.7), **carga de piernas efectiva** (4.6) y **salidas del mes**: salen de los hechos de 5.2.
- **La salida concreta del sábado** (qué ruta, qué lista, qué clima) se arma al abrirla; no se guarda un «plan generado».

### 5.4 Cola, local primero

Hábitos hoy escribe directo con `upsert` (HB-17). La bicicleta usa **la cola desde el inicio**, con los tipos `habitos.bici_perfil`, `habitos.bici_bicicleta`, `habitos.bici_mantenimiento`, `habitos.bici_salida` y `habitos.musica_lista` (el prefijo `habitos.` ya es personal: `cola_sin_conexion.dart:61-69`), con este orden de subida por llaves: perfil, bicicleta y lista; luego mantenimiento y salida. Pedido a `plataforma` (junto con los `habitos.gim_*` del gimnasio; B3). **Todo funciona sin red.**

---

## 6. Pantallas y flujos

Siguen `DISENO_UX_UI.md`: **teléfono** (lo que se hace en el momento), **laptop** (planear y revisar) y **tablet** (sección 11). La personalidad **Sport** (alto contraste, números enormes) se usa **solo en las pantallas en movimiento**: en la V1, la tarjeta de Hoy y el cronómetro; en la V2, el visor en vivo (`DISENO_UX_UI.md:194`; `Submodulo.bici` ya existe, HB-12). Las pantallas de planear, mantenimiento, historial y ajustes usan la personalidad calma de Hábitos. Todas con estados **vacío, cargando, sin conexión y error** (`DISENO_UX_UI.md:49`) y sin reintentos automáticos.

### 6.1 Mapa de pantallas

| # | Pantalla | Versión | Teléfono | Laptop | Tablet personal | Tablet pública |
|---|---|---|---|---|---|---|
| B1 | **Hoy · tarjeta «Bicicleta»** (viernes: preparar; sábado: salir, regreso estimado, revisión) | V1 | Sí | Sí | Sí | Con nombre y PIN, sin ruta ni contacto |
| B2 | **Bicicleta › Planear la salida** (hora, duración, ruta, bicicleta, regreso, encaje con la revisión, 48 h, música, clima, seguridad) | V1 | Sí | Sí (principal, sin rutas) | Sí | No |
| B3 | **Preparación** (viernes y antes de salir) | V1 | Sí | Sí (editar la lista) | Sí | No |
| B4 | **Registro de la salida** y **cronómetro** | V1 | Sí | Sí (registrar después) | Sí | No |
| B5 | **Historial** (salidas, barras por semana con texto alternativo) | V1 | Sí | Sí (principal) | Sí | No |
| B6 | **Rutas guardadas** (a mano) | V1 | **Solo en el equipo donde se escribieron** | **No** | Solo en este equipo | **Nunca** |
| B7 | **Mi bici y mantenimiento** (bicicletas, odómetro, lecturas, tareas, intervalos) | V1 | Sí | Sí (principal) | Sí | No |
| B8 | **Seguridad y contacto** (textos, contacto, número de emergencias) | V1 | Sí (el contacto **solo aquí**) | Solo los textos | Solo este equipo | **Nunca** |
| B9 | **Ajustes › Bicicleta** (valores de 4, enlaces de clima y música, «Sobre esta guía», mis datos) | V1 | Sí | Sí | Sí | No |
| B10 | **En vivo** (visor) | V2 | Sí | **Solo ver el resumen** | No | No |
| B11 | **Resumen con mapa**, mapas sin conexión, importar y exportar GPX | V2 y V2.1 | Sí | Sí (con `flutter_map`; el trazo solo si está en ese equipo) | No | No |

**Navegación.** Dentro de Hábitos: *Salud › Bicicleta*, con rutas nuevas `bicicleta`, `bicicleta/planear`, `bicicleta/preparacion`, `bicicleta/salida`, `bicicleta/historial`, `bicicleta/rutas`, `bicicleta/mi-bici`, `bicicleta/seguridad` (relativas a `/habitos`, como `rutasHabitos`: `app/lib/modulos/habitos/habitos.dart:49`). La barra de órdenes entiende *«abre bicicleta»* (pedido a `asistente`, 12.2).

### 6.2 Flujos clave (V1)

| # | Flujo | Pasos | Meta |
|---|---|---|---|
| F-B1 | **Marcar la salida** (sin detalles) | Hoy → *Salí* sobre «Bicicleta» → «Guardado · Deshacer» | **1 toque** |
| F-B2 | **Preparar la noche anterior** | Hoy (viernes) → tarjeta «Prepara tu salida» → marcar puntos → *Listo* | 1 por punto; la lista completa son ~10 toques **opcionales** |
| F-B3 | **Salir con cronómetro** | Hoy → *Empezar* (parado) → guardar la hora → *Terminar* al llegar → hoja de registro | 1 + 1 + 3 |
| F-B4 | **Registrar después** | Hoy → bloque → *Registrar lo que hice* → *Todo como estaba planeado* → Guardar | **3** |
| F-B5 | **Primera vez** | Bicicleta → aviso «guía general que no sustituye tu prudencia» → *Entendido* → Mi bici (nombre, odómetro actual escrito) → Planear (hora, duración) → *Poner en mi agenda* | Unos 3 minutos |
| F-B6 | **Guardar una ruta a mano** | Rutas → *Nueva* → nombre, tipo, distancia, desnivel, tramos (superficie y metros), enlace (opcional) → Guardar | 6 campos; todos opcionales salvo el nombre |
| F-B7 | **Mantenimiento** | Mi bici → tarea → *Hecho* (con odómetro del día) | **2** |
| F-B8 | **Avisar mi hora de regreso** | Planear → *Avisar mi hora de regreso* → se abre mensajes con el texto → la persona toca Enviar | 2 + el Enviar de la persona |
| F-B9 | **Abrir mi música** | Planear → *Abrir mi lista* → se abre la app de música | 2 |
| F-B10 | **Llamar al contacto** | Seguridad → *Llamar* | **1** |

### 6.3 La pantalla B2, Planear la salida

```
┌──────────────────────────────────┐
│ ◀ Salida del sábado              │
├──────────────────────────────────┤
│ Sábado · 8:00 · ≈ 4 h            │
│ Regreso estimado   12:00         │
│ Revisión semanal   14:30 ✓ cabe  │
│ Ruta   [Elegir ruta ▾]           │
│ Bici   Mi bici · 470 km          │
├──────────────────────────────────┤
│ ⚠ Piernas: la sesión C del jueves│
│   queda a 36 h 45 min de la ruta.│
│   [Ver opciones]                 │
├──────────────────────────────────┤
│ Preparación (8 de 10)  [Abrir]   │
│ Mantenimiento: lubricar cadena   │
│ ♪ [Abrir mi lista]  ☁ [Ver clima]│
│ [Avisar mi hora de regreso]      │
│ [Llamar a mi contacto]           │
│ Esta guía no sustituye tu        │
│ prudencia ni las reglas de       │
│ tránsito.                        │
└──────────────────────────────────┘
```

Ejemplo con datos inventados. El aviso de piernas dice **qué intervalo hay y qué opciones existen** (4.6), sin culpa, y se puede cerrar con «Dejarlo así».

### 6.4 El visor en vivo (V2; solo si el dueño aprueba los paquetes de 3.3 a 3.5)

**Principio (HB-08): nada que exija mirar la pantalla ni tocarla en movimiento.** La pantalla se **lee de reojo** y **todo lo que se toca se toca parado**.

```
┌──────────────────────────────────┐
│ 1:42:10     32,4 km    ▲ 410 m   │  ← números de 96 dp o más
│ 19 km/h                          │
│ ┌──────────────────────────────┐ │
│ │ MAPA (solo si hay espacio;   │ │  ← sin gestos finos; no se mueve
│ │  planeada ─ ─  recorrida ━━) │ │
│ │              ● tú            │ │
│ └──────────────────────────────┘ │
│ [⏸ Pausa]      [Modo ahorro]     │  ← botones de 64 dp o más
│ [📞 SOS]                         │
│ Mantén 2 s para TERMINAR         │
└──────────────────────────────────┘
```

- **Terminar** exige mantener presionado 2 segundos (HB-07); **bloqueo táctil** opcional; **auto-pausa** al detenerse.
- **Aviso de desvío y recordatorios de hidratación y comida:** por **vibración y una voz breve y de volumen bajo** (el motor de voz del dispositivo, `flutter_tts`); nunca solo sonido ni solo color. La música bajando mientras habla necesita el manejo del foco de audio, que está en evaluación en P3.2b del motor de voz y **no está aprobado** (`ROADMAP.md`, control de cambios 3.0: `audio_session`).
- **Modo ahorro (PB-16):** fondo negro, solo los números, sin mapa ni animaciones; la grabación sigue.
- **Sin señal:** el mapa usa los datos sin conexión; la grabación sigue con el GPS.
- **Recuperar:** si la app se cierra, se recupera la salida (los puntos se guardan de forma incremental en el tipo local).
- **Alto contraste siempre** (`personalidad_modulo.dart:208`), probado al sol en el dispositivo.

### 6.5 Laptop y tablet

- **Laptop (D4: planear y revisar).** Planear la semana (plan del gimnasio con la bicicleta y el aviso de 48 h), la **lista de preparación** (se edita aquí), el **historial** con gráficas más amplias, el **mantenimiento** y los **ajustes**. **No muestra ni conoce las rutas ni el contacto** (7.1): lo dice «Tus rutas y tu contacto están solo en tu teléfono». No es el equipo para salir.
- **Tablet personal:** como el teléfono de la persona (D21; `fase-3-habitos.md:366`): puede registrar y ver, pero el almacén local de rutas y contacto es **de cada equipo** (no se copia de uno a otro).
- **Tablet pública de la casa:** con nombre y PIN solo se ve la tarjeta de Hoy (sin ruta ni contacto) y nunca recibe recordatorios de la bicicleta (regla 105 de la Fase 3).
- **Pulsera (D15):** recibe el título discreto del aviso; sin botones.

### 6.6 Accesibilidad y letra grande

Siguen `DISENO_UX_UI.md:360-366` y `fase-3-habitos.md:529`:

- **Letra al 200 %** en 360 dp en el teléfono sin desbordes; desde 900 dp en la laptop. En el cronómetro y en el visor, **solo se desplaza el contenido secundario**; los números y el botón de terminar no salen de la pantalla.
- **Zonas táctiles de 48 dp** o más; en el cronómetro y el visor, **64 dp**.
- **Nada depende solo del color:** cada estado (hecha, pendiente, vence, sin registro) lleva **icono y texto**.
- **Alto contraste** siempre en la bici (HB-12); el contraste se mide con `contraste.dart` y, **al sol**, en el dispositivo.
- **Lector de pantalla:** cada punto de la lista anuncia «Casco, marcado» o «Casco, pendiente»; el cronómetro anuncia el tiempo cada minuto cuando se toca; los botones tienen etiqueta; el `Velocimetro` ya tiene su texto (`futuros.dart:547`).
- **Sin gestos finos** en el visor y en el cronómetro; las acciones por deslizamiento tienen botón (`DISENO_UX_UI.md:351`).
- **Reducir movimiento:** el arco del velocímetro deja de animar y muestra solo el número.
- **Voz y vibración:** nunca solo sonido; la voz es opcional.

---

## 7. Privacidad y seguridad

| Qué | Regla |
|---|---|
| **Ubicación y rutas nunca a la IA ni a la nube de IA** | Ninguna función de este bloque llama a una IA; ninguna herramienta de GRAVITY devuelve rutas, puntos, contacto, ni cifras de salidas; el filtro de D3 del servidor rechaza cualquier campo de ubicación (sección 7.3). **Tampoco van a Supabase:** ni rutas, ni trazos, ni domicilio, ni contacto (CA-B-18) |
| **Todo lo de ubicación, en el almacén local** | Tipo `ubicacion_local` (7.1): cifrado con la **llave local** del equipo; sin nube; excluido de la subida diferida; **fuera del respaldo automático de Android** (ya apagado: `allowBackup="false"`, HB-16) y dentro del respaldo local cifrado con la frase de 12 palabras |
| **Lo que sí sube a tu hogar** | Salidas (números y tipo de superficie), perfil, bicicletas, mantenimientos y enlaces de música, por RLS «solo tú» |
| **La cuenta maestra, el cuidador, Hogar y `anon`** | No leen ni escriben nada (misma regla que `hab_*`); el dueño y el coadministrador ven **solo lo propio** |
| **Bitácora** | Las tablas no escriben en la bitácora y el prefijo `hab_` las oculta (RB3, CA-B-16) |
| **Notificaciones** | Títulos del catálogo, sin lugares ni nombres de rutas, sin dígitos (≤ 40 caracteres) |
| **Enlaces externos** | Solo **`https`**, **`tel`**, **`sms`** y **`geo`**; se rechazan `javascript:`, `intent:`, `file:`, `content:` y cualquier otro esquema; **nada se abre sin un toque** de la persona (CA-B-14). La app **no sabe** qué hace la otra app con el enlace; un enlace que contenga coordenadas **vive en el tipo local** (es una ruta) |
| **Capturas de pantalla** | Las pantallas de rutas, contacto y resumen con mapa llevan **FLAG_SECURE** y se ocultan en modo privado (como lo reservado, `fase-3-habitos.md:524`); lo demás de la bicicleta no es sensible |
| **Pareja** | V1: no se comparte nada por el servidor (7.4) |
| **Borrar y exportar** | *Mis datos de Hábitos* exporta y borra por tipo: el alcance `bicicleta` borra las cinco tablas; las rutas y el contacto se borran del equipo; **cada ruta y cada punto se pueden borrar** (HB-07) |
| **Tablets** | Pública: nunca rutas ni contacto. Personal: cada equipo tiene su almacén local |
| **Permisos** | V1: **ninguno nuevo**. V2: ubicación precisa, servicio en primer plano; se piden **al usarlos** con una explicación antes, no al abrir la app (CA-B-44) |

### 7.1 El tipo local de ubicación (`ubicacion_local`) — PB-03

El almacén de sobres local ya cifra con la llave local de la persona (`DocumentosSensibles`, `documentos_sensibles.dart:26-130`) y el servidor ya rechaza cualquier tipo que no sea uno de los dos (HB-16). El gimnasio propone un tercer tipo `salud_local` con las mismas propiedades (PG-03). **Propuesta:** que `plataforma` implemente los tipos locales **como datos** (una lista con una marca «solo local»: sin modo, sin fila en `hab_modos`, sin botón de nube) y no como un desarrollo por tipo; la bicicleta agrega `ubicacion_local` a esa lista. Si G3 ya construyó `salud_local` de forma cerrada, se extiende. **Es una ampliación de D21** y necesita el visto bueno del dueño (sección 12, D-B).

Documento `ubicacion` con elementos:

| Clase | Campos (todos opcionales salvo el nombre) | V |
|---|---|---|
| `ruta` | `nombre` (hasta 60), `superficie` (`calle`, `terreno`, `mixta`), `distancia_m`, `desnivel_m`, `tiempo_est_min`, `dificultad` (1 a 5), `tramos` (hasta 12 de `{superficie, metros}`), `enlace` (hasta 500, esquema `https`), `favorita`, `nota` (hasta 200) | V1 |
| `contacto` | `nombre` (hasta 60), `telefono` (hasta 20), `mensaje` (plantilla propia, hasta 200) | V1 |
| `enlaces` | `clima` y `mapa` (https) | V1 |
| `salida_ruta` | `{salida_id, ruta_id}` (el vínculo que el servidor no conoce) | V1 |
| `traza` | puntos `{lat_e5, lon_e5, alt_dm, t}` (enteros), **guardado incremental** con muestreo adaptativo por tiempo y distancia (HB-07) | V2 |
| `domicilio` | **No se pide en la V1 ni se necesita.** Si la V2 lo requiere (por ejemplo para recortar el inicio y el fin), va **aquí** y nunca fuera | V2 |

**Efecto de «solo en el dispositivo».** Las rutas y el contacto de un equipo **no los conoce otro**. La salida que se registra en la laptop no puede mostrar su ruta. Si se pierde el teléfono, se pierden salvo que haya respaldo local con la frase (R-B-8).

### 7.2 Contacto de emergencia

Vive solo en el teléfono; se usa **solo con un toque** de la persona para llamar o abrir un mensaje; la app **no envía nada por sí sola**, no lee la libreta de contactos y no pide permisos de SMS ni de contactos (CA-B-33). **No vigila:** el texto de 4.4 (5) lo dice.

### 7.3 Filtro de D3

Cualquier carga que llegue al asistente en el servidor se rechaza si trae claves de la bicicleta (`ruta`, `lat`, `lon`, `traza`, `contacto`, `telefono`, `domicilio`, `distancia`, `salida`, `odometro`). Es un pedido a `asistente` (sección 12) y una prueba (CA-B-27).

### 7.4 Pareja y consentimiento (solo si el dueño lo decide; V3)

La V1 **no comparte nada** por el servidor: la persona dice «salí acompañado» (una casilla sin identidad) y, si quiere, **ella misma envía** un mensaje. Si el dueño decide en la pregunta 2 compartir más, se propone este mecanismo, que **no se construye hasta que lo apruebe**:

1. **Consentimiento explícito, por salida:** «Compartir mi ubicación con [la pareja] durante esta salida», con interruptor visible y un texto que dice qué se comparte.
2. **Caduca solo** al terminar la salida más 30 minutos; **revocable en cualquier momento** con un toque, y la revocación borra lo ya compartido del lado de la pareja.
3. **Solo la cuenta de la pareja emparejada** (como en `fase-8-habitos-pareja-y-correccion.md`, sección 3), **nunca** la cuenta maestra, el dueño del hogar ni otro rol.
4. **Servicio y almacenamiento temporal**: **decisión del dueño, no aprobado** (Realtime u otro): son datos de ubicación fuera del teléfono. Debe revisarse con `backend` y `calidad` y contradice la regla 109 de la Fase 3, que se actualiza si se aprueba.

---

## 8. Etapas de construcción y paquetes de trabajo

Orden de las etapas del diseño (`diseno-app-habitos.md:2418`, etapa 7), pero partidas en V1 sin paquetes y V2 con aprobación. **Ningún paquete de B1 a B7 agrega una dependencia ni un permiso de ubicación.**

| Etapa | Paquete | Agente | Entrega | Depende de |
|---|---|---|---|---|
| **B0** | Aprobar esta especificación; responder las preguntas 1, 2, 3 y 8; decidir la propuesta D-B (sección 12); decidir el cambio al dominio del gimnasio de 4.6 | arquitecto y dueño | Preguntas contestadas; decisión registrada | — |
| **B1** | **B1.1 Reglas de la salida y de la revisión** | habitos | Hora de regreso, encaje con la revisión, huecos, duración prevista (4.1, 4.7) | B0 |
| | **B1.2 Carga de piernas** | habitos | Valor `carga_piernas` y su efecto en la regla de 48 h; se coordina con el gimnasio (4.6, 12) | B0 (pregunta 3) |
| | **B1.3 Mantenimiento y odómetro** | habitos | Odómetro derivado, tareas, intervalos, estado «sin registro» (4.8) | B0 |
| | **B1.4 Progresión informativa, clima y mensajes** | habitos | 4.3, 4.9, 4.10, 4.12 |  B0 |
| **B2** | **Servidor** | backend | Migración con `hab_bici_perfil`, `hab_bici_bicicletas`, `hab_bici_mantenimientos`, `hab_bici_salidas` y `hab_musica_listas`; ampliación de `hab_borrar_datos_de` y `hab_cuota_filas`; RLS; pruebas SQL (CA-B-16 a 23) | Spec aprobada |
| **B3** | **Plataforma** | plataforma | Tipos locales como datos con `ubicacion_local`; tipos de cola `habitos.bici_*` y `habitos.musica_lista`; `<queries>` del manifiesto (`https`, `tel`, `sms`, `geo`); títulos en el catálogo si se veta el uso de bloques; FLAG_SECURE en rutas, contacto y resumen; rutas `bicicleta/…`; roles (CA-B-24, 25, 28, 29, 31, 33) | B2 (nombres de columnas) y G3 del gimnasio (mismo almacén y misma cola) |
| **B4** | **Diseño** | diseno | Tarjeta de Hoy de la bicicleta; lista de preparación con estados; tarjeta de mantenimiento; hoja de registro de la salida; cronómetro; barras de historial con texto alternativo; maquetas B1 a B9 y, como **maqueta**, B10 y B11 sin funcionar; estados vacío, cargando, sin conexión y error (CA-B-30) | Spec aprobada |
| **B5** | **App Hábitos V1** | habitos | Casos de uso y pantallas B1 a B9; «Poner en mi agenda»; objetivo «Bicicleta» (4.11); enlaces; integración con Hoy, agenda, revisión, sueño (pregunta de un toque) y modo foco (`ModoFocoActivo`) (CA-B-02 a 15, 24, 32, 33, 34) | B1, B3, B4 |
| **B6** | **Asistente** | asistente | `habitos.abrir_bicicleta` (`soloLocal`, solo navegación), orden *«abre bicicleta»*, el bloque en `habitos.resumen_hoy` sin cifras ni rutas, filtro de D3 de 7.3, y las tablas nuevas en `api/openapi.yaml` (CA-B-27, 32) | B2 |
| **B7** | **Calidad V1** | calidad | Revisión de cierre: contenido de seguridad (sin diagnósticos), RLS, **sin ubicación en el servidor**, sin paquetes nuevos ni permisos de ubicación, accesibilidad, mediciones en el A52 y la tablet | B5 |
| — | **Compuerta del dueño** | dueño | Decide con las mediciones de B8 y las preguntas 4, 5 y 6 | B7 |
| **B8** | **Evaluación de paquetes** (**decisión del dueño, no aprobado**) | plataforma | En una **rama de prueba** y solo para medir: batería de un GPS de 4 h con la pantalla apagada en el A52, estabilidad del servicio en primer plano, tamaño de la región de teselas, comportamiento de `flutter_map` en el A52 y en Windows. **No se integra nada**; el informe va a `docs/revisiones/` | Aprobación explícita (pregunta 4) |
| **B9** | **V2: grabar** | plataforma, habitos, backend | GPS con servicio en primer plano, traza local incremental, recuperar la salida, hold-to-end, modo ahorro, SOS con ubicación compuesta (CA-B-40 a 46) | B8 aprobada |
| **B10** | **V2: visor y mapa** | diseno, habitos | Visor B10 y resumen B11; pantalla encendida (decisión compartida con el gimnasio, 3.5); proveedor de teselas decidido | B9 |
| **B11** | **V2.1: GPX y sin conexión** | habitos, plataforma | `gpx`, importar y exportar con recorte (PB-17), mapas sin conexión, aviso antes de salir (CA-B-44, 45) | B10 |
| **B12** | **V2.2: Health Connect** | plataforma, habitos | `health` fijado en una versión de más de 2 semanas, pantalla de ayuda del permiso de rutas, interruptores (CA-B-47) | B9, aprobación aparte |
| **B13** | **Calidad V2** | calidad | Revisión de la grabación, la privacidad de la ruta, el consumo de batería y los permisos | B9 a B12 |
| *V3* | Spotify; Bluetooth; ubicación en vivo con la pareja; reloj | — | Se especificarán aparte | Decisión del dueño |

**Orden sugerido.** B0; luego **B1, B2 y B4 en paralelo**; después B3 y B5 (B5 puede empezar con un repositorio en memoria, como la Fase 3: `repositorio.dart:16`); B6 cuando exista B2; B7 al final de la V1. **Lo que depende del dueño no bloquea la V1:** el odómetro, las rutas y el contacto se capturan en la app; los intervalos de mantenimiento salen `borrador`.

---

## 9. Criterios de aceptación

Dónde van las pruebas: **dominio** `paquetes/habitos_dominio/test/bicicleta/` (`cd paquetes/habitos_dominio && dart test`); **app** `app/test/modulos/habitos/bicicleta/` (`cd app && flutter analyze && flutter test`); **servidor** `supabase/tests/` con el siguiente número libre (hoy, después de las pruebas 122 a 127 del gimnasio, lo asigna el arquitecto); **manual** en el Galaxy A52, la laptop y la tablet, anotado en `docs/revisiones/`. Los nombres de archivo son propuestas. Cada criterio incluye un **caso malo**.

### 9.1 Contenido y reglas (B1)

| # | Criterio | Cómo se comprueba |
|---|---|---|
| CA-B-01 | **Sin contenido médico:** ningún texto del módulo contiene diagnóstico, tratamiento, medicamento, dosis, litros, gramos, calorías ni nombre de enfermedad o lesión; todo texto de seguridad incluye «no sustituye», «médico» o «emergencias» según 4.4; el texto «si te sientes mal» **no nombra síntomas**. **Caso malo:** agregar «infarto» o «500 ml» a un texto falla | `contenido_bici_test.dart` (como CA-G-03) |
| CA-B-02 | **Bloques de la salida:** con los valores iniciales, el sábado a las 8:00 con 240 min y `recordar_min = 45`, y la preparación el viernes en el primer hueco libre de 15 min desde las 19:30 y antes de `dormir − 60 min`; con la sesión C el viernes a las 19:15, la preparación se mueve al hueco siguiente y **avisa sin impedir guardar**. **Caso malo:** un hueco menor de 15 min no se ofrece | `salida_bloque_test.dart` |
| CA-B-03 | **Regreso y revisión (4.7):** salida de 4 h → regreso 12:00, cabe con 60 min de sobra; de 5 h → cabe justo; de 5 h 30 min → no cabe, faltan 30 min, con las tres propuestas; cambiar el margen o `revision_hora` cambia el resultado. **Caso malo:** la regla **nunca** mueve la revisión sola | `revision_sabado_test.dart` |
| CA-B-04 | **48 horas con la bicicleta (4.6):** C jueves 19:15 → 36 h 45 min, faltan 615 min, avisa; C viernes 20:00 → 12 h, avisa; C miércoles 19:15 → 60 h 45 min, cumple; C martes 19:15 → 84 h 45 min, cumple; C jueves 9:00 → 47 h 0 min, cumple; con `carga_piernas = ligera` ninguna avisa; con `por_esfuerzo` y tres salidas de esfuerzo 2 no avisa, con una de 4 sí. **Caso malo:** la versión corta de C **no** quita el aviso | `carga_piernas_test.dart` y ampliación de `cuarenta_y_ocho_horas_test.dart` del gimnasio (el cambio al dominio del gimnasio es decisión del dueño) |
| CA-B-05 | **Odómetro derivado:** 350 + 62 + 58 = 470 km; con una lectura de 480 km y una salida posterior de 60 km, 540 km; dos bicis llevan cada una el suyo; borrar una salida lo recalcula. **Caso malo:** una salida sin bicicleta no suma a ninguna | `odometro_test.dart` |
| CA-B-06 | **Mantenimiento:** «lubricar cadena» cada 150 km o 4 semanas, hecha a los 350 km: a 470 km no toca (120 km); a 505 km toca; a 4 semanas y 1 día toca aunque los km no lleguen; sin ningún registro dice «sin registro», no «vencida»; un intervalo vacío desactiva la tarea. **Caso malo:** un intervalo de 0 km se rechaza | `mantenimiento_test.dart` |
| CA-B-07 | **Progresión informativa:** una salida de 5 h con promedio de las últimas cuatro de 4 h (+25 %) y tope 20 % muestra la nota; con +15 % no; con menos de cuatro salidas no hay nota; no se muestra en modo foco; **nunca bloquea**. **Caso malo:** un promedio con una salida de 0 minutos no divide entre cero | `progresion_bici_test.dart` |
| CA-B-08 | **Tono:** ningún mensaje usa *fallaste, fracaso, perdiste, culpa, castigo, vergüenza* ni `!` (`MensajesHabitos.prohibidas`, `mensajes.dart:25`); la omisión por clima o seguridad **no** produce un mensaje de ruptura | `mensajes_bici_test.dart` |
| CA-B-09 | **Clima V1:** cada casilla produce su texto fijo; ninguna bloquea; «Posible lluvia» y «Mucho calor» sugieren y no obligan; sin red funciona; el enlace de clima **no** se guarda en la salida | `clima_test.dart` |
| CA-B-10 | **Cansancio:** con «Cansado» propone «ruta más corta o de calle plana» y no bloquea; la regla de cansancio acumulado se aplica a la **última sesión de piernas**, sea el día que sea | `cansancio_test.dart` |
| CA-B-11 | **Objetivo «Bicicleta»:** meta mensual de salidas sin racha semanal; una salida omitida por clima no rompe nada ni muestra texto de ruptura; marcar *Salí* escribe `hecho` en `hab_registros` con el id v5 del bloque y la fecha. **Caso malo:** una semana sin salida no produce «racha rota» | `objetivo_bici_test.dart` |
| CA-B-12 | **Modo foco:** con `ModoFocoActivo = true` no hay nota de progresión, la salida sigue disponible y los textos de seguridad **siguen visibles**; la bicicleta no recibe ni expone qué hábito causó el foco | `modo_foco_bici_test.dart` |
| CA-B-13 | **Lista de preparación:** los puntos por tipo de ruta (calle, terreno, mixta) salen como en 4.2; la persona apaga un punto y agrega hasta 10 propios de 60 caracteres; el once se rechaza; marcar y desmarcar no bloquea nada | `preparacion_test.dart` |
| CA-B-14 | **Enlaces:** solo `https`, `tel`, `sms` y `geo`; se rechazan `javascript:`, `intent:`, `file:`, `content:`, `http:` sin cifrar y cualquier otro; nada se abre sin un toque; con la app destino ausente, la app dice «No se pudo abrir» y no falla; un cliente HTTP falso no registra **ninguna** petición de la app durante una sesión completa de V1 | `enlaces_test.dart` |
| CA-B-15 | **Hoy:** el viernes por la noche muestra «Prepara tu salida»; el sábado muestra la tarjeta con regreso estimado y encaje con la revisión; la tarjeta no aparece en la tablet pública con ruta ni contacto | `hoy_bici_test.dart` |

### 9.2 Servidor (B2)

| # | Criterio | Cómo se comprueba |
|---|---|---|
| CA-B-16 | **RLS:** el dueño no lee lo de la pareja ni al revés; el coadministrador no lee lo del dueño; la cuenta maestra, el cuidador, Hogar y `anon` no leen ni escriben nada de las cinco tablas; una persona dada de baja pierde el acceso. **Bitácora:** una entrada con la tabla `hab_bici_salidas` es rechazada y no se muestra al dueño ni a la maestra | `supabase/tests/NNN_hab_bici_rls.sql` |
| CA-B-17 | **Esquema y rangos:** `esfuerzo` 1 a 5; `distancia_m` 0 a 1 000 000; `duracion_min` 1 a 1 440; `n` 1 a 3; `superficie`, `clima`, `estado` y `motivo` solo de sus listas; `enlace` empieza por `https://`; un `odometro_m` negativo se rechaza; `lectura_odometro` sin `odometro_m` se rechaza; el servidor pone `persona_id`, `hogar_id` y `actualizado_en`; gana el último cambio y uno en el futuro lejano se ajusta | `supabase/tests/NNN_hab_bici_esquema.sql` |
| CA-B-18 | **Sin ubicación en el servidor:** no existe en ninguna tabla `hab_bici_*` ni `hab_musica_listas` columna de latitud, longitud, trazo, ruta, domicilio, contacto o teléfono (consulta al catálogo del esquema); `hab_bici_salidas` no tiene llave a ninguna ruta. **Caso malo:** agregar una columna `ruta` falla la prueba | `supabase/tests/NNN_hab_bici_sin_ubicacion.sql` |
| CA-B-19 | **Un sobre de tipo `ubicacion_local` es rechazado** por la restricción de `hab_sobres.tipo`; la prueba cubre **también** `salud_local` si ya existe | `supabase/tests/NNN_hab_bici_sin_sobres.sql` |
| CA-B-20 | **Borrar mis datos:** `hab_borrar_mis_datos('todo')` y el alcance `bicicleta` borran las cinco tablas; el borrado de una baja a los 90 días las incluye; una tabla ausente de la lista falla la prueba (H-10 del gimnasio) | `supabase/tests/NNN_hab_bici_borrado.sql` |
| CA-B-21 | **Cuotas:** superar el tope de filas de `hab_bici_salidas` da 54000; una tabla sin tope en `hab_cuota_filas` falla la prueba | `supabase/tests/NNN_hab_bici_cuotas.sql` |
| CA-B-22 | **Idempotencia:** insertar la misma salida o el mismo mantenimiento con el mismo id v5 no duplica; con el mismo id y otro contenido gana el de `modificado_en` más reciente | `supabase/tests/NNN_hab_bici_idempotencia.sql` |
| CA-B-23 | **Enlaces de música:** `https`, 10 a 300 caracteres; el gimnasio y la bicicleta pueden leer la misma lista | `supabase/tests/NNN_hab_musica_listas.sql` |

### 9.3 App y plataforma (B3 y B5)

| # | Criterio | Cómo se comprueba |
|---|---|---|
| CA-B-24 | **Sin conexión:** el registro, el historial y el mantenimiento funcionan sin red; lo hecho se encola con los tipos `habitos.bici_*` y sube con el **mismo id** al volver la señal; el reintento no duplica y el orden respeta las llaves. **Caso malo:** un registro escrito directo con `upsert` falla la prueba de la cola | `cola_bici_test.dart` |
| CA-B-25 | **Ubicación solo local:** las rutas y el contacto se guardan solo en el almacén local cifrado con la llave local; ninguna cola ni consulta a la red los contiene (se busca una cadena marcada en todo lo persistido y en todo lo enviado con un cliente falso); no entran en el respaldo automático de Android; **activar la nube de `habitos_sensibles` o `diario_oracion` no los sube**; la pantalla lleva FLAG_SECURE. **Manual:** FLAG_SECURE | `ubicacion_local_test.dart` |
| CA-B-26 | **V1 sin paquetes ni permisos nuevos:** el `pubspec.yaml` al cerrar B7 no agrega ninguna dependencia respecto a la de antes de B1, y el manifiesto no declara `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE*`, `WAKE_LOCK`, `BLUETOOTH*` ni permisos de Health Connect. **Caso malo:** agregar `geolocator` falla la prueba | `sin_paquetes_bici_test.dart` + revisión de calidad |
| CA-B-27 | **Sin IA:** ningún archivo de `bicicleta` importa el cliente del asistente ni llama a `gravity-asistente`; un cliente HTTP falso no registra ninguna petición en una sesión completa; el filtro de D3 rechaza las claves de 7.3 | `sin_ia_bici_test.dart` + prueba de la función del asistente |
| CA-B-28 | **Roles:** dueño, coadministrador y familiar ven la bicicleta; cuidador, Hogar y la cuenta maestra no la ven | `bici_por_rol_test.dart` (plataforma) |
| CA-B-29 | **Tablets (D21):** la **pública** con nombre y PIN solo ve la tarjeta de Hoy sin ruta ni contacto y no recibe recordatorios; la **personal** se comporta como el teléfono con su propio almacén local; la **laptop** no muestra rutas ni contacto y lo dice. **Manual** en la tablet | pruebas de widget + manual |
| CA-B-30 | **Accesibilidad (6.6):** letra al 200 % en 360 dp y desde 900 dp sin desbordes; cronómetro con botones de 64 dp o más y resto de 48 dp o más; cada punto de la lista anuncia su estado; nada depende solo del color; contraste del tema de alto contraste. **Manual:** lectura al sol | `accesibilidad_bici_test.dart` (como el criterio 57 de la Fase 3); manual |
| CA-B-31 | **Notificaciones discretas:** los títulos nuevos (si se veta el uso de bloques) tienen 40 caracteres o menos, sin dígitos ni nombres; los bloques usan el título existente. **Manual:** que el aviso de 7:15 llegue con la app cerrada en el A52 | `mensajes_bici_test.dart`; manual |
| CA-B-32 | **Herramienta de GRAVITY:** `habitos.abrir_bicicleta` es `soloLocal` y no escribe; ninguna herramienta devuelve rutas, contacto, distancias ni kilometraje | prueba del registro de herramientas |
| CA-B-33 | **Contacto de emergencia:** *Llamar* es un toque y abre el marcador con el número; *Avisar mi hora de regreso* abre la aplicación de mensajes con el texto y **no envía nada**; el manifiesto no declara `SEND_SMS`, `READ_CONTACTS` ni `CALL_PHONE`. **Caso malo:** la app **nunca** llama ni envía sin un toque | `contacto_test.dart` + manual en el A52 |
| CA-B-34 | **Pocos toques:** *Salí* en Hoy es 1 toque; registrar con todo como se planeó es 3; mantenimiento hecho son 2; llamar al contacto es 1 | `toques_bici_test.dart` (pasos) |

### 9.4 V2 y posteriores (**solo si el dueño aprueba los paquetes; no se construyen sin esa aprobación**)

| # | Criterio | Cómo se comprueba |
|---|---|---|
| CA-B-40 | **Una salida de 4 horas se graba completa** con la pantalla apagada y sin conexión, y la traza queda en el tipo local | **Solo en dispositivo** (A52) |
| CA-B-41 | **Recuperar:** si la app se cierra o el teléfono se reinicia, la salida en curso se recupera sin perder los puntos ya guardados | prueba de la traza con almacén falso + **manual** |
| CA-B-42 | **Terminar exige mantener 2 segundos**; un toque no termina; el bloqueo táctil evita toques accidentales | prueba de widget + manual |
| CA-B-43 | **Batería:** el consumo medido en 4 h en el A52, con y sin modo ahorro, queda por debajo del umbral que se fije tras B8 (**propuesta inicial: no más de 15 % por hora, sin fuente, se ajusta con la medición**) | **Solo en dispositivo** |
| CA-B-44 | **Permisos y mapas:** sin permiso de ubicación la app explica por qué y lleva a concederlo, sin romperse; sin mapas descargados avisa **antes de salir**; el permiso se pide al usarlo, no al abrir la app | prueba de widget + manual |
| CA-B-45 | **GPX:** importar y exportar un archivo conserva puntos, altitud y tiempo; al exportar **se recortan 200 m al inicio y al final por omisión** y se avisa antes de compartir; un GPX malformado se rechaza sin cerrar la app | `gpx_test.dart` (archivos de ejemplo inventados) |
| CA-B-46 | **Puntos privados y borrables:** cada traza y cada ruta se borra del equipo; el respaldo local con la frase la incluye; la nube no la ve (CA-B-25 sigue) | `traza_privada_test.dart` |
| CA-B-47 | **Health Connect:** solo con permiso explícito pedido al usarlo; verifica que Health Connect esté disponible (Android 13 o anterior: app aparte); escribe solo tipo bicicleta, inicio, fin, distancia y, si la persona lo activó, la ruta; **nunca** esfuerzo, notas, contacto ni mantenimiento; muestra la ayuda para el permiso de rutas | fake de Health Connect + manual |
| CA-B-48 | **La música baja cuando la app habla y vuelve después** (aceptación del diseño, `:2297`) | **Solo en dispositivo**; depende de la decisión de manejo del foco de audio |
| CA-B-49 | **SOS con ubicación:** compone el texto con la última posición; la persona toca Enviar; sin posición, avisa que no la tiene | prueba de widget + manual |

---

## 10. Pruebas: qué se automatiza y qué solo se prueba en el dispositivo

**Automatizable (V1):** CA-B-01 a 15 (dominio puro, con tablas de ejemplos y **reloj y programador falsos**); CA-B-16 a 23 (pruebas SQL, `supabase/tests/correr.sh`); CA-B-24 a 34 (pruebas de widgets y de casos de uso con **cliente HTTP, almacén local y cola falsos**). El choque de 48 h, la hora de regreso y el odómetro son **funciones puras**: se prueban con las tablas de las secciones 4.6, 4.7 y 4.8.

**Solo en dispositivo** (las hace el dueño o calidad y se anotan en `docs/revisiones/`):

| Qué | Dónde | Por qué no se automatiza |
|---|---|---|
| El aviso de las 7:15 y el de las 14:15 **llegan con la app cerrada y la pantalla apagada** | Galaxy A52 | Android puede retrasar alarmas inexactas con el ahorro de batería (`fase-3-habitos.md:625`, observación 7) |
| Los enlaces **abren la app correcta** (Spotify, Amazon Music, mapa, clima, marcador, mensajes) y fallan con elegancia si no está | A52 | Depende de qué apps tiene el teléfono |
| **FLAG_SECURE** en rutas, contacto y resumen; el almacén local **fuera del respaldo** de Android | A52 | Es de plataforma |
| **Legibilidad al sol** de la tarjeta y del cronómetro | A52 y tablet | No se mide con una prueba de contraste |
| **Tablet personal y pública** (retención de la sesión, contexto) | Tablet | Depende del dispositivo |
| **V2: 4 h de grabación**, batería, recuperación, hold-to-end, voz con música, permiso de rutas de Health Connect | A52 | Sensores, energía y servicios del sistema |
| **Revisión del texto de seguridad** y de los **intervalos de mantenimiento** por una persona competente (mecánico de bicicletas, y un profesional para el texto de salud) | — | No es comprobable por código |

---

## 11. Riesgos

| # | Riesgo | Mitigación |
|---|---|---|
| R-B-1 | **Batería** en 4 h de GPS con la pantalla encendida o apagada (V2) | B8 mide antes de decidir; modo ahorro en la propia interfaz (PB-16); servicio en primer plano con notificación; sin mapa en vivo si no cabe en la batería; la V1 no usa GPS |
| R-B-2 | **GPS débil o sin señal** en calle y terreno (V2) | Indicador de señal; la grabación **no pierde lo guardado**; guardado incremental; mapas sin conexión; la V1 no depende de la señal |
| R-B-3 | **Seguridad en tránsito:** distracción por usar el teléfono en movimiento | La V1 no tiene nada que operar en movimiento (todo se hace parado); en V2, botones grandes, voz breve, hold-to-end, bloqueo táctil, sin mapa interactivo (HB-08); texto fijo de seguridad (1.2, 4.4) |
| R-B-4 | **Falsa sensación de seguridad por el contacto o el SOS** | La app dice «GRAVITY no vigila tu salida; si no regresas, nadie recibe un aviso automático»; el SOS de la V1 es **llamar o escribir**, no enviar ubicación; no se promete detección de caídas (HB-05, V3 y sin sensores) |
| R-B-5 | **Clima** (lluvia, calor, frío) | Casillas con texto fijo (4.3); la omisión por clima no produce ruptura (4.11); el servicio de pronóstico solo con aprobación (3.2) |
| R-B-6 | **Datos de ubicación** salen por una vía no prevista (un enlace pegado con coordenadas, un GPX compartido, un mensaje) | Los enlaces de ruta viven en el tipo local; el GPX se recorta al exportar y avisa; el SMS lo envía la persona; CA-B-14, 18, 25 y 45 |
| R-B-7 | **Los intervalos de mantenimiento no tienen fuente** | Marcados `borrador`; editables; «confirma con el manual o tu taller»; revisión por un mecánico (sección 10) |
| R-B-8 | **Las rutas y el contacto se pierden si se pierde el teléfono** (solo local) | Entran al respaldo local cifrado con la frase (como las molestias del gimnasio, R-8); se avisa al guardarlas |
| R-B-9 | **Un patrón de salidas insinúa cuándo no estás en casa** | RLS «solo tú»; solo fechas y duraciones, sin lugares; riesgo aceptado y mostrado en la pregunta 7; la alternativa es cifrar también las salidas (D13) |
| R-B-10 | **La bicicleta compite con la fuerza y se ve como una exigencia** | 4.6 trata la carga con opciones; 4.11 quita la racha; 4.9 solo informa |
| R-B-11 | **El aviso de 48 h se vuelve ruido** si el dueño deja C el jueves | «Dejarlo así» con memoria por semana (decisión del dueño, 4.6); opción 1 o 3 |
| R-B-12 | **Paquetes con licencia o términos que cambian** (`flutter_blue_plus`, `flutter_background_geolocation`, Spotify) | Solo se proponen los de licencia verificada; todo está marcado «decisión del dueño, no aprobado»; se verifica lo vigente antes de fijar (HB-04) |
| R-B-13 | **El número de emergencias es de otro país** | Es un valor editable de Ajustes; 911 en México se marca **[confirmar]** |
| R-B-14 | **La música y los audífonos tapan el tráfico** | Recordatorio de escucha exterior (4.2, HB-05); en V2 la voz y la música no suben el volumen |

---

## 12. Propuestas, pedidos y la decisión nueva

### 12.1 Propuestas de esta versión (y qué pasa si se vetan)

| # | Propuesta | Dónde | Si se veta |
|---|---|---|---|
| PB-01 | **V1 sin paquetes, V2 con aprobación**; GPS y visor no bloquean lo demás | 0, 1.1, 3 | Construir el GPS primero (el diseño, `:1471`) |
| PB-02 | Prefijos `hab_bici_*` y `hab_musica_*`, tablas editables con último-gana | 5.2 | Otro prefijo exige ampliar bitácora y listas (H-09 y H-10 del gimnasio) |
| PB-03 | Tipo local `ubicacion_local` (y `salud_local`) como **datos** de una lista «solo local» | 7.1 | Dos tipos hechos a mano, o rutas y contacto en `habitos_sensibles` con el riesgo de subir con la nube |
| PB-04 | La salida del servidor **no** enlaza con ninguna ruta; el vínculo es local | 5.2, 7.1 | Un `ruta_id` opaco en el servidor (revela cuántas veces se repite una ruta) |
| PB-05 | Odómetro derivado: inicial + lecturas + salidas; **sin contador guardado** | 4.8 | Un campo de kilometraje guardado (se desincroniza) |
| PB-06 | Objetivo «Bicicleta» como meta mensual, sin racha semanal | 4.11 | Una racha semanal que se rompe con la lluvia |
| PB-07 | `carga_piernas` (`normal`, `ligera`, `por_esfuerzo`) y **C el martes** como recomendación | 4.6 | Dejar el aviso del jueves cada semana |
| PB-08 | Dos bloques (preparación del viernes y salida del sábado), sin recordatorios nuevos | 4.1, 4.2 | Dos tipos de recordatorio nuevos en el catálogo |
| PB-09 | Clima en la V1: casillas y enlace; servicio solo si se aprueba, sin guardar la consulta | 3.2, 4.3 | Siempre un servicio |
| PB-10 | Contacto local y mensajes por `sms:`/`tel:` sin permisos de SMS ni de contactos | 4.4, 7.2 | Un permiso de SMS (exige revisión de políticas de la tienda **[no verificado]**) |
| PB-11 | Intervalos de mantenimiento iniciales `borrador`, sin fuente, editables | 4.8 | Pedirlos al dueño desde el inicio |
| PB-12 | Progresión informativa con tope de 20 %, editable, sin bloquear | 4.9 | Sin comparación |
| PB-13 | El mantenimiento **no** genera notificaciones; aparece en la preparación del viernes | 4.8 | Un aviso mensual |
| PB-14 | Tabla compartida `hab_musica_listas` (bici y gimnasio) con enlaces `https` | 5.2 | Una tabla por bloque |
| PB-15 | Enlaces externos: solo `https`, `tel`, `sms`, `geo`; nada se abre sin un toque | 7 | Más esquemas |
| PB-16 | Modo ahorro en la propia interfaz (fondo negro, números) sin paquete de brillo | 3.5, 6.4 | Un paquete de brillo **[no evaluado]** |
| PB-17 | Recortar 200 m al inicio y al final del GPX exportado | 3.7 | Exportar el trazo completo |
| PB-18 | Regla del regreso y la revisión: margen de 90 min, solo propone | 4.7 | Otro margen o sin aviso |
| PB-19 | Texto «si te sientes mal» sin lista de síntomas | 4.4 | Restaurar la lista del diseño (`:1453`) |
| PB-20 | Cronómetro por instantes en V1, sin pantalla encendida ni servicio | 3.1, 4.5 | Sin cronómetro |

**Decisión nueva para `DECISIONES.md` (propuesta D-B).** *«Bicicleta: primera versión sin paquetes ni permisos nuevos (agenda, preparación, registro manual, mantenimiento por kilómetros y enlaces); GPS, mapa, pantalla encendida, GPX, Health Connect y Spotify quedan como decisiones del dueño, una por una; la ubicación, las rutas y el contacto de emergencia viven solo en el dispositivo (tipo local, extensión de D21) y nunca van a la IA ni a Supabase; la regla de 48 h se resuelve entre las opciones de la sección 4.6 de su especificación.»* Cuando el dueño la apruebe, la registra el arquitecto.

### 12.2 Pedidos a otras áreas

| Área | Pedido | Sección |
|---|---|---|
| **backend** (B2) | Migración con las cinco tablas de 5.2 (checks de rango y de lista, claves compuestas, único `(persona_id, fecha, n)`, RLS, `grant` por columna, `hab_propio()` y `hab_ultimo_gana`); ampliar `hab_borrar_datos_de` (`todo` y alcance `bicicleta`), `hab_cuota_filas` y la baja a 90 días; **no** crear columnas ni tablas de ubicación; pruebas SQL de CA-B-16 a 23; entrada en `supabase/README.md` (qué ve y qué no ve el servidor) | 5.2, 9.2 |
| **plataforma** (B3) | Tipos locales como datos con `ubicacion_local`, **mismo desarrollo** que el `salud_local` del gimnasio (G3); tipos de cola `habitos.bici_*` y `habitos.musica_lista` con niveles de subida; `<queries>` del manifiesto (`https`, `tel`, `sms`, `geo`); FLAG_SECURE en rutas, contacto y resumen; rutas `bicicleta/…`; roles. **Antes de B9:** la **evaluación de paquetes** de B8 en una rama de prueba, solo con la aprobación del dueño; y la **decisión de la pantalla encendida**, que es la misma del gimnasio | 3, 7.1, 8 |
| **diseno** (B4) | Tarjeta de Hoy de la bici, lista de preparación, tarjeta de mantenimiento, hoja de registro, cronómetro, barras de historial con texto alternativo, estados vacío, cargando, sin conexión y error; maquetas B1 a B9 y, como maqueta, B10 y B11; revisar el gadget `Velocimetro` con datos reales solo cuando exista V2 | 6 |
| **asistente** (B6) | `habitos.abrir_bicicleta` (`soloLocal`, sin escribir), orden *«abre bicicleta»*, el bloque en `habitos.resumen_hoy` **sin cifras ni rutas**, el filtro de D3 de 7.3 y las tablas nuevas en `api/openapi.yaml`. **Si el dueño aprueba un servicio de clima o de teselas con clave** (3.2, 3.4), la clave va en el servidor, no en la app | 7.3 |
| **calidad** (B7 y B13) | Revisión de cierre: contenido de seguridad, RLS, **sin ubicación en el servidor ni en la IA**, sin paquetes ni permisos de ubicación en V1, accesibilidad, mediciones en el A52 y la tablet, y el registro de la revisión por una persona competente | 9, 10 |
| **arquitecto** | Registrar la decisión **D-B**; actualizar el diseño (`diseno-app-habitos.md:1398`, `:1453`, `:1468-1473`) con V1 sin paquetes y el texto de seguridad; confirmar el número de bloque; asignar migración y número de prueba SQL; una fila en `docs/ROADMAP.md` 11.4; **decidir el cambio al dominio del gimnasio** (abajo) | 1.6, 12.1 |

**Cambio mínimo y vetable al dominio del gimnasio** (el gimnasio es de `habitos` y está verificado; **esta especificación no lo toca**). Depende de la pregunta 3:

1. **Si el dueño elige la opción 1 (C el martes):** una variante del plan semanal con C el martes (hoy solo existe `cEnViernes`, `plan_semana.dart:36-55`) y la propuesta nueva «mover C al martes» en el aviso de bicicleta (hoy, `plan_semana.dart:158-160`).
2. **Si elige la opción 3 (ruta ligera):** que `gruposDeTipo` reciba `carga_piernas` (`plan_semana.dart:101-105`) para que `bici` no cuente cuando sea `ligera`, o cuando sea `por_esfuerzo` con las tres últimas salidas por debajo de 3.

---

## 13. Preguntas para el dueño

Solo las que de verdad cambian el diseño. Cada una trae mi recomendación. **Si no respondes, vale lo que dice el documento.** Las 1, 3 y 4 conviene contestarlas antes de B5; las demás no bloquean.

| # | Pregunta | Por qué cambia el diseño | Recomendación |
|---|---|---|---|
| 1 | **¿Qué parte de la bici quieres primero?** Hay tres: (a) planear, preparar, registrar y cuidar la bici **sin paquetes** (V1); (b) grabar la ruta con GPS y verla en un mapa (V2); (c) música y Health Connect | Decide el orden y cuándo hace falta tu aprobación de paquetes | **(a) primero.** Es útil desde el primer sábado, no toca tu privacidad y no instala nada. Luego (b), con mediciones, y (c) al final |
| 2 | **¿Sales en pareja el sábado?** Y si sí: ¿quieres que la app comparta algo con ella (hora de regreso, ubicación) o prefieres mandarle tú un mensaje? | La ubicación en vivo exige un servicio y rompe la regla 109 de la Fase 3 (7.4) | **V1: casilla «salí acompañado» y un mensaje que tú envías.** La ubicación en vivo, solo si lo pides, con consentimiento por salida, revocable, y después de medir el GPS |
| 3 | **¿Cómo percibes la carga de piernas de la ruta de 4 h?** Ligera, media o fuerte (con terreno incluido). Y dado que C el jueves deja **36 h 45 min** y la regla pide 47 h: ¿qué prefieres? (1) C el martes (A lunes, C martes, B miércoles); (2) dejar el aviso; (3) declarar la ruta ligera; (4) mover la ruta | Decide el plan por omisión de la semana y si se toca el dominio del gimnasio (4.6, 12.2) | Si la sientes **media o fuerte: la opción 1.** Si la sientes **ligera: la opción 3** y C el jueves. La versión corta de C **no** resuelve el aviso. Mientras no respondas, el plan queda como está y avisa |
| 4 | **¿Mapa y visor ahora o después?** Y, para decidir bien, ¿autorizas a `plataforma` a **medir** en una rama de prueba (sin integrarlos) `geolocator`, un servicio en primer plano, `wakelock_plus` y `flutter_map` en tu A52 durante una salida? | La V2 depende de paquetes y de la batería, que no se conocen hasta medir (3.3 a 3.5) | **Después de la V1**, y **sí a la medición** cuando termines B7. Nada se integra sin tu aprobación por paquete, con versión exacta |
| 5 | **¿Spotify o solo un enlace a tu lista?** | Spotify agrega un paquete, una app registrada y límites de uso; el enlace sirve para Spotify y para el Amazon Music de tu pareja | **Solo el enlace** (3.12). Los controles de medios de Android dan pausa y salto. Spotify solo si después falta ver lo que suena dentro de la app |
| 6 | **Clima: ¿abrir tu app de clima y marcar una casilla, o permitir que GRAVITY consulte un servicio con tu ubicación aproximada?** | La segunda opción envía coordenadas (redondeadas) a un tercero | **Tu app de clima y la casilla** (V1). El servicio, solo si lo pides; se redondea y no se guarda |
| 7 | **Seguridad y contacto:** ¿a quién avisas tu hora de regreso y cómo (llamada o mensaje)? ¿Aceptas que ese contacto y tus rutas vivan **solo en tu teléfono** (no en la laptop ni en la nube) y que un patrón de salidas (fecha y duración, sin lugares) sí suba a tu hogar? ¿El número de emergencias es 911? | Decide el tipo local y el alcance de lo que se ve en la laptop (7.1, R-B-9) | **Sí**, local el contacto y las rutas; en tu hogar solo fechas y números. Se confirma 911. La alternativa es cifrar también las salidas, con más trabajo |
| 8 | **Los datos de tu bicicleta:** ¿cuántos km tiene hoy, de qué tipo es, qué te dice tu taller o tu manual sobre la cadena, los frenos y la revisión general, y de dónde copias la distancia (ciclocomputador, otra app)? ¿Te sirve una **meta mensual** de salidas (3 por omisión) en lugar de una racha semanal? | Fija el odómetro inicial, los intervalos reales y el objetivo (4.8, 4.11) | **Captúralos tú en el primer uso** (F-B5); los intervalos iniciales salen `borrador` hasta que los confirmes. **Meta mensual, sin racha**: una salida que no sale por la lluvia no es un fallo |

---

## 14. Historial de versiones

Este archivo contiene **solo la bicicleta** (ruta del sábado) de la Fase 8; el gimnasio está en `fase-8-habitos-gimnasio.md`; la música como módulo, el sueño y la IA opcional se especificarán aparte.

| Versión | Fecha | Cambio |
|---|---|---|
| **0.1** | 23/nov/2026 | Primera versión (agente `habitos`). Cumple el contexto del dueño del 23/nov/2026 (bicicleta propia, rutas mixtas, sábados a las 8:00, unas 4 h, a veces en pareja; revisión a las 14:30) y su orden «además también bici». Verificado contra el diseño v1.18 (Anexo E, G.3.9, G.10.2, 5.2, 7.1), `fase-8-habitos-gimnasio.md` y el código de `paquetes/habitos_dominio`, `app/lib/modulos/habitos`, `app/lib/nucleo`, `app/lib/diseno`, `app/pubspec.yaml`, el manifiesto de Android y `supabase/migrations` (21 hallazgos HB-01 a HB-21 y 9 conflictos CB-1 a CB-9); consulta de 11 paquetes en pub.dev el 23/nov/2026. 20 propuestas PB-01 a PB-20, 49 criterios CA-B y 8 preguntas al dueño |
