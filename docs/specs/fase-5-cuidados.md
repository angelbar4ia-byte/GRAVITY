# Fase 5 · Cuidados (especificación)

> v1.6, 8/nov/2026 (respuestas del dueño sobre medicamentos de la hermana y bitácora de la pareja). Aprobada por el dueño con sus respuestas del mismo día. El documento de la app de cuidados actual se pospone a la siguiente sesión. Base: D2, D5, D18 y las respuestas del dueño a D5 (7/nov/2026). Pendiente: el documento de la app de cuidados actual (no está en el repositorio); mientras llega, esta especificación se apoya en la descripción del roadmap (Fase 5).

## 1. Alcance

- **Teléfono (cuidadora, hermana):** mi turno y entrega de turno, horario de medicamentos con marcado de "dado", comidas de Papá (comió, comió poco, rechazó), bitácora y gastos de cuidado.
- **Laptop (dueño):** medicamentos, citas, turnos y cuidadoras; resumen y costos. Los gastos de cuidado pasan a Finanzas con confirmación.
- **Cambios urgentes** desde el teléfono del dueño, con aviso inmediato a la cuidadora de turno (D4).
- **Recordatorios** al teléfono de quien está de turno (D5).
- Fuera de esta fase: el modo por voz (ver §6, pendiente) y la identificación por voz.

## 2. Personas y roles (D5)

| Persona | Rol | Cuidados | Dinero |
|---|---|---|---|
| Dueño | Dueño y **cuidador de turno** los domingos y en la tarde de sábados y lunes | Completo | Sus finanzas, compartidas y las de Papá como albacea |
| Pareja | Co-administrador | Según consentimiento (§4) | Sus finanzas y las compartidas |
| Cuidadora principal | Cuidador | Su turno, medicamentos, comidas de Papá, bitácora | Solo los gastos de cuidado que registra |
| Hermana | Cuidador (familiar) | Su turno de martes y visitas; resumen mensual (§4) | Gastos de cuidado que registra y el resumen mensual |
| Papá | Persona bajo cuidado | Titular de los datos (no usa la app) | — |

- La cuidadora **no ve** nada de la familia fuera de Cuidados.
- La hermana ve el **registro mensual del costo del cuidado** y los **gastos de la casa**, excepto los que corresponden a la pareja y al dueño (respuesta del dueño, 7/nov/2026). El **albacea** autoriza los datos que ella ve.

## 3. Turnos (respuesta del dueño, 7/nov/2026)

| Día | Cuidadora principal | Hermana |
|---|---|---|
| Lunes | 9:00 a 15:00; el dueño, de 15:00 en adelante | — |
| Martes | 7:30 a 15:00 | 15:00 en adelante |
| Miércoles | 7:30 a 18:30 | Se va a las 7:00 |
| Jueves | 7:30 a 18:30 | — |
| Viernes | 7:30 a 18:30 | — |
| Sábado | 9:00 a 15:00; el dueño, de 15:00 en adelante | Visitas de fin de semana |
| Domingo | — (el dueño lo cuida **todo el día**) | Visitas de fin de semana |

Reglas:
- Los recordatorios de medicamentos y comidas llegan a **quien está de turno** en ese momento (D5). Fuera de turno no llega nada a la cuidadora.
- La **entrega de turno** se hace al cambiar de turno (notas para quien sigue).
- Las visitas de la hermana no cambian el turno de la cuidadora.

- El dueño cubre los domingos todo el día y la tarde de sábados y lunes (respuesta del dueño, 7/nov/2026). Sus recordatorios de turno siguen las mismas reglas que los de la cuidadora.

## 4. Consentimientos y datos

- **Papá:** los consentimientos sobre sus datos los firma **el albacea** (respuesta del dueño, 7/nov/2026: "también firma").
- **Pareja:** ve los turnos y el resumen de Papá. **La bitácora de cuidados la ve solo con su consentimiento explícito** (v1.2). Sin consentimiento, no.
- **Dueño:** da su consentimiento para sus propios datos.
- **Resumen mensual del costo del cuidado:** solo para la hermana y el dueño. Sin montos de la pareja ni del dueño.

