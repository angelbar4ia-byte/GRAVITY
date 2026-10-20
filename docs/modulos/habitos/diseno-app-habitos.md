# App de Hábitos y Objetivos — Documento de Diseño v1.18

> Una app móvil (Android) de coaching personal, espiritual y educativo para planear, dar seguimiento y valorar objetivos medibles y persistentes. Uso individual y en pareja.

**Cambios en v1.18:** nota del **Anexo I** sobre Spec-Driven Development (anotado; se desarrollará cuando se unan los repositorios).

**Cambios en v1.17:** teléfono de pruebas (Samsung Galaxy A52 SM-A525M) y referencia al **contrato final v1.2** (`CONTRATO_CONEXION_APPS.md`) para unir los dos repositorios.

**Cambios en v1.16:** **Anexo H** con el plan de construcción por etapas para Claude Code (arquitectura, 12 etapas con criterios de aceptación, flujo de trabajo, pruebas, riesgos y prompts).

**Cambios en v1.15:** detalle de las pantallas **Hoy**, **Bicicleta (visor de ruta)** y **Panel de hábitos a eliminar** (G.10), con zonas, reglas, estados, datos y criterios de aceptación.

**Cambios en v1.14:** **Anexo G** con las pantallas: sistema de diseño, mapa de navegación, bocetos de 17 pantallas, inventario, componentes, gestos, widgets y accesibilidad.

**Cambios en v1.13:** principio de **configuración dentro de la app**: nada queda fijo en el documento; se agrega el **asistente de configuración inicial** (7.2) y la tabla de parámetros de hábitos a eliminar (F.15). Los horarios, cantidades y límites de este documento son **valores de ejemplo o plantillas editables**.

**Cambios en v1.12:** **plan inicial del usuario** para hábitos a eliminar (cigarrillo: primer mes gradual y dejarlo de golpe desde el segundo mes; azúcar: alimentos muy regulados y refresco ocasional), modo foco y calendario de cambios (Anexo F.14).

**Cambios en v1.11:** música por persona (Spotify para el usuario, Amazon Music para la pareja) y **Anexo F** con el módulo de hábitos a eliminar: azúcar y cigarrillo.

**Cambios en v1.10:** audífonos con escucha exterior y Spotify Premium confirmados (Anexo E).

**Cambios en v1.9:** salida en bicicleta de unas 4 horas con **visor de ruta** y **conexión con Spotify** (Anexo E) y aviso 15 minutos antes de la revisión de los sábados.

**Cambios en v1.8:** ruta en bicicleta los sábados a las **8:00**, y el recordatorio de dar pasa a ser **opcional y configurable** por el usuario (día y hora), sin recordatorio fijo.

**Cambios en v1.7:** día de pago los **viernes** (recordatorio de dar ese día), revisión del sábado individual por defecto y ruta en bicicleta sin choque de horario.

**Cambios en v1.6:** **revisión semanal los sábados a las 14:30** (resumen por área, práctica de los estudios y ajustes de la siguiente semana) y recordatorio de dar ligado al **pago semanal**.

**Cambios en v1.5:** revisión de la práctica **una vez por semana** y estudio de administración ampliado a 8 sesiones con **diezmos y ofrendas** (sin montos en Hábitos).

**Cambios en v1.4:** estudios prioritarios con sesiones detalladas (Espíritu Santo, Cristología, Perdón y Administración), **seguimiento "de la Biblia a la práctica"** para cada estudio (principios, compromisos, check-ins y revisión) y nivel de exégesis intermedio y avanzado.

**Cambios en v1.3:** versión principal RVR1960 y secundaria NVI, ruta de inicio para quien no tiene plan de lectura, **estudios bíblicos guiados** por tema y **estudio por métodos** (exégesis, inductivo, palabras, personajes, libros) en el Anexo D.

**Cambios en v1.2:** detalle completo del **área espiritual** (Anexo D): lector bíblico, planes de lectura, estudio, devocional, oración, memorización, ayuno, pareja, iglesia, datos y licencias.

**Cambios en v1.1:** decisión sobre cómo conectar las apps por etapas (archivos, mismo dispositivo, base compartida, MCP), separación de la futura app de cuidados y estrategia de IA con Claude (Anexo C).

**Cambios en v1.0:** alineación con el **contrato de conexión v1.0** de la app "Presupuesto y Alimentación" (reparto de datos, archivos JSON, enlaces y Health Connect), stack Flutter + Firebase Spark, política de IA y **Anexo B** con observaciones al contrato.

**Cambios en v0.9:** plan de transición de sueño (dormir y levantarse más temprano), mañana con devocional breve y cardio, regreso del trabajo planeado como bloque de 1 hora, y día tipo rehecho.

**Cambios en v0.8:** día tipo entre semana con el horario real (despertar 7:00, entrada 8:00, salida 18:00, llegada ~19:00), sugerencia de entrenar de noche y medidor de carga del día.

**Cambios en v0.7:** rutas mixtas en bicicleta (calle y terreno), y ventana de entrenamiento flexible (mañana o noche) con duración ajustable y periodo de prueba.

**Cambios en v0.6:** semana de entrenamiento de 3 a 5 días con 2 regenerativos, ruta en bicicleta los sábados, y lista de equipo futuro (pesas libres) para ampliar las rutinas.

**Cambios en v0.5:** inventario real del gimnasio (estación de poleas Marcy MWM-7119, banco inclinado y caminadora) con una rutina de ejemplo, y modo traslado en auto con la pareja (solo audio y actividades compartidas).

**Cambios en v0.4:** modo traslado (aprovechar ~35 min de trayecto), generador de rutinas a partir de los aparatos del gimnasio propio, y plan de inglés ajustado a 50–60 min diarios más extras.

**Cambios en v0.3:** pantalla de **Agenda** (horario laboral, ejercicio, plan de gimnasio y todo lo programado) y **plan de lecciones de inglés** de 24 semanas (Anexo A).

**Cambios en v0.2:** salud ampliada (sueño, vitaminas/suplementos, dieta), integración con la app de finanzas, Biblia multi-versión con concordancia y diccionarios, inglés desde B1 con la app como inmersión, modo pareja y prioridad en reducir azúcares y cigarrillo.

---

## 1. Visión y principios

**Visión:** ser un coach de bolsillo que integra fe, salud, educación, trabajo y crecimiento personal en un solo lugar.

**Principios de diseño**
1. **Medible:** todo objetivo tiene una métrica, una meta y una fecha.
2. **Persistente:** el progreso nunca se pierde; hay historial, rachas y recuperación tras fallar.
3. **Simple en móvil:** acción diaria en máximo 3 toques.
4. **Compasivo:** un día fallado no es un fracaso; la app anima a retomar.
5. **Integral:** las áreas se conectan (ej. ayuno ↔ salud, lectura ↔ educación).
6. **Offline-first:** funciona sin conexión y sincroniza después.
7. **Configurable dentro de la app:** fechas, horarios, cantidades, límites, versiones, aparatos y reglas se definen y se cambian en la app. Los valores de este documento son plantillas y ejemplos por defecto.

---

## 2. Áreas y herramientas auxiliares

| Área | Subáreas | Herramientas auxiliares |
|---|---|---|
| 🙏 Espiritual | Biblia (multi-versión), oración, ayuno | Plan de lectura, comparador de versiones, concordancia, diccionario bíblico, devocional diario, diario de oración, planificador de ayunos |
| 💪 Salud | Entrenamiento, alimentación y dieta, sueño, vitaminas y suplementos, valoración médica | Rutinas, registro de comidas y agua, control de azúcar, diario de sueño, recordatorios de suplementos, medidas corporales, citas y estudios médicos |
| 📚 Educación | Inglés (desde B1) | Lecciones, app bilingüe como inmersión, vocabulario con repaso espaciado, escucha, pronunciación, evaluaciones |
| 🌱 Personal | Lectura de libros | Biblioteca, metas de páginas, notas y citas, reseñas |
| 💼 Laboral | Carrera y productividad | Metas profesionales, bloques de enfoque, registro de logros |
| 🗂️ Proyectos | Proyectos propios | Hitos, tareas, fechas límite, avance en % |
| 🚫 Dejar hábitos | Refresco, cigarrillo, otros | Contador de días limpios, disparadores, plan de reemplazo, ahorro acumulado |

---

## 3. Modelo central de objetivos

Todo objetivo (de cualquier área) comparte esta estructura:

```
Objetivo
├── título
├── área / subárea
├── tipo: construir hábito | alcanzar meta | eliminar hábito | proyecto
├── métrica (unidad): minutos, páginas, días, kg, %, veces...
├── meta (valor objetivo) y frecuencia (diaria, semanal, total)
├── fecha de inicio y fecha objetivo
├── prioridad
├── recordatorios
├── registros de progreso (fecha, valor, nota)
└── valoración periódica (semanal / mensual)
```

**Tipos de objetivo**
- **Construir hábito:** "Leer 20 min al día" → se mide con racha y % de cumplimiento.
- **Alcanzar meta:** "Bajar 5 kg en 3 meses" → se mide con progreso hacia el valor final.
- **Eliminar hábito:** "0 refrescos" → se mide con días limpios y recaídas.
- **Proyecto:** "Terminar curso de inglés A2" → se mide con hitos completados.

---

## 4. Ciclo de coaching: Planear → Seguir → Valorar

### 4.1 Planear
- Asistente de metas tipo **SMART** (específica, medible, alcanzable, relevante, con fecha).
- Plantillas por área (ej. "Leer la Biblia en un año", "Correr 5K").
- Descomposición automática: meta anual → trimestral → semanal → diaria.

### 4.2 Seguir
- Pantalla **"Hoy"** con la lista de acciones del día.
- Registro rápido (toque, deslizar o ingresar valor).
- Rachas, calendario de calor y gráficas por objetivo.
- Recordatorios inteligentes (hora, lugar, contexto).

### 4.3 Valorar
- **Revisión semanal de los sábados a las 14:30 (15 a 25 min):**
  1. Resumen de la semana por área (qué funcionó, qué no).
  2. Práctica de los estudios bíblicos: compromisos cumplidos, aprendizajes y ajustes.
  3. Recordatorio de dar: ¿se cumplió lo que se decidió esta semana?
  4. Mini prueba y avance de inglés.
  5. Ajustes de la próxima semana en la agenda y las rutinas.
  - Aviso previo **15 minutos antes** (14:15).
  - Se programa como bloque fijo en la agenda; si ese sábado no se puede, se mueve sin perder la racha.
- **Revisión mensual:** puntaje por área, tendencia y reflexión.
- **Rueda de la vida:** autoevaluación 1–10 de cada área, comparada en el tiempo.
- Coach de IA que sugiere ajustes según los datos.

---

## 5. Detalle por área

### 5.1 🙏 Espiritual
Enfoque cristiano evangélico.

**Estudio bíblico**
- Planes de lectura: cronológico, un año, por libros, temático, personalizado.
- Lector con notas, subrayados y versículos favoritos.
- Método de estudio guiado (ej. **Observación → Interpretación → Aplicación**).
- Memorización de versículos con repaso espaciado.

**Versiones, concordancia y diccionarios** (detalle completo en el **Anexo D**)
- **Varias versiones:** RVR1960, NVI, Dios Habla Hoy (DHH), LBLA, NTV, entre otras, y en inglés (NIV, ESV, KJV) para practicar el idioma. Sujeto a licencias de cada versión.
- **Comparador:** ver el mismo pasaje en 2–4 versiones lado a lado.
- **Concordancia:** buscar una palabra y ver todos los versículos donde aparece (con números Strong si hay fuente disponible).
- **Diccionarios bíblicos:** consulta rápida de términos, personajes y lugares al tocar una palabra.
- **Referencias cruzadas** y notas de estudio.

**Devocionales**
- Devocional diario ligado al pasaje del plan de lectura.
- Estructura sugerida: lectura → reflexión → aplicación → oración.
- Biblioteca de devocionales y opción de añadir los propios.

**Oración**
- Diario de oración con peticiones, fecha y estado (pendiente / respondida).
- Lista de intercesión (personas, familia, iglesia).
- Tiempo de oración con temporizador y registro de minutos.
- Sección "Oraciones respondidas" para recordar la fidelidad de Dios.

**Ayuno**
- Planificador: tipo (agua, parcial, Daniel), duración y propósito.
- Temporizador, guía de oración durante el ayuno y diario.
- Recomendaciones de seguridad y aviso de consultar al médico si hay condiciones de salud.

**Métricas:** días de lectura, capítulos, minutos de oración, ayunos completados, versículos memorizados.

### 5.2 💪 Salud
**Entrenamiento (gimnasio propio)**
- Rutinas (fuerza, cardio, movilidad), registro de series/repeticiones/peso.
- Progresión y récords personales.

**Mi gimnasio: inventario de aparatos y generador de rutinas**
1. **Inventario:** el usuario marca o escribe los aparatos que tiene, por categoría:
   - Peso libre: barras, mancuernas (rango de pesos), discos, banco, rack.
   - Máquinas: prensa, jalón, remo, press de pecho, etc.
   - Poleas y cables.
   - Cardio: caminadora, bicicleta, elíptica, otros.
   - Accesorios: bandas, cuerda, barra de dominadas, TRX, colchoneta.
2. **Perfil de entrenamiento:** objetivo (fuerza, masa, pérdida de grasa, salud general), nivel, días por semana, duración por sesión, molestias o limitaciones físicas.
3. **Generación de rutinas:** la IA arma un plan semanal usando **solo los aparatos del inventario**, con ejercicios por grupo muscular, series, repeticiones y descansos.
4. **Edición:** se puede cambiar, sustituir un ejercicio (con alternativas por aparato) o pedir una versión más corta.
5. **Progresión:** sugiere subir carga o repeticiones según los registros y programa semanas de descarga.
6. **Agenda:** el plan se coloca en los días y horas libres (ver 7.1).

- Cada ejercicio incluye explicación breve, grupo muscular y errores comunes.
- Recomendación de calentamiento y estiramiento en cada sesión.
- Si se registra una molestia o lesión, la app sugiere ajustar el ejercicio y consultar a un médico o entrenador.
- La rutina generada es una guía general: no sustituye la valoración de un profesional.

**Inventario inicial (ejemplo real del usuario)**
| Aparato | Categoría | Notas para el generador |
|---|---|---|
| Estación multifuncional Marcy MWM-7119 | Máquina de pila de pesas + poleas | Pila de aprox. 68 kg (150 lb) según el distribuidor; poleas alta y baja, brazos de press y cojín de curl de bíceps. Confirmar en el aparato qué otras estaciones tiene (ej. extensión de pierna) |
| Banco inclinado | Banco | Sin pesas libres registradas: se usa con peso corporal o con la estación |
| Caminadora | Cardio | Intervalos y calentamiento |

- **Sin pesas libres por ahora** (mancuernas, barras, discos, bandas o barra de dominadas): las rutinas usan estación, banco, caminadora y peso corporal.
- **Equipo futuro:** el usuario puede registrar los aparatos que planea comprar. La app genera una versión de cada rutina "para cuando tengas mancuernas" y sugiere qué compra amplía más las opciones (ej. mancuernas ajustables, bandas, barra de dominadas) para que la rutina se adapte al instante cuando se agreguen al inventario.
- **Límite de carga:** como la pila es de ~68 kg, la progresión se hace subiendo repeticiones, series, control del tempo y reduciendo descansos, además de la carga.

**Semana tipo de entrenamiento (3 a 5 días, con 2 regenerativos y sábado de bicicleta)**

La semana se arma con **3 sesiones de fuerza** (A, B y C) y hasta **2 sesiones regenerativas**; el usuario elige cuántas hace (3, 4 o 5 días). Los **sábados** son de ruta en bicicleta.

| Opción | Lunes | Martes | Miércoles | Jueves | Viernes | Sábado | Domingo |
|---|---|---|---|---|---|---|---|
| **3 días** | A | — | B | — | C | Bicicleta | Descanso |
| **4 días** | A | Regenerativo | B | — | C | Bicicleta | Descanso |
| **5 días** | A | Regenerativo | B | Regenerativo | C | Bicicleta | Descanso |

Es un borrador editable: los días se mueven en la agenda según tu horario.

*Calentamiento (sesiones de fuerza):* 5–8 min en caminadora a paso suave + movilidad de hombros y caderas.

| Sesión | Enfoque | Ejercicios (series × repeticiones) |
|---|---|---|
| A | Empuje: pecho, hombro y tríceps | Press de pecho en la estación 3×10–12; elevaciones laterales en polea baja 3×12–15; extensión de tríceps en polea alta 3×12; fondos en banco con peso corporal 3×8–12 |
| B | Tirón: espalda y bíceps | Jalón al pecho en polea alta 3×10–12; remo sentado en polea baja 3×10–12; face pull en polea alta 3×12–15; curl de bíceps en el cojín o polea baja 3×10–12 |
| C | Pierna y core | Sentadilla con peso corporal hacia el banco 3×12–15; subidas al banco (step-ups) 3×10 por pierna; puente de glúteo con apoyo en el banco 3×12–15; patada de glúteo en polea baja 3×12 por pierna; plancha 3×30–45 s |

- Duración orientativa: 45–60 min por sesión de fuerza, ajustable por el usuario.
- **Tres versiones de cada sesión:** corta (30 min), estándar (45 min) y larga (60 min); la app elige según el tiempo libre que muestre la agenda ese día.

**Ventana de entrenamiento (mañana o noche)**
- El usuario aún no define horario, así que la app permite elegir **mañana**, **noche** o **flexible** (según el día).
- **Periodo de prueba de 2 semanas** en cada horario: la app compara cuántas sesiones se cumplieron, la energía percibida y la calidad del sueño, y sugiere el mejor.
- En la **noche**, avisa si la sesión queda muy cerca de la hora de dormir y propone versiones más suaves o terminar antes.
- En la **mañana**, propone calentamiento más largo y la sesión se coloca antes de la salida al trabajo, considerando el traslado.
- El horario se puede cambiar por día sin perder la racha.
- **Plan del usuario:** la **mañana** es para un **devocional breve** y **cardio suave** (con tiempo para bañarse y prepararse), y la **fuerza** va **de noche, después de las 19:00**. Esto depende de adelantar la hora de despertar (ver el plan de transición de sueño).
- Mientras el usuario aún se levanta a las 7:00, el cardio matutino se acorta a 10–15 min o se mueve a la noche.
- Descanso entre series: 45–75 s. Se dejan al menos 48 h entre sesiones del mismo grupo muscular.
- Cierre: 5 min de estiramiento.
- Si la estación tiene más puestos (ej. desarrollador de piernas), el generador los incorpora.
- Es una guía general de partida; no sustituye la valoración de un médico o entrenador.

**Sesión regenerativa (20–40 min)**
- Caminata suave en caminadora 15–25 min.
- Movilidad y estiramientos guiados (cadera, hombros, espalda).
- Respiración y relajación; opcional: oración o devocional al final.
- La app propone una u otra según el cansancio que reportes y la calidad del sueño de la noche anterior.
- Meta de la sesión: recuperar, no rendir; no se mide por carga ni por intensidad.

**Modelo del aparato**
```
Aparato
├── nombre y categoría
├── grupos musculares que trabaja
├── cantidad y carga disponible (ej. mancuernas de 5 a 30 kg)
└── notas (ajustes, estado)
```

**Ruta en bicicleta (sábados)**
- **Salida programada:** sábados a las **8:00** (editable), de unas **4 horas**, con recordatorio de preparación (agua, casco, luces y clima) la noche anterior o 30 min antes. Visor de ruta, seguridad y música en el **Anexo E**.
- **Planificador de ruta:** guardar rutas favoritas, distancia, desnivel y tiempo estimado.
- **Seguimiento por GPS** con el teléfono: distancia, tiempo, velocidad media y desnivel.
- **Progresión:** aumento gradual de distancia o tiempo semana a semana (sin saltos bruscos).
- **Seguridad:** recordatorio de casco, luces, hidratación y revisión de la bicicleta; clima antes de salir; contacto de emergencia.
- **Rutas mixtas** (calle, ciclovía y terreno): cada ruta guarda el tipo de superficie por tramo, la dificultad y el tiempo estimado.
- **Tramos de calle:** recordatorio de luces y ropa visible, y aviso de horarios de mucho tráfico.
- **Tramos de terreno:** revisión de llantas y frenos antes de salir, y lista de herramientas básicas (bomba, parche, cámara de repuesto).
- **Mantenimiento de la bicicleta:** recordatorio de limpieza, lubricación de cadena y revisión según kilómetros recorridos.
- **Opcional en pareja:** compartir la ruta y el avance si salen juntos.
- Se registra automáticamente en Progreso y en la agenda del sábado.

**Alimentación: cumplimiento del plan (conectada con "Presupuesto y Alimentación")**
- La app **de Presupuesto es dueña** de menús, recetas, costos, lista de compras y despensa. Hábitos **no** los crea ni los calcula.
- Hábitos **recibe el plan** (por archivo JSON) y muestra **"Plan de hoy"** con las comidas por tiempo (desayuno, colación, comida, cena) y las reglas de la persona (alergias, exclusiones, preferencias).
- Cada comida se marca como **cumplida, parcial, sustituida (con el platillo real) u omitida**; con eso se calcula la constancia nutricional y se exporta el seguimiento semanal.
- Las comidas del plan se pueden poner en la **Agenda** como bloques con recordatorio, con confirmación del usuario.
- **Modo independiente** (si no está instalada la otra app): registro simple de las comidas del día (sí/no y una nota) y contadores de hábitos; sin calorías ni macros.
- **Calorías y macros:** no se calculan aquí; si el usuario los quiere ver, se **leen de Health Connect** (los escribe la app de Presupuesto).
- **Agua y peso:** Hábitos es el dueño y los escribe en Health Connect, con permiso.
- **Control de azúcar (hábito):** contadores de bebidas azucaradas y postres, días sin refresco, reducción gradual de gramos si el usuario los registra, y vínculo con las etiquetas del plan (ej. `azucar_alta`). Es un hábito conductual, no un cálculo nutricional.
- Tipos de dieta (déficit, mantenimiento, baja en azúcar) se capturan como **reglas en la app de Presupuesto**; Hábitos las muestra.

**Sueño**
- Registro de hora de dormir y despertar, calidad percibida y despertares.
- Meta de horas y hora fija de acostarse, con recordatorio nocturno.

**Plan de transición de sueño (dormir y levantarse más temprano)**
- Punto de partida del usuario: acostarse entre las 23:00 y las 24:00. Meta: **dormir más temprano y levantarse más temprano**.
- La app mueve el horario de forma **gradual, 15 minutos cada 3–4 días**, para que el cambio sea sostenible.
- Ejemplo de escalera (editable):

