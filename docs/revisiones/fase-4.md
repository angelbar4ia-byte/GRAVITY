# Revisión de calidad — Fase 4 (Pulido 1)

Revisor: agente calidad · Fecha: 7/nov/2026 · Árbol: `ec49699` más los archivos de calidad de la sección 9.
Alcance: `docs/specs/fase-4-pulido.md` v0.2 (con la sección 14), `fase-4-alimentacion.md`, `fase-4-finanzas-aporte.md`, `fase-4-vista-temporal.md`, D22 a D27; `app/lib/diseno` (Glass), `app/lib/nucleo/seguridad`, `app/lib/app` (capturas, invitación, tablet), `app/lib/modulos/{alimentacion,ajustes,finanzas,gravity}`, `paquetes/finanzas_dominio` y las pruebas de servidor.

## 1. Veredicto

**Aprobada con condiciones. 0 bloqueantes, 5 importantes, 8 menores.** La base de privacidad aguanta: el PIN de 600 000 vueltas corre en un `Isolate` y migra los hashes viejos, la huella solo se enciende si la persona se identifica, la frase de la nube cifrada se muestra una vez, bajo `FLAG_SECURE`, sin poder copiarse y con confirmación de 3 palabras, el portapapeles se limpia a los 60 s, la tablet pública con Glass (noche y día) no muestra dinero, Hábitos ni datos clínicos, `app/lib/diseno` no importa red ni datos de módulos, Swagger (el estilo) y Anton no están en código, fuentes ni licencias, y Glass cumple 4.5:1 contra sus tres fondos extremos. Ni el cierre de semana (extras 20 %, sobre, sobrante, redondeo) ni el motivo de 3 caracteres tienen fallas de dominio (2 000 cierres al azar sin una sola violación).

**Lo que más pesa es Alimentación**, que está hecha solo en la app y en memoria: no hay tablas ni RLS (`ali_*`), así que los permisos de D23 viven únicamente en la interfaz (D5 pide el servidor); la matriz de permisos de la app y del servidor sigue diciendo lo anterior a D23 (Casa lee, el familiar no escribe, la maestra tiene "total"); la pantalla del menú de Papá, con su perfil clínico, no está protegida contra capturas ni vistas previas; y con sesión real muestra un menú y suplementos de ejemplo como si fueran de Papá. Como hoy todo es de ejemplo y no se guarda nada, **no hay fuga ni dato real expuesto**; la condición es **no activar Alimentación con datos reales** hasta cerrar F4-A1, F4-A2/A3, F4-A6 y las tablas del servidor (F4-B1).

Otro importante: las verificaciones de PIN en cambiar PIN y en montos revisan el bloqueo fuera de la fila (F4-S1), así que ráfagas de toques se saltan el límite de 5 intentos.

**Lo pendiente que no es fallo:** la vista temporal de Finanzas de Papá para el familiar (D24) **no se ha construido** (ni en app ni en servidor); y las mediciones en el Galaxy A52 y en la laptop (arranque, gasto, hábito, PIN) quedan **manual pendiente**; tampoco existen `MedidorArranque` ni `app/test/rendimiento/`.

Límites (honestidad): no tuve el Galaxy A52, la laptop Windows ni TalkBack/Narrator, no corrí Deno ni un teléfono real, y no probé `SetWindowDisplayAffinity` en Windows. Lo que digo de Windows y de rendimiento real lo leí en el código. Los criterios los asigné por el nombre y el contenido de las pruebas; solo marco "re-probado" lo que corrí por mi cuenta.

## 2. Pruebas corridas

| Comando | Resultado |
|---|---|
| `flutter analyze` (app) | Sin problemas |
| `flutter test --exclude-tags hallazgo` (app) | 2457 pasan antes de mis pruebas; con mis 34 guardias nuevas, 2491 pasan y ninguna falla (corrida completa); las 4 de `f4_d3_fuentes_test.dart` las corrí aparte (pasan): 2495 en total. 14 omitidas (las capturas, que piden `CAPTURAS_DIR`) |
| `paquetes/finanzas_dominio`: `dart test` | 304 pasan |
| `paquetes/habitos_dominio`: `dart test` | 44 pasan |
| `bash supabase/tests/correr.sh` | 37 archivos, 2146 afirmaciones, todo pasa |
| `bash herramientas/respaldo/probar_respaldo.sh` | 44 comprobaciones, todo pasa |
| `api`: `npm run verificar` y `npm run validar` | Al día / válido |
| `psql -f supabase/tests/hallazgos_fase4.sql` (no entra en la corrida normal) | F4-A3, F4-B1, F4-B2, F4-M1, M1b, M1c y F4-A2 salen ABIERTO |
| `flutter test --tags hallazgo test/revision_calidad/f4_*` | 11 fallan a propósito (F4-A1 a A6, F4-S1, F4-I1, F4-X1 en tres estilos) |
| Medición propia: `pin_600k_test.dart` en esta máquina (VM, no el A52) | crear 600 000 vueltas = 1036 ms; verificar = 1012 ms |

