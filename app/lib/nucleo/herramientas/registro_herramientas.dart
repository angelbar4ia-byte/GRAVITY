import '../contratos/roles.dart';
import '../permisos/permisos.dart';
import 'herramienta.dart';
import 'navegacion.dart';

/// Módulos que no se desactivan: el núcleo de GRAVITY y los ajustes.
const Set<Modulo> modulosSiempreActivos = {Modulo.gravity, Modulo.ajustes};

/// Módulos con dinero o datos clínicos (D3): sus herramientas son solo locales,
/// salvo las de navegación ([HerramientaNavegacion]), que no leen datos.
const Set<Modulo> modulosSoloLocal = {Modulo.finanzas, Modulo.cuidados};

/// La lista cerrada de herramientas de GRAVITY (D1).
///
/// Filtra por rol y por módulos activos, y es el único camino para ejecutar
/// una herramienta: revisa el permiso, pide confirmación a las que escriben y
/// garantiza que el resultado de una herramienta solo local no lleve nada
/// para la IA (D3).
final class RegistroHerramientas {
  /// Valida cada herramienta y lanza [ArgumentError] si alguna no cumple:
  ///
  /// - El nombre tiene el formato `<modulo>.<accion>`, el prefijo es su
  ///   módulo y no se repite.
  /// - Declara al menos un rol, y cada rol puede usarla según la matriz de
  ///   permisos (D5, `nucleo/permisos/permisos.dart`): abrir el módulo si es
  ///   de navegación, escribir en él si [Herramienta.escribe], o leerlo.
  /// - Si es de Finanzas o Cuidados y no es de navegación, es
  ///   [Herramienta.soloLocal] (D3): el dinero y los datos clínicos nunca van
  ///   a la IA en la nube. La regla no depende de que el autor recuerde la marca.
  RegistroHerramientas(Iterable<Herramienta> herramientas)
    : _porNombre = _indexar(herramientas);

  final Map<String, Herramienta> _porNombre;

  static Map<String, Herramienta> _indexar(Iterable<Herramienta> herramientas) {
    final porNombre = <String, Herramienta>{};
    for (final h in herramientas) {
      if (!formatoNombreHerramienta.hasMatch(h.nombre)) {
        throw ArgumentError.value(
          h.nombre,
          'nombre',
          'Debe tener la forma <modulo>.<accion>, sin acentos ni mayúsculas',
        );
      }
      final prefijo = h.nombre.split('.').first;
      if (prefijo != h.modulo.name) {
        throw ArgumentError.value(
          h.nombre,
          'nombre',
          'El prefijo debe ser el módulo "${h.modulo.name}"',
        );
      }
      if (h.roles.isEmpty) {
        throw ArgumentError.value(
          h.nombre,
          'roles',
          'Debe declarar al menos un rol',
        );
      }
      for (final rol in h.roles) {
        if (!_matrizPermite(h, rol)) {
          throw ArgumentError.value(
            h.nombre,
            'roles',
            'La matriz de permisos no deja al rol ${rol.name} '
                '${_queNecesita(h)} ${nombreModulo(h.modulo)} (D5)',
          );
        }
      }
      if (modulosSoloLocal.contains(h.modulo) &&
          !h.soloLocal &&
          h is! HerramientaNavegacion) {
        throw ArgumentError.value(
          h.nombre,
          'soloLocal',
          'Las herramientas de ${nombreModulo(h.modulo)} deben ser solo '
              'locales: su resultado nunca va a la IA en la nube (D3)',
        );
      }
      if (porNombre.containsKey(h.nombre)) {
        throw ArgumentError.value(h.nombre, 'nombre', 'Herramienta repetida');
      }
      porNombre[h.nombre] = h;
    }
    return Map.unmodifiable(porNombre);
  }

  /// `true` si la matriz espejo deja a [rol] usar [h]: abrir el módulo si es
  /// de navegación; escribir en él si escribe; leerlo si no.
  static bool _matrizPermite(Herramienta h, Rol rol) => switch (h) {
    HerramientaNavegacion() => puedeAbrir(rol, h.modulo),
    _ when h.escribe => puede(rol, h.modulo, Accion.escribir),
    _ => puede(rol, h.modulo, Accion.leer),
  };

