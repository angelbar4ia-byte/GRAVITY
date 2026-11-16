# Contenido de inglés en datos (`gravity-ingles-v1`)

> Estado (16/nov/2026): el plan está **aprobado por el dueño** (`docs/specs/fase-8-ingles-plan.md`, decisiones D-ING-1 a 8, registradas en D29) y el formato (`docs/specs/fase-8-ingles-formato.md`) sigue en propuesta. La herramienta `herramientas/ingles` ya valida (`validar` e `informe`). Aquí viven los contratos y los ejemplos patrón; el contenido del curso empieza con la matriz de niveles (paquete P1.3).

## Qué hay

| Carpeta | Contenido | Estado |
|---|---|---|
| `ejemplos/` | Nueve archivos patrón: marcan la calidad exigida y serán casos de prueba del validador | Escritos, en `borrador`; pendientes de resolución a ciegas (paquete P1.4a). Su cuaderno sin respuestas: `docs/contenido/ingles/generado/cuaderno-ejemplos-patron.md` |
| `formatos/` | Nueve contratos: seis de exámenes oficiales (A2 Key, B1 Preliminary, B2 First, TOEIC L&R, TOEIC S&W y TOEFL iBT 2026, cada dato con la página del manual) y tres propios de GRAVITY (`gravity-sesion-60`, `gravity-ubicacion`, `gravity-escalon`, cada dato con su origen en un documento del proyecto o en una decisión del dueño) | En `borrador`. Quedan datos marcados `pendiente: true`, con su nota |
| `niveles.yaml`, `unidades/`, `formas/`, `curso/`, `revisiones/` | Los crea el plan (paquetes P1.3 y siguientes) | Aún no existen |

## Reglas

1. Lo que está aquí es la fuente. El cuaderno, la clave y lo que carga la app se generan; no se editan a mano.
2. La primera opción de cada pregunta es la correcta. La letra se sortea al exportar.
3. Ningún archivo afirma que está completo, verificado o aprobado por su cuenta: el estado lo comprueba la herramienta.
4. Todo es contenido propio. De los manuales oficiales solo se toma el formato.
