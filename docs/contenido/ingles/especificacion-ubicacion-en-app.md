# Especificación · Prueba de ubicación dentro de la app

> **Contexto:** nota general en `CONTEXTO.md`. La prueba y su regla de emparejamiento están en `prueba-de-nivel.md`. Versión interactiva en `prueba-ubicacion.html`.
> Estado: **propuesta; la sustituye la fase 2 del plan** (`docs/specs/fase-8-ingles-plan.md`, paquetes P2.1 a P2.4).
> **Corrección (15/nov/2026):** esta nota decía que la app no tenía código y que vivía en el repositorio de Hábitos. No es así: por D1 y D10 la app es GRAVITY y el módulo Hábitos existe en `app/lib/modulos/habitos` desde la Fase 3. Lo que falta es el bloque de inglés.

## 1. Regla

- Cada cuenta hace la prueba de ubicación **una sola vez**.
- El nivel resultante se guarda en el perfil de la cuenta y define el punto de inicio del curso (ver `prueba-de-nivel.md`, sección 4).
- Ninguna acción permite repetirla: no hay botón de "repetir" ni reinicio desde la interfaz.

## 2. Qué tiene que hacer la app

1. **Ofrecer la prueba** al entrar al curso por primera vez, antes de la lección 1.
2. **Calificar en el servidor o en la base de la cuenta,** no solo en la página. Una calificación hecha solo en el navegador se puede repetir cambiando de navegador o borrando datos.
3. **Guardar el resultado de forma permanente** en el perfil de la cuenta: nivel, fecha y versión de la prueba. Sin borrar ni sobrescribir.
4. **Bloquear la segunda aplicación** comprobando si la cuenta ya tiene un resultado registrado antes de mostrar la prueba.
5. **Iniciar el curso en el nivel asignado,** con el plan de inicio de `prueba-de-nivel.md`, sección 4.

## 3. Lo que esto no resuelve por sí solo

- Una página publicada fuera de la app (`prueba-ubicacion.html`) **no puede** garantizar una sola aplicación: cualquiera con el enlace puede abrirla y ver el resultado en su navegador. Por eso la regla vive en la app, con la cuenta de la persona.
- La escritura (parte 4) sigue necesitando una persona revisora. El nivel final puede quedar pendiente de esa revisión; esto se registra en el perfil como "pendiente de escritura".
- La parte de escucha sigue en texto hasta que se apruebe el audio.

## 4. Pendientes para implementarlo

1. Construirla en GRAVITY, dentro del módulo Hábitos (plan, fase 2). La prueba actual se rehace antes (paquete P2.1), porque ubica de más (revisión, ING-B5).
2. Definir el modelo de datos del perfil: campos de nivel, fecha, versión y estado de escritura.
3. Aprobar los saltos a B1+ y B2 desde la prueba (propuesta en `prueba-de-nivel.md`, sección 4).
4. Revisar la copia de la prueba en la app con la misma clave y reglas que este documento.