  static String _queNecesita(Herramienta h) => switch (h) {
    HerramientaNavegacion() => 'abrir',
    _ when h.escribe => 'escribir en',
    _ => 'leer',
  };

  /// Todas las herramientas registradas, sin filtrar (para documentarlas).
  List<Herramienta> get todas => List.unmodifiable(_porNombre.values);

  /// Las herramientas que [rol] puede usar con [modulosActivos]
  /// (`null`: todos los módulos activos), en el orden en que se registraron.
  List<Herramienta> disponibles({
    required Rol rol,
    Set<Modulo>? modulosActivos,
  }) => List.unmodifiable(
    _porNombre.values.where((h) => _motivo(h, rol, modulosActivos) == null),
  );

  /// La herramienta [nombre] si [rol] la puede usar; si no, `null`.
  Herramienta? buscar(
    String nombre, {
    required Rol rol,
    Set<Modulo>? modulosActivos,
  }) {
    final h = _porNombre[nombre];
    if (h == null || _motivo(h, rol, modulosActivos) != null) return null;
    return h;
  }

  /// Ejecuta [nombre] con [parametros].
  ///
  /// - Si no existe para el rol o su módulo está inactivo, lanza
  ///   [HerramientaNoDisponible].
  /// - Si escribe y [ContextoHerramienta.confirmado] es `false`, no la ejecuta:
  ///   devuelve un resultado con `requiereConfirmacion` y el texto de la
  ///   tarjeta de confirmación.
  /// - Si es solo local, el resultado nunca lleva `paraIa`, aunque la
  ///   herramienta lo haya puesto, y si falla lanza [FalloHerramienta] sin el
  ///   mensaje del error original (podría llevar cifras).
  Future<ResultadoHerramienta> ejecutar(
    String nombre,
    Map<String, Object?> parametros,
    ContextoHerramienta ctx,
  ) async {
    final h = _porNombre[nombre];
    if (h == null) {
      throw HerramientaNoDisponible(nombre, MotivoNoDisponible.noExiste);
    }
    final motivo = _motivo(h, ctx.rol, ctx.modulosActivos);
    if (motivo != null) throw HerramientaNoDisponible(nombre, motivo);

    if (h.escribe && !ctx.confirmado) {
      return ResultadoHerramienta.pendienteDeConfirmacion(
        h,
        contenido: h.resumenConfirmacion(parametros),
      );
    }

    final ResultadoHerramienta resultado;
    try {
      resultado = await h.ejecutar(parametros, ctx);
    } catch (error, pila) {
      if (!h.soloLocal) rethrow;
      Error.throwWithStackTrace(
        FalloHerramienta(h.nombre, causaLocal: error),
        pila,
      );
    }
    return _sanear(h, resultado);
  }

  static MotivoNoDisponible? _motivo(
    Herramienta h,
    Rol rol,
    Set<Modulo>? modulosActivos,
  ) {
    // La matriz ya se revisó al registrar; se vuelve a mirar por si cambia.
    if (!h.roles.contains(rol) || !_matrizPermite(h, rol)) {
      return MotivoNoDisponible.rolSinPermiso;
    }
    if (modulosActivos != null &&
        !modulosSiempreActivos.contains(h.modulo) &&
        !modulosActivos.contains(h.modulo)) {
      return MotivoNoDisponible.moduloInactivo;
    }
    return null;
  }

  /// Rehace el resultado con los datos de la herramienta registrada: así una
  /// herramienta no puede hacerse pasar por otra ni saltarse [soloLocal].
  static ResultadoHerramienta _sanear(Herramienta h, ResultadoHerramienta r) {
    if (r.nombreHerramienta == h.nombre &&
        r.soloLocal == h.soloLocal &&
        (!h.soloLocal || r.paraIa == null)) {
      return r;
    }
    return r.requiereConfirmacion
        ? ResultadoHerramienta.pendienteDeConfirmacion(
            h,
            contenido: r.contenido,
          )
        : ResultadoHerramienta(h, contenido: r.contenido, paraIa: r.paraIa);
  }
}