| Semana | Hora de dormir | Hora de despertar |
|---|---|---|
| Hoy | 23:00–24:00 | 7:00 |
| 1 | 23:30 | 6:45 |
| 2 | 23:00 | 6:30 |
| 3 | 22:30 | 6:15 |
| 4 | 22:00–22:30 | 6:00 |

- Meta de sueño: aproximadamente **7 a 8 horas**; la hora de despertar final la define el usuario.
- **Rutina previa al sueño** de 30 min: sin pantallas, luz tenue, oración o lectura breve.
- Alarmas escalonadas: aviso "empieza tu rutina" y aviso "hora de dormir".
- Regla importante: **se acuesta más temprano antes de levantarse más temprano**; si un día no se logra, la app no castiga la racha y reajusta el siguiente paso.
- Relaciona el sueño con el cumplimiento del cardio matutino, la energía y los antojos (ej. azúcar).
- Rutina previa al sueño (ej. oración, lectura, sin pantallas).
- Relación visible entre sueño y otros indicadores (ánimo, rendimiento, antojos).

**Vitaminas y suplementos**
- Registro de lo que toma, con horario, presentación y recordatorios.
- Control de inventario: aviso cuando queda poco para volver a comprar.
- Aviso de posibles interacciones o duplicados con base en lo que el usuario registra.
- La app **no receta ni sugiere dosis**: las pautas las define el médico o nutriólogo.

**Valoración médica**
- Agenda de citas, estudios y exámenes de laboratorio.
- Registro de medidas: peso, presión, glucosa, cintura, etc.
- Recordatorio de chequeos preventivos y medicamentos.

**Métricas:** peso, % de grasa, entrenamientos por semana, agua diaria, azúcar añadida, horas de sueño, adherencia a la dieta y a los suplementos.

### 5.3 📚 Educación — Inglés
La app debe **enseñar** el idioma, no solo medirlo. Punto de partida: **nivel B1** (intermedio), con meta B2 y luego C1.

**Ruta de aprendizaje (B1 → B2 → C1)**
- Prueba de nivel inicial para confirmar B1 y detectar puntos débiles.
- Unidades temáticas con lecciones cortas (5–10 min).
- Ajuste automático de dificultad según resultados.

**Interfaz bilingüe como método de aprendizaje**
- La app es bilingüe (español/inglés) y **usarla es parte de la lección**.
- **Modo de inmersión graduable:** el usuario elige qué parte de la interfaz ve en inglés (botones, mensajes, recordatorios, coach).
- **Alternancia automática:** ciertos días, áreas o pantallas cambian al inglés para reforzar vocabulario real (ej. "Today", "Goals", "Streak").
- **Toque para traducir:** cualquier texto en inglés se puede tocar para ver traducción, pronunciación y guardarlo en el vocabulario.
- El **coach de IA** conversa en inglés con apoyo en español, según el nivel.
- Las tareas diarias de otras áreas pueden aparecer en inglés (ej. "Read 20 minutes").

**Escucha**
- Audios graduados (diálogos, noticias breves, podcasts) con preguntas de comprensión.
- Velocidad ajustable, repetición por frases y transcripción opcional.
- Dictados para entrenar el oído.
- Variedad de acentos (EE. UU., Reino Unido, otros).

**Pronunciación**
- Grabar y comparar con un modelo nativo.
- Retroalimentación por sonido (vocales, "th", "r", sílaba tónica) con reconocimiento de voz.
- Pares mínimos (ship/sheep) y trabalenguas.
- Puntaje de pronunciación por sesión y evolución en el tiempo.

**Vocabulario y gramática**
- Tarjetas con repaso espaciado, con ejemplos y audio.
- Phrasal verbs, expresiones y falsos amigos.
- Gramática en explicaciones breves con ejercicios.

**Hablar y escribir**
- Conversación guiada con IA por situaciones (trabajo, viajes, médico, iglesia).
- Redacciones cortas corregidas con explicación del error.
- Diario en inglés (1–3 líneas al día).

**Lectura**
- Textos graduados y noticias simplificadas.
- Lectura de versículos en inglés en paralelo con la versión en español (puente con el área espiritual).

**Para un aprendizaje completo, a futuro**
- Preparación para exámenes (TOEFL, IELTS, Cambridge) con simulacros.
- Inglés para el trabajo (correos, reuniones, entrevistas).
- Series y videos con subtítulos interactivos.
- Retos con tu pareja (conversar en inglés cierta cantidad de minutos).
- Certificado interno de nivel y reporte de progreso por habilidad (escucha, habla, lectura, escritura).

**Métricas:** palabras aprendidas, minutos de estudio, racha, puntaje de pronunciación, precisión en escucha, nivel estimado por habilidad.

> El plan completo de 24 semanas está en el **Anexo A**.

### 5.4 🌱 Personal — Lectura de libros
- Biblioteca: por leer / leyendo / terminado.
- Meta anual de libros y meta diaria de páginas o minutos.
- Notas, citas favoritas y reseña breve por libro.
- Sugerencias de lectura según objetivos del usuario.

**Métricas:** libros terminados, páginas por día, tiempo de lectura, racha.

### 5.5 💼 Laboral y 🗂️ Proyectos
- Metas profesionales con hitos y fechas.
- Proyectos con tareas, avance en % y próximas acciones.
- Bloques de enfoque (técnica Pomodoro) y registro de logros semanales.

### 5.6 🚫 Eliminar malos hábitos
Módulo transversal, disponible en cualquier área (salud, espiritual, personal).

**Primeros hábitos a trabajar: disminuir azúcares y cigarrillo** (detalle completo en el **Anexo F**).
- **Azúcares:** alimentos muy regulados y refresco ocasional (con un límite que define el usuario), registro de porciones, sustitutos y vínculo con el área de alimentación.
- **Cigarrillo:** primer mes de reducción gradual y, desde el segundo mes, dejarlo por completo ("Día D"), con registro de disparadores y ahorro acumulado.

**Funciones**
- **Contador de días limpios** y racha más larga.
- **Ahorro acumulado** (ej. dinero no gastado en refrescos o cigarrillos).
- **Registro de antojos:** hora, intensidad, disparador, qué hice.
- **Plan "Si… entonces…":** "Si siento ganas de fumar, entonces tomo agua y camino 5 minutos."
- **Reemplazo de hábito:** sustituir por una conducta positiva.
- **Botón de emergencia ("Tengo un antojo"):** respiración guiada, versículo de ánimo, contactar a alguien de apoyo.
- **Manejo de recaídas:** sin culpa; registrar, aprender y reiniciar el plan.
- **Reducción gradual o abstinencia total**, según elija el usuario.
- **Hitos de salud** (ej. beneficios al pasar 24 h, 1 semana, 1 mes).

> Para adicciones fuertes (como el tabaco), la app incluye recomendación de apoyo profesional y líneas de ayuda locales.

### 5.7 👫 Modo pareja
Uso **individual** y en **pareja**.

- Cada persona tiene sus propios objetivos y datos privados por defecto.
- **Objetivos compartidos** opcionales (ej. orar juntos, leer la Biblia en pareja, caminar 3 veces por semana).
- **Compañero de rendición de cuentas:** cada quien decide qué comparte (rachas, avances, antojos).
- Devocional y oración en pareja: peticiones compartidas y respondidas.
- Retos conjuntos de inglés y de salud.
- Mensajes de ánimo y celebración de logros.
- **Privacidad:** el contenido sensible (salud, diario de oración, recaídas) es privado hasta que el usuario lo comparte.

### 5.8 💰 Conexión con la app "Presupuesto y Alimentación"
Dos apps independientes (ambas Android, Flutter y Firebase Spark) que se entienden mediante el **contrato de conexión v1.0**. Cada una **funciona completa sin la otra**.

**Reparto de datos (un solo escritor por tipo de dato)**
| Dato | Dueña | La otra app |
|---|---|---|
| Reglas del plan (alergias, exclusiones, preferencias) | Presupuesto | Hábitos las recibe y las muestra |
| Menús, recetas, costo, lista de compras, despensa | Presupuesto | Hábitos no los calcula |
| Cumplimiento y constancia de las comidas | **Hábitos** | Presupuesto lo recibe |
| Ejercicio, rutinas, bicicleta, agenda, sueño, inglés, espiritual, suplementos, hábitos a eliminar | **Hábitos** | No se comparte |
| Peso y agua | **Hábitos** (Health Connect) | Presupuesto solo lee, con permiso |
| Comidas registradas (nutrición) | Presupuesto (Health Connect) | Hábitos solo lee |
| Dinero, cuentas, presupuesto | Presupuesto | **Nunca se comparte** |

**Vías de conexión**
1. **Archivo JSON** compartido con el botón Compartir de Android: plan (Presupuesto → Hábitos) y seguimiento (Hábitos → Presupuesto). Siempre con pantalla de revisión y confirmación.
2. **Enlaces entre apps** (`habitos://` y `presupuesto://`): abrir la pantalla correcta de la otra app.
3. **Health Connect** (segunda etapa): peso, agua, comidas y ejercicio, con permiso pedido solo cuando se usa.

**Qué hace Hábitos en esta conexión**
- Importa el plan, lo revisa con el usuario y arma "Plan de hoy".
- Registra el cumplimiento de cada comida y exporta el seguimiento semanal.
- Escribe peso y agua (y, propuesto, sueño y sesiones de ejercicio) en Health Connect; lee las comidas.
- **No envía dinero ni precios.** El ahorro por hábitos eliminados (azúcar, cigarrillo) se muestra solo dentro de Hábitos, con el precio que el usuario captura aquí como motivación personal. Ver el Anexo B para una opción que respete el contrato.

**Privacidad:** los datos de salud propios (peso, sueño, medidas, citas, hábitos a eliminar) se quedan en Hábitos salvo lo que el contrato define; la conexión es con consentimiento, por persona y por tipo de dato.

---

## 6. Gamificación y motivación
- Rachas, insignias y niveles por área.
- Puntaje semanal de equilibrio (rueda de la vida).
- Mensajes motivacionales y versículos de ánimo.
- Celebración de hitos.
- Evitar la presión excesiva: opción de "día de gracia" para no perder la racha.

---

## 7. Pantallas principales (navegación)

Barra inferior con 5 pestañas:

1. **Hoy:** lo que sigue en la agenda, acciones del día, recordatorios, versículo del día.
2. **Agenda:** calendario con todo lo programado (ver 7.1).
3. **Áreas:** tarjetas por área con progreso y acceso a objetivos (lista, creación y edición).
4. **Progreso:** gráficas, rachas y revisiones.
5. **Coach:** asistente de IA y revisión semanal.

> Los **Objetivos** se crean y editan desde Áreas y desde el botón "+" global, para respetar el máximo de 5 pestañas de la navegación inferior en Android.

**Flujos clave**
- Onboarding: elegir áreas → crear primeros objetivos → configurar recordatorios.
- Crear objetivo (asistente SMART).
- Registro rápido desde la pantalla Hoy.
- Revisión semanal guiada.

> Los bocetos de cada pantalla están en el **Anexo G**.

### 7.1 📅 Agenda (pantalla de lo programado)

**Qué muestra**
- Vistas: **Día** (línea de tiempo), **Semana** (columnas) y **Mes** (puntos por área).
- Bloques con color por área: horario laboral, ejercicio, inglés, devocional/oración, comidas, suplementos, sueño, citas médicas, ayuno, lectura y proyectos.
- Estado de cada bloque: pendiente, hecho, omitido o reprogramado (alimenta las rachas y el progreso).

**Horario laboral**
- Se captura una vez: días, hora de entrada/salida y descansos (horario **fijo**; los turnos rotativos quedan como opción futura).
- Se repite automáticamente y se muestra como bloque fijo.
- La app usa los huecos libres para proponer ejercicio, estudio de inglés, oración o lectura.

**Traslado al trabajo (~35 min)**
- Se configura la duración del trayecto (ida y vuelta) y se muestra como bloque en la agenda.
- Es un **bloque de aprovechamiento**: la app propone actividades de solo audio o manos libres, según cómo te traslades.
- **Modo traslado (manos libres):** botones grandes, control por voz y reproducción automática; sin tener que mirar la pantalla.
- **Te trasladas en auto:** el modo traslado es **solo audio y voz**, sin lecturas ni tarjetas visuales. La pantalla se bloquea para el conductor y todo se controla por comandos de voz (se activa por Bluetooth o Android Auto). Una versión con pantalla para transporte público queda como opción futura.

**Traslado en pareja (viajan juntos y trabajan juntos)**
- El traslado puede ser un **bloque compartido** en la agenda de ambos.
- Actividades compartidas propuestas:
| Actividad | Ejemplo |
|---|---|
| Conversación en inglés entre ustedes | La app da un tema y frases de apoyo; el primer tramo del trayecto se habla solo en inglés |
| Escucha compartida | Un audio del módulo y luego comentarlo en inglés |
| Devocional y oración en pareja | Lectura del pasaje del día y tiempo de oración conjunta |
| Planear el día de trabajo | Prioridades y tareas de cada uno, con ayuda del coach por voz |
| Cierre del día en el regreso | Gratitud, logros y pendientes para mañana |
- El audio lo puede controlar la persona que va de copiloto, o ambos por voz.
- Cada quien conserva su progreso individual (su racha y sus minutos).

**Propuestas de actividades para el traslado** (el usuario elige y la app las alterna):
| Actividad | Área | Ejemplo |
|---|---|---|
| Escucha de inglés | Educación | Audio graduado del módulo + preguntas por voz |
| Shadowing (repetir en voz alta) | Educación | Repetir frases para mejorar pronunciación y ritmo |
| Repaso de vocabulario por audio | Educación | Palabras del día con ejemplo y repetición |
| Biblia en audio | Espiritual | Lectura del pasaje del plan |
| Devocional en audio | Espiritual | Reflexión y aplicación |
| Oración guiada | Espiritual | Lista de intercesión por voz |
| Memorización de versículos | Espiritual | Repetir y recibir retroalimentación |
| Audiolibro o resumen de libro | Personal | Avance de la meta de lectura |
| Planear el día con el coach | Coach | Revisar la agenda y la prioridad del día por voz |
| Revisión de objetivos de regreso | Coach | Resumen y gratitud al final de la jornada |

- Los días de **escucha y pronunciación** del plan de inglés se apoyan más en el traslado.
- La app registra el tiempo del traslado como minutos de estudio, lectura u oración, según la actividad.

**Ejercicio y plan de gimnasio**
- Plan semanal con **qué área trabajar cada día** (ejemplo con 5 días de entrenamiento):

| Día | Enfoque | Ejemplo |
|---|---|---|
| Lunes | Fuerza A: empuje | Press de pecho, tríceps |
| Martes | Regenerativo | Caminata suave y movilidad |
| Miércoles | Fuerza B: tirón | Jalón, remo, bíceps |
| Jueves | Regenerativo | Estiramientos y respiración |
| Viernes | Fuerza C: pierna y core | Sentadilla al banco, step-ups, plancha |
| Sábado | Ruta en bicicleta | Salida larga con GPS |
| Domingo | Descanso | Descanso y devocional |

- Estructura configurable: cuerpo completo, torso/pierna, push/pull/legs o por grupos musculares. Los días y grupos de arriba son un ejemplo editable.
- La agenda sugiere rotar áreas y deja descanso entre sesiones del mismo grupo muscular.
- Al tocar un bloque de gimnasio se abre la rutina del día (ejercicios, series, repeticiones y peso) y se registra el entrenamiento.
- Si te saltas un día, propone reprogramar sin romper el plan.

**Funciones de la agenda**
- **Búsqueda de huecos:** al crear un objetivo ("20 min de inglés al día") la app propone horarios libres.
- **Detección de conflictos:** avisa si un bloque se cruza con el trabajo u otra actividad.
- **Bloques recurrentes** con excepciones (vacaciones, enfermedad).
- **Recordatorios** antes de cada bloque y **widget de Android** con lo siguiente del día.
- **Sincronización con Google Calendar** (opcional, en ambos sentidos).
- **Modo pareja:** bloques compartidos opcionales (oración juntos, caminata) y vista de disponibilidad en común. Los bloques de salud y oración personales se mantienen privados.
- **Trabajan juntos:** pueden compartir el horario laboral y el traslado como bloques conjuntos, y cada uno agrega lo demás por su cuenta.

**Día tipo entre semana (propuesta para cuando se complete la transición de sueño; editable)**

Basado en: entrada al trabajo 8:00, salida 18:00, regreso de 1 hora y llegada a casa ~19:00. La hora de salida de casa (~7:20) se confirma con el usuario.

| Hora | Bloque | Área |
|---|---|---|
| 6:00–6:10 | Despertar, agua y aseo breve | Salud |
| 6:10–6:25 | Devocional breve | Espiritual |
| 6:25–6:50 | Cardio suave en caminadora (20–25 min) | Salud |
| 6:50–7:20 | Baño, preparación, desayuno y suplementos | Salud |
| ~7:20–8:00 | Traslado de ida (~35 min): escucha y conversación en inglés con tu pareja | Educación |
| 8:00–18:00 | Trabajo; en el descanso, repaso de vocabulario (5–10 min) y registro de agua | Laboral / Educación |
| 18:00–19:00 | **Traslado de regreso (1 hora):** shadowing de inglés (~30 min), devocional y oración en pareja (~20 min) y cierre del día (~10 min) | Educación / Espiritual |
| 19:00–19:15 | Llegada y cambio de ropa | — |
| 19:15–20:15 | Fuerza (días A, B y C); en día regenerativo, movilidad o descanso | Salud |
| 20:15–21:00 | Cena | Salud |
| 21:00–21:15 | Inglés: bloque principal corto (el traslado ya cubre la mayor parte) | Educación |
| 21:15–21:45 | Lectura de libro, oración y diario; tiempo en pareja | Personal / Espiritual |
| 21:45–22:00 | Rutina previa al sueño (sin pantallas) | Salud |
| 22:00–22:30 | Dormir (meta) | Salud |

- **El traslado ya suma ~95 min** (35 de ida y 60 de regreso): cubre las 50–60 min diarias de inglés, y la noche queda solo para repaso corto.
- En **días regenerativos**, el cardio de la mañana puede ser la sesión y la noche queda libre.
- Los **sábados**: ruta en bicicleta a las **8:00** y **revisión semanal a las 14:30** (individual; en pareja es opcional). Los **domingos**: descanso, devocional e iglesia.
- Durante las primeras semanas de transición, la app muestra el horario **intermedio** de cada semana, no el final.

**Medidor de carga del día**
- La agenda suma los minutos programados por área y muestra si el día está **ligero, equilibrado o saturado**.
- Si hay saturación (muchas actividades nocturnas seguidas), la app propone mover o acortar bloques, usar versiones cortas y proteger las horas de sueño.
- Los **bloques mínimos** (los que no se negocian) se marcan primero y el resto se ofrece como opcional.
- El objetivo es **constancia sostenible**, no llenar el día.

**Modelo del bloque**
```
Bloque
├── título y área
├── inicio, fin (o duración) y repetición
├── objetivo vinculado (opcional)
├── detalle (ej. rutina de gimnasio, lección de inglés, pasaje bíblico)
├── visibilidad: privado | compartido con pareja
└── estado: pendiente | hecho | omitido | reprogramado
```

### 7.2 Asistente de configuración inicial
Se ejecuta la primera vez (10 a 15 minutos), por pasos, **se puede pausar o saltar** y todo se puede cambiar después en Ajustes.

| Paso | Qué se define | Plantilla sugerida |
|---|---|---|
| 1. Perfil y modo | Individual o pareja, y qué se comparte | Individual, nada compartido |
| 2. Áreas activas | Qué áreas usar al inicio | Empezar con 2 o 3 y sumar después |
| 3. Trabajo y traslado | Horario laboral, duración del traslado, medio (auto o transporte) y si se hace con la pareja | Horario fijo; traslado en modo solo audio si se maneja |
| 4. Sueño | Hora actual de dormir y despertar, meta y ritmo de cambio | Transición de 15 minutos cada 3 o 4 días |
| 5. Espiritual | Versión principal y secundaria, ruta de inicio, hora del devocional, recordatorio de dar (opcional) | Plan de inicio de 21 días, devocional breve |
| 6. Salud | Inventario de aparatos, días y duración del entrenamiento, ventana (mañana o noche), ruta en bicicleta, suplementos y metas | Rutina generada con el inventario; 3 a 5 días, 2 regenerativos |
| 7. Hábitos a eliminar | Qué hábito, estrategia (gradual o de golpe), fecha de inicio y Día D, límites (por ejemplo, qué es "ocasional"), motivos y apoyo | Línea base de 7 días primero |
| 8. Inglés | Prueba de nivel, minutos diarios, porcentaje de inmersión y uso en el traslado | Nivel según la prueba; inmersión progresiva |
| 9. Música | App por persona (Spotify, Amazon Music u otra) y listas por actividad | Controles de medios de Android |
| 10. Revisión semanal | Día, hora y aviso previo | Un día fijo con aviso 15 minutos antes |
| 11. Privacidad | PIN o biometría, qué se comparte con la pareja, IA por función y clave | Todo privado, IA apagada |
| 12. Conexión con Presupuesto | Activar o no el intercambio de archivos y enlaces | Desactivada |

**Reglas del asistente**
- Cada paso propone un valor **por defecto** que el usuario acepta o cambia, y siempre hay **"decidir después"**.
- Al final muestra una **semana tipo** con todo lo programado, y el **medidor de carga** avisa si está saturada; si lo está, sugiere empezar con menos.
- Los cambios importantes (por ejemplo, mover el **Día D**) piden confirmación y muestran qué otros planes se ven afectados (sueño, agenda, modo foco).
- Se puede **reconfigurar** cualquier parte en cualquier momento.
- Los textos y ejemplos del documento (horarios, porcentajes, días) **no están fijos en el código**: viven en configuración y plantillas.

---

## 8. Coach de IA
- Ayuda a definir y ajustar objetivos.
- Analiza tendencias ("fallas más los miércoles por la noche").
- Tutor de inglés conversacional.
- Acompañamiento en antojos y recaídas.
- Sugerencias devocionales y preguntas de reflexión.
- **Límites:** no sustituye consejo médico, psicológico ni pastoral.

---

## 9. Requisitos técnicos (propuesta)

| Aspecto | Propuesta |
|---|---|
| Plataforma | **Android**, Flutter (mismo stack que la app de Presupuesto) |
| Datos locales | Base local SQLite (ej. Drift), offline-first: es la fuente principal |
| Sincronización | Firebase Spark (plan gratuito): respaldo y sincronía entre la pareja, con reglas de seguridad |
| Notificaciones | Locales + push |
| IA | API de Claude para coach y tutor, **sin dejar la clave dentro de la app** (ver Anexo B.5) |
| Voz | Reconocimiento y síntesis de voz (pronunciación y escucha), TTS en inglés con varios acentos |
| Mapas | Mapa con rutas, GPS en segundo plano y mapas sin conexión (ver Anexo E) |
| Música | Spotify: abrir listas y controlar la reproducción (ver Anexo E) |
| Integraciones | Android Auto / Bluetooth (modo traslado), Health Connect / Google Fit, calendario, API con la app de finanzas |
| Biblia | Varias versiones con licencia (RVR1960, NVI, DHH, etc.), concordancia y diccionarios; revisar derechos de cada versión |

