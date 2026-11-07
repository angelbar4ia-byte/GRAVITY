# Fase 5 · Cuidados (especificación)

> v0.1, 7/nov/2026. Borrador para aprobación. Base: D2, D5, D18 y las respuestas del dueño a D5 (7/nov/2026). Pendiente: el documento de la app de cuidados actual (no está en el repositorio); mientras llega, esta especificación se apoya en la descripción del roadmap (Fase 5).

## 1. Alcance

- **Teléfono (cuidadora, hermana):** mi turno y entrega de turno, horario de medicamentos con marcado de "dado", comidas de Papá (comió, comió poco, rechazó), bitácora y gastos de cuidado.
- **Laptop (dueño):** medicamentos, citas, turnos y cuidadoras; resumen y costos. Los gastos de cuidado pasan a Finanzas con confirmación.
- **Cambios urgentes** desde el teléfono del dueño, con aviso inmediato a la cuidadora de turno (D4).
- **Recordatorios** al teléfono de quien está de turno (D5).
- Fuera de esta fase: el modo por voz (ver §6, pendiente) y la identificación por voz.

## 2. Personas y roles (D5)

| Persona | Rol | Cuidados | Dinero |
|---|---|---|---|
| Dueño | Dueño | Completo | Sus finanzas, compartidas y las de Papá como albacea |
| Pareja | Co-administrador | Según consentimiento (§4) | Sus finanzas y las compartidas |
| Cuidadora principal | Cuidador | Su turno, medicamentos, comidas de Papá, bitácora | Solo los gastos de cuidado que registra |
| Hermana | Cuidador (familiar) | Su turno de martes y visitas; resumen mensual (§4) | Gastos de cuidado que registra y el resumen mensual |
| Papá | Persona bajo cuidado | Titular de los datos (no usa la app) | — |

- La cuidadora **no ve** nada de la familia fuera de Cuidados.
- La hermana ve el **registro mensual del costo del cuidado** y los **gastos de la casa**, excepto los que corresponden a la pareja y al dueño (respuesta del dueño, 7/nov/2026). El **albacea** autoriza los datos que ella ve.

## 3. Turnos (respuesta del dueño, 7/nov/2026)

| Día | Cuidadora principal | Hermana |
|---|---|---|
| Lunes | 9:00 a 15:00 | — |
| Martes | 7:30 a 15:00 | 15:00 en adelante |
| Miércoles | 7:30 a 18:30 | Se va a las 7:00 |
| Jueves | 7:30 a 18:30 | — |
| Viernes | 7:30 a 18:30 | — |
| Sábado | 9:00 a 15:00 | Visitas de fin de semana |
| Domingo | *No indicado* | Visitas de fin de semana |

Reglas:
- Los recordatorios de medicamentos y comidas llegan a **quien está de turno** en ese momento (D5). Fuera de turno no llega nada a la cuidadora.
- La **entrega de turno** se hace al cambiar de turno (notas para quien sigue).
- Las visitas de la hermana no cambian el turno de la cuidadora.

*Pendiente:* el domingo. Si no hay turno, la app no debe avisar a nadie ese día.

## 4. Consentimientos y datos

- **Papá:** los consentimientos sobre sus datos los da **el albacea** (respuesta del dueño: "albacea autoriza los datos", 7/nov/2026). *Pendiente de confirmar:* si el albacea firma también en nombre de Papá en Cuidados o solo autoriza el resumen de la hermana.
- **Pareja y dueño:** dan su consentimiento para sus propios datos. *Pendiente:* si la pareja ve Cuidados (D5 lo deja "según consentimiento"). Propuesta: la pareja ve el resumen de Papá y los turnos, sin la bitácora clínica, hasta que dé su consentimiento explícito.
- **Resumen mensual del costo del cuidado:** solo para la hermana y el dueño. Sin montos de la pareja ni del dueño.

## 5. Permisos (matriz propuesta)

| Rol | Turno | Medicamentos | Comidas de Papá | Bitácora | Gastos de cuidado | Resumen mensual |
|---|---|---|---|---|---|---|
| Dueño | Total | Total | Total | Total | Total | Total |
| Pareja | Solo lectura (con consentimiento) | Solo lectura | Solo lectura | No | Sus propios | No |
| Cuidadora (de turno) | Su turno | Marca "dado" | Registra comió/poco/rechazó | Escribe | Los suyos | No |
| Hermana | Sus visitas y martes | Solo lectura | Solo lectura | Escribe | Los suyos | Solo lectura (albacea autoriza) |

- Los permisos se validan **en el servidor** (reglas por rol), no solo en la pantalla (D5).
- Al dar de baja a alguien, pierde el acceso de inmediato; lo que registró queda en la bitácora con su nombre.

## 6. Voz de la hermana (conflicto con D5, pendiente)

La hermana pidió activar su modo diciendo **"Gravity estoy en casa"** y terminarlo con **"Gravity nos vemos"**, y que el sistema **detecte su voz**. D5 dice que la voz **no identifica de forma segura** a una persona, y las bocinas siempre tienen el rol Casa.

Propuesta (para decidir, no implementar):
- La frase **no identifica**: solo activa un modo que pide confirmación (PIN o toque) antes de dar acceso a datos de la hermana.
- Las bocinas siguen con rol Casa; el modo de la hermana vive en el teléfono o la laptop.
- Esto va con la Fase 6 (voz). En la Fase 5 no se construye la voz.

## 7. Criterios de aceptación (borrador)

1. Un cuidador fuera de turno no recibe recordatorios de medicamentos ni de comidas (prueba con horario).
2. La cuidadora no ve la bitácora ni los datos de la familia fuera de Cuidados (prueba de servidor y de app).
3. La hermana ve el resumen mensual, sin montos de la pareja ni del dueño, solo con autorización del albacea (prueba de servidor).
4. Un cambio urgente del dueño avisa a la cuidadora de turno al instante (prueba de aviso).
5. Dar de baja a un cuidador corta su acceso de inmediato (prueba de servidor).
6. Ningún dato de Cuidados sale a IA, bocinas ni tablet pública (D3).

## 8. Preguntas abiertas

1. ¿El domingo hay turno de cuidado?
2. ¿El albacea firma también por Papá en Cuidados, o solo autoriza el resumen de la hermana?
3. ¿La pareja ve Cuidados (turnos y resumen de Papá) desde ya?
4. ¿Papá vive en la casa de las bocinas? (Afecta qué se dice en voz alta.)
5. Sobre la voz de la hermana: ¿aceptas la propuesta de §6 (la frase activa un modo que confirma con PIN o toque)?
6. Falta el documento de la app de cuidados actual. ¿Lo compartes o describes sus pantallas?

## 9. Trabajo por agente (cuando se apruebe)

- **backend:** tablas de turnos, medicamentos, comidas de Papá, bitácora de cuidados y resumen mensual; RLS por rol; pruebas SQL.
- **cuidados:** pantallas del teléfono (turno, medicamentos, comidas, bitácora, gastos) y de la laptop (resumen, turnos, cuidadoras).
- **plataforma:** recordatorios al turno de quien está de turno; cambio urgente.
- **finanzas:** gastos de cuidado a Finanzas con confirmación; resumen mensual.
- **calidad:** revisión al cierre de la fase.
