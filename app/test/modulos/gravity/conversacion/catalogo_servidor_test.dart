// El catálogo de la función gravity-asistente es un espejo de lo que el modelo
// puede elegir. Esta prueba falla si deja de coincidir con el registro de
// herramientas de la app (nombre, módulo, roles) o si ofrece lo que el modelo
// no debe ver (D3, D13).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/herramientas/herramientas.dart';

void main() {
  final archivo = File('../supabase/functions/gravity-asistente/catalogo.json');
  final catalogo =
      (jsonDecode(archivo.readAsStringSync())['herramientas'] as List)
          .cast<Map<String, dynamic>>();
  final registro = registroDeGravity();
  final todas = registro.disponibles(rol: Rol.dueno);

  test('cada herramienta del servidor existe y coincide con el registro', () {
    expect(catalogo, isNotEmpty);
    for (final e in catalogo) {
      final h = todas.firstWhere(
        (x) => x.nombre == e['nombre'],
        orElse: () => throw TestFailure('Falta en la app: ${e['nombre']}'),
      );
      expect(h.modulo.name, e['modulo'], reason: h.nombre);
      final roles = (e['roles'] as List).cast<String>().toSet();
      final reales = {
        for (final r in Rol.values)
          if (registro.buscar(h.nombre, rol: r) != null) r.name,
      };
      expect(roles, reales, reason: 'roles de ${h.nombre}');
      expect(h.soloLocal, isTrue, reason: '${h.nombre} debe ser solo local');
      expect(h.escribe, isFalse, reason: '${h.nombre} no debe escribir');
    }
  });

  test('solo Finanzas, Hábitos y Cuidados; nunca lo reservado de Hábitos', () {
    const permitidos = {'finanzas', 'habitos', 'cuidados'};
    const reservadas = {
      'habitos.sos',
      'habitos.abrir_espiritual',
      'habitos.abrir_lector',
      'habitos.abrir_pausa',
      'habitos.abrir_revision',
    };
    for (final e in catalogo) {
      expect(permitidos, contains(e['modulo']));
      expect(reservadas, isNot(contains(e['nombre'])));
    }
  });
}