## 3. Hallazgos bloqueantes

Ninguno.

## 4. Hallazgos importantes

### F4-A1. La pantalla del menú de Papá (perfil clínico) no está protegida contra capturas ni vistas previas
- `esPantallaSensible` (`app/lib/app/pantalla_segura.dart`) cubre Finanzas, Cuidados, Hoy, avisos y lo reservado de Hábitos, pero **no `/alimentacion`**. El menú de Papá pinta "Adulto mayor con Alzheimer · Dieta alta en proteínas… · No puede comer alimentos duros". Ni `FLAG_SECURE` (Android) ni `WDA_EXCLUDEFROMCAPTURE` (Windows) se activan ahí; el vistazo reciente del sistema y las capturas lo muestran. La spec del pulido (9.1) dice que las pantallas nuevas quedan cubiertas "por la misma regla de rutas": la regla no las incluye.
- Reproducir: `app/test/revision_calidad/f4_alimentacion_test.dart` (F4-A1, etiqueta `hallazgo`): `esPantallaSensible('/alimentacion', Rol.dueno)` es `false`.
- Corrige: **plataforma** (agregar `/alimentacion` para quien ve el menú de Papá; el menú de la pareja no es clínico, pero la ruta es la misma). Alternativa: que `PantallaMenuSemana` pida `PantallaSegura` solo cuando muestra el perfil.

### F4-A2 / F4-A3. La matriz de permisos (app y servidor) no sigue D23 y el ajuste del 6/nov
- Servidor (`permisos_rol`, migración base) y espejo (`nucleo/permisos/permisos.dart`), que la prueba I1 mantiene iguales entre sí:
  - **Casa** tiene fila de lectura "Menú y lista de compras (Fase 7)" (alcance `restringido`). D23 y la spec 4 dicen que Casa no ve nada. En la app, la ruta `/alimentacion` se abre para Casa (el servicio la rechaza y la pantalla dice "No tienes menús para ver. Pide al dueño que te dé acceso."), y la herramienta `alimentacion.abrir` se ofrece a Casa. Si backend arma las políticas desde `permisos_rol` como en Finanzas, Casa leería el perfil clínico de Papá.
  - El **familiar** solo tiene `leer` "su parte". D23 (ajuste) le da **escribir** el menú de Papá. Una RLS derivada de la matriz se lo negaría; una escrita a mano (spec, sección 6) contradiría el espejo.
  - La **cuenta maestra** (coadministrador) tiene `alimentacion = total` en servidor y espejo; D23 y D19 dicen solo lectura (el servicio de la app ya lo respeta, el servidor no lo sabe). El ROADMAP (línea 482) ya lo dejaba pendiente.
- Reproducir: `f4_alimentacion_test.dart` (F4-A2, F4-A3); en SQL, `hallazgos_fase4.sql` (F4-A2: Casa tiene `alcance` de lectura; F4-A3: el familiar no puede `escribir`).
- Corrige: **arquitecto** (decidir la matriz y el espejo, son de `nucleo/permisos`) + **backend** (migración con la matriz y `ali_puede(menu, accion)` de la spec, sección 6; sin esto, no usar `permisos_rol` para las políticas de `ali_*`) + **plataforma** (navegación y herramienta de Casa). Después se actualiza I1.

### F4-A5. La cuidadora no tiene camino al menú de Papá
- D23 y el criterio 4 de la spec de Alimentación: "La cuidadora ve el de Papá sin controles de edición". Hoy `calcularRedireccion('/alimentacion', Rol.cuidador)` la manda a `/cuidados` (la matriz le da "desde Cuidados", sin acceso directo) y su navegación no tiene Alimentación. La pantalla solo se comprueba montándola suelta. Depende de la Fase 5 (Cuidados) o de abrir la ruta solo para ella.
- Reproducir: `f4_alimentacion_test.dart` (F4-A5). Ver también la fila del familiar: sí llega por *Más* (reviso `modulosEnMas`), sin pestaña propia.
- Corrige: **arquitecto/plataforma** (decidir si entra por Cuidados en la Fase 5 o se abre ya); registrar como pendiente si es Fase 5.