## 5. Permisos (matriz propuesta)

| Rol | Turno | Medicamentos | Comidas de Papá | Bitácora | Gastos de cuidado | Resumen mensual |
|---|---|---|---|---|---|---|
| Dueño | Total | Total | Total | Total | Total | Total |
| Pareja | Solo lectura (con consentimiento) | Solo lectura | Solo lectura | Solo lectura (con consentimiento) | Sus propios | No |
| Cuidadora (de turno) | Su turno | Marca "dado" | Registra comió/poco/rechazó | Escribe | Los suyos | No |
| Hermana | Sus visitas y martes | Marca y da en su turno (v1.2) | Solo lectura | Escribe | Los suyos | Solo lectura (albacea autoriza) |

- Los permisos se validan **en el servidor** (reglas por rol), no solo en la pantalla (D5).
- Al dar de baja a alguien, pierde el acceso de inmediato; lo que registró queda en la bitácora con su nombre.

## 6. Voz de la hermana (decidido: sin PIN, con identidad pedida de nuevo)

La hermana pidió activar su modo diciendo **"Gravity estoy en casa"** y terminarlo con **"Gravity nos vemos"**, y que el sistema **detecte su voz**. D5 dice que la voz **no identifica de forma segura** a una persona, y las bocinas siempre tienen el rol Casa.

Decisión del dueño (7/nov/2026): **sin PIN**. Si la voz no da seguridad para identificar, la app **pide de nuevo la identidad** de la hermana antes de dar acceso a sus datos.
- La frase **no identifica**: solo activa el modo; después la app pide la identidad (confirmación de su cuenta) antes de mostrar nada.
- Las bocinas siguen con rol Casa; el modo de la hermana vive en el teléfono o la laptop.
- Las frases van con la Fase 6 (voz). En la Fase 5 la hermana activa su modo desde el teléfono con la misma confirmación de identidad.

## 7. Criterios de aceptación (borrador)

1. Un cuidador fuera de turno no recibe recordatorios de medicamentos ni de comidas (prueba con horario).
2. La cuidadora no ve la bitácora ni los datos de la familia fuera de Cuidados (prueba de servidor y de app).
3. La hermana ve el resumen mensual, sin montos de la pareja ni del dueño, solo con autorización del albacea (prueba de servidor).
4. Un cambio urgente del dueño avisa a la cuidadora de turno al instante (prueba de aviso).
5. Dar de baja a un cuidador corta su acceso de inmediato (prueba de servidor).
6. Ningún dato de Cuidados sale a IA, bocinas ni tablet pública (D3).

## 8. Preguntas resueltas (7/nov/2026)

1. Domingos: el dueño cuida todo el día; sábados y lunes, por la tarde.
2. El albacea firma también por Papá.
3. La pareja ve turnos y el resumen de Papá; sin bitácora clínica hasta su consentimiento.
4. Papá vive en la casa de las bocinas. **Consecuencia:** los recordatorios que se dicen en voz alta son genéricos (sin nombre de medicamento ni de persona), según D6.
5. Voz de la hermana: sin PIN; si la voz no da seguridad, se pide de nuevo la identidad.
6. El documento de la app de cuidados actual se revisa en la siguiente sesión. No bloquea la construcción de esta versión.

## 8d. Respuestas del dueño (v1.2, 7/nov/2026)

- **Medicamentos:** la hermana puede **marcar y dar** los medicamentos durante **su turno** (martes por la tarde y visitas), igual que la cuidadora de turno.
- **Pareja con consentimiento:** **sí ve la bitácora** de cuidados (con consentimiento explícito; sin consentimiento, no).

## 8h. Respuestas del dueño (v1.6, 8/nov/2026)

