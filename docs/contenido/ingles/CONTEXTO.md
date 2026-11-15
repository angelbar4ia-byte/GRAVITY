# Contexto · Inglés (Hábitos, Fase 8 bloque 5)

> Nota de respaldo para no perder el hilo. Fecha de corte: 15/nov/2026. Rama de trabajo: `claude/zen-pasteur-b0jblz`. Se actualiza en cada cierre importante.

## 1. Dónde estamos

- El inglés es un bloque del módulo **Hábitos** dentro de la app única **GRAVITY** (D1 y D10). Diseño base: `docs/modulos/habitos/diseno-app-habitos.md`, §5.3 y Anexo A. Especificación: `docs/specs/fase-8-habitos-ampliaciones.md` (bloque 5a, v0.4; quedó atrás respecto a decisiones posteriores).
- **Revisión completa del bloque (14 y 15/nov/2026):** `docs/revisiones/fase-8-ingles.md`. Veredicto: buena base de borradores, **no apto todavía** como curso ni como preparación de examen. Cinco hallazgos bloqueantes y nueve importantes, con mediciones.
- **Plan de ejecución:** `docs/specs/fase-8-ingles-plan.md`. Propuesto; espera las decisiones D-ING-1 a 8 del dueño. Lo ejecuta el equipo de agentes (Sonnet 5.5).
- **Formato de contenido `gravity-ingles-v1`:** `docs/specs/fase-8-ingles-formato.md`. Ejemplos patrón en `data/ingles/ejemplos/`.
- **En la app todavía no hay código de inglés.** El módulo Hábitos sí existe (`app/lib/modulos/habitos`, `paquetes/habitos_dominio`) y el sistema de diseño ya tiene el submódulo `ingles`.

## 2. Reglas aprobadas por el dueño (vigentes)

**Tiempo y constancia**
- 60 minutos diarios, **de lunes a viernes**. Sábado y domingo, descanso (el domingo, inglés ligero opcional que no cuenta).
- Bloque principal 35 min (repaso 5, lección 10, pronunciación 8, producción 12) y traslado 25 min (escucha 10, repetición 10, tarjetas 5).
- Racha: un día cuenta si se completan el principal y el traslado.
- **Día de gracia: tres por trimestre** (no se acumulan).
- Metas semanales: 5 de 5 días, 60 tarjetas, 300 minutos. Revisión del domingo, 5 minutos.

**Niveles y avance** (`niveles-y-avance.md`, v0.3)
- Regla de fondo: **cada bimestre se sube de nivel solo si se cumple todo; si no, no se sube.**
- Cuatro requisitos: pruebas de módulo con 80 % por habilidad, evaluación de cierre con 80 % por habilidad, constancia con días de gracia y al menos 90 % de los minutos planeados.
- **Dos oportunidades por bloque.** Si fallan las dos, se baja un nivel. La primera evaluación semanal fallida del bloque queda como día de gracia.
- Calendario vigente de 28 semanas: repaso A1 → A2 (4 semanas), bimestre 1 → B1, bimestre 2 → B1+, bimestre 3 → B2.

**Ubicación y pareja**
- La prueba de ubicación se aplica **una sola vez** y vive dentro de la app; de ahí empieza el curso.
- Los saltos de nivel solo valen si la prueba los confirma; si no, la persona queda en su nivel real.
- Cada persona tiene su resultado. Si coinciden, estudian juntos; si no, nadie frena al otro.

**Evaluación** (`rubrica-evaluacion.md`)
- Cuatro habilidades con el mismo peso. Escala 0 a 4 por criterio. Umbral 80 % por habilidad, sin compensar.

**Exámenes**
- Cambridge (B1 Preliminary y B2 First), TOEIC y TOEFL se preparan **por igual, sin perder calidad**. El usuario elige cuál lleva.
- Bimestre 3: B2 First como principal y TOEFL como secundario.

> La revisión propone ajustar **cómo** se aplican estas reglas (escalera de escalones, plantilla de sesión, ubicación con puerta anticipada). Nada cambia hasta que el dueño responda las decisiones del plan, sección 4.

## 3. Estado real de los documentos

