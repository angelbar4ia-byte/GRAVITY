import 'fecha.dart';
import 'libro.dart';

/// Libros de Finanzas (D19; sección 4.5 de la especificación de la Fase 1).
///
/// Cada persona adulta con Finanzas lleva su **libro personal**; hay **libros
/// compartidos** (por ejemplo, "Gastos de la casa") con sus miembros, y el
/// **libro representado** de papá, que llevan sus albaceas (1 o 2) en su
/// nombre. Una **cuenta maestra** por hogar lee todo y no escribe en lo ajeno.
///
/// La verdad de los permisos está en el servidor (`fin_puede`); esto es su
/// espejo para la interfaz.
enum TipoLibro { personal, compartido, representado }

/// Papel de una persona en un libro (`fin_libro_miembros.papel`).
enum PapelLibro { titular, miembro, albacea, albaceaSuplente }

/// Una persona en un libro, con su vigencia.
///
/// **Vigencia (misma regla que el servidor, `fin_libro_miembros`):** vigente
/// si `desde <= ahora` y (`hasta` es nulo o `hasta > ahora`). Con fechas de
/// día eso es: [desde] **inclusivo** (el día de `desde` ya es vigente) y
/// [hasta] **exclusivo** (el día de `hasta` ya no lo es). La app manda ambos
/// como el inicio del día local, así que el día del cambio de albacea el
/// espejo de la interfaz y el servidor coinciden (M1 de la revisión de la
/// Fase 1).
///
/// Ojo: es distinto de las fechas `hasta` de `fin_vigencias_ingreso` y
/// `fin_compromisos`, que son `date` y el servidor trata como inclusivas
/// (`daterange(…, '[]')`): ver [VigenciaIngreso].
class MiembroLibro {
  final String personaId;
  final PapelLibro papel;

  /// Primer día en que es vigente (inclusivo).
  final Fecha? desde;

  /// Primer día en que **ya no** es vigente (exclusivo).
  final Fecha? hasta;

  const MiembroLibro({
    required this.personaId,
    required this.papel,
    this.desde,
    this.hasta,
  });

  bool vigenteEn(Fecha dia) =>
      (desde == null || !dia.antesDe(desde!)) &&
      (hasta == null || dia.antesDe(hasta!));
}

/// Error de configuración de un libro.
class ErrorLibros implements Exception {
  final String mensaje;
  const ErrorLibros(this.mensaje);

  @override
  String toString() => 'ErrorLibros: $mensaje';
}

/// Un libro (`fin_libros`).
class Libro {
  final String id;
  final String nombre;
  final TipoLibro tipo;

  /// Persona dueña del libro: obligatoria en `personal` y `representado` (en
  /// este, la persona representada, que no tiene cuenta); nula en
  /// `compartido`.
  final String? titularId;
  final bool activo;
  final List<MiembroLibro> miembros;

  Libro({
    required this.id,
    required this.nombre,
    required this.tipo,
    this.titularId,
    this.activo = true,
    List<MiembroLibro> miembros = const [],
  }) : miembros = List.unmodifiable(miembros);

  List<MiembroLibro> vigentes(Fecha dia) =>
      miembros.where((m) => m.vigenteEn(dia)).toList();

  /// Papel vigente de [personaId], o nulo si no es miembro.
  PapelLibro? papelDe(String personaId, Fecha dia) {
    for (final m in vigentes(dia)) {
      if (m.personaId == personaId) return m.papel;
    }
    return null;
  }

  /// `true` si hay un albacea (no suplente) vigente.
  bool hayAlbaceaVigente(Fecha dia) =>
      vigentes(dia).any((m) => m.papel == PapelLibro.albacea);

