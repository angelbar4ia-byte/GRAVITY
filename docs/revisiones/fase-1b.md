# Revisión de calidad — Fase 1b (revisión corta)

> Agente **calidad** · 23 a 30/oct/2026 · rama `claude/zen-pasteur-b0jblz`, sobre `4bfb560` (base de la revisión: `c1ddfb6`, y lo que fueron integrando plataforma, finanzas, backend y asistente mientras corría).
> Alcance: lo que cambió desde `docs/revisiones/fase-1.md` (commit `975bd02`): los arreglos de I1–I11 y M1–M13, las respuestas del dueño del 23/oct (D14, D17, D18, D19, `docs/DECISIONES.md`) y su segunda ronda (commit `38499ca`: compartido que se queda con menos de 2 miembros pasa a **privado**, PIN de 6 dígitos para quien ve dinero, montos a la vista al entrar con PIN en la tablet, bandeja de salida "a prueba").
> Base: `CLAUDE.md`, `docs/DECISIONES.md`, `docs/specs/fase-1-finanzas.md` v0.4, `supabase/README.md` (salvaguardas y "Respuestas del dueño"), `docs/DISENO_UX_UI.md`, `docs/revisiones/fase-1.md`.
> Método: lectura del código y de las migraciones, y **intentos de romperlo** contra un PostgreSQL 16 real y con pruebas de Flutter (servidor de autenticación simulado en local, archivos hostiles armados a mano). Cada hallazgo se reprodujo antes de listarlo y tiene una prueba que lo demuestra. No toqué código fuente ni documentos de otros: solo `docs/revisiones/`, `app/test/revision_calidad/` y `supabase/tests/`.

## 1. Veredicto

**La Fase 1 sigue sin bloqueantes. Hay 6 importantes nuevos (X1 ya lo corrigió finanzas mientras corría la revisión; quedan 5) que conviene cerrar antes de poner datos reales de la familia, y la bandeja de salida sin PIN se puede PROBAR tal como está (no recomiendo acotarla ya), con tres correcciones de plataforma (B1 a B3) y la de P1 antes de usarla con dinero real.**

- **Servidor.** Es sólido. Intenté unas 60 vías de ataque (maestra con login propio, libros compartidos, libro de papá, bitácora, escalada de privilegios) y las reglas de D19 aguantan: ninguna fuga entre personas. Lo que se rompe es **disponibilidad** (llenar la bitácora, N1), una **forma sin fondo** (motivo en blanco, N2) y casos de borde del cargo de albacea y de administrador (N3 a N5).
- **Cerrados.** Los 11 importantes (I1–I11) y 10 de los 13 menores (M6 superado por la decisión del dueño) de la revisión anterior quedaron cerrados con evidencia; M9 y M11 quedan parciales y M12 sigue en la Fase 6 (sección 7). No encontré ninguna aserción relajada para lograrlo (sección 8).
- **Lo más serio que encontré:** el PIN con el que "se vuelven a ver los montos" se puede **cambiar sin conocer el actual** (P1): quien tenga la app abierta con los montos ocultos —justo la situación para la que se ocultan— lo cambia en Ajustes › Privacidad y los ve. Y la bandeja de salida tiene tres defectos de robustez (B1 a B3) que no son fugas pero la dejan sin cumplir lo que promete.
- **Bandeja de salida (pregunta del dueño).** Riesgo residual **bajo a medio**: probabilidad baja, impacto alto, y el aumento frente a lo ya aceptado (la credencial de cada persona vive en la tablet protegida solo por su PIN) es pequeño. **No recomiendo pasar ya al permiso acotado**; sí recomiendo corregir B1 a B3 antes de probarla con dinero real. Razones y condiciones en la sección 3.

| Gravedad | Cuántos | Con prueba que lo demuestra |
|---|---|---|
| Bloqueante | 0 | — |
| Importante | 6 (P1, B1, B2, B3, X1, N1); **X1 ya corregido**, quedan 5 abiertos | 6 de 6 |
| Menor | 16 (sección 6): **5 ya corregidos** (S1, X2 a X5) y 11 abiertos | 11 con prueba; los otros 5 son de decisión, de documentación o de código muerto |

## 2. Pruebas corridas

| Comando | Resultado |
|---|---|
| `cd app && flutter analyze` | Sin problemas (también con las pruebas nuevas y sin las de exploración) |
| `cd app && flutter test test/revision_calidad --exclude-tags hallazgo` | **143 pasan, 0 fallan** (guardias de la Fase 0, 1 y 1b; incluyen S1 y X1 a X5, ya corregidos) |
| `cd app && flutter test test/revision_calidad --tags hallazgo` | **0 pasan, 9 fallan a propósito**: P1 ×3, B1 ×2, B2 ×2, B3 y B5 |
| `cd app && flutter test --exclude-tags hallazgo` (todo, a mitad de la integración de plataforma) | 1311 pasan, 19 fallan: **18 son pruebas de plataforma que esperan el PIN de 6 dígitos y siguen su camino** (`bandeja_tablet_test` ×5, `pin_con_dinero_test` ×1, `bloqueo_telefono_test` ×4, `montos_ocultos_test` ×8) y 1 era una guardia mía (fórmulas del importador) que arreglé después. Con el arranque en `c1ddfb6` eran 1240 y 0 |
| `cd paquetes/finanzas_dominio && dart test` | **227 pasan** |
| `bash supabase/tests/correr.sh` | **23 archivos, 1455 afirmaciones, todo pasa** (el archivo nuevo `81_calidad_fase1b.sql` aporta 63; antes 21 archivos y 1331) |
| `bash supabase/tests/correr.sh hallazgos_fase1b.sql` | Falla a propósito: **7 abiertos** (N1, N1b, N2a, N2b, N3, N4, N5) |
| `bash herramientas/respaldo/probar_respaldo.sh` | 44 comprobaciones, todo pasa |
| `cd api && npm run verificar` / `npm run validar` | Al día (`fnv1a32:7577b1b9`) / `openapi.yaml` válido |

> **Una prueba que cuelga la suite completa, y no es la mía.** `test/app/montos_ocultos_test.dart`, caso *"tablet con la persona dentro se pide su PIN de la tablet, sin huella"* (línea ~300), se queda 10 minutos y se cae por tiempo: con la regla nueva (los montos se ven al entrar con el PIN) el diálogo "Ver los montos" ya no se abre y la prueba espera para siempre. Es de plataforma y debe actualizarse a la regla nueva. La prueba P3 mía (`f1b_montos_pin_test.dart`) que se colgaba era una versión con widgets y `pumpAndSettle`; ya está reescrita solo con proveedores y con un tiempo máximo de 30 s por caso, y corre en 2 s.