**Persistencia:** historial completo, exportación (CSV/PDF) y respaldo en la nube.

---

## 10. Privacidad y seguridad
- Los datos de salud, oración y hábitos son sensibles: cifrado local y en tránsito.
- Bloqueo con PIN o biometría.
- El usuario controla qué se sincroniza y puede borrar todo.
- Sin venta de datos ni publicidad.
- **IA con datos de salud:** cada función con IA (coach, rutinas, tutor) se activa por separado; se envía solo lo mínimo, sin nombres, alergias ni datos de terceros.
- Los archivos exportados a la otra app llevan datos de salud: la app lo avisa antes de compartir.

---

## 11. Hoja de ruta

> El orden de construcción detallado para Claude Code está en el **Anexo H**.

| Fase | Contenido |
|---|---|
| **MVP (v1)** | Modelo de objetivos, pantalla Hoy, **Agenda básica (horario laboral y bloques)**, rachas, hábitos a eliminar (azúcares y cigarrillo), Biblia multi-versión + devocional + oración, lectura de libros, revisión semanal |
| **v1.1** | Salud: cumplimiento de comidas del plan y conexión con Presupuesto (archivos JSON y enlaces), sueño (con plan de transición), suplementos, **inventario del gimnasio y generador de rutinas**, ruta en bicicleta con visor de ruta (Anexo E), plan de gimnasio en la agenda, entrenamiento y medidas |
| **v1.2** | Inglés B1: lecciones, vocabulario, escucha, interfaz bilingüe con inmersión, **modo traslado** |
| **v1.3** | Modo pareja y objetivos compartidos |
| **v2** | Coach de IA, pronunciación avanzada, ayuno, valoración médica, concordancia y diccionarios, Health Connect (peso, agua, sueño, ejercicio y lectura de comidas), sincronía opcional con Firebase compartido |
| **v3** | Laboral y proyectos avanzados, preparación de exámenes de inglés, comunidad |

---

## 12. Decisiones tomadas y preguntas abiertas

> Muchos de estos datos (fechas, horarios, cantidades, límites) **se definen dentro de la app** con el asistente de configuración (7.2); aquí solo quedan las decisiones de diseño.

**Decisiones**
| Tema | Decisión |
|---|---|
| Estudios bíblicos | Prioritarios: salvación, amor, Espíritu Santo, Cristología, perdón y administración; cada estudio con seguimiento de práctica; exégesis en nivel intermedio y avanzado; revisión semanal los sábados a las 14:30 (incluye la práctica de los estudios); administración incluye diezmos y ofrendas (sin montos en Hábitos); pago semanal (viernes); el recordatorio de dar es opcional y lo programa el usuario |
| Versiones de la Biblia | Principal **RVR1960**, secundaria **NVI**; otras (DHH y más) después; con comparador, concordancia y diccionarios |
| Nivel de inglés | B1 |
| Plataforma | Android, Flutter y Firebase Spark |
| Usuarios | Individual y pareja |
| Primeros hábitos a eliminar | Azúcares y cigarrillo |
| Idioma de la app | Bilingüe, con inmersión graduable; usar la app es parte de la lección |
| Conexión entre apps | v1: archivos JSON y enlaces (contrato); v2: Firebase compartido solo para plan y seguimiento; MCP no se usa para esto |
| App de cuidados | Separada de las otras dos; los datos clínicos nunca entran a Hábitos ni a Presupuesto |
| IA | API de Claude (Consola de Anthropic, se paga aparte de Claude Pro); la app funciona sin IA; la clave no va dentro de la app |
| Finanzas | App aparte "Presupuesto y Alimentación" (individual, pareja o familiar), conectada por el contrato v1.0 (JSON, enlaces y Health Connect), sin compartir dinero |
| Horario laboral | Fijo: despertar 7:00, entrada 8:00, salida 18:00, llegada a casa ~19:00; traslado aprovechable |
| Gimnasio | Propio; las rutinas se generan a partir del inventario de aparatos |
| Tiempo diario de inglés | 50–60 min (bloque principal + traslado) más extras |
| Traslado | En auto, con la pareja (trabajan juntos): solo audio y manos libres, con actividades compartidas |
| Aparatos del gimnasio | Estación Marcy MWM-7119, banco inclinado y caminadora; pesas libres a futuro |
| Sueño | Meta del usuario: dormir y levantarse más temprano; la app propone una transición gradual de 15 min cada 3–4 días |
| Regreso del trabajo | Se planea como bloque de 1 hora (inglés y devocional en pareja) |
| Hábitos a eliminar | Cigarrillo: primer mes de reducción gradual y desde el segundo mes dejarlo de golpe; azúcar: alimentos muy regulados y refresco ocasional (Anexo F.14) |
| Frecuencia de entrenamiento | 3 a 5 días por semana, 2 regenerativos; sábados ruta en bicicleta |
| Bicicleta | Propia; rutas mixtas (calle y terreno); sábados a las 8:00, unas 4 horas; con visor de ruta y conexión con Spotify |
| Horario de entrenar | Fuerza de noche (después de las 19:00); cardio suave en la mañana con devocional breve; duración ajustable (30 / 45 / 60 min) |

**Preguntas abiertas**
1. ¿La integración con finanzas debe ser por cuenta única o con apps totalmente separadas?
2. ¿En pareja, quieren ver el progreso del otro de forma automática o solo lo que cada uno decida compartir?
3. Como la versión principal es RVR1960 y la secundaria NVI, ¿se resuelve la licencia desde el inicio o se arranca con RVR1909 mientras tanto?
4. ¿Contenido de inglés propio o apoyo en servicios externos (audios, pronunciación)?
5. ¿Tienes alguna condición médica que deba tomar en cuenta el módulo de ayuno, dieta o suplementos?
6. ¿La salida en bici del sábado es en pareja y a qué hora la haces normalmente?
7. ¿A qué hora quieres despertar al final de la transición (por ejemplo 6:00) y cuántas horas de sueño buscas?
8. ¿Tu pareja usará la app con su propia cuenta (también para el inglés y el traslado)?
9. ¿Trabajas de lunes a viernes, y a qué hora sales de casa en la mañana?
10. Después del área espiritual (Anexo D), ¿qué detallamos: pantallas, base de datos o el módulo de azúcar y cigarrillo?
11. ¿Quieres que la app de Presupuesto planee comidas para la persona bajo cuidado? (con reglas dietéticas mínimas y sin diagnóstico)
12. ¿Quién crea los integrantes (Presupuesto o Hábitos) y cómo se vinculan con los perfiles de cada app?


---

## Anexo A — Plan de lecciones de inglés (B1 → B2)

### A.1 Estructura general
- **Duración:** 24 semanas (6 módulos de 4 semanas), ajustable según el ritmo.
- **Sesión diaria:** 50–60 minutos en dos bloques (principal + traslado), más extras opcionales.
- **Semana 0:** prueba de nivel que confirma B1 y detecta debilidades en las cuatro habilidades.
- **Cada módulo** tiene un tema, gramática, vocabulario, foco de pronunciación, tarea de habla y una porción de la interfaz en inglés.
- **Cada módulo termina** con una prueba de las cuatro habilidades (se avanza con 80 % o más; si no, se refuerza una semana).

### A.2 Sesión diaria de 50–60 minutos

| Bloque | Min | Dónde | Qué se hace |
|---|---|---|---|
| **Principal** | 25–30 | Casa o descanso | Repaso espaciado (3), lección nueva (8–10), pronunciación grabada (5), producción escrita o hablada (8–10) |
| **Traslado** | 25–35 | Camino al trabajo (solo audio) | Escucha con preguntas por voz, shadowing y repaso de vocabulario por audio |
| **Extras** (opcional) | 10–20 | Cuando haya tiempo | Ver una serie o video con subtítulos, leer un texto graduado, diario en inglés, conversar en inglés con tu pareja, canciones, versículo en inglés |

- Si un día no hay traslado, el bloque se sustituye por una sesión de escucha y pronunciación en casa.
- Los **extras** suman a la racha pero no son obligatorios; la meta mínima del día es el bloque principal más el traslado.
- La app avisa si pasas de 60 min de estudio seguidos y propone pausa.

### A.3 Ritmo semanal
En el traslado de cada día se refuerza el enfoque del día (escucha, shadowing o repaso).

| Día | Enfoque |
|---|---|
| Lunes | Gramática + vocabulario nuevo |
| Martes | Escucha (audio y dictado) |
| Miércoles | Pronunciación (pares mínimos, ritmo, entonación) |
| Jueves | Lectura y escritura (diario en inglés) |
| Viernes | Conversación guiada con IA |
| Sábado | Repaso y mini prueba semanal |
| Domingo | Inglés ligero: versículo o devocional en inglés, canciones, video |

### A.4 Módulos

| Mód. | Semanas | Tema | Gramática | Pronunciación | Tarea de habla |
|---|---|---|---|---|---|
| 1 | 1–4 | Rutinas, hábitos y salud | Present simple vs continuous, adverbios de frecuencia, verbos de estado | Terminaciones -s/-es, acento de palabra | Describir tu día y tus hábitos |
| 2 | 5–8 | Experiencias y pasado | Past simple, present perfect, used to | Terminaciones -ed, formas débiles | Contar una experiencia importante |
| 3 | 9–12 | Planes y metas | Will, going to, presente continuo para futuro, primer condicional | Contracciones, entonación en preguntas | Explicar tus metas y cómo las lograrás |
| 4 | 13–16 | Trabajo y comunicación | Modales (deber, consejo, permiso), preguntas indirectas, correos | Acento de oración, unión de palabras | Simular una reunión o entrevista |
| 5 | 17–20 | Opiniones y comparaciones | Comparativos y superlativos, voz pasiva, segundo condicional | Sonido "th", vocales largas y cortas | Dar y defender una opinión |
| 6 | 21–24 | Relatos y fluidez | Pasado perfecto, estilo indirecto, oraciones de relativo, phrasal verbs | Ritmo y fluidez | Contar una historia de 2 minutos sin pausas largas |

**Vocabulario transversal** (conecta con las demás áreas): salud, gimnasio y alimentación; trabajo; fe y vida espiritual (versículos y oración en inglés); finanzas básicas; viajes y vida diaria.

### A.5 Interfaz como inmersión (progresiva)
| Semanas | % de la interfaz en inglés | Qué cambia |
|---|---|---|
| 1–4 | 10 % | Botones y etiquetas de navegación (Today, Goals, Streak) |
| 5–8 | 25 % | Mensajes de logro y recordatorios |
| 9–12 | 40 % | Títulos de tareas y agenda |
| 13–16 | 55 % | Resúmenes semanales y mensajes del coach |
| 17–20 | 70 % | Casi toda la app, con traducción al tocar |
| 21–24 | 85 % | Solo explicaciones difíciles en español |

El usuario puede subir, bajar o pausar el porcentaje en cualquier momento.

### A.6 Evaluación y progreso
- **Mini prueba semanal** (sábado) y **prueba de módulo** de cuatro habilidades.
- **Reporte por habilidad:** escucha, habla, lectura y escritura, con nivel estimado.
- **Palabras difíciles** vuelven automáticamente al repaso espaciado.
- **Meta de racha** con día de gracia semanal.
- Al terminar el módulo 6: **prueba final tipo B2** y plan siguiente (B2+ / examen oficial / inglés laboral).

### A.7 Pantallas del área de inglés
1. **Inicio de inglés:** lección de hoy, racha, nivel y módulo actual.
   - **Modo traslado:** botón grande para iniciar el audio del día, con control por voz.
2. **Lección:** tarjetas, ejercicio y audio.
3. **Escucha:** reproductor con velocidad y transcripción.
4. **Pronunciación:** grabar, ver la forma de onda y recibir comentarios.
5. **Conversación con IA:** chat y voz con escenarios.
6. **Vocabulario:** mazos y repaso.
7. **Progreso:** gráficas por habilidad y por módulo.
8. **Configuración de inmersión:** porcentaje de inglés en la app.

---

## Anexo B — Conexión con "Presupuesto y Alimentación": ajustes y observaciones al contrato v1.0

> La versión final del contrato (v1.2), con esquemas JSON, archivos de prueba, plan de integración por hitos y prompts para Claude Code, está en **`CONTRATO_CONEXION_APPS.md`**. Este anexo conserva el análisis que lo originó.

### B.1 Veredicto
El contrato es **sólido**: un solo escritor por tipo de dato, cada app funciona sin la otra, versión de esquema, pantalla de revisión, archivos tratados como no confiables y pruebas de aceptación. Necesita **aclaraciones y varios ajustes** antes de programar (B.3).

### B.2 Cambios aplicados a este diseño
1. Alimentación pasa a ser **cumplimiento del plan**; se eliminan de Hábitos los planes de comidas propios, la lista de compras y el cálculo de calorías/macros.
2. Se agrega **modo independiente** con registro simple de comidas y hábito de azúcar.
3. El plan importado puede crear **bloques de comida en la Agenda**.
4. El dinero no sale de la app: el ahorro por hábitos eliminados se queda como motivación local.
5. Se unifica el stack: **Flutter + Firebase Spark**.

### B.3 Observaciones al contrato

**A corregir o aclarar (prioridad alta)**
1. **Sección 8.2:** actualizar la instrucción para Hábitos. Ya no está "en papel": existe este documento de diseño; debe pedir que la sesión lo lea junto con el contrato.
2. **"Datos clínicos del paciente":** definir "paciente" como otra persona bajo cuidado, y aclarar que los datos de salud propios del usuario (peso, sueño, medidas) sí viven en Hábitos. **Confirmado:** es una persona bajo cuidado distinta del usuario; ver Anexo C.2.
3. **Peso y agua por dos vías** (JSON y Health Connect): elegir una. Recomendado: Health Connect, y quitar `peso_kg` y `agua_ml_dia` del JSON o dejarlos solo con consentimiento por campo.
4. **Reimportación (idempotencia):** agregar `revision` al plan; `plan_revision` y `registrado_en` (fecha y hora) a cada registro. Mismo `id` con revisión mayor reemplaza; misma revisión se ignora; en el seguimiento gana el registro más reciente.
5. **`sustituciones.alternativas`** trae solo claves (`LAC-002`): Hábitos no puede mostrarlas. Usar objetos con nombre, cantidad y unidad.
6. **Integrantes:** definir quién genera los `id` (ej. `m-ana`), cómo se vinculan con los perfiles de Hábitos en la primera importación y qué pasa si cambia el nombre.
7. **Versiones:** regla clara: misma versión mayor se acepta (con campos desconocidos ignorados); versión mayor distinta se rechaza.
8. **Zona horaria:** no fijar `America/Mexico_City`; usar la hora local del teléfono sin convertir.
9. **Recepción de archivos:** aceptar también `text/plain` y `application/octet-stream` con extensión `.json` y agregar un botón "Importar archivo" con selector de archivos (WhatsApp y Drive cambian el tipo MIME).
10. **Enlaces:** validar parámetros (fecha y tiempo) y no ejecutar escrituras ni importaciones desde un enlace; todo pasa por pantalla de confirmación. Otra app podría registrar el mismo esquema personalizado, así que no se envían datos por enlace.
11. **Privacidad de los archivos:** alergias y notas son datos de salud. Avisar al exportar y sugerir compartir directo a la otra app, no por mensajería ni nube.
12. **Límites de validación concretos:** 1 MB, máximo 14 días, 8 comidas por día, 200 caracteres por texto y 50 elementos por lista; mostrar texto plano (sin HTML ni Markdown).
13. **IA:** definir qué datos pueden enviarse a la IA (ver B.5); la sección 6 solo dice "nada sin configuración activada".

**Mejoras recomendadas (prioridad media)**
14. Ampliar la tabla de la sección 1 con las áreas de Hábitos (sueño, suplementos, bicicleta, agenda, inglés, espiritual, hábitos a eliminar): dueña Hábitos, no se comparte.
15. **Etiquetas estándar** en `platillo.etiquetas` (lista cerrada, ej. `azucar_alta`, `bebida_azucarada`, `sin_mariscos`) para que Hábitos relacione el plan con el hábito de azúcar.
16. **Ahorro sin dinero (opcional):** campo `habitos_evitados` con unidades (ej. refrescos no consumidos) para que Presupuesto calcule el ahorro con sus propios precios. Desactivado por defecto y por tipo; el cigarrillo es especialmente sensible.
17. **Reposición de suplementos (opcional):** una lista de necesidades sin precio que Presupuesto pueda sumar a su lista de compras.
18. **Health Connect:** agregar **sueño** y **sesiones de ejercicio** (incluida la ruta en bicicleta) como datos que escribe Hábitos. En Android 13 o anterior, Health Connect es una app aparte que debe estar instalada; verificar su estado antes de ofrecer la función, y si algún día se publica en Google Play, preparar la declaración de permisos de salud.
19. **Pruebas adicionales:** reimportar el mismo plan; plan revisado a mitad de semana; archivo `.json` recibido como `text/plain`; dos teléfonos con distinto `integrante`; enlace con parámetros inválidos; archivo de 2 MB; Android 13 sin Health Connect; archivo con versión menor 1.1.

### B.4 Pantallas nuevas en Hábitos por la conexión
1. **Plan de hoy** (desde Hoy y Agenda).
2. **Importar plan:** revisión, confirmación y vinculación del integrante.
3. **Marcar comida:** cumplida, parcial, sustituida u omitida.
4. **Exportar seguimiento semanal:** resumen y aviso de privacidad antes de compartir.
5. **Ajustes > Conexión:** estado de la otra app, permisos de Health Connect y qué se comparte.

### B.5 Observaciones técnicas para la implementación
- **Clave de la API de Claude:** nunca dentro de la app. El plan Spark de Firebase no permite desplegar Cloud Functions (requiere plan Blaze). Opciones: (a) uso personal con la clave del usuario guardada en el almacenamiento seguro del teléfono (Keystore), (b) un proxy externo gratuito con la clave en el servidor, (c) plan Blaze con alertas de gasto.
- **Base local como fuente principal;** Firestore solo para respaldo y sincronía de la pareja.
- **Recordatorios:** en Android 13 o superior hay que pedir el permiso de notificaciones; las alarmas exactas y el ahorro de batería pueden retrasar avisos.
- **Modo traslado:** Android Auto admite solo ciertas categorías de apps. Lo más simple es un reproductor de audio con sesión de medios y control por voz del teléfono vía Bluetooth; validar antes de comprometerse.
- **Programar con Claude Code:** dar a la sesión este documento y el contrato, y avanzar por etapas: núcleo, agenda, conexión por archivos y enlaces, y después Health Connect.

---

## Anexo C — Conexión entre apps, app de cuidados y estrategia de IA

### C.1 Cómo conectar las apps: opciones y recomendación

| Opción | Qué es | Ventajas | Límites | Veredicto |
|---|---|---|---|---|
| **Archivos JSON + enlaces** | Compartir un archivo y abrir pantallas con `habitos://` y `presupuesto://` | Funciona entre teléfonos distintos, sin servidor, privado, sencillo de probar | Es manual (botón Compartir) | **Etapa 1 (contrato v1.0)** |
| **Mismo dispositivo** (proveedor de contenido o servicio de Android) | Una app le ofrece datos a la otra en el mismo teléfono | Automático, sin internet | Solo en el mismo teléfono; ambas apps deben firmarse con la misma llave; no sirve entre los teléfonos de la pareja | Opcional, probablemente innecesaria |
| **Misma base de datos** (mismo proyecto de Firebase) | Las dos apps leen y escriben en el mismo proyecto, en colecciones separadas | Automático entre teléfonos y personas, con modo sin conexión | Riesgo de mezclar dinero y salud si las reglas de seguridad fallan; requiere cuenta y diseño cuidadoso | **Etapa 2**, solo para plan y seguimiento |
| **MCP** | Protocolo para que un modelo de IA use herramientas y datos | Útil para que una IA consulte fuentes | No sirve para sincronizar dos apps entre sí | **No usar para esto** |

**Recomendación por etapas**
1. **Etapa 1:** archivos JSON y enlaces, tal como el contrato. Es lo más simple y lo más privado.
2. **Etapa 2 (si cansa lo manual):** un solo proyecto de Firebase con una colección compartida (`compartido/hogar/...`) para el **plan** y el **seguimiento**. El archivo JSON se mantiene como respaldo y exportación.
3. **Health Connect** para peso, agua, comidas, sueño y ejercicio (según el contrato).

**Reglas si se usa Firebase compartido**
- Cada app es una app Android distinta dentro del mismo proyecto (paquetes diferentes).
- Colecciones separadas: `presupuesto/...` solo la lee y escribe la app de Presupuesto; `habitos/...` solo Hábitos; `compartido/...` ambas, solo con plan y seguimiento.
- **El dinero nunca va en `compartido`.**
- Reglas de seguridad por usuario y por hogar, probadas con casos de acceso denegado.
- Se mantiene "un solo escritor por tipo de dato".

### C.2 App de cuidados (persona bajo cuidado)
- Es una app **futura y separada**. Debe tener su propio proyecto de base de datos o ser solo local, **sin conexión automática** con Hábitos ni Presupuesto.
- Los **datos clínicos** de la persona (diagnóstico, medicamentos, citas, comportamiento) **nunca** entran a Hábitos ni a Presupuesto ni a la IA de estas apps.
- Si Presupuesto arma comidas para esa persona, se usan solo **reglas dietéticas mínimas** (alergias, exclusiones, texturas), **sin diagnóstico**.
- Propuesta para el contrato: agregar `tipo_integrante` (`adulto` o `persona_bajo_cuidado`). Para `persona_bajo_cuidado`: sin IA, sin Health Connect, sin exportaciones por mensajería y con seguimiento registrado por el cuidador.
- El consentimiento lo da quien la representa; hay que revisar con la familia cómo se decide y quién tiene acceso.
- Los cuidadores también necesitan descanso: la agenda de Hábitos puede incluir bloques de autocuidado y de apoyo familiar.

### C.3 IA con Claude

**Claude Pro y la API son productos distintos.** Una suscripción Pro da acceso a Claude en web, escritorio y móvil, mientras que la **API se factura aparte** desde la Consola de desarrolladores. Para que la app use Claude hay que crear una cuenta en la Consola, cargar crédito y definir un límite de gasto.
- **Claude Pro sí te sirve** para diseñar y revisar en chat (como este documento) y para programar las apps con Claude Code, con límites de uso.
- **Claude Pro no sirve** como motor de IA dentro de la app.

