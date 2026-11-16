# Plan de ejecución — Fase 8, bloque 5 (Hábitos · Inglés)

> Versión 0.4 (16/nov/2026). **Aprobado en lo esencial por el dueño** (D-ING-1 a 6, sección 4.1); faltan D-ING-7 y D-ING-8. Lo que cambió desde la 0.1 está en el anexo C.
> Ejecuta: el equipo de agentes del roadmap (sección 11), todos en **Sonnet 5.5** por la regla 11.1.10. Orquesta e integra: el arquitecto.
> Base: revisión `docs/revisiones/fase-8-ingles.md` (5 bloqueantes, 9 importantes) y formato `docs/specs/fase-8-ingles-formato.md`.
> No cambia ninguna decisión confirmada por su cuenta: lo que requiere al dueño está en la sección 4.

## 1. Resultado que se busca

Un programa de inglés dentro de GRAVITY (módulo Hábitos) que:

1. Ubica a cada persona **una sola vez** y con justicia.
2. Le da **una hora diaria de práctica real**, no una hora de reloj.
3. Le dice **la verdad** sobre su nivel y sobre si está lista para un examen.
4. Funciona **sin conexión** y sin IA, como pide la especificación 5a.
5. Se produce y se revisa con agentes Sonnet **sin depender de que alguien lea cada pregunta**.

Palabras que usa este plan:

| Palabra | Significa |
|---|---|
| Escalón | Tramo de 8 semanas con su prueba al final. Cada bimestre se sube un escalón si se cumple todo |
| Etapa | Nivel del marco europeo: A1, A2, B1 o B2. Una etapa tiene de 2 a 4 escalones |
| Puerta | La prueba que hay que pasar para subir: de escalón (interna) o de etapa (con formato de examen oficial) |
| Unidad | Un texto, audio o consigna con sus preguntas |
| Forma | Una prueba armada con unidades. Dos formas del mismo examen no comparten nada |
| Fidelidad | Cuánto se parece una forma al examen oficial: completa o reducida. La calcula la herramienta |
| Resolución a ciegas | Otro agente contesta la prueba sin ver la clave; si no coincide, la pregunta se corrige o se retira |

## 2. Principios

1. **Primero los rieles, después el contenido.** Hasta ahora se escribió mucho sin forma de comprobarlo. Se construye primero el formato y el validador; después se produce.
2. **Lo que no se mide, no se afirma.** Ningún documento dice "completo" o "verificado" a mano. El estado lo calcula la herramienta.
3. **Una sola fuente.** El contenido vive en datos (`data/ingles/`). El cuaderno del estudiante, la clave y lo que carga la app se generan de ahí.
4. **Fidelidad por contrato.** Cada examen tiene su contrato tomado del manual oficial: partes, preguntas, opciones, longitud de textos, tiempos y número de veces que se oye el audio.
5. **Nadie revisa su propio trabajo.** Toda pregunta objetiva se resuelve a ciegas por otro agente antes de llegar a la app.
6. **Las etiquetas A2, B1 y B2 se ganan en una puerta, no en un calendario.**
7. **El dueño aprueba plantillas y muestras, no cada documento.** Puede vetar cualquier pieza cuando quiera.

## 3. Diseño propuesto

### 3.1 Escalera de niveles

Se conserva la regla del dueño: **cada 8 semanas se sube si se cumple todo; si no, no se sube**. Lo que cambia es qué se sube: un **escalón**. La etiqueta del marco europeo se obtiene al pasar la puerta de la etapa, que tiene formato de examen oficial. **Confirmado por el dueño el 16/nov/2026 (D-ING-1): 13 escalones de 8 semanas y 40 horas**, alineados a las horas guiadas de Cambridge (anexo E).

| Etapa | Escalones (8 semanas y 40 horas cada uno) | Horas acumuladas al pasar la puerta | Puerta de la etapa |
|---|---|---|---|
| A1 | A1.1, A1.2 | 80 | Prueba interna de A1 |
| A2 | A2.1, A2.2, A2.3 | 200 | Forma completa tipo **A2 Key** |
| B1 | B1.1, B1.2, B1.3, B1.4 | 360 | Forma completa tipo **B1 Preliminary** |
| B2 | B2.1, B2.2, B2.3, B2.4 | 520 | Forma completa tipo **B2 First** |

- **Dos oportunidades en cada puerta de escalón.** Cada una es una evaluación de cierre completa. Si no se aprueba ninguna, **se baja un escalón** y se repite desde las habilidades no alcanzadas (regla ya aprobada, `niveles-y-avance.md`, sección 4; el dueño la recordó el 16/nov/2026). La primera evaluación semanal fallida del bloque queda como día de gracia, y entre oportunidades pasa al menos una semana de práctica.

- Los seis módulos del Anexo A (y los temas ya aprobados de los módulos 1 y 2) son semilla de la etapa B1: B1.1 = módulos 1 y 2, B1.2 = módulos 3 y 4, B1.3 y B1.4 = módulos 5 y 6 repartidos. Se reescriben con profundidad de B1 y con la plantilla de 60 minutos.
- El repaso A1 → A2 de un mes deja de ser un bloque para todos: quien salga ubicado en A2 hace los escalones de A2; quien salga en B1 con huecos de A2 recibe repaso dirigido en sus primeras semanas.
- TOEIC y TOEFL son rutas de preparación opcionales que se abren desde B1.2 y B2.1. No son puertas.
- El temario de cada escalón está en el anexo B.

**Tiempos honestos**, con 5 horas a la semana (40 horas por escalón) y aprobando todo a la primera:

| Empiezas en | Para llegar a | Escalones | Semanas | Horas | Horas guiadas acumuladas que estima Cambridge para ese nivel |
|---|---|---|---|---|---|
| Cero | A2 | 5 | 40 | 200 | 180 a 200 |
| A2 | B1 | 4 | 32 | 160 (360 acumuladas) | 350 a 400 |
| B1 | B2 | 4 | 32 | 160 (520 acumuladas) | 500 a 600 |

El plan coincide con la guía de Cambridge: desde cero son unos dos años a una hora diaria de lunes a viernes. Una hora con una app sin maestro probablemente rinde menos que una hora de clase, así que 520 horas es el piso y no el techo. Lo normal será repetir algún escalón, y eso no es un fracaso: es lo que dice la medición.

### 3.2 Sesión de 60 minutos real

Se respetan los tiempos aprobados (principal 35: repaso 5, lección 10, pronunciación 8, producción 12; traslado 25: escucha 10, repetición 10, tarjetas 5). Cada bloque tiene **mínimos de contenido** que el validador comprueba: por ejemplo, 10 preguntas en la lección del lunes, dos audios de 200 a 350 palabras en B1, 20 frases para repetir y una tarea de producción con lista de cotejo y respuesta modelo. Detalle en el formato, sección 7.

### 3.3 Ubicación: una vez, pero justa

- **48 preguntas**, 12 por etapa (6 de gramática y vocabulario, 3 de lectura, 3 de escucha con audio), alineadas al temario. Una etapa se alcanza con 10 de 12 y con todas las anteriores alcanzadas. La app deja de preguntar tras la primera etapa no alcanzada.
- El resultado decide **el escalón de entrada**:

  | Última etapa alcanzada | Entra en |
  |---|---|
  | Ninguna | A1.1 |
  | A1 | A2.1 |
  | A2 | B1.1 |
  | B1 | B2.1 |
  | B2 | B2.1, con derecho a presentar de inmediato la puerta de la etapa B2 (forma completa tipo B2 First). Doce preguntas no bastan para dar B2 por ganado |

- **El margen de error, con números.** Con 12 preguntas por etapa y corte en 10, quien domina el 70 % de una etapa la alcanza una de cada cuatro veces (25 %), y quien domina el 90 % se queda fuera una de cada nueve (11 %). Quien domina la mitad casi nunca la alcanza (2 %), y adivinando es prácticamente imposible. Es un cálculo binomial que supone preguntas independientes. Una prueba corta no puede dar más precisión; por eso el resultado se corrige después con evidencia.
- **La ubicación lleva escucha y es única:** no se abre hasta que el audio funcione en el dispositivo (P3.2a). Sin escucha ubicaría de más a quien lee bien y entiende poco al oído, y ese error ya no se podría corregir repitiéndola.
- No se repite. Los errores de ubicación se corrigen con evidencia, no con otra prueba de ubicación:
  - **Hacia arriba, puerta anticipada:** en la semana 2 de un escalón se puede presentar su puerta. Con 90 % o más en cada habilidad se pasa al siguiente escalón. No gasta ninguna de las dos oportunidades.
  - **Hacia abajo, descenso por evidencia:** dos mini pruebas seguidas por debajo de 50 % bajan un escalón, sin penalización.
