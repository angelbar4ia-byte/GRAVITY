# Fase 8 · Bloque 3: Objetivos, inversión, bienes y previsión

> v1.0, 8/nov/2026. Aprobada por el dueño. Base: D19 (libros por persona), D25, D28 (apartado de ahorro) y las respuestas de hoy.

## Alcance

1. **Objetivos:** metas de ahorro con monto y fecha (por ejemplo, un viaje o un fondo para la casa). Se alimentan del **apartado de ahorro** que ya existe.
2. **Inversión:** se registran inversiones con su saldo y su rendimiento. Se **capturan a mano** y también se **leen de los estados en PDF** (solo en la laptop; el PDF no sale de ella). El **cálculo automático** del rendimiento se activa **después**, cuando el dueño lo entienda; por ahora, el rendimiento se captura.
3. **Bienes y previsión:** bienes (auto, casa) y previsión (seguros, pensión). Los valores se **ingresan a mano**, con fecha de captura.

## Reglas

- Cada objetivo, inversión, bien y previsión pertenece a una persona (D19). Solo ella y el dueño como albacea de Papá lo ven; el suplente de Papá lo lee igual que en la Fase 1.
- Dinero en centavos; tasas y rendimientos en puntos base.
- Los datos capturados a mano se marcan como **capturados**; los leídos del PDF, como **verificados** (igual que en deudas).
- El apartado de ahorro de un objetivo no se duplica: el objetivo lee el apartado, no lo copia.
- Ningún dato de inversiones, bienes ni previsión sale a la IA ni a las bocinas (D3).

## Criterios de aceptación

1. Un objetivo muestra cuánto falta y en cuántas semanas se alcanza con su apartado (prueba con datos de ejemplo).
2. Una inversión capturada y una leída del PDF se distinguen por su origen (capturado/verificado).
3. El rendimiento capturado se muestra tal como lo capturó la persona; no se calcula solo en este bloque.
4. Un bien o una previsión sin fecha de captura no se muestra como vigente.
5. Ninguna cifra de este bloque llega a la IA, a las bocinas ni a la tablet pública (D3).

## Trabajo por agente

- **finanzas:** objetivos, inversiones, bienes y previsión en la laptop y la app.
- **backend:** tablas y RPC con RLS por persona (D19); el apartado de ahorro se lee, no se copia.
- **plataforma:** lectura de estados de inversión en PDF en la laptop.
- **calidad:** revisión al cierre (D3, D19).
