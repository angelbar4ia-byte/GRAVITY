/// Subida diferida de sobres (Fase 3, regla 92 y 93): los sobres de
/// `habitos_sensibles` se suben **en lote**, al cerrar el día y como máximo una
/// vez cada 6 horas con señal, o al instante si la persona pulsa
/// *Sincronizar*, con la hora del servidor, para que el servidor no vea cuándo
/// ocurrió cada registro. Van por la cola sin conexión **ya cifrados**
/// (`habitos.sobres` → `hab_subir_sobres`).
library;

import 'dart:convert';

import '../cola/cola_sin_conexion.dart';
import '../seguridad/almacen_seguro.dart';
import 'llaves_habitos.dart';
import 'sobres.dart';

/// Tipo de la cola para un lote de sobres. Lleva el prefijo de lo personal
/// (`habitos.`): nunca sale con el origen "tablet de la casa".
const tipoColaSobres = 'habitos.sobres';

/// Función del servidor a la que sube ese tipo.
const funcionSubirSobres = 'hab_subir_sobres';

/// Cada cuánto, como máximo, sube el diario sensible sin que se pida.
const esperaEntreSubidas = Duration(hours: 6);

/// Modo de cada tipo, guardado en el equipo (`hab_modos` es la verdad en el
/// servidor; esto es la copia local para decidir sin señal). Por omisión,
/// `solo_telefono`: nada sale hasta que la persona active la nube.
class ModosLocales {
  ModosLocales(this._almacen);

  final AlmacenSeguro _almacen;

  static String _clave(String persona, TipoSensible tipo) =>
      'hab.modo.$persona.${tipo.valor}';

  Future<ModoSensible> modo(String persona, TipoSensible tipo) async {
    final v = await _almacen.leer(_clave(persona, tipo));
    return ModoSensible.values.firstWhere(
      (m) => m.valor == v,
      orElse: () => ModoSensible.soloTelefono,
    );
  }

  Future<void> fijar(String persona, TipoSensible tipo, ModoSensible modo) =>
      _almacen.escribir(_clave(persona, tipo), modo.valor);

  Future<void> borrar(String persona) async {
    for (final t in TipoSensible.values) {
      await _almacen.borrar(_clave(persona, t));
    }
  }
}

/// ¿Toca subir ya? [forzar] es *Sincronizar*.
bool tocaSubir({
  required DateTime ahora,
  required DateTime? ultimaSubida,
  bool forzar = false,
}) =>
    forzar ||
    ultimaSubida == null ||
    !ahora.isBefore(ultimaSubida.add(esperaEntreSubidas));

class SubidaDiferidaDeSobres {
  SubidaDiferidaDeSobres({
    required this.sobres,
    required this.modos,
    required this.cola,
    required this.almacen,
    DateTime Function()? reloj,
  }) : _reloj = reloj ?? DateTime.now;

  final AlmacenDeSobres sobres;
  final ModosLocales modos;
  final ColaSinConexion cola;
  final AlmacenSeguro almacen;
  final DateTime Function() _reloj;

  static String _claveUltima(String persona) => 'hab.ultima_subida.$persona';

  Future<DateTime?> ultimaSubida(String persona) async {
    final v = await almacen.leer(_claveUltima(persona));
    return v == null ? null : DateTime.tryParse(v);
  }

  /// Junta lo que falta por subir de los tipos en **nube cifrada** y lo encola
  /// en lotes de [maximoSobresPorLlamada], ya cifrado. Se llama al cerrar el día
  /// y al abrir la app; solo sube si pasaron 6 horas desde la última vez (o si
  /// [forzar], que es *Sincronizar*). Los tipos en
  /// `solo_telefono` nunca se encolan. Devuelve cuántos sobres encoló.
  Future<int> encolarPendientes(
    String persona, {
    bool forzar = false,
  }) async {
    final ahora = _reloj();
    if (!tocaSubir(
      ahora: ahora,
      ultimaSubida: await ultimaSubida(persona),
      forzar: forzar,
    )) {
      return 0;
    }
    var total = 0;
    for (final tipo in TipoSensible.values) {
      if (await modos.modo(persona, tipo) != ModoSensible.nubeCifrada) continue;
      final pendientes = await sobres.porSubir(persona, tipo);
      for (var i = 0; i < pendientes.length; i += maximoSobresPorLlamada) {
        final lote = pendientes.skip(i).take(maximoSobresPorLlamada).toList();
        await cola.encolar(
          tipo: tipoColaSobres,
          carga: {'p_sobres': [for (final s in lote) s.aJson()]},
          personaId: persona,
        );
        await sobres.marcarEncolados(persona, lote);
        total += lote.length;
      }
    }
    if (total > 0) {
      await almacen.escribir(_claveUltima(persona), ahora.toUtc().toIso8601String());
    }
    return total;
  }

  /// Los sobres que lleva una carga de la cola, para pruebas y revisión: solo
  /// campos opacos.
  static List<Map<String, Object?>> sobresDeCarga(Map<String, Object?> carga) => [
    for (final s in (carga['p_sobres'] as List)) (s as Map).cast<String, Object?>(),
  ];

  /// La carga como texto (para comprobar que no lleva texto claro).
  static String comoTexto(Map<String, Object?> carga) => jsonEncode(carga);
}