  /// Revisa las reglas de 4.5 (`fin_libro_miembros`). Lanza [ErrorLibros].
  ///
  /// - `personal`: con titular, y el titular es su único miembro.
  /// - `representado`: con titular (la persona representada, que no es
  ///   miembro), 1 albacea y, opcional, 1 suplente (máximo 2).
  /// - `compartido`: sin titular y con 2 o más miembros.
  void validar(Fecha dia) {
    final v = vigentes(dia);
    switch (tipo) {
      case TipoLibro.personal:
        if (titularId == null) {
          throw const ErrorLibros('Un libro personal necesita su titular');
        }
        if (v.length != 1 ||
            v.single.personaId != titularId ||
            v.single.papel != PapelLibro.titular) {
          throw const ErrorLibros(
            'En un libro personal el titular es su único miembro',
          );
        }
      case TipoLibro.representado:
        if (titularId == null) {
          throw const ErrorLibros(
            'El libro representado necesita a la persona que representa',
          );
        }
        final albaceas = v.where((m) => m.papel == PapelLibro.albacea).length;
        final suplentes = v
            .where((m) => m.papel == PapelLibro.albaceaSuplente)
            .length;
        final otros = v.length - albaceas - suplentes;
        if (albaceas != 1 || suplentes > 1 || otros != 0) {
          throw const ErrorLibros(
            'El libro representado lleva 1 albacea y, si quieres, 1 suplente',
          );
        }
        if (v.any((m) => m.personaId == titularId)) {
          throw const ErrorLibros(
            'La persona representada no es albacea de su propio libro',
          );
        }
      case TipoLibro.compartido:
        if (titularId != null) {
          throw const ErrorLibros('Un libro compartido no tiene titular');
        }
        if (v.length < 2 || v.any((m) => m.papel != PapelLibro.miembro)) {
          throw const ErrorLibros('Un libro compartido tiene 2 o más miembros');
        }
    }
  }

  @override
  String toString() => 'Libro($nombre, ${tipo.name})';
}

/// Lo que una persona puede hacer en un libro (espejo de `fin_puede`).
class PermisoLibro {
  final bool leer;
  final bool escribir;
  final bool administrar;

  /// En el libro representado, cada movimiento va **en nombre de** la persona
  /// representada, con motivo obligatorio (regla 3 de 4.5).
  final bool enNombreDe;

  /// Lee como cuenta maestra un libro del que no es miembro: solo lectura, y
  /// la app registra la consulta (`fin_registrar_consulta_maestra`).
  final bool comoMaestra;

  const PermisoLibro({
    this.leer = false,
    this.escribir = false,
    this.administrar = false,
    this.enNombreDe = false,
    this.comoMaestra = false,
  });

  static const ninguno = PermisoLibro();

  bool get soloLectura => leer && !escribir;
}

/// Permiso de [personaId] en [libro] (regla de `fin_puede`, 4.5):
///
/// - **leer:** miembro vigente o cuenta maestra.
/// - **escribir:** miembro vigente (titular, miembro o albacea; en el
///   representado siempre con motivo). El **suplente** escribe solo si no hay
///   albacea vigente (D17). La cuenta maestra **nunca** escribe en un libro
///   del que no es miembro.
/// - **administrar:** titular de un personal; cualquier miembro de un
///   compartido; albacea de un representado (el suplente, solo si no hay
///   albacea vigente).
///
/// [rolConFinanzas] es `false` si el rol de la persona no tiene Finanzas
/// (familiar, cuidador, casa): entonces nada.
PermisoLibro permisoEnLibro(
  Libro libro,
  String personaId, {
  required Fecha hoy,
  bool esMaestra = false,
  bool rolConFinanzas = true,
}) {
  if (!rolConFinanzas || !libro.activo) {
    return esMaestra && rolConFinanzas
        ? const PermisoLibro(leer: true, comoMaestra: true)
        : PermisoLibro.ninguno;
  }
  final papel = libro.papelDe(personaId, hoy);
  if (papel == null) {
    return esMaestra
        ? const PermisoLibro(leer: true, comoMaestra: true)
        : PermisoLibro.ninguno;
  }
  // El suplente solo actúa cuando no hay albacea vigente (D17).
  final suplenteEnEspera =
      papel == PapelLibro.albaceaSuplente && libro.hayAlbaceaVigente(hoy);
  final administra = switch (libro.tipo) {
    TipoLibro.personal => papel == PapelLibro.titular,
    TipoLibro.compartido => true,
    TipoLibro.representado =>
      papel == PapelLibro.albacea ||
          (papel == PapelLibro.albaceaSuplente && !suplenteEnEspera),
  };
  return PermisoLibro(
    leer: true,
    escribir: !suplenteEnEspera,
    administrar: administra,
    enNombreDe: libro.tipo == TipoLibro.representado,
  );
}

