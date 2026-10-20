# Contrato de conexión entre apps (versión 2.0)

**Apps del sistema (SEGUNDO CEREBRO):**

| App | Carpeta | Qué es | Estado |
|---|---|---|---|
| **Presupuesto y Alimentación** | `FINANZAS/` | Dinero, deudas, ahorro, menús, recetas, lista de compras y despensa. Android, Flutter, Firebase Spark | Diseño cerrado (v23), sin código |
| **Hábitos y Objetivos** | `HABITOS/` | Coaching personal, espiritual y educativo; cumplimiento del plan de comidas, ejercicio, sueño, agenda. Android, Flutter, Firebase Spark | Diseño v1.18, sin código |
| **GRAVITY** | `GRAVITY/` | Asistente virtual tipo JARVIS (voz y texto) | Fase inicial; arquitectura sin definir |
| **App de cuidados** | *(fuera de este repositorio)* | Persona bajo cuidado: lo clínico y diario. Ya existe (fase 3, rediseñable) | Externa |

**Para qué sirve este archivo:** es lo que se le da a **cada** sesión de Claude Code para que las apps se entiendan sin ambigüedad. Si algo cambia, se cambia **primero en la raíz del repositorio** (`SEGUNDO CEREBRO/CONTRATO_CONEXION_APPS.md`), se sincronizan las copias (`sincronizar-contrato.sh`) y se avisa a todas las sesiones. Nadie edita su copia por su lado.

> **Origen de esta versión.** Parte del contrato v1.0 (14/oct/2026, FINANZAS) y aplica las observaciones B.3 y C.2 del diseño de Hábitos, más la entrada de GRAVITY y de la app de cuidados. El diseño de Hábitos menciona una "v1.2" de este contrato que **no estaba en el repositorio**; si existe, hay que compararla con esta versión antes de programar.
>
> Lo marcado **(propuesto)** no está confirmado por el dueño del proyecto y debe aprobarse antes de implementarse.

---

## 1. Reparto de responsabilidades

Regla de oro: un **solo escritor por tipo de dato**. Si una app necesita un dato de otra, lo **lee**; no lo vuelve a escribir.

| Tema | Dueña | Las demás |
|---|---|---|
| Reglas del plan (alergias, exclusiones, preferencias) | Usuario, capturadas en **Presupuesto** | Las reciben y las muestran |
| Menús, recetas, costo, lista de compras, despensa | **Presupuesto** | No los calculan |
| Cumplimiento y constancia (comió, hábito cumplido) | **Hábitos** | Presupuesto lo recibe de regreso |
| Ejercicio, rutinas, bicicleta, agenda, sueño, inglés, espiritual, suplementos, hábitos a eliminar | **Hábitos** | **No se comparte** |
| Peso y agua | **Hábitos** (Health Connect) | Presupuesto solo lee, con permiso |
| Comidas registradas (nutrición) | **Presupuesto** (Health Connect) | Hábitos solo lee |
| Dinero, cuentas, deudas, presupuesto, precios | **Presupuesto** | **Nunca se comparte** (tampoco con GRAVITY ni con IA) |
| Gastos de cuidado y necesidades de alimentación de la persona bajo cuidado | **App de cuidados** → entran a Presupuesto como movimiento/regla, con confirmación (sección 6) | — |
| Datos clínicos de la persona bajo cuidado (diagnóstico, medicamentos, citas, comportamiento) | **App de cuidados** | **Nunca** entran a Presupuesto, Hábitos ni GRAVITY |
| Datos de salud **propios** del usuario (peso, sueño, medidas) | **Hábitos** | Solo lo que esta tabla permita |
| Órdenes en lenguaje natural, recordatorios del asistente, memoria del asistente | **GRAVITY** | No participa en el dinero ni en la salud (sección 9) |

**"Persona bajo cuidado"** es otra persona distinta del usuario (con consentimiento de quien la representa). Los datos de salud propios del usuario no son "datos clínicos de paciente".

---

## 2. Vías de conexión (en este orden de implementación)

