# Fase 8 · Bloque 4: Reportes, imagen y voz en el teléfono

> v0.1, 8/nov/2026. Borrador: el dueño aprobó los tres alcances y pidió "todos" en reportes y en imagen, y "solo dictar" en voz. Base: D3, D19, D25 y las especificaciones de los bloques 1 a 3.

## 1. Reportes (todos)

- **Gasto por categoría** por mes (y por el periodo que se configure).
- **Aportación de la casa** por periodo: referencia y aportado por persona y por subcuenta (bloque 1).
- **Resumen de deudas:** saldos, tasas y la estrategia recomendada (bloque 2).
- **Avance de objetivos:** lo que falta y las semanas estimadas (bloque 3).
- Cada reporte respeta el libro de quien lo pide: nadie ve en un reporte lo que no ve en su pantalla (D19).
- Los reportes se pueden ver en la laptop y en el teléfono. Sin cifras fuera de la app (D3).

## 2. Imagen desde el teléfono (todas)

- **Recibos y tickets:** se fotografía el recibo y se propone un gasto; la persona confirma antes de guardar.
- **Estados de cuenta:** se fotografía o se escanea la página para conciliar (bloque 1), sin subir la imagen a ninguna nube.
- **Lectura de la imagen:** el texto se lee **en el teléfono** (sin enviar la imagen a la IA ni al servidor).
- La imagen no se guarda después de registrar el gasto, salvo que la persona lo elija.

*Pendiente de confirmar:* si la imagen se borra al terminar, o si se guarda como comprobante del gasto.

## 3. Voz en el teléfono (solo dictar)

- Se **dicta** un gasto o una consulta; el texto reconocido entra como un mensaje normal (mismo filtro de D3 del servidor).
- **No se leen respuestas en voz alta** en esta fase.
- La voz no identifica ni autoriza: las acciones que requieren confirmación siguen pidiendo botón (D5, D8).

## Criterios de aceptación

1. Un reporte nunca muestra cifras que la persona no vea en su libro (prueba por rol).
2. Un recibo fotografiado propone un gasto que solo se guarda con confirmación.
3. La imagen no sale del teléfono (prueba: sin llamadas de red con la imagen).
4. Dictar un gasto llega como texto y pasa por el mismo flujo que escribirlo.
5. Ninguna cifra de estos reportes llega a la IA ni a las bocinas (D3).

## Pendientes

- Si la imagen se borra al registrar el gasto o se guarda como comprobante.

## Trabajo por agente (cuando se apruebe)

- **finanzas:** reportes por rol y gasto propuesto desde imagen.
- **plataforma:** cámara, reconocimiento de texto en el teléfono (sin nube) y dictado.
- **backend:** consultas de reportes con RLS por libro; sin datos nuevos de imagen en el servidor.
- **calidad:** revisión al cierre (D3, D19).
