# Licencias y huellas de las voces candidatas (P3.0b)

Verificación del 22/nov/2026 de las candidatas de `docs/specs/fase-8-motor-de-voz.md`, sección 9.1.
Cada `.tar.bz2` se descargó completo de los *releases* `tts-models` de sherpa-onnx; se midió su tamaño y su
sha256, se extrajo (sin `espeak-ng-data`) y se hasheó cada archivo. Los textos de licencia se leyeron de las
fuentes y se copiaron **literales** a `textos/`. Las huellas por archivo están en `verificadas.json`.

**Esto no es el catálogo de la app** (`app/assets/voces/catalogo.json`, spec 4.2.1): le faltan el alojamiento
(pregunta 4, sin respuesta), la revisión fija en ese alojamiento, los `sid`/género de cada voz y las mediciones
de `uso` y `rtf` (P3.3, en el A52 y la laptop). La regla 1 del catálogo prohíbe entradas con pendientes.

**Quién decide:** lo legal lo decide una persona (el dueño o su asesor), no un agente. Abajo van las lecturas y
una recomendación; no es asesoría legal.

## Resultado por candidata

| Candidata | Licencia que declara | Lo que encontré | Veredicto |
|---|---|---|---|
| `kristin` (en-US, mujer), `norman` (en-US, hombre) | «public domain», entrenadas desde cero con grabaciones de LibriVox | Tarjeta leída (`textos/MODEL_CARD-*`). **No pude leer** librivox.org ni la página del autor (hosts no permitidos): el «dominio público» es lo que afirma el autor del modelo | **Usable** |
| `john` (en-US, hombre) | «public domain»; ajustada desde kristin | Hereda lo de kristin | **Usable** |
| `cori` (en-GB, mujer) | «public domain», desde cero, LibriVox | Piper pide fonemas `espeak`; con `sherpa_onnx` 2.0.x hace falta un lexicón y **solo existe el americano** (V8): sonaría americanizada | **Licencia limpia; el acento es de V8** |
| `libritts_r` (904 voces, en-US) y `vctk` (109, en-GB) | CC BY 4.0 (los datos) | Las dos están **ajustadas desde *lessac***. La licencia de lessac es **solo de investigación** (ver abajo) | **No usar hasta que una persona decida** |
| `kokoro-en-v0_19` (11 voces) y `kokoro-int8-multi-lang-v1_1` | Apache-2.0 (el `LICENSE` del paquete y la tarjeta de hexgrad) | Los datos de entrenamiento incluyen audio **CC BY** (SIWIS, CC BY 4.0; Koniwa, CC BY 3.0) y «audio sintético generado por modelos de voz **cerrados** de grandes proveedores». El paquete v0_19 **no trae lexicón** y los modelos de Piper/Kokoro usaban `espeak-ng`, que `sherpa_onnx` 2.0.x ya no incluye; el v1_1 trae `lexicon-us-en.txt` y `lexicon-gb-en.txt` | **Licencia aceptable con atribución; falta que una persona acepte lo de los datos sintéticos y probar que funciona sin espeak (V8)** |
| `kitten-nano-en-v0_1-fp16` (8 voces) | Apache-2.0 (`LICENSE` del paquete, repositorio de KittenML y su tarjeta) | La tarjeta dice «developer preview» y **no dice con qué datos se entrenó** | **Licencia aceptable; procedencia de los datos sin documentar** |
| `es_MX-ald-medium` | Datos «unlicense» | Ajustada desde la voz `davefx` en español, **cuya licencia no leí**. Para el asistente basta la voz del dispositivo (pregunta 7) | **Fuera por ahora** |
| `es_MX-claude-high` | «apache-2.0» | La tarjeta cita como origen **un *space* de Hugging Face**, sin dataset ni procedencia de las grabaciones | **Fuera por ahora** |
| `lexicon-en-us.txt` | Sin licencia propia; encabezado «CMUDict + en_list + compounds» | CMUDict es BSD con copia del aviso (`textos/CMUDICT-LICENSE.txt`). **No encontré el origen ni la licencia de `en_list`** | **Pendiente de una persona** si se redistribuye |

### Lessac (Blizzard 2013): por qué excluyo `libritts_r` y `vctk`

El texto está en `textos/LESSAC-BLIZZARD-2013-licencia-de-investigacion.txt`. Lo que dice, literal:

- La licencia es «**exclusively for Research Purposes only**»; los fines de investigación «**excludes** … using the
  Materials for any commercial purpose, including the development, marketing, commercialisation, sale or licencing
  of **voice synthesis** or speech recognition products or services».
- Cláusula 7: no se puede «sell, distribute or otherwise part with the Materials».
- Cláusula 8: licencia solo para el usuario; no permite que terceros usen los materiales.