| Vía | Para qué | Etapa |
|---|---|---|
| **A. Archivo JSON compartido** (botón "Compartir" o "Importar archivo") | Plan, seguimiento, y (borrador) archivos de cuidados | **Primera** |
| **B. Enlaces entre apps** (deep links) | Abrir la otra app en una pantalla concreta | **Primera** |
| **C. Health Connect** | Peso, agua, comidas, sueño y ejercicio, con permiso | Segunda |
| **D. Mismo proyecto de Firebase** | Sincronización automática de plan y seguimiento en `compartido/` | Solo si las apps son del mismo dueño y se decide después |

- Cada app **debe funcionar completa sin las otras instaladas**. Si la otra no existe, los botones de conexión se ocultan o muestran "Instala la app de …".
- **MCP no sirve para sincronizar apps**; no se usa para esto.
- **GRAVITY no es una vía de datos**: no es intermediaria entre Presupuesto y Hábitos (sección 9).

---

## 3. Reglas generales de los archivos (vía A)

- UTF-8. Fechas `AAAA-MM-DD`. Hora `HH:MM` en **hora local del teléfono, sin convertir** (no se fija zona horaria).
- Todo archivo trae `schema_version` (texto, hoy `"2.0"`).
  - **Misma versión mayor** (`2.x`): se acepta; campos desconocidos se ignoran.
  - **Versión mayor distinta**: se rechaza con un mensaje claro; nunca se importa a medias.
  - La app dueña del archivo no debe cambiar la versión mayor sin cambiar este contrato.
- Identificadores: `id` de texto único y estable (UUID o similar). **Nunca se reutilizan.** Los `id` de integrante (`m-ana`) los genera la app de **Presupuesto**; Hábitos los vincula con sus perfiles en la primera importación (pantalla de vinculación) y conserva el vínculo aunque cambie el nombre.
- **Reimportación (idempotencia):**
  - El plan lleva `revision` (entero, empieza en 1). Mismo `id` y revisión **mayor** reemplaza; misma revisión se ignora (se avisa "ya importado"); menor se rechaza.
  - Cada registro de seguimiento lleva `plan_revision` y `registrado_en` (`AAAA-MM-DD HH:MM`). Si dos registros apuntan a la misma comida, **gana el más reciente**.
- Nombres: `plan_AAAA-Www_<integrante>.json`, `seguimiento_AAAA-Www_<integrante>.json` (semana ISO).
- Tipo MIME: se **envía** como `application/json`; se **acepta** también `text/plain` y `application/octet-stream` si la extensión es `.json` (WhatsApp y Drive cambian el tipo). Toda app con importación tiene un botón **"Importar archivo"** con selector de archivos.
- **No incluir** montos de dinero, cuentas, precios ni nombres de comercios.
- Al importar: **pantalla de revisión y confirmación**; nunca se importa en silencio.
- **Límites de validación** (se rechaza o recorta, nunca se rompe): 1 MB por archivo; máximo 14 días; máximo 8 comidas por día; 200 caracteres por texto; 50 elementos por lista. Los textos se muestran como **texto plano** (sin HTML ni Markdown).
- Todo archivo importado se trata como **no confiable**: validar contra el esquema, descartar campos desconocidos.

---

## 4. Plan (Presupuesto → Hábitos)

```json
{
  "schema_version": "2.0",
  "tipo": "plan_nutricion",
  "id": "plan-0001",
  "revision": 1,
  "creado": "2026-10-14",
  "vigencia": { "desde": "2026-10-19", "hasta": "2026-10-25" },
  "autor": "usuario",
  "integrante": { "id": "m-ana", "nombre": "Ana", "tipo_integrante": "adulto" },
  "reglas": [
    { "id": "r1", "tipo": "alergia", "valor": "cacahuate" },
    { "id": "r2", "tipo": "exclusion", "valor": "mariscos" },
    { "id": "r3", "tipo": "preferencia", "valor": "desayuno ligero", "tiempo_comida": "desayuno" }
  ],
  "dias": [
    {
      "fecha": "2026-10-19",
      "comidas": [
        {
          "id": "c-0001",
          "tiempo": "desayuno",
          "hora": "08:00",
          "platillo": {
            "id": "SAN-001",
            "nombre": "Sándwich de queso panela",
            "porciones": 1,
            "etiquetas": ["sin_mariscos"],
            "ingredientes": [
              { "clave": "LAC-001", "nombre": "Queso panela", "cantidad": 60, "unidad": "g" }
            ],
            "sustituciones": [
              {
                "clave": "LAC-001",
                "alternativas": [
                  { "clave": "LAC-002", "nombre": "Queso fresco", "cantidad": 60, "unidad": "g" }
                ]
              }
            ]
          }
        }
      ]
    }
  ]
}
```

