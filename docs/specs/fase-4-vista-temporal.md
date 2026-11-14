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

## 6. Contrato de servidor

Migración `supabase/migrations/20261110000000_fin_vista_papa.sql`; pruebas en `supabase/tests/93_fin_vista_papa.sql`. No cambia ninguna decisión.

| Pieza | Qué hace |
|---|---|
| Tabla `fin_vistas_solicitadas` | `id`, `hogar_id`, `solicitante_id` (familiar), `libro_persona_id` (Papá, titular del libro representado), `motivo` (3 caracteres visibles, máximo 200), `estado` (`pendiente`, `autorizada`, `rechazada`, `cancelada`, `vencida`), `autorizada_por`, `vigente_hasta`, `creado_en`, `cambiado_en`. Solo cambia por RPC; no se borra. El solicitante ve las suyas y el dueño las del hogar |
| `fin_pedir_vista_papa(motivo) -> uuid` | Solo el familiar vigente (42501 si no). Crea la solicitud pendiente y avisa al dueño. Una pendiente o vigente a la vez; 5 por 24 horas (22023) |
| `fin_responder_vista(solicitud, accion)` | Solo el dueño del hogar. `autorizar` (pendiente: `vigente_hasta = now() + 30 min`), `rechazar` (pendiente), `cancelar` (pendiente o autorizada vigente; corta la lectura al instante) |
| `fin_vista_papa_vigente() -> boolean` | Para la app: verdadero si la sesión es familiar y tiene una autorizada con `vigente_hasta > now()` |
| `fin_vistas_vencer(hogar?)` | Marca `vencida` lo vencido (autorizadas pasadas de tiempo; pendientes de más de 24 h). Solo `service_role` y `pg_cron` cada 5 minutos |

- **Lectura:** con vista vigente, `fin_puede(libro, 'leer')` es verdadero para el libro de Papá (y con él todas las tablas `fin_*` de ese libro); también se leen los nombres de categorías y cuentas de gasto del hogar. Nunca se escribe. La lectura **no depende** de la marca `vencida`: la RLS compara `vigente_hasta` con `now()` en cada consulta, así que al vencer o cancelar el servidor niega al instante. La app debe usar `fin_vista_papa_vigente()` y `vigente_hasta` (no el campo `estado`) para el contador.
- **Aviso al dueño (D20):** tipo nuevo `solicitud_vista` (crítico: no se agrupa), `objeto_tipo = 'solicitud_vista'`, `objeto_id` = la solicitud. Sin texto, montos ni nombres; el texto lo pone el catálogo de la app. Al responder, el aviso queda `resuelta`.
- **Bitácora:** cada alta y cambio de estado queda por trigger (tabla `fin_vistas_solicitadas`), sin el motivo, sin montos ni cuentas: solo quién, cuándo, estado y `vigente_hasta`. Las escribe el servidor, así que no cuentan en el tope de 500 entradas por 24 horas.
- **Pendiente de otras áreas:** la consulta (lecturas) no se registra en la bitácora, porque un SELECT no deja huella; si el dueño la quiere, la app debe llamar una función de registro (propuesta, no incluida).