## 3. Bandeja de salida sin PIN: riesgo residual y recomendación

### 3.1 Qué es y qué se puede hacer con ella
La persona se registra en la tablet con nombre y PIN, queda un gasto sin subir, sale, y su **sesión completa de Supabase** (JWT y refresh token) pasa del sobre cifrado con su PIN a un permiso de subida en el almacenamiento seguro, **en claro** (protegido solo por el almacén del dispositivo: Keystore o DPAPI). La cola la abre en una sesión aparte, sube lo suyo, y al terminar la **sella** (ECIES) para que solo su PIN la abra. A los 7 días se borra.

Esa credencial no está acotada: da **toda** la autoridad de la persona en el servidor. Hoy eso es sus libros, el compartido, el de papá (si es albacea) y las cuentas de gasto del hogar; desde la Fase 5, los datos clínicos de papá; y en la Fase 3, los datos de Hábitos. Además la API de Auth acepta ese token para cambiar el correo o la contraseña (con *Secure password change* activo pide reautenticar; hay que activarlo al crear el proyecto, ver pregunta 2).

### 3.2 Lo que ataqué y aguantó
- **Criptografía** (`sobre_sellado.dart`, `cifrado.dart`, `pin.dart`; 8 pruebas en `f1b_sobre_sellado_test.dart`, todas pasan): ECDH P-256 con llave efímera nueva por sellado, HKDF-SHA256 con la llave efímera como sal y etiqueta de contexto, AES-256-GCM con nonce aleatorio de 12 bytes. 300 sellados del mismo texto dan 300 llaves, 300 nonces y 300 sobres distintos; 2,000 cifrados con la llave del PIN, 2,000 nonces distintos. Alterar un byte del texto cifrado, de la etiqueta, del nonce o de la llave efímera, recortar la etiqueta, cambiar la versión: siempre `null`, nunca lanza. Ni la llave pública, ni otra privada, ni una vacía lo abren. La comparación del hash del PIN es en tiempo constante (`HashPin.verificar`); la de la etiqueta de GCM la hace la biblioteca.
- **Identidad:** una persona solo sube lo registrado con su sesión (`_listosDePersona` filtra por persona y excluye el origen "tablet de la casa"); lo registrado con solo el nombre nunca sale con el token de nadie; la cuenta Hogar nunca sube lo de una persona; `abrirSesionAparte` comprueba que el perfil leído sea el de la persona del permiso. La cola rechaza dinero con origen `tabletCasa` (M3) y el enviador lo vuelve a rechazar si llegara un registro viejo (defensa en profundidad).
- **Rotación del refresh token:** la renovación se guarda al instante (se escucha *antes* de abrir), con candado por persona; el simulador vigila que nunca se use una copia vieja (`rotacionEstricta`, 0 usos). Ningún camino deja dos copias vivas: la credencial **se mueve** del sobre del PIN al permiso y vuelve al entrar.
- **Aviso:** solo cuenta (`AvisoBandejaDeSalida`: "N por subir…"); ni montos ni nombres, y "Por revisar" solo muestra lo de la propia persona.
- **Quitar a la persona** (`alQuitarPersona`) borra el permiso y manda lo pendiente a "requiere atención"; **cambiar el PIN** vuelve a cifrar la llave privada con el PIN nuevo; **dada de baja** en el servidor: `sinRol`, se cierra su sesión y lo pendiente pasa a atención.

### 3.3 Lo que no aguanta (B1 a B5, secciones 5 y 6)
La credencial en claro **no caduca** si la sesión de Hogar se cierra (B1); un 429 la destruye (B2); una subida que no contesta bloquea la entrada con PIN (B3); al caducar solo se borra la copia local (B4); volver a agregar a la persona deja el permiso viejo (B5).

### 3.4 Riesgo residual, dicho con honestidad
- **Quién puede explotarlo.** Hace falta leer el almacenamiento seguro de la app: root, o un equipo robado y desbloqueado con acceso a datos. Otra app no puede; `allowBackup="false"` y las reglas de extracción excluyen las copias. En una casa, es poco probable.
- **Qué obtiene.** La sesión completa de esa persona, con todo lo que puede hacer. Y **no se acota con "7 días"**: el refresh token de Supabase no caduca por tiempo en el plan gratis, y la app, al caducar, borra su copia pero no cierra la sesión en el servidor (B4). Una copia sacada en ese lapso sirve hasta que alguien cierre la sesión o cambie la contraseña. Mitigante real: los refresh tokens rotan y Supabase revoca la familia si se reutiliza uno viejo; si el ladrón usa la copia, la tablet falla en su siguiente subida y la persona se entera.
- **Frente a lo que ya estaba aceptado.** La credencial de cada persona **ya vive en la tablet** cifrada con su PIN (Fase 0, I6). Con PBKDF2 de 10,000 vueltas, un PIN de 6 dígitos cae en segundos con una GPU o en 1 a 2 horas de un núcleo (4 dígitos, en minutos; estimación mía, no medida aquí); y el hash del PIN, guardado aparte, permite comprobarlo sin conexión. Quien extrae el almacenamiento ya obtiene la sesión completa de cualquiera que haya entrado en esa tablet. La bandeja le quita esa dificultad **solo mientras haya algo por subir**. Por eso el aumento es pequeño.
- **Calificación:** probabilidad baja, impacto alto, aumento marginal pequeño frente a lo aceptado: **riesgo residual bajo a medio**, no inaceptable.

### 3.5 Recomendación: **no acotar ya**; probar con condiciones
Pasar ahora al permiso de subida acotado costaría trabajo de backend y de plataforma y **no cerraría lo importante**: mientras la tablet guarde la sesión completa de cada persona (aunque sea cifrada con un PIN de 6 dígitos), quien llegue al almacenamiento tiene la cuenta, tenga o no una bandeja. El acotado solo mejora de verdad junto con endurecer eso (más vueltas o Argon2 en un aislado, o dejar de guardar la sesión de la persona en la tablet pública y verificar el PIN en el servidor).

