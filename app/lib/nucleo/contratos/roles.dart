/// Contrato compartido entre agentes (dueño: arquitecto).
/// Roles, módulos y acciones de D5 y de docs/specs/fase-0-cimientos.md (sección 5).
/// La verdad de los permisos está en el servidor (RLS); esto solo sirve para
/// ocultar en la interfaz lo que no corresponde.
library;

enum Rol { dueno, coadministrador, familiar, cuidador, casa }

enum Modulo { gravity, finanzas, habitos, cuidados, alimentacion, casa, ajustes }

enum Accion { leer, escribir, administrar }