- Las preguntas de ubicación no se usan en ningún otro lugar.
- En el servidor, una persona solo puede tener un registro de ubicación.

### 3.4 Exámenes

- Cada examen tiene contrato, banco por parte con longitud oficial, práctica por partes y dos formas completas más una de reserva.
- Lo que hoy existe se reetiqueta como **formato reducido** y sirve de práctica mientras se construyen las formas completas.
- **Semáforo de preparación por zonas**, sin puntajes inventados: rojo (menos de 60 % en alguna prueba), amarillo (60 a 79 %), verde (80 % o más en todas las pruebas de dos formas completas, con audio y con el tiempo oficial). La conversión a la escala de cada examen solo se muestra cuando esa escala esté verificada en su fuente.
- TOEFL iBT 2026 se rehace en tres puntos: "Completar palabras" con texto, conjuntos de 2 y 3 preguntas, y dos etapas (módulo de ruta y módulo inferior o superior).

### 3.5 Audio y habla

- **Audio:** la voz del propio dispositivo lee los guiones (paquete `flutter_tts`). Cuesta cero, funciona sin conexión y no tiene licencias que resolver porque los guiones son propios. Detrás de una interfaz, para poder cambiarlo por audio grabado sin tocar el contenido. El guion no se muestra hasta después de contestar.
- **Habla:** grabación local (no sale del dispositivo), autoevaluación con lista de cotejo y respuesta modelo. La revisión cruzada en pareja llega en la fase 6.

### 3.6 En la app

- **Servidor:** tablas `ing_*` (perfil, ubicación única, sesiones, tarjetas, pruebas) con reglas por persona como las de `hab_*`. Solo-agregar en ubicación, sesiones y pruebas. La cuenta maestra no las lee (D21).
- **Dominio:** `paquetes/habitos_dominio`, carpeta `ingles`: repaso espaciado, sesión completa y minutos, reglas de puertas, ubicación, puerta anticipada y descenso.
- **Pantallas:** Inicio de inglés, Ubicación, Sesión del día por bloques, Tarjetas, Progreso y puertas. El contenido viaja dentro de la app (`app/assets/ingles/`), así que estudiar no usa la red.

### 3.7 Pareja

Cada quien tiene su ruta. Si coinciden de escalón, comparten calendario y actividades. Si no, cada uno sigue la suya y hay un reto semanal que no depende del nivel. Es la fase 6 y necesita su propia especificación, porque hoy el progreso es privado.

## 4. Decisiones que necesita el dueño

| # | Decisión | Recomendación | Mientras no respondas |
|---|---|---|---|
| D-ING-1 | Escalera de 13 escalones de 8 semanas (propuesta revisada, anexo E); la etiqueta del marco europeo se obtiene en la puerta de la etapa | **Sí.** Mantiene tu regla y la alinea con las horas de Cambridge | No se redacta contenido nuevo de curso |
| D-ING-2 | Hora diaria con la plantilla nueva. Mientras no haya audio, cuenta solo el bloque principal (35 minutos) y el requisito del 90 % se calcula sobre eso | **Sí** | Igual que D-ING-1 |
| D-ING-3 | Audio con la voz del dispositivo (`flutter_tts`) | **Sí.** Se puede cambiar después por audio grabado | La escucha sigue en texto, los simulacros quedan como reducidos y la ubicación no se puede abrir, porque lleva escucha |
| D-ING-4 | Apruebas plantillas y muestras; el contenido pasa con validación, revisión a ciegas y muestreo de calidad | **Sí.** Hoy los módulos 3 y 4 esperan tu lectura y tú mismo dices que no es tu tema | Cada pieza espera tu aprobación, como ahora |
| D-ING-5 | Ubicación única con puerta anticipada y descenso por evidencia | **Sí.** Y no usar la página publicada para decidir el nivel hasta la versión 3 | La ubicación no se construye |
| D-ING-6 | En escritura y habla, aprobar es promedio ponderado de 3.2 sobre 4 (80 %) y «gramática del tema» en 3 o más: sacar 3 en todo **no** aprueba. Pruebas objetivas de 10 preguntas o más por habilidad | **Sí.** (Cambié mi recomendación anterior, «ningún criterio bajo 3», por ser dura con criterios chicos) | Se aplica el 80 % como está |
| D-ING-7 | Orden: primero B1.1 y la ubicación; después A2.1. Exámenes: B1 Preliminary, A2 Key, TOEIC, B2 First, TOEFL | **Sí.** Se reordena con el resultado real de la ubicación | Se sigue este orden |
| D-ING-8 | Borrar la rama `claude/ubicacion-ingles` del repositorio archivado de Hábitos y la rama `claude/integracion-ingles-main`. Llevar el trabajo a `main` por pull request cuando lo pidas | **Sí** | Las ramas quedan como están |

Las que se aprueben se registran en `docs/DECISIONES.md` como una decisión nueva (D29, ya abierta con las confirmadas).

### 4.1 Respuestas del dueño

| # | Respuesta | Fecha | Estado |
|---|---|---|---|
| D-ING-1 | **Sí, 13 escalones**, después de pedir y ver la investigación de horas por nivel (anexo E). Recordó que cada puerta tiene **dos oportunidades** y que, si no se aprueba, se baja un escalón | 16/nov/2026 | Confirmada |
| D-ING-2 | **Sí, con mínimos** | 15/nov/2026 | Confirmada |
| D-ING-3 | Pidió **las tres vías de audio** (voz del dispositivo, modelo descargable y audio pregrabado) y **empezar también el motor de voz de GRAVITY** | 16/nov/2026 | Confirmada. Ver fase 3 y anexo F |
| D-ING-4 | **Sí, por muestras** | 15/nov/2026 | Confirmada |
| D-ING-5 | **Sí, 12 preguntas por nivel** | 16/nov/2026 | Confirmada |
| D-ING-6 | **Promedio de 80 % y «gramática del tema» en 3 o más**; en las pruebas objetivas, 10 preguntas o más por habilidad | 16/nov/2026 | Confirmada |
| D-ING-7 y 8 | Todavía no se le han presentado | | Pendientes |

## 5. Cómo se ejecuta con Sonnet

### 5.1 Quién hace qué

| Agente | En este bloque | Carpetas para este bloque |
|---|---|---|
| **arquitecto** | Orquesta, lanza paquetes, integra, corre todas las pruebas, hace commit, mantiene este plan, el roadmap y las habilidades | Todo (integración), `.claude/skills/` |
| **habitos** | Formato, herramienta, contenido, dominio y pantallas de inglés | `data/ingles/`, `herramientas/ingles/`, `docs/contenido/ingles/`, `docs/specs/fase-8-habitos-*`, `docs/specs/fase-8-ingles-formato.md`, `paquetes/habitos_dominio/`, `app/lib/modulos/habitos/` |
| **calidad** | Resolución a ciegas, muestreo y revisión de cierre | `docs/revisiones/` (las respuestas a ciegas van en `docs/revisiones/ingles/`) y pruebas en `test/` |
| **backend** | Tablas `ing_*`, reglas por persona y pruebas SQL | `supabase/` |
| **plataforma** | Recursos de la app, cola sin conexión, recordatorio, paquete de voz y permisos | Las suyas |
| **diseno** | Componentes del submódulo `ingles` | Las suyas |
| **asistente** | Herramientas de GRAVITY y OpenAPI de lo nuevo | Las suyas |

Todos los agentes ya están fijados en Sonnet 5.5 en su definición. La sesión que orquesta también puede ser Sonnet: este plan convierte cada juicio en una regla o en una comprobación, para no depender de un modelo más fuerte.

### 5.2 Forma de un paquete

- Un paquete cabe en una sola corrida de un agente: una semana de curso (5 sesiones), una parte de un examen (hasta 12 unidades) o un módulo de código con sus pruebas. Si no cabe, se parte.
- Todo paquete de contenido recorre el mismo camino: **autor → `validar` → cuaderno → revisor a ciegas → `comparar` → correcciones → integración**.
- Un commit por paquete, hecho por el arquitecto.
- **Patrón antes que serie.** Ninguna parte de examen ni tipo de sesión se produce en serie sin un ejemplo patrón. Si falta (la lista está en la sección 12 del formato), el primer paquete de esa parte entrega **una sola** unidad candidata, que resuelven a ciegas dos agentes y revisa el arquitecto; solo después se escriben las demás. Un modelo imita mejor un buen ejemplo que una regla.

### 5.3 Encargo tipo

