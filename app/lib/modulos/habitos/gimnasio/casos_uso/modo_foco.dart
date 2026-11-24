/// Modo foco para el gimnasio (spec 5.9 y 8.3, PG-11): una interfaz **sin
/// causa**. El generador solo recibe un booleano; nunca sabe qué hábito a
/// eliminar lo produjo.
///
/// El plan de un hábito a eliminar (Día D y días de foco) vive cifrado en lo
/// reservado. Para no abrirlo cada vez, esta clase guarda una **copia local**
/// mínima —rangos de fechas, sin nombre del hábito ni cantidades— en el almacén
/// seguro del equipo (`habitos.copia.<persona>`, la convención de copias locales
/// que borra la limpieza al salir o dar de baja). **No se sube a ninguna parte.**
/// Se **actualiza cuando la persona abre su sección reservada**.
///
/// Sin la llave en este equipo (laptop, o tablet sin el PIN) y sin copia, el
/// valor es `false` y [ModoFocoActivo.legible] dice que no se pudo leer
/// (`MensajesGimnasioApp.modoFocoNoLegible`).
library;

import 'dart:convert';

import 'package:habitos_dominio/habitos_dominio.dart';

import '../../../../nucleo/contratos/roles.dart';
import '../../../../nucleo/seguridad/almacen_seguro.dart';
import '../../../../nucleo/seguridad/limpieza_local.dart' show claveCopiaLocal;

/// ¿Hay modo foco ese día? (sin causa).
abstract interface class ModoFocoActivo {
  bool para(DateTime fecha);

  /// `false` si no se pudo saber en este equipo (sin llave ni copia).
  bool get legible;

  /// Los lunes de las semanas, entre [desde] y [hasta], en que hubo foco algún
  /// día: el ciclo de carga y descarga no cuenta esas semanas (5.9).
  List<DateTime> lunesEnFoco(DateTime desde, DateTime hasta);
}

/// Nunca hay foco (demostración y pruebas).
class SinModoFoco implements ModoFocoActivo {
  const SinModoFoco({this.legible = true});

  @override
  final bool legible;

  @override
  bool para(DateTime fecha) => false;

  @override
  List<DateTime> lunesEnFoco(DateTime desde, DateTime hasta) => const [];
}

/// Un rango de días de foco (incluyente).
class RangoFoco {
  const RangoFoco(this.desde, this.hasta);

  final DateTime desde;
  final DateTime hasta;

  bool contiene(DateTime f) {
    final d = soloDia(f);
    return !d.isBefore(desde) && !d.isAfter(hasta);
  }
}

class ModoFocoDeRangos implements ModoFocoActivo {
  const ModoFocoDeRangos(this.rangos, {this.legible = true});

  final List<RangoFoco> rangos;

  @override
  final bool legible;

  @override
  bool para(DateTime fecha) => rangos.any((r) => r.contiene(fecha));

  @override
  List<DateTime> lunesEnFoco(DateTime desde, DateTime hasta) {
    final r = <DateTime>[];
    for (
      var l = lunesDe(desde);
      !l.isAfter(soloDia(hasta));
      l = sumarDias(l, 7)
    ) {
      if (List.generate(7, (i) => sumarDias(l, i)).any(para)) r.add(l);
    }
    return r;
  }
}

/// La copia local de los rangos de foco de una persona.
class CopiaLocalFoco {
  CopiaLocalFoco(this._almacen, this.persona);

  final AlmacenSeguro _almacen;
  final String persona;

  String get _clave => claveCopiaLocal(Modulo.habitos, persona);

  String _f(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<Map<String, Object?>?> _leer() async {
    final t = await _almacen.leer(_clave);
    if (t == null) return null;
    try {
      return (jsonDecode(t) as Map).cast<String, Object?>();
    } catch (_) {
      return null;
    }
  }

  /// `null` si nunca se guardó una copia en este equipo.
  Future<ModoFocoDeRangos?> leer() async {
    final m = await _leer();
    final foco = m?['gim_foco'];
    if (foco is! Map) return null;
    final rangos = <RangoFoco>[];
    for (final e in foco.values) {
      if (e is! Map) continue;
      final d = DateTime.tryParse('${e['desde']}');
      final h = DateTime.tryParse('${e['hasta']}');
      if (d != null && h != null) rangos.add(RangoFoco(soloDia(d), soloDia(h)));
    }
    return ModoFocoDeRangos(rangos);
  }

  /// Anota el foco de un hábito ([clave]: `cigarrillo` o `azucar`): del Día D a
  /// Día D + días de foco − 1; sin Día D, se quita.
  Future<void> registrar(
    String clave, {
    DateTime? diaD,
    required int focoDias,
  }) async {
    final m = await _leer() ?? {};
    final foco = ((m['gim_foco'] as Map?) ?? {}).cast<String, Object?>();
    if (diaD == null) {
      foco.remove(clave);
    } else {
      final d = soloDia(diaD);
      foco[clave] = {'desde': _f(d), 'hasta': _f(sumarDias(d, focoDias - 1))};
    }
    m['gim_foco'] = foco;
    await _almacen.escribir(_clave, jsonEncode(m));
  }

  /// Marca que ya se leyó lo reservado en este equipo (aunque no haya foco).
  Future<void> marcarLeido() async {
    final m = await _leer() ?? {};
    m['gim_foco'] ??= <String, Object?>{};
    await _almacen.escribir(_clave, jsonEncode(m));
  }
}