### F4-A6. Con sesión real, Alimentación muestra un menú y suplementos de ejemplo como si fueran de Papá, y no guarda nada
- `repositorioAlimentacionProvider` arma siempre `RepositorioAlimentacionEnMemoria` con el menú y los suplementos de ejemplo (p. ej. "Multivitamínico · 1 tableta · Desayuno" en el menú de Papá), sin importar si la sesión es real, sin etiqueta de "datos de ejemplo", y lo editado se pierde al cerrar. Es el mismo principio de I9 de la Fase 1 ("con sesión real no hay cifras de ejemplo"), que aquí no se aplicó. Para un cuidador o el familiar, un suplemento inventado puede leerse como indicación.
- Reproducir: `f4_alimentacion_test.dart` (F4-A6): con `ServicioSesionFalso` (no demostración) el repositorio devuelve 2 suplementos de ejemplo para Papá.
- Corrige: **alimentacion** (con sesión real: vacío o un aviso fijo "Datos de ejemplo, no guardados"; solo la demostración trae el ejemplo) hasta que **backend** entregue las tablas (F4-B1).

### F4-S1. El límite de 5 intentos se salta en cambiar PIN y en los montos
- `SerieDePin` pone las verificaciones en fila, pero solo `desbloquearConPin` y `comprobarPin` del bloqueo (y su gemelo en la tablet) revisan el bloqueo **dentro** de la fila. `ControladorBloqueo.cambiarPin`, `ControladorTablet.cambiarPin`, `ControladorMontos._cambiarPropio` y `ControladorMontos.verificar` (fuente propia) revisan `_intentos.bloqueado` **antes** de entrar a la fila: varias llamadas simultáneas pasan todas la revisión y la fila las ejecuta una por una sin volver a revisar. Además `ControladorBloqueo` (activar con PIN propio, línea ~248) llama a `verificarAsync` sin pasar por la fila.
- Efecto medido: ocho llamadas a `cambiarPin('000000', …)` a la vez dieron **7** `pinIncorrecto` (el máximo permitido es 4; el quinto fue `bloqueado` y los tres siguientes volvieron a probar PIN) y un PIN bueno enviado en la misma ráfaga entró (`abierto`) con la cuenta ya bloqueada. Con 600 000 vueltas cada intento tarda del orden de 1 s, así que la ventana es una ráfaga de toques o un guion, no un ataque remoto; por eso no es bloqueante.
- Reproducir: `app/test/revision_calidad/f4_pin_serie_test.dart` (F4-S1, etiqueta `hallazgo`). Las mismas pruebas con `desbloquearConPin` y `comprobarPin` pasan.
- Corrige: **plataforma** (mover la revisión de `bloqueado` a dentro de `_serie.correr(...)` en los cuatro sitios, y meter en la fila la verificación de activar bloqueo).

## 5. Hallazgos menores

- **F4-A4. El servicio de Alimentación no pide permiso para leer el catálogo de platillos** (`platillos()`), así que Casa lo lee; el campo `duros` delata la textura del perfil de Papá. `f4_alimentacion_test.dart` (F4-A4). Corrige: alimentacion.
- **F4-I1. El código de invitación se pinta en un `SelectableText`**: mantener pulsado y "Copiar" lo deja en el portapapeles del sistema **sin** el borrado a los 60 s; el aviso de la pantalla dice "Si lo copias, se borra". El botón Copiar sí lo borra (re-probado: 60 s, respeta lo copiado después, y al volver a primer plano). El diálogo tampoco pide `FLAG_SECURE`. `f4_invitacion_portapapeles_test.dart` (F4-I1). Corrige: plataforma.
- **F4-X1. Ajustes › Privacidad desborda con letra 2.0 a 360 dp**: el `DropdownButton` de "Ocultar los montos tras" va como `trailing` de un `ListTile` y ocupa todo el ancho (`pantalla_privacidad.dart:120`). Pasa igual con el Futurista; no depende de Glass. `f4_matriz_glass_test.dart` (F4-X1, tres estilos). Corrige: plataforma.
- **F4-M1. El servidor acepta motivos que la app rechaza.** La app (`motivoValido`) exige 3 caracteres visibles, **al menos 2 letras o dígitos y no todos iguales**; su comentario dice que "es la regla de `fin_motivo_valido` en el servidor", pero el servidor solo cuenta 3 visibles: acepta `___`, `...` y `aaa`. La spec del aporte (F4-3.1.3) pedía la misma regla en ambos, y backend no tiene migración en la Fase 4. La app protege el camino normal; una llamada directa o una versión vieja no. `hallazgos_fase4.sql` (F4-M1, M1b, M1c). Corrige: backend.
- **F4-D1. El cambio de claro/oscuro no espera a que se cierre una acción.** La spec (4.2, punto 3, criterio 10) pide que el cambio espere si hay hoja, formulario con datos, teclado o sesión en curso; no encontré nada de eso en `app/lib/diseno` ni en `app_gravity.dart` (solo el cambio por hora y por sol, probado). Como `ThemeMode` conserva el estado, el efecto es un fundido de 300 ms a mitad de una acción, no pérdida de datos. Sin prueba (lectura). Corrige: diseno.
- **F4-W1. (Por verificar en Windows) El protector de capturas usa `GetActiveWindow`**, que devuelve 0 si la ventana de la app no está activa en ese momento; entonces `SetWindowDisplayAffinity` no se llama, la función regresa `false` sin registrarlo, y `ControladorPantallaSegura` da por aplicada la protección y no reintenta (solo `reaplicar()` al cambiar el ajuste). Si una ruta sensible se abre con la ventana en segundo plano o recién abierta, quedaría sin protección. Lo leí en el código; hay que probarlo en la laptop con Win+Shift+S. Corrige: plataforma (usar el HWND de la vista de Flutter y reintentar al recuperar el foco).
- **F4-A7. (Pregunta al dueño) El perfil real de Papá está escrito en el código y en las pruebas** (`app/lib/modulos/alimentacion/datos/perfiles.dart`: 80 años, Alzheimer, dieta, textura), sin nombre. El contrato de servidor prevé que viva en la base (`ali_menus.perfil`, "dato clínico"). El repositorio es privado y D23 ya está en `docs/`, pero conviene que el dueño diga si acepta ese texto en el código fuente.
- **F4-H1. La huella abre sin exigir el cambio de un PIN corto** de quien ve dinero (`desbloquearConHuella` no revisa `pinEsCortoParaSuRol`). Solo afecta PIN viejos de 4 o 5 dígitos; el PIN sí lo exige. Corrige: plataforma.

