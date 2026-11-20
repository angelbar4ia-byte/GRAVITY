# Fase 8 · Finanzas: actualización entre dispositivos (Realtime)

> Borrador v1.0 (20/nov/2026). Paquete F8-6.6. Diseño decidido por el dueño el 20/nov/2026. Base: D3 y D20 (el dinero no viaja por canales ni va a IA), D5 y D19 (permisos en el servidor), D24 (vista temporal de Papá).

## Problema

Finanzas cargaba una vez al abrir el módulo y solo se actualizaba tras cambios propios, al deslizar para actualizar (teléfono) o con «Reintentar». Lo que se registraba en un dispositivo no aparecía en el otro.

## Diseño

1. **Realtime como camino principal.** Un disparador en la base emite un mensaje **sin datos** por el canal privado del libro: `finanzas:libro:<uuid>`, evento `cambio`, cuerpo `{"v":1}`. Cada dispositivo suscrito vuelve a pedir lo suyo con su sesión y ahí se aplica la RLS. Detalle del servidor: `supabase/README.md` (sección «Actualización entre dispositivos con Realtime») y la migración `20261148000000_finanzas_realtime.sql`.
2. **Quién se suscribe:** quien **lee** el libro (`fin_puede(libro, 'leer')`) y no es la vista temporal de Papá. La app, además, solo abre canal de los libros **en los que la persona es titular, miembro o albacea vigente**: la cuenta maestra, el lector de un compartido público y la vista de Papá (D24) se ponen al día al entrar o al volver.
3. **App, mientras Finanzas está abierta** (`ServicioSincroniaFinanzas`):
   - Aviso de cambio → espera 1.5 s (debounce) → **una** recarga por ráfaga. Un aviso que llega durante una recarga pide una más al terminar.
   - **Sin pisar una hoja:** con una hoja o un diálogo abierto, la recarga se aplaza y se hace al cerrarlo (se revisa cada segundo solo mientras hay una recarga pendiente).
   - Se refresca también al **entrar o volver** al módulo, al **volver de segundo plano** y al **reconectar** el canal, con un **mínimo de 20 s** entre refrescos (si se cargó hace menos, se omite); al **reconectar** tras una caída el mínimo es solo de 3 s (H-06: pudo perderse un aviso; 3 s junta las reconexiones simultáneas de varios canales). La carga inicial cuenta como refresco.
   - **Sin temporizador periódico.**
   - Si la recarga falla (sin señal, servidor caído) se queda con lo último cargado, sin pantalla de error. La cola sin conexión se conserva: el repositorio mezcla lo pendiente con lo del servidor al cargar.
   - **Laptop:** botón discreto «Actualizar» (icono, junto a «Mostrar montos») y atajo **F5** (no hace nada con una hoja abierta). **Teléfono y tablet:** deslizar para actualizar, como antes.

## Lecturas razonables y decisiones tomadas

- Los avisos del servidor **no** se limitan a 10 s (solo se juntan en 1.5 s): el mínimo de 20 s es para entrar y volver (al reconectar, 3 s). Actualizar a mano siempre recarga.
- Un mensaje por libro **y por transacción** (no solo por sentencia): una RPC que toca varias tablas manda uno. Un mensaje propio también llega al dispositivo que escribió; la recarga sobrante es barata y evita lógica de «yo ya lo sé».
- «Actualizar (menú)» se resolvió como botón de icono con tooltip «Actualizar (F5)», no como entrada de menú: Finanzas en la laptop no tiene un menú de acciones propio; se puede mover si el dueño prefiere un menú.
- La suscripción se decide al unirse: una consulta de la maestra que vence a los 30 minutos no corta un canal abierto, pero la maestra ni siquiera se suscribe desde la app (solo libros propios) y el mensaje no trae datos.
- Tablas fuera de la lista (libros, miembros, categorías, bolsas, objetivos, tarjetas, transferencias, cierres…) no disparan. Quedan al día al entrar, volver o actualizar. Se pueden agregar en una migración nueva con el mismo disparador.

## Criterios de aceptación

