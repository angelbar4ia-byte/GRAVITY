# Fase 8 · Bloque 2: Deudas e intereses

> Cerrada en lo técnico (8/nov/2026). Pendiente de confirmar: la regla de Papá (el suplente lee su libro también con albacea vigente, como fin_puede de la Fase 1). v1.1, 8/nov/2026. Aprobada por el dueño; v1.1 agrega las respuestas de construcción (regla del libro de Papá uniforme con la Fase 1; presupuesto mensual = suma de mínimos, editable; vencimiento con ciclos futuros). Base: D18, D19, D25 y la especificación de deudas de la Fase 2 (`fase-2-finanzas.md`). Las tasas y saldos vienen de los estados de cuenta en PDF (solo en la laptop; no se suben).

## Alcance

1. **Simulador de estrategias de pago.** Compara tres estrategias con las deudas actuales:
   - **Bola de nieve:** pagar primero la deuda de saldo más chico.
   - **Avalancha:** pagar primero la deuda de tasa más alta.
   - **Por fecha de vencimiento:** pagar primero la deuda que vence antes, para evitar recargos y mora. Protege la liquidez de la semana.
2. **Estimador de intereses.** Calcula cuánto se paga de intereses con cada estrategia y con el pago mínimo, usando la tasa y el saldo de cada deuda.
3. **Beneficios de tarjetas.** Registro de los beneficios de cada tarjeta (puntos, cashback, meses sin intereses) con su vigencia, para verlos junto a las deudas. Sin cifras de saldo fuera del libro de la persona dueña de la tarjeta.

## Fuentes de datos

- **Saldos, tasas, pago mínimo y fecha límite:** de los estados de cuenta en PDF, leídos en la laptop. El PDF no sale de la laptop.
- Si un dato no viene en el estado, se captura a mano y se marca como capturado (no como verificado).

## Reglas

- Cada deuda y cada tarjeta pertenece a una persona (D19). Solo la dueña ve sus deudas y sus beneficios; el dueño ve las de la casa y las de Papá solo como albacea.
- Ningún dato de deudas, tasas ni tarjetas sale a la IA ni a las bocinas (D3).
- El simulador **no decide por ti**: muestra cuánto cuesta cada estrategia y recomienda la de menor intereses, pero el pago lo confirmas tú.
- Dinero en centavos; tasas en puntos base (2000 = 20%).
- Ninguna cifra se inventa: si falta una tasa o un saldo, la estrategia dice "falta dato" en lugar de estimar.

## Criterios de aceptación

1. Las tres estrategias dan el mismo total de deuda pagada al final del plan; solo cambia el orden y el interés total.
2. La avalancha paga menos intereses que la bola de nieve cuando las tasas difieren (prueba con datos de ejemplo).
3. La estrategia por vencimiento nunca deja una deuda vencida mientras haya liquidez (prueba con fechas límite).
4. Un dato faltante bloquea solo la estrategia que lo necesita.
5. Ninguna cifra de deuda ni tarjeta llega a la IA, a las bocinas ni a la tablet pública (D3).

## Respuestas del dueño (v1.1, 8/nov/2026)

1. **Libro de Papá:** la regla de deudas y tarjetas se **uniforma con la Fase 1**: el suplente lee el libro de Papá mientras no haya albacea vigente (D19).
2. **Presupuesto mensual:** se **calcula** como la suma de los pagos mínimos, y la persona puede **pedir otro monto** en el simulador.
3. **Vencimiento:** la estrategia **proyecta los ciclos futuros** de cada deuda, no solo la próxima fecha límite.

## Pendientes

- **Bancos y tarjetas:** la lista de bancos y tarjetas con sus beneficios la captura el dueño cuando llegue el momento de cargarlos (no bloquea el simulador).

## Trabajo por agente

- **finanzas:** simulador de las tres estrategias, estimador de intereses y registro de beneficios de tarjetas.
- **backend:** tablas de deudas (si no existen), tarjetas y beneficios, con RLS por persona (D19).
- **plataforma:** lectura de los estados de cuenta en PDF en la laptop (sin subir archivos).
- **calidad:** revisión al cierre (D3, D19).