```
Ejecuta el paquete <ID> del plan de inglés.

Lee primero, en este orden:
1. CLAUDE.md y docs/ROADMAP.md, sección 11.1.
2. docs/specs/fase-8-ingles-plan.md: secciones 2 y 5, y la ficha del paquete <ID>.
3. docs/specs/fase-8-ingles-formato.md.
4. <entradas propias del paquete>.

Tus carpetas para este paquete: <lista>. No escribas fuera de ellas.
Entregables: <lista>.
Hecho cuando: <comandos y resultado esperado>.
No hagas commit. No cambies decisiones: si te falta una, detente y dilo en el reporte.
Reporte: el de la sección 5.4 del plan.
```

**El revisor a ciegas no necesita abrir ningún archivo.** Recibe el cuaderno dentro del encargo y devuelve sus respuestas dentro del reporte, en un bloque YAML con la forma de la sección 9 del formato; el arquitecto las guarda en `docs/revisiones/ingles/`. El encargo le prohíbe leer `data/ingles/` y cualquier clave exportada. Para que eso no dependa solo de su palabra, se lanza en un árbol de trabajo aislado (opción `isolation: worktree` al lanzar el agente), donde las unidades nuevas no existen. **Nunca se le da una ruta:** en la primera corrida el árbol aislado no contenía el cuaderno, el agente salió a buscarlo al árbol principal y el aislamiento dejó de servir. El reporte del revisor debe decir qué archivos abrió.

### 5.4 Reporte de cada agente

1. Qué hizo, en tres líneas.
2. Archivos creados o cambiados.
3. Comandos corridos y su salida final, pegada tal cual.
4. Conteos: unidades, preguntas, palabras por estímulo, minutos estimados (salida de `informe`).
5. Lo que no pudo hacer y por qué.
6. Preguntas para el dueño.

### 5.5 Hecho cuando

| Tipo de paquete | Condiciones |
|---|---|
| Contenido | `validar` sin errores · revisión a ciegas sin disputas abiertas · sin duplicados (V19, V20) · reporte con la salida de `informe` · ningún estado escrito a mano por encima de `validado` |
| Herramienta | `dart analyze` sin problemas · `dart test` en verde, con al menos un caso malo por cada comprobación · los ejemplos patrón pasan |
| App | `flutter analyze` sin errores · `flutter test --exclude-tags hallazgo` en verde · pruebas nuevas para cada criterio de la especificación |
| Servidor | Migraciones aplican en limpio · `bash supabase/tests/correr.sh` en verde |
| Cierre de fase | Revisión de calidad en `docs/revisiones/` sin bloqueantes abiertos |

Flutter y Dart están en `/home/user/tools/flutter/bin`.

### 5.6 Reglas que salen de los errores de esta etapa

1. **No afirmes sin respaldo.** "Verificado" lleva la página del manual o el comando. Si no pudiste comprobar algo, se queda como pendiente.
2. **No edites contenido con expresiones regulares.** Se edita la fuente, se valida y se exporta. Dos correcciones masivas sobre Markdown dejaron archivos inconsistentes.
3. **No escribas letras de respuesta.** La correcta es la primera opción de la fuente; el sorteo es de la herramienta.
4. **Si una pregunta se puede discutir, está mal.** Ante una disputa no se argumenta: se reescribe o se retira.
5. **Distractores plausibles.** Cada opción incorrecta es la respuesta correcta a una pregunta parecida o un error típico del nivel. Nunca una frase absurda.
6. **Huecos abiertos: palabras gramaticales y todas las respuestas válidas.** Si caben más de tres palabras de contenido, el hueco está mal elegido.
7. **Nada se usa dos veces.** Ni entre formas, ni entre práctica y forma, ni entre ubicación y lo demás.
8. **Longitud del contrato o etiqueta de reducido.** No hay término medio.
9. **Lo generado no se toca.** Si el cuaderno está mal, se corrige la fuente.
10. **Si falta una decisión del dueño, el paquete se detiene.** No se asume.
11. **El revisor no ve la clave.** Y el autor no resuelve su propia prueba.
12. **Si el contenido cambia después de la revisión, la revisión caduca.** Lo detecta la huella.

### 5.7 Paralelismo e integración

- Hasta 4 agentes a la vez, siempre en carpetas distintas.
- Los subpaquetes de la herramienta van en serie. Las semanas del curso y las partes de un examen pueden ir en paralelo.
- Al integrar, el arquitecto corre `validar` sobre todo `data/ingles` (los duplicados solo se ven en conjunto), la suite de la app si hubo código, y actualiza el estado en este plan.
- Si un paquete falla dos veces su condición de hecho, no se intenta una tercera: el arquitecto revisa el encargo.

## 6. Fases y paquetes

### Resumen

| Fase | Para qué | Paquetes | Necesita del dueño |
|---|---|---|---|
| 0 · Orden y decisiones | Dejar de afirmar lo que no es cierto y destrabar decisiones | P0.1 a P0.4 | D-ING-7 y 8 (las otras seis, confirmadas) |
| 1 · Rieles | Formato, contratos, herramienta, niveles, revisión a ciegas y piloto | P1.1 a P1.5 | Aprobar el piloto |
| 2 · Ubicación y núcleo en la app | Ubicarse una vez y estudiar la sesión del día | P2.1 a P2.6 | Proyecto de Supabase (pendiente desde la Fase 0) |
| 3 · Audio y habla | Escuchar de verdad (la ubicación lo necesita); motor de voz de GRAVITY; traslado solo con audio; grabarse | P3.0 a P3.3 | Elegir de oído en el teléfono |
| 4 · Curso por escalones | Producir el curso, siempre dos semanas por delante de quien estudia | Por semana | Muestreo |
| 5 · Exámenes | Formas con fidelidad completa y semáforo | Por examen y parte | Muestreo |
| 6 · Pareja y extras | Estudiar juntos, revisión cruzada, IA opcional | Por definir | Especificación propia |

### Fase 0 · Orden y decisiones

**P0.1 · Etiquetas honestas** · habitos · **hecho el 15/nov/2026** por la sesión que integra
- Entradas: revisión ING-B1 e ING-B5.
- Hace: en el bloque de contexto de cada simulacro y de cada práctica, cambia "completo" por "formato reducido: mismo número de preguntas, textos más cortos y sin audio". En `prueba-de-nivel.md` añade "en revisión: no usar para decidir el nivel". Corrige ING-M4. No toca preguntas.
- Hecho cuando: ningún encabezado de `docs/contenido/ingles/` afirma formato completo; el aviso está en la prueba y en la página publicada.

**P0.2 · Decisiones del dueño** · arquitecto
- Hace: recoge las respuestas de la sección 4, las registra aquí y en `docs/DECISIONES.md` (D29) y ajusta el resto del plan.

**P0.3 · Especificación v0.5 del bloque** · habitos (redacta), arquitecto (integra) · depende de P0.2
- Hace: reescribe el bloque 5 de `docs/specs/fase-8-habitos-ampliaciones.md` en sub-bloques (5a núcleo en la app, 5b audio y habla, 5c ubicación, 5d exámenes, 5e pareja). Resuelve las contradicciones de ING-I7, fija el modelo de datos `ing_*`, numera los criterios de aceptación y deja una sola numeración de semanas (1 a 8 dentro de cada escalón).
- Hecho cuando: cada criterio se puede probar; calidad no encuentra contradicciones con `DECISIONES.md`.

**P0.4 · Ramas** · arquitecto · depende de D-ING-8
- Hace: borra las dos ramas indicadas y, cuando el dueño lo pida, abre el pull request a `main`.

### Fase 1 · Rieles

**P1.1 · Contratos de formato** · habitos · dos subpaquetes
- Entradas: manuales oficiales citados en `formatos-oficiales.md`, más el manual de A2 Key. Se descargan a una carpeta temporal fuera del repositorio; no se suben ni se copian sus preguntas.
- P1.1a (no espera decisiones): contratos de los exámenes oficiales en `data/ingles/formatos/`: `cambridge-a2-key`, `cambridge-b1-preliminary`, `cambridge-b2-first`, `toeic-lr`, `toeic-sw` y `toefl-ibt-2026`. Cada dato con la página del manual. Si el manual declara la longitud de un texto, se usa esa cifra; si no, se mide en su prueba de muestra y se anota la medida. Lo que no se pueda leer queda como pendiente; no se completa de memoria.
- P1.1b (depende de D-ING-1, D-ING-2 y D-ING-5): contratos propios `gravity-sesion-60`, `gravity-ubicacion` y `gravity-escalon`, con los mínimos por bloque de la sección 7 del formato y las reglas de la sección 3.3 de este plan.
- Hecho cuando: `validar data/ingles/formatos` sin errores (mientras no exista la herramienta: los archivos se leen como YAML y el arquitecto los revisa) y calidad contrasta 10 datos al azar de cada contrato oficial con el PDF.

