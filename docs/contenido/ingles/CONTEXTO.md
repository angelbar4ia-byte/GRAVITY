# Contexto · Inglés (Hábitos, Fase 8 bloque 5)

> Nota de respaldo para no perder el hilo. Fecha de corte: 14/nov/2026. Rama: `claude/zen-pasteur-b0jblz`. Se actualiza en cada cierre importante.

## 1. Qué es y de dónde sale

- Módulo de **inglés** dentro de Hábitos (GRAVITY). Diseño base: `docs/modulos/habitos/diseno-app-habitos.md`, §5.3 y Anexo A.
- Especificación de este bloque: `docs/specs/fase-8-habitos-ampliaciones.md` (alcance 5a: aprobado por el dueño).
- Alcance 5a: ruta de lecciones, prueba de nivel, vocabulario con repaso espaciado, gramática con ejercicios, métricas y racha. **Sin audio, sin pronunciación con reconocimiento de voz y sin IA en esta etapa.**

## 2. Reglas aprobadas por el dueño

**Tiempo y constancia**
- 60 minutos diarios, **de lunes a viernes**. Sábado y domingo, descanso (el domingo, inglés ligero opcional que no cuenta).
- Bloque principal 35 min (repaso 5, lección 10, pronunciación 8, producción 12) y traslado 25 min (escucha 10, repetición 10, tarjetas 5).
- Racha: un día cuenta si se completan el principal y el traslado.
- **Día de gracia: tres por trimestre** (no se acumulan).
- Metas semanales: 5 de 5 días, 60 tarjetas, 300 minutos.
- Revisión del domingo, 5 minutos.

**Niveles y avance** (`niveles-y-avance.md`)
- Calendario de 28 semanas: prueba de nivel (semana 0), **repaso A1 → A2 (semanas 1 a 4)**, bimestre 1 (módulos 1 y 2) → **B1**, bimestre 2 (módulos 3 y 4) → **B1+**, bimestre 3 (módulos 5 y 6) → **B2**, solo con la prueba final tipo B2.
- Cada bloque sube de nivel solo si cumple **cuatro requisitos**: pruebas de módulo con 80 % por habilidad, evaluación de cierre con 80 % por habilidad, constancia con días de gracia, y al menos 90 % de los minutos planeados.
- **Dos oportunidades por bloque.** Si fallas las dos, bajas un nivel.
- La primera evaluación semanal fallida del bloque queda como día de gracia.

**Evaluación** (`rubrica-evaluacion.md`)
- Cuatro habilidades con el mismo peso (25 % cada una).
- Escala 0 a 4 por criterio. Umbral 80 % por habilidad, sin compensar una con otra.
- No es certificación oficial.

**Exámenes externos**
- **Bimestre 1: Cambridge B1 Preliminary** (elegido por el dueño, porque su nivel es B1).
- **Bimestre 2: TOEIC** (preparación con simulacros mensuales).
- **Bimestre 3:** dos alternados. Principal Cambridge B2 First (confirmado por el dueño); secundario TOEFL cada cuatro semanas.
- **Principio del dueño:** los tres exámenes (TOEIC, Cambridge y TOEFL) deben prepararse **por igual, sin perder calidad**. El usuario elige cuál lleva: uno, dos o tres alternados.
- **Cuarta opción** (la recomendada por el dueño): combina lo mejor de cada examen y prepara para aprobar cualquiera de los tres oficiales. Es la referencia del sistema.

## 3. Estado de los documentos