**Principios**
1. **La app funciona sin IA** (modo básico): rachas, agenda, recordatorios, rutinas y plan de inglés con reglas y contenido fijo.
2. **La IA es opcional**, se activa por función y aporta donde marca diferencia.
3. **Lo barato primero:** reglas y plantillas locales, voz del teléfono, caché y resúmenes antes de llamar a la API.

| Función | Tipo de modelo sugerido | Frecuencia | Nota de costo |
|---|---|---|---|
| Revisión semanal y mensual del coach | Más capaz | 1 vez por semana | Pocas llamadas |
| Generar rutinas con tu inventario | Más capaz | Al crear o cambiar el plan | Guardar el resultado |
| Tutor de inglés (conversación y corrección) | Rápido y económico | Diario | Mensajes cortos, historial resumido |
| Lecciones y ejercicios | Rápido y económico | Por lotes | Generar una vez y guardar en caché |
| Pronunciación y escucha | Voz del teléfono (reconocimiento y síntesis) | Diario | Sin costo de API; la IA solo evalúa el texto |
| Apoyo ante antojos y ánimo | Plantillas locales primero; IA si se pide | Eventual | Respuestas breves |

**Control de gasto**
- Límite mensual en la Consola y límite diario por persona dentro de la app.
- Recortar el historial y resumir conversaciones largas.
- Reutilizar contenido ya generado.
- Mostrar al usuario cuánto ha usado.

**Dónde vive la clave** (la clave nunca va dentro de la app)
1. **Uso personal y de pareja:** cada persona pega su clave de la Consola y se guarda en el almacenamiento seguro del teléfono. Es lo más simple para empezar.
2. **Si crece:** un proxy externo con la clave en el servidor, con límites por persona.
3. **Plan Blaze de Firebase:** solo si se aceptan funciones en la nube, con alertas de gasto.

**Privacidad y seguridad de la IA**
- Se envía lo mínimo, sin nombres ni alergias, y **nunca datos de la persona bajo cuidado**.
- No se guardan conversaciones sensibles más tiempo del necesario.
- Avisos claros: la IA **no sustituye** a un médico, un psicólogo ni un pastor.
- El coach de la fe sugiere y acompaña, pero no reemplaza el consejo pastoral.

### C.4 Siguiente paso sugerido
1. Cerrar el contrato **v1.1** con los cambios del Anexo B y `tipo_integrante`.
2. Empezar a programar Hábitos por etapas: núcleo, agenda, conexión por archivos y enlaces.
3. Dejar la IA para después, con el modo básico funcionando primero.

---

## Anexo D — Área espiritual (Biblia, devocional, oración y ayuno)

### D.1 Principios
1. **La Escritura es la fuente;** la app acompaña, no la reemplaza ni la interpreta con autoridad.
2. **Constancia sin legalismo:** los registros ayudan a formar el hábito; no miden la fe ni "puntúan" la espiritualidad de nadie.
3. **Sin culpa:** si se pierden días, la app ayuda a retomar (ponerse al día o saltar), no reclama.
4. **Privacidad máxima** para oración, diario y notas: privados por defecto y sin enviarse a ninguna IA salvo acción explícita del usuario.
5. **Personalizable:** versión bíblica, ritmo de lectura y método de estudio los elige el usuario.
6. **Se integra con la vida diaria:** agenda, traslado, sueño, inglés y hábitos a eliminar.

### D.2 Pantalla "Espiritual hoy"
Muestra lo que toca hoy, en este orden y con un toque cada uno:
1. Lectura del plan (con botón de audio).
2. Devocional del día.
3. Versículo para memorizar (repaso).
4. Peticiones de oración del día.
5. Ayuno activo (si lo hay) con temporizador.
6. Nota rápida o gratitud.

Incluye el versículo del día, la racha suave (con día de gracia) y un acceso rápido a "Oración en pareja".

### D.3 Lector bíblico

| Función | Detalle |
|---|---|
| Versiones | Varias, con cambio rápido (ver D.12 para licencias) |
| Lectura paralela | Dos versiones lado a lado (ej. Dios Habla Hoy y una versión de estudio, o español e inglés) |
| Comparador | El mismo versículo en 2 a 4 versiones |
| Notas | Por versículo, con etiquetas (ej. promesa, mandato, oración) |
| Subrayado | Colores con significado que define el usuario |
| Marcadores y favoritos | Versículos y pasajes |
| Referencias cruzadas | Pasajes relacionados al tocar un versículo |
| Búsqueda | Por palabra, frase o referencia |
| Concordancia | Todas las apariciones de una palabra (con números Strong cuando haya fuente) |
| Diccionario bíblico | Al tocar una palabra, personaje o lugar |
| Audio | Lectura narrada, con velocidad ajustable; sirve para el traslado |
| Lectura cómoda | Tamaño de letra, modo oscuro y brillo bajo para leer de noche |
| Sin conexión | Versiones y planes descargados |

### D.4 Planes de lectura

| Plan | Duración orientativa | Ritmo aproximado |
|---|---|---|
| Biblia en un año (canónico o cronológico) | 365 días | Unos 3 capítulos diarios |
| Nuevo Testamento | 90 días | Unos 3 capítulos diarios (260 capítulos) |
| Salmos y Proverbios | 30 días | 5 Salmos o 1 Proverbio por día |
| Evangelios | 60 días | Según el libro |
| Por libro (ej. Romanos, Juan) | A elección | A elección |
| Temático (ej. oración, fe, perseverancia) | A elección | Pasajes seleccionados |
| Personalizado | A elección | El usuario arma el plan |

- **Retraso sin culpa:** si se atrasa, la app ofrece **ponerse al día** (repartir lo pendiente en los siguientes días), **saltar** o **reiniciar** el tramo.
- **Plan en pareja:** el mismo plan, cada quien avanza a su ritmo; se ve cuánto avanza el otro solo si decide compartirlo.
- **Plan + audio:** el capítulo del día puede reproducirse durante el traslado.
- El tiempo estimado de lectura aparece en la agenda como bloque.

### D.5 Estudio bíblico (método guiado)
Plantillas para estudiar un pasaje:

| Método | Pasos |
|---|---|
| **OIA** | **Observación** (¿qué dice?) → **Interpretación** (¿qué significó?) → **Aplicación** (¿qué hago?) |
| **SOAP** | **S**cripture (pasaje) → **O**bservación → **A**plicación → **P**rayer (oración) |

- Preguntas guía en cada paso: ¿quién, qué, cuándo, dónde, por qué?, ¿qué enseña de Dios?, ¿qué enseña de mí?, ¿qué cambia hoy?
- Contexto del pasaje (autor, época, género literario) cuando haya contenido disponible.
- Los estudios quedan guardados y se pueden retomar o exportar.
- Las notas del estudio enlazan con la oración y con un objetivo si hay una aplicación práctica.

### D.6 Devocional
**Flujo diario sugerido (10 a 15 min):** lectura → reflexión → aplicación → oración.

| Tipo | Descripción |
|---|---|
| **Devocional del plan** | Se arma sobre el pasaje del plan de lectura del día |
| **Mi devocional** | Plantilla para escribir el propio (observación, aplicación, oración) |
| **Packs de devocionales** | Devocionales de editoriales o autores, **solo con permiso o licencia** |
| **Devocional en audio** | Para el traslado de regreso, en pareja |

- Si se usa IA (opcional), solo ayuda con **preguntas de reflexión** y **contexto del pasaje**; no inventa doctrina ni sustituye el estudio personal (ver D.13).
- Cada entrada guarda fecha, pasaje, reflexión, aplicación y oración.
- Hay una opción de **devocional breve** de 5 min para días de poco tiempo.

### D.7 Oración
- **Diario de oración:** peticiones con fecha, categoría y estado (**pendiente, en espera, respondida**).
- **Guía de oración:** adoración, confesión, gratitud y petición (método ACTS) como estructura opcional.
- **Listas de intercesión:** familia, iglesia, enfermos, nación, trabajo (por días de la semana si se quiere).
- **Oraciones respondidas:** registro con fecha y cómo respondió Dios, para recordar su fidelidad.
- **Temporizador** de oración con registro de minutos.
- **Recordatorios** suaves (ej. antes de dormir, al salir del trabajo).
- **Modo voz** en el traslado: guía por audio con pausas para orar.
- **Oración en pareja:** peticiones compartidas y respondidas; cada petición se marca como privada o compartida.
- Todo el diario de oración es **privado por defecto** y no se envía a ninguna IA.

### D.8 Memorización de versículos
- Se agregan versículos desde el lector o a mano.
- **Repaso espaciado** (el mismo motor que el vocabulario de inglés).
- **Niveles de práctica:** leer, completar palabras, ordenar frases, escribir y decir en voz alta.
- **Modo traslado:** repaso por voz, sin pantalla.
- **Versículos en inglés:** opción de memorizar el mismo versículo en español e inglés para reforzar el idioma.
- Se pueden armar **colecciones** (ej. ánimo ante antojos, fe, sabiduría) y usarlas en otras áreas.

### D.9 Ayuno
**Tipos**
| Tipo | Descripción |
|---|---|
| Omitir comida(s) | Ayuno de una o más comidas en un día |
| Parcial (ej. tipo Daniel) | Sin ciertos alimentos, con otros permitidos |
| Líquidos o con agua | Más exigente; ver seguridad |
| Ayuno de otras cosas | Pantallas, redes sociales, azúcar, entretenimiento |

**Funciones**
- Planificador: tipo, duración, **propósito** y pasaje base.
- Temporizador, diario del ayuno y guía de oración durante el día.
- **Romper el ayuno de forma suave:** recomendación de comida ligera y agua.
- **Hidratación** y recordatorios de agua según el tipo.
- Se refleja en la **agenda** y se coordina con el plan de entrenamiento y la dieta.

**Seguridad**
- Antes del primer ayuno, la app pregunta si hay **condiciones de salud, medicamentos, embarazo o lactancia, antecedentes de trastornos alimentarios** u otra situación que requiera orientación médica; si es así, recomienda hablar antes con un médico y no propone ayunos de comida ni de líquidos.
- Los **ayunos prolongados** requieren supervisión médica.
- Si aparecen mareo, debilidad intensa, confusión u otros síntomas preocupantes, la app indica **interrumpir el ayuno** y buscar atención.
- No se programan sesiones de fuerza intensas en días de ayuno de comida.
- Si el usuario está reduciendo azúcar o tabaco, el **ayuno de comida no se usa como castigo ni para compensar** recaídas.

### D.10 Pareja y familia en lo espiritual
- **Devocional compartido:** leer el mismo pasaje y comentar.
- **Peticiones compartidas** y oraciones respondidas.
- **Plan de lectura juntos** con avance opcional del otro.
- **"Estoy orando por ti":** aviso opcional.
- **Revisión espiritual semanal en pareja** (sábado tras la revisión personal, o domingo): gratitud, aprendizaje de la semana y peticiones.
- **Privacidad por elemento:** cada nota, petición o estudio es privado o compartido.

### D.11 Iglesia y comunidad
- **Agenda de la iglesia:** cultos, reuniones y grupos en la agenda, con recordatorio.
- **Notas de predicación:** pasaje, puntos principales y aplicación de la semana.
- **Aplicación semanal:** una acción concreta ligada a un objetivo.
- **Servicio y ministerio:** tareas y horarios de servicio.
- **Contactos de oración** (opcional) para peticiones por personas de la iglesia.

### D.12 Contenido, versiones y licencias ⚠️

| Fuente | Qué hay que revisar |
|---|---|
| Versiones de dominio público (ej. Reina-Valera 1909, KJV, WEB, ASV) | Suelen poder incluirse sin costo; confirmar la edición exacta y su origen |
| Versiones con derechos (ej. RVR1960, NVI, DHH, NTV, LBLA) | Requieren licencia o acuerdo con el titular; confirmar condiciones, límites de uso, atribución y descarga sin conexión |
| Servicios de API de contenido bíblico (ej. API.Bible) | Verificar qué versiones ofrecen, términos de uso y límites |
| Números Strong y diccionarios | Strong es de dominio público; para diccionarios, confirmar la licencia (los clásicos en inglés como Easton o Smith suelen ser de dominio público; en español hay menos opciones) |
| Devocionales de terceros | Solo con permiso o licencia |

**Tu elección:** versión principal **RVR1960** y secundaria **NVI**. Ambas tienen derechos, así que la licencia o el acceso por servicio es el **primer pendiente** del área espiritual.
- **Mientras se resuelve:** desarrollar y probar con **Reina-Valera 1909** y **KJV** (dominio público), con la misma estructura de datos para cambiar de versión sin rehacer nada.
- Los diccionarios en inglés sirven además como **práctica de inglés**.

### D.13 IA en el área espiritual
**Permitido (opcional, por función):**
- Preguntas de reflexión sobre el pasaje.
- Contexto histórico y cultural, citando de dónde sale.
- Resumir las **notas del propio usuario** (si lo pide).
- Ayudar a **encontrar pasajes por tema**.
- Ayudar a redactar una oración **solo si el usuario lo pide**.

**Límites:**
- No sustituye al pastor, a la iglesia ni a la Escritura.
- No da "mensajes de Dios" ni dirección personal sobre decisiones importantes.
- Ante temas doctrinales debatidos, presenta las posturas con los pasajes y sugiere conversarlo con el pastor o la comunidad.
- Si el usuario expresa crisis emocional, duelo severo u otro riesgo, responde con cuidado y lo orienta a **apoyo humano** (persona de confianza, pastor, profesional).
- **El diario de oración y las peticiones no se envían a la IA** salvo que el usuario elija enviar algo en concreto.

### D.14 Modelo de datos (borrador)

| Entidad | Campos principales |
|---|---|
| `VersionBiblica` | id, nombre, idioma, licencia, descargada |
| `Lectura` | id, fecha, libro, capitulo, inicio, fin, minutos, plan_id (opcional) |
| `PlanLectura` | id, tipo, nombre, fecha_inicio, ritmo, estado, compartido |
| `ProgresoPlan` | plan_id, dia, estado (pendiente, hecho, saltado), fecha_hecho |
| `NotaBiblica` | id, referencia, texto, etiquetas, version_id, privacidad |
| `Subrayado` | id, referencia, color, version_id |
| `Marcador` | id, referencia, titulo |
| `Estudio` | id, pasaje, metodo (OIA, SOAP), campos, fecha |
| `EntradaDevocional` | id, fecha, pasaje, reflexion, aplicacion, oracion, objetivo_id (opcional) |
| `PeticionOracion` | id, texto, categoria, estado, fecha_creada, fecha_respondida, nota_respuesta, privacidad |
| `SesionOracion` | id, fecha, minutos, tipo, compartida |
| `VersiculoMemorizar` | id, referencia, version_id, nivel, proxima_revision, coleccion |
| `Ayuno` | id, tipo, inicio, fin, proposito, estado, diario |
| `NotaPredicacion` | id, fecha, predicador, pasaje, puntos, aplicacion |
| `ElementoCompartido` | id, tipo, referencia_id, con_quien, fecha |
| `EstudioGuiado` | id, titulo, objetivo, tipo (tema, libro, personaje, propio), sesiones, version_catalogo |
| `SesionEstudio` | id, estudio_id, orden, pasajes, preguntas, versiculo_memorizar, oracion |
| `ProgresoEstudio` | id, estudio_id, sesion_id, estado, fecha, notas |
| `EstudioMetodo` | id, metodo (exegesis, inductivo, palabras, personaje, libro, tematico), pasaje, nivel, pasos (respuestas), conclusiones |
| `PrincipioEstudio` | id, estudio_id, sesion_id, principio, pasaje, area |
| `CompromisoPractica` | id, principio_id, accion, metrica, frecuencia, duracion, objetivo_id (opcional), compartido, estado |
| `CheckinPractica` | id, compromiso_id, fecha, estado (hecho, parcial, no), nota |
| `RevisionPractica` | id, compromiso_id, semana, aprendizaje, dificultad, ajuste |

Todos con `creado`, `actualizado` y `privacidad` (privado o compartido). Por ahora, nada de esto se envía a la app de Presupuesto.

### D.15 Métricas y revisión
- **Métricas de hábito:** días de lectura, capítulos, minutos de oración, devocionales completados, versículos memorizados, ayunos completados, peticiones respondidas.
- **No se compara ni se "califica" la vida espiritual:** son indicadores de constancia, no de fe.
- **Revisión semanal reflexiva:** ¿qué aprendí?, ¿qué agradezco?, ¿qué pido?, ¿qué obedezco esta semana?
- Gráficas simples y un calendario de constancia con día de gracia.

### D.16 Integración con las otras áreas
| Con | Cómo se conecta |
|---|---|
| Agenda | Devocional de 6:10 a 6:25; lectura y oración como bloques; cultos y reuniones de iglesia |
| Traslado | Biblia y devocional en audio, oración guiada, repaso de versículos |
| Sueño | Oración o lectura breve en la rutina previa al sueño |
| Hábitos a eliminar | Colección de versículos de ánimo y botón de ayuda ante un antojo |
| Inglés | Versículos y vocabulario bíblico en inglés; diccionario en inglés |
| Salud | Ayuno coordinado con dieta, hidratación y entrenamiento |
| Pareja | Devocional, peticiones y plan compartidos |

### D.17 Pantallas del área espiritual
1. **Espiritual hoy.**
2. **Lector** (con paralelo y comparador).
3. **Planes de lectura** (crear, ver, ponerse al día).
4. **Estudio** (plantilla OIA o SOAP).
5. **Devocional** (del plan, propio o por audio).
6. **Oración:** diario, listas, respondidas y temporizador.
7. **Memorización** (repaso y colecciones).
8. **Ayuno:** planificar, temporizador y diario.
9. **Iglesia:** agenda y notas de predicación.
10. **Pareja:** compartido y revisión semanal.
11. **Estudios guiados:** catálogo, sesiones y progreso.
12. **Mis prácticas:** compromisos, check-ins y revisión (ver D.23).
13. **Ajustes espirituales:** versión principal, método, recordatorios, privacidad, descargas.

### D.18 Etapas
| Etapa | Contenido |
|---|---|
| **MVP espiritual** | Lector con RVR1960 y NVI (si se resuelve la licencia) o, mientras tanto, RVR1909 y KJV, plan de lectura, notas y subrayados, devocional con plantilla, diario de oración, recordatorios y bloque en agenda |
| **v1.1** | Versiones con licencia, comparador, memorización, audio y modo traslado |
| **v1.2** | Ayuno con seguridad, notas de predicación e iglesia |
| **v1.3** | Estudios guiados con "de la Biblia a la práctica" y estudio por métodos (exégesis intermedia) |
| **v2** | Concordancia, diccionarios, exégesis avanzada (texto original), pareja y compartir, IA opcional |

### D.19 Preguntas abiertas
1. ¿Qué comentarios, libros o maestros quieres tener como fuentes de consulta confiables?
2. ¿Ya ayunas? ¿Con qué frecuencia y de qué tipo?
3. ¿Oran en pareja todos los días y a qué hora?
4. ¿Qué días y horarios tienen de iglesia o grupo?

### D.20 Estudios guiados por tema
Cursos cortos con una secuencia de pasajes, preguntas y aplicación.

**Estructura de un estudio guiado**
| Elemento | Detalle |
|---|---|
| Título y objetivo | Qué se quiere entender y vivir |
| Duración | De 5 a 8 sesiones (una o dos por semana, o una por día) |
| Cada sesión | Pasaje(s), contexto breve, preguntas de observación, interpretación y aplicación, referencias cruzadas, versículo para memorizar, oración sugerida y espacio de notas |
| Cierre | Resumen del estudio, lo que aprendí y una acción concreta ligada a un objetivo |
| Progreso | Sesiones completadas, notas guardadas y repetir el estudio |
| Pareja | Opción de hacerlo juntos y comentar |

**Catálogo inicial** (borrador editable)

| Estudio | Sesiones y pasajes clave |
|---|---|
| **La salvación** | 1) Nuestra necesidad: Romanos 3:9-26. 2) La gracia: Efesios 2:1-10. 3) La fe y el arrepentimiento: Juan 3:16-21; Hechos 3:19. 4) La justificación: Romanos 5:1-11. 5) La seguridad: Juan 10:27-30; Romanos 8:31-39. 6) La vida nueva: 2 Corintios 5:17; Gálatas 2:20 |
| **El amor** | 1) El amor de Dios: Juan 3:16; 1 Juan 4:7-21. 2) El amor de Cristo: Romanos 5:8; Juan 15:9-17. 3) Cómo es el amor: 1 Corintios 13. 4) Amar al prójimo: Lucas 10:25-37; Mateo 22:36-40. 5) Amar a los enemigos: Mateo 5:43-48. 6) El amor en el matrimonio: Efesios 5:21-33 (en pareja) |
| **La fe** | Hebreos 11; Romanos 4; Santiago 2:14-26; Marcos 9:14-29 |
| **La oración** | Mateo 6:5-15; Lucas 11:1-13; Filipenses 4:6-7; Juan 17 |
| **El Espíritu Santo** | Juan 14-16; Hechos 2; Romanos 8; Gálatas 5:16-26 |
| **El perdón** | Mateo 18:21-35; Efesios 4:32; Colosenses 3:12-14 |
| **Dominio propio y vencer hábitos** | Gálatas 5:16-25; 1 Corintios 10:13; Romanos 6:11-14; Tito 2:11-14 (se conecta con el módulo de hábitos a eliminar) |
| **Matrimonio y pareja** | Génesis 2:18-24; Eclesiastés 4:9-12; Efesios 5:21-33; 1 Pedro 3:1-7 |
| **Trabajo y vocación** | Colosenses 3:23; Génesis 2:15; Proverbios (selección) |
| **Cuidar el cuerpo y la salud** | 1 Corintios 6:19-20; Daniel 1; Proverbios (selección) |
| **Ansiedad y confianza en Dios** | Mateo 6:25-34; Filipenses 4:6-7; 1 Pedro 5:7; Salmo 23 |
| **Ayuno** | Mateo 6:16-18; Isaías 58; Joel 2; Hechos 13:2-3 (se conecta con el módulo de ayuno) |
| **Sufrimiento y esperanza** | Romanos 8:18-39; 2 Corintios 1:3-7; 2 Corintios 4:16-18; Salmo 34:18 |
| **Familia y honrar a los padres** | Éxodo 20:12; 1 Timoteo 5:4 y 8; Proverbios 23:22 |
| **Panorámicos** | Sermón del Monte (Mateo 5-7); Fruto del Espíritu (Gálatas 5); Carácter de Dios |

- El usuario puede **crear estudios propios** con la misma estructura (título, sesiones, pasajes y preguntas) y guardarlos.
- Los estudios se **recomiendan según el momento**: por ejemplo, el de "dominio propio" ante un antojo recurrente o el de "ansiedad" tras una semana pesada (siempre como sugerencia y nunca como obligación).
- Las preguntas y el contexto de cada sesión son **contenido propio**; los textos bíblicos vienen de la versión elegida por el usuario.
- Los pasajes y las sesiones del catálogo se revisan antes de publicar; es una guía de estudio, no una doctrina de la app.