## 6. Revisado y sin hallazgo

- **PIN de 600 000 (re-probado):** constante 600 000; hashes de 10 000 y 100 000 se reconocen y se rehacen con la derivación en hilo aparte; la versión asíncrona da el mismo hash que la síncrona (`pin_600k_test.dart`, `migracion_vueltas_test.dart`); las derivaciones de la interfaz usan las versiones `*Async`. Las llamadas síncronas que quedan son de demostración y de pruebas. `desbloquearConPin` y `comprobarPin` simultáneos respetan el límite de 5 (re-probado con 9 llamadas a la vez).
- **Huella:** `activarHuella` exige autenticarse y que haya huellas registradas; sin bloqueo con PIN no se activa; apagarla no pide nada; en la tablet compartida no abre (B3, re-probado por la prueba existente).
- **Nube cifrada en Ajustes:** frase de 12 palabras con 128 bits de entropía (aleatoria segura); el diálogo no se cierra tocando fuera, va bajo `PantallaSegura`, las palabras son `Chip` (no seleccionables), se confirman 3 posiciones al azar (sin acentos y en mayúsculas se acepta) y se pide el PIN antes de guardar llaves en laptop y tablet personal; toda la sección va dentro de `PuertaReservada` (no existe en la tablet pública).
- **Invitación:** el código se muestra una vez en un diálogo; el botón Copiar usa `PortapapelesTemporal` (60 s, respeta lo copiado después, borra al volver a primer plano); el rol `dueno` no se asigna y no se acepta una invitación de otro correo; "Tengo una invitación" funciona sin sesión y con sesión abierta lleva al inicio.
- **Personas:** el servidor (`membresias_editar`) solo deja al dueño, no a sí mismo y no a `dueno`; la baja pone `activa = false` y `rol_en_hogar` exige `activa`, así que el acceso se pierde al instante aunque el reloj del equipo esté mal; el router cierra `/ajustes/personas` a quien no administra (`seccionDisponible`).
- **Finanzas en Hoy solo por rol:** `resumenFinanzasHoyProvider` filtra al armar la lista (sin libros que la persona solo lee como maestra o lector); familiar, cuidador y Casa: `sinAcceso`; los montos ocultos se dibujan con `MontoOcultable`.
- **Tablet pública con Glass (re-probado, `f4_tablet_glass_test.dart`):** modo Casa con Glass noche y día: sin `MontoOcultable`, sin "$", sin Hábitos, Finanzas, Papá ni Alzheimer; el estilo del dueño se aplica después del PIN y a los 3 minutos sin uso vuelve el de la casa.
- **Glass:** contraste 4.5:1 de texto, acento, éxito, alerta y peligro contra el fondo, el segundo color y la mancha, y contra el panel translúcido sobre cada uno; alto contraste 7:1; en el teléfono no se usa `BackdropFilter` (esmerilado en cero); tope de 3 capas; apagado automático a menos de 45 cuadros por segundo en 5 s; los montos ocultos son otro texto, no un desenfoque; 12 pantallas reales (Hoy, Finanzas, Semana, Hábitos, Objetivos, Alimentación y compras, Ajustes, Apariencia, Personas, Notificaciones) sin desbordes con letra 2.0 a 360 y a 900 dp, y con las guías de 48 dp, etiquetas y contraste de texto de Flutter en noche y día (`f4_matriz_glass_test.dart`; Privacidad es F4-X1).
- **Bento en pausa y Swagger eliminado:** `estilosIncluidos` = Futurista y Glass; Bento solo en `estilosEnPausa`; un id guardado `swagger` o `bento` vuelve al Futurista. No hay Anton ni `swagger.dart`; "Swagger" que queda en el repositorio es **Swagger UI**, el explorador de APIs de *Ajustes › Desarrollador* (D16), y la palabra clave de la herramienta que lo abre; no es el estilo.
- **Fuentes y licencias (re-probado, `f4_d3_fuentes_test.dart`):** cada familia del `pubspec.yaml` tiene carpeta, archivos y `OFL.txt` con la SIL Open Font License, y está en `licencias.dart`; no hay carpetas sin declarar; las fuentes pesan 2.85 MiB en total (2 985 300 bytes; las dos nuevas, Inter y Plus Jakarta Sans, 1.25 MiB). Verifiqué con fontTools que las cinco familias (18 archivos) traen á é í ó ú ñ ü ¿ ¡ $ % y que Inter y Plus Jakarta Sans tienen la característica `tnum`; los montos usan Inter con `FontFeature.tabularFigures`.
- **D3 en el diseño:** `app/lib/diseno` solo importa `nucleo/contratos`; ningún paquete de analítica, fallas ni `google_fonts` en el `pubspec`. Las órdenes de Hábitos reservadas no se guardan en historial; `alimentacion.abrir` solo navega.
- **Alimentación, servicio:** la matriz de D23 en el servicio (re-probado con los cinco roles y la maestra): dueño y pareja editan los dos menús; el familiar edita solo el de Papá y no ve el otro, ni suplementos, ni compras; la cuidadora solo lee el de Papá y su lista; la maestra solo lee los dos; Casa no ve ni el perfil. El perfil clínico solo está en `perfiles.dart` (no aparece en otro archivo de `lib/`); el módulo no importa asistente, voz, herramientas, sesión ni red y no usa portapapeles ni compartir.
- **Dominio del cierre (re-probado):** 2 000 cierres al azar: nunca se aparta más que el remanente, no queda negativo, el sobre no pasa de lo disponible, con deuda que recibe extra solo cuenta el fondo de emergencia y solo el mínimo, el orden de aplicación es extras, sobre, sobrante y redondeo, y el sobrante va a una sola bolsa (la primera de la prioridad arrastrada); los extras apartan el 20 % por omisión; ids estables y distintos por cierre, origen y bolsa; deshacer anula con contraasiento y repetirlo no hace nada (por lectura y `fase4_test.dart`). Observación: con una bolsa de sobrante, el redondeo de otra bolsa nunca recibe nada (el sobrante se lleva todo); es lo que dice la spec ("al final y solo si queda disponible").
- **Motivo de 3 caracteres (app):** `___`, `...`, `---`, `aaa`, `!!a`, ceros de ancho, relleno hangul, braille en blanco y solo espacios se rechazan; `abc`, `1.2`, `é-é` se aceptan.
- **Hoy sin datos:** `ResumenFinanzasHoy.sinDatos` dice "Sin datos todavía" con sesión real, sin cifras de ejemplo (I9 sigue en verde).
- **Secretos y datos reales:** busqué claves, tokens, PEM, JWT y llaves de servicio en todo lo que cambió desde el cierre de la Fase 3 (386 archivos): solo aparece `token-de-ejemplo-$id` en un repositorio en memoria. `data/personal/` sigue ignorada; los dos `.xlsx` de `data/` vienen de la Fase 0 (autor limpiado el 23/oct). Los datos de ejemplo de Alimentación son inventados.
- **Aserciones:** ninguna prueba existente debilitada; solo agregué archivos.