- **Horarios de comida:** desayuno 8:30, comida 14:00, colación 17:00 y cena 19:00 **por omisión**, pero **editables** por el dueño (el servidor los guarda por hogar; los recordatorios usan los guardados).
- **Gastos de la casa:** es un gasto **compartido entre Papá, la pareja y el dueño**. Al confirmarlo, el dueño elige el libro compartido donde va (la lista de sus libros compartidos vigentes); no se adivina.
- **Cuenta maestra:** no deja instrucciones (se mantiene).
- **pg_cron:** el dueño lo activa en Supabase; las tomas se generan solas una vez activado.

## 8g. Noches y medicamentos (v1.5, 8/nov/2026)

- **Cambio urgente:** siempre hay alguien a quien avisar. Los martes de noche está la hermana; el resto del tiempo, el dueño (sección 8e). No hay caso sin destinatario.
- **Recordatorios de medicamentos de noche:** **suenan**, y se pueden **posponer hasta el siguiente turno** (quien entre a turno recibe la toma pospuesta).

## 8f. Instrucciones para la cuidadora principal (v1.4, 7/nov/2026)

- **Quién deja instrucciones:** el dueño, la hermana y la pareja.
- **Para quién:** la cuidadora principal. Ella ve esas instrucciones y sus propias entradas (sección 8c).
- **La pareja** puede dejar instrucciones aunque no tenga consentimiento para leer la bitácora. Solo escribe instrucciones; no lee la bitácora ni las entregas sin consentimiento.

## 8e. Roles de cuidador (v1.3, 7/nov/2026)

- **Cuidadora principal:** rol cuidador, con su horario de la sección 3.
- **Hermana:** rol cuidador (D5), con sus turnos y visitas (tipo `hermana_visita`).
- **Dueño:** conserva el rol dueño y, además, es **cuidador de turno** en sus horarios y en los huecos (tipo `dueno`).

## 8c. Respuestas del dueño (v1.1, 7/nov/2026)

- **Bitácora de la cuidadora:** ve lo **suyo** y lo que la **hermana** y el **dueño** escriben o planean para ella con Papá. No ve nada más de la familia.
- **Turno del dueño:** cubre **todo lo que no cubren** la cuidadora ni la hermana, después de su trabajo. Si nadie está de turno, el responsable es el dueño (un cambio urgente y los recordatorios van a él).
- **La visita de la hermana** la define ella.
- **Turnos de la hermana:** se confirman (martes desde las 15:00 y miércoles hasta las 7:00).

## 8b. Respuestas del dueño a preguntas de construcción (7/nov/2026)

- **Noches sin cuidador de turno:** las cubre el **dueño**. Un cambio urgente en esas horas avisa al dueño. (Si no hay turno, el destinatario por omisión es el dueño.)
- **Resumen mensual:** "Cuidados de largo plazo" va **aparte** del rubro Salud, pero **agrupado junto a él**, porque están relacionados.

*Pendiente de respuesta del dueño (del informe de Cuidados):* (a) si la cuidadora ve solo su propia bitácora; (b) si el turno del dueño por la tarde termina a las 24:00 y las visitas de la hermana se muestran todo el día; (c) el turno de la hermana de martes (15:00 a 24:00) y del miércoles (0:00 a 7:00).

## 9. Pendiente de la siguiente sesión

- Documento de la app de cuidados actual: confirmar si algo que hoy usan falta en esta versión.

## 10. Trabajo por agente

- **backend:** tablas de turnos, medicamentos, comidas de Papá, bitácora de cuidados y resumen mensual; RLS por rol; pruebas SQL.
- **cuidados:** pantallas del teléfono (turno, medicamentos, comidas, bitácora, gastos) y de la laptop (resumen, turnos, cuidadoras).
- **plataforma:** recordatorios al turno de quien está de turno; cambio urgente.
- **finanzas:** gastos de cuidado a Finanzas con confirmación; resumen mensual.
- **calidad:** revisión al cierre de la fase.