### D.20.1 Estudios prioritarios (detalle)
Prioridad del usuario: **salvación, amor, Espíritu Santo, Cristología, perdón y administración**. La salvación y el amor ya están detallados arriba; aquí van los demás.

**El Espíritu Santo** (8 sesiones)
| Sesión | Tema | Pasajes |
|---|---|---|
| 1 | Quién es: una persona divina | Juan 14:15-26; Hechos 5:3-4; 2 Corintios 13:14; Mateo 28:19 |
| 2 | Su obra en el Antiguo Testamento y la promesa | Génesis 1:2; Salmo 51:11; Joel 2:28-29 |
| 3 | Su obra en la salvación: convence y regenera | Juan 16:7-15; Juan 3:5-8; Tito 3:5 |
| 4 | Morada y sello | Romanos 8:9-17; Efesios 1:13-14; 1 Corintios 6:19 |
| 5 | Bautismo y llenura | Hechos 1:8; Hechos 2:1-21; 1 Corintios 12:13; Efesios 5:18 |
| 6 | Dones | 1 Corintios 12-14; Romanos 12:3-8 |
| 7 | Fruto | Gálatas 5:16-26 |
| 8 | Guía y oración | Romanos 8:14 y 26-27; Juan 16:13 |

**Cristología** (8 sesiones)
| Sesión | Tema | Pasajes |
|---|---|---|
| 1 | Su deidad | Juan 1:1-18; Colosenses 1:15-20; Hebreos 1:1-4 |
| 2 | Su humanidad | Lucas 2:1-20; Hebreos 2:14-18; Hebreos 4:14-16 |
| 3 | La encarnación | Mateo 1:18-25; Lucas 1:26-38; Filipenses 2:5-11 |
| 4 | Su ministerio y enseñanza | Marcos 1:14-45; Mateo 5-7 (selección) |
| 5 | Sus títulos y los "Yo soy" | Juan 6:35; 8:12; 10:11; 11:25; 14:6; 15:1 |
| 6 | Su muerte y la expiación | Isaías 53; Romanos 3:21-26; 1 Pedro 2:21-25 |
| 7 | Su resurrección y ascensión | Lucas 24; 1 Corintios 15:1-28; Hechos 1:1-11 |
| 8 | Su reinado y su regreso | Filipenses 2:9-11; 1 Tesalonicenses 4:13-18; Apocalipsis 19:11-16 |

**El perdón** (6 sesiones)
| Sesión | Tema | Pasajes |
|---|---|---|
| 1 | El perdón de Dios hacia nosotros | Salmo 103:1-14; Efesios 1:7; 1 Juan 1:9 |
| 2 | El siervo que no perdonó | Mateo 18:21-35 |
| 3 | Perdonar a otros | Colosenses 3:12-14; Efesios 4:31-32; Marcos 11:25 |
| 4 | Reconciliación y confrontación | Mateo 18:15-20; Mateo 5:23-24; Romanos 12:17-21 |
| 5 | Vivir libre de la condenación | Romanos 8:1; Salmo 32 |
| 6 | Ejemplos: José y Esteban | Génesis 45 y 50:15-21; Hechos 7:54-60 |

- Nota de cuidado: **perdonar no significa permanecer en peligro**. Si hay violencia, abuso o amenaza, la app orienta a buscar protección y apoyo (persona de confianza, pastor, profesional) y no presenta la reconciliación como obligación inmediata.

**La administración (mayordomía)** (8 sesiones)
| Sesión | Tema | Pasajes |
|---|---|---|
| 1 | Todo es de Dios | Salmo 24:1; 1 Crónicas 29:11-16; Deuteronomio 8:17-18 |
| 2 | El mayordomo fiel | Lucas 16:1-13; 1 Corintios 4:1-2 |
| 3 | Los talentos | Mateo 25:14-30 |
| 4 | Dinero, planificación y contentamiento | Proverbios 21:5; Proverbios 22:7; Lucas 14:28-30; 1 Timoteo 6:6-10; Hebreos 13:5 |
| 5 | Diezmos y ofrendas: principios | Génesis 14:18-20; Génesis 28:20-22; Levítico 27:30; Malaquías 3:8-12; Mateo 23:23; 1 Corintios 16:1-2; Proverbios 3:9-10 |
| 6 | Generosidad y el corazón | 2 Corintios 8:1-15; 2 Corintios 9:6-15; Lucas 21:1-4; Mateo 6:19-21; Hechos 4:32-35 |
| 7 | Tiempo y cuerpo | Efesios 5:15-17; Salmo 90:12; 1 Corintios 6:19-20 |
| 8 | Trabajo, descanso y compartir | Colosenses 3:23; Efesios 4:28; Génesis 2:2-3 |

- Nota: sobre el dar (diezmos y ofrendas) hay distintas posturas entre las iglesias evangélicas. La app **presenta los textos y no fija montos ni porcentajes**; el usuario decide con su iglesia y su familia, y se sugiere conversarlo con su pastor.
- Hábitos **no guarda montos**: solo registra si se cumplió el compromiso de dar. Si el usuario quiere llevar las cifras, las anota en la app de Presupuesto.
- La administración abarca **tiempo, talentos, cuerpo y dinero**; el estudio se conecta con la agenda, el entrenamiento, el sueño y, en el dinero, con la app de Presupuesto (sin compartir montos con Hábitos).

### D.21 Estudio por métodos
Asistente paso a paso que guía el estudio de un pasaje según el método elegido, con las herramientas del lector a la mano (versiones, concordancia, diccionarios, referencias cruzadas).

| Método | Para qué sirve | Pasos principales |
|---|---|---|
| **Exégesis** | Entender lo que el texto significó para sus primeros lectores | Ver abajo |
| **Inductivo (OIA)** | Estudio personal de un pasaje | Observación, interpretación y aplicación |
| **SOAP** | Devocional diario con registro | Escritura, observación, aplicación y oración |
| **Estudio de palabras** | Profundizar en un término clave | Elegir palabra, ver su original (Strong), sus usos en la Biblia y su definición, y sintetizar |
| **Estudio de personaje** | Aprender de una vida bíblica | Quién es, contexto, decisiones, relación con Dios, lecciones |
| **Estudio de un libro** | Ver el panorama | Autor, fecha, destinatarios, tema, versículo clave, bosquejo y aplicación |
| **Estudio temático** | Seguir un tema por la Biblia | Concordancia, referencias cruzadas y síntesis |
| **Meditación bíblica** | Interiorizar un pasaje corto | Leer despacio, repetir, preguntar, orar y responder |

**Exégesis paso a paso**
1. **Contexto histórico y literario:** autor, destinatarios, fecha, ocasión y **género literario** (narrativa, poesía, profecía, epístola, parábola, ley).
2. **Texto:** leer en **varias versiones** (RVR1960, NVI y otras) y anotar diferencias.
3. **Estructura:** dividir el pasaje en unidades y escribir un **bosquejo**.
4. **Observación del texto:** palabras clave, repeticiones, contrastes, conectores ("pues", "por tanto") y verbos.
5. **Estudio de palabras:** buscar los términos importantes en la **concordancia** (con números Strong, si hay fuente) y en el **diccionario bíblico**.
6. **Contexto inmediato y del libro:** qué viene antes y después, y el tema general del libro.
7. **Contexto bíblico y teológico:** **referencias cruzadas** y cómo encaja con el resto de la Escritura.
8. **Interpretación:** qué significó para los primeros lectores y cuál es la idea principal.
9. **Principio y aplicación:** el principio permanente y la acción concreta hoy.
10. **Oración:** responder a Dios con lo aprendido.

- **Niveles:** básico (pasos 1-4 y 9), intermedio (todos, con las herramientas de la app) y avanzado (con apoyo del texto original). **Nivel elegido por el usuario: intermedio y avanzado.**

**Nivel avanzado (texto original)**
- **Texto original** (griego del Nuevo Testamento y hebreo del Antiguo) con transliteración y, si hay fuente, **interlineal** junto a la versión en español.
- **Números Strong, léxicos y análisis de palabras** (tiempo verbal, caso, número) cuando el contenido esté disponible.
- **Variantes textuales** y notas de traducción, para entender por qué RVR1960 y NVI difieren en ciertos pasajes.
- **Estructura y bosquejo:** frases y conectores, con un esquema del argumento del pasaje.
- **Comentarios y obras de consulta** como fuentes (solo con licencia o de dominio público).
- **Mini-curso opcional** para leer el interlineal: alfabeto griego y hebreo, tiempos verbales y partículas básicas.
- **Entregable:** resumen exegético exportable (texto o PDF) con contexto, observaciones, interpretación y aplicación.
- **Licencias:** los textos originales y léxicos clásicos suelen ser de dominio público, pero hay que confirmar la edición y la fuente antes de incluirlos.
- **Guía de género:** consejos para leer cada tipo de texto (por ejemplo, cómo leer una parábola o un salmo).
- **Errores comunes:** avisos como sacar un versículo de su contexto o leer en el texto lo que ya creemos.
- **Contrastar:** la app sugiere comparar con comentarios confiables, con tu pastor o con la comunidad antes de dar una conclusión por definitiva.
- **IA opcional:** puede ayudar con contexto histórico y preguntas, y siempre debe indicar de dónde sale la información (ver D.13).

### D.22 Ruta de inicio (sin plan de lectura previo)
Como hoy no hay un plan ni un devocional en marcha, la app propone empezar **poco a poco**:

| Fase | Duración | Qué se hace |
|---|---|---|
| **1. Arrancar** | 21 días | Evangelio de Juan, 1 capítulo por día, con devocional breve de 5 a 10 min en la mañana |
| **2. Profundizar** | 4 a 6 semanas | Romanos (16 capítulos) o Salmos y Proverbios, más el estudio guiado **"La salvación"** (1 o 2 sesiones por semana) |
| **3. Consolidar** | 90 días | Nuevo Testamento completo, con el estudio guiado **"El amor"** y el primer estudio por método (exégesis básica) |

- La meta de la fase 1 es **formar el hábito**, no leer mucho. Si un día solo da tiempo para un versículo, también cuenta.
- La ruta se ajusta a la agenda: devocional de la mañana (6:10 a 6:25), audio en el traslado y oración al final del día.
- En pareja, pueden seguir **la misma ruta** y comentar los domingos.

### D.23 De la Biblia a la práctica (seguimiento de cada estudio)
Cada estudio guiado termina en **acción**: qué dice la Biblia del tema y cómo ponerlo en práctica, con seguimiento.

**Flujo**
1. **Estudiar:** la sesión del estudio (pasajes, preguntas, notas).
2. **Principios:** al terminar, la app resume los **principios** de la sesión, cada uno con su pasaje (por ejemplo, "planificar antes de gastar", Lucas 14:28).
3. **Compromiso:** el usuario elige **1 a 3 acciones concretas y medibles** por estudio, con métrica, frecuencia y duración. Se pueden enlazar a un **objetivo** de la app.
4. **Registro durante la semana (opcional):** marcar la práctica cuando ocurre (hecho, parcial o no) con una nota breve; no hace falta registrar a diario.
5. **Revisión una vez por semana** (los sábados a las 14:30, de 10 a 15 min dentro de la revisión semanal): se marca lo cumplido y se responde: ¿qué aprendí?, ¿dónde me costó?, ¿qué ajusto?
6. **Cierre del estudio:** resumen de acciones cumplidas, notas y versículos clave, y se decide **qué práctica se queda como hábito permanente**.

**Ejemplo: administración**
| Principio | Pasaje | Práctica medible (ejemplo) |
|---|---|---|
| Todo es de Dios; somos mayordomos | Salmo 24:1; 1 Corintios 4:2 | Oración semanal de entrega de las finanzas y los planes |
| Planificar antes de gastar | Lucas 14:28; Proverbios 21:5 | Revisión semanal del presupuesto (15 min), con el día y la hora que elija el usuario (por ejemplo, el viernes de pago), marcada como hecha |
| Contentamiento y evitar deudas innecesarias | 1 Timoteo 6:6-10; Proverbios 22:7 | Regla de 24 horas antes de una compra no planeada |
| Dar con generosidad: diezmos y ofrendas | Malaquías 3:10; 2 Corintios 9:6-7 | Apartar y entregar lo que el usuario decide con su iglesia y su familia, con recordatorio en su fecha de pago; solo se marca si se cumplió |
| Administrar el tiempo | Efesios 5:15-17 | Planificar la semana en la agenda durante la revisión de los sábados |
| Administrar el cuerpo | 1 Corintios 6:19-20 | Entrenamientos y sueño del plan, como evidencia automática |
| Administrar los talentos | Mateo 25:14-30 | Servir una vez por semana en la iglesia o en la familia |

- La app **solo registra si se cumplió**, nunca montos. Las cifras se quedan en la app de Presupuesto.
- El pago del usuario es **semanal** (viernes). El **recordatorio de dar es opcional y lo configura el usuario**: elige el día y la hora (o ninguno) y, si quiere, que suene por voz en el traslado. **Por defecto no hay recordatorio automático**; el tema se repasa en la revisión del sábado. Hábitos no necesita saber cuánto gana.
- **Viernes de pago, revisión del presupuesto:** la práctica "revisar el presupuesto de la semana" se puede programar ese mismo día si el usuario quiere, en la app de Presupuesto; en Hábitos solo se marca como hecha.

**Ejemplo: amor**
| Principio | Pasaje | Práctica medible (ejemplo) |
|---|---|---|
| El amor se demuestra con hechos | 1 Juan 3:18 | Un acto de amor intencional al día (palabra de ánimo, servicio, tiempo o detalle) |
| Paciente y amable | 1 Corintios 13:4-7 | 10 minutos diarios de conversación con tu pareja, escuchando sin interrumpir |
| Servir por amor | Gálatas 5:13 | Una tarea de servicio en casa por semana, sin que te la pidan |
| Amar al prójimo | Lucas 10:25-37 | Una llamada o visita semanal a alguien que lo necesita |
| Amar a los enemigos | Mateo 5:43-48 | Orar tres veces por semana por una persona con quien hay tensión |
| Amor en el matrimonio | Efesios 5:25 | Revisión semanal en pareja: gratitud y una petición |

**Cómo se mide**
- Se mide la **práctica** (veces por semana, días con acción), **no** el amor, la fe ni la espiritualidad.
- Sin puntos competitivos ni comparación entre personas; en pareja, cada quien comparte solo lo que decide.
- **Recordatorios en el momento oportuno (opcionales):** por ejemplo, en el traslado de regreso, por voz: "¿Qué acto de amor hiciste hoy?". La revisión formal es semanal.
- **Evidencia:** diario de práctica con lo que sucedió ("lo que Dios hizo y lo que hice yo").
- **Ajuste:** si el compromiso es muy grande o muy chico, la app propone cambiarlo, sin juicio.

**Pareja:** compromiso compartido opcional (por ejemplo, el de amor o el de administración familiar) y revisión conjunta (el mismo sábado después de la personal, o el domingo).

**IA opcional:** ayuda a convertir un principio en una acción concreta y medible; solo usa lo que el usuario decida compartir (ver D.13).

**Pantallas:** pestaña "Poner en práctica" dentro de cada estudio, lista "Mis prácticas", check-in rápido, revisión semanal y resumen final del estudio.

---

## Anexo E — Bicicleta de 4 horas: visor de ruta y música (Spotify)

### E.1 La salida del sábado
Salida de unas **4 horas** (de 8:00 a 12:00 aproximadamente), por rutas mixtas de calle y terreno, y revisión semanal a las 14:30.

| Momento | Qué hace la app |
|---|---|
| Noche anterior | Recordatorio de preparación: bicicleta, agua, casco, luces, herramientas y clima |
| ~7:15 | Aviso de salida: desayuno ligero, cargar el teléfono y compartir la hora estimada de regreso |
| 8:00 | Inicio de la ruta: GPS, mapa y música |
| Durante la salida | Recordatorios de hidratación y comida a intervalos, aviso de paradas y registro de pausas |
| ~12:00 | Cierre: resumen de la ruta, hidratación y recuperación |
| Después | Comida, descanso y revisión semanal a las 14:30 (con aviso a las 14:15) |

- Después de una salida larga, la app **reduce la carga** del resto del sábado y sugiere un domingo de **descanso o regenerativo**.
- La **sesión de fuerza del viernes** se ajusta si el usuario reporta cansancio acumulado.
- La app **no fija montos de comida ni de líquidos**; sugiere beber con regularidad desde el inicio y llevar comida fácil de comer, y el usuario ajusta según el calor y su propia experiencia.

### E.2 Visor de ruta

| Función | Detalle |
|---|---|
| **Mapa** | Calles, caminos y terreno, con la posición en tiempo real |
| **Ruta planeada y ruta recorrida** | Se ven por separado; la app avisa si el usuario se desvía |
| **Datos en vivo** | Distancia, tiempo, velocidad, pausas y desnivel |
| **Elevación** | Perfil de subidas y bajadas |
| **Superficie por tramo** | Calle, ciclovía o terreno, con dificultad |
| **Rutas favoritas** | Guardar, repetir y comparar salidas |
| **Mapas sin conexión** | Imprescindible en 4 horas y tramos sin señal |
| **Importar y exportar GPX** | Para usar rutas de otras apps o llevarse el recorrido |
| **Puntos útiles** | Agua, tiendas, talleres, paradas y zonas de riesgo |
| **Clima** | Pronóstico y alertas antes de salir |
| **Ubicación en vivo con tu pareja** | Opcional, con consentimiento y solo durante la salida |
| **Contacto de emergencia** | Botón para enviar la ubicación |
| **Modo ahorro de batería** | Pantalla atenuada y menos actualizaciones |
| **Resumen** | Mapa, distancia, tiempo, desnivel y notas, guardado en el historial |

**Notas técnicas**
- Mapas basados en **OpenStreetMap** con un proveedor de teselas adecuado (el servidor público de OSM no está pensado para uso intensivo) o un SDK comercial de mapas; se decide según costo y mapas sin conexión.
- El GPS en segundo plano en Android requiere un **servicio en primer plano con notificación** y permisos de ubicación explicados al usuario.
- Los datos se guardan **localmente** durante la salida y se sincronizan al terminar.
- La sesión se registra como **ejercicio con ruta** en Health Connect, con permiso.
- Opcional a futuro: **monitor de frecuencia cardiaca** o sensores de bicicleta (Bluetooth).

### E.3 Música con Spotify

**Qué hace**
- **App de música por persona:** cada quien elige la suya en Ajustes (Spotify, Amazon Music u otra) y tiene sus propias listas.
- **Listas por actividad:** bicicleta, entrenamiento de fuerza (A, B, C), regenerativo, traslado, descanso y adoración o devocional.
- **Controles dentro de la app:** reproducir, pausar, saltar y ver lo que suena, sin salir del visor de ruta.
- **Música y voz juntas:** cuando la app habla (avisos de ruta, hidratación o coach), **baja el volumen** de la música y lo restablece después (manejo de foco de audio de Android).
- **Música según el momento:** lista de adoración sugerida en el devocional o la oración.
- **Todo opcional:** la app funciona completa sin Spotify.

**Cómo conectarlo (por etapas)**
1. **Etapa 1 (sin integración técnica, para todos):** abrir una lista o canción desde la app con su enlace, y controlar la reproducción con los **controles de medios de Android**. Sirve con Spotify, **Amazon Music** y otras apps de música.
2. **Etapa 2 (integración con Spotify):** autenticación con la cuenta del usuario y control directo de la reproducción, y listas desde la app.

**Requisitos y límites (verificar los vigentes antes de programar)**
- Según los cambios anunciados en febrero de 2026, el **modo desarrollo** de Spotify exige que quien registre la app tenga **Spotify Premium**, limita cada app a **5 usuarios** (que se agregan manualmente en el panel de desarrolladores) y redujo endpoints y límites de la API.
- El usuario **ya tiene Spotify Premium**, así que puede registrar la app de desarrollo. - Su pareja **no** tiene Spotify Premium, pero sí **Amazon Music**. Para el uso **personal** (1 usuario con Spotify) el límite de 5 usuarios es suficiente. Si algún día se quiere compartir con más personas, haría falta una **cuota extendida** con requisitos exigentes.
- La reproducción bajo demanda depende de la cuenta Premium del usuario.
- **Amazon Music (pareja):** según la documentación de Amazon, la API de dispositivos es heredada y ya no incorpora ni certifica apps, y el acceso a la API web se limita hasta que Amazon Music valide y apruebe la integración. Por eso, para Amazon Music se usa **solo la etapa 1** (enlaces y controles de medios), y se vuelve a revisar si Amazon abre su API.
- Se debe revisar la política de desarrolladores de Spotify antes de usar su contenido con IA; por eso **no se envían datos de música a la IA** de la app.

### E.4 Seguridad en salidas largas
- Casco, luces y ropa visible en tramos de calle; revisión de frenos y llantas antes de salir.
- **Audífonos con escucha exterior** (el usuario ya los tiene): en los tramos de calle se recomienda activar el modo de escucha exterior y mantener el volumen bajo para oír el tráfico; la app lo recuerda al iniciar la ruta.
- Aviso de **hora estimada de regreso** a una persona de confianza y ubicación en vivo opcional.
- Alerta de **calor, sol y clima**; protección solar y agua suficiente.
- Si el usuario se siente mal (mareo, dolor en el pecho, confusión u otro síntoma preocupante), la app indica **detenerse y buscar ayuda**.
- Ante una caída o inactividad prolongada, opción de **enviar la ubicación** al contacto de emergencia.

### E.5 Modelo de datos (borrador)

| Entidad | Campos principales |
|---|---|
| `RutaBici` | id, nombre, distancia, desnivel, superficie_por_tramo, dificultad, favorita |
| `SalidaBici` | id, fecha, ruta_id (opcional), inicio, fin, distancia, desnivel, pausas, notas, compartida_con |
| `PuntoRuta` | salida_id, orden, latitud, longitud, altitud, tiempo |
| `ListaMusica` | id, nombre, actividad (bici, fuerza, traslado, adoración), enlace |
| `SesionMusica` | id, salida_o_sesion_id, lista_id, inicio, fin |

Los puntos de ruta son **datos de ubicación sensibles**: privados por defecto, sin enviarse a la IA ni a la app de Presupuesto, y borrables por el usuario.

### E.6 Etapas
| Etapa | Contenido |
|---|---|
| **v1.1** | Registro de la salida con GPS, visor de mapa básico, resumen, recordatorio de preparación y abrir listas de Spotify con enlace |
| **v1.2** | Mapas sin conexión, importar y exportar GPX, rutas favoritas, hidratación y recordatorios, ubicación en vivo con la pareja |
| **v2** | Integración con Spotify (cuenta y control directo), sensores y análisis de entrenamiento |

