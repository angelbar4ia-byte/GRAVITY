/// Preferencias de voz por persona (spec, sección 5.2).
///
/// Por persona y por uso: fuente preferida, "solo esta fuente", velocidad y
/// qué voz del motor suena como cada voz de guion. Se guardan en
/// `shared_preferences` con una clave por persona, como la apariencia (no es
/// dato sensible). En la tablet cambian con la persona en pantalla; la cuenta
/// Casa tiene las suyas ([claveHogar]).
///
/// Los modelos y paquetes de audio (B y C) son del equipo, no de la persona:
/// no se guardan aquí.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../diseno/almacen_apariencia.dart' show claveHogar;
import '../../../diseno/proveedores.dart' show personaEnPantallaProvider;
import 'tipos.dart';

/// Velocidad más lenta y más rápida que se ofrece (1.0 es la normal).
const double velocidadVozMinima = 0.5;
const double velocidadVozMaxima = 1.5;

@immutable
final class PreferenciasDeUso {
  const PreferenciasDeUso({
    this.fuente,
    this.soloEstaFuente = false,
    this.velocidad = 1.0,
  });

  /// Fuente que pasa al frente de la cadena; `null`: automática.
  final Fuente? fuente;

  /// Sin respaldo: solo la [fuente]. Solo vale si hay una fuente elegida.
  final bool soloEstaFuente;

  /// 1.0 es la normal.
  final double velocidad;

  PreferenciasDeUso copiar({
    Object? fuente = _igual,
    bool? soloEstaFuente,
    double? velocidad,
  }) => PreferenciasDeUso(
    fuente: identical(fuente, _igual) ? this.fuente : fuente as Fuente?,
    soloEstaFuente: soloEstaFuente ?? this.soloEstaFuente,
    velocidad: velocidad ?? this.velocidad,
  );

  static const Object _igual = Object();

  @override
  bool operator ==(Object other) =>
      other is PreferenciasDeUso &&
      other.fuente == fuente &&
      other.soloEstaFuente == soloEstaFuente &&
      other.velocidad == velocidad;

  @override
  int get hashCode => Object.hash(fuente, soloEstaFuente, velocidad);
}

@immutable
final class PreferenciasVoz {
  const PreferenciasVoz({
    this.curso = const PreferenciasDeUso(),
    this.asistente = const PreferenciasDeUso(),
    this.asignaciones = const {},
  });

  final PreferenciasDeUso curso;
  final PreferenciasDeUso asistente;

  /// `"<fuente>/<variante>/<voz de guion>"` -> id de la voz del motor.
  final Map<String, String> asignaciones;

  PreferenciasDeUso de(UsoVoz uso) => switch (uso) {
    UsoVoz.curso => curso,
    UsoVoz.asistente => asistente,
  };

  PreferenciasVoz conUso(UsoVoz uso, PreferenciasDeUso valor) =>
      uso == UsoVoz.curso
      ? PreferenciasVoz(
          curso: valor,
          asistente: asistente,
          asignaciones: asignaciones,
        )
      : PreferenciasVoz(
          curso: curso,
          asistente: valor,
          asignaciones: asignaciones,
        );

  static String claveAsignacion(
    Fuente fuente,
    Variante variante,
    VozDeGuion voz,
  ) => '${fuente.name}/${variante.etiqueta}/${voz.etiqueta}';

  /// Lo que la persona eligió para esa fuente y variante.
  Map<VozDeGuion, String> asignacionDe(Fuente fuente, Variante variante) => {
    for (final voz in VozDeGuion.values)
      voz: ?asignaciones[claveAsignacion(fuente, variante, voz)],
  };

  /// Reemplaza lo elegido para esa fuente y variante.
  PreferenciasVoz conAsignacion(
    Fuente fuente,
    Variante variante,
    Map<VozDeGuion, String> asignacion,
  ) {
    final nuevas = Map<String, String>.of(asignaciones)
      ..removeWhere((k, _) => k.startsWith('${fuente.name}/${variante.etiqueta}/'));
    asignacion.forEach((voz, id) {
      nuevas[claveAsignacion(fuente, variante, voz)] = id;
    });
    return PreferenciasVoz(
      curso: curso,
      asistente: asistente,
      asignaciones: nuevas,
    );
  }

  Map<String, Object?> aJson() => {
    'v': 1,
    'curso': _usoAJson(curso),
    'asistente': _usoAJson(asistente),
    'asig': asignaciones,
  };

  static Map<String, Object?> _usoAJson(PreferenciasDeUso u) => {
    'fuente': ?u.fuente?.name,
    'solo': u.soloEstaFuente,
    'vel': u.velocidad,
  };

