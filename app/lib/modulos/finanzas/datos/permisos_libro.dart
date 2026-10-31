/// Lo que una persona puede hacer en un libro, con lo cargado: el espejo de
/// `fin_puede` (dominio) más lo que el servidor dijo donde el espejo no
/// alcanza (el suplente del libro de papá; I4).
library;

import 'package:finanzas_dominio/finanzas_dominio.dart';

import 'repositorio.dart';

/// Permiso de [personaId] en [libro] según [carga].
///
/// - [soloLectura]: la cuenta maestra que **no es la dueña** nunca registra ni
///   administra nada, tampoco lo suyo (D19, 23/oct/2026).
/// - Si el servidor dio su veredicto para este libro (`permisosServidor`), es
///   el que manda para escribir y administrar: el suplente escribe cuando el
///   albacea ya no es un adulto con Finanzas del hogar, algo que quien no es el
///   dueño no puede ver en las membresías.
PermisoLibro permisoDeCarga(
  CargaFinanzas carga,
  Libro libro,
  String personaId, {
  required Fecha hoy,
  bool esMaestra = false,
  bool soloLectura = false,
}) {
  final p = permisoEnLibro(
    libro,
    personaId,
    hoy: hoy,
    esMaestra: esMaestra,
    soloLectura: soloLectura,
  );
  final servidor = carga.permisosServidor[libro.id];
  if (servidor == null || !p.leer || soloLectura || libro.archivado) return p;
  return PermisoLibro(
    leer: true,
    escribir: servidor.escribir,
    administrar: servidor.administrar,
    enNombreDe: p.enNombreDe,
    comoMaestra: p.comoMaestra,
    comoLector: p.comoLector,
  );
}

/// `true` si el cargo [papel] (albacea o suplente) del libro de papá [libro] está
/// **vacío**: nadie vigente que siga siendo adulto con Finanzas del hogar
/// ([adultos], lo que dice `fin_adultos_con_finanzas`). Si el cargo lo ocupa
/// alguien que ya se fue o perdió el rol, también cuenta como vacío y el dueño
/// puede volver a nombrarlo (`fin_nombrar_albacea`). Con [adultos] vacío (no se
/// sabe) se da por ocupado.
bool cargoVacioEnLibro(
  Libro libro,
  PapelLibro papel,
  Set<String> adultos,
  Fecha hoy,
) =>
    libro.tipo == TipoLibro.representado &&
    !libro
        .vigentes(hoy)
        .any(
          (m) =>
              m.papel == papel &&
              (adultos.isEmpty || adultos.contains(m.personaId)),
        );
