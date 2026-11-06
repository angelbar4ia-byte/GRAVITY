/// Limpieza de lo que la app guarda **en el equipo** por persona (M5 de la
/// revisión de la Fase 1; D5: al darlos de baja pierden el acceso de
/// inmediato; Fase 0, I3).
///
/// Cada módulo puede guardar una **copia local** de lo suyo para trabajar sin
/// señal (p. ej. Finanzas: libros, cuentas con su límite, categorías, sobres,
/// nombres de personas). Esa copia nunca debe quedar en el equipo de quien ya
/// no está: al **salir**, al detectar una **baja** y al **quitar a la persona
/// de la tablet** se borra.
///
/// Dos mecanismos, con una sola llamada ([LimpiezaLocal.alQuitarPersona]):
///
/// 1. **Convención** (el almacén seguro): la copia de [modulo] de una persona
///    vive en [claveCopiaLocal] = `<modulo>.copia.<personaId>`. No hace falta
///    registrar nada: todo lo que siga la convención se borra. Es la clave de
///    `CopiaLocalFinanzas` (`finanzas.copia.<personaId>`).
/// 2. **Ganchos** ([LimpiezaLocal.registrar]): para lo que un módulo guarde
///    fuera del almacén seguro (otra base, archivos, memoria). Reciben el id
///    de la persona.
///
/// Una limpieza que falla se anota y sigue con lo demás: nunca impide salir ni
/// quitar a alguien.
library;

import 'package:flutter/foundation.dart';

import '../cola/bandeja_salida.dart';
import '../contratos/roles.dart';
import 'almacen_seguro.dart';

/// Limpia lo que un módulo guardó en el equipo de [personaId].
typedef LimpiezaPorPersona = Future<void> Function(String personaId);

/// Clave, en el almacén seguro, de la copia local de [modulo] de [personaId].
String claveCopiaLocal(Modulo modulo, String personaId) =>
    '${modulo.name}.copia.$personaId';

class LimpiezaLocal {
  LimpiezaLocal(
    this._almacen, {
    Iterable<LimpiezaPorPersona> ganchos = const [],
    BandejaDeSalida? bandeja,
  }) : _ganchos = [...ganchos],
       bandeja = bandeja ?? BandejaDeSalida(_almacen);

  final AlmacenSeguro _almacen;
  final List<LimpiezaPorPersona> _ganchos;

  /// Los permisos de subida de la bandeja de salida (D14, 23/oct/2026): se
  /// comparte la instancia con la subida para que el candado sea uno solo.
  final BandejaDeSalida bandeja;

  /// La cuenta del equipo (Hogar) cerró sesión: con nadie dentro, no debe
  /// quedar en el equipo la credencial en claro de quien dejó algo por subir.
  /// Se **sella** (solo su PIN la abre) y lo pendiente espera a que esa
  /// persona vuelva a entrar (B1 de la revisión de la Fase 1b).
  Future<void> alCerrarElEquipo() => _sinFallar(
    bandeja.sellarTodos,
    'las credenciales de la bandeja de salida',
  );

  /// Agrega un gancho para lo que el módulo guarda fuera del almacén seguro.
  void registrar(LimpiezaPorPersona gancho) => _ganchos.add(gancho);

  /// Borra del equipo lo guardado de [personaId]: las copias locales de todos
  /// los módulos ([claveCopiaLocal]) y lo de cada gancho registrado.
  Future<void> alQuitarPersona(String personaId) async {
    for (final modulo in Modulo.values) {
      await _sinFallar(
        () => _almacen.borrar(claveCopiaLocal(modulo, personaId)),
        'la copia de ${modulo.name}',
      );
    }
    for (final gancho in _ganchos) {
      await _sinFallar(() => gancho(personaId), 'un gancho');
    }
  }

  /// Borra las copias locales de **cualquier** persona. Para una baja
  /// detectada cuando no se sabe de quién era la sesión (no quedó guardada).
  /// Las copias se vuelven a bajar del servidor la próxima vez que cada
  /// persona abra su módulo con señal. No corre los ganchos (piden una
  /// persona).
  Future<void> alQuitarTodas() async {
    final List<String> claves;
    try {
      claves = await _almacen.claves();
    } catch (error) {
      debugPrint('No se pudieron listar las copias locales: $error');
      return;
    }
    final prefijos = [for (final m in Modulo.values) '${m.name}.copia.'];
    for (final clave in claves) {
      if (!prefijos.any(clave.startsWith)) continue;
      await _sinFallar(() => _almacen.borrar(clave), 'una copia ($clave)');
    }
  }

  static Future<void> _sinFallar(
    Future<void> Function() tarea,
    String que,
  ) async {
    try {
      await tarea();
    } catch (error) {
      debugPrint('No se pudo borrar $que del equipo: $error');
    }
  }
}