**P1.2 · Herramienta `herramientas/ingles`** · habitos · tres subpaquetes en serie
- P1.2a: modelo, lectura de YAML, comprobaciones V01 a V14 (salvo V06, que pertenece a `exportar`) y estados básicos (V24), orden `validar`. No espera a P1.1 ni a P1.3: se prueba con contratos y niveles de prueba guardados en `herramientas/ingles/test/`, escritos según las secciones 6 y 8 del formato. Si falta el contrato de una unidad o `data/ingles/niveles.yaml`, `validar` lo dice ("sin contrato", "sin niveles") y no inventa ninguno: es aviso en un archivo en `borrador` y error de `validado` en adelante.
- P1.2b: contratos y fidelidad (V15 a V20), orden `informe`. Necesita P1.1a integrado.
- P1.2c: `exportar` con sorteo (V06, V26), `comparar` con huella (V24), sesiones (V21 a V23) y `compilar` (V25). Los mínimos de la sesión se leen del contrato `gravity-sesion-60` (P1.1b), no del código. Al terminar, se borra `herramientas/ingles/transitorio/`, que solo existe para generar cuadernos mientras falta `exportar`.
- Hecho cuando: lo de "Herramienta" en 5.5, y `README.md` con todas las órdenes. Los ejemplos patrón pasan V01 a V14 al cerrar P1.2a y todas las comprobaciones al cerrar P1.2c. Si un ejemplo no pasa, el agente lo reporta: se corrige el ejemplo o la regla con el arquitecto, nunca se relaja una comprobación en silencio.

**P1.3 · Matriz de niveles** · habitos; revisa calidad · depende de D-ING-1
- Hace: `data/ingles/niveles.yaml` con los 13 escalones (gramática, funciones, vocabulario y descriptores "puedo" por habilidad), las listas controladas, y `niveles-y-avance.md` en versión 0.4 con la escalera, la puerta anticipada y el descenso.
- Hecho cuando: cada tema de gramática es "nuevo" en un solo escalón; cada escalón tiene descriptores para las cuatro habilidades; calidad contrasta 10 temas al azar con el manual del examen de su etapa.

**P1.4 · Revisión a ciegas y habilidades** · calidad (protocolo), arquitecto (habilidades) · dos subpaquetes
- P1.4a (no espera a la herramienta): calidad resuelve a ciegas los ejemplos patrón objetivos, a partir del cuaderno `docs/contenido/ingles/generado/cuaderno-ejemplos-patron.md`, que no trae respuestas ni explicaciones. El arquitecto compara a mano; cada disputa corrige el ejemplo antes de que nadie lo imite. Los ejemplos los escribió la sesión que hizo este plan, así que también a ellos les toca el principio 5. El arquitecto crea la habilidad `leccion-idioma` (cómo redactar una sesión), junto a `simulacro-examen-idioma`, ya actualizada.
- P1.4b (depende de P1.2c): la misma corrida de punta a punta, ahora con la herramienta (`exportar`, resolver, `comparar`).
- Hecho cuando: (a) ningún ejemplo patrón tiene disputas abiertas y las respuestas quedan en `docs/revisiones/ingles/`; (b) `comparar` deja la revisión en `data/ingles/revisiones/` y detecta una disputa provocada a propósito.

**P1.5 · Piloto vertical** · habitos, calidad y dueño · depende de P1.1 a P1.4, D-ING-1, D-ING-2, D-ING-4 y D-ING-5
- Hace: (1) la semana 1 de B1.1 completa, con la plantilla de 60 minutos; (2) una unidad de Reading 3 y una de Listening 3 de B1 Preliminary con longitud oficial; (3) 12 preguntas de ubicación, 3 por etapa.
- Hecho cuando: todo en `revisado`; cuadernos exportados; el dueño aprueba la plantilla o pide cambios en una sola ronda.

### Fase 2 · Ubicación y núcleo en la app

**P2.1 · Prueba de ubicación, versión 3** · habitos; calidad resuelve a ciegas con dos agentes distintos · depende de P1.3 y P1.5
- Hace: banco de 72 preguntas (18 por etapa) y forma de 48, con el contrato `gravity-ubicacion`. Las de escucha llevan guion para el audio del dispositivo.
- Hecho cuando: las dos resoluciones a ciegas coinciden con la clave en todas las preguntas; V20 sin errores.

**P2.2 · Servidor** · backend · depende de P0.3
- Hace: migración con las tablas `ing_*`, reglas por persona y pruebas SQL: otra persona no lee, la cuenta maestra no lee, una segunda ubicación se rechaza, no hay edición ni borrado en ubicación, sesiones y pruebas.

**P2.3 · Dominio** · habitos · depende de P0.3
- Hace: repaso espaciado, sesión completa y minutos, puertas (80 % por habilidad, dos oportunidades, días de gracia, 90 % de minutos), ubicación, puerta anticipada y descenso. Con pruebas de los casos límite.

**P2.4 · Pantallas y plataforma** · habitos, diseno y plataforma · depende de P2.2, P2.3 y `compilar`; la pantalla de Ubicación, además, de P3.2a
- Hace: Inicio de inglés, Ubicación (se puede pausar y reanudar, no reiniciar), Sesión del día, Tarjetas y Progreso. Recursos en `app/assets/ingles/`, cola sin conexión y recordatorio local discreto. Sin audio, el traslado aparece como "disponible cuando haya audio" y no cuenta minutos, y la Ubicación no se ofrece: la pantalla explica cómo instalar una voz en inglés.

**P2.5 · Herramientas y API** · asistente
- Hace: `habitos.ingles_hoy`, navegación y OpenAPI de lo nuevo.

**P2.6 · Revisión de calidad de la fase** · calidad
- Revisa: privacidad (Hábitos es personal), reglas por persona, una sola ubicación, estudio sin red y accesibilidad.

### Fase 3 · Audio y habla · D-ING-3 confirmada (16/nov/2026)

El dueño pidió **las tres vías de audio** (voz del dispositivo, modelo de voz descargable y audio pregrabado) y **empezar también el motor de voz de GRAVITY**: un solo componente de voz para el curso, el asistente y, si D6 se confirma, las bocinas. La app ya define la interfaz `VozSalida` en `app/lib/modulos/gravity/conversacion/voz.dart`, sin implementación (hoy solo dicta, con `speech_to_text`). Las bocinas hablan por el servicio de texto a voz de Home Assistant (`puente_casa.dart`). El motor implementa `VozSalida` una vez y el curso la usa.

El reproductor y el motor (P3.0 a P3.3) están en la ruta crítica: la ubicación lleva escucha y no se abre sin ellos. Se construyen en paralelo con la fase 2, no después.

- **P3.0 · Especificación del motor de voz de GRAVITY** · asistente (redacta), con plataforma y habitos (revisan): `docs/specs/fase-8-motor-de-voz.md`. Trae: la interfaz ampliada (varias voces con nombre, velocidad, parar, avance), las tres fuentes y cómo elegir entre ellas, la gestión de modelos descargables (tamaño visible, descarga solo con aviso, borrar, comprobación de integridad, registro de la licencia de cada voz), las reglas de D3 y D6 (al motor solo llega texto ya filtrado) y los paquetes que el dueño tiene que aprobar. Lo que no se puede verificar sin red (tamaño y licencia de cada voz, calidad, velocidad en el Galaxy A52) queda como lista de pendientes, con la forma de verificarlo.
- **P3.1 · Especificación del reproductor del curso** · habitos y plataforma: reproducciones según contrato, velocidad 0.8 y 1.0, guion oculto hasta contestar y grabación local. Usa el motor de P3.0.
- **P3.2a · Reproductor y motor** · plataforma (paquetes y permisos), asistente (motor) y habitos (bloque de escucha), con una fuente simulada para las pruebas. Primero la voz del dispositivo; el modelo descargable y el audio pregrabado entran detrás de la misma interfaz.
- **P3.2b · Repetición, traslado y grabación** · habitos y plataforma: repetir frases, traslado solo con audio y grabación local para el habla.
- **P3.3 · Prueba en el teléfono** · dueño: comparar las tres vías con la misma frase del curso en el Galaxy A52 y en Windows, y elegir de oído. Se hace en cuanto exista P3.2a y antes de producir muchos guiones.

### Fase 4 · Curso por escalones · depende de aprobar el piloto

