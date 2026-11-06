# Instrucciones para Claude Code — GRAVITY

GRAVITY es **la app única del proyecto Segundo Cerebro** (D1): laptop Windows con el sistema completo, teléfono Android con lo mínimo, tablet portátil de la casa y pulsera. Módulos: Finanzas, Hábitos, Cuidados, Alimentación, Casa y GRAVITY (el asistente que los une).

## Lee primero
1. `docs/DECISIONES.md` — decisiones D1 a D16 (mandan sobre el contrato v2.0).
2. `docs/ROADMAP.md` — fases, estado y **equipo de agentes** (sección 11).
3. `docs/specs/fase-0-cimientos.md` — estructura del repositorio, pila técnica y **convenciones obligatorias**.
4. `docs/DISENO_UX_UI.md` — estilos, pantallas, flujos y voz.
5. El diseño del módulo en `docs/modulos/` y la especificación de la fase en `docs/specs/`.

## Equipo de agentes
Los agentes especializados están en `.claude/agents/` (arquitecto, plataforma, diseno, backend, asistente, finanzas, habitos, cuidados, casa, alimentacion, calidad). Cada uno escribe solo en sus carpetas; el arquitecto integra y hace commit.

## Reglas que no se rompen
- Permisos en el servidor (RLS); cada persona ve solo lo de su rol (D5).
- El dinero y los datos clínicos **nunca** van a la IA en la nube ni a las bocinas (D3, D6).
- Dinero en centavos; semana en lunes; libro de movimientos solo-agregar.
- Sin secretos ni datos reales en el repositorio (`data/personal/` está ignorada).
- Especificación antes que código; pruebas en verde antes de entregar.

## Comandos
- App: `cd app && flutter analyze && flutter test`
- Paquetes de dominio: `cd paquetes/<paquete> && dart test`
- Base de datos: ver `supabase/README.md`

## Cómo trabajar
- Responde en español.
- No cambies decisiones confirmadas por tu cuenta: propón el cambio (qué y por qué).
