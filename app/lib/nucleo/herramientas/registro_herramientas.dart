import '../contratos/roles.dart';
import '../permisos/permisos.dart';
import 'herramienta.dart';
import 'navegacion.dart';
import 'visibilidad_modulos.dart';

/// Módulos que no se desactivan: el núcleo de GRAVITY y los ajustes.
const Set<Modulo> modulosSiempreActivos = {Modulo.gravity, Modulo.ajustes};

/// La lista cerrada de herramientas de GRAVITY (D1).
///
/// Filtra por rol, por cuenta maestra y por módulos activos, y es el único
/// camino para ejecutar una herramienta: revisa el permiso, pide confirmación
/// a las que escriben y garantiza que el resultado de una herramienta solo
/// local no lleve nada para la IA (D3).
final class RegistroHerramientas {
  /// Valida cada herramienta y lanza [ArgumentError] si alguna no cumple:
  ///
  /// - El nombre tiene el formato `<modulo>.<accion>`, el prefijo es su
  ///   módulo y no se repite.
  /// - Si escribe, exige poder escribir o administrar ([Herramienta.accion]).
  /// - Declara al menos un rol, y cada rol puede usarla según la matriz de
  ///   permisos (D5, `nucleo/permisos/permisos.dart`): abrir el módulo si es
  ///   de navegación y hacer en él su [Herramienta.accion], sobre lo propio o
  ///   lo ajeno según [Herramienta.pertenencia] ([puedeSobre]; una de lectura
  ///   de lo ajeno vale si la usa la cuenta maestra, D19).
  /// - Quien en GRAVITY solo tiene su bandeja (la cuidadora, D18) solo puede
  ///   tener herramientas de la bandeja, y ninguna de Finanzas.
  /// - Si es de Finanzas o Cuidados, es [Herramienta.soloLocal] (D3), también
  ///   las de navegación: el dinero y los datos clínicos nunca van a la IA en
  ///   la nube. La regla no depende de que el autor recuerde la marca.
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
      if (h.escribe && h.accion == Accion.leer) {
        throw ArgumentError.value(
          h.nombre,
          'accion',
          'Una herramienta que escribe exige poder escribir o administrar',
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
        if (!_permite(h, rol) && !_permite(h, rol, esMaestra: true)) {
          throw ArgumentError.value(
            h.nombre,
            'roles',
            'La matriz de permisos no deja al rol ${rol.name} '
                '${_queNecesita(h)} ${nombreModulo(h.modulo)} (D5, D18)',
          );
        }
      }
      if (modulosSoloLocal.contains(h.modulo) && !h.soloLocal) {
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

  /// `true` si la matriz espejo deja a [rol] usar [h] ([esMaestra]: la
  /// sesión es la cuenta maestra, D19).
  ///
  /// - D18: quien en GRAVITY solo tiene su bandeja solo recibe herramientas
  ///   de la bandeja, y ninguna de Finanzas (sus gastos de cuidado se
  ///   registran desde Cuidados, Fase 5).
  /// - Navegación: abrir las pantallas del módulo, salvo la bandeja, que solo
  ///   pide leer GRAVITY (como su ruta en el router de la plataforma).
  /// - Después, poder hacer [Herramienta.accion] sobre lo propio o lo ajeno
  ///   ([puedeSobre]): la cuenta maestra lee lo ajeno de Finanzas y GRAVITY
  ///   y nunca lo escribe ni lo administra.
  /// - La cuenta maestra que no es la dueña es de solo lectura total
  ///   ([esSoloLectura]): solo navegación y lectura, ninguna herramienta que
  ///   escriba ni que abra una hoja de registro (D19, 23/oct).
  static bool _permite(Herramienta h, Rol rol, {bool esMaestra = false}) {
    // Solo un rol con Finanzas puede ser la cuenta maestra (como en el
    // servidor, `es_cuenta_maestra`); con otro rol la marca no amplía nada.
    final maestra = esMaestra && puedeSerCuentaMaestra(rol);
    // D19 (23/oct): la maestra con login propio, que no es la dueña, es de
    // solo lectura total ([esSoloLectura] de la plataforma): ni una
    // herramienta que escriba ni una que abra una hoja de registro, tampoco
    // para lo propio. Solo navegación y lectura. ([puedeSobre] ya le quita lo
    // que no es de leer; aquí se cierra también la hoja de registro.)
    if (esSoloLectura(rol, esMaestra: maestra) &&
        (h.accion != Accion.leer ||
            h.escribe ||
            (h is HerramientaNavegacion && h.hoja != null))) {
      return false;
    }
    final deBandeja = h.ambito == AmbitoHerramienta.solicitudes;
    if (soloBandejaEnGravity(rol) &&
        (!deBandeja || h.modulo == Modulo.finanzas)) {
      return false;
    }
    if (h is HerramientaNavegacion && !deBandeja && !puedeAbrir(rol, h.modulo)) {
      return false;
    }
    return puedeSobre(
      rol,
      h.modulo,
      h.accion,
      esDeLaPersona: h.pertenencia == Pertenencia.propia,
      esMaestra: maestra,
    );
  }

  static String _queNecesita(Herramienta h) => switch (h) {
    HerramientaNavegacion(accion: Accion.leer) => 'abrir',
    HerramientaNavegacion(accion: Accion.escribir) => 'abrir y escribir en',
    HerramientaNavegacion() => 'abrir y administrar',
    _ when h.accion == Accion.administrar => 'administrar',
    _ when h.accion == Accion.escribir => 'escribir en',
    _ => 'leer',
  };

  /// Todas las herramientas registradas, sin filtrar (para documentarlas).
  List<Herramienta> get todas => List.unmodifiable(_porNombre.values);

  /// Las herramientas que [rol] puede usar con [modulosActivos]
  /// (`null`: todos los módulos activos), en el orden en que se registraron.
  /// Con [esMaestra] (la cuenta maestra, D19) no aparece ninguna que escriba
  /// o administre lo ajeno y, si no es la dueña, tampoco ninguna que escriba
  /// ni abra una hoja de registro (solo lectura total, [esSoloLectura]).
  List<Herramienta> disponibles({
    required Rol rol,
    Set<Modulo>? modulosActivos,
    bool esMaestra = false,
  }) => List.unmodifiable(
    _porNombre.values.where(
      (h) => _motivo(h, rol, modulosActivos, esMaestra: esMaestra) == null,
    ),
  );

  /// La herramienta [nombre] si [rol] la puede usar; si no, `null`.
  Herramienta? buscar(
    String nombre, {
    required Rol rol,
    Set<Modulo>? modulosActivos,
    bool esMaestra = false,
  }) {
    final h = _porNombre[nombre];
    if (h == null ||
        _motivo(h, rol, modulosActivos, esMaestra: esMaestra) != null) {
      return null;
    }
    return h;
  }

  /// Ejecuta [nombre] con [parametros].
  ///
  /// - Si no existe para el rol (o para la cuenta maestra) o su módulo está
  ///   inactivo, lanza [HerramientaNoDisponible].
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
    final motivo = _motivo(
      h,
      ctx.rol,
      ctx.modulosActivos,
      esMaestra: ctx.esMaestra,
    );
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
    Set<Modulo>? modulosActivos, {
    required bool esMaestra,
  }) {
    if (!h.roles.contains(rol)) return MotivoNoDisponible.rolSinPermiso;
    // La matriz ya se revisó al registrar; se vuelve a mirar por si cambia.
    if (!_permite(h, rol, esMaestra: esMaestra)) {
      return esMaestra && _permite(h, rol)
          ? MotivoNoDisponible.cuentaMaestra
          : MotivoNoDisponible.rolSinPermiso;
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