- **Unidad de trabajo:** una semana. El autor (habitos) entrega 5 sesiones, los 2 audios de traslado, 32 tarjetas y la mini prueba, siguiendo el ejemplo `sesion-b1-1-s01-lun-ejemplo.yaml`. El revisor (calidad) la resuelve a ciegas.
- **Por escalón:** 8 semanas más su puerta, con tres formas (dos oportunidades y una reserva).
- **Orden inicial** (a confirmar con D-ING-7): B1.1, A2.1, B1.2, A2.2, B1.3, A2.3, B1.4, A1.1, A1.2, B2.1 a B2.4. Tras la ubicación real del dueño y de su pareja, sube al frente el escalón donde caiga cada uno.
- **Ritmo:** el contenido va dos semanas por delante de quien estudia. No hace falta terminar el curso para empezar a usarlo.
- **Semillas:** los módulos 1 y 2 aprobados dan los temas de B1.1; el 3 y el 4, de B1.2.

### Fase 5 · Exámenes · depende de la fase 1

Cuatro pasos por examen, cada uno por partes:
1. **Triaje** de lo que existe: cada pregunta se conserva, se corrige o se descarta al pasarla a unidades (sección 7).
2. **Banco por parte** con la longitud del contrato.
3. **Dos formas completas y una de reserva**, que no comparten nada entre sí ni con el banco de práctica.
4. **Práctica por partes** generada desde el banco.

Orden: B1 Preliminary (también es la puerta de B1), A2 Key (puerta de A2), TOEIC Listening y Reading, B2 First (puerta de B2), TOEFL iBT 2026, TOEIC Speaking y Writing.

### Fase 6 · Pareja y extras

Especificación primero: emparejamiento por escalón, actividades en pareja, revisión cruzada de habla y escritura con lista de cotejo, y qué ve cada quien del otro, con consentimiento. La corrección con IA es opcional y posterior; no toca dinero ni datos clínicos, pero necesita su propia especificación.

## 7. Qué pasa con lo que ya existe

| Documento | Destino |
|---|---|
| `modulo-1.md`, `modulo-2.md` (aprobados) | Semilla de temas de B1.1. Se conservan como historial; el contenido ampliado vive en `data/ingles/curso/b1-1/` |
| `modulo-3.md`, `modulo-4.md` | Semilla de B1.2. Con D-ING-4 no necesitan aprobación por separado |
| `prueba-de-nivel.md` y `prueba-ubicacion.html` | Aviso de "en revisión" (P0.1). Se retiran al publicar la versión 3 (P2.1) |
| `rubrica-evaluacion.md` | Se conserva. Se ajusta con D-ING-6 y da origen a las listas de cotejo |
| `niveles-y-avance.md` | Versión 0.4 con la escalera (P1.3) |
| `formatos-oficiales.md` | Su contenido pasa a los contratos (P1.1) |
| B1 Preliminary A y B | Sus preguntas válidas pasan al banco como práctica reducida. Las formas completas se escriben nuevas |
| B2 First A y B | Partes 2, 3 y 6 se rehacen. Partes 1, 4, 5 y 7 se corrigen; por su dificultad sirven como práctica de B1 |
| TOEIC completo | Partes 1, 2 y 5 se conservan. Partes 3, 4, 6 y 7 se amplían a la longitud del contrato. Se eliminan las 41 oraciones repetidas con `toeic-bimestre-2.md` |
| TOEFL A y B | "Completar palabras" se rehace con texto. El resto se reorganiza en conjuntos de 2 y 3 y se reescriben los distractores absurdos |
| Prácticas por partes (cinco documentos) | Se regeneran desde el banco. Hasta entonces quedan como reducidas |
| `guia-multiexamen.md`, `cambridge-y-toefl.md`, `toeic.md`, `simulacros/bimestre-3.md`, `cobertura-practica.md` | Los sustituyen la especificación v0.5 y el `informe` de la herramienta. Se archivan |

## 8. Orden y primer lote

**Ruta crítica hasta el primer uso real** (el dueño y su pareja se ubican en la app y empiezan su escalón):

```
D-ING-1,2,4,5 ─► P1.1b y P1.3 ─► P1.5 (piloto) ─► P2.1 (ubicación) ────┐
P1.1a y P1.2a ─► P1.2b ─► P1.2c ─► P1.4b ──────────────────────────────┤
P0.2 ─► P0.3 ─► P2.2 (servidor) y P2.3 (dominio) ──────────────────────┼─► P2.4 (pantallas) ─► primer uso
D-ING-3 ─► P3.1 ─► P3.2a (reproductor) ─► P3.3 (prueba en el teléfono) ┘
En paralelo: fase 4 (primeras dos semanas de B1.1 y de A2.1)
```

El piloto (P1.5) necesita además la herramienta completa (P1.2c) y la revisión a ciegas probada (P1.4b).

**Primer lote: hecho** (15/nov/2026): P0.1, P1.1a, P1.2a y P1.4a. Sus encargos están en el anexo D.
**Puede salir ya, con D-ING-2 y 4 confirmadas:** P1.2b (comprobaciones de longitud, fidelidad y duplicados, y el informe). Solo necesita lo que ya existe.
**Ya pueden salir** (D-ING-1 a 6 confirmadas): P1.1b (contratos propios), P1.3 (matriz de niveles), P0.3 (especificación v0.5 del bloque) y P3.0 (motor de voz).
**Después:** P1.2c (necesita P1.1b), P1.4b (necesita P1.2c), P2.x (necesitan P0.3 y P1.x) y, al final, P1.5.
**Espera D-ING-8:** P0.4 (ramas).
**Espera D-ING-7:** el orden de producción de la fase 4 y de los exámenes de la fase 5.

## 9. Riesgos

| Riesgo | Cómo se controla |
|---|---|
| El volumen es grande: 13 escalones y 6 exámenes | Producir por delante de quien estudia, no todo antes de empezar. Priorizar por la ubicación real |
| Preguntas de B2 escritas por agentes | Ejemplos patrón, resolución a ciegas doble en ubicación y puertas, muestreo del dueño con el cuaderno |
| La voz del dispositivo suena mal o no está instalada | Interfaz de fuente de audio y verificación temprana (P3.3). Hay modelos de voz descargables como alternativa (anexo F) |
| Los revisores a ciegas son del mismo modelo y comparten puntos ciegos | Muestreo del dueño (D-ING-4), puerta de etapa con formato oficial y, antes de cualquier uso oficial, una revisión humana de las puertas |
| No hay población para calibrar la dificultad | Zonas en lugar de puntajes; ubicación corregida con evidencia; registro de aciertos por pregunta para retirar las que fallen sin razón |
| La especificación de TOEFL 2026 puede cambiar | Contrato con fecha de consulta; se revisa antes de producir sus formas |
| El dueño como cuello de botella | D-ING-4 |
| Documentos que se contradicen | Una fuente y un informe generado |
| Derechos de autor | Todo el contenido es propio. Los contratos citan la página del manual; no copian texto |

## 10. Cuándo se da por cerrado el bloque

- `validar` sin errores en todo `data/ingles`.
- Toda pregunta objetiva que llega a la app tiene revisión a ciegas vigente.
- Ningún duplicado entre formas ni entre ubicación, puertas y práctica.
- Toda forma dice su fidelidad, calculada por la herramienta.
- Toda sesión estima entre 54 y 66 minutos.
- Una sola ubicación por persona, comprobada en el servidor.
- Suites de la app, del dominio y del servidor en verde, y revisión de calidad sin bloqueantes.

## Anexo A. Estado de los paquetes

