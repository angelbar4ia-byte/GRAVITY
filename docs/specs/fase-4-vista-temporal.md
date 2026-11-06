# Vista temporal de Finanzas de Papá para el familiar (D24)

> v0.1, 6/nov/2026. Respuesta del dueño: el familiar **puede ver las finanzas de Papá solo por solicitud** y el dueño autoriza la vista **por 30 minutos**, sin poder tomar capturas ni copiar datos.

## 1. Regla

- El familiar **no** tiene acceso permanente a Finanzas de Papá. Puede **pedir** la vista.
- El dueño (y la pareja, si el dueño lo habilita; por ahora solo el dueño) **autoriza** la solicitud. La autorización dura **30 minutos** y después se cierra sola.
- Durante la vista: **no** hay captura de pantalla (bloqueo de capturas), **no** hay copiar ni seleccionar datos, y **no** hay exportar.
- Cada solicitud, autorización y consulta queda en la bitácora.
- Los montos quedan visibles solo durante la vista; al cerrarse, vuelven a ocultarse.

## 2. Flujo

1. El familiar toca "Pedir ver finanzas de Papá" y escribe el motivo (3 caracteres mínimo).
2. El dueño recibe un aviso discreto ("Solicitud de vista: Familiar") y puede **autorizar 30 min** o **rechazar**.
3. Autorizada, el familiar ve un contador de 30 min y la vista de solo lectura de Papá.
4. Al terminar el tiempo, o si el dueño la cancela, la vista se cierra y se bloquea.

## 3. Criterios

1. El familiar no ve Finanzas de Papá sin una autorización vigente (prueba de servidor y de app).
2. La autorización dura 30 min exactos; al vencer, el servidor rechaza las lecturas (prueba con reloj simulado).
3. Durante la vista, la captura de pantalla está bloqueada y no se puede copiar ni seleccionar (prueba de widget y de plataforma).
4. El dueño puede cancelar la autorización antes de tiempo.
5. Cada solicitud y autorización queda en la bitácora sin monto ni cuenta (solo quién y cuándo).
6. El aviso al dueño no lleva montos ni nombres de cuentas (catálogo cerrado de textos, D20).
7. Ninguna cifra de esta vista sale a IA, bocinas ni tablet pública (D3, D14).

## 4. Trabajo por agente

- **backend:** tabla `fin_vistas_solicitadas` (solicitante, libro, motivo, estado, autorizada_por, vigente_hasta), RPC para pedir, autorizar, rechazar y cancelar; RLS que da lectura del libro de Papá solo con autorización vigente; bitácora sin montos.
- **finanzas:** pantalla de solicitud y vista temporal con contador; bloqueo de copia, selección y exportar en esa vista.
- **plataforma:** captura bloqueada (FLAG_SECURE) en la vista temporal; aviso al dueño con el catálogo de textos.
- **asistente:** la orden "pedir ver finanzas de Papá" solo abre la solicitud; nunca muestra cifras.

## 5. Decisión registrada

D5 cambia en este punto: el familiar **no** tiene permanentemente dinero; tiene vista temporal por solicitud (D24).