| Documento | Estado |
|---|---|
| `prueba-de-nivel.md` | Redactada, pendiente de revisión |
| `prueba-ubicacion.html` | Versión interactiva de la prueba de ubicación: cada persona la contesta sola y ve su nivel en la página. Publicada como artefacto privado. No guarda resultados en ningún servidor. Pendiente: validar contra las escalas oficiales |
| `modulo-1.md` | **Aprobado** (versión 1.0) |
| `modulo-2.md` | **Aprobado** (versión 1.0) |
| `modulo-3.md` | Redactado, pendiente de revisión |
| `modulo-4.md` | **Borrador v0.1**, pendiente de revisión del dueño. Depende de la aprobación del módulo 3 (`modulo-3.md`, también pendiente) |
| `prueba-de-nivel.md` | **Prueba de ubicación v0.2**: ubica a cada persona en A1, A2, B1, B1+ o B2 por separado (35 ítems automáticos y una tarea de escritura). Plan de inicio por resultado y reglas de emparejamiento en pareja (sin ajustar resultados). Pendiente: aprobación de saltos de bimestre (B1+ y B2) |
| `modulo-5` a `modulo-6` | Pendiente. Se redactan después de cada aprobación |
| `rubrica-evaluacion.md` | Borrador, pendiente de aprobación |
| `niveles-y-avance.md` | Versión 0.3 con las decisiones del dueño |
| `toeic.md` | Método de preparación (decisiones registradas) |
| `formatos-oficiales.md` | Verificado con fuentes oficiales: TOEIC (handbook de ETS), Cambridge B1 Preliminary y B2 First (Cambridge), TOEFL iBT 2026 (especificación de ETS) |
| `simulacros/cambridge-b2-first-B-lectura.md`, `cambridge-b2-first-B-escucha.md`, `cambridge-b2-first-B-escritura-habla.md` | **B2 First simulacro B** completo en formato (Reading 52, Listening 30 en texto, Writing 2, Speaking 4). Pendientes: opciones de Listening Parte 3 (verificar), audio, imágenes |
| `simulacros/cambridge-b2-first-A-lectura.md`, `cambridge-b2-first-A-escucha.md`, `cambridge-b2-first-A-escritura-habla.md` | **B2 First simulacro A** completo en formato verificado (Reading 52, Listening 30 en texto, Writing 2, Speaking 4). Pendientes: opciones de Listening Parte 3 (verificar), audio, imágenes de Speaking |
| `simulacros/toeic-bimestre-2.md` | Simulacros A y B **de práctica por partes** (33 preguntas cada uno). **No cumplen el formato completo**; la revisión está en su sección 0 |
| `simulacros/cambridge-y-toefl.md` | Plan de simulacros de Cambridge B1 y B2 First, y de TOEFL |
| `simulacros/cambridge-b1-preliminary-A.md` | **Simulacro A completo** (Reading 32, Writing 2, Listening 25 en texto, Speaking 4 partes) con clave |
| `simulacros/cambridge-b1-preliminary-B.md` | **Simulacro B completo** (Reading 32, Writing 2, Listening 25 en texto, Speaking 4 partes) con clave. Letras de Reading P1 reordenadas para evitar repetición. Pendientes: audio, imágenes de Speaking, aprobación de la fuente |
| `simulacros/toefl-ibt-A.md` | **Simulacro A completo** (Reading 50, Listening 47 en texto, Writing 12, Speaking 11) con clave |
| `simulacros/toefl-ibt-B.md` | **Simulacro B completo** (Reading 50, Listening 47 en texto, Writing 12, Speaking 11) con clave. Preguntas nuevas; letras de las claves revisadas (sin tres respuestas iguales seguidas). Pendientes: audio, imágenes, tiempos de Speaking y extensión de Writing 11 contra la especificación |
| `simulacros/bimestre-3.md` | Índice del bimestre 3 (B2): qué existe para B2 First y TOEFL, y las decisiones pendientes del dueño (examen o modo de elección) |
| `simulacros/b2-first-practica-por-partes.md` | Práctica por partes de B2 First (15 sesiones: Reading 1–7, Listening 1–4, Writing 1–2, Speaking 1–4), con clave y regla por error. Preguntas originales. Pendiente: verificar el número de opciones de Listening Parte 3 |
| `simulacros/b2-first-practica-por-partes-2.md` | Segunda ronda de práctica por partes de B2 First (sesiones 16 a 30), con preguntas nuevas, clave y regla por error. Pendiente: verificar el número de opciones de Listening Parte 3 |
| `cobertura-practica.md` | Matriz de cobertura: programa (repaso, módulos 1 a 6) y exámenes (B1 Preliminary, B2 First, TOEFL, TOEIC), con lo que falta y el orden |
| `b1-preliminary-practica-por-partes.md` | Práctica por partes de Cambridge B1 Preliminary (16 sesiones: Reading 1 a 6, Writing 1 y 2, Listening 1 a 4, Speaking 1 a 4), con clave y regla por error. Preguntas originales |
| `toefl-practica-por-seccion.md` | Práctica de TOEFL iBT 2026 por sección y tipo de tarea (12 sesiones: Reading 3, Listening 4, Writing 3, Speaking 2), con clave y regla por error. Preguntas originales. Pendiente: audio y tiempos de Speaking |
| `toeic-practica-por-partes.md` | Práctica de TOEIC por partes (Listening 1 a 4, Reading 5 a 7) en tres niveles: básico, intermedio, avanzado. El usuario elige el nivel de inicio. Preguntas originales. Pendiente: audio y fotografías |
| `simulacros/toeic-completo-escucha.md`, `toeic-completo-lectura.md`, `toeic-completo-hablar-escribir.md` | **TOEIC completo** (formato oficial: 100 Listening, 100 Reading, 11 Speaking, 8 Writing). Pendientes: reequilibrar letras correctas en Listening (partes 3 y 4) y Reading (Parte 5); revisar Reading 6 (146); tiempos de Speaking y extensión de Writing 8 contra el handbook; imágenes y audio |
| `simulacros/guia-multiexamen.md` | Guía común: mismo paquete para TOEIC, Cambridge y TOEFL; tres modos de elección |

