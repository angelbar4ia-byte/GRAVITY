/// Dónde se guarda la apariencia **por persona** (respuesta P3 del dueño):
/// estilo, claro/oscuro, lugar del sol y alto contraste. La tablet de la casa
/// (Hogar) tiene la suya con la clave [claveHogar].
///
/// El sistema de diseño no sabe de archivos: define esta puerta y plataforma
/// la conecta en el arranque con su almacén local (una copia en memoria ya
/// cargada, porque la lectura es síncrona):
/// `almacenAparienciaProvider.overrideWithValue(MiAlmacen())`.
/// No guarda nada sensible: son preferencias de apariencia.
library;

import 'package:flutter/material.dart';

import 'modo_claro_oscuro.dart';
import 'solar.dart';

abstract interface class AlmacenApariencia {
  /// Valor guardado de [campo] para la persona [clave], o `null`.
  String? leer(String clave, String campo);

  /// Guarda (o borra, con `null`) el valor de [campo].
  void guardar(String clave, String campo, String? valor);
}

/// Almacén en memoria: el de las pruebas y el que usa la app mientras
/// plataforma no conecte uno persistente.
class AlmacenAparienciaMemoria implements AlmacenApariencia {
  final Map<String, String> _valores = {};

  @override
  String? leer(String clave, String campo) => _valores['$clave/$campo'];

  @override
  void guardar(String clave, String campo, String? valor) {
    if (valor == null) {
      _valores.remove('$clave/$campo');
    } else {
      _valores['$clave/$campo'] = valor;
    }
  }
}

/// Clave de la tablet de la casa y de cualquier equipo sin persona en pantalla.
const String claveHogar = 'hogar';

/// Nombres de los campos guardados.
abstract final class CampoApariencia {
  static const estilo = 'estilo';
  static const modo = 'modo';
  static const horario = 'horario';
  static const lugar = 'lugar';
  static const altoContraste = 'alto_contraste';
}

String horarioATexto(HorarioClaro h) {
  String hm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  return '${hm(h.inicio)}-${hm(h.fin)}';
}

/// Lee "07:00-19:00"; si no se entiende, el horario por omisión.
HorarioClaro horarioDeTexto(String? texto) {
  final partes = texto?.split('-');
  if (partes == null || partes.length != 2) return HorarioClaro.porDefecto;
  TimeOfDay? hm(String t) {
    final p = t.split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return TimeOfDay(hour: h, minute: m);
  }

  final inicio = hm(partes[0]);
  final fin = hm(partes[1]);
  if (inicio == null || fin == null) return HorarioClaro.porDefecto;
  return HorarioClaro(inicio: inicio, fin: fin);
}

/// Lee el modo guardado por su nombre; si no existe, el modo por omisión.
ModoClaroOscuro modoDeTexto(String? texto) {
  for (final modo in ModoClaroOscuro.values) {
    if (modo.name == texto) return modo;
  }
  return const PreferenciaClaroOscuro().modo;
}

/// Preferencia completa guardada para [clave].
PreferenciaClaroOscuro leerPreferenciaClaroOscuro(
  AlmacenApariencia almacen,
  String clave,
) => PreferenciaClaroOscuro(
  modo: modoDeTexto(almacen.leer(clave, CampoApariencia.modo)),
  horario: horarioDeTexto(almacen.leer(clave, CampoApariencia.horario)),
  lugar: lugarSolarPorId(almacen.leer(clave, CampoApariencia.lugar)),
);

void guardarPreferenciaClaroOscuro(
  AlmacenApariencia almacen,
  String clave,
  PreferenciaClaroOscuro p,
) {
  almacen
    ..guardar(clave, CampoApariencia.modo, p.modo.name)
    ..guardar(clave, CampoApariencia.horario, horarioATexto(p.horario))
    ..guardar(clave, CampoApariencia.lugar, p.lugar.id);
}