1. Registrar un gasto en el dispositivo A hace que el B (suscrito) lo vea sin tocar nada, en unos 2 a 4 s.
2. El mensaje no contiene montos, cuentas, comercios, notas ni nombres (probado en SQL).
3. Familiar, cuidador, Casa, tablet pública, otro hogar y `anon` no pueden suscribirse; la vista temporal de Papá tampoco; la cuenta maestra solo con consulta vigente y solo a ese libro (probado en SQL contra un stub de `realtime`).
4. Una importación masiva (una sentencia) o una RPC con varias tablas emiten un solo mensaje por libro.
5. Un envío fallido o un servidor sin Realtime no impiden escribir en el libro.
6. Con una hoja o un diálogo abierto no se recarga hasta cerrarlo.
7. Ráfaga de avisos = una recarga; mínimo de 20 s al entrar y volver (3 s al reconectar); sin temporizador periódico; reconexión del canal refresca.
8. Lo pendiente en la cola sigue visible tras recargar.
9. F5 y «Actualizar» en la laptop; deslizar en el teléfono.

## Qué no se pudo verificar

No hay un proyecto de Supabase en este entorno (y no se aplicó nada a ninguno), ni acceso a la documentación en línea. **Sin verificar contra un Supabase real:**

- La firma `realtime.send(payload jsonb, event text, topic text, private boolean)`, la función `realtime.topic()` y la columna `realtime.messages.extension` (de memoria de la documentación; el servidor es tolerante: si no existen, no hace nada o avisa).
- Que la política sobre `realtime.messages` se pueda crear desde una migración con el rol que aplica Supabase (la función `fin_realtime_instalar_politica()` avisa si no hay permiso).
- Que Realtime evalúe la política con `authenticated` y pueda ejecutar `fin_realtime_puede_suscribir` (se concedió `execute` a `authenticated`).
- La API Dart `channel(..., opts: RealtimeChannelConfig(private: true))`, `onBroadcast` y los estados de `subscribe` (comprobadas contra `realtime_client 2.13.2` en el caché local, no contra el servidor).
- El comportamiento del reintento automático del canal ante una caída de red y el evento de reconexión.

**Pruebas hechas:** SQL contra Postgres puro con un stub del esquema `realtime` (`supabase/tests/119_finanzas_realtime.sql`); Flutter con una fuente falsa de eventos (`app/test/modulos/finanzas/sincronia_test.dart`).

## Qué probar con dos dispositivos reales

Laptop y teléfono con la misma cuenta (o pareja con el compartido): registrar un gasto en uno y ver que aparece en el otro; registrar sin señal y comprobar que sigue visible; abrir una hoja de gasto en la laptop mientras el teléfono registra y comprobar que no se cierra ni se pisa; poner la app en segundo plano más de 20 s y volver; apagar y volver a encender el Wi-Fi de un dispositivo; probar con la cuenta maestra y con la vista temporal de Papá (deben ponerse al día solo al entrar).

## Pendientes de la revisión de calidad del bloque 6 (F8-6.8)

Corregidos en F8-6.8: mínimo de 20 s en el texto (H-07) y reconexión del canal con mínimo de 3 s en vez de 20 s (H-06).

Quedan pendientes, por no ser una corrección pequeña y segura:

- **H-05 (carrera entre una recarga automática y una escritura propia).** `_cargar` lee la cola primero y el servidor después; una recarga en vuelo puede pisar un gasto recién registrado hasta el siguiente eco de Realtime. Corrección propuesta: un contador de carga en `CargaFinanzasNotifier` que descarte la respuesta que empezó antes de otra publicación. Toca el repositorio y el estado central; conviene un paquete propio con pruebas de concurrencia. No se pierde ningún dato guardado.
- **H-10 («Deslizar para actualizar» sin alternativa ni retroalimentación).** En teléfono y tablet el único camino manual es el gesto; sin señal el indicador se cierra sin avisar. Corrección propuesta: un elemento «Actualizar» en la barra del teléfono (accesible con TalkBack) y un aviso breve si no se pudo actualizar. Toca varias pantallas del diseño; queda para un paquete de diseño.