Valores permitidos:

| Campo | Valores |
|---|---|
| `autor` | `usuario`, `profesional`, `app` |
| `tipo_integrante` | `adulto`, `persona_bajo_cuidado` |
| `reglas[].tipo` | `alergia`, `exclusion`, `restriccion`, `preferencia`, `meta` (las metas numéricas **no se usan por ahora**) |
| `tiempo` | `desayuno`, `colacion_am`, `comida`, `colacion_pm`, `cena` |
| `unidad` | `g`, `kg`, `ml`, `l`, `pza`, `tbsp`, `tsp`, `taza` |
| `etiquetas` | Lista cerrada; **inicial (propuesta):** `azucar_alta`, `bebida_azucarada`, `sin_mariscos`, `sin_gluten`, `sin_lacteos`, `vegetariano`. Se amplía solo por cambio de contrato; etiqueta desconocida se ignora |

**Integrantes `persona_bajo_cuidado`:** sin IA, sin Health Connect, sin envío por mensajería; el seguimiento lo registra el cuidador. Las reglas son **solo dietéticas mínimas** (alergias, exclusiones, texturas), **sin diagnóstico**.

**Privacidad al exportar:** alergias y notas son datos de salud. La app avisa y sugiere compartir **directo a la otra app**, no por mensajería ni nube.

---

## 5. Seguimiento (Hábitos → Presupuesto)

```json
{
  "schema_version": "2.0",
  "tipo": "seguimiento_nutricion",
  "plan_id": "plan-0001",
  "integrante": { "id": "m-ana", "nombre": "Ana" },
  "generado": "2026-10-26",
  "registros": [
    {
      "comida_id": "c-0001",
      "plan_revision": 1,
      "registrado_en": "2026-10-19 08:20",
      "fecha": "2026-10-19",
      "tiempo": "desayuno",
      "estado": "cumplido",
      "platillo_real": null,
      "nota": ""
    },
    {
      "comida_id": "c-0002",
      "plan_revision": 1,
      "registrado_en": "2026-10-19 14:05",
      "fecha": "2026-10-19",
      "tiempo": "comida",
      "estado": "sustituido",
      "platillo_real": "Tacos de frijol",
      "nota": "No había pollo"
    }
  ]
}
```

- `estado`: `cumplido`, `parcial`, `sustituido`, `omitido`. Si es `sustituido`, `platillo_real` es obligatorio.
- `comida_id` debe existir en el plan; si no existe, se **descarta ese registro y se avisa**.
- **Peso y agua ya no viajan en este archivo** (cambio respecto de v1.0): van por Health Connect (sección 8). No se reintroducen campos de peso o agua sin cambiar el contrato.
- **Opcionales (propuestos, desactivados por defecto):** `habitos_evitados` (unidades, p. ej. refrescos no consumidos, sin dinero) para que Presupuesto calcule ahorro con sus propios precios, y reposición de suplementos como lista de necesidades sin precio. Requieren consentimiento por tipo; el cigarrillo es especialmente sensible.

---

## 6. Archivos de cuidados (App de cuidados ↔ Presupuesto) — **borrador**

El diseño de Presupuesto (6.14) ya prevé estos flujos; el esquema JSON se define cuando se confirme el formato de exportación de la app de cuidados.

| Qué viaja | De → a | Cómo entra |
|---|---|---|
| Gastos de cuidado (medicamentos, pañales, material, cuidador) | Cuidados → Presupuesto | Movimientos de *Cuidados de largo plazo y paliativos*, **con confirmación** |
| Necesidades de alimentación (texturas, espesantes, restricciones, horarios) | Cuidados → Presupuesto | **Reglas del plan**, solo si las indica un profesional o el cuidador responsable; la app no las inventa |
| Seguimiento de comidas (comió, comió poco, rechazó) | Presupuesto → Cuidados | Registro de seguimiento (estado `parcial`/`omitido`/`cumplido` + nota breve) |
| Resumen mensual del costo del cuidado | Presupuesto → familia | Solo dentro de Presupuesto |