### E.7 Preguntas abiertas
1. ¿Qué tipo de música usas en la bicicleta y en el gimnasio?
2. ¿Tu pareja prefiere usar Amazon Music también en la bicicleta y en el traslado?
3. ¿Sales solo o acompañado en la ruta del sábado?
4. ¿Prefieres un mapa estilo Google o uno basado en OpenStreetMap (más flexible para mapas sin conexión)?

---

## Anexo F — Hábitos a eliminar: azúcar y cigarrillo

### F.1 Principios
1. **Sin culpa:** una recaída es un dato para aprender, no un fracaso.
2. **Medible:** todo se mide (consumo, antojos, días libres) y la meta la fija el usuario.
3. **Reemplazo:** no basta quitar; se construye una conducta que ocupe el lugar.
4. **Personalizado:** reducción gradual o dejarlo de golpe, a elección de cada persona y cada hábito.
5. **Apoyo:** pareja, fe, comunidad y, cuando hace falta, profesionales de la salud.
6. **Privacidad:** son datos de salud muy sensibles; privados por defecto.
7. **La app no sustituye atención médica ni psicológica;** no recomienda medicamentos ni dosis.

### F.2 Estructura común (para cualquier hábito)

| Etapa | Qué se hace |
|---|---|
| **1. Conocer la línea base** | 7 días registrando cuánto, cuándo, dónde y por qué, **sin intentar cambiar** todavía |
| **2. Elegir la estrategia** | Reducción gradual, o fecha para dejarlo; meta final y fecha de inicio |
| **3. Motivos** | Lista personal de razones (salud, familia, fe, ahorro) visible en los momentos difíciles |
| **4. Disparadores y plan "si… entonces"** | Detectar situaciones de riesgo y decidir qué hacer en cada una |
| **5. Reemplazos** | Conductas que ocupan el lugar del hábito |
| **6. Apoyo** | Personas, oración y profesional de salud |
| **7. Seguimiento** | Registro diario de 30 segundos y revisión semanal (sábados 14:30) |
| **8. Recaídas** | Protocolo sin culpa para retomar |
| **9. Mantenimiento** | Después de la meta, prevención y revisión mensual |

### F.3 Módulo de azúcar

**Qué se registra**
- **Bebidas azucaradas** (refresco, jugos, café o té con azúcar), **postres y dulces**, y **botanas** con azúcar añadida.
- Por **porciones** (lo más fácil); los gramos son opcionales.
- Hora, lugar, estado de ánimo y disparador (opcional, en un toque).

**Estrategia**
- **Reducción escalonada** por semanas (por ejemplo: línea base, reducir a la mitad, reducir otra vez y llegar a la meta), o eliminar primero lo más fácil (refresco) y seguir con lo demás.
- **Meta final:** la define el usuario con apoyo de un médico o nutriólogo. Como referencia general, la OMS recomienda que los azúcares libres sean menos del 10 % de la energía diaria y, idealmente, menos del 5 %.
- **Reemplazos:** agua simple o mineral, té o café sin azúcar, fruta, y un hábito de "algo dulce natural" después de comer.
- **Entorno:** no tener refresco en casa, y la lista de compras de la app de Presupuesto lo apoya (etiqueta `azucar_alta`).
- **Educación breve:** aprender a leer etiquetas y reconocer los nombres del azúcar.
- **Sueño y entrenamiento:** el cansancio aumenta los antojos; la app relaciona la mala noche con más antojos y sugiere una versión suave del día.
- Se registra cuántas veces se cumplió el plan del día de comidas (conexión con la app de Presupuesto, si está activa).

**Métricas:** porciones por día, días sin bebida azucarada, tendencia semanal, antojos superados y gramos estimados (opcional).

**Cuidado:** si el usuario tiene diabetes u otra condición, la app recomienda hablar con su médico antes de cambiar la alimentación. Si el seguimiento empieza a causar ansiedad, obsesión o restricciones extremas, se recomienda apoyo profesional.

### F.4 Módulo de cigarrillo

**Qué se registra**
- **Cigarrillos por día**, hora, lugar, compañía, estado de ánimo y disparador.
- Línea base de 7 días, con el momento más frecuente (después de comer, café, estrés, traslado, reuniones).

**Estrategia**
- **Reducción gradual** (bajar la cantidad por etapas con fechas) o **fecha para dejar de fumar** con preparación previa.
- **Motivos personales** siempre a la mano.
- **Apoyo médico:** existen tratamientos de apoyo para dejar de fumar; la app **recomienda hablar con un médico** para valorar opciones y **no recomienda ni dosifica** nada.
- **Síntomas de abstinencia:** irritabilidad, ansiedad, dificultad para concentrarse, más apetito y sueño alterado son frecuentes al principio. La app avisa que existen y sugiere consultar si son intensos o si hay tristeza o ansiedad fuerte.
- **Reemplazos:** agua, respiración, caminata corta, algo para masticar sin azúcar, o llamar a alguien.
- **Entorno:** sacar cigarros, encendedores y ceniceros del carro, de la casa y del trabajo; avisar a personas cercanas.
- **Ahorro:** cuánto se deja de gastar, **visible solo para el usuario** (el precio lo captura en Hábitos como motivación personal).
- **Hitos de salud:** mensajes de lo que va mejorando el cuerpo con el tiempo, con datos de una fuente oficial (OMS o autoridad sanitaria). Verificar cada dato antes de publicarlo.
- **Línea de ayuda:** pantalla con una línea de apoyo para dejar de fumar o para adicciones. En México existe la Línea de la Vida (800 911 2000); verificar que siga vigente antes de publicarla.

**Métricas:** cigarrillos por día, días libres de cigarrillo, racha actual, mejor racha, días libres acumulados, antojos superados, ahorro y hitos alcanzados.

### F.5 Botón "Tengo un antojo" (SOS)
Disponible en la pantalla de inicio, en el widget y **por voz** (sin tocar la pantalla).

1. **Pausa:** "Respira. Las ganas pasan; casi siempre duran pocos minutos."
2. **Qué es:** cigarrillo, azúcar u otro hábito.
3. **Elegir una técnica:** respiración guiada, beber agua, caminar 5 minutos, masticar algo sin azúcar, llamar o escribirle a alguien de apoyo, o un versículo y una oración corta.
4. **Temporizador de 10 minutos:** "Si en 10 minutos sigue, repetimos."
5. **Registro rápido:** intensidad, disparador y qué hice (30 segundos).
6. **Cierre:** reconocimiento sobrio y, si pasó, se suma al contador de antojos superados.

**En el traslado (manejando):**
- El SOS funciona **solo por voz y audio**, con respiración guiada por audio.
- La app **no pide mirar ni tocar la pantalla** mientras se maneja.
- Si va la pareja, puede apoyar leyendo la técnica o poniendo el audio.

### F.6 Registro, patrones y revisión
- **Registro diario de 30 segundos** por la noche: cuánto, antojos y cómo me fue.
- **Mapa de patrones:** horas, lugares, estados de ánimo y personas asociadas a más consumo.
- **Resumen semanal:** tendencia, mejores y peores momentos, disparadores y un ajuste sugerido. Se revisa en la **revisión de los sábados a las 14:30**.
- **Revisión mensual:** meta, motivos y plan de mantenimiento.

### F.7 Recaídas
- Frase de partida: "Una caída no borra lo avanzado."
- La app **no pone el contador en cero sin más**: conserva la **mejor racha** y los **días libres acumulados**, y reinicia la racha actual.
- **Protocolo:** registrar qué pasó, identificar el disparador, ajustar el plan (más apoyo, otro reemplazo o un paso más pequeño) y volver a empezar con una acción concreta hoy.
- Si hay varias recaídas seguidas, la app sugiere **hablar con un profesional de la salud** o con alguien de confianza.
- Sugerencias espirituales opcionales: estudios de "Dominio propio y vencer hábitos" y "El perdón" (Anexo D).

### F.8 Apoyo
- **Pareja como compañera de apoyo (opcional):** ve solo lo que el usuario decida compartir (por ejemplo, racha y mensajes de ánimo, no el detalle de cada antojo).
- **Mensajes de ánimo** programados por la pareja o enviados en el momento de un antojo.
- **Fe:** colección de versículos de ánimo, oración breve en el SOS y apoyo del pastor si el usuario quiere.
- **Profesionales:** recordatorio de cita médica o de seguimiento (con el módulo de valoración médica).
- **Comunidad:** información de grupos de apoyo, sin datos personales en la app.

### F.9 Integración con las otras áreas

| Con | Cómo se conecta |
|---|---|
| Agenda | Bloques de refuerzo, momentos de riesgo y revisión semanal |
| Sueño | Más antojos con mala noche; rutina de sueño como parte del plan |
| Entrenamiento y bicicleta | La actividad física ayuda con los antojos y se sugiere ante un SOS |
| Alimentación | Reglas de azúcar en el plan de comidas y lista de compras (Presupuesto) |
| Espiritual | Versículos, oración, ayuno y estudios guiados |
| Traslado | SOS por voz y audio de motivación |
| Pareja | Apoyo opcional y mensajes de ánimo |
| Música | Lista de "calma" para antojos |
| Presupuesto | **Opcional y desactivado por defecto:** unidades evitadas, sin dinero (el cigarrillo exige activación aparte) |

**IA (opcional):** puede ayudar a revisar patrones y a proponer ajustes del plan, usando datos mínimos y siempre con el consentimiento del usuario. No diagnostica, no recomienda medicamentos y, ante señales de malestar importante, orienta a apoyo humano y profesional. **Los registros de consumo y antojos no se envían a la IA por defecto.**

### F.10 Pantallas
1. **Panel de hábitos:** días libres, racha, mejor racha, ahorro (privado), próximos hitos y tendencia.
2. **Configurar hábito:** línea base, estrategia, motivos, disparadores y reemplazos.
3. **Registro rápido** (cigarrillo, bebida azucarada y postre).
4. **SOS "Tengo un antojo"** (con voz).
5. **Patrones:** gráficas de horas, lugares y estados de ánimo.
6. **Hitos de salud.**
7. **Recaída y reinicio.**
8. **Apoyo:** pareja, mensajes y líneas de ayuda.
9. **Revisión semanal y mensual.**

### F.11 Modelo de datos (borrador)

| Entidad | Campos principales |
|---|---|
| `HabitoEliminar` | id, tipo (azucar, cigarrillo, otro), estrategia (gradual, fecha), fecha_inicio, meta, motivos, estado |
| `LineaBase` | habito_id, fecha_inicio, fecha_fin, promedio, momentos_frecuentes |
| `RegistroConsumo` | id, habito_id, fecha_hora, cantidad, unidad, lugar, estado_animo, disparador, compania |
| `Antojo` | id, habito_id, fecha_hora, intensidad, tecnica, resultado (superado, consumo), nota |
| `PlanSiEntonces` | id, habito_id, situacion, accion |
| `Reemplazo` | id, habito_id, conducta, tipo |
| `Recaida` | id, habito_id, fecha, causa, ajuste |
| `RachaHabito` | habito_id, actual, mejor, dias_libres_acumulados |
| `Hito` | id, habito_id, nombre, fecha_alcanzado |
| `ApoyoHabito` | id, habito_id, persona, nivel_compartido, mensajes |

Todos con `creado`, `actualizado` y `privacidad` (privado por defecto).

### F.12 Privacidad y seguridad
- **Datos de salud sensibles:** privados por defecto, con bloqueo por PIN o biometría para esta sección.
- **No se envían** a la app de Presupuesto ni a la IA, salvo opciones activadas expresamente.
- **Notificaciones discretas:** el texto de los avisos no menciona el hábito si el usuario lo prefiere.
- El usuario puede **exportar o borrar** todo el historial del módulo.
- Si algún día se comparte con la pareja, cada dato se elige por separado.

### F.13 Etapas
| Etapa | Contenido |
|---|---|
| **MVP** | Línea base, registro rápido, contadores y racha, motivos, SOS básico, recaídas, hitos y revisión semanal |
| **v1.1** | SOS por voz, patrones y gráficas, plan "si… entonces", reemplazos y apoyo de la pareja |
| **v1.2** | Ahorro privado, líneas de ayuda, hitos de salud verificados y notificaciones discretas |
| **v2** | IA opcional, integración con Presupuesto (unidades evitadas) y música de calma |

### F.14 Plan inicial del usuario

**Cigarrillo: un mes gradual y luego dejarlo de golpe**

| Fase | Duración | Qué se hace |
|---|---|---|
| **Semana 1** | 7 días | **Línea base:** registrar cada cigarrillo (hora, lugar, disparador) sin intentar cambiar |
| **Semanas 2 a 4** | 3 semanas | **Reducción escalonada** frente a la línea base: meta semanal por debajo del promedio (por ejemplo, alrededor de un 25 %, 50 % y 75 % menos; es un ejemplo editable), retrasar el primer cigarrillo del día, quitar primero los de menos valor y cambiar la rutina de los disparadores principales |
| **Preparación (semana 4)** | Antes del Día D | Elegir la **fecha** (primer día del segundo mes), **cita médica** para valorar opciones de apoyo, sacar cigarros, encendedores y ceniceros (casa, carro y trabajo), avisar a la pareja y a las personas de apoyo, preparar el SOS, el plan del traslado y los reemplazos |
| **Día D** | Primer día del mes 2 | **Cero cigarrillos.** Lista del día, mensajes de apoyo, oración y agenda ligera |
| **Primeras 2 semanas** | 14 días | Registro diario, SOS disponible, **modo foco** y revisión semanal |
| **Después** | Resto del mes 2 y mes 3 | Consolidar, hitos, mantenimiento y revisión mensual |

- La app **propone y el usuario decide**: las cifras de reducción se ajustan a la línea base y, si es posible, con el médico.
- Si en el mes 1 no se logra reducir según lo previsto, **no pasa nada**: se ajusta el paso y se mantiene la fecha del Día D, salvo que el usuario decida moverla.
- Si ocurre una recaída después del Día D, se aplica el protocolo de F.7 (sin culpa, con ajustes).

**Azúcar: alimentos muy regulados y refresco ocasional**
- **Alimentos muy regulados:** tres listas editables, definidas con apoyo de un nutriólogo si es posible.

| Lista | Qué incluye | Regla |
|---|---|---|
| **Verde** | Alimentos sin azúcar añadida (fruta entera, verduras, agua, café o té sin azúcar, etc.) | Libre |
| **Amarilla** | Alimentos con algo de azúcar añadida (por ejemplo, algunos lácteos, cereales o salsas) | Limitada y con frecuencia definida |
| **Roja** | Dulces, postres, jugos y bebidas azucaradas habituales | Evitar |

- La app marca en el plan de comidas los platillos con `azucar_alta` y ayuda a cumplir las listas.
- **Refresco ocasional:** el usuario define **cuántas veces** lo permite (por semana o por mes) y qué se considera una ocasión.
  - Cada vez se registra como **"ocasión planeada"** (con porción y contexto, por ejemplo una reunión o una comida especial) o **"no planeada"**.
  - Si aparece un antojo **impulsivo**, primero se hace el SOS de 10 minutos y luego se decide.
  - **Semáforo:** verde dentro del límite, amarillo cerca del límite y rojo si se pasó; el rojo lleva a ajustar el plan, no a culparse.
  - Si el refresco ocasional va en aumento semana tras semana, la revisión de los sábados lo señala y propone endurecer la regla.
- **Métricas:** refrescos por semana o mes, porcentaje de ocasiones planeadas, días sin azúcar alta, antojos superados y tendencia.

**Modo foco (después del Día D)**
- Dejar de fumar puede traer irritabilidad, ansiedad y cambios de sueño. Durante las **primeras 2 semanas** la app activa un modo foco:
  - Mantiene lo esencial: sueño, comidas reguladas, SOS, oración y registro del hábito.
  - **Pausa los incrementos** de entrenamiento, el inglés extra y los pasos nuevos del plan de sueño (mantiene el último horario).
  - Reduce recordatorios y propone una agenda más ligera.
  - Sugiere actividad suave (caminata, bicicleta moderada) como apoyo ante los antojos.
- Al terminar las 2 semanas, la app propone retomar lo pausado de forma gradual.

**Calendario de cambios propuesto** (para no cambiar todo a la vez)

| Periodo | Foco principal | Se mantiene o se hace en pequeño |
|---|---|---|
| **Semanas 1 a 4** | Línea base y reducción de cigarrillo; reglas de azúcar; plan de sueño escalonado | Devocional breve, entrenamiento básico, ruta de inicio de Biblia (Juan) |
| **Semana 4 (preparación)** | Cita médica, entorno limpio, apoyo y plan del Día D | Sueño estable |
| **Semanas 5 y 6** | **Día D y modo foco** | Solo lo esencial; sin nuevos pasos |
| **Semanas 7 y 8** | Consolidar sin cigarrillo | Retomar entrenamiento e inglés extra poco a poco |
| **Mes 3** | Mantenimiento y revisión mensual | Estudios guiados y metas nuevas |

**Mientras tanto, sin esperar la app:** la línea base se puede empezar ya en una libreta o una nota del teléfono (hora, lugar y por qué de cada cigarrillo y de cada refresco o dulce), y luego se importa a la app.

### F.15 Qué se define dentro de la app
Estos datos **no se fijan en el documento**: se configuran en el asistente (7.2) y en Ajustes de cada hábito.

| Parámetro | Dónde se define | Valor por defecto |
|---|---|---|
| Fecha de inicio de la reducción de cigarrillo | Configurar hábito | Al terminar la semana de línea base |
| Cantidad base de cigarrillos | Línea base de 7 días | Promedio calculado por la app |
| Metas semanales de reducción | Configurar hábito | Plantilla escalonada editable |
| Fecha del Día D | Configurar hábito | Primer día del segundo mes (editable) |
| Cita médica de apoyo | Agenda | Recordatorio en la semana de preparación |
| Qué es refresco "ocasional" (cuántas veces) | Configurar hábito de azúcar | Sin valor: la app lo pregunta al configurar |
| Listas verde, amarilla y roja | Configurar hábito de azúcar | Plantillas editables |
| Compañera de apoyo y qué se comparte | Privacidad | Nada compartido |
| Ahorro visible en el panel | Ajustes del hábito | Oculto |
| Notificaciones discretas | Ajustes del hábito | Activadas |
| Duración del modo foco | Configurar hábito | 2 semanas (editable) |

---

## Anexo G — Pantallas

Bocetos en texto de las pantallas principales (Android, Flutter, Material 3). Son **estructuras**, no el diseño visual final: los textos, horarios y cantidades son ejemplos y se configuran en la app.

### G.1 Sistema de diseño
| Aspecto | Decisión |
|---|---|
| **Base** | Material 3 con tema claro y oscuro (la lectura nocturna es frecuente) |
| **Color por área** | Espiritual (violeta), Salud (verde), Inglés (naranja), Personal (azul verdoso), Laboral (gris azulado), Hábitos a eliminar (terracota suave; nunca rojo de alarma) |
| **Tipografía** | Una familia legible; tamaño ajustable; el lector bíblico permite elegir fuente y tamaño |
| **Zonas táctiles** | Mínimo 48 dp; acciones principales al alcance del pulgar (parte inferior) |
| **Navegación** | Barra inferior con 5 pestañas: Hoy, Agenda, Áreas, Progreso y Coach; botón "+" global y acceso al botón de antojo |
| **Tono** | Cercano y sin culpa; los fallos se muestran como "ajuste", no como error |
| **Estados** | Todo tiene estado vacío, cargando, sin conexión y error con un mensaje claro y una acción |
| **Accesibilidad** | Contraste suficiente, lector de pantalla, tamaño de letra grande, no depender solo del color |
| **Modo traslado** | Pantalla propia de audio y voz, con botones grandes y sin lectura |
| **Sin conexión** | Indicador discreto; lo pendiente se sincroniza después |

### G.2 Mapa de navegación

```
Hoy ─┬─ Tarjeta "Sigue" ──► Detalle del bloque
     ├─ Lista de hoy ─────► Registro rápido
     ├─ Botón "Tengo un antojo" ──► SOS
     └─ Versículo del día ──► Lector

Agenda ─┬─ Día / Semana / Mes
        ├─ Bloque ──► Detalle ► Editar
        └─ "+" ──► Nuevo bloque / objetivo

Áreas ─┬─ Espiritual ─► Hoy · Lector · Planes · Estudios · Devocional · Oración · Memorización · Ayuno · Iglesia
       ├─ Salud ──────► Entrenamiento · Bicicleta · Alimentación · Sueño · Suplementos · Medidas · Citas
       ├─ Inglés ─────► Lección · Escucha · Pronunciación · Conversación · Vocabulario
       ├─ Personal ───► Libros · Notas
       ├─ Laboral ────► Metas · Proyectos · Enfoque
       └─ Hábitos a eliminar ► Panel · Registro · SOS · Patrones · Hitos

Progreso ─┬─ Rachas y gráficas por área
          └─ Revisión semanal (sábado) · mensual

Coach ──► Chat y voz · Sugerencias · Ajustes de IA

Ajustes (⚙) ─┬─ Perfil y pareja · Privacidad · Música · Conexión · Notificaciones · Respaldo
             └─ Asistente de configuración (volver a ejecutar)
```

### G.3 Bocetos

#### G.3.1 Hoy
```
┌──────────────────────────────────┐
│ Lunes 19 oct           🔥 12  ⚙ │
│ Buenos días                      │
├──────────────────────────────────┤
│ SIGUE                            │
│ ┌──────────────────────────────┐ │
│ │ 06:25  Cardio suave · 25 min │ │
│ │ [Empezar]       [Posponer]   │ │
│ └──────────────────────────────┘ │
│ HOY  4 de 9  ▓▓▓▓░░░░░           │
│ ☑ Devocional breve               │
│ ☐ Cardio suave                   │
│ ☐ Inglés en el traslado          │
│ ☐ Registro de hábitos            │
│ ☐ Fuerza A · 19:15               │
│ ☐ Lectura y oración              │
│ Carga del día: ● equilibrada     │
│ ┌──────────────┐ ┌─────────────┐ │
│ │ Versículo    │ │ Tengo un    │ │
│ │ del día      │ │ antojo      │ │
│ └──────────────┘ └─────────────┘ │
├──────────────────────────────────┤
│ Hoy  Agenda  Áreas  Progreso  Coach │
└──────────────────────────────────┘
```
- Deslizar un elemento a la derecha = **hecho**; a la izquierda = **posponer u omitir**.
- Tocar un elemento abre su detalle; mantener presionado abre opciones.

