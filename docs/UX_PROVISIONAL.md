# GRAVITY — UX provisional

> **PROPUESTA — plataforma decidida: Android y escritorio. Las pantallas son propuestas, sujetas a la confirmación de la sección 9 del contrato (propuesta)**
>
> **Decisión del usuario:** GRAVITY será para **Android y escritorio**, y las pantallas de este documento son **propuestas**, no diseño final. El stack sigue sin decidirse. Este documento ordena lo que el contrato v2.0 ya fija, lista las pantallas conceptuales que de ahí se derivan y deja el resto al usuario. Todo lo marcado «(propuesto)» necesita su aprobación.

Fuentes: `docs/CONTRATO_CONEXION_APPS.md` v2.0 (secciones 7, 9, 10 y caso 12 de la 11), `CLAUDE.md` y `README.md` de este repositorio.

---

## 1. Qué fija el contrato y qué no

### 1.1 Reglas de UX que se derivan literalmente

| # | Regla | Origen |
|---|---|---|
| R1 | GRAVITY **no es dueña de datos** de Presupuesto, Hábitos ni Cuidados y **no lee sus bases de datos**. | 9.1 |
| R2 | Solo **abre pantallas** de otras apps por enlace (`habitos://…`, `presupuesto://…`), **por orden del usuario**. | 9.2, 7 |
| R3 | Un enlace **no importa, no escribe y no confirma por el usuario**. Todo pasa por la confirmación de la app destino. | 9.2, 7 |
| R4 | Los enlaces **no llevan datos**; solo destinos y parámetros simples (fecha, tiempo), que se **validan**. Con parámetros inválidos, no se hace nada. | 7, 11.6 |
| R5 | Si la app destino no está instalada, se muestra un **aviso**, no un error. | 7, 11.6 |
| R6 | Leer un plan o seguimiento exportado solo con **consentimiento explícito y por sesión**. Nunca archivos con alergias o notas de salud **sin aviso**. | 9.3 |
| R7 | **Prohibido:** dinero, cuentas, precios, datos clínicos de la persona bajo cuidado y datos de salud de terceros. | 9.4, 10 |
| R8 | **IA:** solo si el usuario la activa, por función; lo mínimo, **sin nombres ni alergias**; la **clave de la API nunca va dentro de la app**. | 9.5, 10 |
| R9 | GRAVITY **funciona sin las otras apps** y ellas sin GRAVITY. | 9.6, 11.5 |
| R10 | Un dato nuevo de otra app no se resuelve por cuenta propia: se **propone un cambio al contrato**. | 9.7 |
| R11 | El caso de aceptación 12: puede abrir pantallas por enlace; no puede leer dinero ni datos clínicos; sin las otras apps no falla. | 11.12 |
| R12 | Las apps funcionan en modo básico sin IA. | 10 |

### 1.2 Enlaces conocidos hoy (sección 7)

| Esquema | Enlaces |
|---|---|
| `habitos://` | `habitos://hoy`, `habitos://comida/registrar?fecha=AAAA-MM-DD&tiempo=desayuno`, `habitos://importar-plan` |
| `presupuesto://` | `presupuesto://plan/semana?fecha=AAAA-MM-DD`, `presupuesto://lista-compras`, `presupuesto://importar-seguimiento` |
| `gravity://` *(propuesto)* | `gravity://chat` |

Nota de UX: `habitos://importar-plan` y `presupuesto://importar-seguimiento` solo **abren la pantalla** de importación; GRAVITY no debe presentarlas como «importar por ti» (R3).

### 1.3 Qué NO está fijado

- Plataforma (Android, escritorio o ambos) y stack.
- Si la voz usa palabra de activación o botón.
- Proveedor de IA y dónde vive la clave.
- Qué se entiende por «sesión» para el consentimiento de archivo (R6).
- Cómo se identifican las apps instaladas (depende de la plataforma).
- Todo lo de la sección 9 sigue siendo **propuesta**.
- Calendario, archivos y web (hoja de ruta del README): **fuera de este documento**.

---

## 2. Mapa de pantallas conceptual (independiente de plataforma)

Son pantallas o estados, sin medidas ni diseño visual.