Reglas: lo **mínimo necesario**; Presupuesto **no guarda notas clínicas ni diagnósticos**; acceso por rol y con consentimiento de la familia; todo cambio queda en bitácora; **nada de esto va a servicios de IA**; Hábitos y GRAVITY **no participan**. La app de cuidados tiene su propio proyecto de base de datos (o solo local), sin conexión automática con las demás.

---

## 7. Vía B: enlaces entre apps

| App | Esquema | Enlaces |
|---|---|---|
| Presupuesto | `presupuesto://` | `presupuesto://plan/semana?fecha=AAAA-MM-DD`, `presupuesto://lista-compras`, `presupuesto://importar-seguimiento` |
| Hábitos | `habitos://` | `habitos://hoy`, `habitos://comida/registrar?fecha=AAAA-MM-DD&tiempo=desayuno`, `habitos://importar-plan` |
| GRAVITY *(propuesto)* | `gravity://` | `gravity://chat` |

- Cada app declara su esquema en el manifiesto de Android.
- Los enlaces **no llevan datos**, solo destinos y parámetros simples (fecha y tiempo), que se **validan**. Otra app podría registrar el mismo esquema.
- **Un enlace nunca ejecuta una escritura ni una importación**: abre una pantalla, y todo pasa por confirmación.
- Si la app destino no está instalada, se muestra un aviso, no un error.
- Los archivos se envían con la acción de compartir de Android y un `FileProvider`; sin permisos amplios de almacenamiento.

---

## 8. Vía C: Health Connect

| Dato | Escribe | Lee | Permiso |
|---|---|---|---|
| Peso | Hábitos | Presupuesto (opcional) | Lectura / escritura |
| Agua | Hábitos | Presupuesto (opcional) | Lectura / escritura |
| Sueño | Hábitos | Ninguna | Solo en Hábitos |
| Ejercicio (incluida la ruta en bicicleta) | Hábitos | Ninguna | Solo en Hábitos |
| Comidas (nutrición) | Presupuesto | Hábitos | Lectura / escritura |

- Cada permiso se pide **solo cuando se usa**, con una explicación en español. Sin permiso, la función se oculta y la app sigue funcionando.
- **Verificar el estado de Health Connect** (instalado y disponible) antes de ofrecer la función. En Android 13 o anterior es una app aparte.
- Health Connect transporta registros de salud, **no** recetas, platillos ni presupuesto; eso viaja por la vía A.
- Si se publica en Google Play, preparar la declaración de permisos de salud.
- Google Fit no se usa (su API termina a finales de 2026).

---

## 9. GRAVITY *(propuesto; la arquitectura de GRAVITY aún no está definida)*

GRAVITY es un asistente de voz/texto que **ayuda a usar** las otras apps; **no es dueño de ningún dato** de ellas.

1. **Sin acceso directo a datos.** No lee las bases de datos de Presupuesto, Hábitos ni Cuidados.
2. **Acciones solo por enlaces** (sección 7): puede abrir `habitos://hoy` o `presupuesto://lista-compras` por orden del usuario. No importa, no escribe y no confirma por el usuario.
3. **Lectura de contenido solo por archivo, con consentimiento explícito y por sesión** si algún día se quiere que lea un plan o seguimiento exportado. Nunca archivos con alergias o notas de salud sin aviso.
4. **Prohibido para GRAVITY:** dinero, cuentas, precios, datos clínicos de la persona bajo cuidado, y datos de salud propios de terceros.
5. **IA:** si GRAVITY usa un modelo de lenguaje, aplica la sección 10 sin excepciones. La clave de la API **nunca va dentro de la app** (almacenamiento seguro del teléfono, proxy o plan Blaze, según lo decida GRAVITY).
6. **Funciona sin las otras apps** y las otras apps funcionan sin GRAVITY.
7. Si GRAVITY necesita un dato nuevo de otra app, se **propone un cambio a este contrato**; no se hace por su cuenta.

Pendiente: definir el stack de GRAVITY (¿móvil o escritorio?). Si no es Android, los enlaces `gravity://` y la sección 7 deben revisarse.