#### G.3.2 Agenda (vista día)
```
┌──────────────────────────────────┐
│ ◀  Lun 19 oct  ▶    Día|Sem|Mes  │
├──────────────────────────────────┤
│ 06:10 ▌ Devocional breve    🟣   │
│ 06:25 ▌ Cardio suave        🟢   │
│ 06:50 ▌ Baño y desayuno          │
│ 07:20 ▌ Traslado · inglés   🟠   │
│ 08:00 ▒ Trabajo ▒▒▒▒▒▒▒▒▒▒▒▒     │
│ 18:00 ▌ Regreso · oración   🟣   │
│ 19:15 ▌ Fuerza A (45 min)   🟢   │
│ 20:15 ▌ Cena                     │
│ 21:00 ▌ Inglés corto        🟠   │
│ 22:00 ▌ Rutina de sueño     🟢   │
├──────────────────────────────────┤
│ Carga: ● equilibrada        [ + ]│
└──────────────────────────────────┘
```
- Tocar un hueco libre sugiere actividades; arrastrar mueve un bloque; un conflicto se marca en ámbar.

#### G.3.3 Áreas
```
┌──────────────────────────────────┐
│ Áreas                            │
│ ┌────────────┐ ┌──────────────┐  │
│ │ 🙏 Espiritual│ │ 💪 Salud     │  │
│ │ 5/7  ▓▓▓▓░ │ │ 3/5  ▓▓▓░░   │  │
│ └────────────┘ └──────────────┘  │
│ ┌────────────┐ ┌──────────────┐  │
│ │ 📚 Inglés   │ │ 🌱 Personal  │  │
│ │ 6/7  ▓▓▓▓▓ │ │ 2/4  ▓▓░░░   │  │
│ └────────────┘ └──────────────┘  │
│ ┌────────────┐ ┌──────────────┐  │
│ │ 💼 Laboral  │ │ 🚫 Hábitos   │  │
│ │ 1/3  ▓░░░░ │ │ 14 días ▓▓▓  │  │
│ └────────────┘ └──────────────┘  │
│ [ + Nuevo objetivo ]             │
└──────────────────────────────────┘
```

#### G.3.4 Espiritual hoy
```
┌──────────────────────────────────┐
│ ◀ Espiritual                     │
├──────────────────────────────────┤
│ Lectura de hoy · Juan 3          │
│ [📖 Leer]  [🎧 Audio]    ☐       │
│ Devocional breve · 10 min  [Ir]  │
│ Versículo a repasar  [Repasar]   │
│ Peticiones de hoy (3)    [Orar]  │
│ Ayuno: sin ayuno activo          │
│ Estudio: La salvación 2/6 [Ir]   │
│ Mi práctica de la semana  [Ver]  │
│ ┌──────────────────────────────┐ │
│ │ Nota rápida / gratitud       │ │
│ └──────────────────────────────┘ │
│ Racha suave: 9 días (1 de gracia)│
└──────────────────────────────────┘
```

#### G.3.5 Lector bíblico
```
┌──────────────────────────────────┐
│ ◀ Juan 3     RVR1960 ▾  Aa  ☾   │
├──────────────────────────────────┤
│ 16  [texto del versículo]        │
│ 17  [texto del versículo]        │
│     ← versículo seleccionado     │
│ ┌──────────────────────────────┐ │
│ │ Subrayar · Nota · Comparar   │ │
│ │ Referencias · Concordancia   │ │
│ │ Diccionario · Memorizar      │ │
│ └──────────────────────────────┘ │
│ [▶ Audio]  [Paralelo: NVI]  [✓]  │
└──────────────────────────────────┘
```
- El texto bíblico lo provee la versión elegida (con licencia); los bocetos no lo reproducen.

#### G.3.6 Estudio guiado y "poner en práctica"
```
┌──────────────────────────────────┐
│ ◀ La administración · Sesión 4/8 │
├──────────────────────────────────┤
│ Pasajes: [Pr 21:5] [Lc 14:28]    │
│ 1 Observación   ▸                │
│ 2 Interpretación▸                │
│ 3 Aplicación    ▸                │
│ Referencias cruzadas ▸           │
│ Versículo a memorizar [Agregar]  │
│ Mis notas ▸                      │
│ ── Poner en práctica ──          │
│ Principio: planificar antes de   │
│ gastar                           │
│ ☐ Revisar presupuesto semanal    │
│ [+ Crear compromiso]             │
│ [Terminar sesión]                │
└──────────────────────────────────┘
```

#### G.3.7 Hábito a eliminar: panel y botón de antojo
```
┌──────────────────────────────────┐
│ ◀ Cigarrillo            ⚙        │
├──────────────────────────────────┤
│ Fase: reducción · semana 2       │
│ Hoy: 6 de 8 permitidos           │
│ Racha: 3 días bajo la meta       │
│ Mejor racha: 5   Días libres: 0  │
│ Día D: en 19 días                │
│ Ahorro: oculto  [Mostrar]        │
│ ──────────────────────────────── │
│ [ + Registrar ]                  │
│ [ 🆘 Tengo un antojo ]           │
│ Patrones ▸  Hitos ▸  Apoyo ▸     │
│ Mis motivos ▸                    │
└──────────────────────────────────┘

SOS
┌──────────────────────────────────┐
│ Respira. Las ganas pasan.        │
│        ( 10:00 )                 │
│ ¿Qué técnica?                    │
│ [Respiración] [Agua] [Caminar]   │
│ [Versículo y oración] [Llamar]   │
│ Después: intensidad ▢▢▢▢▢        │
│ [Superé el antojo] [Lo consumí]  │
└──────────────────────────────────┘
```
- La pantalla de azúcar usa la misma estructura, con porciones, semáforo y "ocasión planeada".
- "Lo consumí" lleva al registro sin juicio y a un ajuste del plan.

#### G.3.8 Entrenamiento de hoy (gimnasio)
```
┌──────────────────────────────────┐
│ ◀ Fuerza A · Empuje · 45 min     │
├──────────────────────────────────┤
│ Calentamiento · caminadora 5 min │
│ 1 Press de pecho (estación)      │
│   Serie 1  12 × ___ kg  [✓]      │
│   Serie 2  12 × ___ kg  [ ]      │
│ 2 Elevaciones laterales (polea)  │
│ 3 Tríceps en polea alta          │
│ 4 Fondos en banco                │
│ Descanso: 00:45 ⏱                │
│ [Versión corta 30′] [Cambiar ej.]│
│ [Terminar y registrar]           │
└──────────────────────────────────┘
```

#### G.3.9 Bicicleta en vivo (visor de ruta)
```
┌──────────────────────────────────┐
│ ┌──────────────────────────────┐ │
│ │        [  MAPA  ]            │ │
│ │   ruta planeada ─ ─          │ │
│ │   ruta recorrida ━━          │ │
│ │              ● tú            │ │
│ └──────────────────────────────┘ │
│ 1:42:10   32,4 km   ▲ 410 m      │
│ Vel. 19 km/h    Siguiente: agua  │
│ ♪ Lista bicicleta  ⏮ ⏯ ⏭         │
│ [Pausar]  [Compartir ubicación]  │
│ [Terminar]            [SOS]      │
└──────────────────────────────────┘
```

#### G.3.10 Inglés: lección del día
```
┌──────────────────────────────────┐
│ ◀ Inglés · Módulo 1 · Semana 2   │
├──────────────────────────────────┤
│ Hoy (principal 25 min)           │
│ ☑ Repaso (3)   ☐ Lección (9)     │
│ ☐ Pronunciación (5)  ☐ Hablar (8)│
│ Traslado (audio)  [▶ Iniciar]    │
│ Extras: [Video] [Lectura] [Diario]│
│ Inmersión: 25 %  [Ajustar]       │
│ Racha: 11   Nivel estimado: B1+  │
└──────────────────────────────────┘
```

#### G.3.11 Modo traslado (solo audio y voz)
```
┌──────────────────────────────────┐
│ 🚗 Modo traslado                 │
│                                  │
│    Inglés: escucha y repetición  │
│    ─────────────○──── 12:30      │
│                                  │
│  ┌──────────┐   ┌──────────┐     │
│  │    ⏯     │   │   ⏭      │     │
│  └──────────┘   └──────────┘     │
│  ┌──────────────────────────┐    │
│  │   🎤  Di un comando      │    │
│  └──────────────────────────┘    │
│  [ Tengo un antojo (voz) ]       │
└──────────────────────────────────┘
```
- Sin texto largo ni teclado; todo por **voz**, y para quien maneja la pantalla queda bloqueada para interacciones.
- Si va la pareja, puede tocar los controles.

#### G.3.12 Progreso
```
┌──────────────────────────────────┐
│ Progreso      [Semana ▾]         │
├──────────────────────────────────┤
│ Equilibrio por áreas (radar)     │
│        Esp                       │
│   Per ◢◣ Salud                   │
│        Ing                       │
│ Rachas                           │
│ Devocional 9 · Inglés 11 · Gym 4 │
│ Gráficas ▸ Sueño · Entreno · Inglés│
│ Hábitos a eliminar ▸             │
│ Revisión semanal ▸ (sáb 14:30)   │
└──────────────────────────────────┘
```

#### G.3.13 Revisión semanal (sábados 14:30)
```
┌──────────────────────────────────┐
│ Revisión semanal · paso 2 de 5   │
├──────────────────────────────────┤
│ Mis prácticas de los estudios    │
│ ☑ Revisar presupuesto            │
│ ◐ Un acto de amor al día  (5/7)  │
│ ☐ Servir una vez en la semana    │
│ ¿Qué aprendí?                    │
│ ┌──────────────────────────────┐ │
│ │                              │ │
│ └──────────────────────────────┘ │
│ ¿Dónde me costó? / ¿Qué ajusto?  │
│ [Anterior]            [Siguiente]│
└──────────────────────────────────┘
```
- Pasos: resumen por área, prácticas de estudios, dar, inglés y ajustes de la próxima semana.

#### G.3.14 Coach
```
┌──────────────────────────────────┐
│ Coach                  🎤  ⚙     │
├──────────────────────────────────┤
│ Sugerencias de la semana         │
│ ▸ Tus mañanas fallan los lunes   │
│ ▸ Mover entrenamiento a la noche │
│ ─────────────────────────────    │
│ (chat con el coach)              │
│ Tú: ¿Cómo voy esta semana?       │
│ Coach: …                         │
│ ┌──────────────────────────┐ ➤   │
│ │ Escribe o habla…         │     │
│ └──────────────────────────┘     │
│ IA: activada solo en esta función│
└──────────────────────────────────┘
```

#### G.3.15 Asistente de configuración (un paso)
```
┌──────────────────────────────────┐
│ Configuración · paso 7 de 12     │
│ ▓▓▓▓▓▓▓░░░░░                     │
├──────────────────────────────────┤
│ Hábitos a eliminar               │
│ ¿Qué hábito quieres trabajar?    │
│ ☑ Cigarrillo   ☑ Azúcar  ☐ Otro  │
│ Estrategia:  ( ) Gradual         │
│              ( ) De golpe        │
│              (•) Gradual y luego │
│                  de golpe        │
│ Fecha de inicio: [ elegir ]      │
│ [Decidir después]  [Siguiente]   │
└──────────────────────────────────┘
```

#### G.3.16 Pareja
```
┌──────────────────────────────────┐
│ Pareja                           │
├──────────────────────────────────┤
│ Compartido con ella              │
│ ▸ Plan de lectura juntos         │
│ ▸ Peticiones de oración (4)      │
│ ▸ Horario laboral y traslado     │
│ ▸ Rutas en bicicleta             │
│ Privado (solo tú)                │
│ 🔒 Hábitos a eliminar · Salud    │
│ Mensajes de ánimo ▸              │
│ [Revisión en pareja]             │
└──────────────────────────────────┘
```

#### G.3.17 Ajustes y privacidad
```
┌──────────────────────────────────┐
│ Ajustes                          │
├──────────────────────────────────┤
│ Perfil y pareja ▸                │
│ Privacidad y bloqueo (PIN) ▸     │
│ IA por función ▸                 │
│ Música (por persona) ▸           │
│ Notificaciones discretas ▸       │
│ Conexión con Presupuesto ▸       │
│ Respaldo y exportación ▸         │
│ Reiniciar asistente ▸            │
└──────────────────────────────────┘
```

### G.4 Inventario de pantallas

| ID | Pantalla | Etapa |
|---|---|---|
| P01 | Hoy | MVP |
| P02 | Agenda (día, semana, mes) | MVP |
| P03 | Detalle y edición de bloque | MVP |
| P04 | Áreas | MVP |
| P05 | Crear y editar objetivo (asistente SMART) | MVP |
| P06 | Asistente de configuración | MVP |
| P07 | Progreso | MVP |
| P08 | Revisión semanal y mensual | MVP |
| P09 | Hábito a eliminar: panel | MVP |
| P10 | Registro rápido de consumo | MVP |
| P11 | SOS "Tengo un antojo" | MVP |
| P12 | Espiritual hoy | MVP |
| P13 | Lector bíblico | MVP |
| P14 | Planes de lectura | MVP |
| P15 | Devocional | MVP |
| P16 | Oración (diario) | MVP |
| P17 | Estudio guiado y sesión | v1.3 |
| P18 | Mis prácticas (check-ins y revisión) | v1.3 |
| P19 | Entrenamiento de hoy | v1.1 |
| P20 | Inventario de aparatos y generador de rutinas | v1.1 |
| P21 | Bicicleta: planear y en vivo | v1.1 |
| P22 | Alimentación: plan de hoy y cumplimiento | v1.1 |
| P23 | Sueño: registro y transición | v1.1 |
| P24 | Suplementos | v1.1 |
| P25 | Inglés: inicio, lección, escucha y pronunciación | v1.2 |
| P26 | Modo traslado | v1.2 |
| P27 | Memorización de versículos | v1.1 |
| P28 | Ayuno | v1.2 |
| P29 | Iglesia y notas de predicación | v1.2 |
| P30 | Coach | v2 |
| P31 | Pareja y compartidos | v1.3 |
| P32 | Ajustes, privacidad y respaldo | MVP |
| P33 | Conexión con Presupuesto | v1.1 |

### G.5 Componentes reutilizables
- **Tarjeta de objetivo:** título, área, métrica, progreso y acción rápida.
- **Fila de tarea con deslizar:** hecho, posponer y omitir.
- **Chip de racha:** número y día de gracia.
- **Selector de versión bíblica** y de **app de música**.
- **Temporizador** (entrenamiento, oración, ayuno y SOS).
- **Registro rápido en un toque:** botones grandes con confirmación suave.
- **Hoja inferior** para acciones y detalles sin salir de la pantalla.
- **Semáforo** (verde, ámbar y terracota) para límites como el refresco ocasional.
- **Medidor de carga del día.**
- **Gráficas simples:** barras, líneas y calendario de calor.
- **Bloque de agenda** con color por área y estado.
- **Estado vacío** con una sola acción sugerida.

### G.6 Gestos y notificaciones
- Deslizar para marcar, mantener presionado para opciones, tirar para actualizar.
- **Notificaciones con acciones** (Hecho, Posponer 10 min, Omitir) y texto **discreto** en hábitos sensibles.
- **Widgets de Android:** "Sigue" (próximo bloque), botón de antojo y versículo del día.
- **Atajos de la pantalla de inicio:** Registrar, Antojo y Modo traslado.
- **Comandos de voz** en el modo traslado y en el SOS.

### G.7 Estados vacíos y mensajes (tono sin culpa)
| Situación | Mensaje de ejemplo |
|---|---|
| Sin objetivos | "Empecemos con uno pequeño. ¿Qué te gustaría lograr esta semana?" |
| Racha rota | "Un día no borra lo que has avanzado. Retomemos hoy." |
| Recaída en un hábito | "Aprendamos de lo que pasó y ajustemos el plan." |
| Día saturado | "Hoy hay mucho. ¿Dejamos solo lo esencial?" |
| Sin conexión | "Sin conexión: se guarda y se sincroniza después." |

### G.8 Accesibilidad y seguridad de uso
- **Nunca** se exige leer ni tocar la pantalla mientras se maneja: el modo traslado es de audio y voz.
- En la bicicleta, pantalla atenuada y botones grandes; el mapa no pide interacción en movimiento.
- Contraste suficiente, tamaño de letra grande y soporte de lector de pantalla.
- Hábitos sensibles protegidos con PIN o biometría y notificaciones discretas.

### G.9 Preguntas abiertas
1. ¿Prefieres tema claro, oscuro o automático?
2. ¿Qué tamaño de letra te resulta cómodo, para el lector bíblico y para la app en general?
3. ¿Quieres iconos con emojis o iconos más sobrios?
4. De las tres pantallas detalladas en G.10 (Hoy, bicicleta y panel de hábitos), ¿qué cambiarías o qué falta?

### G.10 Pantallas en detalle

#### G.10.1 P01 · Hoy

**Propósito:** que el usuario sepa en 3 segundos **qué sigue**, **qué falta hoy** y pueda registrar con un toque.

**Zonas (de arriba abajo)**
1. **Encabezado:** fecha, saludo según la hora, racha global y ajustes.
2. **Tarjeta "Sigue":** el próximo bloque o el que está **en curso** (con temporizador), con una acción principal y "Posponer".
3. **Lista de hoy**, agrupada por franja (mañana, traslado y trabajo, noche), con barra de progreso.
4. **Medidor de carga del día** (ligero, equilibrado o saturado).
5. **Accesos:** versículo del día y botón "Tengo un antojo".
6. **Banners contextuales** (si aplican): modo foco, revisión semanal, ruta del sábado, preparación del Día D.

**Reglas**
- **Orden:** por hora; lo que no tiene hora va al final de su franja.
- **"Sigue"** elige el bloque más cercano que no esté hecho; si hay uno en curso, muestra "En curso" con el tiempo transcurrido. Si es un traslado, ofrece el botón **Modo traslado**.
- Lo **hecho** se colapsa al final; lo **omitido** puede llevar un motivo opcional.
- **Racha global:** días en que se cumplieron los **mínimos del día** (los define el usuario en el asistente; por defecto, una acción por cada área activa). Incluye **día de gracia** semanal.
- **Modo foco:** si está activo, la lista muestra **solo lo esencial** y un banner lo explica.
- **Sábado:** tarjeta de ruta a las 8:00 y de revisión semanal a las 14:30 (con aviso a las 14:15).
- **Mensajes** siempre sin culpa; la racha rota se muestra como "retomemos".

**Interacciones**
- Deslizar a la derecha: **hecho**; a la izquierda: **posponer u omitir**. Tras marcar, aparece **Deshacer** unos segundos.
- Tocar: abre el detalle; mantener presionado: opciones (mover, editar, cambiar versión corta).
- Tirar hacia abajo: sincronizar y actualizar.
- Doble toque en el encabezado: volver a "Sigue".

**Estados**
| Estado | Qué muestra |
|---|---|
| Primer uso | Invitación a ejecutar el asistente de configuración |
| Sin bloques hoy | "Hoy está libre. ¿Agregamos algo pequeño?" y botón de agregar |
| Todo hecho | Cierre sobrio del día, con un resumen y vista previa de mañana |
| Sin conexión | Indicador discreto; todo se guarda y se sincroniza después |
| Error al cargar | Mensaje con botón de reintentar; la lista local sigue visible |

**Datos:** `Bloque`, `Tarea`, `Objetivo`, `RachaGlobal`, `VersiculoDia`, `CargaDia`, estado del modo foco.

**Notificaciones y widget:** recordatorio del bloque (con minutos de antelación configurables) con acciones Hecho, Posponer 10 min y Omitir; widget "Sigue" y botón de antojo.

**Accesibilidad:** cada fila anuncia su estado; las acciones de deslizar tienen un equivalente con botones para lector de pantalla.

**Criterios de aceptación**
- [ ] La tarjeta "Sigue" cambia sola cuando termina o se omite un bloque.
- [ ] Marcar y deshacer funcionan sin conexión y se sincronizan después.
- [ ] El orden respeta la hora y las franjas.
- [ ] El modo foco oculta lo no esencial.
- [ ] La racha respeta los mínimos del día y el día de gracia.
- [ ] El botón de antojo está visible en todas las condiciones.
- [ ] Todas las acciones por deslizamiento tienen alternativa accesible.

#### G.10.2 P21 · Bicicleta: visor de ruta

**Propósito:** acompañar una salida de unas 4 horas, sin pedir interacción en movimiento, y guardar bien el recorrido.

**Tres fases:** Planear, En vivo y Resumen.

**Fase 1: Planear**
- Elegir una **ruta guardada**, crear una nueva o **importar GPX**.
- **Lista de preparación** (editable): agua, casco, luces, herramientas, bicicleta revisada, teléfono cargado y clima.
- Muestra **clima**, hora estimada de regreso y distancia y desnivel previstos.
- **Mapas sin conexión** descargados (si faltan, la app lo avisa).
- Opción de **compartir la hora de regreso** y la ubicación en vivo con una persona de confianza.
- Elegir la **lista de música** (con la app de música de cada persona).

**Fase 2: En vivo**
```
┌──────────────────────────────────┐
│ ┌──────────────────────────────┐ │
│ │          MAPA (60 %)         │ │
│ │  planeada ─ ─   recorrida ━━ │ │
│ │              ● tú            │ │
│ └──────────────────────────────┘ │
│ 1:42:10 · 32,4 km · ▲ 410 m      │
│ 19 km/h · Agua en 8 min          │
│ ♪ Lista bicicleta  ⏮ ⏯ ⏭         │
│ [⏸ Pausar]  [📍 Compartir]  [SOS]│
│ (mantener 2 s para Terminar)     │
└──────────────────────────────────┘
```
- **Mapa** con ruta planeada y recorrida, posición y orientación; **datos grandes** (tiempo, distancia, desnivel y velocidad).
- **Recordatorios de hidratación y comida** por intervalos que el usuario define, con vibración y voz breve de volumen bajo (la música baja mientras habla).
- **Aviso de desvío** si se aleja de la ruta planeada.
- **Auto-pausa** al detenerse y reanudación automática.
- **Terminar** exige mantener presionado 2 segundos, para evitar toques accidentales.
- **Bloqueo táctil** opcional para evitar toques en el bolsillo o el manubrio.
- **SOS:** envía la ubicación al contacto de emergencia.
- **Modo ahorro de batería:** pantalla atenuada y menos actualizaciones; la grabación sigue.
- **Sin señal:** el mapa usa los datos sin conexión; la grabación sigue con el GPS.
- Si la app se cierra o el teléfono se reinicia, **recupera la salida** en curso.

**Fase 3: Resumen**
- Mapa con el recorrido, distancia, tiempo, desnivel, velocidad media y pausas.
- **Esfuerzo percibido** (1 a 5), hidratación y una nota.
- Opciones: guardar como favorita, **exportar GPX** y escribir la sesión en Health Connect (con permiso).
- Sugerencia de **recuperación** y ajuste de la carga del domingo.

