# Contexto · Inglés (Hábitos, Fase 8 bloque 5)

> Nota de respaldo para no perder el hilo. Fecha de corte: 15/nov/2026. Rama de trabajo: `claude/zen-pasteur-b0jblz`. Se actualiza en cada cierre importante.

## 1. Dónde estamos

- El inglés es un bloque del módulo **Hábitos** dentro de la app única **GRAVITY** (D1 y D10). Diseño base: `docs/modulos/habitos/diseno-app-habitos.md`, §5.3 y Anexo A. Especificación: `docs/specs/fase-8-habitos-ampliaciones.md` (bloque 5a, v0.4; quedó atrás respecto a decisiones posteriores).
- **Revisión completa del bloque (14 y 15/nov/2026):** `docs/revisiones/fase-8-ingles.md`. Veredicto: buena base de borradores, **no apto todavía** como curso ni como preparación de examen. Cinco hallazgos bloqueantes y nueve importantes, con mediciones.
- **Plan de ejecución:** `docs/specs/fase-8-ingles-plan.md` (versión 0.4). Lo ejecuta el equipo de agentes (Sonnet 5.5). El dueño confirmó D-ING-1 a 6 (escalera de 13 escalones, hora diaria con mínimos, tres vías de audio y motor de voz de GRAVITY, aprobación por muestras, ubicación de 12 preguntas por nivel y criterio de aprobar), registradas en D29. Faltan D-ING-7 y 8. El primer lote y P1.2b ya se ejecutaron (anexo A).
- **Herramienta `herramientas/ingles`:** orden `validar` (V01 a V14 sin V06), 169 pruebas en verde. Faltan `exportar`, `comparar`, `compilar` e `informe`. Mientras tanto, `herramientas/ingles/transitorio/` genera el cuaderno a ciegas y compara las rondas.
- **Formato de contenido `gravity-ingles-v1`:** `docs/specs/fase-8-ingles-formato.md` (versión 0.3). Nueve ejemplos patrón en `data/ingles/ejemplos/`, en borrador, y su cuaderno a ciegas en `docs/contenido/ingles/generado/`.
- **Paquete P0.1 hecho (15/nov/2026):** simulacros y prácticas dicen "formato reducido"; la prueba de nivel y la página dicen "en revisión".
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
- **Dos oportunidades por bloque.** Si fallan las dos, se baja un nivel (ahora, un escalón). La primera evaluación semanal fallida del bloque queda como día de gracia.
- **Calendario (D-ING-1, 16/nov/2026): escalera de 13 escalones de 8 semanas y 40 horas** (A1 ×2, A2 ×3, B1 ×4, B2 ×4), con puertas de etapa de formato oficial a las 200, 360 y 520 horas acumuladas. Sustituye al calendario de 28 semanas.

**Ubicación y pareja**
- La prueba de ubicación se aplica **una sola vez** y vive dentro de la app; de ahí empieza el curso.
- Los saltos de nivel solo valen si la prueba los confirma; si no, la persona queda en su nivel real.
- Cada persona tiene su resultado. Si coinciden, estudian juntos; si no, nadie frena al otro.

**Evaluación** (`rubrica-evaluacion.md`)
- Cuatro habilidades con el mismo peso. Escala 0 a 4 por criterio. Umbral 80 % por habilidad, sin compensar.
- **Aprobar escritura y habla (D-ING-6):** promedio ponderado de 80 % y «gramática del tema» en 3 o más. Las pruebas objetivas llevan 10 preguntas o más por habilidad.

**Exámenes**
- Cambridge (B1 Preliminary y B2 First), TOEIC y TOEFL se preparan **por igual, sin perder calidad**. El usuario elige cuál lleva.
- Bimestre 3: B2 First como principal y TOEFL como secundario.

> La revisión propone ajustar **cómo** se aplican estas reglas (escalera de escalones, plantilla de sesión, ubicación con puerta anticipada). Nada cambia hasta que el dueño responda las decisiones del plan, sección 4.

## 3. Estado real de los documentos