| Paquete | Estado | Nota |
|---|---|---|
| Revisión del bloque | Hecho (14/nov/2026) | `docs/revisiones/fase-8-ingles.md` |
| Formato `gravity-ingles-v1` | Propuesto (versión 0.3, 16/nov/2026) | `docs/specs/fase-8-ingles-formato.md`. La 0.3 recoge lo que encontró el validador |
| Ejemplos patrón | Escritos (15/nov/2026), en `borrador` | Nueve archivos en `data/ingles/ejemplos/`, descritos en la sección 12 del formato. Los resuelve a ciegas P1.4a |
| Cuaderno a ciegas de los ejemplos | Generado (15/nov/2026) | `docs/contenido/ingles/generado/cuaderno-ejemplos-patron.md`, 40 preguntas sin respuestas. Lo genera `herramientas/ingles/transitorio/cuaderno_ejemplos.py` mientras no exista `exportar` |
| Habilidad `simulacro-examen-idioma` | Actualizada y versionada (15/nov/2026) | Con las reglas de 5.6. Antes no estaba en git |
| P0.1 Etiquetas honestas | Hecho (15/nov/2026) | 25 documentos y la página de ubicación, tanto la copia del repositorio como la publicada (versión 4). No se tocó ninguna pregunta |
| P1.1a Contratos de exámenes | Hecho (15/nov/2026), en `borrador` | Seis contratos en `data/ingles/formatos/`, cada dato con su página. Quedan 24 datos pendientes, casi todos de TOEIC y TOEFL, porque sus manuales traen pocas muestras. Falta el contraste de calidad (10 datos por contrato) |
| P1.4a Revisión a ciegas de los ejemplos | Hecho (15/nov/2026), tres rondas | La respuesta principal coincide con la clave en 40, 40 y 31 preguntas. Segundas respuestas defendibles: 6, 2 y 0, todas reescritas. Detalle en `docs/revisiones/ingles/`. Los ejemplos siguen en `borrador` hasta que existan `niveles.yaml` y el contrato de sesión |
| Habilidad `leccion-idioma` | Creada (15/nov/2026) | `.claude/skills/leccion-idioma/`. Propuesta hasta la decisión D-ING-2 |
| P1.2a Validador | Hecho (15/nov/2026) | `herramientas/ingles`: orden `validar` con V01 a V14 (sin V06) y la parte de V24 que no depende de revisiones. 169 pruebas en verde, 0 errores sobre `data/ingles`. Lo escribió el agente `habitos` con autorización expresa del dueño; al integrar se sembraron siete defectos en una copia y los detectó todos. Sus 12 hallazgos están resueltos en el formato 0.3 o asignados a P1.1b, P1.2b, P1.2c y P1.3 |
| P0.2 Decisiones del dueño | Hecho (16/nov/2026) | Registradas en 4.1 y en `docs/DECISIONES.md` (D29). Se ajustó el plan a 13 escalones |
| P1.2b Longitud, fidelidad, duplicados e informe | Hecho (16/nov/2026) | V15 a V20, fidelidad por forma y orden `informe`. 371 pruebas en verde. Al integrar se sembraron defectos y V17 no detectó un español hecho de palabras de contenido: se le agregó una segunda señal (tildes) con cinco pruebas |
| P0.3, P0.4, P1.1b, P1.2c, P1.3, P3.0 en adelante | Pendientes | P0.3, P1.1b, P1.3 y P3.0 pueden salir ya. P0.4 espera D-ING-8 y la fase 5, D-ING-7 |

## Anexo B. Temario por escalón (propuesta para P1.3; el reparto de A2.2 y A2.3 y de B1.3 y B1.4 es mío y P1.3 lo ajusta con el manual del examen de la etapa)

| Escalón | Gramática nueva | Puedo… | Origen |
|---|---|---|---|
| A1.1 | *to be*, pronombres, *a / an / the*, plurales, *this / that*, posesivos, *there is / are*, presente simple en afirmativa; números, horas y fechas | Presentarme y hablar de mi familia y mis cosas | Repaso R1 |
| A1.2 | Presente simple en negativa y pregunta, adverbios de frecuencia, *can*, *like + -ing*, imperativos, preposiciones de lugar y tiempo, *some / any* | Describir mi día y pedir datos simples | Repaso R2 |
| A2.1 | Presente simple y continuo, pasado simple, *was / were*, contables e incontables, comparativos y superlativos, *going to* | Contar lo que hice, comparar y hablar de planes | Repaso R3 |
| A2.2 | Presente perfecto (experiencias; *just, already, yet*), *will*, *have to / must / should* | Contar experiencias, dar consejos y predecir | Repaso R4 |
| A2.3 | Pasado continuo, primera condicional (inicio), *too / enough*, relativos (inicio) y repaso para la puerta | Contar lo que pasaba y plantear condiciones simples. **Puerta A2** | Nuevo: P1.3 lo define |
| B1.1 | Presentes a fondo (estado y acción, situaciones temporales), pasado simple y continuo, presente perfecto frente a pasado simple, *for / since*, *used to*, preguntas de sujeto | Describir rutinas, salud y experiencias con detalle | Módulos 1 y 2 |
| B1.2 | Futuros (*will*, *going to*, presente continuo, oraciones de tiempo), primera condicional, modales de obligación, consejo, permiso y habilidad, preguntas indirectas, verbo + *-ing* o infinitivo, correos de trabajo | Explicar planes y metas; resolver situaciones de trabajo | Módulos 3 y 4 |
| B1.3 | Comparaciones (*as… as*, *much / far*), pasiva en presente y pasado, segunda condicional | Comparar, describir procesos y hablar de situaciones imaginarias | Módulos 5 y 6 |
| B1.4 | Pasado perfecto, estilo indirecto, relativas, verbos frasales frecuentes y repaso para la puerta | Opinar y defender una idea; contar una historia de dos minutos. **Puerta B1** | Módulos 5 y 6, y nuevo |
| B2.1 | Presente perfecto continuo, tiempos narrativos, futuro continuo y perfecto, *used to / would / be used to* | Narrar con matices; hablar de cambios y tendencias | Nuevo |
| B2.2 | Modales de deducción en presente y pasado, tercera condicional y mixtas, *wish / if only* | Especular, lamentar y plantear hipótesis | Nuevo |
| B2.3 | Pasiva avanzada (*have something done*, pasiva con verbos de opinión), gerundios e infinitivos, verbos de reporte, relativas y participios | Informar, reportar y describir procesos | Nuevo |
| B2.4 | Conectores de contraste, causa y propósito; énfasis (*what I need is…*); formación de palabras; colocaciones y verbos frasales por tema | Argumentar por escrito (ensayo, informe, reseña) y en debate. **Puerta B2** | Nuevo |

## Anexo C. Qué cambió en la versión 0.2

1. **Dependencias corregidas.** En la 0.1, el primer lote incluía trabajo que sí dependía de decisiones o de la herramienta: los contratos propios y la corrida de punta a punta de la revisión a ciegas. Ahora P1.1 y P1.4 se parten en a y b, y el segundo lote pide también D-ING-5.
2. **Ubicación.** Tabla de entrada por resultado, incluido quien alcanza B2. Margen de error calculado. El audio entra en la ruta crítica, porque la ubicación lleva escucha y es única.
3. **Revisor a ciegas aislado** (5.3): recibe el cuaderno en el encargo, devuelve las respuestas en el reporte y trabaja en un árbol aislado.
4. **Patrón antes que serie** (5.2), y dos ejemplos patrón más: transformaciones y oraciones omitidas de B2 First.
5. **P1.2a** ya no espera contratos ni niveles: usa archivos de prueba y avisa cuando faltan.
6. **P0.1 hecho.**
7. **Anexo D:** encargos del primer lote, listos para lanzar.

**Lo que enseñó la primera corrida (15/nov/2026):**
- Medir con página corrige al que escribió de memoria: los contratos bajaron tres cifras de la revisión (el guion de Listening se había contado con el narrador; el texto de Reading 3 de B1 mide 352 palabras, no 390; las muestras de TOEIC son más cortas).
- La revisión a ciegas encuentra lo que el autor no ve: seis preguntas de los ejemplos patrón admitían una segunda respuesta.
- Dos recursos cierran casi todas las disputas de respuesta abierta: que la respuesta ocupe ya el máximo de palabras, y dejar fuera del hueco la palabra que admite sinónimos.
- Al revisor no se le dan rutas (5.3).

## Anexo D. Encargos del primer lote

Los tres se pueden lanzar a la vez: escriben en carpetas distintas. Cada bloque se pasa tal cual al agente indicado.

### D.1 · P1.1a · agente `habitos`