Condiciones para **probarla** ya:
1. Corregir **B1, B2 y B3** (plataforma) antes de usarla con dinero real; con datos de ejemplo se puede probar hoy.
2. Activar *Secure password change* y la reautenticación al cambiar el correo en el proyecto de Supabase (pregunta 2).
3. Mantener PIN de 6 dígitos para quien ve dinero (ya implementado; P2 lo vigila) y corregir **P1** (se cambia el PIN sin conocer el actual).
4. Cerrar la sesión en el servidor cuando caduque o se descarte un permiso (B4) o decidir por escrito que no.

**Cuándo sí acotar:** antes de la Fase 5 (cuando la sesión del dueño abra datos clínicos de papá), si el dueño decide que una tablet comprometida no debe ceder la cuenta completa, o si la bandeja se ofrece fuera de la tablet de la casa. Propiedades que debe tener el permiso acotado (para que backend lo diseñe): solo `INSERT` en las tablas de la cola de **esa** persona; vence en el servidor (≤ 7 días) y es revocable (al quitar a la persona, al cerrar sesión, en la baja); no sirve para leer ni para Auth; no rota (sin refresh token, así desaparece la carrera de la rotación y el candado); cada subida queda en bitácora a nombre de la persona *"desde la tablet de la casa"*. Ojo con una restricción de diseño: el permiso hay que **emitirlo con señal, al entrar con el PIN**, porque sin señal no hay con quién registrarlo; si la persona entró sin señal, esa vez no hay bandeja (la cola espera su PIN, como antes). Una variante más fuerte es una llave del dispositivo en el Keystore que firma cada fila y el servidor verifica.

## 4. Hallazgos bloqueantes

Ninguno. Revisé de nuevo que ningún camino lleve dinero, cuentas o datos de papá a la IA en la nube, a las bocinas, al modo Casa, a la tablet pública o a un rol que no corresponde, y no lo hay (sección 9, D3).

## 5. Hallazgos importantes

### P1. El PIN para ver los montos se cambia sin conocer el actual
- **Dónde:** `app/lib/nucleo/seguridad/montos.dart` (`crearPin` pisa el hash sin pedir el actual), `app/lib/nucleo/seguridad/bloqueo.dart` (`configurarPin` y `quitarBloqueo`, igual) y `app/lib/modulos/ajustes/privacidad/pantalla_privacidad.dart` ("Cambiar el PIN para ver los montos", "Cambiar PIN", interruptor "Pedir PIN al abrir GRAVITY").
- **Reproducir:** `cd app && flutter test test/revision_calidad/f1b_montos_pin_test.dart --tags hallazgo` (3 casos).
- **Escenario:** la decisión del 23/oct es que los montos se ocultan solos y para volverlos a ver se pide el PIN. Alguien frente a la laptop (o el teléfono desbloqueado) del dueño con los montos ocultos entra a Ajustes › Privacidad, cambia el PIN sin decir el actual (o apaga el bloqueo, que tampoco lo pide, y "Ver los montos" ofrece entonces **crear** un PIN), y con el PIN nuevo ve todo. El PIN de la tablet sí está bien: `cambiarPin` exige el actual.
- **Esperado:** cambiar o quitar el PIN (de los montos o del bloqueo) exige el actual; crear uno solo si no hay ninguno. La firma cambia (`crearPin(pin, actual: …)`): actualiza las llamadas de la prueba, la expectativa no cambia.
- **Agente:** plataforma (con diseno si se rehace el diálogo).

### B1. Cerrar la sesión de Hogar deja la credencial en claro y ya no caduca
- **Dónde:** `app/lib/nucleo/cola/cola_sin_conexion.dart` (`_procesar`: `caducar()` solo corre si hay sesión abierta) y `servicio_sesion_supabase.dart` (`salir()` borra la copia local de Hogar pero no los permisos de las demás personas).
- **Reproducir:** `flutter test test/revision_calidad/f1b_bandeja_hallazgos_test.dart --tags hallazgo --plain-name B1` (2 casos).
- **Escenario:** el dueño registró un gasto sin señal y salió: su sesión completa queda en claro. Si la cuenta Hogar cierra sesión (cambio de contraseña, sesión revocada, la persona toca "Salir"), nadie vuelve a ejecutar la caducidad: a los 8 días la credencial sigue en el almacén, sin PIN. El "caduca a los 7 días" de D14 es lo que se le dijo al dueño.
- **Esperado:** `salir()` y la baja de Hogar borran los permisos en claro (lo pendiente pasa a "requiere atención"), y la caducidad corre también al abrir la app sin sesión.
- **Agente:** plataforma.

### B2. Un error pasajero se toma por "credencial vencida" y destruye el permiso
- **Dónde:** `servicio_sesion_supabase.dart`, `abrirSesionAparte` (y `abrirSesionDePersona`): todo error que no sea de red cuenta como `credencialVencida`. Solo se reconocen como red las excepciones de socket, tiempo, cliente HTTP y `AuthRetryableFetchException` (5xx); un **429** (límite de peticiones, `over_request_rate_limit`) o un 5xx de PostgREST al leer el perfil tampoco (por la lectura del código: `traducirErrorSesion` lo vuelve un error genérico, no probado con servidor).
- **Reproducir:** `… --plain-name "B2"` (con el servidor simulado local, `ayuda_gotrue.dart`).
- **Escenario:** vuelve la señal, Supabase responde 429 al renovar: la cola borra el permiso y manda lo pendiente a "requiere atención" ("tu sesión ya no sirve"); la persona tiene que volver a agregarse con correo y contraseña. Al levantarse el límite habría subido sola.
- **Esperado:** 429, 408 y 5xx se tratan como "sin conexión" (se reintentan); solo un 400/401 con `refresh_token_not_found` o `invalid_grant` es "vencida".
- **Agente:** plataforma.

### B3. Una subida que no contesta bloquea la entrada con PIN
- **Dónde:** `bandeja_salida.dart` (`abrir` retiene el candado de la persona hasta `cerrar`; ningún envío tiene tiempo máximo) y `tomarParaEntrada` / `cambiarPin` / `alQuitarPersona`, que esperan ese candado.
- **Reproducir:** `… --plain-name "B3"`.
- **Escenario:** Wi-Fi con portal cautivo o servidor a medias: la petición de subida no vuelve. La persona escribe su PIN y la tablet se queda esperando; tampoco se puede cambiar su PIN ni quitarla. Es una negación de servicio local con una red mala.
- **Esperado:** tiempo máximo por envío (p. ej. 30 s) o que la entrada con PIN pueda cancelar la subida (cerrar la sesión aparte y tomar la credencial).
- **Agente:** plataforma.

