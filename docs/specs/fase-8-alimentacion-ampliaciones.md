# Fase 8 · Alimentación (ampliaciones)

> v1.0, 9/nov/2026. Aprobada por el dueño: historial de compra completo y más platillos y recetas con ayuda de la IA y de la despensa. Base: especificación de la Fase 7 (v1.2), D3, D19, D23 y D28.

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

## 3. Criterios de aceptación

1. El historial se puede filtrar por escala de tiempo, precio, producto y tienda, y las combinaciones dan el mismo total que la suma de compras reales.
2. El precio base de supuesto no aparece en ningún análisis.
3. Una compra sin tienda no se guarda sin tienda (la tienda es obligatoria desde ahora; las compras anteriores quedan como "sin tienda").
4. La sugerencia de platillos usa solo la despensa de la cuenta que la pide.
5. Ningún dato clínico de Papá llega a la IA (prueba: el contexto enviado no contiene su perfil).
6. Una receta sugerida no se guarda sin confirmación.

## 4. Trabajo por agente (cuando se apruebe)

- **alimentacion:** análisis del historial, captura de tienda en la compra, sugerencia de platillos desde la despensa.
- **backend:** tabla de tiendas por hogar y campo de tienda en cada compra; consultas del historial con RLS.
- **asistente:** la sugerencia con IA usa solo el contexto permitido (sección 2).
- **calidad:** revisión al cierre (D3, D23).
