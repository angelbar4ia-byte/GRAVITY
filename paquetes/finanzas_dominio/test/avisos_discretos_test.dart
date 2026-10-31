import 'dart:io';

import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:test/test.dart';

void main() {
  test('criterio 31: ningun texto tiene digitos, "\$" ni mas de 40 caracteres', () {
    for (final t in TextoAviso.todos()) {
      expect(TextoAviso.esDiscreto(t), isTrue, reason: t);
    }
    expect(TextoAviso.cuerpo, isEmpty);
    expect(TextoAviso.esDiscreto('Pagas \$500'), isFalse);
    expect(TextoAviso.esDiscreto('Pago 3'), isFalse);
    expect(TextoAviso.esDiscreto('x' * 41), isFalse);
  });

  test('clave desconocida cae al texto generico', () {
    expect(TextoAviso.paraClave('inventada'), TextoAviso.generico);
    expect(TextoAviso.paraClave('pago_proximo'), 'Tienes un pago próximo');
  });

  test('claves unicas y titulos sin nombres de cuentas', () {
    final claves = TipoAlerta.values.map((t) => t.clave).toList();
    expect(claves.toSet().length, claves.length);
  });

  test('el dominio no manda avisos a servicios de red', () {
    for (final f in Directory('lib/src').listSync().whereType<File>()) {
      final s = f.readAsStringSync();
      expect(s.contains('dart:io'), isFalse, reason: f.path);
      expect(s.contains('package:http'), isFalse, reason: f.path);
    }
  });
}