## 4. Decisiones pendientes

1. **Bimestre 3:** aprobar la fuente de audio para Listening de B2 First y TOEFL.
2. **Simulacro completo de TOEIC:** escrito con el formato oficial. Faltan los ajustes de la sección de estado (letras de la clave, tiempos de Speaking, imágenes y audio).
3. **Cambridge B1 Preliminary:** Listening con audio y Speaking con imágenes, cuando se apruebe el material. Parte 3 de Reading: **verificada** en el manual para profesores (5 preguntas, 4 opciones).
4. **TOEFL:** audio y el formato de imágenes/video de Speaking cuando estén disponibles.
5. **Revisión de la Parte 2 de Writing de Cambridge:** elegir artículo o historia (formato del handbook).
6. **Equivalencias:** cómo se traduce un simulacro a la escala del examen oficial. Aún no acordado.

## 5. Acceso y herramientas

- **Red:** el entorno Default permite `www.ets.org` y `www.cambridgeenglish.org` (aprobado por el dueño el 14/nov/2026). Revertible si se pide.
- **GitHub:** no se buscan repositorios de terceros con material de examen; el acceso de GitHub se limita al repositorio del proyecto.
- **Material oficial** de ETS y Cambridge: se usa solo para formato. No se copian ni se redistribuyen preguntas.

## 5b. Habilidad para idiomas

- Se creó `.claude/skills/simulacro-examen-idioma/SKILL.md`: procedimiento para construir simulacros con formato oficial verificado, preguntas originales, claves reequilibradas y contexto. **Se aplica primero a inglés.** Otros idiomas se agregan después, en su propia carpeta, y solo cuando el dueño lo pida.

## 6. Pendientes fuera de inglés (proyecto GRAVITY)

Lo que sigue pendiente en el proyecto, según el roadmap (`docs/ROADMAP.md`, sección de versiones 2.x):
- Alimentación v1.6 y v1.7: falta la app del botón del albacea para autorizar el reembolso (ya se hizo el botón en el historial) y la prueba en dispositivo.
- Finanzas bloque 1: conciliación de estados de cuenta en PDF (falta la lista de bancos).
- Owner: activar `pg_cron`, clave de Gemini, despliegue de funciones de Supabase, Google Cloud para Gmail y Calendar, Home Assistant Green.
- Prueba 99 de Cuidados: falla con la fecha actual; ya fallaba antes de cambios recientes.

## 7. Cómo retomar

1. Leer este archivo y `niveles-y-avance.md`.
2. Confirmar qué simulacro sigue: **TOEIC completo** (Listening 100, Reading 100, Writing 8, Speaking 11), con el formato del handbook de ETS.
3. Después: TOEFL y Cambridge con audio e imágenes en cuanto estén disponibles; la elección de examen del usuario se mantiene.