## 7. Criterios de aceptación (spec del pulido, v0.2)

Sí = con prueba que pasa · Parcial = parte con prueba, parte pendiente · Manual = solo con equipo real · N/A = fuera del alcance acotado por D27 (solo Glass; el Arquitectónico, Minimalista, Claro y Swagger no se ofrecen).

| # | Estado | Nota |
|---|---|---|
| 1 | Sí | Suites de las fases 0 a 3 en verde |
| 2 | Sí | Catálogo con Futurista y Glass; Bento en pausa; ids desconocidos (también `swagger`) vuelven al Futurista (`glass_test.dart`) |
| 3 | Parcial | Cambio en vivo y por persona sí (`cambio_estilo_test`, `apariencia_por_persona_test`); no hay prueba de que conserve el desplazamiento, el texto escrito ni la hoja abierta |
| 4 | Sí | `guardia_sin_colores_fijos_test` |
| 5 | Parcial | No existe `estilo_nuevo_test`; la matriz recorre el catálogo con gadgets y Apariencia |
| 6 a 9 | Sí | Contraste de valores, con personalidad, Glass en el peor caso (re-probado en parte) y alto contraste 7:1 |
| 10 | Parcial | Horas, sol y modos fijos sí; **no existe el "espera a que se cierre la acción"** (F4-D1) |
| 11 | Parcial | Núcleo y componentes se detienen con reducir movimiento; no hay `reducir_movimiento_test` por estilo y gadget |
| 12 | Parcial | Verificado por mí (OFL, licencias, caracteres, 3 MB; `f4_d3_fuentes_test`); falta `fuentes_test` de que los glifos se dibujan |
| 13 | Sí | Montos con Inter y cifras tabulares (`glass_test`; verificado `tnum`) |
| 14 | N/A | Arquitectónico no se construye (P1 y D27) |
| 15 | Parcial | *Desarrollador* sigue siendo Swagger UI (D16); no hay `desarrollador_estilo_test` con el estilo activo |
| 16 | Parcial | Glass aprobado por el dueño (D27, 7/nov); no hay pruebas doradas, solo capturas opcionales (`capturas_matriz_test`, necesita `CAPTURAS_DIR`) |
| 17, 18 | Parcial | Personalidad y tres opciones por módulo con pruebas sueltas (`cambio_estilo_test`, `seccion_apariencia_test`); falta `personalidad_test` y la prueba de que no apaga las excepciones en todas las combinaciones |
| 19 | Manual | Una personalidad por pantalla: revisión visual del dueño |
| 20 a 23 | Parcial | Gadgets visuales y catálogo en la matriz de gadgets (`matriz_estilos_test`, `componentes_test`, `gadgets_*`); faltan `catalogo_gadgets_test`, `gadgets_visuales_test`, `estados_gadgets_test` y `nucleo_test` por nombre |
| 24 | Parcial | 12 pantallas reales con Glass a 360 y 900 dp sin desbordes (mi `f4_matriz_glass_test`); falta 1366 dp, tablet y los cuatro estados; Privacidad desborda (F4-X1) |
| 25 | Sí | `indicador_conexion_test`, `conectividad_test`, `fondo_y_conexion_test` |
| 26 | Sí | `fase4_test` (grupo 1), `finanzas_por_rol_test` |
| 27 | Sí | `invitacion_test`, `personas_miembros_test`, `personas_hogar_test` y SQL 50 y 70 |
| 28, 29 | Sí | `editar_bloque_test`, `editar_objetivo_test`, `mis_datos_habitos_test` |
| 30 | Sí | `fase4_test` (grupo 2) |
| 31 | Sí | `nube_cifrada_pantalla_test`, `nube_cifrada_test`, `cripto_test` |
| 32 | Sí | `lector_marcas_test` |
| 33 | Parcial | `configuracion_eliminar_test` (motivos, listas, hitos, recordatorio, aviso); sin los archivos con los nombres de la spec |
| 34 | Sí | `fase4_test` (grupo 8) y SQL 87 |
| 35 | Sí | `fase4_test` (grupo 5), `cierre_ahorro_test` (dominio) y mis propiedades |
| 36 | Parcial | Avisos de flujo y de abono bajo el mínimo en `fase4_test`; no hay prueba de la tarjeta en Semana ni de la alerta roja en pantalla (`semana_alerta_test`, `deudas_alerta_test`); letra 2.0 de la fase 2 sí (`letra_grande_fase2_test`) |
| 37 | Manual | **Pendiente.** No existen `MedidorArranque`, `datos_un_ano.dart` ni `arranque_perfil_test` |
| 38 | Manual | **Pendiente.** Guardar a la vista sí (`f1_i8`); no existe `flujo_f1_test` con la cuenta de toques |
| 39 | Parcial | `toques_habitos_test`; el manual en el A52 queda pendiente |
| 40 | Parcial | Hilo aparte y equivalencia sí (`pin_600k_test`), Glass con 3 capas y apagado sí (`glass_test`), fuentes 3 MB sí; PIN ≤ 1.5 s en el A52, cambio de estilo, cuadros lentos, CPU y APK **sin medir** |
| 41 | No | No hay tabla de mediciones en A52 ni laptop (sección 8) |
| 42 | Parcial | Las tres guías de Flutter con Glass en 12 pantallas reales (teléfono, noche y día); la laptop y los demás estilos no |
| 43 | Parcial | Letra 2.0 a 360 y 900 dp en 12 pantallas con Glass; Privacidad falla en 360 dp (F4-X1) |
| 44 | Parcial | F3-12 permanente y montos ocultos sin cifra (`f1b_montos_semantica_test`); falta `semantica_gadgets_test`; TalkBack y Narrator **Manual** |
| 45 | Parcial | `componentes_test` ("siempre lleva texto"); no hay `no_solo_color_test` ni revisión en escala de grises |
| 46 | No | No existe `foco_teclado_test` |
| 47 | Sí | `glass_test` (lo oculto se sustituye) y `f1b_montos_semantica_test` |
| 48 | Sí | `f4_tablet_glass_test` (re-probado) y `tablet_test` |
| 49 | Parcial | Windows con canal falso (`protector_windows_test`); **`/alimentacion` sin cubrir (F4-A1)**; Win+Shift+S y Recortes **Manual** |
| 50 | Sí | `f4_d3_fuentes_test` (guardia de D3 sobre `lib/diseno` y el `pubspec`); no existe `d3_diseno_test` con ese nombre; el medidor de arranque no existe |
| 51 | Parcial | `PuertaReservada` cubre con fondo opaco y no existe en la tablet pública; sin `reservado_estilos_test` con Glass |
| 52 | Pendiente | `DISENO_UX_UI.md` sigue en v0.6 (lo actualiza el arquitecto) |
| 53 | Parcial | Este informe: 0 bloqueantes; mediciones pendientes (sección 8) |