---

## 10. Privacidad e IA

- No se comparten datos de dinero ni datos clínicos.
- Se comparte lo mínimo necesario, con el consentimiento de la persona a la que pertenecen los datos, por persona y por tipo de dato.
- **IA:** funciona solo si el usuario la activa por función. Se envía lo mínimo, **sin nombres ni alergias**, y **nunca** datos financieros, datos de la persona bajo cuidado ni salud de terceros. La IA no sustituye a un médico, un psicólogo ni un pastor.
- Las apps funcionan en modo básico sin IA.
- El repositorio es **privado**. No se suben estados de cuenta, saldos, límites ni números de tarjeta (`FINANZAS/data/personal/` está ignorada por git). Ningún archivo de ejemplo contiene datos reales de personas.

---

## 11. Pruebas de aceptación

1. Exportar un plan de Presupuesto → importarlo en Hábitos → ver el plan del día.
2. Marcar una comida como cumplida y otra como sustituida → exportar el seguimiento → importarlo en Presupuesto → ver el cumplimiento semanal.
3. Importar un archivo con `schema_version` mayor desconocida → mensaje claro, sin cambios.
4. Importar un archivo con `comida_id` inexistente → se descarta ese registro y se informa.
5. Con la otra app desinstalada → los botones de conexión se ocultan y nada falla.
6. Los enlaces abren la pantalla correcta; sin la app destino, avisan; con parámetros inválidos, no hacen nada.
7. Health Connect: sin permiso, la función se oculta; con permiso, un solo escritor por tipo de dato; Android 13 sin Health Connect no falla.
8. Reimportar el mismo plan (se ignora); plan con `revision` mayor a mitad de semana (reemplaza); dos registros de la misma comida (gana el más reciente).
9. Archivo `.json` recibido como `text/plain` (se acepta); archivo de 2 MB (se rechaza); versión `2.1` (se acepta con campos desconocidos ignorados).
10. Dos teléfonos con distinto `integrante`; probar con **modo avión**.
11. Un enlace nunca provoca una importación ni una escritura.
12. GRAVITY *(cuando exista)*: puede abrir pantallas por enlace; no puede leer dinero ni datos clínicos; sin las otras apps no falla.

---

## 12. Instrucciones para cada sesión de Claude Code

Cada carpeta tiene un `CLAUDE.md` con su instrucción:

- `FINANZAS/CLAUDE.md` → sesión de **Presupuesto**
- `HABITOS/CLAUDE.md` → sesión de **Hábitos**
- `GRAVITY/CLAUDE.md` → sesión de **GRAVITY**

Cada sesión lee este contrato (copia en `docs/CONTRATO_CONEXION_APPS.md` de su carpeta) y su propio documento de diseño. **Nadie cambia el contrato por su cuenta:** si algo no cuadra, se propone el cambio (qué y por qué) y se edita primero la copia de la raíz.

---

## 13. Control de cambios

| Versión | Fecha | Cambio |
|---|---|---|
| 1.0 | 14/oct/2026 | Primera versión (FINANZAS): archivos JSON, enlaces, reparto con Health Connect y pruebas |
| 2.0 | 19/oct/2026 | Ajuste para las tres carpetas: entra **GRAVITY** (sección 9, propuesto) y la **app de cuidados** (sección 6, borrador); `revision`, `plan_revision` y `registrado_en` (idempotencia); alternativas con objeto completo; `tipo_integrante`; etiquetas estándar; peso y agua solo por Health Connect; hora local sin zona fija; MIME flexible e "Importar archivo"; límites concretos; enlaces sin escrituras; sueño y ejercicio en Health Connect; reparto ampliado con las áreas de Hábitos. Incorpora B.3 y C.2 del diseño de Hábitos |

### Pendientes

1. Comparar con la "v1.2" que menciona el diseño de Hábitos (no está en el repositorio).
2. Confirmar la sección 9 cuando GRAVITY defina su arquitectura.
3. Definir el esquema JSON de la sección 6 con la app de cuidados.
4. Aprobar la lista inicial de etiquetas y los campos opcionales de la sección 5.
5. Archivos de prueba (JSON válidos e inválidos) para los casos 3, 4, 8 y 9.