```
Ejecuta el paquete P1.1a del plan de inglés: contratos de los exámenes oficiales.

Lee primero, en este orden:
1. CLAUDE.md y docs/ROADMAP.md, sección 11.1.
2. docs/specs/fase-8-ingles-plan.md: secciones 2 y 5, y la ficha de P1.1.
3. docs/specs/fase-8-ingles-formato.md: secciones 3, 4.2 y 6.
4. docs/contenido/ingles/formatos-oficiales.md: enlaces a los manuales y lo ya verificado.

Tu carpeta para este paquete: data/ingles/formatos/. No escribas fuera de ella.

Entregables: seis archivos YAML, uno por examen: cambridge-a2-key, cambridge-b1-preliminary,
cambridge-b2-first, toeic-lr, toeic-sw y toefl-ibt-2026. Cada uno con todas sus secciones y
partes. En cada parte: tarea, tipo_pregunta (uno de la tabla 4.2 del formato), unidades,
preguntas_por_unidad, opciones, reproducciones si es de escucha, palabras_estimulo {min, max}
y pagina_manual.

Cómo:
- Descarga cada manual desde www.cambridgeenglish.org o www.ets.org a una carpeta temporal
  fuera del repositorio. Son los únicos dominios permitidos. El de A2 Key está en
  https://www.cambridgeenglish.org/Images/504505-a2-key-handbook-2020.pdf; los demás, en
  formatos-oficiales.md y en el encabezado de los simulacros.
- Si un manual no se puede descargar o un dato no aparece, no lo completes de memoria:
  marca el dato con pendiente: true y dilo en el reporte.
- palabras_estimulo: si el manual declara la longitud, usa esa cifra. Si no, cuenta las
  palabras del texto o del guion de esa parte en la prueba de muestra del manual, guarda la
  medida en un campo medido y fija el rango en la medida menos 15 % y más 15 %, redondeado
  a decenas.
- No copies al repositorio ninguna pregunta ni texto del manual: solo números, nombres de
  parte y páginas.
- Todos los archivos quedan en estado: borrador.

Hecho cuando:
- Los seis archivos se leen como YAML sin errores.
- Cada parte tiene pagina_manual, o pendiente: true con su explicación en el reporte.
- El total de preguntas de cada contrato coincide con formatos-oficiales.md. Si no coincide,
  explícalo en el reporte con la página del manual.

No hagas commit. No cambies decisiones: si te falta una, detente y dilo en el reporte.
Reporte: el de la sección 5.4 del plan, más una tabla por examen con parte, preguntas,
palabras medidas y página.
```

### D.2 · P1.2a · agente `habitos` (otra instancia)

```
Ejecuta el paquete P1.2a del plan de inglés: primera parte de la herramienta herramientas/ingles.

Lee primero, en este orden:
1. CLAUDE.md y docs/ROADMAP.md, sección 11.1.
2. docs/specs/fase-8-ingles-plan.md: secciones 2 y 5, y la ficha de P1.2.
3. docs/specs/fase-8-ingles-formato.md completo. Las comprobaciones están en la sección 11.
4. herramientas/biblia (misma forma de paquete) y los nueve archivos de data/ingles/ejemplos/.

Tu carpeta para este paquete: herramientas/ingles/. No escribas fuera de ella y no toques
herramientas/ingles/transitorio/.

Entregables:
- Paquete Dart con bin/ingles.dart, lib/, test/, pubspec.yaml, analysis_options.yaml y
  README.md. Única dependencia nueva permitida: yaml.
- Orden validar [ruta]: lee los YAML de la ruta (por defecto, data/ingles), aplica V01 a V14
  salvo V06, y la parte de V24 que no depende de revisiones (un archivo en validado no puede
  tener errores). Imprime una línea por hallazgo (archivo, código, error o aviso, mensaje en
  español) y un resumen. Sale con 1 si hay errores.
- Contratos y niveles de prueba dentro de test/, escritos según las secciones 6 y 8 del formato.
- Pruebas: por cada comprobación, al menos un caso bueno y un caso malo. El caso malo se
  construye en la prueba a partir de un caso bueno, cambiando un solo dato.

Reglas:
- Si falta el contrato de una unidad o data/ingles/niveles.yaml, validar avisa ("sin contrato",
  "sin niveles") y sigue. Es aviso en borrador y error de validado en adelante. No crees esos
  archivos en data/ingles.
- No cambies los ejemplos patrón. Si uno no pasa una comprobación, no relajes la comprobación:
  repórtalo con el archivo, el código y tu lectura de quién tiene razón.
- exportar, comparar, compilar e informe son de P1.2b y P1.2c. No las escribas ahora, pero
  deja el modelo listo para ellas.

Hecho cuando (desde herramientas/ingles, con /home/user/tools/flutter/bin en el PATH):
- dart analyze: sin problemas.
- dart test: todo en verde.
- dart run bin/ingles.dart validar ../../data/ingles/ejemplos: cero errores, o la lista de
  los que consideras defectos del ejemplo.

No hagas commit. No cambies decisiones: si te falta una, detente y dilo en el reporte.
Reporte: el de la sección 5.4 del plan, con la salida completa de los tres comandos.
```

### D.3 · P1.4a · agente `calidad`, en árbol aislado

Se lanza con `isolation: worktree`. Donde dice `<CUADERNO>` se pega completo el archivo `docs/contenido/ingles/generado/cuaderno-ejemplos-patron.md`; no se sustituye por su ruta (ver 5.3).

```
Vas a resolver a ciegas un cuaderno de preguntas de inglés. Tu trabajo es encontrar las
preguntas que están mal: las que tienen dos respuestas defendibles, ninguna, o una clave
que alguien podría discutir.

Reglas:
- No abras data/ingles/ ni ningún archivo del repositorio. No busques la clave. Todo lo que
  necesitas está abajo. Si aun así abres algo, anótalo en archivos_abiertos.
- Sigue las instrucciones del propio cuaderno. Contesta todo.
- En huecos abiertos, formación de palabras, transformaciones y respuestas cortas, escribe
  todas las respuestas que consideres válidas en inglés británico (Cambridge) o americano
  (TOEFL y curso), según indique cada unidad.
- En cada pregunta intenta defender una segunda respuesta. Si lo logras, anótala en
  otras_validas y explica por qué en nota. No seas indulgente: una pregunta discutible es un
  hallazgo, no un problema tuyo.
- En observaciones, di si el texto, el nivel o las instrucciones no corresponden al examen
  que la unidad dice imitar.

Entrega: un bloque YAML por unidad, con la forma que pide el cuaderno. No escribas archivos.

<CUADERNO>
```

### D.4 · Qué hace quien integra al recibir los reportes

1. Corre él mismo los comandos de "hecho cuando" de P1.1a y P1.2a. No da por bueno el reporte.
2. Guarda cada bloque de P1.4a en `docs/revisiones/ingles/<objeto>-calidad.yaml`.
3. Compara con la clave: `python3 herramientas/ingles/transitorio/cuaderno_ejemplos.py --clave`. En opción múltiple y en oraciones omitidas, la letra debe coincidir. En las demás, cada respuesta del revisor debe estar en `aceptadas`. Toda respuesta que no esté, y toda `otras_validas`, es una disputa.
4. Cada disputa se cierra de una de dos formas: se añade la respuesta a `aceptadas` si de verdad es válida, o se reescribe la pregunta para que deje de serlo. No se discute con el revisor. Después se genera el cuaderno otra vez y lo resuelve un agente distinto.
5. Un commit por paquete, y se actualiza el anexo A.

### Cambios de la versión 0.3 (16/nov/2026)

1. **Tres decisiones confirmadas** (4.1): D-ING-2, D-ING-3 en principio y D-ING-4. D-ING-1 espera la investigación de horas por nivel (anexo E).
2. **Investigación de cómo estructuran el avance** institutos y exámenes (anexo E) y respuesta sobre las voces descargables (anexo F).
3. **El primer lote terminó.** Lo que enseñó el validador está en el formato 0.3: `puntos_por_pregunta` puede ser rango, `palabras_respuesta` en las transformaciones, `clase` en los huecos abiertos, `nota` del audio para completar notas, unidades del contrato frente a archivos, y las contracciones.
4. **Riesgo nuevo:** los revisores a ciegas son del mismo modelo (sección 9).

## Anexo E. Cómo estructuran el avance los institutos y los exámenes

> Investigación del 16/nov/2026, a petición del dueño ("puedes investigar cómo están estructurados... Macmillan, Cambridge, TOEIC y TOEFL; tal vez son cumplir ciertas horas, para realizar un examen de avance de nivel").
> Marcas: **leído** = abrí el documento oficial; **resultado de búsqueda** = vi la cifra en un resumen de búsqueda sin abrir la página; **no confirmado** = no pude comprobarlo.

### E.1 Lo que se encontró

