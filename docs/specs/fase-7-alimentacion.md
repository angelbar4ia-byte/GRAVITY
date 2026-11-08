# Fase 7 · Alimentación completa (especificación)

> v1.1, 8/nov/2026. Aprobada por el dueño. v1.1 añade sus respuestas sobre presupuesto, votación y precios. Base: roadmap (Fase 7), D23, D28 (confirmada: se construye aquí), D3, D19, D5 y la especificación de la Fase 4 (`fase-4-alimentacion.md`).

## 1. Alcance

- **Catálogo** de ingredientes y platillos, **recetas paso a paso** y **menú** (menú de Papá y menú de la pareja y del dueño; plan familiar por votación, D28).
- **Despensas e inventario por persona** (D28): el inventario de Papá se separa del de la pareja y del dueño. Se actualiza con las compras.
- **Lista de compras** en el teléfono, para usarla en el súper.
- **Historial de precios con alerta** y **lector de código de barras** (roadmap; FINANZAS fase 3). Los precios se toman solo de lo que captura el usuario o de fuentes verificadas; **nunca se inventan**.
- **Plan de comidas** conectado a Hábitos (marcar cumplimiento) y a Cuidados (comidas de Papá), dentro de la misma app y sin archivos.
- **Suplementos** de Papá (D28): visibles para quien ve el menú de Papá; cada toma se confirma (dado o no dado); si nadie confirma, se solicita reposición.

## 2. Quién ve y hace qué (D28 y D23)

| Cuenta | Menú de Papá | Menú de pareja y dueño | Plan familiar | Despensa de Papá | Compras |
|---|---|---|---|---|---|
| Dueño | Ver y editar | Ver y editar | Ver y votar | Ver y comprar | Confirmar |
| Pareja | Ver y editar | Ver y editar | Ver y votar | Ver y comprar (sobrantes) | Confirmar |
| Familiar (hermana) | Ver y editar | No | Ver, proponer, votar | Ver y elegir ingredientes | Solicitar |
| Cuidadora | Ver (solo lectura) | No | No | No | No |
| Casa | Ver (menú del día) | No | Ver | No | No |

- **Casa:** solo el menú del día de Papá y el plan familiar (D28).
- **Pareja y dueño:** comparten lo que **sobra** de su inventario planeado por semana (D28).
- **Suplementos:** visibles según la tabla de arriba; la confirmación de toma la hace quien la da; Casa solo ve.

## 3. Reglas

- **Dinero en centavos**; el libro de movimientos es solo-agregar (D19). Una compra de la lista genera un movimiento en el libro correspondiente (o una solicitud al albacea para lo de Papá).
- **Menú familiar por votación:** alguien propone; otra persona da su propuesta; ambas se votan; el ganador evalúa los ingredientes faltantes y quien propone puede pedir su compra.
- **Compra de Papá:** la aprueba y paga el albacea (D19); sale del libro de Papá.
- **Perfil clínico de Papá** (alzheimer, dieta, textura) no sale a la IA ni a las bocinas (D3, D23). Las recetas para la bocina no llevan cifras (filtro de salida de la Fase 6b).
- **Precios:** solo los que captura el usuario o de una fuente verificada; no se inventan ni se estiman sin aviso.
- **Lector de código de barras:** cámara del teléfono; el código se busca en el catálogo local; si no existe, se captura a mano.

## 4. Integraciones

- **Hábitos:** el plan de comidas marca el cumplimiento de la comida del día (D11 de Hábitos).
- **Cuidados:** las comidas de Papá (`cui_comidas`) se registran desde el plan; el resultado (comió, comió poco, rechazó) regresa a Alimentación (contrato v2.0, sección 6).
- **Gravity asistente:** las herramientas de solo lectura ya existen (Fase 6b); el asistente no envía precios ni datos clínicos al proveedor.

## 5. Decisiones del dueño (8/nov/2026)

1. **Recetas:** primero se importan desde archivo. Tu pareja y tú las pueden cargar; la IA puede ayudar a redactarlas (sin cifras para la bocina).
2. **Precios:** cada ingrediente o platillo empieza con un **precio base supuesto** (sin mucha relevancia). Al registrar la **primera compra real**, el precio real reemplaza al base y se **actualiza** con las siguientes compras.
3. **Lector de código de barras:** después de la lista de compras.
4. **Lista de compras:** organizada **por pasillo**.
5. **Votación del menú familiar:** dura **un día**. Si hay empate, se decide por **volado** en el servidor.

## 5a. Respuestas del dueño (v1.1, 8/nov/2026)

1. **Presupuesto para comprar:** la familia (y quien participa) puede ver los **precios** de presupuesto, pero **no** cuentas bancarias ni saldos. Puede preguntar si **hay presupuesto para comprar** y recibir **sí o no**, sin cifras de saldo.
2. **Cambio de voto:** se permite **mientras la votación esté abierta**, haya empate o no.
3. **Precios base:** los carga el asistente (arquitecto) como **supuestos**, marcados como base; se reemplazan con la primera compra real.
4. **Empate:** se resuelve con un **volado** (sorteo al cerrar la votación). Ya no se reabre el día.
5. **Precios para el familiar:** están bien (lo necesita para armar el menú de una visita).
6. **Cuenta maestra:** sí lee todas las despensas y listas (D19).

## 5b. Decisiones pendientes

- Ninguna.

1. **Recetas:** ¿quién las carga? (tú, tu pareja, o ambas) y ¿cómo: pantalla en el teléfono o archivo importado?
2. **Precios:** ¿los captura el usuario al comprar, o quieres una fuente externa? Si es externa, cuál (la verificamos antes de usarla).
3. **Lector de código de barras:** ¿hace falta desde la primera versión o después de la lista de compras?
4. **Supermercados:** ¿la lista se organiza por pasillo o solo por nombre?
5. **Votación:** ¿cuánto dura una votación y quién desempata?

## 6. Trabajo por agente (cuando se apruebe)

- **alimentacion:** catálogo, recetas, menú, lista de compras, inventario por persona, plan familiar y votación, precios, lector de código.
- **backend:** tablas de inventario, despensas, plan y votación; RLS por cuenta (D28); suplementos; compras que generan movimientos.
- **plataforma:** cámara del lector, notificaciones de votación y de compras.
- **finanzas:** compras de la lista como movimientos del libro correcto; solicitud al albacea para lo de Papá.
- **calidad:** revisión al cierre (D3, D19, D23, D28).