| Documento | Estado |
|---|---|
| `docs/revisiones/fase-8-ingles.md` | Revisión del bloque, con evidencia |
| `docs/specs/fase-8-ingles-plan.md` | Plan de ejecución, propuesto |
| `docs/specs/fase-8-ingles-formato.md` y `data/ingles/ejemplos/` | Formato propuesto y siete ejemplos patrón |
| `modulo-1.md`, `modulo-2.md` | Temas aprobados por el dueño. Material para 5 a 10 minutos por día, no para 60 (ING-B4) |
| `modulo-3.md`, `modulo-4.md` | Redactados, sin aprobar. Mismo problema de densidad |
| `prueba-de-nivel.md` (v0.2) y `prueba-ubicacion.html` (publicada) | **En revisión: no usar para decidir el nivel.** Ubica de más (ING-B5) |
| `rubrica-evaluacion.md` | Borrador. Falta confirmar qué significa aprobar (D-ING-6) |
| `niveles-y-avance.md` (v0.3) | Vigente hasta la decisión D-ING-1 |
| `formatos-oficiales.md` | Número de partes y de preguntas verificado con los manuales. Faltan las longitudes, que irán en los contratos |
| Simulacros: B1 Preliminary A y B, B2 First A y B, TOEFL A y B, TOEIC completo | **Formato reducido.** Número de preguntas correcto; textos y guiones de 2.5 a 6 veces más cortos que los oficiales; sin audio; con preguntas inválidas listadas en la revisión (ING-B1, ING-B2) |
| Prácticas por partes (B1, B2 ×2, TOEFL, TOEIC) y `toeic-bimestre-2.md` | Reducidas. Comparten contenido entre sí y con los simulacros (ING-I1) |
| `guia-multiexamen.md`, `cambridge-y-toefl.md`, `toeic.md`, `simulacros/bimestre-3.md`, `cobertura-practica.md` | Planes anteriores. Los sustituye el plan de ejecución |
| `especificacion-ubicacion-en-app.md` | Corregida. La sustituye la fase 2 del plan |

## 4. Decisiones que esperan al dueño

Están en el plan, sección 4, con recomendación en cada una:

1. D-ING-1: escalera de escalones; etiqueta del marco europeo al pasar la puerta de la etapa.
2. D-ING-2: hora diaria con la plantilla nueva.
3. D-ING-3: audio con la voz del dispositivo.
4. D-ING-4: aprobar plantillas y muestras en lugar de cada documento.
5. D-ING-5: ubicación única con puerta anticipada y descenso por evidencia.
6. D-ING-6: qué significa aprobar con la rúbrica.
7. D-ING-7: orden de producción y de exámenes.
8. D-ING-8: limpieza de ramas.

## 5. Acceso y herramientas

- **Red:** el entorno permite `www.ets.org` y `www.cambridgeenglish.org` (aprobado por el dueño el 14/nov/2026). Otros dominios, como la página de soporte de Cambridge, no.
- **Flutter y Dart:** en `/home/user/tools/flutter/bin`. La suite de la app corre aquí: 3033 pruebas en verde el 14/nov/2026.
- **Manuales oficiales:** se descargan a una carpeta temporal para leer el formato. No se suben al repositorio ni se copian sus preguntas.
- **Habilidad:** `.claude/skills/simulacro-examen-idioma/`. Desde el 15/nov/2026 está versionada (antes `.gitignore` la dejaba fuera y se habría perdido).
- **GitHub:** no se buscan repositorios de terceros con material de examen.

## 6. Ramas

- Trabajo: `claude/zen-pasteur-b0jblz`.
- Sobran, a la espera de D-ING-8: `claude/integracion-ingles-main` (solo un commit de merge sobre `main`) y `claude/ubicacion-ingles` en el repositorio de Hábitos, que por D10 es historial archivado.

## 7. Pendientes fuera de inglés

- Prueba SQL `99_cuidados_recordatorios.sql`: falla porque la función usa `now()` y la prueba usa fechas fijas. Hay que decidir cuál cambia.
- `flutter analyze`: 7 avisos informativos (Alimentación, Finanzas y una prueba), sin errores.
- Lo que depende del dueño según el roadmap: proyecto de Supabase, Firebase, `pg_cron`, clave de Gemini y Google Cloud.

## 8. Cómo retomar

1. Leer la revisión y el plan.
2. Si el dueño ya respondió las decisiones: registrarlas (paquete P0.2) y lanzar el segundo lote del plan (sección 8).
3. Si no ha respondido: lanzar el primer lote, que no depende de ninguna decisión (P0.1, P1.1, P1.2a y P1.4).
4. Cada paquete se lanza con el encargo tipo de la sección 5.3 del plan.
