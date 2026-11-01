# Revisión de calidad — Fase 2 (Finanzas MVP 2: deudas, ahorro, avisos)

Revisor: agente calidad · Fecha: 31/oct/2026 · Árbol: `b5216d3` (más los archivos de calidad listados en la sección 8).
Alcance: spec `fase-2-finanzas.md` v0.1 + sección 11, D20, migraciones `20261101`, `20261102` y `20261103`, Edge Function `enviar-avisos`, `app/lib/nucleo/avisos`, `app/lib/app/avisos`, Finanzas fase 2 y `finanzas_dominio`.

## 1. Veredicto

**Aprobada con condiciones. Sin bloqueantes.** D3 se sostiene: lo único que viaja por FCM es `{v:"1", id}`, los títulos son un catálogo cerrado sin cifras y la notificación local lleva el cuerpo vacío. Los privilegios del servidor y la RLS aguantaron todos los ataques probados con PostgreSQL real. Quedan **1 importante** (el push se apaga solo y no se recupera) y **3 menores**; ninguno expone dinero ni datos.

Límites de esta revisión (dicho con honestidad): no se corrió la Edge Function con Deno (no está instalado aquí; se leyó el código y la prueba `enviar_test.ts`), no se probaron `pg_net`/Vault en un Supabase real, y las pruebas diferenciales del dominio (orden de pago, MSI, fondo de 5 niveles, `repartirAhorro`) se apoyan en los 279 casos existentes, sin pruebas nuevas mías.

## 2. Pruebas corridas

| Comando | Resultado |
|---|---|
| `flutter analyze` (app) | Sin problemas |
| `flutter test --exclude-tags hallazgo` | 1690 pasan (más 2 guardias nuevas mías) |
| `cd paquetes/finanzas_dominio && dart test` | 279 pasan |
| `bash supabase/tests/correr.sh` | 31 archivos, 1910 afirmaciones, todo pasa (+23 de `88_calidad_fase2.sql`) |
| `probar_respaldo.sh` | 44 comprobaciones, todo pasa |
| `api`: `npm run verificar` y `npm run validar` | Al día / válido |
| `enviar_test.ts` (Deno) | **No corrido** (sin Deno) |

## 3. Hallazgos bloqueantes

Ninguno.

## 4. Hallazgos importantes

### F2-1. El push se apaga solo tras 5 errores pasajeros y no se vuelve a encender
- `avisos_registrar_entrega` suma un fallo por cada resultado `error` (una caída de red de FCM cuenta) y a los 5 pone `recibe_avisos = false`. `registrar_dispositivo` conserva ese `false` para la misma persona (y solo reinicia `fallos`). Un lote de 5 avisos durante una caída apaga el push del teléfono hasta que la persona lo reactive a mano en Ajustes; no hay aviso de que pasó.
- Reproducir: `supabase/tests/hallazgos_fase2.sql` (F2-1 sale ABIERTO). A mano: 5 llamadas `avisos_registrar_entrega(aviso, dispositivo, 'error')`, luego `registrar_dispositivo(mismo token)`: `recibe_avisos` sigue en `false`.
- Corrige: **backend**. Opciones: no apagar nunca por `error` (solo contar y reintentar), o apagar y reactivar solo en `registrar_dispositivo` si lo apagó el sistema (columna `apagado_por_fallos`).

## 5. Hallazgos menores

- **F2-5. FK `fin_retiros_destino_fk` sin `libro_id`** (`bolsa_destino_id` apunta a `fin_bolsas_ahorro(id)`). Un retiro podría nombrar una bolsa de otro libro del mismo hogar; la RLS impide verla pero no que el id se guarde. Reproducir: `hallazgos_fase2.sql` F2-5. Corrige: backend (FK compuesta `(libro_id, bolsa_destino_id)`; nota: un traspaso de bolsa a bolsa dentro del libro no se afecta).
- **F2-6. Recordatorios locales: solo se programa el más próximo.** `calcularRecordatorios` hace `break` tras el primer "días antes" futuro: con el vencimiento a 9 días solo queda el de 3 días antes; el de 1 día no existe hasta reabrir o sincronizar. Sin señal ni Firebase puede no llegar. Reproducir: `app/test/revision_calidad/f2_recordatorios_test.dart` (etiqueta `hallazgo`, falla a propósito). Corrige: **finanzas/plataforma** (programar todos los pasos futuros dentro de la ventana; los ids son por clave, así que el servidor los reemplaza sin duplicar).
- **F2-3. Cualquier miembro de un libro compartido puede emitir avisos críticos falsos a los demás** (`fin_emitir_aviso('flujo_negativo' o 'abono_bajo_minimo')`, hasta 60 por día; `objeto_id` no se valida contra el libro). Es consecuencia del diseño D20 (la app calcula lo que solo ella sabe), pero un miembro puede asustar o agotar el tope de otro. El texto sigue siendo genérico (no hay fuga). Corrige: backend (validar que el objeto pertenezca al libro; limitar críticos por clave y día) o decisión del dueño de aceptar el riesgo entre miembros de confianza.

## 6. Revisado y sin hallazgo (con prueba)