## 8. Rendimiento: qué se midió y qué falta

No inventé ninguna cifra del A52. Lo único medido es lo que se puede medir sin el teléfono:

| Meta (spec, sección 7) | Qué hay | Estado |
|---|---|---|
| Abrir en ≤ 2 s (mediana de 10, peor ≤ 3 s) | `MedidorArranque` y `datos_un_ano.dart` no existen. Por lectura, `prepararArranque` espera en serie a `initializeDateFormatting`, `prepararFirebase`, `Supabase.initialize`, la sesión y la apariencia antes de `runApp`; no hay primer cuadro "esqueleto" ni diferido | **Manual pendiente** (A52 y laptop); el diferido es riesgo para la meta |
| Registrar un gasto en ≤ 10 s | Guardar a la vista a 360 × 800 y 411 × 850 dp (`f1_i8`); no hay prueba de toques del flujo (F4-1.1 y F4-1.2) | **Manual pendiente**; falta la prueba de toques |
| Acción diaria de Hábitos en ≤ 3 toques | `toques_habitos_test` | Automática parcial; **manual pendiente** (icono + marcar ≤ 6 s) |
| Entrar con PIN de 600 000 sin congelar y ≤ 1.5 s en el A52 | La derivación va en `Isolate` (prueba de equivalencia). En esta VM (no el A52, modo de pruebas) crear y verificar tardan ≈ 1.0 s cada una; la tablet suma una derivación más para abrir la credencial | **Manual pendiente**: el A52 puede pasar de 1.5 s; la spec (P10) prevé bajar las vueltas a lo que alcance |
| Cambio de estilo, cuadros lentos, CPU del núcleo | Sin medir | **Manual pendiente** |
| Glass: tope de 3 capas y apagado a < 45 cuadros por segundo | Pruebas de unidad del gestor y del monitor (`glass_test`) | Lógica sí; fps reales **sin medir** |
| Tamaño | Fuentes 2.85 MiB en total, 1.25 MiB las nuevas; `flutter build apk --analyze-size` no se corrió | APK **sin medir** |