**Estados y errores**
| Situación | Qué hace |
|---|---|
| Sin permiso de ubicación | Explica por qué se necesita y lleva a concederlo |
| Señal GPS débil | Indicador y sigue intentando; no pierde lo grabado |
| Batería baja | Aviso, propone el modo ahorro y guardar la salida |
| Mapas sin conexión no descargados | Avisa antes de salir |
| Error al guardar | Conserva un borrador local y reintenta |

**Permisos:** ubicación precisa, ubicación en segundo plano (con servicio en primer plano y notificación visible), notificaciones y, opcional, Health Connect.

**Datos:** `RutaBici`, `SalidaBici`, `PuntoRuta` (muestreo adaptativo por tiempo y distancia, guardado incremental), `ListaMusica`, `SesionMusica`.

**Criterios de aceptación**
- [ ] Una salida de 4 horas queda grabada completa, con la pantalla apagada y sin conexión.
- [ ] Si la app se cierra, la salida se recupera.
- [ ] Terminar requiere mantener presionado; no se puede terminar por un toque accidental.
- [ ] El consumo de batería es razonable y existe el modo ahorro.
- [ ] La música baja cuando la app habla y vuelve después.
- [ ] El resumen se guarda, se exporta a GPX y se puede escribir en Health Connect con permiso.
- [ ] Los puntos de ruta son privados y se pueden borrar.

#### G.10.3 P09 · Panel de hábito a eliminar (cigarrillo y azúcar)

**Propósito:** mostrar dónde está el usuario **hoy**, dar una acción inmediata (registrar o pedir ayuda) y sostener la motivación **sin juicio**.

**Zonas**
1. **Encabezado:** hábito, fase actual y ajustes.
2. **Tarjeta de estado de hoy** (cambia según el hábito y la fase).
3. **Rachas:** racha actual, mejor racha y días libres acumulados.
4. **Cuenta regresiva** al Día D (si aplica).
5. **Acciones:** **Registrar** y **Tengo un antojo**, siempre visibles.
6. **Pestañas internas:** Hoy, Patrones, Hitos, Apoyo y Motivos.
7. **Ahorro** (oculto por defecto) y mensaje de ánimo del día.

**Estados por fase**
| Fase | Qué muestra |
|---|---|
| **Línea base** | "Solo observamos": se registra, sin metas ni semáforo |
| **Reducción** | Límite del día que baja por etapas, semáforo y, opcional, "próximo permitido a las HH:MM" |
| **Preparación** | Lista de tareas del Día D (cita, entorno limpio, apoyo, SOS) |
| **Día D** | Tarjeta especial con lista del día, mensajes de apoyo y agenda ligera |
| **Libre** | Días libres, mejor racha, hitos y modo foco durante las primeras 2 semanas |
| **Recaída** | Mensaje de partida sin culpa, ajuste del plan y reinicio de la racha actual |
| **Mantenimiento** | Revisión mensual y recordatorio de motivos |

**Cigarrillo**
- Tarjeta: "Hoy: X de Y" según el límite de la fase, y racha de días bajo la meta.
- **Registrar** suma un cigarrillo con la hora actual; luego una hoja inferior permite añadir **disparador, ánimo y compañía** (todo opcional, nunca obligatorio).
- Superar el límite **no se pinta de rojo**: se muestra con color suave y la pregunta "¿Qué te ayudaría mañana?".

**Azúcar**
- Tarjeta con **semáforo** según las reglas del usuario (listas verde, amarilla y roja).
- Contador de **refrescos ocasionales**: "este mes: X de Y planeadas" y registro como **ocasión planeada** o **no planeada**.
- **Registrar** por porción (bebida, postre o botana), con un toque.
- Si el antojo es impulsivo, el flujo sugiere primero el SOS de 10 minutos.

**Interacciones**
- Registrar y **Deshacer** en un toque; editar la hora si fue antes.
- El botón de antojo abre el SOS (y también funciona **por voz**).
- Mantener presionado un registro: editar o eliminar.

**Privacidad**
- Se abre con **PIN o biometría** si el usuario lo activa.
- **Notificaciones discretas** (sin nombrar el hábito).
- Opción de **ocultar la vista previa** en apps recientes y de bloquear capturas.
- **Ahorro y cifras** visibles solo si el usuario lo decide; nunca se comparten sin su permiso.

**Datos:** `HabitoEliminar`, `LineaBase`, `RegistroConsumo`, `Antojo`, `PlanSiEntonces`, `Reemplazo`, `Recaida`, `RachaHabito`, `Hito`, `ApoyoHabito`.

**Criterios de aceptación**
- [ ] Registrar un consumo toma un solo toque y se puede deshacer.
- [ ] La pantalla cambia según la fase y no muestra metas en la línea base.
- [ ] El botón de antojo es accesible desde cualquier pantalla del hábito y por voz.
- [ ] Ninguna cifra ni mensaje culpa al usuario; la recaída activa el protocolo de ajuste.
- [ ] Reiniciar la racha conserva la mejor racha y los días libres acumulados.
- [ ] Con las opciones de privacidad activadas, no aparece el nombre del hábito en notificaciones ni en la vista previa de apps recientes.
- [ ] El Día D y el modo foco se programan y se activan según la fecha configurada en la app.

---

## Anexo H — Plan de construcción por etapas (para Claude Code)

### H.1 Principios
1. **Cada etapa deja una app que funciona** y se puede usar en un teléfono real.
2. **Etapas pequeñas,** con criterios de aceptación y pruebas.
3. **Lo más útil primero:** el núcleo y los hábitos a eliminar antes que lo sofisticado.
4. **Offline-first:** todo funciona sin conexión; la sincronización es una capa posterior.
5. **Configurable:** nada de horarios, cantidades ni textos de ejemplo queda fijo en el código (ver 7.2 y F.15).
6. **Datos sensibles protegidos desde la primera etapa** (PIN, notificaciones discretas, nada a la IA por defecto).
7. **Probar en un Android real** (GPS, notificaciones, segundo plano y Health Connect no se prueban bien en el emulador).

### H.2 Arquitectura propuesta (Flutter)

| Capa | Propuesta |
|---|---|
| **Presentación** | Flutter con Material 3, tema claro y oscuro, es y en (internacionalización) |
| **Estado** | Un gestor de estado simple y probado (por ejemplo, Riverpod) |
| **Navegación** | Navegación declarativa (por ejemplo, go_router), con barra inferior de 5 pestañas |
| **Datos locales** | Base SQLite con una capa tipada (por ejemplo, Drift); es la **fuente principal** |
| **Módulos por área** | Una carpeta por área (espiritual, salud, inglés, hábitos a eliminar, agenda, etc.) con sus pantallas, datos y lógica |
| **Servicios comunes** | Notificaciones locales, audio y voz, ubicación, almacenamiento seguro, bloqueo con PIN o biometría, archivos |
| **Sincronización y respaldo** | Capa posterior (Firebase Spark) para respaldo y pareja |
| **IA** | Módulo opcional, apagado por defecto, con la clave en el almacenamiento seguro |

**Candidatos de paquetes** (verificar las versiones y el mantenimiento vigentes antes de usarlos): gestor de estado, navegación, base local, notificaciones locales, ubicación, mapas, reproducción de audio, voz (reconocimiento y síntesis), almacenamiento seguro, autenticación biométrica, compartir y selector de archivos, y Health Connect.

**Estructura sugerida**
```
lib/
  core/        (tema, rutas, configuración, plantillas, utilidades)
  data/        (base local, repositorios, migraciones)
  services/    (notificaciones, audio, voz, ubicación, seguridad)
  features/
    hoy/  agenda/  objetivos/  progreso/  revision/  ajustes/
    habitos_eliminar/  espiritual/  salud/  ingles/  bicicleta/
    estudios/  pareja/  conexion_presupuesto/  coach/
  l10n/        (textos es y en)
test/          (pruebas por módulo)
```

**Reglas técnicas**
- Plantillas y textos de ejemplo en **archivos de configuración**, no en el código.
- **Migraciones** de la base de datos desde la primera versión.
- **Respaldo y exportación** local desde la etapa 0.
- Errores y estados vacíos en todas las pantallas.
- Sin claves ni datos reales en el repositorio.

### H.3 Etapas

| Etapa | Nombre | Resultado utilizable |
|---|---|---|
| 0 | Fundaciones | App vacía, con navegación, tema, base local y seguridad |
| 1 | Núcleo | Objetivos, Hoy, registro, rachas y carga del día |
| 2 | Hábitos a eliminar | Cigarrillo y azúcar con línea base, registro y SOS |
| 3 | Agenda y asistente | Horario, traslado, bloques y configuración inicial |
| 4 | Espiritual (MVP) | Lector, plan de lectura, devocional y oración |
| 5 | Progreso y revisión | Revisión semanal, gráficas y libros |
| 6 | Salud | Sueño, entrenamiento, suplementos y medidas |
| 7 | Bicicleta y música | Grabar y ver rutas; enlaces a la música |
| 8 | Inglés y modo traslado | Lecciones, vocabulario, escucha y pronunciación |
| 9 | Estudios y vida espiritual ampliada | Estudios guiados, práctica, memorización, ayuno e iglesia |
| 10 | Pareja y conexiones | Compartir, conexión con Presupuesto y Health Connect |
| 11 | IA opcional | Coach, rutinas y tutor |

**MVP = etapas 0 a 5.** Los hábitos a eliminar van **antes** que la agenda porque el plan de reducción de cigarrillo es el más urgente (y la línea base se puede empezar en papel mientras tanto).

#### Etapa 0 · Fundaciones
- **Tareas:** proyecto Flutter, tema Material 3 claro y oscuro, es y en, navegación con 5 pestañas, base local con migraciones, repositorios, ajustes, **PIN o biometría**, respaldo y exportación local, pruebas automáticas y compilación de prueba (APK).
- **Aceptación:** la app abre en un teléfono real; cambia de tema; el PIN protege secciones sensibles; se exporta e importa un respaldo; las pruebas pasan.

#### Etapa 1 · Núcleo
- **Tareas:** modelo de objetivo, bloque y registro; crear y editar objetivos (asistente SMART); pantalla **Hoy** (P01); marcar, posponer y omitir; mínimos del día; rachas con día de gracia; medidor de carga básico.
- **Aceptación:** crear un objetivo diario y marcarlo; la racha respeta los mínimos y el día de gracia; funciona sin conexión; criterios de G.10.1 (los que apliquen).

#### Etapa 2 · Hábitos a eliminar
- **Tareas:** configurar hábito (cigarrillo y azúcar), **línea base de 7 días**, registro en un toque con deshacer, fases (línea base, reducción, preparación, Día D, libre, recaída, mantenimiento), **SOS** con temporizador, recaídas sin culpa, hitos, racha y mejor racha, privacidad (PIN, notificaciones discretas, ocultar vista previa).
- **Aceptación:** criterios de G.10.3; las fechas y las metas se configuran en la app; el Día D y el modo foco se activan según la fecha; reiniciar la racha conserva la mejor racha y los días libres.

#### Etapa 3 · Agenda y asistente
- **Tareas:** agenda (día, semana y mes); bloques recurrentes; horario laboral fijo y traslado; **asistente de configuración** de 12 pasos; recordatorios locales con acciones; búsqueda de huecos y conflictos; medidor de carga; modo foco; widget "Sigue".
- **Aceptación:** el asistente genera una semana tipo; un bloque se mueve y avisa de conflictos; los recordatorios llegan con la app cerrada; las notificaciones tienen acciones.

#### Etapa 4 · Espiritual (MVP)
- **Tareas:** lector con versiones de dominio público (RVR1909 y KJV) mientras se resuelve la licencia de RVR1960 y NVI; plan de lectura (ruta de inicio con Juan); notas y subrayados; devocional con plantilla; diario de oración (pendiente, en espera y respondida); recordatorio de dar **opcional**; privacidad del diario.
- **Aceptación:** leer y avanzar el plan sin conexión; cambiar de versión sin perder notas; poner al día un plan atrasado; el diario no se envía a ningún servicio.

#### Etapa 5 · Progreso y revisión
- **Tareas:** **revisión semanal** de los sábados con aviso previo; revisión mensual; gráficas por área; calendario de constancia; módulo de libros (biblioteca, metas de páginas y notas).
- **Aceptación:** la revisión semanal recorre los pasos definidos y guarda lo respondido; los gráficos reflejan los registros; se programan el aviso y el bloque en la agenda.

#### Etapa 6 · Salud
- **Tareas:** sueño (registro y plan de transición escalonada con recordatorios); entrenamiento (inventario de aparatos, rutinas por plantillas, registro de series y versiones corta, estándar y larga); sesiones regenerativas; suplementos (horarios e inventario); medidas; citas médicas.
- **Aceptación:** la transición de sueño mueve el horario por pasos; la rutina usa solo los aparatos del inventario; el modo foco pausa los incrementos.

#### Etapa 7 · Bicicleta y música
- **Tareas:** planear, grabar con GPS en segundo plano y ver la ruta (P21); mapas sin conexión; importar y exportar GPX; hidratación y recordatorios; compartir ubicación (opcional); abrir listas de música por persona y controles de medios de Android.
- **Aceptación:** criterios de G.10.2; una salida de 4 horas se graba completa; la música baja cuando la app habla.

#### Etapa 8 · Inglés y modo traslado
- **Tareas:** prueba de nivel; lecciones y módulos; vocabulario con **repaso espaciado**; escucha con síntesis de voz; pronunciación con reconocimiento de voz; interfaz bilingüe con inmersión graduable; **modo traslado** solo audio y voz.
- **Aceptación:** una lección completa funciona sin conexión; la inmersión cambia el porcentaje de la interfaz; el modo traslado se maneja por voz.

#### Etapa 9 · Estudios y vida espiritual ampliada
- **Tareas:** estudios guiados con catálogo; "poner en práctica" (compromisos, registros y revisión semanal); estudio por métodos (exégesis intermedia); memorización con repaso espaciado; ayuno con preguntas de seguridad; iglesia y notas de predicación; versiones con licencia, concordancia y diccionarios.
- **Aceptación:** una práctica de un estudio aparece en la revisión semanal; el ayuno no se activa sin las preguntas de seguridad.

#### Etapa 10 · Pareja y conexiones
- **Tareas:** modo pareja (compartir por elemento); respaldo y sincronía (Firebase Spark); **conexión con Presupuesto** (archivos JSON y enlaces, según el contrato); Health Connect (peso, agua, sueño, ejercicio y lectura de comidas).
- **Aceptación:** lo marcado como privado no se comparte; la app funciona completa sin Presupuesto; las pruebas del contrato pasan.

#### Etapa 11 · IA opcional
- **Tareas:** coach de revisión semanal, generador de rutinas, tutor de inglés y ayudas de estudio, con **clave en almacenamiento seguro**, límites de gasto y datos mínimos.
- **Aceptación:** la app es completa con la IA apagada; nada sensible se envía sin activación; hay límite diario y mensaje claro de uso.

### H.4 Cómo trabajar con Claude Code

**Archivos que se le dan a cada sesión**
- `DISENO_APP_HABITOS.md` (este documento).
- `CLAUDE.md` con las reglas del proyecto (ver abajo).
- `CONTRATO_CONEXION_APPS.md` (solo desde la etapa 10).

**Plantilla de `CLAUDE.md`**
```text
Proyecto: App de Hábitos (Android, Flutter). Diseño en DISENO_APP_HABITOS.md.
Reglas:
- Trabaja una etapa a la vez (Anexo H). No adelantes funciones de etapas futuras.
- Offline-first: la base local es la fuente principal.
- Nada de horarios, cantidades ni textos de ejemplo fijos en el código: van en configuración o plantillas.
- Datos sensibles (hábitos a eliminar, oración, ubicación, salud): privados por defecto, protegidos con PIN, sin enviarse a la IA ni a otras apps sin activación explícita.
- Mensajes sin culpa; las recaídas son datos para ajustar, no fracasos.
- Todas las pantallas con estado vacío, cargando, sin conexión y error.
- No guardes claves ni datos reales en el repositorio.
- Escribe pruebas para cada criterio de aceptación de la etapa.
- Si algo del diseño no cuadra, dime qué propondrías cambiar y por qué; no lo cambies sin avisarme.
```

**Prompt de inicio de etapa**
```text
Lee DISENO_APP_HABITOS.md (Anexo H y las secciones que menciona la etapa N) y CLAUDE.md.
Implementa SOLO la etapa N del Anexo H.
1. Resume el alcance y los criterios de aceptación y propón un plan de tareas.
2. Espera mi confirmación antes de escribir código.
3. Implementa por partes pequeñas con pruebas.
4. Al terminar, genera un APK de prueba y una lista de lo que debo probar en el teléfono.
```

**Prompt de cierre de etapa**
```text
Revisa los criterios de aceptación de la etapa N uno por uno e indica cuáles se cumplen, cuáles no
y qué pruebas lo demuestran. Lista las decisiones que tomaste, los pendientes y los riesgos.
No empieces la etapa siguiente.
```

**Flujo**
- Una **rama por etapa**, commits pequeños y una revisión al terminar.
- **Probar en el teléfono** después de cada parte; anotar problemas y pedir correcciones.
- Si se cambia el diseño, **se actualiza primero el documento**.
- Para etapas con dependencias externas (licencia bíblica, mapas, IA, Health Connect), se deja una **interfaz con un proveedor de reemplazo** (por ejemplo, versiones de dominio público) para no bloquear.

### H.5 Plan de pruebas
| Tipo | Qué cubre |
|---|---|
| **Unitarias** | Reglas de rachas, mínimos, fases del hábito, repaso espaciado, transición de sueño, medidor de carga |
| **De datos** | Migraciones, respaldo y restauración, exportación |
| **De interfaz** | Estados vacío, cargando, sin conexión y error; accesibilidad básica |
| **En teléfono real** (Galaxy A52 SM-A525M) | Notificaciones con la app cerrada, GPS en segundo plano de 4 horas, batería, audio y voz |
| **De privacidad** | PIN, notificaciones discretas, vista previa oculta, nada enviado sin activación |
| **De uso real** | Una semana usando la app antes de pasar a la siguiente etapa grande |

### H.6 Riesgos y mitigaciones
| Riesgo | Mitigación |
|---|---|
| **Alcance muy grande** | Etapas pequeñas; el MVP es solo 0 a 5; nada de funciones de etapas futuras |
| **Licencias bíblicas (RVR1960 y NVI)** | Empezar con versiones de dominio público y una interfaz de proveedor intercambiable |
| **Batería y GPS en 4 horas** | Muestreo adaptativo, modo ahorro y pruebas con salidas reales |
| **Notificaciones que no llegan** (ahorro de batería) | Permisos explicados, pruebas en el teléfono real y recordatorios dentro de la app |
| **Clave de la IA** | Almacenamiento seguro, límites de gasto y proxy si crece |
| **Datos sensibles** | Privado por defecto, PIN, nada a la IA sin activación y exportación y borrado completos |
| **Exceso de cambios al mismo tiempo en la vida real** | El medidor de carga y el modo foco evitan saturar al usuario |
| **Sincronización y conflictos** | Dejar la nube para la etapa 10; antes, respaldo manual |

### H.7 Decisiones técnicas por confirmar
1. ¿Gestor de estado, navegación y base local propuestos o prefieres otros?
2. ¿Mapas basados en OpenStreetMap o un SDK comercial?
3. ¿La licencia de RVR1960 y NVI se resuelve antes de la etapa 4 o se arranca con versiones de dominio público?
4. ¿Quién programa y prueba cada etapa (solo con Claude Code o con apoyo de una persona técnica)?
5. **Teléfono de pruebas:** Samsung Galaxy A52 (SM-A525M). Verificar la versión de Android instalada (Ajustes > Acerca del teléfono) y quitar la optimización de batería de la app durante las pruebas de notificaciones y GPS.
6. **Spec-Driven Development:** anotado en el Anexo I; se desarrolla cuando se unan los repositorios.

---

## Anexo I — Spec-Driven Development (anotado, pendiente)

**Estado:** anotado. **No está desarrollado todavía:** se desarrollará cuando se unan los repositorios (ver `CONTRATO_CONEXION_APPS.md`).

### I.1 Qué es
Desarrollo guiado por especificaciones: primero se escribe **qué** se necesita y **por qué** (la especificación), después el **plan técnico**, luego las **tareas**, y al final la IA **implementa** y se **verifica** contra la especificación. Una herramienta conocida es **GitHub Spec Kit**, que funciona con Claude Code (flujo: constitución, especificar, planear, tareas e implementar). Es una herramienta joven y cambia con frecuencia: revisar su documentación vigente antes de adoptarla.

### I.2 Qué ya cubre este proyecto
| Pieza de SDD | Equivalente actual |
|---|---|
| **Constitución** (principios y reglas) | Plantilla de `CLAUDE.md` y principios del Anexo H (H.1 y H.2) |
| **Especificación** (qué y por qué) | Este documento y sus anexos (aún mezclados con el "cómo") |
| **Plan técnico** (cómo) | Arquitectura de H.2, modelos de datos y decisiones técnicas |
| **Tareas** | Tareas de cada etapa en H.3 |
| **Implementación** | Prompts de inicio y cierre de etapa (H.4) |
| **Verificación** | Criterios de aceptación (G.10 y H.3) y fixtures del contrato |

### I.3 Qué falta (para desarrollar cuando se unan los repos)
1. **Decidir** si se usa Spec Kit o una versión ligera con los mismos pasos.
2. **Separar el "qué" del "cómo"** en este documento (hoy están mezclados).
3. Crear una **especificación corta por etapa** (etapas 0 a 11), con historias de usuario y escenarios "dado, cuando, entonces".
4. Redactar la **constitución común** para los dos repositorios.
5. Escribir el **plan técnico** y el **archivo de tareas** de cada etapa.
6. Agregar un paso de **análisis de consistencia** entre especificación, plan y tareas.
7. Actualizar los prompts de H.4 y del contrato (sección 13) para que cada sesión lea **solo la especificación de su etapa**, el plan, el contrato y la constitución.
8. Empezar por las **etapas 0 a 3** como piloto.

### I.4 Estructura propuesta
```
specs/
  000-fundaciones/   spec.md  plan.md  tasks.md
  001-nucleo/        spec.md  plan.md  tasks.md
  002-habitos-eliminar/ ...
  003-agenda-asistente/ ...
```
- Las especificaciones compartidas entre apps (como el contrato) viven en `contrato-apps/`.
- Cada repositorio mantiene su propia carpeta `specs/`.

### I.5 Plantilla ligera de especificación
```text
# Especificación: <nombre de la etapa>
Contexto y objetivo
Historias de usuario (como… quiero… para…)
Escenarios de aceptación (dado… cuando… entonces…)
Requisitos funcionales
Reglas y restricciones (privacidad, sin culpa, sin conexión, configuración dentro de la app)
Fuera de alcance
Datos involucrados
Preguntas abiertas
```

---

*Documento vivo: se irá refinando por secciones.*