- **Privilegios:** `authenticated` no puede llamar `avisos_reclamar`, `avisos_registrar_entrega`, `avisos_resultado_envio`, `avisos_insertar`, `avisos_generar_*`, `avisos_limpiar`, `avisos_revisar_base`, `avisos_invocar_enviar`, `fin_avisos_destinatarios`; tampoco `anon`; ni siquiera `service_role` llama a los generadores. `avisos_sistema` y `avisos_entregas` no se leen. Las tablas `avisos` y `dispositivos` no admiten escritura directa. (`88_calidad_fase2.sql`, F2G1 a F2G12.)
- **RLS por rol:** la maestra (con o sin consulta), la familiar, el cuidador, la cuenta Casa, el otro hogar y la pareja de Ana no ven avisos, preferencias, deudas, bolsas, estados de cuenta ni MSI ajenos; la maestra con consulta no escribe ni emite. Estados de cuenta solo-agregar (sin update ni delete). (F2G13 a F2G23.) Un estado de cuenta solo se acepta en deudas de clase tarjeta y con `registrado_por` propio.
- **`fin_emitir_aviso`:** exige poder escribir en el libro, tipo emitible, clave con formato, par objeto tipo/id; tope de 60 claves por 24 h; idempotente por `(persona, clave)`.
- **Destinatarios:** calculados en el servidor y filtrados por `fin_destinatario_valido`; la maestra, la familiar, el cuidador, Casa y la tablet pública no reciben (tablet pública: `recibe_avisos` forzado a `false`).
- **`avisos_actualizar_preferencias`:** rechaza silencio con desde = hasta (probado; cerrado).
- **Secretos:** sin claves reales en el repositorio; la URL y la clave de servicio viven en el Vault. El PEM de `enviar_test.ts` se genera en la prueba. No hay `google-services.json`.
- **Prueba débil:** ninguna. `git diff 2740a40..HEAD` sobre `app/test/revision_calidad` y `supabase/tests` no muestra aserciones eliminadas ni debilitadas.
- **FLAG_SECURE:** `esPantallaSensible` cubre todo `/finanzas/*` (deudas, ahorro y vencimientos incluidos), la bandeja de avisos y pendientes (guardia en `f2_recordatorios_test.dart`).

## 7. Preguntas para el dueño

1. Un teléfono sin señal por días: ¿aceptas que los avisos solo lleguen al volver (hoy es así) o quieres un recordatorio local más agresivo (F2-6)?
2. ¿Los miembros de un libro compartido pueden emitirse avisos críticos entre sí (F2-3), o solo el motor del servidor?
3. Si el push se apaga por fallos (F2-1), ¿prefieres que se reactive solo al volver a abrir la app?

## 8. Pruebas agregadas por calidad

- `supabase/tests/88_calidad_fase2.sql` (23 afirmaciones, pasan): privilegios y RLS.
- `supabase/tests/hallazgos_fase2.sql` (no entra en la corrida normal): F2-1 y F2-5 salen ABIERTO.
- `app/test/revision_calidad/f2_recordatorios_test.dart`: F2-6 (etiqueta `hallazgo`) y dos guardias (catálogo sin cifras, FLAG_SECURE).

## 9. Pedidos por agente

- **backend:** F2-1, F2-5, F2-3.
- **finanzas / plataforma:** F2-6.

## 10. Pendientes de esta revisión

No verificados por mí: simulación semana por semana A1/A2 y la pantalla "¿y si pago $X extra?" (la spec sección 11 los marca pendientes: criterios parciales); límites 30/60 %, regla 16 y husos con cambio de horario (solo vía las pruebas existentes); pantallas a letra 2.0 en 360 dp y 900 dp; importador de la ficha con archivo hostil (hay prueba heredada `f1b_importar_no_confiable`); estados de cuenta, aportaciones y retiros sin señal (decisión del dueño: piden señal, no se pierde nada porque no se guardan); suites de Deno. Criterios manuales: notificación real en Android con Firebase, ocultar montos con lector de pantalla en dispositivo físico.

---

## Estado de los hallazgos al cierre de la Fase 2 (1/nov/2026)

| Hallazgo | Estado | Quién | Nota |
|---|---|---|---|
| F2-1 (el push se apagaba solo) | Cerrado | backend | Solo los rechazos definitivos suman (5 apagan); los errores pasajeros reintentan; abrir la app en el teléfono reactiva. La función `enviar-avisos` manda hoy los 4xx distintos del token como `error` (pasajero): pendiente ajustarla para anotar `rechazado` |
| F2-3 (avisos críticos falsos) | Mitigado | backend | Objeto del libro, emisor miembro con permiso de escribir, críticas de la app limitadas a 5 por día y libro; lo ideal es que solo las emita el servidor (decisión del dueño, siguiente ronda) |
| F2-4 (horas de silencio iguales) | Cerrado | backend | |
| F2-5 (FK de retiros sin libro) | Cerrado | backend | Clave compuesta (libro, bolsa) y destino distinto del origen |
| F2-6 (recordatorio de 1 día antes) | Cerrado | arquitecto | Se quitó el `break` de `calcularRecordatorios`; ahora 3 y 1 día antes |

**Sin verificar por calidad (queda para la siguiente ronda):** la Edge Function con Deno real, pg_net y Vault en un Supabase real; pruebas diferenciales del dominio de deudas y ahorro; el importador de la ficha con un archivo hostil; letra 2.0 en 360 dp y 900 dp en las vistas nuevas de Fase 2 (incluida la tarjeta de abono extra); y la tabla de los 57 criterios.

**Veredicto de cierre:** 0 bloqueantes y 0 importantes abiertos.