| ID | Pantalla / estado | Propósito | Estados | Regla |
|---|---|---|---|---|
| G01 | **Conversación (texto)** | Pedir cosas en lenguaje natural y ver la respuesta | Vacío: invitación con ejemplos de órdenes · Cargando: «pensando» · Sin conexión: solo órdenes locales, aviso discreto · Error: mensaje con «Reintentar» | R2, R12 |
| G02 | **Entrada por voz** | Dictar la orden y ver el texto reconocido antes de actuar | Vacío: «Di una orden» · Escuchando · Sin permiso de micrófono: explicación y cómo concederlo · No entendí: «No te entendí, ¿lo intentamos otra vez?» · Error | R2 |
| G03 | **Tarjeta «Voy a abrir X — ¿Abrir?»** | Confirmar antes de lanzar un enlace | Normal (destino + botones) · Parámetros inválidos: no se lanza nada y se avisa · Cancelada | R2, R3, R4 |
| G04 | **Aviso «App no instalada»** | Informar sin error cuando falta la app destino | Único estado; ofrece cerrar o seguir en el chat | R5, R9 |
| G05 | **Consentimiento de archivo (por sesión)** | Permitir leer un plan o seguimiento exportado solo durante esta sesión, con aviso de datos de salud | Pedido · Concedido (indicador visible mientras dure) · Rechazado · Sesión terminada: se pide de nuevo · Archivo no válido: no se lee y se explica | R6, R7 |
| G06 | **Activación de IA por función** | Activar o no la IA, explicando qué se envía | Apagada (valor inicial) · Activa por función · Sin conexión · Sin clave configurada: explica el paso, sin pedirla en pantalla de chat | R8, R12 |
| G07 | **Ajustes de privacidad** | Ver y revocar consentimientos, IA y permisos | Lista con estado de cada permiso · Sin nada concedido | R6, R8 |
| G08 | **Estado «sin otras apps»** | Que GRAVITY sea útil y no parezca rota sin Hábitos ni Presupuesto | Se muestran solo las funciones propias; los accesos a otras apps se ocultan o indican «Instala la app de …» | R9, 11.5 |
| G09 | **Rechazo por límite del contrato** | Responder con claridad si se pide dinero, cuentas, precios o datos clínicos | Único estado: explica que GRAVITY no participa y, si aplica, señala la app dueña | R7 |

Ver G09: es un estado de la conversación (G01), no una pantalla aparte.

---

## 3. Wireframes neutrales

Solo estructura, sin marco de dispositivo ni de ventana.

### 3.1 Conversación (G01)

```
GRAVITY                                  [Ajustes]
----------------------------------------------------
(vacío)  Pídeme lo que necesites. Por ejemplo:
          · «Abre lo de hoy en Hábitos»
          · «Ver la lista de compras»

Tú:       Abre lo de hoy en Hábitos
GRAVITY:  Puedo abrir Hábitos en «Hoy».
          [ Tarjeta de confirmación (3.2) ]

----------------------------------------------------
[ Escribe tu orden…                  ] [Enviar] [Voz]
IA: apagada                      (indicador siempre visible)
```

### 3.2 Tarjeta de confirmación de enlace (G03)

```
Voy a abrir Hábitos en «Hoy».
Solo se abrirá esa pantalla; no se importa ni se guarda nada.

[ Abrir ]   [ Cancelar ]
```

### 3.3 Consentimiento de archivo por sesión (G05)

```
¿Leer este archivo en esta sesión?
Archivo: plan_2026-W43_ana.json

Puede incluir datos de salud (alergias, notas).
Solo lo leeré mientras dure esta sesión y no lo guardo.

[ Permitir esta sesión ]   [ No permitir ]
```

### 3.4 Activación de IA por función (G06)

```
Asistencia con IA  (apagada)

Función: redactar respuestas
Se envía:   el texto de tu orden
No se envía: nombres, alergias, dinero ni datos de salud
Proveedor:   <por definir>

[ Activar solo para esta función ]   [ Dejar apagada ]
```

---

## 4. Variantes por plataforma (se hacen las dos)

Con la decisión de Android **y** escritorio, las pantallas conceptuales de la sección 2 se mantienen y cada plataforma adapta su presentación. Lo que cambia entre ambas queda en la tabla; el detalle de cada variante sigue siendo propuesta.

| Tema | Android | Escritorio |
|---|---|---|
| Invocar | Icono, widget o acceso rápido; `gravity://chat` (propuesto) | Ventana o bandeja; atajo de teclado |
| Abrir `habitos://` / `presupuesto://` | Directo, en el mismo teléfono | **No definido**: las otras apps son Android (ver B y la pregunta 7) |
| Estado «sin otras apps» (G04/G08) | Excepción | Estado habitual en escritorio |
| Voz | Permiso de micrófono al usarla | Permiso del sistema al usarla |

### A. Android

- Enlace propio `gravity://chat` (sección 7, propuesto) abre la conversación.
- Widget o acceso rápido a la conversación.
- Voz con permiso de micrófono pedido solo al usarla.
- Los enlaces `habitos://` y `presupuesto://` funcionan de forma natural en el mismo teléfono; la app destino puede no estar instalada (R5).

| Pros | Contras |
|---|---|
| Mismo entorno que las otras apps; enlaces directos | Hay que declarar el esquema en el manifiesto; otra app podría registrar el mismo esquema (contrato 7) |
| Voz y accesos rápidos naturales | Permisos de micrófono y, si hay widget, de segundo plano |

### B. Escritorio

- Ventana o bandeja del sistema; atajo de teclado para invocarlo.
- Las otras apps son Android: en escritorio **pueden no existir**. Un enlace `habitos://` o `presupuesto://` solo funciona si el equipo tiene algo registrado para ese esquema (por ejemplo, un emulador o un puente al teléfono); eso **no está definido** y no se asume.
- Sin las otras apps, G04 y G08 serían el estado habitual, no la excepción.