### X1. El lector de `.xlsx` no limita lo que descomprime
- **Dónde:** `app/lib/modulos/finanzas/importacion/lector_xlsx.dart` (`_leerZip`: `ZLibDecoder(raw: true).convert` sin tope; el límite de 10 MB es del archivo comprimido).
- **Reproducir (contra el código de `c1ddfb6`):** `f1b_importar_no_confiable_test.dart`, caso X1. **Corregido por finanzas en el árbol de trabajo (sin commit) mientras corría la revisión y verificado:** topes por componente (4 MiB) y en total (8 MiB), razón de compresión máxima de 100 a 1, 1000 componentes, filas, columnas y celdas acotadas, recorrido lineal y todo error como `ErrorArchivo`. Lo volví a atacar: una bomba de 400 MB (408 KB comprimidos) se rechaza en 7 ms, 1,200 componentes, 200,000 etiquetas anidadas y 100,000 `<row>` sin cerrar se rechazan en menos de 100 ms, un DTD con entidades no se expande, y el archivo semilla real (`data/DATOS_SEMILLA_PRESUPUESTO.xlsx`) sigue leyéndose (128 filas).
- **Escenario:** un `.xlsx` de ~100 KB se expande a 100 MB (medí 15 s de congelamiento de la pantalla y memoria); con los 10 MB permitidos, a ~10 GB: la app muere. Lo elige el propio dueño, pero el dueño pidió tratar lo importado como no confiable (tamaño, tipo, zip bombs, fórmulas, rutas).
- **Esperado:** rechazar con `ErrorArchivo` si lo descomprimido pasa unos pocos MB (la plantilla pesa decenas de KB); bastaría leer la entrada con un tope.
- **Agente:** finanzas (hecho; pendiente de commit).

### N1. Cualquier miembro puede llenar la base con la bitácora (M2, parte 2 de la Fase 0)
- **Dónde:** `bitacora_agregar` (`20261020000000_base.sql`, reglas de inserción): no limita cuántas entradas ni cuánto pesan en total (hasta 32 KB cada una).
- **Reproducir:** `bash supabase/tests/correr.sh hallazgos_fase1b.sql` → **N1** (una cuenta de **familiar** mete 36 MB con una sentencia) y **N1b** (lo mismo con la cuenta Hogar, la de la tablet pública).
- **Escenario:** el plan gratis tiene 500 MB: bastan unas 15 sentencias así para que el proyecto deje de aceptar escrituras para **toda la familia**. Lo puede hacer un error de la app en un bucle, una cuenta robada o la tablet pública. Estaba en "Pendientes conocidos" del README; ahora está medido.
- **Esperado:** un tope por persona (p. ej. 500 entradas por día y 4 KB por entrada para las acciones de la app), con trigger por sentencia (uno por fila no ve las inserciones en lote); más un aviso al llegar al 80 % de la base.
- **Agente:** **backend**.

## 6. Hallazgos menores

| # | Dónde | Escenario | Propuesta | Agente | Prueba |
|---|---|---|---|---|---|
| **N2** | `fin_movimientos_representado` y el check `fin_movimientos_motivo_obligatorio` comparan `nullif(btrim(motivo), '')`; `btrim` solo quita espacios | En el libro de papá, un motivo de un tabulador o de un salto de línea cuenta como motivo (N2a, N2b). Un punto o "x" también pasan; eso lo decide el dueño | Quitar también `\t\r\n` y espacios Unicode antes de comparar (y, si el dueño quiere, un largo mínimo) | **backend** | `hallazgos_fase1b.sql` N2a, N2b |
| **N3** | `fin_movimientos_salida_representado`: solo avisa si el destino es un libro **personal** | Papá → un compartido del albacea con alguien que no es el suplente → su cuenta personal: el segundo paso sale de un compartido y no deja aviso. D19: "las salidas hacia un libro personal avisan al suplente"; este es un camino indirecto hacia lo personal. (El movimiento sí queda en la bitácora general, que ve el suplente) | Avisar toda salida del libro de papá hacia **otro libro** (no solo personal) | **backend**; decisión del dueño (pregunta 3) | `hallazgos_fase1b.sql` N3 |
| **N4** | `fin_libro_miembros_validar` (agregar exige `administrar`) | Si el albacea deja el cargo sin suplente (o ambos), el dueño del hogar no puede volver a nombrar albacea: el libro de papá queda sin nadie y solo `service_role` lo arregla. Con suplente vigente se recupera (el suplente escribe y administra) | Que el dueño del hogar pueda nombrar albacea del libro de papá aunque no sea albacea, con entrada en la bitácora | **backend** | `hallazgos_fase1b.sql` N4 |
| **N5** | `fin_libro_miembros_proteger` (relevo del administrador solo al cerrar una fila) | Si el administrador de un compartido es dado de baja **del hogar** (no se "sale" del libro), `creado_por` apunta a alguien sin acceso: el que queda no puede agregar miembros, cambiar la visibilidad ni archivar, y el dueño tampoco (si no es miembro). El relevo ocurre solo cuando alguien se sale | Pasar el cargo al miembro vigente más antiguo también cuando el administrador deja de ser adulto con Finanzas del hogar (trigger sobre `membresias`) | **backend** | `hallazgos_fase1b.sql` N5 |
| **B4** | `bandeja_salida.dart` (`caducar`, `descartar`, `alQuitarPersona`) | La caducidad (y descartar o quitar a la persona) borra la copia local pero no cierra la sesión en el servidor; una copia sacada antes sigue sirviendo (sección 3.4). La caducidad usa el reloj del dispositivo (atrasarlo la alarga) | Con señal, abrir la sesión una última vez y cerrarla (`signOut` local); documentar que "7 días" es de la tablet | plataforma | `f1b_bandeja_hallazgos_test.dart` B2 (revocación) |
| **B5** | `controlador_tablet.dart` (`agregarUsuario` no toca el permiso) | Volver a agregar a una persona con un permiso en espera: al entrar con el PIN nuevo se usa la credencial **vieja** del permiso y se pisa la nueva. Si el permiso está sellado, queda para siempre cifrado con el PIN viejo | `agregarUsuario` borra el permiso (lo pendiente espera su entrada) o lo vuelve a cifrar | plataforma | B5 |
| **X2** (corregido) | `lector_xlsx.dart` (`_filas`) | `<row r="50000000">` reserva 50 millones de filas vacías (~400 MB; con 2,000,000,000, ~16 GB) con un archivo de 1 KB | Rechazar filas por encima de 1,048,576 | finanzas | X2 |
| **X3** (corregido) | `lector_xlsx.dart` (regex de celdas) | `<c>` sin cerrar: tiempo cuadrático (40,000 celdas: 5 s; 400,000, ~8 min) en el hilo de la pantalla | Leer con un analizador de XML por eventos, o correrlo en un aislado con tope de tiempo | finanzas | X3 |
| **X4** (corregido) | `importar.dart` (`elegirArchivoDelSistema`) | Llama a `readAsBytes()` antes de mirar el tamaño; un archivo de 3 GB se carga entero. En Android, además, el selector **copia** el archivo al caché de la app (`cacheDir/file_picker/…`) antes de que la app lo vea y nunca se limpia (`FilePicker.clearTemporaryFiles` no se llama). Hoy Importar es solo de la laptop (D4) | Revisar `lengthSync()` antes de leer; limpiar el caché si se ofrece en Android | finanzas | X4 |
| **X5** (corregido) | `lector_xlsx.dart` | Un ZIP dañado (tamaño declarado mentiroso, índice de cadena compartida fuera de rango, `&#99999999;`) lanza `RangeError` y no `ErrorArchivo`. La pantalla lo atrapa ("No pude leer el archivo: RangeError…"), pero el lector promete `ErrorArchivo` | Envolver y traducir | finanzas | X5 (3 casos) |
| **S1** (corregido) | `sobre_sellado.dart` (`sellar`) | pointycastle no comprobaba que el punto de la llave pública estuviera en la curva. No era explotable (la llave la genera la propia app y vive junto a la credencial en claro). **Plataforma ya lo corrigió en el árbol de trabajo (`_estaEnLaCurva`) mientras corría la revisión; la prueba pasa y quedó como guardia** | — | plataforma | `f1b_sobre_sellado_test.dart` |
| M9' | `pin.dart` | M9 pedía además más vueltas de PBKDF2 y un tope de 5 min en la tablet pública. Siguen 10,000 vueltas y hasta 30 min (`regresoModoCasaMaximo`). Ver sección 3.4: el PIN de 6 dígitos con 10,000 vueltas no resiste a quien extrae el almacenamiento | ≥ 600,000 vueltas en un aislado, o Argon2 | plataforma; dueño | — |
| C1 | `ajustes/personas/seccion_cuenta_maestra.dart` | El token de la invitación de la cuenta maestra se copia al portapapeles y ahí se queda (no hay vaciado). Mitigado: `aceptar_invitacion` exige además el correo **confirmado** de la persona invitada | Marcarlo como sensible (Android 13) o avisar | plataforma | — |
| W1 | `pantalla_segura.dart` | FLAG_SECURE es de Android; en Windows (la laptop, con Finanzas completo) nada impide capturas ni miniaturas de la barra de tareas. Puede hacerse con `SetWindowDisplayAffinity` | Decidir si se quiere | plataforma; dueño | — |
| L1 | cola local (`pendientes.carga`) | Lo que una persona quitada de la tablet no alcanzó a subir queda en la base local en claro (monto, concepto, cuentas) en "requiere atención" hasta que ella vuelva; si no vuelve, nunca se borra | Purga a los N días | plataforma | — |
| G1 | `pantallas_externas.dart` (`ganchosDeLimpieza`) | Declarado y nunca registrado en `LimpiezaLocal`. No falla nada (la convención `modulo.copia.<persona>` ya borra la copia de Finanzas), pero es código muerto engañoso | Quitarlo o registrarlo | plataforma | — |

