// GENERADO por api/generar_dart.mjs a partir de api/openapi.yaml. No se edita a mano.
// Permite abrir Swagger UI con doble clic (file://), donde el navegador no deja leer
// ../openapi.yaml. Servida por http, la página lee openapi.yaml directamente.
// huella: fnv1a32:f7eaed1d
window.ESPECIFICACION_GRAVITY = {
  "openapi": "3.1.0",
  "info": {
    "title": "GRAVITY · APIs del sistema",
    "version": "0.6.0",
    "summary": "Herramientas de GRAVITY, base de datos, funciones del servidor y puente de casa (D16).",
    "description": "Especificación de las APIs de GRAVITY (decisión D16). Se consulta en la laptop, en\nAjustes › Desarrollador, solo con rol Dueño. **No se publica en internet.**\n\nCada operación declara, con extensiones propias:\n\n- `x-roles`: roles que la pueden usar (D5): `dueno`, `coadministrador`, `familiar`,\n  `cuidador`, `casa`. La verdad de los permisos está en el servidor (RLS).\n- `x-escribe`: `true` si escribe datos; GRAVITY y esta consola piden confirmación antes\n  de enviarla. `segun-herramienta` en la operación genérica de herramientas.\n- `x-solo-local`: `true` si su resultado nunca pasa por la IA en la nube (D3: dinero,\n  datos clínicos y datos personales). `segun-herramienta` en la operación genérica.\n- `x-fase`: fase del roadmap en que se construye.\n\nConvenciones (especificación de la Fase 0, sección 4): dinero en centavos (`int`),\nidentificadores UUID, fechas `date` y `timestamptz`, semana en lunes, libros solo-agregar.\n\nFase 1 (Finanzas, D19): cada quien ve **su** libro y los compartidos de los que es\nmiembro (o que son públicos); la **cuenta maestra** es otra persona con su propio login\ny de solo lectura total: lee con una consulta registrada y no escribe nada. Las\nsalvaguardas y las respuestas del dueño del 23/oct viven en el servidor, no en el\ncliente (`supabase/migrations/20261023000000_finanzas_salvaguardas.sql` y\n`supabase/migrations/20261024000000_finanzas_respuestas_dueno.sql`). Los ejemplos\nson inventados (el hogar de Ana y Alex de `supabase/seed.sql`, con \"Papá (ejemplo)\").\n\nLas llaves (Supabase, Home Assistant) entran por `--dart-define` o archivos ignorados\npor git; nunca se escriben aquí.\n",
    "license": {
      "name": "Privado. Uso exclusivo del proyecto Segundo Cerebro; no se publica."
    }
  },
  "servers": [
    {
      "url": "https://{proyecto}.supabase.co",
      "description": "Proyecto de Supabase (D7). El identificador real no se guarda en el repositorio.",
      "variables": {
        "proyecto": {
          "default": "tu-proyecto",
          "description": "Identificador del proyecto de Supabase."
        }
      }
    },
    {
      "url": "http://127.0.0.1:54321",
      "description": "Supabase local para desarrollo (`supabase start`)."
    }
  ],
  "security": [
    {
      "llavePublica": [],
      "sesion": []
    }
  ],
  "tags": [
    {
      "name": "Herramientas de GRAVITY",
      "description": "Lista cerrada de funciones que GRAVITY puede usar (D1). Cada una declara su módulo,\nsus roles, si escribe (pide confirmación) y si es solo local (D3). El registro de la\napp rechaza, al arrancar, una herramienta declarada para un rol que la matriz de\npermisos no deja abrir, leer o escribir su módulo (D5), y una de Finanzas o Cuidados\nque no sea solo local (D3), **también las de navegación**: ni siquiera \"se abrió\nFinanzas\" llega a la IA en la nube. A la cuidadora solo se le ofrece su bandeja de\nsolicitudes (D18: nada de dinero, de la familia ni de conversación libre). Una cuenta\nmaestra que no es la dueña es de **solo lectura total** (D19, 23/oct): solo\nnavegación y lectura, ninguna herramienta que escriba ni que abra una hoja de\nregistro; si el dueño es además la maestra, conserva las suyas para lo propio y no\nrecibe lo que administra el hogar. En las Fases 0 y 1 son de navegación y se ejecutan\ndentro de la app; \"registrar gasto\" solo abre la hoja de registro, que es la\nconfirmación (una orden nunca registra dinero sola), y hay que decir el verbo: la\npalabra \"gasto\" suelta no abre nada. Exponerlas por red para el puente de casa es una\npropuesta de la Fase 6.\n"
    },
    {
      "name": "Base de datos",
      "description": "Supabase (PostgREST): `/rest/v1/<tabla>` con los filtros de PostgREST\n(`?id=eq.<uuid>`, `select`, `order`, `limit`). Cada consulta pasa por las reglas\npor registro (RLS) del rol: se lee solo lo que el rol puede ver. Esquema en\n`supabase/migrations/20261020000000_base.sql` (Finanzas, en su propio grupo). La\nbitácora solo se agrega, y lo de Finanzas (acciones `finanzas*` y tablas `fin_*`) lo\nescribe solo el servidor. Lo que la app escribe en ella tiene tope: 4 KB por entrada\ny 500 entradas por persona en 24 horas (54000). Nada de esta base va a la IA.\n"
    },
    {
      "name": "Base de datos · Finanzas",
      "description": "Tablas `fin_*`, vistas y funciones de Finanzas (Fase 1, D19), según\n`supabase/migrations/20261021000000_finanzas_mvp1.sql`,\n`supabase/migrations/20261023000000_finanzas_salvaguardas.sql`,\n`supabase/migrations/20261024000000_finanzas_respuestas_dueno.sql` y\n`supabase/README.md` (\"Finanzas (Fase 1)\"). Solo dueño y coadministrador, cada quien\n**su libro** y los compartidos de los que es miembro, más los compartidos públicos\n(`fin_puede`); familiar, cuidador y Casa no ven nada. La **cuenta maestra** es otra\npersona con su propio login: el dueño la invita con `crear_invitacion` y\n`p_es_maestra`, y queda como coadministrador con la marca de maestra, sin libro\npersonal ni membresía en ningún libro. Si no es la dueña es de **solo lectura\ntotal**: lee con una consulta registrada y toda escritura suya (movimientos,\nconfiguración del hogar, crear libros) responde 403 (42501). El dueño también puede\nser la maestra con su propia persona, y en lo suyo sigue escribiendo. Nada de esto va\na la IA en la nube ni a las bocinas (D3, D6).\n\n- **Dinero** en centavos (entero); porcentajes y tasas en puntos base (2000 = 20 %);\n  semana en lunes; identificadores UUID generados en el dispositivo.\n- **Solo agregar:** `fin_movimientos`, `fin_conciliaciones`, `fin_cierres`,\n  `fin_cierre_partidas`, `fin_cierre_abonos` y `fin_importaciones` solo aceptan\n  INSERT; un error se corrige con una anulación (contraasiento) o una versión nueva.\n- **Cola sin conexión (idempotente):** se sube con `on_conflict=id` y\n  `Prefer: resolution=ignore-duplicates`. El mismo `id` con el mismo contenido no hace\n  nada y no falla; con otro contenido, en los libros solo agregar, 409 (23505).\n- **Lo que pone el servidor** (marcado como de solo lectura; no se manda):\n  `recibido_en`, `libro_origen_id` y `libro_destino_id` de los movimientos, las\n  columnas generadas y `reaperturas`.\n- **Errores** (código de PostgreSQL → HTTP de PostgREST): `23503` falta algo de lo\n  que depende (otra cuenta, el original de una anulación; la cola reintenta) → 409;\n  `23505` duplicado o mismo `id` con otro contenido → 409; `23514` regla de la tabla\n  (monto, motivo, lunes, cascada) → 400; `22023` regla de negocio (combinación de\n  cuentas, libro equivocado, papel) → 400; `55000` estado (cuenta no activa, semana\n  cerrada) → 500; `42501` sin permiso o columna que no cambia → 403; `54000` límite\n  (la bitácora: una entrada de más de 4 KB o más de 500 propias en 24 horas) → 500.\n- **Cuenta maestra y consulta registrada (I2):** sin una consulta vigente, la maestra\n  solo ve la **portada**: los libros y quién los lleva (`fin_libros`,\n  `fin_libro_miembros`), las categorías, las cuentas de gasto del hogar y lo que no es\n  de Finanzas. El contenido de un libro ajeno (cuentas, movimientos, plan, cierres,\n  saldos y su bitácora) llega **vacío, sin error**, hasta que llama\n  `fin_registrar_consulta_maestra(libro)`, que deja la entrada\n  `finanzas.consulta_maestra` y habilita la lectura de ese libro por **30 minutos**\n  (por libro y por persona; pasado el tiempo hay que llamarla otra vez, y la app la\n  renueva sola mientras el libro está abierto).\n- **Salvaguardas en el servidor** (hallazgos I1 a I5, M6 y M10 de la revisión de\n  calidad): (I1) en un libro compartido solo quien lo creó, o el dueño del hogar si es\n  miembro, agrega o cambia a otra persona (42501); salirse, o que te saquen, con menos\n  de 2 miembros deja el libro privado y activo, y el último miembro no puede salirse\n  (22023; ver abajo); (I2) la consulta\n  registrada de arriba; (I3) todo movimiento del libro de Papá lleva `en_nombre_de` y\n  `motivo` (23514) y las salidas hacia cualquier otro libro dejan la entrada\n  `finanzas.salida_libro_representado`; (I4) un albacea es vigente solo si sigue siendo\n  adulto con Finanzas, y si no, escribe el suplente; (I5) las acciones `finanzas*` y\n  las tablas `fin_*` de la bitácora las escribe solo el servidor (42501 si la app las\n  inserta); (M6) la maestra que no es la dueña no escribe nada, tampoco la\n  configuración del hogar (42501); (M10) asignar o quitar la maestra deja\n  `finanzas.maestra_asignada`.\n- **Libros compartidos (respuestas del dueño del 23/oct):** quien crea el libro\n  (`creado_por`) es su administrador: agrega y saca miembros, cambia la `visibilidad`\n  y lo archiva. La API no manda ni cambia `creado_por` (42501): solo el servidor, que\n  lo pasa al miembro vigente más antiguo si el creador se sale. `visibilidad` solo\n  existe en los compartidos: `privada` (por omisión; todo nace privado) o `publica`.\n  Privada: leen y escriben sus miembros, y la maestra lee con consulta; el dueño no\n  entra a un compartido privado del que no es miembro. Pública: además la **leen**\n  (no la escriben) los adultos con Finanzas del hogar. **Salirse** es un `PATCH` a la\n  propia fila de `fin_libro_miembros` con `hasta` = ahora (la hora la pone el\n  dispositivo), siempre posible. Si quedan menos de 2 miembros vigentes (también cuando\n  el administrador saca a alguien) el libro **no se archiva**: el servidor lo deja\n  `activo` y `privada`, y el miembro que queda es el administrador (`creado_por`); si\n  se va el administrador (o deja de ser adulto con Finanzas del hogar por una baja o un\n  cambio de rol, N5), `creado_por` pasa al miembro vigente más antiguo y, con menos de\n  2 vigentes, el libro pasa a `privada` (nunca se archiva solo). El\n  **último miembro no puede salirse** (400, 22023: si ya no lo usa, lo archiva).\n  **Archivar** es solo la decisión del administrador (`activo` = `false`) y nunca\n  ocurre solo: un libro archivado se lee y no registra movimientos (403, 42501);\n  reactivarlo (`activo` = `true`) no exige 2 miembros, y mientras está archivado solo su\n  administrador lo administra.\n- **Cuentas de periodo:** solo las de activo y pasivo piden saldo cero para cerrarse\n  o archivarse (22023); las de gasto e ingreso se cierran o archivan con saldo, y en\n  ellas se puede anular un movimiento aunque estén archivadas. Archivar una\n  categoría archiva su cuenta de gasto (si ninguna otra categoría activa la usa) y\n  desarchivarla la reactiva.\n- **Albacea de Papá (N4):** si el cargo de albacea o el de suplente queda vacío (nadie\n  vigente que siga siendo adulto con Finanzas), el dueño del hogar lo vuelve a nombrar\n  con `fin_nombrar_albacea`. Un INSERT directo en `fin_libro_miembros` sigue sin pasar\n  para el dueño (RLS): la función es la única puerta.\n- **Motivo (N2):** el `motivo` de una anulación, un ajuste, un movimiento en nombre\n  de otra persona, el del libro de Papá y el de una conciliación con diferencia\n  necesita al menos 3 caracteres visibles: no cuentan los espacios, tabuladores,\n  saltos de línea, espacios Unicode ni caracteres invisibles (23514). Lo valida un\n  trigger al agregar y no un CHECK, así que lo ya guardado nunca se rechaza y un\n  reenvío idéntico de la cola no falla. El sentido no se juzga.\n- **Funciones internas:** `fin_vigencia_consulta_maestra`, `fin_adulto_con_finanzas` y\n  las de los triggers (`fin_libro_miembros_proteger`, `fin_libros_proteger`,\n  `fin_libro_miembros_sin_maestra`, `fin_categorias_archivar_cuenta`,\n  `bitacora_tope_por_persona`, `fin_motivo_valido`, `fin_motivo_validar`,\n  `fin_libro_asegurar_administrador`, `fin_membresia_relevo_administrador`…) no son\n  llamables desde la API (se les quitó `EXECUTE` a todos los roles); por eso no\n  tienen operación aquí. De la migración de endurecimiento, la app solo llama\n  `fin_nombrar_albacea`. Sí lo son `fin_solo_lectura` y `fin_puede_salir`, que las\n  reglas llaman con el rol de la sesión, y `fin_adultos_con_finanzas` (en plural: la\n  que lista a los adultos con Finanzas del hogar; no la confundas con el ayudante\n  interno `fin_adulto_con_finanzas`, en singular).\n"
    },
    {
      "name": "Funciones del servidor",
      "description": "Funciones de Supabase (`/functions/v1/<nombre>`) desde la Fase 2: avisos al instante\ny, en la Fase 6, el intermediario de la IA, que guarda la clave de la API en el\nservidor (nunca en la app).\n"
    },
    {
      "name": "Puente de casa",
      "description": "Home Assistant en la red de la casa (D9), Fase 6. Usa la cuenta de rol Casa: nunca\nalcanza dinero ni datos clínicos, y las bocinas solo dicen frases genéricas (D3, D6).\nSolo en la red local; nunca se abren puertos del router.\n"
    }
  ],
  "paths": {
    "/herramientas": {
      "servers": [
        {
          "url": "http://127.0.0.1:{puerto}",
          "description": "Propuesta para la Fase 6: GRAVITY en la laptop atiende las herramientas para el puente de casa. En la Fase 0 se ejecutan dentro de la app, sin red.",
          "variables": {
            "puerto": {
              "default": "8787"
            }
          }
        }
      ],
      "get": {
        "tags": [
          "Herramientas de GRAVITY"
        ],
        "operationId": "listarHerramientas",
        "summary": "Herramientas disponibles para la sesión",
        "description": "Lista las herramientas que el rol de la sesión puede usar con los módulos activos. Lo que no está en la lista no existe para GRAVITY. Es lo único que ve la IA para elegir qué hacer. A la cuidadora solo le llega su bandeja de solicitudes (D18); a una cuenta maestra que no es la dueña, solo navegación y lectura: ninguna que escriba ni abra una hoja de registro (D19).",
        "x-roles": [
          "dueno",
          "coadministrador",
          "familiar",
          "cuidador",
          "casa"
        ],
        "x-escribe": false,
        "x-solo-local": false,
        "x-fase": 0,
        "responses": {
          "200": {
            "description": "Herramientas del rol.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/Herramienta"
                  }
                },
                "example": [
                  {
                    "nombre": "habitos.abrir",
                    "descripcion": "Abre Hábitos.",
                    "modulo": "habitos",
                    "roles": [
                      "dueno",
                      "coadministrador",
                      "familiar"
                    ],
                    "escribe": false,
                    "solo_local": false,
                    "accion": "leer",
                    "pertenencia": "propia",
                    "ambito": "general",
                    "hoja": null
                  },
                  {
                    "nombre": "finanzas.registrar_gasto",
                    "descripcion": "Abre la hoja para registrar un gasto. No guarda nada: la persona captura y confirma en la hoja.",
                    "modulo": "finanzas",
                    "roles": [
                      "dueno",
                      "coadministrador"
                    ],
                    "escribe": false,
                    "solo_local": true,
                    "accion": "escribir",
                    "pertenencia": "propia",
                    "ambito": "general",
                    "hoja": "gasto"
                  }
                ]
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      }
    },
    "/herramientas/{nombre}": {
      "servers": [
        {
          "url": "http://127.0.0.1:{puerto}",
          "description": "Propuesta para la Fase 6: GRAVITY en la laptop atiende las herramientas para el puente de casa. En la Fase 0 se ejecutan dentro de la app, sin red.",
          "variables": {
            "puerto": {
              "default": "8787"
            }
          }
        }
      ],
      "post": {
        "tags": [
          "Herramientas de GRAVITY"
        ],
        "operationId": "ejecutarHerramienta",
        "summary": "Ejecutar una herramienta",
        "description": "Ejecuta la herramienta si el rol la tiene y su módulo está activo; si no, responde 404 con el mismo mensaje en todos los casos. Si escribe y no viene `confirmado: true`, no ejecuta nada y responde `requiere_confirmacion` con el texto de la tarjeta de confirmación. Si es solo local, `para_ia` siempre es nulo y, si falla, el error no lleva el mensaje original (podría llevar cifras).",
        "x-roles": [
          "dueno",
          "coadministrador",
          "familiar",
          "cuidador",
          "casa"
        ],
        "x-escribe": "segun-herramienta",
        "x-solo-local": "segun-herramienta",
        "x-fase": 0,
        "parameters": [
          {
            "$ref": "#/components/parameters/nombreHerramienta"
          }
        ],
        "requestBody": {
          "$ref": "#/components/requestBodies/PeticionHerramienta"
        },
        "responses": {
          "200": {
            "$ref": "#/components/responses/ResultadoHerramienta"
          },
          "404": {
            "$ref": "#/components/responses/HerramientaNoDisponible"
          }
        }
      }
    },
    "/herramientas/gravity.abrir": {
      "servers": [
        {
          "url": "http://127.0.0.1:{puerto}",
          "description": "Propuesta para la Fase 6: GRAVITY en la laptop atiende las herramientas para el puente de casa. En la Fase 0 se ejecutan dentro de la app, sin red.",
          "variables": {
            "puerto": {
              "default": "8787"
            }
          }
        }
      ],
      "post": {
        "tags": [
          "Herramientas de GRAVITY"
        ],
        "operationId": "herramientaGravityAbrir",
        "summary": "gravity.abrir · Abrir Inicio",
        "description": "Abre la pantalla principal de GRAVITY. No es para la cuidadora: de GRAVITY solo usa su bandeja de solicitudes (D18).",
        "x-roles": [
          "dueno",
          "coadministrador",
          "familiar",
          "casa"
        ],
        "x-escribe": false,
        "x-solo-local": false,
        "x-fase": 0,
        "requestBody": {
          "$ref": "#/components/requestBodies/PeticionHerramienta"
        },
        "responses": {
          "200": {
            "$ref": "#/components/responses/ResultadoHerramienta"
          },
          "404": {
            "$ref": "#/components/responses/HerramientaNoDisponible"
          }
        }
      }
    },
    "/herramientas/finanzas.abrir": {
      "servers": [
        {
          "url": "http://127.0.0.1:{puerto}",
          "description": "Propuesta para la Fase 6: GRAVITY en la laptop atiende las herramientas para el puente de casa. En la Fase 0 se ejecutan dentro de la app, sin red.",
          "variables": {
            "puerto": {
              "default": "8787"
            }
          }
        }
      ],
      "post": {
        "tags": [
          "Herramientas de GRAVITY"
        ],
        "operationId": "herramientaFinanzasAbrir",
        "summary": "finanzas.abrir · Abrir Finanzas",
        "description": "Abre Finanzas: cada quien su libro y los compartidos de los que es miembro (D19). Solo navega: no lee montos. Es solo local como toda herramienta de Finanzas (D3): ni siquiera \"se abrió Finanzas\" llega a la IA en la nube. Órdenes: \"abre presupuesto\", \"abre finanzas\", \"dinero\".",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 0,
        "requestBody": {
          "$ref": "#/components/requestBodies/PeticionHerramienta"
        },
        "responses": {
          "200": {
            "$ref": "#/components/responses/ResultadoHerramienta"
          },
          "404": {
            "$ref": "#/components/responses/HerramientaNoDisponible"
          }
        }
      }
    },
    "/herramientas/finanzas.registrar_gasto": {
      "servers": [
        {
          "url": "http://127.0.0.1:{puerto}",
          "description": "Propuesta para la Fase 6: GRAVITY en la laptop atiende las herramientas para el puente de casa. En la Fase 0 se ejecutan dentro de la app, sin red.",
          "variables": {
            "puerto": {
              "default": "8787"
            }
          }
        }
      ],
      "post": {
        "tags": [
          "Herramientas de GRAVITY"
        ],
        "operationId": "herramientaFinanzasRegistrarGasto",
        "summary": "finanzas.registrar_gasto · Registrar gasto",
        "description": "Abre la hoja de registro rápido de un gasto (F1): diálogo en la laptop, hoja inferior en el teléfono y la tablet. No guarda nada: la persona captura y confirma en la hoja, que es la confirmación; una orden nunca registra dinero sola. Exige poder escribir en Finanzas (dueño y coadministrador, cada quien en sus libros). La cuenta maestra con login propio es de solo lectura total (D19, 23/oct): no la recibe; si el dueño es además la maestra, la conserva para lo propio. Solo local (D3). Hay que decir el verbo (D19, 23/oct): \"registrar gasto\", \"registra gasto\", \"registrar un gasto\" o \"registra un gasto\"; la palabra \"gasto\" suelta no abre nada.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 1,
        "requestBody": {
          "$ref": "#/components/requestBodies/PeticionHerramienta"
        },
        "responses": {
          "200": {
            "$ref": "#/components/responses/ResultadoHerramienta"
          },
          "404": {
            "$ref": "#/components/responses/HerramientaNoDisponible"
          }
        }
      }
    },
    "/herramientas/finanzas.abrir_semana": {
      "servers": [
        {
          "url": "http://127.0.0.1:{puerto}",
          "description": "Propuesta para la Fase 6: GRAVITY en la laptop atiende las herramientas para el puente de casa. En la Fase 0 se ejecutan dentro de la app, sin red.",
          "variables": {
            "puerto": {
              "default": "8787"
            }
          }
        }
      ],
      "post": {
        "tags": [
          "Herramientas de GRAVITY"
        ],
        "operationId": "herramientaFinanzasAbrirSemana",
        "summary": "finanzas.abrir_semana · Abrir Presupuesto de la semana",
        "description": "Abre Finanzas › Semana (`/finanzas/semana`): cascada, partidas con semáforo y revisión semanal. Solo navega: los montos se ven en la pantalla y nunca van a la IA (D3). Órdenes: \"mi semana\", \"presupuesto semanal\", \"cuánto me queda\".",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 1,
        "requestBody": {
          "$ref": "#/components/requestBodies/PeticionHerramienta"
        },
        "responses": {
          "200": {
            "$ref": "#/components/responses/ResultadoHerramienta"
          },
          "404": {
            "$ref": "#/components/responses/HerramientaNoDisponible"
          }
        }
      }
    },
    "/herramientas/habitos.abrir": {
      "servers": [
        {
          "url": "http://127.0.0.1:{puerto}",
          "description": "Propuesta para la Fase 6: GRAVITY en la laptop atiende las herramientas para el puente de casa. En la Fase 0 se ejecutan dentro de la app, sin red.",
          "variables": {
            "puerto": {
              "default": "8787"
            }
          }
        }
      ],
      "post": {
        "tags": [
          "Herramientas de GRAVITY"
        ],
        "operationId": "herramientaHabitosAbrir",
        "summary": "habitos.abrir · Abrir Hábitos",
        "description": "Abre Hábitos (lo propio de cada persona).",
        "x-roles": [
          "dueno",
          "coadministrador",
          "familiar"
        ],
        "x-escribe": false,
        "x-solo-local": false,
        "x-fase": 0,
        "requestBody": {
          "$ref": "#/components/requestBodies/PeticionHerramienta"
        },
        "responses": {
          "200": {
            "$ref": "#/components/responses/ResultadoHerramienta"
          },
          "404": {
            "$ref": "#/components/responses/HerramientaNoDisponible"
          }
        }
      }
    },
    "/herramientas/cuidados.abrir": {
      "servers": [
        {
          "url": "http://127.0.0.1:{puerto}",
          "description": "Propuesta para la Fase 6: GRAVITY en la laptop atiende las herramientas para el puente de casa. En la Fase 0 se ejecutan dentro de la app, sin red.",
          "variables": {
            "puerto": {
              "default": "8787"
            }
          }
        }
      ],
      "post": {
        "tags": [
          "Herramientas de GRAVITY"
        ],
        "operationId": "herramientaCuidadosAbrir",
        "summary": "cuidados.abrir · Abrir Cuidados",
        "description": "Abre Cuidados. Lo que se ve adentro depende del rol: completo (dueño) o recordatorios genéricos (casa). Es solo local (D3). La cuidadora abre Cuidados desde su navegación, no desde GRAVITY (D18), y el coadministrador no entra hasta que se registre el consentimiento (Fase 5). Sinónimo en la barra de órdenes: papá.",
        "x-roles": [
          "dueno",
          "casa"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 0,
        "requestBody": {
          "$ref": "#/components/requestBodies/PeticionHerramienta"
        },
        "responses": {
          "200": {
            "$ref": "#/components/responses/ResultadoHerramienta"
          },
          "404": {
            "$ref": "#/components/responses/HerramientaNoDisponible"
          }
        }
      }
    },
    "/herramientas/alimentacion.abrir": {
      "servers": [
        {
          "url": "http://127.0.0.1:{puerto}",
          "description": "Propuesta para la Fase 6: GRAVITY en la laptop atiende las herramientas para el puente de casa. En la Fase 0 se ejecutan dentro de la app, sin red.",
          "variables": {
            "puerto": {
              "default": "8787"
            }
          }
        }
      ],
      "post": {
        "tags": [
          "Herramientas de GRAVITY"
        ],
        "operationId": "herramientaAlimentacionAbrir",
        "summary": "alimentacion.abrir · Abrir Alimentación",
        "description": "Abre Alimentación. Sinónimos en la barra de órdenes: comida, cocina, menú, recetas.",
        "x-roles": [
          "dueno",
          "coadministrador",
          "familiar",
          "casa"
        ],
        "x-escribe": false,
        "x-solo-local": false,
        "x-fase": 0,
        "requestBody": {
          "$ref": "#/components/requestBodies/PeticionHerramienta"
        },
        "responses": {
          "200": {
            "$ref": "#/components/responses/ResultadoHerramienta"
          },
          "404": {
            "$ref": "#/components/responses/HerramientaNoDisponible"
          }
        }
      }
    },
    "/herramientas/casa.abrir": {
      "servers": [
        {
          "url": "http://127.0.0.1:{puerto}",
          "description": "Propuesta para la Fase 6: GRAVITY en la laptop atiende las herramientas para el puente de casa. En la Fase 0 se ejecutan dentro de la app, sin red.",
          "variables": {
            "puerto": {
              "default": "8787"
            }
          }
        }
      ],
      "post": {
        "tags": [
          "Herramientas de GRAVITY"
        ],
        "operationId": "herramientaCasaAbrir",
        "summary": "casa.abrir · Abrir Casa",
        "description": "Abre Casa. Sinónimo en la barra de órdenes, hogar.",
        "x-roles": [
          "dueno",
          "coadministrador",
          "familiar",
          "casa"
        ],
        "x-escribe": false,
        "x-solo-local": false,
        "x-fase": 0,
        "requestBody": {
          "$ref": "#/components/requestBodies/PeticionHerramienta"
        },
        "responses": {
          "200": {
            "$ref": "#/components/responses/ResultadoHerramienta"
          },
          "404": {
            "$ref": "#/components/responses/HerramientaNoDisponible"
          }
        }
      }
    },
    "/herramientas/gravity.abrir_solicitudes": {
      "servers": [
        {
          "url": "http://127.0.0.1:{puerto}",
          "description": "Propuesta para la Fase 6: GRAVITY en la laptop atiende las herramientas para el puente de casa. En la Fase 0 se ejecutan dentro de la app, sin red.",
          "variables": {
            "puerto": {
              "default": "8787"
            }
          }
        }
      ],
      "post": {
        "tags": [
          "Herramientas de GRAVITY"
        ],
        "operationId": "herramientaGravityAbrirSolicitudes",
        "summary": "gravity.abrir_solicitudes · Abrir Solicitudes",
        "description": "Abre la bandeja de solicitudes y recordatorios de GRAVITY (`/solicitudes`) para confirmarlos (hecho o no se pudo, con nota). Es lo único de GRAVITY que usa la cuidadora (D18): nada de dinero, de la familia ni de conversación libre. Se resuelve por rol (D17); en el servidor su GRAVITY es `restringido`. Órdenes: \"solicitudes\", \"recordatorios\", \"bandeja\".",
        "x-roles": [
          "cuidador"
        ],
        "x-escribe": false,
        "x-solo-local": false,
        "x-fase": 1,
        "requestBody": {
          "$ref": "#/components/requestBodies/PeticionHerramienta"
        },
        "responses": {
          "200": {
            "$ref": "#/components/responses/ResultadoHerramienta"
          },
          "404": {
            "$ref": "#/components/responses/HerramientaNoDisponible"
          }
        }
      }
    },
    "/herramientas/ajustes.abrir": {
      "servers": [
        {
          "url": "http://127.0.0.1:{puerto}",
          "description": "Propuesta para la Fase 6: GRAVITY en la laptop atiende las herramientas para el puente de casa. En la Fase 0 se ejecutan dentro de la app, sin red.",
          "variables": {
            "puerto": {
              "default": "8787"
            }
          }
        }
      ],
      "post": {
        "tags": [
          "Herramientas de GRAVITY"
        ],
        "operationId": "herramientaAjustesAbrir",
        "summary": "ajustes.abrir · Abrir Ajustes",
        "description": "Abre Ajustes (lo propio de cada persona; todo para el dueño). La cuidadora abre sus ajustes desde su navegación, no desde GRAVITY (D18).",
        "x-roles": [
          "dueno",
          "coadministrador",
          "familiar"
        ],
        "x-escribe": false,
        "x-solo-local": false,
        "x-fase": 0,
        "requestBody": {
          "$ref": "#/components/requestBodies/PeticionHerramienta"
        },
        "responses": {
          "200": {
            "$ref": "#/components/responses/ResultadoHerramienta"
          },
          "404": {
            "$ref": "#/components/responses/HerramientaNoDisponible"
          }
        }
      }
    },
    "/herramientas/ajustes.abrir_desarrollador": {
      "servers": [
        {
          "url": "http://127.0.0.1:{puerto}",
          "description": "Propuesta para la Fase 6: GRAVITY en la laptop atiende las herramientas para el puente de casa. En la Fase 0 se ejecutan dentro de la app, sin red.",
          "variables": {
            "puerto": {
              "default": "8787"
            }
          }
        }
      ],
      "post": {
        "tags": [
          "Herramientas de GRAVITY"
        ],
        "operationId": "herramientaAjustesAbrirDesarrollador",
        "summary": "ajustes.abrir_desarrollador · Abrir Desarrollador",
        "description": "Abre Ajustes › Desarrollador, esta consola. Solo el dueño y solo en la laptop (D16): la barra de órdenes no la ofrece en otro dispositivo y el router de la app lo vuelve a revisar. Administra el hogar (lo ajeno): la cuenta maestra no la recibe (D19).",
        "x-roles": [
          "dueno"
        ],
        "x-escribe": false,
        "x-solo-local": false,
        "x-fase": 0,
        "requestBody": {
          "$ref": "#/components/requestBodies/PeticionHerramienta"
        },
        "responses": {
          "200": {
            "$ref": "#/components/responses/ResultadoHerramienta"
          },
          "404": {
            "$ref": "#/components/responses/HerramientaNoDisponible"
          }
        }
      }
    },
    "/rest/v1/hogares": {
      "get": {
        "tags": [
          "Base de datos"
        ],
        "operationId": "leerHogares",
        "summary": "Leer hogares",
        "description": "Hogares de los que eres miembro vigente.",
        "x-roles": [
          "dueno",
          "coadministrador",
          "familiar",
          "cuidador",
          "casa"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 0,
        "parameters": [
          {
            "$ref": "#/components/parameters/select"
          },
          {
            "$ref": "#/components/parameters/filtroId"
          }
        ],
        "responses": {
          "200": {
            "description": "Hogares visibles.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/Hogar"
                  }
                }
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      },
      "patch": {
        "tags": [
          "Base de datos"
        ],
        "operationId": "renombrarHogar",
        "summary": "Cambiar el nombre del hogar",
        "description": "Solo el dueño (administra Ajustes). Solo la columna `nombre`. Queda en la bitácora.",
        "x-roles": [
          "dueno"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 0,
        "parameters": [
          {
            "$ref": "#/components/parameters/filtroIdObligatorio"
          },
          {
            "$ref": "#/components/parameters/preferir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "nombre"
                ],
                "additionalProperties": false,
                "properties": {
                  "nombre": {
                    "type": "string",
                    "minLength": 1,
                    "maxLength": 80
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "$ref": "#/components/responses/Actualizado"
          },
          "204": {
            "description": "Actualizado (sin cuerpo)."
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          }
        }
      }
    },
    "/rest/v1/rpc/crear_hogar": {
      "post": {
        "tags": [
          "Base de datos"
        ],
        "operationId": "crearHogar",
        "summary": "Crear un hogar",
        "description": "Crea un hogar y deja como dueño a quien lo crea. Devuelve el `id` del hogar. La puede llamar **cualquier cuenta con sesión**, aunque todavía no pertenezca a ningún hogar o tenga otro rol en otro hogar: por eso `x-roles` lista los cinco roles. Quien la llama queda como dueño solo del hogar nuevo.",
        "x-roles": [
          "dueno",
          "coadministrador",
          "familiar",
          "cuidador",
          "casa"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 0,
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "p_nombre"
                ],
                "properties": {
                  "p_nombre": {
                    "type": "string",
                    "minLength": 1,
                    "maxLength": 80
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Identificador del hogar nuevo.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/Uuid"
                }
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      }
    },
    "/rest/v1/personas": {
      "get": {
        "tags": [
          "Base de datos"
        ],
        "operationId": "leerPersonas",
        "summary": "Leer personas",
        "description": "Cada quien se ve a sí mismo; el dueño ve a los miembros de su hogar (también a los dados de baja) y a los titulares de sus libros; quien comparte un libro de Finanzas ve a sus miembros y a su titular (p. ej. los albaceas ven a Papá); quien lee un compartido público ve a sus miembros; la cuenta maestra, a todos (D19).",
        "x-roles": [
          "dueno",
          "coadministrador",
          "familiar",
          "cuidador",
          "casa"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 0,
        "parameters": [
          {
            "$ref": "#/components/parameters/select"
          },
          {
            "$ref": "#/components/parameters/filtroId"
          }
        ],
        "responses": {
          "200": {
            "description": "Personas visibles.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/Persona"
                  }
                }
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      },
      "patch": {
        "tags": [
          "Base de datos"
        ],
        "operationId": "cambiarMiNombre",
        "summary": "Cambiar mi nombre visible",
        "description": "Cada quien cambia solo su propio `nombre_visible`.",
        "x-roles": [
          "dueno",
          "coadministrador",
          "familiar",
          "cuidador",
          "casa"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 0,
        "parameters": [
          {
            "$ref": "#/components/parameters/filtroIdObligatorio"
          },
          {
            "$ref": "#/components/parameters/preferir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "nombre_visible"
                ],
                "additionalProperties": false,
                "properties": {
                  "nombre_visible": {
                    "type": "string",
                    "minLength": 1,
                    "maxLength": 80
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "$ref": "#/components/responses/Actualizado"
          },
          "204": {
            "description": "Actualizado (sin cuerpo)."
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          }
        }
      }
    },
    "/rest/v1/membresias": {
      "get": {
        "tags": [
          "Base de datos"
        ],
        "operationId": "leerMembresias",
        "summary": "Leer membresías y roles",
        "description": "Cada quien ve las suyas; el dueño, las de su hogar. `es_maestra` dice cuál es la cuenta maestra (D19); para mostrarla a todos en Ajustes › Privacidad se usa `cuenta_maestra`.",
        "x-roles": [
          "dueno",
          "coadministrador",
          "familiar",
          "cuidador",
          "casa"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 0,
        "parameters": [
          {
            "$ref": "#/components/parameters/select"
          },
          {
            "$ref": "#/components/parameters/filtroId"
          },
          {
            "$ref": "#/components/parameters/filtroHogar"
          }
        ],
        "responses": {
          "200": {
            "description": "Membresías visibles.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/Membresia"
                  }
                }
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      },
      "patch": {
        "tags": [
          "Base de datos"
        ],
        "operationId": "cambiarMembresia",
        "summary": "Cambiar rol o dar de baja",
        "description": "Solo el dueño, sobre otras personas: cambiar `rol` (nunca a dueño), dar de baja (`activa: false` u `hasta`). La baja quita el acceso de inmediato; las membresías no se borran y todo queda en la bitácora. Dar un rol con Finanzas crea el libro personal de esa persona. `es_maestra` no se cambia aquí: `asignar_cuenta_maestra`. Si quien cambia de rol o se da de baja administraba un libro compartido y deja de ser adulto con Finanzas, el servidor pasa el cargo de administrador de ese libro al miembro vigente más antiguo y, con menos de 2 vigentes, lo deja privado (N5); nunca lo archiva.",
        "x-roles": [
          "dueno"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 0,
        "parameters": [
          {
            "$ref": "#/components/parameters/filtroIdObligatorio"
          },
          {
            "$ref": "#/components/parameters/preferir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "additionalProperties": false,
                "minProperties": 1,
                "properties": {
                  "rol": {
                    "$ref": "#/components/schemas/RolInvitable"
                  },
                  "activa": {
                    "type": "boolean"
                  },
                  "hasta": {
                    "type": [
                      "string",
                      "null"
                    ],
                    "format": "date-time"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "$ref": "#/components/responses/Actualizado"
          },
          "204": {
            "description": "Actualizado (sin cuerpo)."
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          }
        }
      }
    },
    "/rest/v1/permisos_rol": {
      "get": {
        "tags": [
          "Base de datos"
        ],
        "operationId": "leerMatrizPermisos",
        "summary": "Leer la matriz de permisos",
        "description": "Matriz rol × módulo × acción con su alcance. Solo cambia por migración; la app lleva un espejo.",
        "x-roles": [
          "dueno",
          "coadministrador",
          "familiar",
          "cuidador",
          "casa"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 0,
        "parameters": [
          {
            "$ref": "#/components/parameters/select"
          }
        ],
        "responses": {
          "200": {
            "description": "La matriz completa.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/PermisoRol"
                  }
                }
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      }
    },
    "/rest/v1/rpc/mis_permisos": {
      "post": {
        "tags": [
          "Base de datos"
        ],
        "operationId": "misPermisos",
        "summary": "Mis permisos en un hogar",
        "description": "Los permisos del rol vigente de quien consulta (módulo, acción y alcance).",
        "x-roles": [
          "dueno",
          "coadministrador",
          "familiar",
          "cuidador",
          "casa"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 0,
        "requestBody": {
          "$ref": "#/components/requestBodies/SoloHogar"
        },
        "responses": {
          "200": {
            "description": "Permisos del rol.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "type": "object",
                    "properties": {
                      "modulo": {
                        "$ref": "#/components/schemas/Modulo"
                      },
                      "accion": {
                        "$ref": "#/components/schemas/Accion"
                      },
                      "alcance": {
                        "$ref": "#/components/schemas/Alcance"
                      }
                    }
                  }
                }
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      }
    },
    "/rest/v1/invitaciones": {
      "get": {
        "tags": [
          "Base de datos"
        ],
        "operationId": "leerInvitaciones",
        "summary": "Leer invitaciones",
        "description": "Solo el dueño del hogar. El token no se guarda, solo su huella SHA-256. `es_maestra` marca una invitación a la cuenta maestra (D19, 23/oct).",
        "x-roles": [
          "dueno"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 0,
        "parameters": [
          {
            "$ref": "#/components/parameters/select"
          },
          {
            "$ref": "#/components/parameters/filtroHogar"
          }
        ],
        "responses": {
          "200": {
            "description": "Invitaciones del hogar.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/Invitacion"
                  }
                }
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      }
    },
    "/rest/v1/rpc/crear_invitacion": {
      "post": {
        "tags": [
          "Base de datos"
        ],
        "operationId": "crearInvitacion",
        "summary": "Invitar a una persona",
        "description": "Solo el dueño. Rol: coadministrador, familiar, cuidador o casa. Devuelve el token una sola vez; las invitaciones pendientes al mismo correo se revocan. Con `p_es_maestra: true` (D19, 23/oct) invita a la **cuenta maestra**: otra persona con su propio login. El rol debe ser `coadministrador` y el correo no puede ser el de un miembro vigente del hogar (400, 22023). Al aceptarla, la persona queda coadministrador con la marca de cuenta maestra, sin libro personal y de solo lectura total en Finanzas. Se llama igual con 3 o 4 parámetros: `p_vigencia_dias` y `p_es_maestra` son opcionales.",
        "x-roles": [
          "dueno"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 0,
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "p_hogar_id",
                  "p_correo",
                  "p_rol"
                ],
                "properties": {
                  "p_hogar_id": {
                    "$ref": "#/components/schemas/Uuid"
                  },
                  "p_correo": {
                    "type": "string",
                    "format": "email",
                    "maxLength": 254
                  },
                  "p_rol": {
                    "$ref": "#/components/schemas/RolInvitable"
                  },
                  "p_vigencia_dias": {
                    "type": "integer",
                    "minimum": 1,
                    "maximum": 30,
                    "default": 7
                  },
                  "p_es_maestra": {
                    "type": "boolean",
                    "default": false,
                    "description": "Invitar a la cuenta maestra (solo con rol `coadministrador` y un correo que no sea de un miembro del hogar)."
                  }
                }
              },
              "examples": {
                "maestra": {
                  "summary": "Invitar a la cuenta maestra (otra persona, con otro correo)",
                  "value": {
                    "p_hogar_id": "b0000000-0000-4000-8000-000000000001",
                    "p_correo": "marta@ejemplo.test",
                    "p_rol": "coadministrador",
                    "p_es_maestra": true
                  }
                },
                "coadministrador": {
                  "summary": "Invitar a la pareja",
                  "value": {
                    "p_hogar_id": "b0000000-0000-4000-8000-000000000001",
                    "p_correo": "alex@ejemplo.test",
                    "p_rol": "coadministrador"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "La invitación y su token (se muestra una sola vez).",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "type": "object",
                    "properties": {
                      "invitacion_id": {
                        "$ref": "#/components/schemas/Uuid"
                      },
                      "token": {
                        "type": "string"
                      },
                      "expira": {
                        "type": "string",
                        "format": "date-time"
                      }
                    }
                  }
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/Invalido"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          }
        }
      }
    },
    "/rest/v1/rpc/aceptar_invitacion": {
      "post": {
        "tags": [
          "Base de datos"
        ],
        "operationId": "aceptarInvitacion",
        "summary": "Aceptar una invitación",
        "description": "La acepta la persona cuyo correo confirmado coincide; crea su membresía con el rol invitado. Devuelve el `id` del hogar. Si la invitación era de cuenta maestra (`es_maestra`), la membresía nace con `es_maestra` y sin libro personal; la maestra anterior, si la había, deja de serlo, y queda la entrada `finanzas.maestra_asignada` en la bitácora (con `anterior_persona_id`, `nueva_persona_id` e `invitada_por`).",
        "x-roles": [
          "coadministrador",
          "familiar",
          "cuidador",
          "casa"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 0,
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "p_token"
                ],
                "properties": {
                  "p_token": {
                    "type": "string"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Hogar al que entraste.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/Uuid"
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/Invalido"
          }
        }
      }
    },
    "/rest/v1/rpc/revocar_invitacion": {
      "post": {
        "tags": [
          "Base de datos"
        ],
        "operationId": "revocarInvitacion",
        "summary": "Revocar una invitación pendiente",
        "description": "Solo el dueño, y solo si la invitación sigue pendiente.",
        "x-roles": [
          "dueno"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 0,
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "p_invitacion_id"
                ],
                "properties": {
                  "p_invitacion_id": {
                    "$ref": "#/components/schemas/Uuid"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "204": {
            "description": "Revocada."
          },
          "400": {
            "$ref": "#/components/responses/Invalido"
          }
        }
      }
    },
    "/rest/v1/dispositivos": {
      "get": {
        "tags": [
          "Base de datos"
        ],
        "operationId": "leerDispositivos",
        "summary": "Leer mis dispositivos",
        "description": "Cada quien ve solo los suyos. La función de avisos (Fase 2) los lee desde el servidor.",
        "x-roles": [
          "dueno",
          "coadministrador",
          "familiar",
          "cuidador",
          "casa"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 0,
        "parameters": [
          {
            "$ref": "#/components/parameters/select"
          },
          {
            "$ref": "#/components/parameters/filtroId"
          }
        ],
        "responses": {
          "200": {
            "description": "Mis dispositivos.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/Dispositivo"
                  }
                }
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      },
      "post": {
        "tags": [
          "Base de datos"
        ],
        "operationId": "registrarDispositivo",
        "summary": "Registrar este dispositivo",
        "description": "Agrega un dispositivo a tu nombre, con su token de avisos (FCM, solo Android).",
        "x-roles": [
          "dueno",
          "coadministrador",
          "familiar",
          "cuidador",
          "casa"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 0,
        "parameters": [
          {
            "$ref": "#/components/parameters/preferir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "plataforma"
                ],
                "additionalProperties": false,
                "properties": {
                  "id": {
                    "$ref": "#/components/schemas/Uuid"
                  },
                  "plataforma": {
                    "type": "string",
                    "enum": [
                      "android",
                      "windows"
                    ]
                  },
                  "token_avisos": {
                    "type": [
                      "string",
                      "null"
                    ],
                    "maxLength": 4096
                  },
                  "nombre": {
                    "type": [
                      "string",
                      "null"
                    ],
                    "maxLength": 80
                  }
                }
              }
            }
          }
        },
        "responses": {
          "201": {
            "description": "Registrado."
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          }
        }
      },
      "patch": {
        "tags": [
          "Base de datos"
        ],
        "operationId": "actualizarDispositivo",
        "summary": "Actualizar mi dispositivo",
        "description": "Token de avisos, nombre o último uso; solo los tuyos.",
        "x-roles": [
          "dueno",
          "coadministrador",
          "familiar",
          "cuidador",
          "casa"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 0,
        "parameters": [
          {
            "$ref": "#/components/parameters/filtroIdObligatorio"
          },
          {
            "$ref": "#/components/parameters/preferir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "additionalProperties": false,
                "minProperties": 1,
                "properties": {
                  "token_avisos": {
                    "type": [
                      "string",
                      "null"
                    ],
                    "maxLength": 4096
                  },
                  "nombre": {
                    "type": [
                      "string",
                      "null"
                    ],
                    "maxLength": 80
                  },
                  "ultimo_uso": {
                    "type": "string",
                    "format": "date-time"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "$ref": "#/components/responses/Actualizado"
          },
          "204": {
            "description": "Actualizado (sin cuerpo)."
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          }
        }
      },
      "delete": {
        "tags": [
          "Base de datos"
        ],
        "operationId": "quitarDispositivo",
        "summary": "Quitar mi dispositivo",
        "description": "Deja de recibir avisos en ese dispositivo; solo los tuyos.",
        "x-roles": [
          "dueno",
          "coadministrador",
          "familiar",
          "cuidador",
          "casa"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 0,
        "parameters": [
          {
            "$ref": "#/components/parameters/filtroIdObligatorio"
          }
        ],
        "responses": {
          "204": {
            "description": "Quitado."
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          }
        }
      }
    },
    "/rest/v1/bitacora": {
      "get": {
        "tags": [
          "Base de datos"
        ],
        "operationId": "leerBitacora",
        "summary": "Leer la bitácora",
        "description": "Solo agregar. Cada quien ve lo que hizo. El historial de GRAVITY (`gravity.*`): su autor, también para el dueño (D18), y la cuenta maestra. Lo de Finanzas (tablas `fin_*` y acciones `finanzas*`): quien puede leer el libro de la entrada (la cuenta maestra solo con una consulta vigente, I2) o, si es del hogar, quien tiene Finanzas. Lo demás (membresías, invitaciones…): el dueño y la cuenta maestra. Las acciones que el servidor deja en Finanzas son `finanzas.consulta_maestra` (cada consulta de la maestra a un libro ajeno, visible para quienes lo llevan), `finanzas.maestra_asignada` (quién es la maestra, visible para todo adulto con Finanzas), `finanzas.salida_libro_representado` (una salida del libro de Papá hacia cualquier otro libro, personal o compartido, visible para quienes lo llevan) y `finanzas.albacea_nombrado` (el dueño nombró al albacea o al suplente del libro de Papá, visible para quienes lo llevan).",
        "x-roles": [
          "dueno",
          "coadministrador",
          "familiar",
          "cuidador",
          "casa"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 0,
        "parameters": [
          {
            "$ref": "#/components/parameters/select"
          },
          {
            "$ref": "#/components/parameters/filtroHogar"
          },
          {
            "$ref": "#/components/parameters/orden"
          },
          {
            "$ref": "#/components/parameters/limite"
          }
        ],
        "responses": {
          "200": {
            "description": "Entradas visibles.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/EntradaBitacora"
                  }
                },
                "example": [
                  {
                    "id": "9a1b2c3d-4e5f-4a6b-8c7d-0e1f2a3b4c01",
                    "hogar_id": "b0000000-0000-4000-8000-000000000001",
                    "persona_id": "e0000000-0000-4000-8000-000000000008",
                    "accion": "finanzas.consulta_maestra",
                    "tabla": "fin_libros",
                    "registro_id": "f1000000-0000-4000-8000-000000000001",
                    "detalle": {
                      "libro_id": "f1000000-0000-4000-8000-000000000001",
                      "tipo": "compartido",
                      "vigencia_minutos": 30
                    },
                    "ocurrido_en": "2026-10-23T09:15:00-06:00",
                    "registrado_en": "2026-10-23T09:15:00-06:00"
                  },
                  {
                    "id": "9a1b2c3d-4e5f-4a6b-8c7d-0e1f2a3b4c02",
                    "hogar_id": "b0000000-0000-4000-8000-000000000001",
                    "persona_id": "e0000000-0000-4000-8000-000000000001",
                    "accion": "finanzas.maestra_asignada",
                    "tabla": "membresias",
                    "registro_id": "e0000000-0000-4000-8000-000000000008",
                    "detalle": {
                      "anterior_persona_id": null,
                      "nueva_persona_id": "e0000000-0000-4000-8000-000000000008",
                      "invitada_por": "e0000000-0000-4000-8000-000000000001"
                    },
                    "ocurrido_en": "2026-10-22T20:00:00-06:00",
                    "registrado_en": "2026-10-22T20:00:00-06:00"
                  },
                  {
                    "id": "9a1b2c3d-4e5f-4a6b-8c7d-0e1f2a3b4c03",
                    "hogar_id": "b0000000-0000-4000-8000-000000000001",
                    "persona_id": "e0000000-0000-4000-8000-000000000001",
                    "accion": "finanzas.salida_libro_representado",
                    "tabla": "fin_movimientos",
                    "registro_id": "3d0c2f5e-8a41-4b7e-9c1d-5f2a6b8e9a05",
                    "detalle": {
                      "libro_id": "f1000000-0000-4000-8000-000000000002",
                      "libro_destino_id": "f1000000-0000-4000-8000-000000000003",
                      "tipo": "transferencia",
                      "fecha": "2026-10-21",
                      "monto_centavos": 150000,
                      "en_nombre_de": "e0000000-0000-4000-8000-000000000009",
                      "motivo": "Reembolso de la farmacia de Papá (ejemplo)"
                    },
                    "ocurrido_en": "2026-10-21T11:20:00-06:00",
                    "registrado_en": "2026-10-21T11:20:03-06:00"
                  }
                ]
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      },
      "post": {
        "tags": [
          "Base de datos"
        ],
        "operationId": "agregarABitacora",
        "summary": "Agregar a la bitácora",
        "description": "Cualquier miembro agrega a su nombre (p. ej. acciones de GRAVITY en la laptop, D8). No se edita ni se borra: se corrige con una entrada nueva. `accion` es un identificador en minúsculas (`^[a-z][a-z0-9_.]*$`, hasta 60 caracteres), p. ej. `entrega_de_turno` o `gravity.abrir`; si no cumple, responde 400 (código 23514). Hay entradas reservadas al servidor, **para todo rol de la app**, y responden 403 (código 42501): las acciones `insertar`, `actualizar` y `borrar` (las de los triggers que registran los cambios de las tablas), cualquier acción que empiece por `finanzas` (p. ej. `finanzas.consulta_maestra`, `finanzas.maestra_asignada` y `finanzas.salida_libro_representado`) y cualquier entrada cuya `tabla` sea `fin_*` (con o sin `public.`). Esas las escriben solo los triggers y las funciones del servidor: así nadie fabrica un cambio automático, una consulta de la cuenta maestra ni un aviso de Finanzas (I5). Lo que la app escribe aquí tiene tope (N1): el `detalle` de una entrada pesa a lo más 4 KB y cada persona agrega a lo más 500 entradas propias en 24 horas (cuentan las que escribe la app: no las automáticas ni las de Finanzas); al excederlo responde 500 con el código 54000 y la sentencia entera se deshace (no se guarda ninguna de sus entradas). No es un error que se reintente: la cola lo deja en \"requiere atención\". No limita a los triggers ni a las funciones del servidor, y vale igual para familiar, cuidador y la cuenta Hogar.",
        "x-roles": [
          "dueno",
          "coadministrador",
          "familiar",
          "cuidador",
          "casa"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 0,
        "parameters": [
          {
            "$ref": "#/components/parameters/preferir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "accion"
                ],
                "additionalProperties": false,
                "properties": {
                  "id": {
                    "$ref": "#/components/schemas/Uuid"
                  },
                  "hogar_id": {
                    "$ref": "#/components/schemas/Uuid"
                  },
                  "accion": {
                    "type": "string",
                    "minLength": 1,
                    "maxLength": 60,
                    "pattern": "^[a-z][a-z0-9_.]*$",
                    "not": {
                      "anyOf": [
                        {
                          "enum": [
                            "insertar",
                            "actualizar",
                            "borrar"
                          ]
                        },
                        {
                          "pattern": "^finanzas"
                        }
                      ]
                    },
                    "description": "Identificador en minúsculas (letras, dígitos, `_` y `.`). `insertar`, `actualizar` y `borrar`, y toda acción que empiece por `finanzas`, están reservadas al servidor (403, código 42501).",
                    "examples": [
                      "entrega_de_turno",
                      "gravity.abrir"
                    ]
                  },
                  "tabla": {
                    "type": "string",
                    "maxLength": 63,
                    "not": {
                      "pattern": "^\\s*(public\\.)?[fF][iI][nN]_"
                    },
                    "description": "Las tablas `fin_*` están reservadas al servidor (403, código 42501)."
                  },
                  "registro_id": {
                    "type": "string",
                    "maxLength": 200
                  },
                  "detalle": {
                    "type": "object",
                    "description": "Hasta 4 KB en texto; si pesa más, 54000 (N1)."
                  },
                  "ocurrido_en": {
                    "type": "string",
                    "format": "date-time"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "201": {
            "description": "Agregada."
          },
          "400": {
            "description": "`accion` no cumple el formato `^[a-z][a-z0-9_.]*$` o pasa de 60 caracteres (restricción del servidor, código 23514).",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ErrorPostgrest"
                },
                "example": {
                  "code": "23514",
                  "message": "new row for relation \"bitacora\" violates check constraint \"bitacora_accion_check\"",
                  "details": null,
                  "hint": null
                }
              }
            }
          },
          "403": {
            "description": "Las reglas del servidor no lo permiten: la acción es `insertar`, `actualizar` o `borrar` (reservadas a los triggers) o empieza por `finanzas`, la tabla es `fin_*` (también reservadas al servidor, I5), la entrada va a nombre de otra persona, el hogar no es tuyo o `ocurrido_en` pasa de 10 minutos en el futuro (código 42501).",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ErrorPostgrest"
                },
                "example": {
                  "code": "42501",
                  "message": "new row violates row-level security policy for table \"bitacora\"",
                  "details": null,
                  "hint": null
                }
              }
            }
          },
          "500": {
            "description": "Pasó el tope de la bitácora (N1, código 54000, `program_limit_exceeded`): una entrada con un `detalle` de más de 4 KB, o más de 500 entradas propias en 24 horas. La sentencia entera se deshace. No es de las clases que la cola reintenta: lo rechazado queda en \"requiere atención\".",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/ErrorPostgrest"
                },
                "example": {
                  "code": "54000",
                  "message": "Demasiadas entradas en la bitácora: el tope es de 500 por persona en 24 horas.",
                  "details": null,
                  "hint": "Inténtalo de nuevo mañana; si es un error de la app, avísale a quien la mantiene."
                }
              }
            }
          }
        }
      }
    },
    "/rest/v1/fin_libros": {
      "get": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "leerLibrosFinanzas",
        "summary": "Leer libros",
        "description": "Tu libro personal, los compartidos de los que eres miembro y, si eres albacea, el de Papá (D19). Un compartido `publica` lo leen (no lo escriben) todos los adultos con Finanzas del hogar; uno `privada` (por omisión), solo sus miembros: el dueño no entra a un compartido privado del que no es miembro. Un libro archivado (`activo: false`) sigue en la lista, de solo lectura. La cuenta maestra ve la **portada** de todos los libros del hogar (el libro y quién lo lleva) sin consulta, para elegir cuál mirar; su contenido exige una consulta registrada (`fin_registrar_consulta_maestra`, I2). El libro personal lo crea el servidor al dar un rol con Finanzas (la maestra no lleva uno): la app lo busca (`tipo=eq.personal` y `titular_id` = su persona), no lo crea.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/select"
          },
          {
            "$ref": "#/components/parameters/filtroId"
          },
          {
            "$ref": "#/components/parameters/filtroHogar"
          }
        ],
        "responses": {
          "200": {
            "description": "Libros que puedes leer.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/FinLibro"
                  }
                },
                "example": [
                  {
                    "id": "f1000000-0000-4000-8000-000000000001",
                    "hogar_id": "b0000000-0000-4000-8000-000000000001",
                    "nombre": "Gastos de la casa",
                    "tipo": "compartido",
                    "titular_id": null,
                    "activo": true,
                    "visibilidad": "privada"
                  },
                  {
                    "id": "f1000000-0000-4000-8000-000000000002",
                    "hogar_id": "b0000000-0000-4000-8000-000000000001",
                    "nombre": "Papá (ejemplo)",
                    "tipo": "representado",
                    "titular_id": "e0000000-0000-4000-8000-000000000009",
                    "activo": true
                  }
                ]
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      },
      "post": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "crearLibroCompartido",
        "summary": "Crear un libro compartido",
        "description": "Cualquier adulto con Finanzas crea un libro `compartido` (p. ej. \"Gastos de la casa\") y queda como su miembro y su **administrador** (`creado_por`); luego agrega a los demás en `fin_libro_miembros`. Todo nace `privada` (por omisión); `visibilidad` solo existe en los compartidos y se puede crear ya `publica`. El personal lo crea el servidor y el representado (Papá), `fin_crear_libro_representado`. `creado_por` y `creado_en` los pone el servidor: mandar `creado_por` responde 403 (42501). La cuenta maestra que no es la dueña no crea libros (solo lectura total, 403, 42501).",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/alConflicto"
          },
          {
            "$ref": "#/components/parameters/preferirAlSubir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "allOf": [
                  {
                    "$ref": "#/components/schemas/FinLibro"
                  },
                  {
                    "required": [
                      "id",
                      "hogar_id",
                      "nombre",
                      "tipo"
                    ]
                  }
                ]
              },
              "examples": {
                "compartido": {
                  "summary": "Gastos de la casa (Ana y Alex), privado por omisión",
                  "value": {
                    "id": "f1000000-0000-4000-8000-000000000001",
                    "hogar_id": "b0000000-0000-4000-8000-000000000001",
                    "nombre": "Gastos de la casa",
                    "tipo": "compartido"
                  }
                },
                "publico": {
                  "summary": "Un compartido público (los adultos con Finanzas lo leen)",
                  "value": {
                    "id": "f1000000-0000-4000-8000-000000000004",
                    "hogar_id": "b0000000-0000-4000-8000-000000000001",
                    "nombre": "Vacaciones (ejemplo)",
                    "tipo": "compartido",
                    "visibilidad": "publica"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "201": {
            "$ref": "#/components/responses/Agregado"
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          }
        }
      },
      "patch": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "cambiarLibroFinanzas",
        "summary": "Cambiar el nombre, la visibilidad o archivar un libro",
        "description": "Quien lo administra (titular de un personal, miembro de un compartido, albacea de un representado). Se cambian `nombre`, `activo` y, en un compartido, `visibilidad`; `tipo`, `titular_id`, `creado_por` y las llaves no cambian (42501). En un compartido, solo quien lo creó cambia la `visibilidad`, lo archiva (`activo: false`) o lo reactiva (`activo: true`); a otro miembro responde 403 (42501). Archivar es solo la decisión explícita del administrador y nunca ocurre solo: cuando quedan menos de 2 miembros el libro pasa a `privada` y sigue activo (ver `cambiarMiembroLibro`). Reactivarlo no exige 2 miembros. Un libro archivado es de solo lectura: se lee y ya no admite movimientos nuevos y, mientras lo está, solo su administrador lo administra.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/filtroIdObligatorio"
          },
          {
            "$ref": "#/components/parameters/preferir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "allOf": [
                  {
                    "$ref": "#/components/schemas/FinLibro"
                  },
                  {
                    "minProperties": 1
                  }
                ]
              },
              "examples": {
                "publicar": {
                  "summary": "Hacer público un compartido (solo su administrador)",
                  "value": {
                    "visibilidad": "publica"
                  }
                },
                "archivar": {
                  "summary": "Archivar el libro (solo lectura)",
                  "value": {
                    "activo": false
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "$ref": "#/components/responses/Actualizado"
          },
          "204": {
            "description": "Actualizado (sin cuerpo)."
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          }
        }
      }
    },
    "/rest/v1/fin_libro_miembros": {
      "get": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "leerMiembrosLibro",
        "summary": "Leer quién lleva cada libro",
        "description": "Miembros vigentes e históricos de los libros que puedes leer (quien lee un compartido público ve a sus miembros); la cuenta maestra ve quién lleva cada libro del hogar sin consulta (I2). Personal: solo su titular. Compartido: sus miembros adultos. Representado: 1 albacea y, opcional, 1 suplente.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/select"
          },
          {
            "$ref": "#/components/parameters/filtroHogar"
          },
          {
            "$ref": "#/components/parameters/filtroLibro"
          }
        ],
        "responses": {
          "200": {
            "description": "Miembros visibles.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/FinLibroMiembro"
                  }
                }
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      },
      "post": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "agregarMiembroLibro",
        "summary": "Agregar un miembro, albacea o suplente",
        "description": "Quien administra el libro agrega a otra persona adulta con Finanzas (dueño o coadministrador): `miembro` en un compartido; `albacea_suplente` en el de Papá (máximo un albacea y un suplente vigentes; el suplente escribe solo si no hay albacea vigente). Nunca familiar, cuidador ni Casa (22023). En un compartido solo agrega quien lo creó, o el dueño del hogar si es miembro (403, 42501). La cuenta maestra que no es la dueña no puede ser miembro de ningún libro (400, 22023: es solo lectura). Para nombrar al albacea o al suplente del libro de Papá cuando ese cargo quedó vacío, el dueño del hogar usa `finNombrarAlbacea` (N4): el INSERT directo no le pasa.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/alConflicto"
          },
          {
            "$ref": "#/components/parameters/preferirAlSubir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "allOf": [
                  {
                    "$ref": "#/components/schemas/FinLibroMiembro"
                  },
                  {
                    "required": [
                      "hogar_id",
                      "libro_id",
                      "persona_id",
                      "papel"
                    ]
                  }
                ]
              },
              "examples": {
                "suplente": {
                  "summary": "Alex, suplente del albacea en el libro de Papá",
                  "value": {
                    "hogar_id": "b0000000-0000-4000-8000-000000000001",
                    "libro_id": "f1000000-0000-4000-8000-000000000002",
                    "persona_id": "e0000000-0000-4000-8000-000000000002",
                    "papel": "albacea_suplente"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "201": {
            "$ref": "#/components/responses/Agregado"
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          }
        }
      },
      "patch": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "cambiarMiembroLibro",
        "summary": "Cerrar la participación en un libro",
        "description": "Los miembros no se borran: se cierra `hasta` (queda en la bitácora). `libro_id` y `persona_id` no cambian (42501). En un libro **compartido**: **salirse** es un `PATCH` a la propia fila con `hasta` = ahora (la hora la manda el dispositivo); cualquier miembro puede, siempre, también con el libro archivado (`fin_puede_salir`). Si al salir (o al sacar a alguien) quedan menos de 2 miembros vigentes (adultos con Finanzas), el libro **no se archiva**: sigue `activo` y pasa a `visibilidad` = `privada`, y el miembro que queda es el administrador (`creado_por`), sin error. Si se va quien lo administra (o ya no es adulto con Finanzas del hogar), `creado_por` pasa al miembro vigente más antiguo (`desde`, luego `id`). El **último miembro vigente no puede salirse** ni lo saca nadie (400, 22023, \"El último miembro de un libro compartido no puede salirse\"; si ya no se usa, el administrador lo archiva). Todo cambio de `fin_libros` que hace el servidor queda en la bitácora. Quien se salió no vuelve a abrir su fila (ni con `upsert`): lo reingresa el administrador con una fila nueva. **Quitar a otro** (o cambiar su `desde`, `hasta` o `papel`) es solo de quien creó el libro, o del dueño del hogar si es miembro (I1); a cualquier otro responde 403 (42501). Cambiar la fecha `desde` de la propia fila también es solo del administrador (42501). Un albacea es vigente (I4) solo si su membresía del hogar sigue activa y con Finanzas; si no, escribe el suplente.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/filtroIdObligatorio"
          },
          {
            "$ref": "#/components/parameters/preferir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "allOf": [
                  {
                    "$ref": "#/components/schemas/FinLibroMiembro"
                  },
                  {
                    "minProperties": 1
                  }
                ]
              },
              "examples": {
                "salirse": {
                  "summary": "Salirme de un libro compartido (PATCH a mi propia fila; si quedan menos de 2 miembros, el libro pasa a privado)",
                  "value": {
                    "hasta": "2026-10-23T09:30:00-06:00"
                  }
                },
                "quitar": {
                  "summary": "El administrador cierra la participación de otro miembro",
                  "value": {
                    "hasta": "2026-10-23T09:35:00-06:00"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "$ref": "#/components/responses/Actualizado"
          },
          "204": {
            "description": "Actualizado (sin cuerpo)."
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          }
        }
      }
    },
    "/rest/v1/fin_categorias": {
      "get": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "leerCategoriasFinanzas",
        "summary": "Leer el árbol de categorías",
        "description": "Árbol común del hogar (3 niveles), para todos los libros. Lo leen quienes tienen Finanzas y la cuenta maestra.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/select"
          },
          {
            "$ref": "#/components/parameters/filtroId"
          },
          {
            "$ref": "#/components/parameters/filtroHogar"
          }
        ],
        "responses": {
          "200": {
            "description": "Categorías del hogar.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/FinCategoria"
                  }
                }
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      },
      "post": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "agregarCategoriaFinanzas",
        "summary": "Agregar una categoría",
        "description": "Nivel 1 sin padre; niveles 2 y 3 con `padre_id`. Única por (`hogar_id`, `padre_id`, `nombre`). La importación de la hoja Categorías usa la misma operación. Es configuración del hogar (M6): la hacen el dueño y la pareja; la cuenta maestra que no es la dueña no la cambia (403, 42501).",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/alConflicto"
          },
          {
            "$ref": "#/components/parameters/preferirAlSubir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "allOf": [
                  {
                    "$ref": "#/components/schemas/FinCategoria"
                  },
                  {
                    "required": [
                      "id",
                      "hogar_id",
                      "nivel",
                      "nombre"
                    ]
                  }
                ]
              },
              "examples": {
                "alimentacion": {
                  "summary": "Alimentación (nivel 1)",
                  "value": {
                    "id": "c1000000-0000-4000-8000-000000000010",
                    "hogar_id": "b0000000-0000-4000-8000-000000000001",
                    "nivel": 1,
                    "nombre": "Alimentación",
                    "naturaleza": "variable",
                    "prioridad": "necesario"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "201": {
            "$ref": "#/components/responses/Agregado"
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          }
        }
      },
      "patch": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "cambiarCategoriaFinanzas",
        "summary": "Cambiar, ocultar o archivar una categoría",
        "description": "Una categoría con datos no se borra: se archiva (`archivada: true`) o se oculta. Es configuración del hogar (M6): la hacen el dueño y la pareja; la cuenta maestra que no es la dueña no la cambia (403, 42501). Archivar una categoría archiva su cuenta de gasto (si ninguna otra categoría activa la usa) y desarchivarla (`archivada: false`) la reactiva.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/filtroIdObligatorio"
          },
          {
            "$ref": "#/components/parameters/preferir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "allOf": [
                  {
                    "$ref": "#/components/schemas/FinCategoria"
                  },
                  {
                    "minProperties": 1
                  }
                ]
              },
              "example": {
                "archivada": true
              }
            }
          }
        },
        "responses": {
          "200": {
            "$ref": "#/components/responses/Actualizado"
          },
          "204": {
            "description": "Actualizado (sin cuerpo)."
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          }
        }
      },
      "delete": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "borrarCategoriaFinanzas",
        "summary": "Borrar una categoría sin datos",
        "description": "Solo sin datos: si la usa un movimiento, una cuenta o una subcategoría, responde 409 (23503); entonces se archiva. Es configuración del hogar (M6): la hacen el dueño y la pareja; la cuenta maestra que no es la dueña no la cambia (403, 42501).",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/filtroIdObligatorio"
          }
        ],
        "responses": {
          "204": {
            "description": "Borrado."
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          }
        }
      }
    },
    "/rest/v1/fin_cuentas": {
      "get": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "leerCuentasFinanzas",
        "summary": "Leer cuentas",
        "description": "Las cuentas de tus libros (efectivo, banco, tarjeta…) y las de gasto del hogar (`libro_id` nulo). El nombre de una cuenta de un libro del que no eres miembro no se ve. `clase` y `liquida` son generadas. La cuenta maestra ve vacío el libro de otra persona mientras no tenga una consulta vigente (`fin_registrar_consulta_maestra`, 30 minutos): no da error, no devuelve filas.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/select"
          },
          {
            "$ref": "#/components/parameters/filtroId"
          },
          {
            "$ref": "#/components/parameters/filtroHogar"
          },
          {
            "$ref": "#/components/parameters/filtroLibro"
          }
        ],
        "responses": {
          "200": {
            "description": "Cuentas visibles.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/FinCuenta"
                  }
                }
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      },
      "post": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "agregarCuentaFinanzas",
        "summary": "Agregar una cuenta",
        "description": "De un libro (activos, pasivos, origen de ingreso) o del hogar si es `de_gasto` o `gasto_financiero` (`libro_id` nulo). Ajustes, Apertura y Por clasificar se crean solas con cada libro. Única por (`hogar_id`, `libro_id`, `nombre`). Las cuentas de gasto son configuración del hogar (M6): la cuenta maestra que no es la dueña no las cambia (403, 42501).",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/alConflicto"
          },
          {
            "$ref": "#/components/parameters/preferirAlSubir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "allOf": [
                  {
                    "$ref": "#/components/schemas/FinCuenta"
                  },
                  {
                    "required": [
                      "id",
                      "hogar_id",
                      "nombre",
                      "tipo"
                    ]
                  }
                ]
              },
              "examples": {
                "efectivo": {
                  "summary": "Efectivo del libro compartido",
                  "value": {
                    "id": "c3000000-0000-4000-8000-000000000020",
                    "hogar_id": "b0000000-0000-4000-8000-000000000001",
                    "libro_id": "f1000000-0000-4000-8000-000000000001",
                    "nombre": "Efectivo de la casa",
                    "tipo": "efectivo"
                  }
                },
                "tarjeta": {
                  "summary": "Tarjeta con límite (pasivo)",
                  "value": {
                    "id": "c3000000-0000-4000-8000-000000000021",
                    "hogar_id": "b0000000-0000-4000-8000-000000000001",
                    "libro_id": "f1000000-0000-4000-8000-000000000001",
                    "nombre": "Tarjeta de la casa (ejemplo)",
                    "tipo": "tarjeta",
                    "limite_centavos": 1500000
                  }
                }
              }
            }
          }
        },
        "responses": {
          "201": {
            "$ref": "#/components/responses/Agregado"
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          }
        }
      },
      "patch": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "cambiarCuentaFinanzas",
        "summary": "Cambiar, congelar, cerrar o archivar una cuenta",
        "description": "Cerrar o archivar exige saldo cero (confirmado y con pendientes; si no, 400, 22023) solo en las cuentas de activo y pasivo: las de gasto e ingreso son de periodo y se cierran o archivan con saldo. Las de sistema no cambian de tipo ni de estado. `libro_id` no cambia (42501). Las cuentas de gasto son configuración del hogar (M6): la cuenta maestra que no es la dueña no las cambia (403, 42501).",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/filtroIdObligatorio"
          },
          {
            "$ref": "#/components/parameters/preferir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "allOf": [
                  {
                    "$ref": "#/components/schemas/FinCuenta"
                  },
                  {
                    "minProperties": 1
                  }
                ]
              },
              "example": {
                "estado": "congelada"
              }
            }
          }
        },
        "responses": {
          "200": {
            "$ref": "#/components/responses/Actualizado"
          },
          "204": {
            "description": "Actualizado (sin cuerpo)."
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          },
          "500": {
            "$ref": "#/components/responses/EstadoFinanzas"
          }
        }
      },
      "delete": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "borrarCuentaFinanzas",
        "summary": "Borrar una cuenta sin movimientos",
        "description": "Solo sin movimientos: con movimientos responde 409 (23503) y se cierra o archiva con saldo cero. Las cuentas de gasto son configuración del hogar (M6): la cuenta maestra que no es la dueña no las cambia (403, 42501).",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/filtroIdObligatorio"
          }
        ],
        "responses": {
          "204": {
            "description": "Borrado."
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          }
        }
      }
    },
    "/rest/v1/fin_parametros": {
      "get": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "leerParametrosFinanzas",
        "summary": "Leer los parámetros de un libro",
        "description": "Una fila por libro (la crea el servidor con los valores por defecto de 5.6 bis y 5.9 bis): meta de remanente, ahorro mínimo con deuda, tope de arrastre, umbrales de semáforo y cierre automático. Porcentajes en puntos base. La cuenta maestra ve vacío el libro de otra persona mientras no tenga una consulta vigente (`fin_registrar_consulta_maestra`, 30 minutos): no da error, no devuelve filas.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/select"
          },
          {
            "$ref": "#/components/parameters/filtroHogar"
          },
          {
            "$ref": "#/components/parameters/filtroLibro"
          }
        ],
        "responses": {
          "200": {
            "description": "Parámetros de los libros visibles.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/FinParametros"
                  }
                }
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      },
      "patch": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "cambiarParametrosFinanzas",
        "summary": "Cambiar los parámetros de un libro",
        "description": "Quien administra el libro. Se cambian con UPDATE (la fila ya existe). Los ids de las cuentas de sistema no cambian (42501).",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/filtroLibroObligatorio"
          },
          {
            "$ref": "#/components/parameters/preferir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "allOf": [
                  {
                    "$ref": "#/components/schemas/FinParametros"
                  },
                  {
                    "minProperties": 1
                  }
                ]
              },
              "example": {
                "meta_remanente_pb": 2000,
                "tope_arrastre_semanas": 2
              }
            }
          }
        },
        "responses": {
          "200": {
            "$ref": "#/components/responses/Actualizado"
          },
          "204": {
            "description": "Actualizado (sin cuerpo)."
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          }
        }
      }
    },
    "/rest/v1/fin_movimientos": {
      "get": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "leerMovimientos",
        "summary": "Leer movimientos",
        "description": "Movimientos de los libros que puedes leer; uno entre libros (aportación a un compartido) se ve desde los dos. Para el saldo usa `fin_v_saldos`. La cuenta maestra ve vacío el libro de otra persona mientras no tenga una consulta vigente (`fin_registrar_consulta_maestra`, 30 minutos): no da error, no devuelve filas.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/select"
          },
          {
            "$ref": "#/components/parameters/filtroId"
          },
          {
            "$ref": "#/components/parameters/filtroHogar"
          },
          {
            "$ref": "#/components/parameters/filtroLibro"
          },
          {
            "$ref": "#/components/parameters/filtroFecha"
          },
          {
            "$ref": "#/components/parameters/orden"
          },
          {
            "$ref": "#/components/parameters/limite"
          }
        ],
        "responses": {
          "200": {
            "description": "Movimientos visibles.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/FinMovimiento"
                  }
                }
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      },
      "post": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "registrarMovimiento",
        "summary": "Registrar un movimiento (solo agregar)",
        "description": "Libro **solo agregar** (sección 4.3): no se edita ni se borra; un error se corrige con una `anulacion` (contraasiento: `anula_a`, mismo monto con origen y destino invertidos y `motivo`). Hay que poder escribir en cada libro que toca (`fin_puede`) y siempre a nombre propio. `registrado_en` es **obligatorio** (cuándo se capturó; si faltara, cada reenvío sería distinto). No mandes `recibido_en`, `libro_origen_id` ni `libro_destino_id`: los pone el servidor (sin permiso de columna, 42501). En el libro de Papá (`representado`) **todo** movimiento, también una anulación, lleva `en_nombre_de` (su titular) y `motivo`; si falta alguno, 400 (23514, I3). El `motivo` (el del libro de Papá, el de una anulación, un ajuste o un movimiento en nombre de otra persona) necesita al menos 3 caracteres visibles: los espacios, tabuladores, saltos de línea, espacios Unicode y caracteres invisibles no cuentan (400, 23514, N2). Lo registra el albacea, que es vigente solo si sigue siendo adulto con Finanzas (I4); si no, escribe el suplente. Una salida del libro de Papá hacia cualquier otro libro, personal o compartido (`transferencia` o `pago_deuda`), deja además la entrada `finanzas.salida_libro_representado` en la bitácora, visible para quienes llevan el libro (un gasto de Papá a una cuenta de gasto del hogar no es una salida de libro). Un libro archivado (`fin_libros.activo` = `false`) rechaza los movimientos nuevos, y la cuenta maestra que no es la dueña no registra nada: en ambos casos 403 (42501). La anulación acepta cuentas de gasto o ingreso archivadas (se archivan con saldo); en activos y pasivos cerrados o archivados, no (500, 55000). Solo `transferencia` y `pago_deuda` (y su anulación) cruzan de un libro a otro. Reenviar el mismo `id` con el mismo contenido no hace nada (0 filas, sin error); con otro contenido, 409 (23505). GRAVITY nunca llama esta operación por su cuenta: la persona confirma en la hoja de registro (D3).",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/alConflicto"
          },
          {
            "$ref": "#/components/parameters/preferirAlSubir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "allOf": [
                  {
                    "$ref": "#/components/schemas/FinMovimiento"
                  },
                  {
                    "required": [
                      "id",
                      "hogar_id",
                      "tipo",
                      "fecha",
                      "registrado_en",
                      "cuenta_origen_id",
                      "cuenta_destino_id",
                      "monto_centavos"
                    ]
                  }
                ]
              },
              "examples": {
                "gasto": {
                  "summary": "Gasto con la tarjeta del banco ($123.50)",
                  "value": {
                    "id": "3d0c2f5e-8a41-4b7e-9c1d-5f2a6b8e9a01",
                    "hogar_id": "b0000000-0000-4000-8000-000000000001",
                    "tipo": "gasto",
                    "fecha": "2026-10-21",
                    "registrado_en": "2026-10-21T19:42:10-06:00",
                    "cuenta_origen_id": "c3000000-0000-4000-8000-000000000001",
                    "cuenta_destino_id": "c2000000-0000-4000-8000-000000000003",
                    "monto_centavos": 12350,
                    "categoria_id": "c1000000-0000-4000-8000-000000000012",
                    "via": "manual",
                    "nota": "Mercado (ejemplo)"
                  }
                },
                "anulacion": {
                  "summary": "Anulación del gasto anterior (contraasiento)",
                  "value": {
                    "id": "3d0c2f5e-8a41-4b7e-9c1d-5f2a6b8e9a02",
                    "hogar_id": "b0000000-0000-4000-8000-000000000001",
                    "tipo": "anulacion",
                    "fecha": "2026-10-21",
                    "registrado_en": "2026-10-21T19:43:00-06:00",
                    "cuenta_origen_id": "c2000000-0000-4000-8000-000000000003",
                    "cuenta_destino_id": "c3000000-0000-4000-8000-000000000001",
                    "monto_centavos": 12350,
                    "anula_a": "3d0c2f5e-8a41-4b7e-9c1d-5f2a6b8e9a01",
                    "motivo": "Deshecho al capturar"
                  }
                },
                "albacea": {
                  "summary": "La albacea paga la luz en nombre de Papá",
                  "value": {
                    "id": "3d0c2f5e-8a41-4b7e-9c1d-5f2a6b8e9a03",
                    "hogar_id": "b0000000-0000-4000-8000-000000000001",
                    "tipo": "gasto",
                    "fecha": "2026-10-20",
                    "registrado_en": "2026-10-20T10:05:00-06:00",
                    "cuenta_origen_id": "c3000000-0000-4000-8000-000000000030",
                    "cuenta_destino_id": "c2000000-0000-4000-8000-000000000005",
                    "monto_centavos": 48000,
                    "en_nombre_de": "e0000000-0000-4000-8000-000000000009",
                    "motivo": "Recibo de luz de Papá (ejemplo)"
                  }
                },
                "salida": {
                  "summary": "Salida del libro de Papá a un libro personal (queda en la bitácora)",
                  "value": {
                    "id": "3d0c2f5e-8a41-4b7e-9c1d-5f2a6b8e9a05",
                    "hogar_id": "b0000000-0000-4000-8000-000000000001",
                    "tipo": "transferencia",
                    "fecha": "2026-10-21",
                    "registrado_en": "2026-10-21T11:20:00-06:00",
                    "cuenta_origen_id": "c3000000-0000-4000-8000-000000000030",
                    "cuenta_destino_id": "c3000000-0000-4000-8000-000000000001",
                    "monto_centavos": 150000,
                    "en_nombre_de": "e0000000-0000-4000-8000-000000000009",
                    "motivo": "Reembolso de la farmacia de Papá (ejemplo)"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "201": {
            "$ref": "#/components/responses/Agregado"
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          },
          "500": {
            "$ref": "#/components/responses/EstadoFinanzas"
          }
        }
      }
    },
    "/rest/v1/fin_ingresos": {
      "get": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "leerIngresos",
        "summary": "Leer ingresos recurrentes",
        "description": "Ingresos de cada libro por persona (sueldo, pensión…). Los extras no se configuran: son movimientos `ingreso`. La cuenta maestra ve vacío el libro de otra persona mientras no tenga una consulta vigente (`fin_registrar_consulta_maestra`, 30 minutos): no da error, no devuelve filas.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/select"
          },
          {
            "$ref": "#/components/parameters/filtroId"
          },
          {
            "$ref": "#/components/parameters/filtroHogar"
          },
          {
            "$ref": "#/components/parameters/filtroLibro"
          }
        ],
        "responses": {
          "200": {
            "description": "Ingresos visibles.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/FinIngreso"
                  }
                }
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      },
      "post": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "agregarIngreso",
        "summary": "Agregar un ingreso recurrente",
        "description": "Quien administra el libro. El monto y el calendario van en `fin_vigencias_ingreso`.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/alConflicto"
          },
          {
            "$ref": "#/components/parameters/preferirAlSubir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "allOf": [
                  {
                    "$ref": "#/components/schemas/FinIngreso"
                  },
                  {
                    "required": [
                      "id",
                      "hogar_id",
                      "libro_id",
                      "persona_id",
                      "nombre"
                    ]
                  }
                ]
              },
              "examples": {
                "pension": {
                  "summary": "Pensión de Papá (ejemplo)",
                  "value": {
                    "id": "1a000000-0000-4000-8000-000000000001",
                    "hogar_id": "b0000000-0000-4000-8000-000000000001",
                    "libro_id": "f1000000-0000-4000-8000-000000000002",
                    "persona_id": "e0000000-0000-4000-8000-000000000009",
                    "nombre": "Pensión (ejemplo)",
                    "tipo": "pension",
                    "certeza": "segura"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "201": {
            "$ref": "#/components/responses/Agregado"
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          }
        }
      },
      "patch": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "cambiarIngreso",
        "summary": "Cambiar un ingreso recurrente",
        "description": "Nombre, cuentas, certeza o `activo`. Un cambio de monto no va aquí: crea una vigencia nueva.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/filtroIdObligatorio"
          },
          {
            "$ref": "#/components/parameters/preferir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "allOf": [
                  {
                    "$ref": "#/components/schemas/FinIngreso"
                  },
                  {
                    "minProperties": 1
                  }
                ]
              },
              "example": {
                "certeza": "probable"
              }
            }
          }
        },
        "responses": {
          "200": {
            "$ref": "#/components/responses/Actualizado"
          },
          "204": {
            "description": "Actualizado (sin cuerpo)."
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          }
        }
      }
    },
    "/rest/v1/fin_vigencias_ingreso": {
      "get": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "leerVigenciasIngreso",
        "summary": "Leer vigencias de ingresos",
        "description": "Monto neto y calendario de cada ingreso por periodo. La cuenta maestra ve vacío el libro de otra persona mientras no tenga una consulta vigente (`fin_registrar_consulta_maestra`, 30 minutos): no da error, no devuelve filas.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/select"
          },
          {
            "$ref": "#/components/parameters/filtroId"
          },
          {
            "$ref": "#/components/parameters/filtroHogar"
          },
          {
            "$ref": "#/components/parameters/filtroLibro"
          }
        ],
        "responses": {
          "200": {
            "description": "Vigencias visibles.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/FinVigenciaIngreso"
                  }
                }
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      },
      "post": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "agregarVigenciaIngreso",
        "summary": "Agregar una vigencia (monto y calendario)",
        "description": "Un cambio de neto crea una vigencia nueva y cierra `hasta` en la anterior; no se traslapan (22023). `libro_id` lo toma el servidor del ingreso. Pensión de Papá: `mensual` con `dias_mes` `[1, 11]` y `siguiente_dia_habil`; apoyo 60+: `cada_meses` con `intervalo_meses` 2.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/alConflicto"
          },
          {
            "$ref": "#/components/parameters/preferirAlSubir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "allOf": [
                  {
                    "$ref": "#/components/schemas/FinVigenciaIngreso"
                  },
                  {
                    "required": [
                      "id",
                      "hogar_id",
                      "ingreso_id",
                      "monto_neto_centavos",
                      "forma",
                      "desde"
                    ]
                  }
                ]
              },
              "examples": {
                "pension": {
                  "summary": "Pensión los días 1 y 11 (monto inventado)",
                  "value": {
                    "id": "1b000000-0000-4000-8000-000000000001",
                    "hogar_id": "b0000000-0000-4000-8000-000000000001",
                    "libro_id": "f1000000-0000-4000-8000-000000000002",
                    "ingreso_id": "1a000000-0000-4000-8000-000000000001",
                    "monto_neto_centavos": 350000,
                    "forma": "mensual",
                    "dias_mes": [
                      1,
                      11
                    ],
                    "regla_inhabil": "siguiente_dia_habil",
                    "desde": "2026-10-01"
                  }
                },
                "apoyo": {
                  "summary": "Apoyo 60+ cada bimestre (monto inventado)",
                  "value": {
                    "id": "1b000000-0000-4000-8000-000000000002",
                    "hogar_id": "b0000000-0000-4000-8000-000000000001",
                    "libro_id": "f1000000-0000-4000-8000-000000000002",
                    "ingreso_id": "1a000000-0000-4000-8000-000000000002",
                    "monto_neto_centavos": 620000,
                    "forma": "cada_meses",
                    "fecha_ancla": "2026-11-03",
                    "intervalo_meses": 2,
                    "regla_inhabil": "siguiente_dia_habil",
                    "desde": "2026-11-01"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "201": {
            "$ref": "#/components/responses/Agregado"
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          }
        }
      },
      "patch": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "cambiarVigenciaIngreso",
        "summary": "Cerrar o corregir una vigencia",
        "description": "Lo normal es cerrar `hasta` al crear la vigencia siguiente. `ingreso_id` y `libro_id` no cambian (42501).",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/filtroIdObligatorio"
          },
          {
            "$ref": "#/components/parameters/preferir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "allOf": [
                  {
                    "$ref": "#/components/schemas/FinVigenciaIngreso"
                  },
                  {
                    "minProperties": 1
                  }
                ]
              },
              "example": {
                "hasta": "2026-12-31"
              }
            }
          }
        },
        "responses": {
          "200": {
            "$ref": "#/components/responses/Actualizado"
          },
          "204": {
            "description": "Actualizado (sin cuerpo)."
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          }
        }
      }
    },
    "/rest/v1/fin_compromisos": {
      "get": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "leerCompromisos",
        "summary": "Leer compromisos (fijos y reservas)",
        "description": "Renta, servicios y reservas (placas, predial) de cada libro, con su frecuencia y su regla de día inhábil. La cuenta maestra ve vacío el libro de otra persona mientras no tenga una consulta vigente (`fin_registrar_consulta_maestra`, 30 minutos): no da error, no devuelve filas.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/select"
          },
          {
            "$ref": "#/components/parameters/filtroId"
          },
          {
            "$ref": "#/components/parameters/filtroHogar"
          },
          {
            "$ref": "#/components/parameters/filtroLibro"
          }
        ],
        "responses": {
          "200": {
            "description": "Compromisos visibles.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/FinCompromiso"
                  }
                }
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      },
      "post": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "agregarCompromiso",
        "summary": "Agregar un compromiso",
        "description": "Su cuenta es una cuenta de gasto del hogar. `regla_inhabil` por omisión `sin_cambio` (D19, regla 5: solo la caja pasa al siguiente día hábil).",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/alConflicto"
          },
          {
            "$ref": "#/components/parameters/preferirAlSubir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "allOf": [
                  {
                    "$ref": "#/components/schemas/FinCompromiso"
                  },
                  {
                    "required": [
                      "id",
                      "hogar_id",
                      "libro_id",
                      "nombre",
                      "tipo",
                      "monto_centavos",
                      "frecuencia"
                    ]
                  }
                ]
              },
              "examples": {
                "renta": {
                  "summary": "Renta mensual del libro compartido (monto inventado)",
                  "value": {
                    "id": "1c000000-0000-4000-8000-000000000001",
                    "hogar_id": "b0000000-0000-4000-8000-000000000001",
                    "libro_id": "f1000000-0000-4000-8000-000000000001",
                    "nombre": "Renta (ejemplo)",
                    "tipo": "fija",
                    "cuenta_gasto_id": "c2000000-0000-4000-8000-000000000001",
                    "monto_centavos": 800000,
                    "frecuencia": "mensual",
                    "forma": "mensual",
                    "dias_mes": [
                      1
                    ],
                    "protegida": true
                  }
                }
              }
            }
          }
        },
        "responses": {
          "201": {
            "$ref": "#/components/responses/Agregado"
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          }
        }
      },
      "patch": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "cambiarCompromiso",
        "summary": "Cambiar un compromiso",
        "description": "Monto, calendario, protección, prioridad o `activo`. Las ocurrencias que siguen `esperada` se regeneran.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/filtroIdObligatorio"
          },
          {
            "$ref": "#/components/parameters/preferir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "allOf": [
                  {
                    "$ref": "#/components/schemas/FinCompromiso"
                  },
                  {
                    "minProperties": 1
                  }
                ]
              },
              "example": {
                "activo": false
              }
            }
          }
        },
        "responses": {
          "200": {
            "$ref": "#/components/responses/Actualizado"
          },
          "204": {
            "description": "Actualizado (sin cuerpo)."
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          }
        }
      }
    },
    "/rest/v1/fin_sobres": {
      "get": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "leerSobres",
        "summary": "Leer sobres (partidas variables)",
        "description": "Partidas variables por rubro del presupuesto de cada libro. La cuenta maestra ve vacío el libro de otra persona mientras no tenga una consulta vigente (`fin_registrar_consulta_maestra`, 30 minutos): no da error, no devuelve filas.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/select"
          },
          {
            "$ref": "#/components/parameters/filtroId"
          },
          {
            "$ref": "#/components/parameters/filtroHogar"
          },
          {
            "$ref": "#/components/parameters/filtroLibro"
          }
        ],
        "responses": {
          "200": {
            "description": "Sobres visibles.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/FinSobre"
                  }
                }
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      },
      "post": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "agregarSobre",
        "summary": "Agregar un sobre",
        "description": "Monto semanal en centavos; `piso_minimo_centavos` entre 0 y el monto semanal.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/alConflicto"
          },
          {
            "$ref": "#/components/parameters/preferirAlSubir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "allOf": [
                  {
                    "$ref": "#/components/schemas/FinSobre"
                  },
                  {
                    "required": [
                      "id",
                      "hogar_id",
                      "libro_id",
                      "cuenta_gasto_id",
                      "nombre",
                      "monto_semanal_centavos"
                    ]
                  }
                ]
              },
              "examples": {
                "super": {
                  "summary": "Súper semanal (monto inventado)",
                  "value": {
                    "id": "1d000000-0000-4000-8000-000000000001",
                    "hogar_id": "b0000000-0000-4000-8000-000000000001",
                    "libro_id": "f1000000-0000-4000-8000-000000000001",
                    "cuenta_gasto_id": "c2000000-0000-4000-8000-000000000003",
                    "nombre": "Súper",
                    "monto_semanal_centavos": 150000,
                    "prioridad": "necesario"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "201": {
            "$ref": "#/components/responses/Agregado"
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          }
        }
      },
      "patch": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "cambiarSobre",
        "summary": "Cambiar un sobre",
        "description": "Monto, protección, prioridad, piso, modo de arrastre o `activo`.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/filtroIdObligatorio"
          },
          {
            "$ref": "#/components/parameters/preferir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "allOf": [
                  {
                    "$ref": "#/components/schemas/FinSobre"
                  },
                  {
                    "minProperties": 1
                  }
                ]
              },
              "example": {
                "monto_semanal_centavos": 140000
              }
            }
          }
        },
        "responses": {
          "200": {
            "$ref": "#/components/responses/Actualizado"
          },
          "204": {
            "description": "Actualizado (sin cuerpo)."
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          }
        }
      }
    },
    "/rest/v1/fin_deudas": {
      "get": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "leerDeudas",
        "summary": "Leer deudas",
        "description": "Deudas de cada libro; el saldo sale del libro (cuenta pasivo, `fin_v_saldos`). La cuenta maestra ve vacío el libro de otra persona mientras no tenga una consulta vigente (`fin_registrar_consulta_maestra`, 30 minutos): no da error, no devuelve filas.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/select"
          },
          {
            "$ref": "#/components/parameters/filtroId"
          },
          {
            "$ref": "#/components/parameters/filtroHogar"
          },
          {
            "$ref": "#/components/parameters/filtroLibro"
          }
        ],
        "responses": {
          "200": {
            "description": "Deudas visibles.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/FinDeuda"
                  }
                }
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      },
      "post": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "agregarDeuda",
        "summary": "Agregar una deuda",
        "description": "Cuenta pasivo del mismo libro. Tasa en puntos base: mayor que 0 solo en `con_costo` (23514). `grupo_prioritario` y `orden_grupo` van juntos (P12: el grupo que elige el titular).",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/alConflicto"
          },
          {
            "$ref": "#/components/parameters/preferirAlSubir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "allOf": [
                  {
                    "$ref": "#/components/schemas/FinDeuda"
                  },
                  {
                    "required": [
                      "id",
                      "hogar_id",
                      "libro_id",
                      "nombre",
                      "tipo",
                      "cuenta_pasivo_id",
                      "abono_centavos",
                      "frecuencia"
                    ]
                  }
                ]
              },
              "examples": {
                "tarjeta": {
                  "summary": "Tarjeta con costo en el grupo prioritario (cifras inventadas)",
                  "value": {
                    "id": "1e000000-0000-4000-8000-000000000001",
                    "hogar_id": "b0000000-0000-4000-8000-000000000001",
                    "libro_id": "f1000000-0000-4000-8000-000000000001",
                    "nombre": "Tarjeta de la casa (ejemplo)",
                    "tipo": "con_costo",
                    "cuenta_pasivo_id": "c3000000-0000-4000-8000-000000000021",
                    "abono_centavos": 39231,
                    "frecuencia": "semanal",
                    "minimo_centavos": 25000,
                    "tasa_anual_pb": 4800,
                    "grupo_prioritario": true,
                    "orden_grupo": 1
                  }
                }
              }
            }
          }
        },
        "responses": {
          "201": {
            "$ref": "#/components/responses/Agregado"
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          }
        }
      },
      "patch": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "cambiarDeuda",
        "summary": "Cambiar una deuda",
        "description": "Abono, calendario, mínimo, tasa, prioridad, grupo prioritario o `activa`.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/filtroIdObligatorio"
          },
          {
            "$ref": "#/components/parameters/preferir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "allOf": [
                  {
                    "$ref": "#/components/schemas/FinDeuda"
                  },
                  {
                    "minProperties": 1
                  }
                ]
              },
              "example": {
                "orden_grupo": 2
              }
            }
          }
        },
        "responses": {
          "200": {
            "$ref": "#/components/responses/Actualizado"
          },
          "204": {
            "description": "Actualizado (sin cuerpo)."
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          }
        }
      }
    },
    "/rest/v1/fin_dias_inhabiles": {
      "get": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "leerDiasInhabiles",
        "summary": "Leer días inhábiles",
        "description": "Calendario del hogar: festivos oficiales (LFT art. 74) y días propios.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/select"
          },
          {
            "$ref": "#/components/parameters/filtroId"
          },
          {
            "$ref": "#/components/parameters/filtroHogar"
          },
          {
            "$ref": "#/components/parameters/filtroFecha"
          }
        ],
        "responses": {
          "200": {
            "description": "Días inhábiles del hogar.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/FinDiaInhabil"
                  }
                }
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      },
      "post": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "agregarDiaInhabil",
        "summary": "Agregar un día inhábil",
        "description": "La precarga de festivos nace inactiva: el dueño la revisa y la activa. Único por (`hogar_id`, `fecha`). Es configuración del hogar (M6): la hacen el dueño y la pareja; la cuenta maestra que no es la dueña no la cambia (403, 42501).",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/alConflicto"
          },
          {
            "$ref": "#/components/parameters/preferirAlSubir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "allOf": [
                  {
                    "$ref": "#/components/schemas/FinDiaInhabil"
                  },
                  {
                    "required": [
                      "id",
                      "hogar_id",
                      "fecha",
                      "nombre"
                    ]
                  }
                ]
              },
              "examples": {
                "festivo": {
                  "summary": "Festivo oficial por revisar",
                  "value": {
                    "id": "1f000000-0000-4000-8000-000000000001",
                    "hogar_id": "b0000000-0000-4000-8000-000000000001",
                    "fecha": "2026-11-16",
                    "nombre": "Día de la Revolución (tercer lunes de noviembre)",
                    "tipo": "festivo_oficial",
                    "fuente": "LFT art. 74",
                    "activo": false
                  }
                }
              }
            }
          }
        },
        "responses": {
          "201": {
            "$ref": "#/components/responses/Agregado"
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          }
        }
      },
      "patch": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "cambiarDiaInhabil",
        "summary": "Activar o cambiar un día inhábil",
        "description": "Al cambiar `activo`, el servidor pone `revisado_por` y `revisado_en`. Es configuración del hogar (M6): la hacen el dueño y la pareja; la cuenta maestra que no es la dueña no la cambia (403, 42501).",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/filtroIdObligatorio"
          },
          {
            "$ref": "#/components/parameters/preferir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "allOf": [
                  {
                    "$ref": "#/components/schemas/FinDiaInhabil"
                  },
                  {
                    "minProperties": 1
                  }
                ]
              },
              "example": {
                "activo": true
              }
            }
          }
        },
        "responses": {
          "200": {
            "$ref": "#/components/responses/Actualizado"
          },
          "204": {
            "description": "Actualizado (sin cuerpo)."
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          }
        }
      }
    },
    "/rest/v1/fin_semanas": {
      "get": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "leerSemanas",
        "summary": "Leer semanas del plan",
        "description": "Foto del plan de cada semana (lunes) por libro, con la cascada ingreso → presupuesto → deuda → remanente. La cuenta maestra ve vacío el libro de otra persona mientras no tenga una consulta vigente (`fin_registrar_consulta_maestra`, 30 minutos): no da error, no devuelve filas.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/select"
          },
          {
            "$ref": "#/components/parameters/filtroId"
          },
          {
            "$ref": "#/components/parameters/filtroHogar"
          },
          {
            "$ref": "#/components/parameters/filtroLibro"
          },
          {
            "$ref": "#/components/parameters/filtroSemanaInicio"
          }
        ],
        "responses": {
          "200": {
            "description": "Semanas visibles.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/FinSemana"
                  }
                }
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      },
      "post": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "agregarSemana",
        "summary": "Armar una semana",
        "description": "`semana_inicio` es lunes (23514). Única por (`libro_id`, `semana_inicio`). La cascada cuadra: `remanente_plan = ingreso − presupuesto − deuda_plan` (23514). `activada_por`, `activada_en` y `reaperturas` los pone el servidor.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/alConflicto"
          },
          {
            "$ref": "#/components/parameters/preferirAlSubir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "allOf": [
                  {
                    "$ref": "#/components/schemas/FinSemana"
                  },
                  {
                    "required": [
                      "id",
                      "hogar_id",
                      "libro_id",
                      "semana_inicio"
                    ]
                  }
                ]
              },
              "examples": {
                "activa": {
                  "summary": "Semana del 19/oct (ejemplo 5.6 bis-1)",
                  "value": {
                    "id": "2a000000-0000-4000-8000-000000000001",
                    "hogar_id": "b0000000-0000-4000-8000-000000000001",
                    "libro_id": "f1000000-0000-4000-8000-000000000001",
                    "semana_inicio": "2026-10-19",
                    "estado": "activa",
                    "ingreso": 738462,
                    "presupuesto": 547231,
                    "deuda_plan": 39231,
                    "remanente_plan": 152000,
                    "meta_remanente_pb": 2000,
                    "techo": 551539
                  }
                }
              }
            }
          }
        },
        "responses": {
          "201": {
            "$ref": "#/components/responses/Agregado"
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          },
          "500": {
            "$ref": "#/components/responses/EstadoFinanzas"
          }
        }
      },
      "patch": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "cambiarSemana",
        "summary": "Cambiar el plan o el estado de una semana",
        "description": "Solo mientras no esté `cerrada` (55000). Para cerrarla se guarda antes el cierre (`fin_cierres`, versión `reaperturas + 1`); reabrir es cambiar solo `estado` (a `activa`, `pendiente_ingreso` o `por_cerrar`), y queda en la bitácora.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/filtroIdObligatorio"
          },
          {
            "$ref": "#/components/parameters/preferir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "allOf": [
                  {
                    "$ref": "#/components/schemas/FinSemana"
                  },
                  {
                    "minProperties": 1
                  }
                ]
              },
              "example": {
                "estado": "por_cerrar"
              }
            }
          }
        },
        "responses": {
          "200": {
            "$ref": "#/components/responses/Actualizado"
          },
          "204": {
            "description": "Actualizado (sin cuerpo)."
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          },
          "500": {
            "$ref": "#/components/responses/EstadoFinanzas"
          }
        }
      }
    },
    "/rest/v1/fin_partidas_semana": {
      "get": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "leerPartidasSemana",
        "summary": "Leer partidas de la semana",
        "description": "Lo asignado a cada compromiso y sobre en la semana, ya repartido por mayor resto. La cuenta maestra ve vacío el libro de otra persona mientras no tenga una consulta vigente (`fin_registrar_consulta_maestra`, 30 minutos): no da error, no devuelve filas.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/select"
          },
          {
            "$ref": "#/components/parameters/filtroHogar"
          },
          {
            "$ref": "#/components/parameters/filtroLibro"
          },
          {
            "$ref": "#/components/parameters/filtroSemana"
          }
        ],
        "responses": {
          "200": {
            "description": "Partidas visibles.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/FinPartidaSemana"
                  }
                }
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      },
      "post": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "agregarPartidaSemana",
        "summary": "Agregar una partida a la semana",
        "description": "Una por origen en cada semana. No se agrega en una semana cerrada (55000).",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/alConflicto"
          },
          {
            "$ref": "#/components/parameters/preferirAlSubir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "allOf": [
                  {
                    "$ref": "#/components/schemas/FinPartidaSemana"
                  },
                  {
                    "required": [
                      "id",
                      "hogar_id",
                      "semana_id",
                      "origen",
                      "origen_id",
                      "tipo",
                      "asignado"
                    ]
                  }
                ]
              }
            }
          }
        },
        "responses": {
          "201": {
            "$ref": "#/components/responses/Agregado"
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          },
          "500": {
            "$ref": "#/components/responses/EstadoFinanzas"
          }
        }
      },
      "patch": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "cambiarPartidaSemana",
        "summary": "Cambiar una partida de la semana",
        "description": "Solo mientras la semana no esté cerrada (55000).",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/filtroIdObligatorio"
          },
          {
            "$ref": "#/components/parameters/preferir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "allOf": [
                  {
                    "$ref": "#/components/schemas/FinPartidaSemana"
                  },
                  {
                    "minProperties": 1
                  }
                ]
              },
              "example": {
                "asignado": 140000
              }
            }
          }
        },
        "responses": {
          "200": {
            "$ref": "#/components/responses/Actualizado"
          },
          "204": {
            "description": "Actualizado (sin cuerpo)."
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          },
          "500": {
            "$ref": "#/components/responses/EstadoFinanzas"
          }
        }
      }
    },
    "/rest/v1/fin_abonos_semana": {
      "get": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "leerAbonosSemana",
        "summary": "Leer abonos planeados",
        "description": "Abono planeado, mínimo y extra de cada deuda en la semana. La cuenta maestra ve vacío el libro de otra persona mientras no tenga una consulta vigente (`fin_registrar_consulta_maestra`, 30 minutos): no da error, no devuelve filas.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/select"
          },
          {
            "$ref": "#/components/parameters/filtroHogar"
          },
          {
            "$ref": "#/components/parameters/filtroLibro"
          },
          {
            "$ref": "#/components/parameters/filtroSemana"
          }
        ],
        "responses": {
          "200": {
            "description": "Abonos visibles.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/FinAbonoSemana"
                  }
                }
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      },
      "post": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "agregarAbonoSemana",
        "summary": "Agregar un abono planeado",
        "description": "Uno por deuda en cada semana. No se agrega en una semana cerrada (55000).",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/alConflicto"
          },
          {
            "$ref": "#/components/parameters/preferirAlSubir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "allOf": [
                  {
                    "$ref": "#/components/schemas/FinAbonoSemana"
                  },
                  {
                    "required": [
                      "id",
                      "hogar_id",
                      "semana_id",
                      "deuda_id",
                      "abono_planeado"
                    ]
                  }
                ]
              }
            }
          }
        },
        "responses": {
          "201": {
            "$ref": "#/components/responses/Agregado"
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          },
          "500": {
            "$ref": "#/components/responses/EstadoFinanzas"
          }
        }
      },
      "patch": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "cambiarAbonoSemana",
        "summary": "Cambiar un abono planeado",
        "description": "Solo mientras la semana no esté cerrada (55000).",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/filtroIdObligatorio"
          },
          {
            "$ref": "#/components/parameters/preferir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "allOf": [
                  {
                    "$ref": "#/components/schemas/FinAbonoSemana"
                  },
                  {
                    "minProperties": 1
                  }
                ]
              },
              "example": {
                "extra_planeado": 10000
              }
            }
          }
        },
        "responses": {
          "200": {
            "$ref": "#/components/responses/Actualizado"
          },
          "204": {
            "description": "Actualizado (sin cuerpo)."
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          },
          "500": {
            "$ref": "#/components/responses/EstadoFinanzas"
          }
        }
      }
    },
    "/rest/v1/fin_ocurrencias": {
      "get": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "leerOcurrencias",
        "summary": "Leer ocurrencias (fechas esperadas)",
        "description": "Fechas esperadas de ingresos, compromisos y deudas (horizonte de 13 semanas), con la fecha ajustada por días inhábiles. La cuenta maestra ve vacío el libro de otra persona mientras no tenga una consulta vigente (`fin_registrar_consulta_maestra`, 30 minutos): no da error, no devuelve filas.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/select"
          },
          {
            "$ref": "#/components/parameters/filtroId"
          },
          {
            "$ref": "#/components/parameters/filtroHogar"
          },
          {
            "$ref": "#/components/parameters/filtroLibro"
          }
        ],
        "responses": {
          "200": {
            "description": "Ocurrencias visibles.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/FinOcurrencia"
                  }
                }
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      },
      "post": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "agregarOcurrencia",
        "summary": "Agregar una ocurrencia",
        "description": "Única por (`libro_id`, `origen`, `origen_id`, `fecha_programada`). En una semana cerrada no se agregan (55000).",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/alConflicto"
          },
          {
            "$ref": "#/components/parameters/preferirAlSubir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "allOf": [
                  {
                    "$ref": "#/components/schemas/FinOcurrencia"
                  },
                  {
                    "required": [
                      "id",
                      "hogar_id",
                      "libro_id",
                      "origen",
                      "origen_id",
                      "fecha_programada",
                      "fecha_ajustada",
                      "monto_esperado"
                    ]
                  }
                ]
              }
            }
          }
        },
        "responses": {
          "201": {
            "$ref": "#/components/responses/Agregado"
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          },
          "500": {
            "$ref": "#/components/responses/EstadoFinanzas"
          }
        }
      },
      "patch": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "cambiarOcurrencia",
        "summary": "Cambiar el estado de una ocurrencia",
        "description": "P. ej. `cumplida` con su `movimiento_id`, o `retrasada`. En una semana cerrada solo cambian el estado y el movimiento (un ingreso que llega tarde), no la fecha ni el monto (55000).",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/filtroIdObligatorio"
          },
          {
            "$ref": "#/components/parameters/preferir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "allOf": [
                  {
                    "$ref": "#/components/schemas/FinOcurrencia"
                  },
                  {
                    "minProperties": 1
                  }
                ]
              },
              "example": {
                "estado": "cumplida",
                "movimiento_id": "3d0c2f5e-8a41-4b7e-9c1d-5f2a6b8e9a04"
              }
            }
          }
        },
        "responses": {
          "200": {
            "$ref": "#/components/responses/Actualizado"
          },
          "204": {
            "description": "Actualizado (sin cuerpo)."
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          },
          "500": {
            "$ref": "#/components/responses/EstadoFinanzas"
          }
        }
      }
    },
    "/rest/v1/fin_cierres": {
      "get": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "leerCierres",
        "summary": "Leer cierres de semana",
        "description": "Fotos del cierre de cada semana y del balance; una por versión. La cuenta maestra ve vacío el libro de otra persona mientras no tenga una consulta vigente (`fin_registrar_consulta_maestra`, 30 minutos): no da error, no devuelve filas.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/select"
          },
          {
            "$ref": "#/components/parameters/filtroHogar"
          },
          {
            "$ref": "#/components/parameters/filtroLibro"
          },
          {
            "$ref": "#/components/parameters/filtroSemana"
          }
        ],
        "responses": {
          "200": {
            "description": "Cierres visibles.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/FinCierre"
                  }
                }
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      },
      "post": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "registrarCierre",
        "summary": "Guardar el cierre de una semana (solo agregar)",
        "description": "**Solo agregar.** `version` = reaperturas + 1 (la siguiente al reabrir); `patrimonio = activos − pasivos` (23514). Se guarda antes de cambiar la semana a `cerrada`, junto con sus partidas y abonos. Las correcciones posteriores no cambian una foto guardada.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/alConflicto"
          },
          {
            "$ref": "#/components/parameters/preferirAlSubir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "allOf": [
                  {
                    "$ref": "#/components/schemas/FinCierre"
                  },
                  {
                    "required": [
                      "id",
                      "hogar_id",
                      "semana_id",
                      "version",
                      "ingreso_real",
                      "gasto_real",
                      "activos",
                      "pasivos",
                      "patrimonio"
                    ]
                  }
                ]
              }
            }
          }
        },
        "responses": {
          "201": {
            "$ref": "#/components/responses/Agregado"
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          },
          "500": {
            "$ref": "#/components/responses/EstadoFinanzas"
          }
        }
      }
    },
    "/rest/v1/fin_cierre_partidas": {
      "get": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "leerCierrePartidas",
        "summary": "Leer partidas de un cierre",
        "description": "Lo gastado, el arrastre y lo que pasó al remanente de cada partida al cerrar. La cuenta maestra ve vacío el libro de otra persona mientras no tenga una consulta vigente (`fin_registrar_consulta_maestra`, 30 minutos): no da error, no devuelve filas.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/select"
          },
          {
            "$ref": "#/components/parameters/filtroHogar"
          },
          {
            "$ref": "#/components/parameters/filtroLibro"
          }
        ],
        "responses": {
          "200": {
            "description": "Partidas de cierres visibles.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/FinCierrePartida"
                  }
                }
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      },
      "post": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "registrarCierrePartida",
        "summary": "Guardar una partida del cierre (solo agregar)",
        "description": "**Solo agregar.** Una por partida en cada cierre.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/alConflicto"
          },
          {
            "$ref": "#/components/parameters/preferirAlSubir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "allOf": [
                  {
                    "$ref": "#/components/schemas/FinCierrePartida"
                  },
                  {
                    "required": [
                      "id",
                      "hogar_id",
                      "cierre_id",
                      "partida_id",
                      "gastado"
                    ]
                  }
                ]
              }
            }
          }
        },
        "responses": {
          "201": {
            "$ref": "#/components/responses/Agregado"
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          },
          "500": {
            "$ref": "#/components/responses/EstadoFinanzas"
          }
        }
      }
    },
    "/rest/v1/fin_cierre_abonos": {
      "get": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "leerCierreAbonos",
        "summary": "Leer abonos de un cierre",
        "description": "Abono planeado, real y mínimo de cada deuda al cerrar; `diferido` = planeado − real (generado). La cuenta maestra ve vacío el libro de otra persona mientras no tenga una consulta vigente (`fin_registrar_consulta_maestra`, 30 minutos): no da error, no devuelve filas.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/select"
          },
          {
            "$ref": "#/components/parameters/filtroHogar"
          },
          {
            "$ref": "#/components/parameters/filtroLibro"
          }
        ],
        "responses": {
          "200": {
            "description": "Abonos de cierres visibles.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/FinCierreAbono"
                  }
                }
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      },
      "post": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "registrarCierreAbono",
        "summary": "Guardar un abono del cierre (solo agregar)",
        "description": "**Solo agregar.** Uno por deuda en cada cierre. No mandes `diferido`: es generado.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/alConflicto"
          },
          {
            "$ref": "#/components/parameters/preferirAlSubir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "allOf": [
                  {
                    "$ref": "#/components/schemas/FinCierreAbono"
                  },
                  {
                    "required": [
                      "id",
                      "hogar_id",
                      "cierre_id",
                      "deuda_id",
                      "planeado",
                      "real"
                    ]
                  }
                ]
              }
            }
          }
        },
        "responses": {
          "201": {
            "$ref": "#/components/responses/Agregado"
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          },
          "500": {
            "$ref": "#/components/responses/EstadoFinanzas"
          }
        }
      }
    },
    "/rest/v1/fin_conciliaciones": {
      "get": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "leerConciliaciones",
        "summary": "Leer conciliaciones",
        "description": "Conciliaciones de saldo de las cuentas de tus libros. La cuenta maestra ve vacío el libro de otra persona mientras no tenga una consulta vigente (`fin_registrar_consulta_maestra`, 30 minutos): no da error, no devuelve filas.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/select"
          },
          {
            "$ref": "#/components/parameters/filtroId"
          },
          {
            "$ref": "#/components/parameters/filtroHogar"
          },
          {
            "$ref": "#/components/parameters/filtroLibro"
          }
        ],
        "responses": {
          "200": {
            "description": "Conciliaciones visibles.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/FinConciliacion"
                  }
                }
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      },
      "post": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "registrarConciliacion",
        "summary": "Registrar una conciliación (solo agregar)",
        "description": "**Solo agregar.** Si el saldo declarado difiere del calculado, primero se registra el movimiento de `ajuste` (contra la cuenta Ajustes del libro, mismo monto, fecha y dirección, con motivo) y luego la conciliación que lo referencia con `motivo` (22023 si no corresponde). El `motivo` de una conciliación con diferencia, como el del ajuste, necesita al menos 3 caracteres visibles (400, 23514, N2). `diferencia` es generada.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/alConflicto"
          },
          {
            "$ref": "#/components/parameters/preferirAlSubir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "allOf": [
                  {
                    "$ref": "#/components/schemas/FinConciliacion"
                  },
                  {
                    "required": [
                      "id",
                      "hogar_id",
                      "libro_id",
                      "cuenta_id",
                      "fecha",
                      "saldo_declarado",
                      "saldo_calculado"
                    ]
                  }
                ]
              }
            }
          }
        },
        "responses": {
          "201": {
            "$ref": "#/components/responses/Agregado"
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          },
          "500": {
            "$ref": "#/components/responses/EstadoFinanzas"
          }
        }
      }
    },
    "/rest/v1/fin_importaciones": {
      "get": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "leerImportaciones",
        "summary": "Leer importaciones",
        "description": "Registro de importaciones del hogar (p. ej. la hoja Categorías de los datos semilla).",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/select"
          },
          {
            "$ref": "#/components/parameters/filtroId"
          },
          {
            "$ref": "#/components/parameters/filtroHogar"
          }
        ],
        "responses": {
          "200": {
            "description": "Importaciones del hogar.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/FinImportacion"
                  }
                }
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      },
      "post": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "registrarImportacion",
        "summary": "Registrar una importación (solo agregar)",
        "description": "**Solo agregar.** `detalle` hasta 256 KB (no se copia a la bitácora). `filas_creadas + filas_omitidas` no pasa de `filas_leidas` (23514). Es configuración del hogar (M6): la hacen el dueño y la pareja; la cuenta maestra que no es la dueña no la cambia (403, 42501).",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/alConflicto"
          },
          {
            "$ref": "#/components/parameters/preferirAlSubir"
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "allOf": [
                  {
                    "$ref": "#/components/schemas/FinImportacion"
                  },
                  {
                    "required": [
                      "id",
                      "hogar_id",
                      "archivo"
                    ]
                  }
                ]
              }
            }
          }
        },
        "responses": {
          "201": {
            "$ref": "#/components/responses/Agregado"
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          },
          "409": {
            "$ref": "#/components/responses/ConflictoFinanzas"
          }
        }
      }
    },
    "/rest/v1/fin_v_saldos": {
      "get": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "leerSaldos",
        "summary": "Leer saldos por cuenta (vista)",
        "description": "Saldo confirmado por cuenta con el signo de su clase (en una tarjeta, lo que se debe) y el saldo con pendientes. Las cuentas de gasto del hogar salen una vez por libro. Respeta la RLS de quien consulta (`security_invoker`). La cuenta maestra ve vacío el libro de otra persona mientras no tenga una consulta vigente (`fin_registrar_consulta_maestra`, 30 minutos): no da error, no devuelve filas.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/select"
          },
          {
            "$ref": "#/components/parameters/filtroHogar"
          },
          {
            "$ref": "#/components/parameters/filtroLibro"
          }
        ],
        "responses": {
          "200": {
            "description": "Saldos de las cuentas visibles.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/FinSaldo"
                  }
                }
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      }
    },
    "/rest/v1/fin_v_gasto_semana": {
      "get": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "leerGastoSemana",
        "summary": "Leer gasto por semana (vista)",
        "description": "Gasto neto confirmado por libro, cuenta de gasto y semana (lunes): gastos − reembolsos ± anulaciones y reclasificaciones, por la fecha económica. Respeta la RLS de quien consulta. La cuenta maestra ve vacío el libro de otra persona mientras no tenga una consulta vigente (`fin_registrar_consulta_maestra`, 30 minutos): no da error, no devuelve filas.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 1,
        "parameters": [
          {
            "$ref": "#/components/parameters/select"
          },
          {
            "$ref": "#/components/parameters/filtroHogar"
          },
          {
            "$ref": "#/components/parameters/filtroLibro"
          },
          {
            "$ref": "#/components/parameters/filtroSemanaInicio"
          }
        ],
        "responses": {
          "200": {
            "description": "Gasto por semana de los libros visibles.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/FinGastoSemana"
                  }
                }
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      }
    },
    "/rest/v1/rpc/fin_puede": {
      "post": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "finPuede",
        "summary": "¿Puedo leer, escribir o administrar este libro?",
        "description": "La regla de las tablas de cada libro (D19). `leer`: miembro vigente; la cuenta maestra, solo con una consulta registrada en ese libro en los últimos 30 minutos (I2, también si es público); y, en un compartido `publica`, todo adulto con Finanzas del hogar. `escribir`: titular, miembro o albacea (el suplente solo si no hay albacea vigente; el albacea es vigente solo si sigue siendo adulto con Finanzas, I4), con el libro activo (archivado = solo lectura). `administrar`: titular de un personal, miembro de un compartido (si está archivado, solo quien lo creó, para reactivarlo), albacea de un representado. La cuenta maestra que no es la dueña nunca escribe ni administra, en ningún libro. Siempre exige un rol con Finanzas: a familiar, cuidador y Casa les responde `false`.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 1,
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "p_libro_id",
                  "p_accion"
                ],
                "properties": {
                  "p_libro_id": {
                    "$ref": "#/components/schemas/Uuid"
                  },
                  "p_accion": {
                    "$ref": "#/components/schemas/Accion"
                  }
                }
              },
              "example": {
                "p_libro_id": "f1000000-0000-4000-8000-000000000001",
                "p_accion": "escribir"
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Si puede.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "boolean"
                },
                "example": true
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      }
    },
    "/rest/v1/rpc/fin_puede_hogar": {
      "post": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "finPuedeHogar",
        "summary": "¿Puedo usar lo de Finanzas del hogar?",
        "description": "La regla de lo que es del hogar (categorías, cuentas de gasto, días inhábiles, importaciones): el rol tiene Finanzas para esa acción; la cuenta maestra además lee (sin consulta: es la portada). Si la cuenta maestra no es la dueña, `escribir` y `administrar` responden `false`: no escribe ni cambia nada del hogar (M6). Es de solo lectura total (D19, 23/oct); el dueño y la pareja sí escriben. A familiar, cuidador y Casa les responde `false`.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 1,
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "p_hogar_id",
                  "p_accion"
                ],
                "properties": {
                  "p_hogar_id": {
                    "$ref": "#/components/schemas/Uuid"
                  },
                  "p_accion": {
                    "$ref": "#/components/schemas/Accion"
                  }
                }
              },
              "example": {
                "p_hogar_id": "b0000000-0000-4000-8000-000000000001",
                "p_accion": "leer"
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Si puede.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "boolean"
                },
                "example": true
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      }
    },
    "/rest/v1/rpc/fin_es_miembro": {
      "post": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "finEsMiembro",
        "summary": "¿Soy miembro de este libro?",
        "description": "Miembro vigente del libro con cualquier papel (titular, miembro, albacea o suplente) y sigue en el hogar. La cuenta maestra no es miembro de lo ajeno: con esto la app decide si llamar `fin_registrar_consulta_maestra`.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 1,
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "p_libro_id"
                ],
                "properties": {
                  "p_libro_id": {
                    "$ref": "#/components/schemas/Uuid"
                  }
                }
              },
              "example": {
                "p_libro_id": "f1000000-0000-4000-8000-000000000002"
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Si es miembro.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "boolean"
                },
                "example": true
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      }
    },
    "/rest/v1/rpc/fin_solo_lectura": {
      "post": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "finSoloLectura",
        "summary": "¿Esta sesión es de solo lectura total en Finanzas?",
        "description": "Verdadero si la sesión es la cuenta maestra y no es la dueña (D19, 23/oct): en Finanzas solo lee, en cualquier libro y en lo del hogar. `fin_puede` y `fin_puede_hogar` de `escribir` y `administrar` le responden `false`; la app la usa para no mostrar (+), Anular ni asistentes. Al dueño (aunque sea además la maestra) y a los demás roles les responde `false`.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 1,
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "p_hogar_id"
                ],
                "properties": {
                  "p_hogar_id": {
                    "$ref": "#/components/schemas/Uuid"
                  }
                }
              },
              "example": {
                "p_hogar_id": "b0000000-0000-4000-8000-000000000001"
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Si la sesión es de solo lectura total.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "boolean"
                },
                "example": false
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      }
    },
    "/rest/v1/rpc/fin_puede_salir": {
      "post": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "finPuedeSalir",
        "summary": "¿Puedo salirme de este libro compartido?",
        "description": "Verdadero si la sesión es miembro vigente de este libro compartido (con un rol vigente en el hogar): puede cerrar su propia participación con un `PATCH` a su fila de `fin_libro_miembros` (`hasta` = ahora), siempre, también si el libro está archivado. En un libro personal o representado, y para quien no es miembro, responde `false`. Si es el último miembro vigente, la respuesta es `true` pero el servidor rechaza la salida (400, 22023): el libro no se queda sin nadie.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 1,
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "p_libro_id"
                ],
                "properties": {
                  "p_libro_id": {
                    "$ref": "#/components/schemas/Uuid"
                  }
                }
              },
              "example": {
                "p_libro_id": "f1000000-0000-4000-8000-000000000001"
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Si puede salirse.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "boolean"
                },
                "example": true
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      }
    },
    "/rest/v1/rpc/fin_adultos_con_finanzas": {
      "post": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "finAdultosConFinanzas",
        "summary": "Los adultos con Finanzas del hogar (para agregarlos a un compartido)",
        "description": "Dueño y coadministradores vigentes del hogar, con su nombre y su rol, para elegir a quién agregar a un libro compartido (`agregarMiembroLibro`). Nunca devuelve familiar, cuidador ni Casa, ni a Papá, ni la cuenta maestra que no es la dueña (es de solo lectura y no lleva libros). La ve cualquier adulto con Finanzas del hogar (incluida la maestra); a quien no lo es le devuelve cero filas, sin error. Incluye a la propia sesión. Ordenada por nombre.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 1,
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "p_hogar_id"
                ],
                "properties": {
                  "p_hogar_id": {
                    "$ref": "#/components/schemas/Uuid"
                  }
                }
              },
              "example": {
                "p_hogar_id": "b0000000-0000-4000-8000-000000000001"
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Adultos con Finanzas del hogar (vacío si quien consulta no lo es).",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "$ref": "#/components/schemas/FinAdultoConFinanzas"
                  }
                },
                "example": [
                  {
                    "persona_id": "e0000000-0000-4000-8000-000000000002",
                    "nombre_visible": "Alex Ejemplo",
                    "rol": "coadministrador"
                  },
                  {
                    "persona_id": "e0000000-0000-4000-8000-000000000001",
                    "nombre_visible": "Ana Ejemplo",
                    "rol": "dueno"
                  }
                ]
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      }
    },
    "/rest/v1/rpc/es_cuenta_maestra": {
      "post": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "esCuentaMaestra",
        "summary": "¿Esta sesión es la cuenta maestra?",
        "description": "Verdadero si quien consulta es la cuenta maestra vigente del hogar (D19) y su rol tiene Finanzas (dueño o coadministrador). Cualquier sesión la puede llamar; a las demás les responde `false`.",
        "x-roles": [
          "dueno",
          "coadministrador",
          "familiar",
          "cuidador",
          "casa"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 1,
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "p_hogar_id"
                ],
                "properties": {
                  "p_hogar_id": {
                    "$ref": "#/components/schemas/Uuid"
                  }
                }
              },
              "example": {
                "p_hogar_id": "b0000000-0000-4000-8000-000000000001"
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Si es la cuenta maestra.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "boolean"
                },
                "example": false
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      }
    },
    "/rest/v1/rpc/cuenta_maestra": {
      "post": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "cuentaMaestra",
        "summary": "¿Existe la cuenta maestra y de quién es?",
        "description": "Para Ajustes › Privacidad: cualquier miembro del hogar ve si existe la cuenta maestra y de quién es (D19). Lista vacía si no hay.",
        "x-roles": [
          "dueno",
          "coadministrador",
          "familiar",
          "cuidador",
          "casa"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 1,
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "p_hogar_id"
                ],
                "properties": {
                  "p_hogar_id": {
                    "$ref": "#/components/schemas/Uuid"
                  }
                }
              },
              "example": {
                "p_hogar_id": "b0000000-0000-4000-8000-000000000001"
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "La cuenta maestra del hogar (o ninguna).",
            "content": {
              "application/json": {
                "schema": {
                  "type": "array",
                  "items": {
                    "type": "object",
                    "properties": {
                      "persona_id": {
                        "$ref": "#/components/schemas/Uuid"
                      },
                      "nombre_visible": {
                        "type": "string"
                      }
                    }
                  }
                },
                "example": [
                  {
                    "persona_id": "e0000000-0000-4000-8000-000000000008",
                    "nombre_visible": "Marta Maestra"
                  }
                ]
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      }
    },
    "/rest/v1/rpc/asignar_cuenta_maestra": {
      "post": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "asignarCuentaMaestra",
        "summary": "Nombrar o quitar la cuenta maestra",
        "description": "Solo el dueño (42501). Nombra la cuenta maestra del hogar: un miembro vigente con rol dueño o coadministrador (si no, 22023); nunca familiar, cuidador ni Casa. Con `p_persona_id` nulo la quita. Una sola por hogar. Puede ser el propio dueño (con su persona: en lo suyo sigue escribiendo) o un coadministrador vigente que no lleve libro propio; a uno que sí lo lleva lo rechaza con 400 (22023: \"invita a otra persona como cuenta maestra, o nómbrate tú\"). Lo normal es invitarla con `crearInvitacion` y `p_es_maestra: true` (otra persona con su propio login, sin libro personal); si no es la dueña, es de solo lectura total. Si cambia quién es, deja la entrada `finanzas.maestra_asignada` (en `detalle`, `anterior_persona_id` y `nueva_persona_id`), que ve todo adulto con Finanzas (M10), además de la de membresías, que solo ve el dueño.",
        "x-roles": [
          "dueno"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "p_hogar_id",
                  "p_persona_id"
                ],
                "properties": {
                  "p_hogar_id": {
                    "$ref": "#/components/schemas/Uuid"
                  },
                  "p_persona_id": {
                    "type": [
                      "string",
                      "null"
                    ],
                    "format": "uuid",
                    "description": "Persona que será la cuenta maestra; nulo la quita."
                  }
                }
              },
              "example": {
                "p_hogar_id": "b0000000-0000-4000-8000-000000000001",
                "p_persona_id": "e0000000-0000-4000-8000-000000000008"
              }
            }
          }
        },
        "responses": {
          "204": {
            "description": "Asignada (o quitada)."
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          }
        }
      }
    },
    "/rest/v1/rpc/fin_registrar_consulta_maestra": {
      "post": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "finRegistrarConsultaMaestra",
        "summary": "Registrar una consulta de la cuenta maestra a un libro ajeno",
        "description": "La cuenta maestra la llama **antes** de abrir un libro ajeno. Deja la consulta en la bitácora (`finanzas.consulta_maestra`, visible para quienes llevan ese libro) y habilita la lectura de ese libro por **30 minutos** (I2): es por libro y por persona, y pasado el tiempo hay que llamarla otra vez (cada llamada queda en la bitácora; la app la renueva sola mientras el libro está abierto). Sin una consulta vigente, el servidor no devuelve filas del contenido de un libro ajeno (cuentas, movimientos, plan, cierres, saldos): llega vacío, **sin error**; los libros y sus miembros sí se ven (la portada). Devuelve `true` si registró la consulta y `false` si el libro es propio (no se registra ni hace falta). Si la sesión no es la cuenta maestra del hogar, o el libro no existe, 403 (42501).",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "p_libro_id"
                ],
                "properties": {
                  "p_libro_id": {
                    "$ref": "#/components/schemas/Uuid"
                  }
                }
              },
              "example": {
                "p_libro_id": "f1000000-0000-4000-8000-000000000001"
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "`true` si se registró la consulta (vale 30 minutos); `false` si el libro es propio.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "boolean"
                },
                "examples": {
                  "registrada": {
                    "summary": "Libro ajeno (Gastos de la casa): consulta registrada",
                    "value": true
                  },
                  "propia": {
                    "summary": "Libro propio: no se registra ni hace falta",
                    "value": false
                  }
                }
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          }
        }
      }
    },
    "/rest/v1/rpc/fin_crear_libro_representado": {
      "post": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "finCrearLibroRepresentado",
        "summary": "Crear el libro de Papá (representado)",
        "description": "Solo el dueño (42501). Crea a la persona sin cuenta (Papá) y su libro `representado`; quien lo crea queda como albacea (el suplente se agrega en `fin_libro_miembros`). Con `p_libro_id` es idempotente: si ese libro ya existe, lo devuelve. Sin nombre, 22023.",
        "x-roles": [
          "dueno"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "p_hogar_id",
                  "p_nombre_titular"
                ],
                "properties": {
                  "p_hogar_id": {
                    "$ref": "#/components/schemas/Uuid"
                  },
                  "p_nombre_titular": {
                    "type": "string",
                    "minLength": 1,
                    "maxLength": 80
                  },
                  "p_nombre_libro": {
                    "type": [
                      "string",
                      "null"
                    ],
                    "maxLength": 80,
                    "description": "Por omisión, el nombre del titular."
                  },
                  "p_libro_id": {
                    "type": [
                      "string",
                      "null"
                    ],
                    "format": "uuid",
                    "description": "Id generado en el dispositivo (reintento sin duplicar)."
                  }
                }
              },
              "example": {
                "p_hogar_id": "b0000000-0000-4000-8000-000000000001",
                "p_nombre_titular": "Papá (ejemplo)",
                "p_nombre_libro": "Papá (ejemplo)",
                "p_libro_id": "f1000000-0000-4000-8000-000000000002"
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Identificador del libro (nuevo o el que ya existía).",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/Uuid"
                },
                "example": "f1000000-0000-4000-8000-000000000002"
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          }
        }
      }
    },
    "/rest/v1/rpc/fin_nombrar_albacea": {
      "post": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "finNombrarAlbacea",
        "summary": "Nombrar al albacea (o al suplente) del libro de Papá",
        "description": "Solo el dueño del hogar (N4): a cualquier otro responde 403 (42501), exista o no el libro, para no revelar libros. Nombra albacea o suplente de un libro `representado` cuyo cargo quedó vacío (nadie vigente que siga siendo adulto con Finanzas); si ese cargo lo tiene abierto alguien que ya no es adulto con Finanzas, lo cierra. Devuelve el id de la fila nueva de `fin_libro_miembros` y deja la entrada `finanzas.albacea_nombrado` en la bitácora (`libro_id`, `persona_id`, `papel` y `anterior_persona_id`). Responde 400 (22023) si el libro no es representado, el cargo no es `albacea` ni `albacea_suplente`, la persona no es adulto con Finanzas del hogar o es la persona representada, el cargo ya lo ocupa alguien (quien lo tiene debe dejarlo primero), o la persona ya lleva el libro con otro cargo.",
        "x-roles": [
          "dueno"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 1,
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "p_libro_id",
                  "p_persona_id"
                ],
                "properties": {
                  "p_libro_id": {
                    "$ref": "#/components/schemas/Uuid"
                  },
                  "p_persona_id": {
                    "$ref": "#/components/schemas/Uuid"
                  },
                  "p_papel": {
                    "type": "string",
                    "enum": [
                      "albacea",
                      "albacea_suplente"
                    ],
                    "default": "albacea"
                  }
                }
              },
              "examples": {
                "suplente": {
                  "summary": "Alex, suplente del libro de Papá",
                  "value": {
                    "p_libro_id": "f1000000-0000-4000-8000-000000000002",
                    "p_persona_id": "e0000000-0000-4000-8000-000000000002",
                    "p_papel": "albacea_suplente"
                  }
                },
                "albacea": {
                  "summary": "Ana vuelve a ser la albacea (por omisión, `albacea`)",
                  "value": {
                    "p_libro_id": "f1000000-0000-4000-8000-000000000002",
                    "p_persona_id": "e0000000-0000-4000-8000-000000000001"
                  }
                }
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Id de la fila nueva de `fin_libro_miembros`.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/Uuid"
                },
                "example": "7c2e9a40-5b1d-4e8a-9f36-1a4d6b8c0e21"
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/ReglaFinanzas"
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          }
        }
      }
    },
    "/rest/v1/rpc/fin_lunes": {
      "post": {
        "tags": [
          "Base de datos · Finanzas"
        ],
        "operationId": "finLunes",
        "summary": "Lunes de la semana de una fecha",
        "description": "La semana empieza en lunes (convención de GRAVITY). No lee datos.",
        "x-roles": [
          "dueno",
          "coadministrador"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 1,
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "p_fecha"
                ],
                "properties": {
                  "p_fecha": {
                    "type": "string",
                    "format": "date"
                  }
                }
              },
              "example": {
                "p_fecha": "2026-10-22"
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "El lunes de esa semana.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "string",
                  "format": "date"
                },
                "example": "2026-10-19"
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      }
    },
    "/functions/v1/avisos": {
      "post": {
        "tags": [
          "Funciones del servidor"
        ],
        "operationId": "enviarAviso",
        "summary": "Enviar un aviso al instante (Fase 2)",
        "description": "Propuesta. Envía una notificación (FCM) a los dispositivos de las personas indicadas, p. ej. una alerta de vencimiento o, en la Fase 5, un cambio urgente de medicamento a la cuidadora de turno. El texto es discreto: sin montos ni nombres de medicamentos.",
        "x-roles": [
          "dueno"
        ],
        "x-escribe": true,
        "x-solo-local": true,
        "x-fase": 2,
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/Aviso"
              }
            }
          }
        },
        "responses": {
          "202": {
            "description": "Aviso en camino."
          },
          "403": {
            "$ref": "#/components/responses/Prohibido"
          }
        }
      }
    },
    "/functions/v1/ia": {
      "post": {
        "tags": [
          "Funciones del servidor"
        ],
        "operationId": "preguntarIa",
        "summary": "Intermediario de la IA (Fase 6)",
        "description": "Propuesta. Guarda la clave de la API de IA en el servidor (nunca en la app). Recibe solo la pregunta y las herramientas del rol, y responde qué herramienta usar. Nunca recibe resultados de herramientas solo locales (D3). Proveedor por decidir.",
        "x-roles": [
          "dueno",
          "coadministrador",
          "familiar",
          "cuidador"
        ],
        "x-escribe": false,
        "x-solo-local": false,
        "x-fase": 6,
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/PreguntaIa"
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Herramienta elegida o respuesta breve.",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/RespuestaIa"
                }
              }
            }
          },
          "401": {
            "$ref": "#/components/responses/SinSesion"
          }
        }
      }
    },
    "/api/services/tts/speak": {
      "servers": [
        {
          "url": "http://{equipo}:8123",
          "description": "Home Assistant en la red de la casa (D9). Nunca expuesto a internet.",
          "variables": {
            "equipo": {
              "default": "homeassistant.local"
            }
          }
        }
      ],
      "post": {
        "tags": [
          "Puente de casa"
        ],
        "operationId": "decirEnBocina",
        "summary": "Decir una frase en una bocina",
        "description": "Propuesta. La voz de GRAVITY en una bocina (D6). Solo frases genéricas: nunca dinero ni datos clínicos; de cuidados, solo recordatorios sin nombres ni medicamentos.",
        "x-roles": [
          "dueno",
          "casa"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 6,
        "security": [
          {
            "tokenPuente": []
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "$ref": "#/components/schemas/FraseBocina"
              },
              "example": {
                "entity_id": "tts.google_translate_es_com",
                "media_player_entity_id": "media_player.bocina_cocina",
                "message": "Hora de la comida."
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Frase enviada a la bocina."
          },
          "401": {
            "description": "Token del puente inválido."
          }
        }
      }
    },
    "/api/services/script/turn_on": {
      "servers": [
        {
          "url": "http://{equipo}:8123",
          "description": "Home Assistant en la red de la casa (D9). Nunca expuesto a internet.",
          "variables": {
            "equipo": {
              "default": "homeassistant.local"
            }
          }
        }
      ],
      "post": {
        "tags": [
          "Puente de casa"
        ],
        "operationId": "ejecutarFraseFija",
        "summary": "Ejecutar una frase fija",
        "description": "Propuesta. Ejecuta un guion de Home Assistant con una frase fija de GRAVITY (D6).",
        "x-roles": [
          "dueno",
          "casa"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 6,
        "security": [
          {
            "tokenPuente": []
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "required": [
                  "entity_id"
                ],
                "properties": {
                  "entity_id": {
                    "type": "string",
                    "pattern": "^script\\.[a-z0-9_]+$"
                  }
                }
              },
              "example": {
                "entity_id": "script.gravity_buenas_noches"
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Guion en marcha."
          },
          "401": {
            "description": "Token del puente inválido."
          }
        }
      }
    },
    "/api/states/{entity_id}": {
      "servers": [
        {
          "url": "http://{equipo}:8123",
          "description": "Home Assistant en la red de la casa (D9). Nunca expuesto a internet.",
          "variables": {
            "equipo": {
              "default": "homeassistant.local"
            }
          }
        }
      ],
      "get": {
        "tags": [
          "Puente de casa"
        ],
        "operationId": "estadoEnCasa",
        "summary": "Estado de una bocina o guion",
        "description": "Propuesta. Comprueba que una bocina o un guion existe y en qué estado está.",
        "x-roles": [
          "dueno",
          "casa"
        ],
        "x-escribe": false,
        "x-solo-local": true,
        "x-fase": 6,
        "security": [
          {
            "tokenPuente": []
          }
        ],
        "parameters": [
          {
            "name": "entity_id",
            "in": "path",
            "required": true,
            "schema": {
              "type": "string"
            },
            "example": "media_player.bocina_cocina"
          }
        ],
        "responses": {
          "200": {
            "description": "Estado de la entidad.",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "entity_id": {
                      "type": "string"
                    },
                    "state": {
                      "type": "string"
                    }
                  }
                }
              }
            }
          },
          "404": {
            "description": "No existe esa entidad."
          }
        }
      }
    }
  },
  "components": {
    "securitySchemes": {
      "llavePublica": {
        "type": "apiKey",
        "in": "header",
        "name": "apikey",
        "description": "Llave pública de Supabase. Entra por `--dart-define`; nunca en el repositorio."
      },
      "sesion": {
        "type": "http",
        "scheme": "bearer",
        "bearerFormat": "JWT",
        "description": "Sesión de la persona (Supabase Auth). Las reglas RLS usan su rol en el hogar."
      },
      "tokenPuente": {
        "type": "http",
        "scheme": "bearer",
        "description": "Token de larga duración de la cuenta Casa en Home Assistant. Nunca en el repositorio."
      }
    },
    "parameters": {
      "nombreHerramienta": {
        "name": "nombre",
        "in": "path",
        "required": true,
        "description": "Nombre `<modulo>.<accion>` de la herramienta.",
        "schema": {
          "type": "string",
          "pattern": "^[a-z][a-z0-9_]*\\.[a-z][a-z0-9_]*$"
        },
        "example": "habitos.abrir"
      },
      "select": {
        "name": "select",
        "in": "query",
        "description": "Columnas a traer (PostgREST).",
        "schema": {
          "type": "string",
          "default": "*"
        }
      },
      "filtroId": {
        "name": "id",
        "in": "query",
        "description": "Filtro de PostgREST por identificador, p. ej. `eq.<uuid>`.",
        "schema": {
          "type": "string"
        },
        "example": "eq.6f1c2a8e-3b7d-4c55-9e0a-2d4b8f1e7a90"
      },
      "filtroIdObligatorio": {
        "name": "id",
        "in": "query",
        "required": true,
        "description": "Registro a cambiar: `eq.<uuid>`. Obligatorio para no tocar varios a la vez.",
        "schema": {
          "type": "string",
          "pattern": "^eq\\.[0-9a-f-]{36}$"
        },
        "example": "eq.6f1c2a8e-3b7d-4c55-9e0a-2d4b8f1e7a90"
      },
      "filtroHogar": {
        "name": "hogar_id",
        "in": "query",
        "description": "Filtro por hogar, p. ej. `eq.<uuid>`.",
        "schema": {
          "type": "string"
        }
      },
      "orden": {
        "name": "order",
        "in": "query",
        "description": "Orden (PostgREST), p. ej. `registrado_en.desc`.",
        "schema": {
          "type": "string"
        }
      },
      "limite": {
        "name": "limit",
        "in": "query",
        "schema": {
          "type": "integer",
          "minimum": 1,
          "maximum": 1000
        }
      },
      "preferir": {
        "name": "Prefer",
        "in": "header",
        "description": "`return=representation` para recibir el registro; `return=minimal` para no recibir nada.",
        "schema": {
          "type": "string",
          "enum": [
            "return=representation",
            "return=minimal"
          ]
        }
      },
      "filtroLibro": {
        "name": "libro_id",
        "in": "query",
        "description": "Filtro por libro de Finanzas, p. ej. `eq.<uuid>`. Sin filtro llegan todos los que puedes leer.",
        "schema": {
          "type": "string"
        },
        "example": "eq.f1000000-0000-4000-8000-000000000001"
      },
      "filtroLibroObligatorio": {
        "name": "libro_id",
        "in": "query",
        "required": true,
        "description": "Libro a cambiar: `eq.<uuid>`.",
        "schema": {
          "type": "string",
          "pattern": "^eq\\.[0-9a-f-]{36}$"
        },
        "example": "eq.f1000000-0000-4000-8000-000000000001"
      },
      "filtroFecha": {
        "name": "fecha",
        "in": "query",
        "description": "Filtro de PostgREST por fecha, p. ej. `gte.2026-10-19`.",
        "schema": {
          "type": "string"
        },
        "example": "gte.2026-10-19"
      },
      "filtroSemana": {
        "name": "semana_id",
        "in": "query",
        "description": "Filtro por semana del plan, p. ej. `eq.<uuid>`.",
        "schema": {
          "type": "string"
        }
      },
      "filtroSemanaInicio": {
        "name": "semana_inicio",
        "in": "query",
        "description": "Filtro por el lunes de la semana, p. ej. `eq.2026-10-19`.",
        "schema": {
          "type": "string"
        },
        "example": "eq.2026-10-19"
      },
      "alConflicto": {
        "name": "on_conflict",
        "in": "query",
        "description": "Columna que identifica un reenvío de la cola sin conexión. Con `Prefer: resolution=ignore-duplicates` equivale a `INSERT … ON CONFLICT (id) DO NOTHING`.",
        "schema": {
          "type": "string",
          "enum": [
            "id"
          ]
        }
      },
      "preferirAlSubir": {
        "name": "Prefer",
        "in": "header",
        "description": "`resolution=ignore-duplicates` para subir desde la cola sin conexión (un reenvío idéntico no hace nada); `return=representation` para recibir lo insertado.",
        "schema": {
          "type": "string",
          "enum": [
            "return=minimal",
            "return=representation",
            "resolution=ignore-duplicates,return=minimal",
            "resolution=ignore-duplicates,return=representation"
          ]
        }
      }
    },
    "requestBodies": {
      "PeticionHerramienta": {
        "required": false,
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/PeticionHerramienta"
            }
          }
        }
      },
      "SoloHogar": {
        "required": true,
        "content": {
          "application/json": {
            "schema": {
              "type": "object",
              "required": [
                "p_hogar_id"
              ],
              "properties": {
                "p_hogar_id": {
                  "$ref": "#/components/schemas/Uuid"
                }
              }
            }
          }
        }
      }
    },
    "responses": {
      "ResultadoHerramienta": {
        "description": "Resultado, o la tarjeta de confirmación si la herramienta escribe y falta confirmar.",
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/ResultadoHerramienta"
            },
            "example": {
              "herramienta": "habitos.abrir",
              "contenido": "Abriendo Hábitos…",
              "requiere_confirmacion": false,
              "solo_local": false,
              "para_ia": "Se abrió Hábitos."
            }
          }
        }
      },
      "HerramientaNoDisponible": {
        "description": "No existe para el rol o su módulo está inactivo (mismo mensaje en todos los casos).",
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/ErrorHerramienta"
            },
            "example": {
              "mensaje": "La herramienta «finanzas.abrir» no está disponible."
            }
          }
        }
      },
      "Agregado": {
        "description": "Agregado. Con `Prefer: return=representation` devuelve lo insertado; un reenvío idéntico desde la cola no inserta nada y devuelve una lista vacía.",
        "content": {
          "application/json": {
            "schema": {
              "type": "array",
              "items": {
                "type": "object"
              }
            }
          }
        }
      },
      "ReglaFinanzas": {
        "description": "No cumple una regla: de la tabla (23514: monto, motivo, lunes, cascada…) o de negocio (22023: combinación de cuentas, libro equivocado, papel…).",
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/ErrorPostgrest"
            },
            "example": {
              "code": "22023",
              "message": "Solo una transferencia o un pago de deuda va de un libro a otro.",
              "details": null,
              "hint": null
            }
          }
        }
      },
      "ConflictoFinanzas": {
        "description": "23503: falta algo de lo que depende (otra cuenta, el original de una anulación; la cola reintenta cuando ya se subió). 23505: duplicado, o el mismo `id` con otro contenido (no se edita: se corrige con un registro nuevo).",
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/ErrorPostgrest"
            },
            "example": {
              "code": "23505",
              "message": "Ya existe el movimiento 3d0c2f5e-8a41-4b7e-9c1d-5f2a6b8e9a01 con otro contenido.",
              "details": null,
              "hint": "No se edita: se corrige con un registro nuevo (anulación o versión siguiente)."
            }
          }
        }
      },
      "EstadoFinanzas": {
        "description": "55000: el registro no está en el estado que se necesita (cuenta congelada, cerrada o archivada; semana cerrada).",
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/ErrorPostgrest"
            },
            "example": {
              "code": "55000",
              "message": "Una de las cuentas no está activa (congelada, cerrada o archivada): no admite movimientos nuevos.",
              "details": null,
              "hint": null
            }
          }
        }
      },
      "Actualizado": {
        "description": "Registros actualizados (con `Prefer` igual a `return=representation`).",
        "content": {
          "application/json": {
            "schema": {
              "type": "array",
              "items": {
                "type": "object"
              }
            }
          }
        }
      },
      "SinSesion": {
        "description": "Falta la sesión o la llave pública.",
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/ErrorPostgrest"
            },
            "example": {
              "code": "PGRST301",
              "message": "JWT expired",
              "details": null,
              "hint": null
            }
          }
        }
      },
      "Prohibido": {
        "description": "Las reglas del servidor (RLS) no lo permiten para tu rol.",
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/ErrorPostgrest"
            },
            "example": {
              "code": "42501",
              "message": "new row violates row-level security policy",
              "details": null,
              "hint": null
            }
          }
        }
      },
      "Invalido": {
        "description": "Datos no válidos (p. ej. invitación vencida o ya usada).",
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/ErrorPostgrest"
            },
            "example": {
              "code": "22023",
              "message": "La invitación no es válida o ya expiró.",
              "details": null,
              "hint": null
            }
          }
        }
      }
    },
    "schemas": {
      "Uuid": {
        "type": "string",
        "format": "uuid"
      },
      "Rol": {
        "type": "string",
        "enum": [
          "dueno",
          "coadministrador",
          "familiar",
          "cuidador",
          "casa"
        ]
      },
      "RolInvitable": {
        "type": "string",
        "description": "Cualquier rol menos dueño.",
        "enum": [
          "coadministrador",
          "familiar",
          "cuidador",
          "casa"
        ]
      },
      "Modulo": {
        "type": "string",
        "enum": [
          "gravity",
          "finanzas",
          "habitos",
          "cuidados",
          "alimentacion",
          "casa",
          "ajustes"
        ]
      },
      "Accion": {
        "type": "string",
        "enum": [
          "leer",
          "escribir",
          "administrar"
        ]
      },
      "Alcance": {
        "type": "string",
        "enum": [
          "total",
          "propio",
          "restringido"
        ]
      },
      "Herramienta": {
        "type": "object",
        "required": [
          "nombre",
          "descripcion",
          "modulo",
          "roles",
          "escribe",
          "solo_local"
        ],
        "properties": {
          "nombre": {
            "type": "string",
            "pattern": "^[a-z][a-z0-9_]*\\.[a-z][a-z0-9_]*$"
          },
          "descripcion": {
            "type": "string"
          },
          "modulo": {
            "$ref": "#/components/schemas/Modulo"
          },
          "roles": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/Rol"
            }
          },
          "escribe": {
            "type": "boolean",
            "description": "Si escribe, pide confirmación."
          },
          "solo_local": {
            "type": "boolean",
            "description": "Si es solo local, su resultado nunca va a la IA en la nube."
          },
          "accion": {
            "$ref": "#/components/schemas/Accion",
            "description": "Lo que la persona debe poder hacer en el módulo para que se le ofrezca (abrir la hoja de un gasto exige escribir, aunque la que guarda es la hoja)."
          },
          "pertenencia": {
            "type": "string",
            "enum": [
              "propia",
              "ajena"
            ],
            "description": "Sobre qué datos actúa (D19). La cuenta maestra nunca recibe una que escriba o administre lo ajeno."
          },
          "ambito": {
            "type": "string",
            "enum": [
              "general",
              "solicitudes"
            ],
            "description": "`solicitudes`: la bandeja de la cuidadora (D18), lo único de GRAVITY que recibe."
          },
          "hoja": {
            "type": [
              "string",
              "null"
            ],
            "enum": [
              "gasto",
              "ingreso_extra",
              null
            ],
            "description": "Hoja de registro que abre (la hoja es la confirmación); nula si abre una pantalla. Una cuenta maestra que no es la dueña no recibe ninguna herramienta con hoja (solo lectura total)."
          }
        }
      },
      "PeticionHerramienta": {
        "type": "object",
        "properties": {
          "parametros": {
            "type": "object",
            "description": "Parámetros de la herramienta (las de navegación no llevan)."
          },
          "confirmado": {
            "type": "boolean",
            "default": false,
            "description": "Solo `true` después de que la persona aceptó la tarjeta de confirmación."
          }
        }
      },
      "ResultadoHerramienta": {
        "type": "object",
        "required": [
          "herramienta",
          "contenido",
          "requiere_confirmacion",
          "solo_local",
          "para_ia"
        ],
        "properties": {
          "herramienta": {
            "type": "string"
          },
          "contenido": {
            "type": "string",
            "description": "Texto para la pantalla o la voz local."
          },
          "requiere_confirmacion": {
            "type": "boolean",
            "description": "Si es `true`, no se escribió nada; `contenido` es la tarjeta de confirmación."
          },
          "solo_local": {
            "type": "boolean"
          },
          "para_ia": {
            "type": [
              "string",
              "null"
            ],
            "description": "Lo mínimo que puede ver la IA. Siempre nulo si `solo_local`."
          }
        }
      },
      "ErrorHerramienta": {
        "type": "object",
        "required": [
          "mensaje"
        ],
        "properties": {
          "mensaje": {
            "type": "string",
            "examples": [
              "La herramienta «finanzas.abrir» no está disponible."
            ]
          }
        }
      },
      "ErrorPostgrest": {
        "type": "object",
        "properties": {
          "code": {
            "type": "string",
            "examples": [
              "42501"
            ]
          },
          "message": {
            "type": "string"
          },
          "details": {
            "type": [
              "string",
              "null"
            ]
          },
          "hint": {
            "type": [
              "string",
              "null"
            ]
          }
        }
      },
      "Hogar": {
        "type": "object",
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "nombre": {
            "type": "string",
            "maxLength": 80
          },
          "creado_en": {
            "type": "string",
            "format": "date-time"
          }
        }
      },
      "Persona": {
        "type": "object",
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "usuario_id": {
            "type": [
              "string",
              "null"
            ],
            "format": "uuid",
            "description": "Cuenta de Supabase; nulo si la cuenta se eliminó."
          },
          "nombre_visible": {
            "type": "string",
            "maxLength": 80
          },
          "creado_en": {
            "type": "string",
            "format": "date-time"
          }
        }
      },
      "Membresia": {
        "type": "object",
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "hogar_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "persona_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "rol": {
            "$ref": "#/components/schemas/Rol"
          },
          "activa": {
            "type": "boolean"
          },
          "desde": {
            "type": "string",
            "format": "date-time"
          },
          "hasta": {
            "type": [
              "string",
              "null"
            ],
            "format": "date-time"
          },
          "es_maestra": {
            "type": "boolean",
            "readOnly": true,
            "description": "Cuenta maestra del hogar (D19): una por hogar, solo dueño o coadministrador; la asigna el dueño con `asignar_cuenta_maestra`."
          },
          "creado_en": {
            "type": "string",
            "format": "date-time"
          }
        }
      },
      "PermisoRol": {
        "type": "object",
        "properties": {
          "rol": {
            "$ref": "#/components/schemas/Rol"
          },
          "modulo": {
            "$ref": "#/components/schemas/Modulo"
          },
          "accion": {
            "$ref": "#/components/schemas/Accion"
          },
          "alcance": {
            "$ref": "#/components/schemas/Alcance"
          },
          "nota": {
            "type": [
              "string",
              "null"
            ]
          }
        }
      },
      "Invitacion": {
        "type": "object",
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "hogar_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "correo": {
            "type": "string",
            "format": "email"
          },
          "rol": {
            "$ref": "#/components/schemas/RolInvitable"
          },
          "es_maestra": {
            "type": "boolean",
            "default": false,
            "description": "Invitación a la cuenta maestra (D19, 23/oct): solo con rol `coadministrador`; al aceptarla, la persona queda con la marca de cuenta maestra y sin libro personal."
          },
          "token_hash": {
            "type": "string",
            "description": "SHA-256 del token; el token no se guarda."
          },
          "expira_en": {
            "type": "string",
            "format": "date-time"
          },
          "creada_por": {
            "type": [
              "string",
              "null"
            ],
            "format": "uuid"
          },
          "creada_en": {
            "type": "string",
            "format": "date-time"
          },
          "aceptada_en": {
            "type": [
              "string",
              "null"
            ],
            "format": "date-time"
          },
          "aceptada_por": {
            "type": [
              "string",
              "null"
            ],
            "format": "uuid"
          },
          "revocada_en": {
            "type": [
              "string",
              "null"
            ],
            "format": "date-time"
          }
        }
      },
      "Dispositivo": {
        "type": "object",
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "persona_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "plataforma": {
            "type": "string",
            "enum": [
              "android",
              "windows"
            ]
          },
          "token_avisos": {
            "type": [
              "string",
              "null"
            ]
          },
          "nombre": {
            "type": [
              "string",
              "null"
            ]
          },
          "creado_en": {
            "type": "string",
            "format": "date-time"
          },
          "ultimo_uso": {
            "type": "string",
            "format": "date-time"
          }
        }
      },
      "EntradaBitacora": {
        "type": "object",
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "hogar_id": {
            "type": [
              "string",
              "null"
            ],
            "format": "uuid"
          },
          "persona_id": {
            "type": [
              "string",
              "null"
            ],
            "format": "uuid",
            "description": "Quién; lo pone el servidor. Nulo = sistema."
          },
          "accion": {
            "type": "string",
            "description": "Qué pasó, en minúsculas. `insertar`, `actualizar` y `borrar` solo las escriben los triggers que registran los cambios de las tablas. Las de Finanzas las escribe solo el servidor (I5): `finanzas.consulta_maestra` (la cuenta maestra consultó un libro ajeno; vale 30 minutos), `finanzas.maestra_asignada` (el dueño nombró o quitó la cuenta maestra, o se aceptó una invitación de cuenta maestra; `detalle` lleva `anterior_persona_id` y `nueva_persona_id` y, con invitación, `invitada_por`), `finanzas.salida_libro_representado` (una salida del libro de Papá hacia cualquier otro libro, personal o compartido; `detalle` lleva el libro de origen, el de destino, el tipo, la fecha, el monto en centavos, `en_nombre_de` y `motivo`) y `finanzas.albacea_nombrado` (el dueño nombró al albacea o al suplente del libro de Papá; `detalle` lleva `libro_id`, `persona_id`, `papel` y `anterior_persona_id`).",
            "examples": [
              "finanzas.consulta_maestra",
              "finanzas.maestra_asignada",
              "finanzas.salida_libro_representado",
              "finanzas.albacea_nombrado"
            ]
          },
          "tabla": {
            "type": [
              "string",
              "null"
            ]
          },
          "registro_id": {
            "type": [
              "string",
              "null"
            ]
          },
          "detalle": {
            "type": "object"
          },
          "ocurrido_en": {
            "type": "string",
            "format": "date-time"
          },
          "registrado_en": {
            "type": "string",
            "format": "date-time"
          }
        }
      },
      "Centavos": {
        "type": "integer",
        "format": "int64",
        "description": "Dinero en centavos (MXN), entero. Nunca va a la IA en la nube (D3)."
      },
      "CentavosPositivos": {
        "type": "integer",
        "format": "int64",
        "minimum": 1,
        "description": "Dinero en centavos (MXN), mayor que cero."
      },
      "CentavosNoNegativos": {
        "type": "integer",
        "format": "int64",
        "minimum": 0,
        "description": "Dinero en centavos (MXN), cero o más."
      },
      "PuntosBase": {
        "type": "integer",
        "minimum": 0,
        "maximum": 10000,
        "description": "Porcentaje en puntos base (2000 = 20.00 %)."
      },
      "UuidONulo": {
        "type": [
          "string",
          "null"
        ],
        "format": "uuid"
      },
      "FinNombre": {
        "type": "string",
        "minLength": 1,
        "maxLength": 80
      },
      "FinPrioridad": {
        "type": "string",
        "enum": [
          "necesario",
          "deseable",
          "discrecional"
        ]
      },
      "FinReglaInhabil": {
        "type": "string",
        "enum": [
          "siguiente_dia_habil",
          "dia_habil_anterior",
          "sin_cambio"
        ],
        "description": "Qué hacer si un pago cae en sábado, domingo o día inhábil (D19, regla 5)."
      },
      "FinFormaPago": {
        "type": "string",
        "enum": [
          "semanal",
          "catorcenal",
          "quincenal",
          "mensual",
          "cada_meses"
        ],
        "description": "semanal (`dia_semana`), catorcenal (`fecha_ancla`), quincenal (2 `dias_mes`), mensual (1 o más `dias_mes`, p. ej. `[1, 11]`) o cada_meses (`fecha_ancla` e `intervalo_meses`)."
      },
      "FinFormaPagoONula": {
        "type": [
          "string",
          "null"
        ],
        "enum": [
          "semanal",
          "catorcenal",
          "quincenal",
          "mensual",
          "cada_meses",
          null
        ],
        "description": "Calendario opcional (como `FinFormaPago`)."
      },
      "FinFrecuencia": {
        "type": "string",
        "enum": [
          "semanal",
          "catorcenal",
          "quincenal",
          "mensual",
          "bimestral",
          "trimestral",
          "semestral",
          "anual",
          "diaria"
        ]
      },
      "FinModoArrastre": {
        "type": "string",
        "enum": [
          "arrastrar",
          "al_remanente"
        ]
      },
      "FinDiaSemana": {
        "type": [
          "integer",
          "null"
        ],
        "minimum": 1,
        "maximum": 7,
        "description": "1 = lunes … 7 = domingo."
      },
      "FinDiasMes": {
        "type": [
          "array",
          "null"
        ],
        "items": {
          "type": "integer",
          "minimum": 0,
          "maximum": 31
        },
        "minItems": 1,
        "maxItems": 31,
        "description": "Días del mes (0 = último día), p. ej. `[1, 11]` o `[15, 0]`."
      },
      "FinIntervaloMeses": {
        "type": [
          "integer",
          "null"
        ],
        "minimum": 1,
        "maximum": 12
      },
      "FinLibro": {
        "type": "object",
        "description": "Libro de Finanzas (D19): `personal` (lo crea el servidor al dar un rol con Finanzas), `compartido` (2 o más adultos) o `representado` (el de Papá, que llevan sus albaceas).",
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "hogar_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "nombre": {
            "$ref": "#/components/schemas/FinNombre"
          },
          "tipo": {
            "type": "string",
            "enum": [
              "personal",
              "compartido",
              "representado"
            ]
          },
          "titular_id": {
            "$ref": "#/components/schemas/UuidONulo",
            "description": "Obligatorio en personal y representado; nulo en compartido."
          },
          "activo": {
            "type": "boolean",
            "default": true,
            "description": "`false` = archivado por su administrador (nunca ocurre solo): se lee y no registra movimientos nuevos."
          },
          "visibilidad": {
            "type": "string",
            "enum": [
              "privada",
              "publica"
            ],
            "default": "privada",
            "description": "Solo en los compartidos (en los demás, siempre `privada`). `privada`: leen y escriben sus miembros (la maestra lee con consulta). `publica`: además la leen, sin escribir, todos los adultos con Finanzas del hogar. La cambia solo quien creó el libro (42501). Pasa sola a `privada` cuando quedan menos de 2 miembros vigentes."
          },
          "creado_por": {
            "$ref": "#/components/schemas/UuidONulo",
            "readOnly": true,
            "description": "El administrador del libro (quien lo creó). La API no lo manda ni lo cambia (42501); el servidor lo pasa al miembro vigente más antiguo si el administrador se sale o deja de ser adulto con Finanzas, y al que queda si quedan menos de 2."
          },
          "creado_en": {
            "type": "string",
            "format": "date-time",
            "readOnly": true
          }
        }
      },
      "FinLibroMiembro": {
        "type": "object",
        "description": "Quién lleva cada libro. No se borra; se cierra `hasta`.",
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "hogar_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "libro_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "persona_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "papel": {
            "type": "string",
            "enum": [
              "titular",
              "miembro",
              "albacea",
              "albacea_suplente"
            ]
          },
          "desde": {
            "type": "string",
            "format": "date-time"
          },
          "hasta": {
            "type": [
              "string",
              "null"
            ],
            "format": "date-time"
          }
        }
      },
      "FinCategoria": {
        "type": "object",
        "description": "Árbol de categorías del hogar (3 niveles, común a todos los libros).",
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "hogar_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "padre_id": {
            "$ref": "#/components/schemas/UuidONulo",
            "description": "Nulo solo en el nivel 1."
          },
          "nivel": {
            "type": "integer",
            "minimum": 1,
            "maximum": 3
          },
          "nombre": {
            "$ref": "#/components/schemas/FinNombre"
          },
          "icono": {
            "type": [
              "string",
              "null"
            ],
            "maxLength": 64
          },
          "color": {
            "type": [
              "string",
              "null"
            ],
            "maxLength": 32
          },
          "naturaleza": {
            "type": [
              "string",
              "null"
            ],
            "maxLength": 40,
            "description": "Texto de la plantilla (fija, variable, mixta, eventual…)."
          },
          "prioridad": {
            "$ref": "#/components/schemas/FinPrioridad"
          },
          "protegida": {
            "type": "boolean"
          },
          "es_del_sistema": {
            "type": "boolean"
          },
          "oculta": {
            "type": "boolean"
          },
          "archivada": {
            "type": "boolean"
          },
          "posiblemente_deducible": {
            "type": "boolean"
          },
          "cuenta_gasto_id": {
            "$ref": "#/components/schemas/UuidONulo"
          }
        }
      },
      "FinCuenta": {
        "type": "object",
        "description": "Cuenta de un libro o, si es `de_gasto` o `gasto_financiero`, del hogar (`libro_id` nulo). Cerrar o archivar exige saldo cero solo en activos y pasivos (las de gasto e ingreso son de periodo); borrar solo sin movimientos.",
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "hogar_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "libro_id": {
            "$ref": "#/components/schemas/UuidONulo"
          },
          "nombre": {
            "$ref": "#/components/schemas/FinNombre"
          },
          "tipo": {
            "type": "string",
            "enum": [
              "efectivo",
              "banco",
              "ahorro",
              "inversion",
              "por_cobrar",
              "tarjeta",
              "prestamo",
              "origen_ingreso",
              "de_gasto",
              "gasto_financiero",
              "por_clasificar",
              "ajustes",
              "apertura"
            ]
          },
          "clase": {
            "type": "string",
            "enum": [
              "activo",
              "pasivo",
              "ingreso",
              "gasto",
              "ajuste",
              "apertura"
            ],
            "readOnly": true,
            "description": "Generada desde `tipo`."
          },
          "liquida": {
            "type": "boolean",
            "readOnly": true,
            "description": "Generada; efectivo y banco entran al \"disponible\"."
          },
          "estado": {
            "type": "string",
            "enum": [
              "activa",
              "congelada",
              "cerrada",
              "archivada"
            ],
            "default": "activa"
          },
          "categoria_id": {
            "$ref": "#/components/schemas/UuidONulo",
            "description": "Solo en cuentas de gasto."
          },
          "limite_centavos": {
            "type": [
              "integer",
              "null"
            ],
            "format": "int64",
            "minimum": 1,
            "description": "Límite de una tarjeta, en centavos (opcional)."
          },
          "creada_por": {
            "$ref": "#/components/schemas/UuidONulo",
            "description": "La app la puede mandar; el servidor la sobrescribe con la sesión."
          },
          "creada_en": {
            "type": "string",
            "format": "date-time",
            "readOnly": true
          }
        }
      },
      "FinParametros": {
        "type": "object",
        "description": "Parámetros de un libro (una fila por libro; porcentajes en puntos base).",
        "properties": {
          "libro_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "hogar_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "meta_remanente_pb": {
            "$ref": "#/components/schemas/PuntosBase"
          },
          "ahorro_minimo_con_deuda_pb": {
            "$ref": "#/components/schemas/PuntosBase"
          },
          "tope_arrastre_semanas": {
            "type": "integer",
            "minimum": 0,
            "maximum": 52
          },
          "partida_ambar_pb": {
            "type": "integer",
            "minimum": 0,
            "maximum": 100000
          },
          "partida_rojo_pb": {
            "type": "integer",
            "minimum": 0,
            "maximum": 100000
          },
          "remanente_verde_pb": {
            "$ref": "#/components/schemas/PuntosBase"
          },
          "remanente_ambar_pb": {
            "$ref": "#/components/schemas/PuntosBase"
          },
          "carga_ambar_pb": {
            "type": "integer",
            "minimum": 0,
            "maximum": 100000
          },
          "carga_rojo_pb": {
            "type": "integer",
            "minimum": 0,
            "maximum": 100000
          },
          "cumplimiento_verde_pb": {
            "$ref": "#/components/schemas/PuntosBase"
          },
          "cumplimiento_ambar_pb": {
            "$ref": "#/components/schemas/PuntosBase"
          },
          "cierre_automatico_dias": {
            "type": "integer",
            "minimum": 1,
            "maximum": 30
          },
          "cuenta_ajustes_id": {
            "$ref": "#/components/schemas/Uuid",
            "readOnly": true
          },
          "cuenta_apertura_id": {
            "$ref": "#/components/schemas/Uuid",
            "readOnly": true
          },
          "cuenta_por_clasificar_id": {
            "$ref": "#/components/schemas/Uuid",
            "readOnly": true
          }
        }
      },
      "FinMovimiento": {
        "type": "object",
        "description": "Movimiento del libro **solo agregar** (partida doble simplificada). Se corrige con una anulación; nunca se edita ni se borra.",
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid",
            "description": "Generado en el dispositivo (la cola sin conexión reenvía el mismo)."
          },
          "hogar_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "tipo": {
            "type": "string",
            "enum": [
              "apertura",
              "ingreso",
              "gasto",
              "reembolso",
              "transferencia",
              "pago_deuda",
              "reclasificacion",
              "ajuste",
              "anulacion"
            ]
          },
          "fecha": {
            "type": "string",
            "format": "date",
            "description": "Fecha económica; define la semana."
          },
          "registrado_en": {
            "type": "string",
            "format": "date-time",
            "description": "Cuándo se capturó, en el dispositivo. **Obligatorio.**"
          },
          "recibido_en": {
            "type": "string",
            "format": "date-time",
            "readOnly": true,
            "description": "Cuándo llegó al servidor; lo pone el servidor."
          },
          "cuenta_origen_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "cuenta_destino_id": {
            "$ref": "#/components/schemas/Uuid",
            "description": "Distinta de la de origen."
          },
          "libro_origen_id": {
            "$ref": "#/components/schemas/UuidONulo",
            "readOnly": true,
            "description": "Libro de la cuenta de origen; lo pone el servidor."
          },
          "libro_destino_id": {
            "$ref": "#/components/schemas/UuidONulo",
            "readOnly": true,
            "description": "Libro de la cuenta de destino; lo pone el servidor."
          },
          "monto_centavos": {
            "$ref": "#/components/schemas/CentavosPositivos"
          },
          "categoria_id": {
            "$ref": "#/components/schemas/UuidONulo"
          },
          "grupo_id": {
            "$ref": "#/components/schemas/UuidONulo",
            "description": "Agrupa un ticket dividido o capital más intereses."
          },
          "realizado_por": {
            "$ref": "#/components/schemas/Uuid",
            "description": "Por omisión, la sesión."
          },
          "registrado_por": {
            "$ref": "#/components/schemas/Uuid",
            "description": "Por omisión, la sesión; siempre la sesión (nadie registra a nombre de otro)."
          },
          "en_nombre_de": {
            "$ref": "#/components/schemas/UuidONulo",
            "description": "Persona representada (Papá). Obligatoria, junto con `motivo`, en todo movimiento que toque el libro de Papá (23514, I3); es el titular de ese libro."
          },
          "via": {
            "type": "string",
            "enum": [
              "manual",
              "voz",
              "imagen",
              "qr",
              "importacion"
            ],
            "default": "manual"
          },
          "nota": {
            "type": [
              "string",
              "null"
            ],
            "maxLength": 200
          },
          "motivo": {
            "type": [
              "string",
              "null"
            ],
            "maxLength": 200,
            "description": "Obligatorio en `ajuste`, `anulacion` y con `en_nombre_de`, y en todo movimiento del libro de Papá: al menos 3 caracteres visibles, sin contar espacios, saltos de línea ni caracteres invisibles (23514, N2)."
          },
          "anula_a": {
            "$ref": "#/components/schemas/UuidONulo",
            "description": "Solo en `anulacion`; cada movimiento tiene a lo más una."
          },
          "estado_inicial": {
            "type": "string",
            "enum": [
              "confirmado",
              "pendiente"
            ],
            "default": "confirmado"
          }
        }
      },
      "FinIngreso": {
        "type": "object",
        "description": "Ingreso recurrente de un libro (por persona).",
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "hogar_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "libro_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "persona_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "nombre": {
            "$ref": "#/components/schemas/FinNombre"
          },
          "tipo": {
            "type": "string",
            "enum": [
              "salario",
              "independiente",
              "prestaciones",
              "pension",
              "otro"
            ],
            "default": "salario"
          },
          "cuenta_origen_id": {
            "$ref": "#/components/schemas/UuidONulo",
            "description": "Cuenta `origen_ingreso` del mismo libro."
          },
          "cuenta_destino_id": {
            "$ref": "#/components/schemas/UuidONulo",
            "description": "Activo del mismo libro donde se recibe."
          },
          "certeza": {
            "type": "string",
            "enum": [
              "segura",
              "probable",
              "incierta"
            ],
            "default": "segura"
          },
          "activo": {
            "type": "boolean",
            "default": true
          }
        }
      },
      "FinVigenciaIngreso": {
        "type": "object",
        "description": "Monto neto y calendario de un ingreso por periodo; no se traslapan.",
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "hogar_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "libro_id": {
            "$ref": "#/components/schemas/Uuid",
            "description": "El del ingreso (lo pone el servidor)."
          },
          "ingreso_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "monto_neto_centavos": {
            "$ref": "#/components/schemas/CentavosPositivos"
          },
          "forma": {
            "$ref": "#/components/schemas/FinFormaPago"
          },
          "dia_semana": {
            "$ref": "#/components/schemas/FinDiaSemana"
          },
          "dias_mes": {
            "$ref": "#/components/schemas/FinDiasMes"
          },
          "fecha_ancla": {
            "type": [
              "string",
              "null"
            ],
            "format": "date"
          },
          "intervalo_meses": {
            "$ref": "#/components/schemas/FinIntervaloMeses"
          },
          "regla_inhabil": {
            "$ref": "#/components/schemas/FinReglaInhabil",
            "default": "siguiente_dia_habil"
          },
          "desde": {
            "type": "string",
            "format": "date"
          },
          "hasta": {
            "type": [
              "string",
              "null"
            ],
            "format": "date"
          }
        }
      },
      "FinCompromiso": {
        "type": "object",
        "description": "Gasto fijo o reserva de un libro (renta, servicios, placas, predial).",
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "hogar_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "libro_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "nombre": {
            "$ref": "#/components/schemas/FinNombre"
          },
          "tipo": {
            "type": "string",
            "enum": [
              "fija",
              "reserva"
            ]
          },
          "cuenta_gasto_id": {
            "$ref": "#/components/schemas/UuidONulo"
          },
          "categoria_id": {
            "$ref": "#/components/schemas/UuidONulo"
          },
          "monto_centavos": {
            "$ref": "#/components/schemas/CentavosPositivos"
          },
          "frecuencia": {
            "$ref": "#/components/schemas/FinFrecuencia"
          },
          "dias_activos": {
            "type": [
              "integer",
              "null"
            ],
            "minimum": 1,
            "maximum": 7,
            "description": "Solo con frecuencia `diaria`."
          },
          "forma": {
            "$ref": "#/components/schemas/FinFormaPagoONula"
          },
          "dia_semana": {
            "$ref": "#/components/schemas/FinDiaSemana"
          },
          "dias_mes": {
            "$ref": "#/components/schemas/FinDiasMes"
          },
          "fecha_ancla": {
            "type": [
              "string",
              "null"
            ],
            "format": "date"
          },
          "intervalo_meses": {
            "$ref": "#/components/schemas/FinIntervaloMeses"
          },
          "regla_inhabil": {
            "$ref": "#/components/schemas/FinReglaInhabil",
            "default": "sin_cambio"
          },
          "protegida": {
            "type": "boolean"
          },
          "prioridad": {
            "$ref": "#/components/schemas/FinPrioridad"
          },
          "desde": {
            "type": [
              "string",
              "null"
            ],
            "format": "date"
          },
          "hasta": {
            "type": [
              "string",
              "null"
            ],
            "format": "date"
          },
          "activo": {
            "type": "boolean",
            "default": true
          }
        }
      },
      "FinSobre": {
        "type": "object",
        "description": "Partida variable por rubro (sobre) del presupuesto de un libro.",
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "hogar_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "libro_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "cuenta_gasto_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "nombre": {
            "$ref": "#/components/schemas/FinNombre"
          },
          "monto_semanal_centavos": {
            "$ref": "#/components/schemas/CentavosNoNegativos"
          },
          "protegida": {
            "type": "boolean"
          },
          "prioridad": {
            "$ref": "#/components/schemas/FinPrioridad"
          },
          "piso_minimo_centavos": {
            "$ref": "#/components/schemas/CentavosNoNegativos",
            "description": "Entre 0 y el monto semanal."
          },
          "modo_arrastre": {
            "$ref": "#/components/schemas/FinModoArrastre"
          },
          "activo": {
            "type": "boolean",
            "default": true
          }
        }
      },
      "FinDeuda": {
        "type": "object",
        "description": "Deuda de un libro; el saldo sale de su cuenta pasivo.",
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "hogar_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "libro_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "nombre": {
            "$ref": "#/components/schemas/FinNombre"
          },
          "tipo": {
            "type": "string",
            "enum": [
              "con_costo",
              "familiar",
              "msi"
            ]
          },
          "cuenta_pasivo_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "abono_centavos": {
            "$ref": "#/components/schemas/CentavosNoNegativos"
          },
          "frecuencia": {
            "$ref": "#/components/schemas/FinFrecuencia",
            "description": "Cualquiera menos `diaria`."
          },
          "forma": {
            "$ref": "#/components/schemas/FinFormaPagoONula"
          },
          "dia_semana": {
            "$ref": "#/components/schemas/FinDiaSemana"
          },
          "dias_mes": {
            "$ref": "#/components/schemas/FinDiasMes"
          },
          "fecha_ancla": {
            "type": [
              "string",
              "null"
            ],
            "format": "date"
          },
          "intervalo_meses": {
            "$ref": "#/components/schemas/FinIntervaloMeses"
          },
          "regla_inhabil": {
            "$ref": "#/components/schemas/FinReglaInhabil",
            "default": "sin_cambio"
          },
          "minimo_centavos": {
            "$ref": "#/components/schemas/CentavosNoNegativos"
          },
          "tasa_anual_pb": {
            "type": "integer",
            "minimum": 0,
            "description": "Puntos base (4800 = 48 % anual); mayor que 0 solo en `con_costo`."
          },
          "prioridad_manual": {
            "type": [
              "integer",
              "null"
            ],
            "minimum": 1
          },
          "grupo_prioritario": {
            "type": "boolean",
            "description": "Del grupo de deudas prioritarias que elige el titular (P12)."
          },
          "orden_grupo": {
            "type": [
              "integer",
              "null"
            ],
            "minimum": 1,
            "description": "Obligatorio si y solo si `grupo_prioritario`."
          },
          "activa": {
            "type": "boolean",
            "default": true
          }
        }
      },
      "FinDiaInhabil": {
        "type": "object",
        "description": "Día inhábil del hogar; la precarga de festivos nace inactiva.",
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "hogar_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "fecha": {
            "type": "string",
            "format": "date"
          },
          "nombre": {
            "$ref": "#/components/schemas/FinNombre"
          },
          "tipo": {
            "type": "string",
            "enum": [
              "festivo_oficial",
              "personal"
            ],
            "default": "festivo_oficial"
          },
          "fuente": {
            "type": [
              "string",
              "null"
            ],
            "maxLength": 120
          },
          "activo": {
            "type": "boolean",
            "default": false
          },
          "revisado_por": {
            "$ref": "#/components/schemas/UuidONulo",
            "description": "Lo pone el servidor al cambiar `activo`."
          },
          "revisado_en": {
            "type": [
              "string",
              "null"
            ],
            "format": "date-time",
            "description": "Lo pone el servidor al cambiar `activo`."
          }
        }
      },
      "FinSemana": {
        "type": "object",
        "description": "Foto del plan de una semana (lunes) de un libro. Cascada: `remanente_plan = ingreso − presupuesto − deuda_plan`.",
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "hogar_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "libro_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "semana_inicio": {
            "type": "string",
            "format": "date",
            "description": "Lunes."
          },
          "estado": {
            "type": "string",
            "enum": [
              "borrador",
              "activa",
              "pendiente_ingreso",
              "por_cerrar",
              "cerrada"
            ],
            "default": "borrador"
          },
          "metodo": {
            "type": "string",
            "enum": [
              "sobres"
            ],
            "default": "sobres"
          },
          "ingreso": {
            "$ref": "#/components/schemas/CentavosNoNegativos"
          },
          "presupuesto": {
            "$ref": "#/components/schemas/CentavosNoNegativos"
          },
          "deuda_plan": {
            "$ref": "#/components/schemas/CentavosNoNegativos"
          },
          "remanente_plan": {
            "$ref": "#/components/schemas/Centavos"
          },
          "meta_remanente_pb": {
            "$ref": "#/components/schemas/PuntosBase"
          },
          "ahorro_minimo_con_deuda_pb": {
            "$ref": "#/components/schemas/PuntosBase"
          },
          "techo": {
            "$ref": "#/components/schemas/Centavos"
          },
          "activada_por": {
            "$ref": "#/components/schemas/UuidONulo",
            "description": "La pone el servidor."
          },
          "activada_en": {
            "type": [
              "string",
              "null"
            ],
            "format": "date-time",
            "description": "La pone el servidor."
          },
          "reaperturas": {
            "type": "integer",
            "minimum": 0,
            "readOnly": true,
            "description": "Veces que se reabrió; lo pone el servidor."
          }
        }
      },
      "FinPartidaSemana": {
        "type": "object",
        "description": "Lo asignado a un compromiso o sobre en una semana.",
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "hogar_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "libro_id": {
            "$ref": "#/components/schemas/Uuid",
            "description": "El de su semana."
          },
          "semana_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "origen": {
            "type": "string",
            "enum": [
              "compromiso",
              "sobre"
            ]
          },
          "origen_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "cuenta_gasto_id": {
            "$ref": "#/components/schemas/UuidONulo"
          },
          "tipo": {
            "type": "string",
            "enum": [
              "fija",
              "variable",
              "reserva"
            ],
            "description": "`variable` si y solo si el origen es un sobre."
          },
          "asignado": {
            "$ref": "#/components/schemas/CentavosNoNegativos"
          },
          "arrastre_recibido": {
            "$ref": "#/components/schemas/CentavosNoNegativos"
          },
          "protegida": {
            "type": "boolean"
          },
          "prioridad": {
            "$ref": "#/components/schemas/FinPrioridad"
          },
          "piso_minimo": {
            "$ref": "#/components/schemas/CentavosNoNegativos"
          },
          "modo_arrastre": {
            "$ref": "#/components/schemas/FinModoArrastre"
          }
        }
      },
      "FinAbonoSemana": {
        "type": "object",
        "description": "Abono planeado a una deuda en una semana.",
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "hogar_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "libro_id": {
            "$ref": "#/components/schemas/Uuid",
            "description": "El de su semana."
          },
          "semana_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "deuda_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "abono_planeado": {
            "$ref": "#/components/schemas/CentavosNoNegativos"
          },
          "minimo": {
            "$ref": "#/components/schemas/CentavosNoNegativos"
          },
          "extra_planeado": {
            "$ref": "#/components/schemas/CentavosNoNegativos"
          }
        }
      },
      "FinCierre": {
        "type": "object",
        "description": "Foto del cierre de una semana y del balance (**solo agregar**).",
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "hogar_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "libro_id": {
            "$ref": "#/components/schemas/Uuid",
            "description": "El de su semana."
          },
          "semana_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "version": {
            "type": "integer",
            "minimum": 1,
            "description": "Reaperturas de la semana + 1."
          },
          "ingreso_real": {
            "$ref": "#/components/schemas/Centavos"
          },
          "gasto_real": {
            "$ref": "#/components/schemas/Centavos"
          },
          "abono_real": {
            "$ref": "#/components/schemas/CentavosNoNegativos"
          },
          "abono_diferido": {
            "$ref": "#/components/schemas/CentavosNoNegativos"
          },
          "abono_extra_real": {
            "$ref": "#/components/schemas/CentavosNoNegativos"
          },
          "ahorro_real": {
            "$ref": "#/components/schemas/CentavosNoNegativos"
          },
          "deficit": {
            "$ref": "#/components/schemas/CentavosNoNegativos"
          },
          "arrastre_siguiente": {
            "$ref": "#/components/schemas/CentavosNoNegativos"
          },
          "accion_elegida": {
            "type": [
              "string",
              "null"
            ],
            "minLength": 1,
            "maxLength": 60
          },
          "con_pendientes": {
            "type": "boolean"
          },
          "activos": {
            "$ref": "#/components/schemas/Centavos"
          },
          "pasivos": {
            "$ref": "#/components/schemas/Centavos"
          },
          "patrimonio": {
            "$ref": "#/components/schemas/Centavos",
            "description": "Activos − pasivos."
          },
          "cerrado_por": {
            "$ref": "#/components/schemas/Uuid",
            "description": "Por omisión, la sesión (siempre la sesión)."
          },
          "cerrado_en": {
            "type": "string",
            "format": "date-time",
            "description": "Se acepta del dispositivo."
          }
        }
      },
      "FinCierrePartida": {
        "type": "object",
        "description": "Una partida al cerrar la semana (**solo agregar**).",
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "hogar_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "libro_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "cierre_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "partida_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "gastado": {
            "$ref": "#/components/schemas/Centavos"
          },
          "arrastre_siguiente": {
            "$ref": "#/components/schemas/CentavosNoNegativos"
          },
          "al_remanente": {
            "$ref": "#/components/schemas/CentavosNoNegativos"
          }
        }
      },
      "FinCierreAbono": {
        "type": "object",
        "description": "Un abono al cerrar la semana (**solo agregar**; el AbonoDiferido del diseño).",
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "hogar_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "libro_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "cierre_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "deuda_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "planeado": {
            "$ref": "#/components/schemas/CentavosNoNegativos"
          },
          "real": {
            "$ref": "#/components/schemas/CentavosNoNegativos"
          },
          "minimo": {
            "$ref": "#/components/schemas/CentavosNoNegativos"
          },
          "diferido": {
            "$ref": "#/components/schemas/CentavosNoNegativos",
            "readOnly": true,
            "description": "Generado; planeado − real (no menos de cero)."
          }
        }
      },
      "FinOcurrencia": {
        "type": "object",
        "description": "Fecha esperada de un ingreso, compromiso o deuda.",
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "hogar_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "libro_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "origen": {
            "type": "string",
            "enum": [
              "ingreso",
              "compromiso",
              "deuda"
            ]
          },
          "origen_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "fecha_programada": {
            "type": "string",
            "format": "date"
          },
          "fecha_ajustada": {
            "type": "string",
            "format": "date",
            "description": "Con la regla de día inhábil aplicada."
          },
          "monto_esperado": {
            "$ref": "#/components/schemas/CentavosNoNegativos"
          },
          "estado": {
            "type": "string",
            "enum": [
              "esperada",
              "cumplida",
              "parcial",
              "retrasada",
              "no_llegara",
              "omitida"
            ],
            "default": "esperada"
          },
          "movimiento_id": {
            "$ref": "#/components/schemas/UuidONulo"
          }
        }
      },
      "FinConciliacion": {
        "type": "object",
        "description": "Conciliación de saldo de una cuenta (**solo agregar**).",
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "hogar_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "libro_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "cuenta_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "fecha": {
            "type": "string",
            "format": "date"
          },
          "saldo_declarado": {
            "$ref": "#/components/schemas/Centavos"
          },
          "saldo_calculado": {
            "$ref": "#/components/schemas/Centavos"
          },
          "diferencia": {
            "$ref": "#/components/schemas/Centavos",
            "readOnly": true,
            "description": "Generada; declarado − calculado."
          },
          "ajuste_movimiento_id": {
            "$ref": "#/components/schemas/UuidONulo",
            "description": "Obligatorio si y solo si hay diferencia."
          },
          "motivo": {
            "type": [
              "string",
              "null"
            ],
            "maxLength": 200,
            "description": "Obligatorio si hay diferencia: al menos 3 caracteres visibles, sin contar espacios, saltos de línea ni caracteres invisibles (23514, N2)."
          },
          "persona_id": {
            "$ref": "#/components/schemas/Uuid",
            "description": "Por omisión, la sesión (siempre la sesión)."
          },
          "creado_en": {
            "type": "string",
            "format": "date-time",
            "description": "Se acepta del dispositivo."
          }
        }
      },
      "FinImportacion": {
        "type": "object",
        "description": "Registro de una importación del hogar (**solo agregar**).",
        "properties": {
          "id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "hogar_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "archivo": {
            "type": "string",
            "minLength": 1,
            "maxLength": 255
          },
          "hoja": {
            "type": [
              "string",
              "null"
            ],
            "maxLength": 100
          },
          "filas_leidas": {
            "type": "integer",
            "minimum": 0
          },
          "filas_creadas": {
            "type": "integer",
            "minimum": 0
          },
          "filas_omitidas": {
            "type": "integer",
            "minimum": 0
          },
          "detalle": {
            "type": [
              "object",
              "array"
            ],
            "description": "Hasta 256 KB; no se copia a la bitácora."
          },
          "persona_id": {
            "$ref": "#/components/schemas/Uuid",
            "description": "Por omisión, la sesión (siempre la sesión)."
          },
          "creado_en": {
            "type": "string",
            "format": "date-time",
            "description": "Se acepta del dispositivo."
          }
        }
      },
      "FinSaldo": {
        "type": "object",
        "description": "Fila de la vista `fin_v_saldos`.",
        "properties": {
          "hogar_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "libro_id": {
            "$ref": "#/components/schemas/UuidONulo"
          },
          "cuenta_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "nombre": {
            "type": "string"
          },
          "tipo": {
            "type": "string"
          },
          "clase": {
            "type": "string",
            "enum": [
              "activo",
              "pasivo",
              "ingreso",
              "gasto",
              "ajuste",
              "apertura"
            ]
          },
          "liquida": {
            "type": "boolean"
          },
          "estado": {
            "type": "string",
            "enum": [
              "activa",
              "congelada",
              "cerrada",
              "archivada"
            ]
          },
          "saldo_centavos": {
            "$ref": "#/components/schemas/Centavos",
            "description": "Saldo confirmado con el signo de su clase (en una tarjeta, lo que se debe)."
          },
          "saldo_con_pendientes_centavos": {
            "$ref": "#/components/schemas/Centavos"
          }
        }
      },
      "FinGastoSemana": {
        "type": "object",
        "description": "Fila de la vista `fin_v_gasto_semana`.",
        "properties": {
          "hogar_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "libro_id": {
            "$ref": "#/components/schemas/UuidONulo"
          },
          "semana_inicio": {
            "type": "string",
            "format": "date"
          },
          "cuenta_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "nombre": {
            "type": "string"
          },
          "tipo": {
            "type": "string"
          },
          "gasto_centavos": {
            "$ref": "#/components/schemas/Centavos"
          }
        }
      },
      "FinAdultoConFinanzas": {
        "type": "object",
        "description": "Una fila de `fin_adultos_con_finanzas`.",
        "properties": {
          "persona_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "nombre_visible": {
            "type": "string",
            "maxLength": 80
          },
          "rol": {
            "type": "string",
            "enum": [
              "dueno",
              "coadministrador"
            ],
            "description": "Nunca familiar, cuidador ni casa."
          }
        }
      },
      "Aviso": {
        "type": "object",
        "description": "Propuesta (Fase 2).",
        "required": [
          "personas",
          "titulo"
        ],
        "properties": {
          "hogar_id": {
            "$ref": "#/components/schemas/Uuid"
          },
          "personas": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/Uuid"
            }
          },
          "titulo": {
            "type": "string",
            "maxLength": 80
          },
          "cuerpo": {
            "type": "string",
            "maxLength": 200
          },
          "ruta": {
            "type": "string",
            "description": "Ruta de la app que abre al tocar el aviso."
          }
        }
      },
      "PreguntaIa": {
        "type": "object",
        "description": "Propuesta (Fase 6). Sin nombres, montos ni datos clínicos.",
        "required": [
          "pregunta",
          "herramientas"
        ],
        "properties": {
          "pregunta": {
            "type": "string",
            "maxLength": 500
          },
          "herramientas": {
            "type": "array",
            "items": {
              "$ref": "#/components/schemas/Herramienta"
            }
          }
        }
      },
      "RespuestaIa": {
        "type": "object",
        "description": "Propuesta (Fase 6).",
        "properties": {
          "herramienta": {
            "type": [
              "string",
              "null"
            ]
          },
          "parametros": {
            "type": "object"
          },
          "texto": {
            "type": [
              "string",
              "null"
            ]
          }
        }
      },
      "FraseBocina": {
        "type": "object",
        "required": [
          "entity_id",
          "media_player_entity_id",
          "message"
        ],
        "properties": {
          "entity_id": {
            "type": "string",
            "description": "Motor de voz de Home Assistant."
          },
          "media_player_entity_id": {
            "type": "string",
            "description": "Bocina."
          },
          "message": {
            "type": "string",
            "maxLength": 200,
            "description": "Frase genérica, sin dinero ni datos clínicos."
          },
          "language": {
            "type": "string",
            "default": "es-MX"
          }
        }
      }
    }
  }
};
window.HUELLA_ESPECIFICACION_GRAVITY = 'fnv1a32:f7eaed1d';