La hoja de medición de 15 minutos por equipo que prometió la sección 16 (y el medidor en la app) **no existen todavía**: sin ellos el dueño no puede medir como ahí se propone.

## 9. Pruebas agregadas por calidad

- `app/test/revision_calidad/f4_alimentacion_test.dart`: 7 guardias (matriz D23 en el servicio con los cinco roles y la maestra; perfil clínico solo en `perfiles.dart`; sin importar asistente, voz, red ni portapapeles) y 6 hallazgos (F4-A1 a F4-A6).
- `app/test/revision_calidad/f4_pin_serie_test.dart`: 3 guardias (600 000 y migración; límite de 5 en `desbloquearConPin` y `comprobarPin` simultáneos) y el hallazgo F4-S1.
- `app/test/revision_calidad/f4_invitacion_portapapeles_test.dart`: 5 guardias del portapapeles temporal y el hallazgo F4-I1.
- `app/test/revision_calidad/f4_matriz_glass_test.dart`: 10 guardias (12 pantallas reales con Glass noche y día, letra 2.0 a 360 y 900 dp, y las tres guías de accesibilidad) y el hallazgo F4-X1 (Privacidad, con Glass y con Futurista).
- `app/test/revision_calidad/f4_tablet_glass_test.dart`: 3 guardias (modo Casa con Glass sin dinero ni Hábitos; estilo tras el PIN y regreso a la casa; el riel de Casa no lista Alimentación).
- `app/test/revision_calidad/f4_dominio_test.dart`: 6 guardias (2 000 cierres al azar, extras 20 %, prioridad, determinismo, ids estables, motivo).
- `app/test/revision_calidad/f4_d3_fuentes_test.dart`: 4 guardias (D3 en `lib/diseno`, sin analítica, familias con OFL y licencias, 3 MB).
- `supabase/tests/hallazgos_fase4.sql` (no entra en la corrida normal): F4-A2, F4-A3, F4-B1, F4-B2, F4-M1, M1b y M1c salen ABIERTO.
- Sin dependencias nuevas. Los hallazgos llevan la etiqueta `hallazgo` y se excluyen con `--exclude-tags hallazgo`.