## 7. Estado de I1–I11 y M1–M13

"Cerrado" significa que hay una prueba que pasa y que intenté romperlo. El archivo SQL de cada uno está en `supabase/tests/`; las de la app, en `app/test/`.

| # | Estado | Evidencia y observaciones |
|---|---|---|
| I1 | **Cerrado** | SQL 32 (89 afirmaciones; reescrito en la 2.ª ronda) y 33; mis ataques Q5 a Q7 (81): un miembro no se adueña del cargo, no cambia la visibilidad, no agrega ni saca, no adelanta su `desde`; quien se sale no vuelve (fila, `upsert` ni fila nueva); el dueño no miembro no ve ni se agrega a un privado. La 2.ª ronda lo cambia a "pasa a privado" (migración `20261025…`, revisada: el último miembro no se sale, 22023; relevo al más antiguo). Queda **N5** |
| I2 | **Cerrado** | SQL 28 y 34; Q1 a Q4: sin consulta, la maestra no lee libros, vistas, saldos ni bitácora ajenos; no forja su consulta (42501); la consulta es por libro y por persona; con consulta tampoco escribe |
| I3 | **Cerrado** (con N2, N3) | SQL 31 y Q9: sin `en_nombre_de` o sin motivo, 23514 (gasto, transferencia a su banco, ajuste, anulación); la salida a un libro personal deja su entrada, que ve el suplente y no una familiar |
| I4 | **Cerrado** | SQL 31: el albacea dado de baja o sin Finanzas deja de contar; el suplente escribe. Queda **N4** (recuperación) |
| I5 | **Cerrado** (con N1) | SQL 30 y Q10: `finanzas*` y `fin_*` reservados (mayúsculas, espacios, `public.`, saltos de línea), también para Hogar y la maestra. Queda **N1** |
| I6 | **Cerrado** | `f1_i6_letra_grande_telefono_test.dart`, ya sin etiqueta, pasa |
| I7 | **Cerrado** | `f1_i7_laptop_ventana_estrecha_test.dart`, ya sin etiqueta, pasa |
| I8 | **Cerrado** | `f1_i8_guardar_a_la_vista_test.dart`, ya sin etiqueta, pasa |
| I9 | **Cerrado** | `f1_i9_hoy_sin_cifras_de_ejemplo_test.dart`; con sesión real "Hoy" dice "Sin datos todavía"; el ejemplo queda solo en demostración |
| I10 | **Cerrado** | `f1_i10_error_sin_reintentos_automaticos_test.dart`, ya sin etiqueta, pasa |
| I11 | **Cerrado** (Android) | `ProtectorDePantallaAndroid` + `MainActivity.kt` + guardia por ruta (`esPantallaSensible`; shell completo y hojas del (+)); revisé a ojo el Kotlin (`configureFlutterEngine` llama a `super`, `MethodChannel` con el mismo nombre que el Dart, `runOnUiThread`, `FLAG_SECURE` por omisión si falta el argumento). No hay SDK aquí: sin ejecutar. En Windows no hay nada (W1) |
| M1 | **Cerrado** | `hasta` exclusivo: `f1_menores_test.dart` M1, mi guardia en `f1b_dominio_test.dart` |
| M2 | **Cerrado** (aserción cambiada, ver §8) | Regla 67 de la especificación v0.4. Ida y vuelta de 20,000 importes al azar con `formatearCentavos`, y lo ambiguo se rechaza (`f1b_dominio_test.dart`) |
| M3 | **Cerrado** | `f1_menores_test.dart` M3 (la cola rechaza tipos personales con origen `tabletCasa`) y el segundo cerrojo en el enviador |
| M4 | **Cerrado** | `f1_menores_test.dart` M4 y mi guardia: 30 y último en febrero = 2 pagos el 28, 24 al año |
| M5 | **Cerrado** | `f1_m5_copia_local_finanzas_test.dart`, `limpieza_local_test.dart`. Queda **L1** (cola) y **B1** (permisos) |
| M6 | **Superado** | La maestra con login propio es de solo lectura total; la pareja configura el hogar (decisión del dueño); Q1 lo vigila |
| M7, M8 | **Cerrados** | `f1_i7…`, `f1_menores_test.dart` M8 |
| M9 | **Parcial** | PIN de 6 dígitos para quien ve dinero: **hecho** (`pin.dart`, `largoPinConDinero`; P2 en `f1b_montos_pin_test.dart` lo vigila en los tres sitios) y PIN triviales rechazados. Faltan vueltas de PBKDF2 y el tope de la tablet pública (M9') |
| M10 | **Cerrado** | SQL 28: `finanzas.maestra_asignada` la ve todo adulto con Finanzas |
| M11 | **Parcial** | Los dos `.xlsx` de `data/` ya no llevan autor ni último en modificar (`docProps/core.xml` vacío; sin correos ni rutas en ninguna parte del archivo); el historial se conserva por decisión del dueño. **Nuevo dato real en los documentos:** `DECISIONES.md` (D19) y la especificación nombran la institución del crédito automotriz del dueño (pregunta 8). `data/personal/` sigue ignorada y solo tiene `.gitkeep` |
| M12 | **Abierto** (Fase 6) | `ContextoHerramienta` lo arma quien llama; sin riesgo hoy (todas las herramientas de Finanzas solo navegan) |
| M13 | **Cerrado** | README: "Garantía y límites del solo agregar" |

## 8. Cambios de aserciones desde `975bd02` (`git diff 975bd02..HEAD -- app/test/revision_calidad supabase/tests`)

No encontré ninguna aserción relajada sin una decisión detrás. Todas, una por una:

**App (`app/test/revision_calidad/`)**
1. `f1_g5_d3_finanzas_test.dart`: `registrar_gasto` con `rol: coadministrador, esMaestra: true` pasó de `isNotNull` a `isNull`, y se agregó la del dueño que también es maestro (`isNotNull`). **Legítimo:** D19 del 23/oct, la maestra con login propio es de solo lectura total ("no tiene (+) ni órdenes que abran una hoja"). La aserción se endureció para ella y se conservó para el dueño.
2. `f1_menores_test.dart` M2: `centavosDeTexto('12,5')` pasó de `null` a `1250`, `'85,50'` de `null` a `8550`, y se agregó `'1,234'` → `123400`. **Legítimo, pero con una nota:** el comentario de la prueba dice "decisión del dueño del proyecto" y está en la regla 67 de la especificación v0.4, pero **no aparece en `DECISIONES.md`**. Lo peligroso (diez veces de error sin aviso) quedó resuelto: ida y vuelta de 20,000 importes y lo ambiguo (`1,2345`, `85.555`, `1,23,4`) se rechaza. Pido anotarla (pregunta 7).
3. Quitar `@Tags(['hallazgo'])` o `tags: ['hallazgo']` de 15 archivos. **Legítimo:** los de la Fase 0 (b1 a b3, i1 a i6) ya pasaban desde que se cerró la Fase 0; los de la Fase 1 (I6 a I10, M1 a M5, M8, I11, `f1_m5`) pasan sin cambiar ninguna cifra, tamaño ni letra (el diff solo toca el comentario y la etiqueta; verifiqué que 360 × 800, letra 2.0, 1100 dp, 850 dp y 40 s → 2 reintentos siguen igual).

**SQL (`supabase/tests/`)**
4. `30_bitacora.sql` (M2 de la Fase 0): `tabla` de `'fin_movimientos'` a `'membresias'` en los casos de acciones reservadas. **Legítimo y necesario:** con I5 una tabla `fin_*` se rechaza con 42501 por *otra* razón; sin el cambio la prueba pasaba por el motivo equivocado. Los códigos esperados (42501 y 23514) no cambiaron, y I5 tiene su propio bloque.
5. `21_finanzas_albacea.sql`: `marta@` se reemplazó por una cuarta persona (`teo@`, creada con `nuevo_adulto`) porque la maestra ya no puede ser miembro; la aportación a la cuenta de papá ahora lleva motivo y `en_nombre_de` (I3). **Legítimo; más estricto.**
6. `24_finanzas_cuentas.sql`: se quitó *"Una cuenta de gasto del hogar con movimientos de varios libros no se archiva"* (22023). **Legítimo:** D19, "las de activos y pasivos siguen pidiendo saldo cero"; se reemplazó por pruebas positivas (se archiva con saldo; no admite gastos nuevos; la anulación sí; la tarjeta y el banco con saldo siguen sin cerrarse; las de sistema nunca).
7. `28_finanzas_maestra.sql`: reescrito para el modelo nuevo. Se quitaron las aserciones de "la maestra ve los 5 libros / los 21 movimientos / los saldos sin consulta", "administra lo suyo", "Alex como maestra" y "la bitácora le muestra todo". **Legítimo:** el dueño decidió consulta registrada (I2), maestra sin libro propio y solo lectura; cada una tiene su equivalente nuevo (consulta vigente de 30 min por libro y persona, no escribe, el dueño como maestra sí escribe lo suyo, `rol → familiar` movido a `34`).
8. `32_finanzas_compartido.sql` en la 2.ª ronda: *"salir con 2 miembros archiva el libro"* y *"sacar a otro con 2 miembros da 22023"* pasaron a *"queda privado y activo"* y *"el último no se sale (22023)"*. **Legítimo:** decisión del 23/oct (2.ª ronda).

## 9. Revisión por tema

**9.1 Servidor** (`81_calidad_fase1b.sql`, 63 afirmaciones que pasan; `hallazgos_fase1b.sql`, 7 abiertos).
- *Maestra con login propio:* de solo lectura total —INSERT, UPDATE y las RPC fallan con 42501 en los libros, en lo del hogar y en las invitaciones—, no es miembro de libros (`fin_libro_miembros_sin_maestra`) ni crea libros; sin consulta ve solo la portada (libros y miembros, nombres, categorías); con la consulta de un libro, ni el de otra persona ni el de otro hogar; no forja su consulta; no ve Cuidados ni Hábitos (no hay tablas; su rol no los tiene).
- *Compartidos:* visibilidad (privada por omisión; pública se lee, no se escribe, no deja ver lo personal de quien aportó); solo el administrador agrega, saca, cambia la visibilidad y archiva; salir siempre es posible y no se vuelve a entrar por cuenta propia; la dueña no miembro no ve, no se agrega ni toca un privado; el relevo del administrador (sin atajo con `desde`) y, con la migración `20261025…`, "pasa a privado" y "el último miembro no se sale".
- *Libro de papá:* `en_nombre_de` y motivo en todo movimiento (incluidas apertura, ajuste, reclasificación y anulación); albacea y suplente vigentes; la salida a lo personal deja su entrada. Fallos: N2, N3, N4.
- *Bitácora:* reservada (I5) y sin escrituras a nombre de otro; Hogar no puede escribir como Ana. Fallo: N1.
- *Privilegios de funciones:* de 56 funciones de `public`, `authenticated` ejecuta solo 24, todas `SECURITY DEFINER` con `search_path` vacío o puras, y todas responden por la sesión; ninguna de las nuevas es llamable por `anon`. `fin_adultos_con_finanzas(hogar)`: cero filas para familiar, Hogar y otro hogar; nunca incluye a la maestra que no es dueña (`35_finanzas_adultos.sql`). `fin_registrar_consulta_maestra` da el mismo 42501 exista o no el libro (no revela libros).
- *Solo agregar:* sin cambios (SQL 22 y 80).

**9.2 FLAG_SECURE y cubierta.** Por ruta (`GuardiaDePantallaSegura` en el shell completo) y en las hojas del (+); el controlador cuenta pedidos y solo llama al sistema al pasar de 0 a 1 y de 1 a 0. Al cambiar de ruta la bandera se quita en el mismo cuadro (las páginas no tienen animación). Revisión a ojo del Kotlin sin errores (arriba). Montos ocultos: ni el texto dibujado ni la semántica que lee un lector de pantalla dejan ver una cifra con los montos ocultos, en **todas** las secciones de Finanzas de la laptop, las dos del teléfono y "Hoy": `f1b_montos_semantica_test.dart` busca `$` pegado a un número en cada `Text` y en cada etiqueta, valor, pista y descripción, y su control confirma que con los montos a la vista sí encuentra cifras. Portapapeles: solo el token de invitación (C1). Notificaciones: la app aún no las usa. Registros: los `debugPrint` no imprimen tokens ni montos. **Se salta con P1.**

**9.3 Montos ocultos.** Todas las vías de mostrar pasan por `revelarMontosProvider` (que en el arranque es `revelarMontos`); la nueva `MontosVisiblesAlEntrar` los muestra solo a quien entró con su PIN en la tablet y se reinicia al cambiar la persona en pantalla. P3 (4 casos, sin widgets, 30 s de tope): en reposo ocultos; el dueño entra y los ve de una vez; al volver a Hogar o entrar otra persona, ocultos; el modo privado y el tiempo sin uso siguen mandando. Falla: P1.

**9.4 D3 y herramientas.** Sin cliente de IA en la nube en el código ni en el `pubspec`; `http` solo para `ClientException`. Toda herramienta de Finanzas es `soloLocal`; la orden "registrar gasto" exige el verbo ("gasto" suelto ya no abre nada); la maestra que no es dueña no recibe herramientas que escriban ni abran una hoja; el dueño que es maestro conserva las suyas. Nada de papá ni de dinero llega a bocinas, modo Casa o tablet pública.

**9.5 Tablets (D14).** Pública y personal separadas; "solo nombre" solo alcanza lo de la casa (lista de compras, recordatorios) y un gasto pide nombre y PIN; la cola con origen `tabletCasa` solo sube con la cuenta Hogar y nunca `fin_*` ni `finanzas.*`/`habitos.*`/`cuidados.*`; la cuenta del equipo se muestra "Hogar" (`nombreParaMostrar` al abrir sesión o leer la sesión guardada). Fallos: B1 a B5.

**9.6 `file_picker` ^13.1.0.** Hashes del `pubspec.lock` iguales a los de caché de pub; el autor de las transitivas es el mismo repositorio (`vicajilau/flutter_file_picker`). **Sin permisos de más:** el manifiesto de la app sigue en `INTERNET` y `USE_BIOMETRIC`, y el del plugin de Android solo agrega un `<queries>` para `GET_CONTENT`; en Windows usa el cuadro nativo. Sin cambios en la app: usa `FileType.custom` con `xlsx` y `csv`. Lo importado: tope de 10 MB (comprimido), extensión (`virus.exe`, `.xlsm`, `.xls` y un archivo que no es ZIP se rechazan), fórmulas **no** se evalúan (se lee el valor guardado; `=cmd|…` es solo un nombre), las rutas del ZIP (`../`, `/etc/…`) no tocan el disco (solo se leen en memoria `.xml` y `.rels`), 50,000 filas de CSV en tiempo razonable. Fallos: X1 a X5 (contra `c1ddfb6`), **ya corregidos** por finanzas y verificados. Permisos de más: no hay.

**9.7 Dominio.** `f1b_dominio_test.dart` (14 casos): la pensión de los días 1 y 11 de 2026 y 2027 (48 pagos) contra un oráculo calculado aparte con el calendario de Python y los festivos de la LFT art. 74 escritos a mano (incluidos el 2/feb/2026 y el 1/feb/2027, primer lunes de febrero, que empujan el pago al martes); día hábil anterior (hasta cruzar el año, 1/ene/2026 → 31/dic/2025); sin cambio; ancla el 31 con pagos mensuales y bimestrales; 30 y último en febrero (24 pagos al año, M4); dos días iguales (12); `hasta` exclusivo; coma decimal; reparto del remanente con grupo prioritario (3,000 casos al azar: el dinero se conserva, con grupo solo el grupo recibe, nunca más que el saldo; con el grupo liquidado todo va a ahorro). Sin hallazgos.

**9.8 Secretos y datos reales.** `git grep` no encuentra llaves, tokens, JWT, `google-services.json`, almacenes de llaves, `service_role` en código de la app, contraseñas ni teléfonos en lo nuevo; los correos fuera de `@ejemplo.test` son de ejemplo de la licencia de swagger-ui, `user@example.com` y variantes de mayúsculas; `data/personal/` ignorada (solo `.gitkeep` versionado); los dos `.xlsx` de `data/` sin autor. Único dato real nuevo: la institución del crédito automotriz (M11, pregunta 8).

## 10. Pruebas agregadas por calidad

Las que llevan la etiqueta `hallazgo` fallan hoy a propósito; las guardias pasan. Línea base: `flutter test --exclude-tags hallazgo`.

| Archivo | Cubre | Hoy |
|---|---|---|
| `supabase/tests/81_calidad_fase1b.sql` | Maestra de solo lectura y sin forjar su consulta (Q1 a Q4), compartidos (Q5 a Q8), libro de papá (Q9), bitácora (Q10) | 63 afirmaciones, pasan |
| `supabase/tests/hallazgos_fase1b.sql` | N1, N1b, N2a, N2b, N3, N4, N5 (no entra en la corrida normal: `correr.sh hallazgos_fase1b.sql`) | 7 abiertos |
| `app/test/revision_calidad/f1b_bandeja_hallazgos_test.dart` | B1 ×2, B2 ×2 (429 y revocación), B3, B5; control de revocada | 6 fallan, 1 pasa |
| `f1b_sobre_sellado_test.dart` | ECIES y cifrado con PIN: nonces, alteraciones, llaves, punto fuera de la curva (S1) | 8 pasan |
| `f1b_montos_pin_test.dart` | P1 ×3 (`hallazgo`), control de intentos, P2 PIN de 6 dígitos ×4, P3 regla nueva ×4 | 3 fallan, 9 pasan |
| `f1b_montos_semantica_test.dart` | Sin cifras con los montos ocultos (texto y lector de pantalla) en Finanzas y "Hoy" | 3 pasan |
| `f1b_importar_no_confiable_test.dart` | Guardias del importador (7) y X1 a X5 (7, que fallaban contra `c1ddfb6` y pasaron con el lector nuevo de finanzas) | 14 pasan |
| `f1b_dominio_test.dart` | Oráculo de la pensión, ancla, coma decimal, reparto | 14 pasan |
| `ayuda_gotrue.dart`, `ayuda_zip.dart` | Servidor de autenticación simulado (con 429 y registro de revocaciones) y armado de ZIP hostiles | — |

Borré mi archivo de exploración (`x_explora_xlsx_test.dart`). `flutter analyze` queda sin avisos.

## 11. Pedidos por agente

| Agente | Qué |
|---|---|
| **plataforma** | P1, B1, B2, B3 (antes de usar la bandeja con dinero real); B4, B5, M9', C1, W1, L1, G1 (S1 ya hecho). **Actualizar `test/app/montos_ocultos_test.dart` a la regla nueva** (el caso de la tablet cuelga la suite 10 min; hay 18 pruebas suyas en rojo por el PIN de 6 dígitos) |
| **backend** | **N1** (tope de bitácora); N2, N3, N4, N5; y, si el dueño acepta el permiso acotado, su diseño (sección 3.5). Mover las afirmaciones de `hallazgos_fase1b.sql` a `NN_*.sql` al corregir |
| **finanzas** | X1 a X5 ya hechos (lector reescrito); confirmar que entra en el commit. Si el importador se ofrece algún día en Android: `FilePicker.clearTemporaryFiles()` (el selector copia el archivo al caché) |
| **asistente** | Nada nuevo. M12 sigue en la Fase 6 |
| **diseno** | Revisar con plataforma el diálogo de cambio de PIN si se rehace (P1) |
| **arquitecto** | Integrar; anotar la coma decimal (regla 67) en `DECISIONES.md`; decisiones de la sección 12 con el dueño |

## 12. Preguntas para el dueño

1. **Bandeja de salida:** ¿pruebas el permiso actual (mi recomendación) con datos de ejemplo o dinero propio mientras plataforma corrige B1 a B3, o prefieres pasar ya al permiso acotado? Si quieres lo segundo, hay que decidir también si se endurece la sesión por persona en la tablet pública (si no, el acotado mejora poco).
2. Al crear el proyecto de Supabase: ¿activo *Secure password change* y la reautenticación al cambiar el correo? (Con la sesión completa en la tablet, es lo que impide que una copia robada cambie tu contraseña. No lo puedo verificar aquí.)
3. **N3:** en el libro de papá, ¿toda salida hacia **otro libro** (no solo uno personal) debe avisar al suplente?
4. **N4:** ¿el dueño del hogar debe poder volver a nombrar albacea de papá aunque ya no lo sea?
5. **N5:** si dan de baja del hogar al administrador de un compartido, ¿el cargo pasa solo al miembro más antiguo?
6. **N2:** ¿qué cuenta como motivo válido? Hoy basta una letra; ¿largo mínimo?
7. **Coma decimal:** *"12,5" = $12.50* está en la regla 67 de la especificación pero no en `DECISIONES.md`. ¿Lo confirmas (y que *"1,234" = mil doscientos treinta y cuatro*)?
8. `DECISIONES.md` y la especificación ya nombran la institución de tu crédito automotriz. El repositorio es privado y el historial se conserva por tu decisión; ¿se queda así?
9. ¿Quieres bloqueo de capturas también en la laptop de Windows (W1)?
10. Lo pendiente de una persona que se quita de la tablet queda en la base local: ¿cuántos días se conserva antes de borrarse (L1)?

## 13. Lo que está bien (y conviene conservar)

- **Servidor:** las reglas de D19 resisten el uso adversarial; los permisos de función son mínimos y todas las nuevas son `SECURITY DEFINER` con `search_path` vacío; el relevo del administrador no se puede adelantar con `desde`.
- **Criptografía de la bandeja:** bien usada (llave efímera y nonce nuevos en cada sellado, HKDF con contexto, GCM).
- **Cola y contrato:** la identidad de quien sube, el origen `tabletCasa` y el aviso solo con números.
- **Pruebas:** los casos adversariales del propio equipo (`bandeja_salida_test`, `sobre_sellado_test`, `pin_con_dinero_test`) son buenos; mantuvieron la suite honesta.