| Pros | Contras |
|---|---|
| Teclado cómodo para escribir órdenes largas | Las otras apps no están en el equipo: la mayoría de las acciones por enlace no aplican |
| Atajo global y bandeja | Falta definir cómo se «ordena abrir» una pantalla de un teléfono |

### Qué cambia en la sección 7 del contrato si es escritorio (solo como pregunta)

- ¿Se mantiene `gravity://chat`? En escritorio un esquema propio requiere registrarlo en el sistema; ¿vale la pena o basta un atajo?
- ¿Los enlaces `habitos://` y `presupuesto://` se envían al teléfono o se omiten? Si se envían, eso es un canal nuevo y habría que proponerlo como cambio al contrato.
- La frase «Cada app declara su esquema en el manifiesto de Android» no aplicaría a GRAVITY.

Al ser **ambos**, G04/G08 y el flujo de enlaces necesitan comportamiento distinto por plataforma. Como la sección 7 asume Android, estas preguntas se llevan al contrato como **propuesta de cambio** (qué y por qué), sin editarlo desde este repositorio.

---

## 5. Microcopy (español, tono cercano y sin culpa)

| Dónde | Texto |
|---|---|
| Conversación vacía | «Pídeme lo que necesites. Por ejemplo: “Abre lo de hoy en Hábitos”.» |
| Tarjeta de enlace | «Voy a abrir {destino}. Solo se abrirá esa pantalla; no se importa ni se guarda nada.» · [Abrir] [Cancelar] |
| Enlace inválido | «Ese enlace no es válido.» |
| App no instalada | «Instala la app de {nombre} para abrir esto.» / «Esta app no está instalada.» |
| Sin otras apps | «Puedo ayudarte sin ellas. Si más adelante instalas Hábitos o Presupuesto, podré abrir sus pantallas.» |
| Consentimiento de archivo | «¿Leer este archivo en esta sesión? Puede incluir datos de salud. Solo lo leeré mientras dure esta sesión.» · [Permitir esta sesión] [No permitir] |
| Consentimiento rechazado | «Está bien, no lo leeré.» |
| Sesión terminada | «La sesión terminó. Si quieres que lo lea de nuevo, te lo vuelvo a preguntar.» |
| Voz sin permiso | «Necesito el micrófono para escucharte. Puedes activarlo cuando quieras.» |
| Voz no entendida | «No te entendí. ¿Lo intentamos otra vez?» |
| IA apagada | «La IA está apagada. Puedo seguir ayudándote con lo básico.» |
| IA, qué se envía | «Se envía el texto de tu orden. No se envían nombres, alergias, dinero ni datos de salud.» |
| Límite del contrato | «De eso se encarga {app}. Yo no participo en dinero ni en datos de salud, pero puedo abrir la app por ti.» |
| Error genérico | «Algo no salió bien. ¿Reintentamos?» |
| Sin conexión | «Sin conexión: solo puedo hacer lo básico.» |

---

## 6. Incoherencias detectadas (no resueltas)

1. **«Coach» de Hábitos vs. GRAVITY.** Hábitos tiene una pestaña «Coach» con IA propia (chat y voz). Dos asistentes conversacionales pueden confundir al usuario; falta decidir cómo se nombran y se distinguen.
2. **Sección 9 es propuesta.** Todo este documento depende de ella; el propio contrato dice que la arquitectura de GRAVITY no está definida.
3. **`gravity://chat` y la sección 7** están marcados como propuestos y asumen Android.
4. **Sección 7 asume Android** («manifiesto de Android», `FileProvider`); no cubre escritorio.
5. **«Sesión»** en 9.3 no está definida (¿cada conversación?, ¿mientras la app está abierta?).
6. **Confirmación doble.** El contrato exige confirmación en la app destino; añadir la tarjeta G03 en GRAVITY es una decisión de UX nuestra, no una regla del contrato (se propone por prudencia; ver pregunta 6).
7. **Comandos de voz de Hábitos** (modo traslado, SOS) también existen en la app de Hábitos; falta delimitar qué hace cada una por voz.
8. **README de GRAVITY** menciona calendario, archivos y web; el contrato no define cómo encajan con las reglas de la sección 9. Fuera de este documento.

---

## 7. Preguntas abiertas para el usuario

1. ~~¿Android, escritorio o ambos?~~ **Decidido: Android y escritorio.** Queda abierto cómo cambian los enlaces `gravity://` y la sección 7 del contrato (preguntas 7 y siguientes).
2. ¿La voz usará **palabra de activación o botón**?
3. ¿Qué **proveedor de IA** y **dónde vive la clave** (almacenamiento seguro del teléfono, proxy o plan Blaze)?
4. ¿Qué cuenta como **sesión** para el consentimiento de archivo?
5. ¿Cómo quieres diferenciar a GRAVITY de la pestaña **Coach** de Hábitos?
6. ¿Quieres la tarjeta de confirmación **«¿Abrir?»** siempre, o solo cuando la orden sea ambigua? (El contrato no la exige.)
7. Si es escritorio, ¿se propondrá un cambio al contrato para abrir pantallas en el teléfono? ¿Qué y por qué?
8. ¿Deben ocultarse o mostrarse (con «Instala la app de …») los accesos a apps no instaladas?