| Documento | Estado |
|---|---|
| `docs/revisiones/fase-8-ingles.md` | Revisión del bloque, con evidencia |
| `docs/specs/fase-8-ingles-plan.md` | Plan de ejecución, propuesto |
| `docs/specs/fase-8-ingles-formato.md` y `data/ingles/ejemplos/` | Formato propuesto y nueve ejemplos patrón |
| `modulo-1.md`, `modulo-2.md` | Temas aprobados por el dueño. Material para 5 a 10 minutos por día, no para 60 (ING-B4) |
| `modulo-3.md`, `modulo-4.md` | Redactados, sin aprobar. Mismo problema de densidad |
| `prueba-de-nivel.md` (v0.2) y `prueba-ubicacion.html` (publicada) | **En revisión: no usar para decidir el nivel.** Ubica de más (ING-B5). El aviso ya está en los dos archivos y en la página publicada (versión 4) |
| `rubrica-evaluacion.md` | Borrador. Falta confirmar qué significa aprobar (D-ING-6) |
| `niveles-y-avance.md` (v0.3) | Vigente salvo el calendario de 28 semanas, que sustituye la escalera de 13 escalones (D29). La versión 0.4 (paquete P1.3) lo reescribe |
| `formatos-oficiales.md` | Número de partes y de preguntas verificado con los manuales. Faltan las longitudes, que irán en los contratos |
| Simulacros: B1 Preliminary A y B, B2 First A y B, TOEFL A y B, TOEIC completo | **Formato reducido.** Número de preguntas correcto; textos y guiones de 2 a 6 veces más cortos que los oficiales; sin audio; con preguntas inválidas listadas en la revisión (ING-B1, ING-B2) |
| Prácticas por partes (B1, B2 ×2, TOEFL, TOEIC) y `toeic-bimestre-2.md` | Reducidas. Comparten contenido entre sí y con los simulacros (ING-I1) |
| `guia-multiexamen.md`, `cambridge-y-toefl.md`, `toeic.md`, `simulacros/bimestre-3.md`, `cobertura-practica.md` | Planes anteriores. Los sustituye el plan de ejecución |
| `especificacion-ubicacion-en-app.md` | Corregida. La sustituye la fase 2 del plan |

## 4. Decisiones

D-ING-1 a 10 están **confirmadas** (15 y 16/nov/2026) y registradas en `docs/DECISIONES.md` (D29). Puntos a tener presentes:

0. **El curso NO arranca hasta que la fase 6 (pareja y corrección con IA) esté integrada** (D-ING-9 y 10, 16/nov/2026). Mientras tanto se construye todo lo demás y se produce el piloto y A2.1. Depende de pendientes del dueño: clave de Gemini, despliegue de la función del asistente y Google Cloud.
1. **Orden (D-ING-7):** el curso arranca por **A2.1** y la ubicación. El orden de los exámenes (A2 Key primero) lo ajusté yo; el dueño no lo eligió.
2. **Ramas (D-ING-8):** aprobada, pero **sin ejecutar**: el servidor rechazó el borrado (403). Ver la sección 6.

## 5. Acceso y herramientas

- **Red:** el entorno permite `www.ets.org` y `www.cambridgeenglish.org` (aprobado por el dueño el 14/nov/2026), y además alcanza pub.dev, `raw.githubusercontent.com` y los archivos de los *releases* de GitHub. No alcanza Hugging Face, la página de soporte de Cambridge ni el sitio de Macmillan. Borrar ramas en el servidor da 403.
- **Flutter y Dart:** en `/home/user/tools/flutter/bin`. La suite de la app corre aquí: 3033 pruebas en verde el 14/nov/2026.
- **Manuales oficiales:** se descargan a una carpeta temporal para leer el formato. No se suben al repositorio ni se copian sus preguntas.
- **Habilidad:** `.claude/skills/simulacro-examen-idioma/`. Desde el 15/nov/2026 está versionada (antes `.gitignore` la dejaba fuera y se habría perdido).
- **GitHub:** no se buscan repositorios de terceros con material de examen.

## 6. Ramas

- Trabajo: `claude/zen-pasteur-b0jblz`.
- **Sobran y el dueño aprobó borrarlas (D-ING-8), pero el servidor lo rechazó (403) desde la sesión:** `claude/integracion-ingles-main` en GRAVITY (solo un commit de unión con `main`; ya no existe la copia local) y `claude/ubicacion-ingles` en el repositorio de Hábitos (una nota ya reescrita en GRAVITY; es historial archivado por D10). Para terminarlo: en GitHub, Branches, icono de papelera; o `git push origin --delete <rama>` desde una terminal propia.

## 7. Pendientes fuera de inglés

- Prueba SQL `99_cuidados_recordatorios.sql`: falla porque la función usa `now()` y la prueba usa fechas fijas. Hay que decidir cuál cambia.
- `docs/DECISIONES.md`: el índice del principio no lista D22 a D28 (sí existen sus secciones).
- `flutter analyze`: 7 avisos informativos (Alimentación, Finanzas y una prueba), sin errores.
- Lo que depende del dueño según el roadmap: proyecto de Supabase, Firebase, `pg_cron`, clave de Gemini y Google Cloud.

## 8. Cómo retomar

1. Leer la revisión y el plan.
2. Lanzar lo que sigue (sección 8 del plan): P0.3 y P6.0 cuando termine P1.3. P1.1b y P3.0 ya están hechos. Los encargos del primer lote, ya ejecutado, están en el anexo D del plan y sirven de modelo.
3. Cuando el dueño pida el pull request a `main`, abrirlo (no antes).
4. Los demás paquetes se lanzan con el encargo tipo de la sección 5.3 del plan.