Lo que **no sé**: si esas condiciones pasan a los **pesos** de un modelo ajustado desde esos datos. Es una pregunta
jurídica abierta; Piper y sherpa-onnx publican esos modelos. GRAVITY es de uso familiar, pero distribuiría los
pesos a varios aparatos y pregrabaría audio del curso. Recomendación: no usarlos mientras una persona no lo decida.

### Atribución que debería mostrar la pantalla

- Voces de dominio público: no la exigen; conviene decir de dónde vienen («Voces de LibriVox, vía Piper»).
- Kokoro: «Kokoro-82M, Apache-2.0 (hexgrad). Entrenado en parte con datos CC BY: SIWIS (CC BY 4.0) y Koniwa (CC BY 3.0)».
- Kitten: «KittenTTS, Apache-2.0 (KittenML)».
- Si se alojan los archivos, se copia junto a ellos el texto de la licencia (`textos/APACHE-2.0.txt`).

### No se redistribuye `espeak-ng-data`

Los paquetes originales traen la carpeta `espeak-ng-data` (datos de espeak-ng, GPL-3.0 según su proyecto; no leí
su texto). El catálogo lista solo los archivos útiles (`verificadas.json`) y no la incluye.

## Lo que alcanza para elegir un conjunto

Con solo lo «usable» hay en inglés americano **tres** voces (kristin, john, norman) y en británico **una** (cori,
con el problema del lexicón). El curso quiere cinco papeles (F1, F2, M1, M2, N) y acento británico para Cambridge.
Para completar hacen falta Kokoro (11 voces, americanas y británicas, la mejor cobertura) o Kitten, o aceptar el
riesgo de lessac. Esa es la decisión del dueño.

## Lo que sigue sin verificar

- LibriVox y la página del autor de las voces de dominio público (hosts no permitidos en esta sesión).
- Licencia de la voz `davefx`, de `en_list` y de `espeak-ng`; procedencia de los datos de Kitten.
- Si los modelos suenan bien y corren sin espeak con `sherpa_onnx` 2.0.1 (V3, V8: hay que oírlos y medirlos).

## Prueba con `sherpa_onnx` 2.0.1 (22/nov/2026, Python, x86 de 4 núcleos; **no** es el A52 ni la laptop)

Sirve para saber si los archivos funcionan sin `espeak-ng`; **el RTF no vale para el catálogo** (regla 5 de 4.2.1: sale
de los aparatos) y la calidad solo se oye (P3.3).

| Modelo | Resultado |
|---|---|
| `kristin` (Piper) con `lexicon-en-us.txt` | **Funciona.** 22 050 Hz; RTF 0.08 con 2 hilos. El lexicón cubre las 48 palabras de prueba menos `I'm` |
| `kokoro-int8-multi-lang-v1_1` con `lexicon-us-en.txt` (`lang=en-us`) | **Funciona**, 103 voces, 24 000 Hz; RTF 1.2 con 2 hilos (más lento que el habla: sirve para **pregrabar**, no para tiempo real). **Pero omite palabras:** el lexicón no trae formas regulares comunes (`lived`, `wanted`, `listened`, `opened`, `arrived`, `believed`) y `sherpa_onnx` las **salta en silencio** («OOV word skipped»). Faltan 7 de 49 palabras de prueba (6 de 49 con el lexicón británico) |
| `kokoro-en-v0_19` sin `espeak-ng-data` | **No funciona** («No lexicon available»): sin espeak necesita un lexicón que su paquete no trae |

Consecuencias: (1) `kokoro-en-v0_19` queda descartado; (2) con Kokoro, todo texto del curso tiene que pasar por una
revisión de palabras fuera del lexicón antes de pregrabarse (se corrige el texto o se agrega la entrada al lexicón,
y esas entradas son contenido propio); (3) las voces Piper de dominio público con su lexicón sí cubren el texto y son
las únicas con tiempo real holgado. El mapa de `sid` a nombre de la documentación es del paquete v1_0 (54 voces); el del
v1_1 (103) no lo pude confirmar, así que los `sid` del catálogo se fijan oyendo (P3.3).

## Decisiones del dueño (22/nov/2026)

- **Pregunta 6, licencias:** se aceptan voces con atribución (CC BY mostrada en Ajustes); Kokoro v1_1 con atribución; las de
  dominio público como respaldo; se excluye lessac (`libritts_r`, `vctk`) hasta que una persona lea y decida.
- **Pregunta 4, alojamiento:** copia propia con revisión fija y huella (Supabase Storage). Pendiente de hacer: crear el
  *bucket* público de solo lectura y subir los archivos de `verificadas.json` que se elijan, con
  `supabase/scripts/verificar-voces.sh` para comprobar las huellas después de subirlos. Peso estimado: unos 255 MB las
  cuatro voces de dominio público y unos 180 MB Kokoro (dentro del 1 GB de D7, que se comparte con las fotos).
