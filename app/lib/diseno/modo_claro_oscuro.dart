/// Capa 4 del sistema de estilos: claro u oscuro (DISENO_UX_UI, sección 4).
///
/// Por defecto es automático según el sol real del lugar (amanecer y
/// atardecer); también hay un horario fijo editable (07:00 a 19:00).
/// Todo lo de este archivo es puro: no lee el reloj ni el sistema por su cuenta.
library;

import 'package:flutter/material.dart';

import 'solar.dart';

/// Cómo se elige entre claro y oscuro.
enum ModoClaroOscuro {
  /// Claro del amanecer al atardecer reales del lugar de la persona
  /// (tabla solar sin red, [solar.dart]). Es el modo por omisión (P8).
  automaticoSolar,

  /// Claro dentro del horario fijo de día; oscuro fuera de él.
  automaticoPorHora,

  /// Lo que diga el sistema operativo.
  sistema,

  /// Siempre claro.
  claro,

  /// Siempre oscuro.
  oscuro,
}

/// Horario en que se usa la versión clara cuando el modo es automático.
///
/// El intervalo es [inicio, fin): a las 07:00 ya es claro y a las 19:00 ya es
/// oscuro. Si [fin] es menor que [inicio], el horario cruza la medianoche.
/// Si son iguales, nunca es claro.
@immutable
class HorarioClaro {
  const HorarioClaro({
    this.inicio = const TimeOfDay(hour: 7, minute: 0),
    this.fin = const TimeOfDay(hour: 19, minute: 0),
  });

  /// Claro de 07:00 a 19:00.
  static const porDefecto = HorarioClaro();

  final TimeOfDay inicio;
  final TimeOfDay fin;

  int get _inicioMin => inicio.hour * 60 + inicio.minute;
  int get _finMin => fin.hour * 60 + fin.minute;

  /// Si [momento] (hora local) cae dentro del horario claro.
  bool contiene(DateTime momento) {
    final m = momento.hour * 60 + momento.minute;
    final ini = _inicioMin;
    final fin = _finMin;
    if (ini == fin) return false;
    if (ini < fin) return m >= ini && m < fin;
    return m >= ini || m < fin;
  }

  HorarioClaro copyWith({TimeOfDay? inicio, TimeOfDay? fin}) =>
      HorarioClaro(inicio: inicio ?? this.inicio, fin: fin ?? this.fin);

  @override
  bool operator ==(Object other) =>
      other is HorarioClaro && other.inicio == inicio && other.fin == fin;

  @override
  int get hashCode => Object.hash(inicio, fin);

  @override
  String toString() => 'HorarioClaro(${_hhmm(inicio)}–${_hhmm(fin)})';

  static String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// Preferencia completa de la capa 4.
@immutable
class PreferenciaClaroOscuro {
  const PreferenciaClaroOscuro({
    this.modo = ModoClaroOscuro.automaticoSolar,
    this.horario = HorarioClaro.porDefecto,
    this.lugar = lugarSolarPorDefecto,
  });

  final ModoClaroOscuro modo;
  final HorarioClaro horario;

  /// Lugar de la persona para el modo solar.
  final LugarSolar lugar;

  PreferenciaClaroOscuro copyWith({
    ModoClaroOscuro? modo,
    HorarioClaro? horario,
    LugarSolar? lugar,
  }) => PreferenciaClaroOscuro(
    modo: modo ?? this.modo,
    horario: horario ?? this.horario,
    lugar: lugar ?? this.lugar,
  );

  @override
  bool operator ==(Object other) =>
      other is PreferenciaClaroOscuro &&
      other.modo == modo &&
      other.horario == horario &&
      other.lugar == lugar;

  @override
  int get hashCode => Object.hash(modo, horario, lugar);
}

/// Si a esa hora toca la versión clara según el horario.
bool esHorarioClaro(
  DateTime momento, [
  HorarioClaro horario = HorarioClaro.porDefecto,
]) => horario.contiene(momento);

/// Decide claro u oscuro. Función pura: la hora y el brillo del sistema entran
/// como parámetros.
Brightness decidirBrillo({
  required ModoClaroOscuro modo,
  required DateTime ahora,
  HorarioClaro horario = HorarioClaro.porDefecto,
  LugarSolar lugar = lugarSolarPorDefecto,
  Brightness brilloSistema = Brightness.light,
}) => switch (modo) {
  ModoClaroOscuro.automaticoSolar =>
    esDeDiaSolar(ahora, lugar) ? Brightness.light : Brightness.dark,
  ModoClaroOscuro.automaticoPorHora =>
    horario.contiene(ahora) ? Brightness.light : Brightness.dark,
  ModoClaroOscuro.sistema => brilloSistema,
  ModoClaroOscuro.claro => Brightness.light,
  ModoClaroOscuro.oscuro => Brightness.dark,
};

/// El `ThemeMode` para `MaterialApp`. En modo sistema se delega a Flutter para
/// que siga los cambios del sistema operativo al instante.
ThemeMode modoTemaPara({
  required ModoClaroOscuro modo,
  required DateTime ahora,
  HorarioClaro horario = HorarioClaro.porDefecto,
  LugarSolar lugar = lugarSolarPorDefecto,
}) => switch (modo) {
  ModoClaroOscuro.sistema => ThemeMode.system,
  ModoClaroOscuro.automaticoSolar =>
    esDeDiaSolar(ahora, lugar) ? ThemeMode.light : ThemeMode.dark,
  ModoClaroOscuro.claro => ThemeMode.light,
  ModoClaroOscuro.oscuro => ThemeMode.dark,
  ModoClaroOscuro.automaticoPorHora =>
    horario.contiene(ahora) ? ThemeMode.light : ThemeMode.dark,
};