## 10. Pedidos por agente

- **plataforma:** F4-A1 (cubrir `/alimentacion`), F4-S1 (bloqueo dentro de la fila en cuatro sitios y en activar bloqueo), F4-I1, F4-X1, F4-W1, F4-H1; `MedidorArranque`, hoja de medición y diferido del arranque (Firebase, Supabase, recordatorios después del primer cuadro).
- **arquitecto:** decidir y fijar la matriz de Alimentación (Casa nada, familiar escribe el menú de Papá, maestra solo lectura, cuidadora desde Cuidados o directo) en `nucleo/permisos` y su espejo (F4-A2, F4-A3, F4-A5); `DISENO_UX_UI.md` v0.7 (criterio 52).
- **backend:** tablas `ali_*` con `ali_puede(menu, accion)` y la RLS de la spec (sección 6), y `fin_vistas_solicitadas` (D24) cuando se construya; la regla de `fin_motivo_valido` igual que la app (F4-M1); actualizar la matriz y que la prueba I1 siga igual entre servidor y app.
- **alimentacion:** F4-A6 (sin datos de ejemplo con sesión real o con etiqueta), F4-A4, y pasar el repositorio a Supabase cuando haya tablas.
- **diseno:** F4-D1 (esperar a que se cierre la acción), pruebas que faltan de la matriz (estilo nuevo, reducir movimiento por estilo, doradas, foco del teclado, no solo color, 1366 dp y tablet).
- **finanzas:** prueba de toques del flujo del gasto (F4-1.1 y F4-1.2), pruebas de la tarjeta de alerta en Semana y de la alerta roja del abono (criterio 36).

## 11. Preguntas para el dueño

1. **¿Cómo sigue la vista temporal de Finanzas de Papá para el familiar (D24)?** Está decidida y especificada pero no construida (ni app, ni tabla `fin_vistas_solicitadas`, ni aviso). Hoy el familiar no ve dinero de Papá: es el estado seguro. ¿La hacemos en la Fase 5 o después?
2. **¿Aceptas que Alimentación se quede con datos de ejemplo** y sin guardar hasta que haya tablas en el servidor, o prefieres que se oculte con sesión real? (F4-A6)
3. **¿La cuidadora debe ver el menú de Papá ya, desde su navegación, o esperamos a Cuidados (Fase 5)?** (F4-A5)
4. **¿Te parece bien que el perfil de Papá esté escrito en el código** o prefieres que solo viva en la base, con el servidor? (F4-A7)
5. **Apagar el bloqueo de capturas en Windows:** hoy se apaga con un toque en *Ajustes › Privacidad* sin pedir PIN (D22 lo deja editable). ¿Quieres que pida el PIN para apagarlo? En Android no se puede apagar.
6. **Mediciones:** ¿qué día me das el Galaxy A52 y la laptop? Antes necesito que plataforma deje el medidor de arranque y la hoja de pasos.
7. **¿Quieres que el cambio de claro/oscuro espere** a que cierres lo que estás haciendo (como dice la spec), o prefieres que cambie a la hora exacta? (F4-D1)

---

## Estado de los hallazgos al cierre de la revisión (7/nov/2026)

| Hallazgo | Estado | Quién |
|---|---|---|
| F4-A1 (menú de Papá sin protección de capturas) | **Abierto** | plataforma |
| F4-A2 / F4-A3 (matriz de permisos sin D23) | **Abierto** | arquitecto, backend, plataforma |
| F4-A5 (cuidadora sin camino al menú de Papá) | **Abierto** | arquitecto, plataforma |
| F4-A6 (datos de ejemplo con sesión real en Alimentación) | **Abierto** | alimentacion |
| F4-S1 (límite de intentos en cambiar PIN y montos) | **Abierto** | plataforma |
| F4-A4, F4-I1, F4-X1, F4-M1, F4-D1, F4-W1, F4-A7, F4-H1 | **Abierto** (menores) | ver sección 5 |
| F4-B1 (sin tablas ni RLS de Alimentación) | **Pendiente conocido** | backend |
| D24 (vista temporal de Finanzas de Papá) | **Pendiente (no construida)** | backend, finanzas, plataforma |
| Mediciones en el A52 y en la laptop (criterios 37 a 41) | **Manual pendiente** | dueño con calidad |

**Veredicto de cierre:** 0 bloqueantes y 5 importantes abiertos; aprobada con las condiciones de la sección 1.