| Tema | Hallazgo | Fuente | Estado |
|---|---|---|---|
| Horas por nivel (Cambridge) | Horas guiadas acumuladas desde cero: A2 180 a 200, B1 350 a 400, B2 500 a 600. Pasar de un nivel al siguiente toma unas 200 horas guiadas, y Cambridge las llama guía: cada quien puede necesitar más o menos | Página de ayuda de Cambridge y guía de Cambridge University Press, vistas como resultados de búsqueda (el sitio de ayuda está bloqueado en este entorno) | Resultado de búsqueda, coincide con otras fuentes |
| Un instituto real | UNAM (ENES Morelia): un nivel por semestre, 120 horas por nivel (90 de clase y 30 de estudio) | Documento de la ENES Morelia, visto como resultado de búsqueda | Resultado de búsqueda |
| Referencias comerciales | EF: de 100 a 150 horas de A1 a A2, de 100 a 200 de A2 a B1, de 150 a 200 de B1 a B2. Otro sitio: 80, 160 y 180 clases | Blogs de EF y de languagecourse.net | Resultado de búsqueda, menos fiable |
| Macmillan | **No pude confirmar cómo estructura sus niveles.** Su sitio está bloqueado en este entorno y las búsquedas no dieron horas por nivel. Solo vi que Language Hub tiene seis niveles de A1 a C1 y que un curso antiguo suyo (*move*) cuenta 15 horas por módulo | Catálogo de Macmillan | No confirmado |
| Cambridge, notas | Escala de Cambridge: en B1 Preliminary, 140 a 152 es B1; 153 a 159, B1 alto; 160 a 170, B2. En B2 First, 160 a 172 es B2; 173 a 179, B2 alto; 180 a 190, C1. En A2 Key, 120 a 139 es A2; 140 a 150, B1 | cambridgeenglish.org, páginas de resultados | **Leído** |
| TOEIC | ETS recomienda puntajes mínimos por habilidad: Listening A2 110, B1 275, B2 400 (de 495); Reading A2 115, B1 275, B2 385 (de 495); Speaking A2 90, B1 120, B2 160 (de 200); Writing A2 70, B1 120, B2 150 (de 200). Y dice que son "guidelines, as ETS does not recommend the use of rigid cut scores" | ETS, *Mapping the TOEIC tests on the CEFR* | **Leído** |
| TOEFL iBT 2026 | Escala nueva de 1 a 6 en pasos de 0.5: A1 1 a 1.5, A2 2 a 2.5, B1 3 a 3.5, B2 4 a 4.5, C1 5 a 5.5, C2 6. Se reporta junto a la escala anterior de 0 a 120 | ETS, informe de abril de 2026 sobre la escala por bandas | **Leído** |
| Horas por punto de TOEIC | No hay cifra oficial. Reglas prácticas de fuentes no oficiales: unas 200 a 300 horas por cada 100 puntos, y las fuentes se contradicen | Varios, entre ellos artículos que citan a Saegusa (1985) | No confirmado; no se usa |

### E.2 Lo que significa

1. **Tu intuición es correcta para los institutos y falsa para los exámenes.** Los institutos estructuran cada nivel por horas (de unas 80 a 200 por nivel, según la fuente) y lo cierran con un examen interno. Los exámenes oficiales **no piden horas**: cualquiera puede presentarlos. Cambridge, ETS y TOEFL miden el nivel con una escala de puntajes; las horas son solo una guía de cuánto suele tomar.
2. **Lo que ya aprobaste es la misma estructura.** Tu regla (cada bimestre, subir solo si cumples todo) ya pide horas (al menos el 90 % de los minutos planeados) y examen (80 % por habilidad). El escalón de 8 semanas y 40 horas es un "nivel de instituto" pequeño.
3. **El plan de 11 escalones llegaba antes que las guías.** Con 40 horas por escalón: la puerta de A2 quedaba en 160 horas (guía: 180 a 200), la de B1 en 280 (guía: 350 a 400) y la de B2 en 440 (guía: 500 a 600). Es entre 11 % y 30 % menos de lo que Cambridge calcula. Y sus horas son de clase con maestro; una hora sola con una app seguramente rinde menos.
4. **Los exámenes oficiales no usan el 80 %.** Cambridge da la nota con una escala por bandas, y ETS dice que sus mínimos son guías. El 80 % por habilidad es un margen de seguridad propio, razonable para decir "estás listo", pero **no equivale a aprobar el examen real**. El plan ya lo dice en el semáforo; conviene no confundirlos.

### E.3 D-ING-1: 13 escalones (aprobada por el dueño el 16/nov/2026)

| Etapa | Escalones (40 horas cada uno) | Horas acumuladas al pasar la puerta | Guía de Cambridge |
|---|---|---|---|
| A1 | A1.1, A1.2 | 80 | no la pude confirmar |
| A2 | A2.1, A2.2, A2.3 | **200** | 180 a 200 |
| B1 | B1.1, B1.2, B1.3, B1.4 | **360** | 350 a 400 |
| B2 | B2.1, B2.2, B2.3, B2.4 | **520** | 500 a 600 |

- Total: **13 escalones**, 520 horas, unos dos años desde cero a una hora diaria de lunes a viernes. Quien entre ubicado al inicio de B1 llega a la puerta de B2 en 8 escalones, unos 15 meses, aprobando todo a la primera.
- **Qué se mantiene:** el escalón de 8 semanas, tu regla de subir solo si se cumple todo, la puerta de etapa con formato de examen oficial, la puerta anticipada y el descenso por evidencia.
- **Qué cambia:** hay dos escalones más (uno en A2 y uno en B1), y por eso el temario del anexo B se reparte en 13 y no en 11.
- **Las horas son un ritmo, no un candado.** Las horas de una etapa fijan el ritmo y el 90 % de minutos ya es requisito, pero quien demuestra el nivel antes (puerta anticipada, al menos 90 % en cada habilidad) avanza. Cambridge lo dice igual: las horas son una guía.
- **El 520 es el piso, no el techo.** Quien tarde más no falló: la propia ruta ya prevé repetir escalones.

## Anexo F. Voces descargables para el audio

> Pregunta del dueño (15/nov/2026), al aprobar el audio: "no tenemos un modelo de voz que podamos descargar?"

**Respuesta corta: sí existen, pero no los pude probar aquí.**

| Vía | Qué es | Pesa | Calidad | Pendiente de verificar |
|---|---|---|---|---|
| A. Voz del dispositivo | La que ya traen Android y Windows (`flutter_tts`) | Nada | Variable. Hay pocas voces distintas, y los diálogos del curso necesitan F1, F2, M1 y M2 | Qué voces en inglés hay en el Galaxy A52 y en Windows, y si funcionan sin conexión |
| B. Modelo descargable | Voces neuronales que corren sin conexión dentro de la app: Piper y Kokoro, con la biblioteca sherpa-onnx (Apache-2.0) y paquetes de Flutter ya existentes. Una misma voz en teléfono y laptop, y varias voces para los diálogos | Decenas de MB por voz. Vi apps de ejemplo de 40 a 129 MB con una voz incluida | Mejor que la A en general; no la he oído | Tamaño de cada modelo, **licencia de cada voz** (no la verifiqué), velocidad en el Galaxy A52 |
| C. Audio pregrabado | Se generan los audios con la vía B en la laptop y se empaquetan en la app | Unos 90 a 120 MB para todo el curso, en formato Opus (cálculo mío: unos 300 audios de 1.6 minutos; no medido). Se podrían bajar por escalón | Fija y revisable antes de entregarla | Que la licencia de la voz permita distribuir el audio generado |

- **"La voz de GRAVITY" todavía no existe como componente.** D6 dice que GRAVITY "genera la voz" para las bocinas, pero no elige el motor. La app tiene `speech_to_text` (entender lo que dices) y la interfaz `VozSalida` (`app/lib/modulos/gravity/conversacion/voz.dart`), sin implementación; las bocinas hablan por el servicio de texto a voz de Home Assistant (`puente_casa.dart`). Lo razonable es un solo motor que implemente `VozSalida` y sirva al curso, al asistente y, si D6 se confirma, a las bocinas.
- **Por qué no se pudo probar:** el entorno solo llega a ets.org y cambridgeenglish.org; Hugging Face y GitHub, donde están los modelos, están bloqueados.
- **Decisión del dueño (16/nov/2026):** las tres vías, y empezar también el motor de voz de GRAVITY (fase 3, paquete P3.0). Lo que sigue era mi recomendación y queda como el modo de elegir.
- **Recomendación:** no cerrar el motor todavía. El guion es lo que importa y la voz va detrás de una interfaz intercambiable (sección 3.5). En la prueba en el teléfono (P3.3) se compara la voz del dispositivo contra una voz descargable con la misma frase del curso, y el dueño elige de oído. Si la del teléfono no tiene voces suficientes para los diálogos, la B o la C pasan a ser la primera opción.

### Cambios de la versión 0.4 (16/nov/2026)

1. **Seis decisiones confirmadas** (4.1). Quedan D-ING-7 (orden) y D-ING-8 (ramas).
2. **13 escalones en lugar de 11** (3.1, anexo B): un escalón más en A2 y otro en B1, para que las puertas queden en 200, 360 y 520 horas, dentro de la guía de Cambridge.
3. **Fase 3 ampliada:** las tres vías de audio y el motor de voz de GRAVITY, con el paquete P3.0.
4. **D-ING-6 cambió de recomendación:** «gramática del tema» en 3 o más en lugar de «ningún criterio bajo 3».
5. **La segunda parte del validador (P1.2b) terminó** y el formato pasó a 0.4 con lo que encontró.