/// Libros que [personaId] puede ver, en el orden del selector: su libro
/// personal, los compartidos, los representados y, para la cuenta maestra,
/// los ajenos al final (cada grupo por nombre).
List<Libro> librosVisibles(
  Iterable<Libro> libros,
  String personaId, {
  required Fecha hoy,
  bool esMaestra = false,
}) {
  int grupo(Libro l) {
    final papel = l.papelDe(personaId, hoy);
    if (papel == null) return 4;
    return switch (l.tipo) {
      TipoLibro.personal => 0,
      TipoLibro.compartido => 1,
      TipoLibro.representado => 2,
    };
  }

  final visibles =
      libros
          .where(
            (l) => permisoEnLibro(
              l,
              personaId,
              hoy: hoy,
              esMaestra: esMaestra,
            ).leer,
          )
          .toList()
        ..sort((a, b) {
          final g = grupo(a).compareTo(grupo(b));
          return g != 0 ? g : a.nombre.compareTo(b.nombre);
        });
  return visibles;
}

/// Prefijo del id de las cuentas virtuales de otros libros.
const String prefijoOtroLibro = 'otro-libro:';

/// Id de la cuenta virtual que representa al libro [libroId] (o a un libro
/// que no se ve, si es nulo).
String idCuentaOtroLibro(String? libroId) =>
    '$prefijoOtroLibro${libroId ?? '?'}';

/// `true` si [cuentaId] es una cuenta virtual de otro libro.
bool esCuentaDeOtroLibro(String cuentaId) =>
    cuentaId.startsWith(prefijoOtroLibro);

/// Arma la **vista de un libro** (D19, reglas 1 y 2 de 4.5): sus cuentas, las
/// cuentas de gasto del hogar y una cuenta virtual por cada otro libro con el
/// que hay movimientos, con los movimientos que tocan alguna cuenta del
/// libro. Una aportación a un compartido sale del banco personal hacia la
/// cuenta virtual "Gastos de la casa" en la vista personal y entra al banco
/// compartido desde la cuenta virtual del libro personal en la vista del
/// compartido: el mismo movimiento se ve en los dos y cada uno cuadra.
///
/// Las cuentas que no están en [cuentas] (de libros que la persona no ve)
/// se juntan en una sola cuenta virtual sin nombre de libro.
LibroMovimientos vistaDelLibro({
  required String libroId,
  required Iterable<Cuenta> cuentas,
  required Iterable<Movimiento> movimientos,
  Map<String, String> nombresDeLibros = const {},
}) {
  final porId = {for (final c in cuentas) c.id: c};
  final propias = <String>{
    for (final c in cuentas)
      if (c.libroId == libroId) c.id,
  };
  final virtuales = <String, Cuenta>{};
  String traducir(String cuentaId) {
    final c = porId[cuentaId];
    if (c != null && (c.libroId == libroId || c.libroId == null)) {
      return cuentaId;
    }
    final otro = c?.libroId;
    final id = idCuentaOtroLibro(otro);
    virtuales.putIfAbsent(
      id,
      () => Cuenta(
        id: id,
        nombre: otro == null
            ? 'Otro libro'
            : (nombresDeLibros[otro] ?? 'Otro libro'),
        tipo: TipoCuenta.otroLibro,
        libroId: otro,
      ),
    );
    return id;
  }

  final delLibro = <Movimiento>[];
  for (final m in movimientos) {
    if (!propias.contains(m.cuentaOrigenId) &&
        !propias.contains(m.cuentaDestinoId)) {
      continue;
    }
    final origen = traducir(m.cuentaOrigenId);
    final destino = traducir(m.cuentaDestinoId);
    delLibro.add(
      origen == m.cuentaOrigenId && destino == m.cuentaDestinoId
          ? m
          : m.conCuentas(origen, destino),
    );
  }
  return LibroMovimientos.restaurar(
    cuentas: [
      for (final c in cuentas)
        if (c.libroId == libroId || c.libroId == null) c,
      ...virtuales.values,
    ],
    movimientos: delLibro,
    validar: false,
  );
}