  /// Lee lo guardado. Lo que no se entiende se ignora y queda el valor por
  /// omisión: una preferencia dañada nunca debe tumbar la voz.
  static PreferenciasVoz deJson(Object? json) {
    if (json is! Map) return const PreferenciasVoz();
    PreferenciasDeUso uso(Object? crudo) {
      if (crudo is! Map) return const PreferenciasDeUso();
      final vel = crudo['vel'];
      return PreferenciasDeUso(
        fuente: Fuente.deNombre(crudo['fuente'] as String?),
        soloEstaFuente: crudo['solo'] == true,
        velocidad: vel is num
            ? vel.toDouble().clamp(velocidadVozMinima, velocidadVozMaxima)
            : 1.0,
      );
    }

    final asig = <String, String>{};
    final crudas = json['asig'];
    if (crudas is Map) {
      crudas.forEach((k, v) {
        if (k is String && v is String && v.isNotEmpty) asig[k] = v;
      });
    }
    return PreferenciasVoz(
      curso: uso(json['curso']),
      asistente: uso(json['asistente']),
      asignaciones: asig,
    );
  }
}

/// Dónde se guardan las preferencias. Es una puerta: en la app es
/// `shared_preferences`; en las pruebas, memoria.
abstract interface class AlmacenVoz {
  String? leer(String clave);
  void guardar(String clave, String? valor);
}

class AlmacenVozMemoria implements AlmacenVoz {
  final Map<String, String> _valores = {};

  @override
  String? leer(String clave) => _valores[clave];

  @override
  void guardar(String clave, String? valor) {
    if (valor == null) {
      _valores.remove(clave);
    } else {
      _valores[clave] = valor;
    }
  }
}

/// Almacén persistente con `shared_preferences` (se abre una vez en el
/// arranque; lee de una copia ya cargada y escribe sin esperar).
class AlmacenVozPersistente implements AlmacenVoz {
  AlmacenVozPersistente(this._preferencias);

  static Future<AlmacenVozPersistente> abrir() async =>
      AlmacenVozPersistente(await SharedPreferences.getInstance());

  static const prefijo = 'voz/';

  final SharedPreferences _preferencias;

  @override
  String? leer(String clave) {
    try {
      return _preferencias.getString('$prefijo$clave');
    } catch (error) {
      debugPrint('Voz: ${error.runtimeType}');
      return null;
    }
  }

  @override
  void guardar(String clave, String? valor) {
    final llave = '$prefijo$clave';
    final futuro = valor == null
        ? _preferencias.remove(llave)
        : _preferencias.setString(llave, valor);
    futuro.catchError((Object error) {
      debugPrint('Voz: ${error.runtimeType}');
      return false;
    });
  }
}

final almacenVozProvider = Provider<AlmacenVoz>((ref) => AlmacenVozMemoria());

/// Clave de la persona en pantalla (o la de la casa).
final clavePreferenciasVozProvider = Provider<String>(
  (ref) => ref.watch(personaEnPantallaProvider) ?? claveHogar,
);

final preferenciasVozProvider =
    NotifierProvider<PreferenciasVozActual, PreferenciasVoz>(
      PreferenciasVozActual.new,
    );

class PreferenciasVozActual extends Notifier<PreferenciasVoz> {
  @override
  PreferenciasVoz build() {
    final clave = ref.watch(clavePreferenciasVozProvider);
    final guardado = ref.watch(almacenVozProvider).leer(clave);
    if (guardado == null) return const PreferenciasVoz();
    try {
      return PreferenciasVoz.deJson(jsonDecode(guardado));
    } catch (_) {
      return const PreferenciasVoz();
    }
  }

  void _fijar(PreferenciasVoz valor) {
    state = valor;
    ref
        .read(almacenVozProvider)
        .guardar(
          ref.read(clavePreferenciasVozProvider),
          jsonEncode(valor.aJson()),
        );
  }

  void fijarFuente(UsoVoz uso, Fuente? fuente) => _fijar(
    state.conUso(
      uso,
      state.de(uso).copiar(
        fuente: fuente,
        soloEstaFuente: fuente == null ? false : null,
      ),
    ),
  );

  void fijarSoloEstaFuente(UsoVoz uso, bool solo) =>
      _fijar(state.conUso(uso, state.de(uso).copiar(soloEstaFuente: solo)));

  void fijarVelocidad(UsoVoz uso, double velocidad) => _fijar(
    state.conUso(
      uso,
      state
          .de(uso)
          .copiar(
            velocidad: velocidad.clamp(
              velocidadVozMinima,
              velocidadVozMaxima,
            ),
          ),
    ),
  );

  void fijarAsignacion(
    Fuente fuente,
    Variante variante,
    Map<VozDeGuion, String> asignacion,
  ) => _fijar(state.conAsignacion(fuente, variante, asignacion));
}
