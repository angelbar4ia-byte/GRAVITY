# Fase 8 · Alimentación (ampliaciones)

> v1.2, 9/nov/2026 (respuestas del dueño sobre regresar compras de Papá y compras rechazadas; historial revertidas y porciones en la app; diálogos de compra y sugerencia con IA). v1.1, 9/nov/2026. Respuestas del dueño: tiendas editables y borrables; Casa ve platillos solo en la comida familiar y en el menú de Papá; el menú de dueño y pareja es el mismo con porciones recomendadas por persona; compra rechazada no sale del historial (solo cambia de cuenta); se pueden regresar compras. v1.0, 9/nov/2026. Aprobada por el dueño: historial de compra completo y más platillos y recetas con ayuda de la IA y de la despensa. Base: especificación de la Fase 7 (v1.2), D3, D19, D23 y D28.

## 1. Historial de compra (análisis completo)

Se puede ver el historial por cuatro ejes, combinables:
- **Escala de tiempo:** semana, mes, bimestre, semestre y año (igual que el periodo de la aportación).
- **Precio:** cuánto ha subido o bajado cada producto (precio unitario de cada compra real).
- **Producto:** la historia de un ingrediente (cuántas veces, cuánto, a qué precio).
- **Tienda:** en qué tienda se compró cada producto y cuál sale más barata.

Reglas:
- La **tienda se captura en cada compra**, eligiéndola de una lista del hogar (se puede agregar una nueva). *Supuesto a confirmar.*
- El historial usa solo **precios reales** de compra; el precio base de supuesto no entra en el análisis.
- Cada quien ve el historial de su propio libro o de la lista que le toca (la misma regla de Alimentación de la Fase 7). Papá solo lo ve quien tiene su lista (albacea y suplente, Fase 1).
- Los precios no salen a la IA ni a las bocinas (D3).

## 2. Más platillos y recetas (con IA y despensa)

- **Crear recetas:** como hasta ahora, por archivo importado; la IA puede ayudar a redactar el archivo fuera de la app.
- **Sugerir platillos desde la despensa:** la app muestra qué se puede cocinar con lo que hay en la despensa (de la cuenta que lo pide), y la IA puede proponer variantes o recetas nuevas a partir de esos ingredientes.
- **Qué se envía a la IA:** solo nombres de ingredientes y cantidades aproximadas de la despensa, y las preferencias que la persona escriba. **Nunca** el perfil clínico de Papá, sus alergias, su textura ni su dieta (D3, D23).
- Una receta sugerida por la IA **no se guarda** hasta que la persona la confirma.

## 2b. Respuestas del dueño (v1.1)

- **Tiendas:** se pueden **editar** y **borrar**. Una tienda con compras no se borra (se desactiva) para no dejar el historial sin tienda.
- **Casa y platillos:** Casa ve platillos **solo** en la **comida familiar** (plan familiar aprobado) y en el **menú del día de Papá**.
- **Menú de dueño y pareja:** es el **mismo menú**, con **porciones recomendadas** por persona.
- **Compra rechazada por el albacea:** **no sale** del historial; solo **cambia de cuenta**.
- **Regresar compras:** se puede deshacer una compra marcada (vuelve a pendiente) dejando registro; el historial conserva la compra original.

## 2c. Respuestas del dueño (v1.2)

- **Regresar compra de Papá:** la solicitud al albacea **se retira** de su cola y la compra vuelve a pendiente.
- **Compra rechazada:** la compra vuelve a la **cuenta de efectivo** por omisión; la persona puede **elegir otra cuenta de gasto** en su lugar. La compra se queda en el historial.
- **Historial:** las compras regresadas se muestran como **revertidas**.
- **Sugerencia con IA:** el servidor del asistente debe aceptar la acción `sugerir_recetas`.

## 2d. Reembolso de compras de Papá (v1.4, respuestas del dueño del 14/nov/2026)

- **Compra de Papá sin cuenta de pago = solicitud de reembolso** al albacea. Quien compró ya pagó con su dinero.
- **Aprobada:** el albacea paga desde una cuenta de Papá (como hasta ahora).
- **Rechazada:** no sale dinero de Papá. La compra queda como rechazada en el histórico. **No se elige cuenta** y no se asigna a la cuenta de efectivo de Papá (se quita ese valor por omisión de la v1.2).
- **Reenvío:** quien compró puede reenviar la solicitud **una vez**, con una justificación de 3 a 200 caracteres. La solicitud nueva (intento 2) entra a la cola del albacea; la rechazada se conserva.
- **Segundo rechazo:** el gasto es de quien compró. No se registra en el libro de Papá; la compra sigue en el histórico.
- **Histórico:** cada solicitud (cada intento, con su estado y su justificación) queda registrada. El resumen de Papá no suma las compras rechazadas.
- Decisiones de construcción (v1.4): el reenvío lo hace solo quien compró, mediante `ali_reenviar_solicitud`; la guardia de compras deja pasar el paso "rechazada a solicitud" solo desde esa función. Migración `20261142000000`, pruebas `111` (ajustada), `113`, y `110` (el resumen ya no suma lo rechazado).

## 3. Criterios de aceptación

1. El historial se puede filtrar por escala de tiempo, precio, producto y tienda, y las combinaciones dan el mismo total que la suma de compras reales.
2. El precio base de supuesto no aparece en ningún análisis.
3a. Editar o borrar tienda: al borrar una tienda con compras, se desactiva en su lugar.
3b. Regresar una compra deja registro y no borra la original del historial.
3. Una compra sin tienda no se guarda sin tienda (la tienda es obligatoria desde ahora; las compras anteriores quedan como "sin tienda").
4. La sugerencia de platillos usa solo la despensa de la cuenta que la pide.
5. Ningún dato clínico de Papá llega a la IA (prueba: el contexto enviado no contiene su perfil).
6. Una receta sugerida no se guarda sin confirmación.

## 4. Trabajo por agente (cuando se apruebe)

- **alimentacion:** análisis del historial, captura de tienda en la compra, sugerencia de platillos desde la despensa.
- **backend:** tabla de tiendas por hogar y campo de tienda en cada compra; consultas del historial con RLS.
- **asistente:** la sugerencia con IA usa solo el contexto permitido (sección 2).
- **calidad:** revisión al cierre (D3, D23).
