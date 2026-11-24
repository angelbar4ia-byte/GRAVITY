import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

void main() {
  group('CA-B-09 clima en cinco casillas', () {
    test('cada casilla produce su texto fijo', () {
      final c = {for (final r in casillasDeClima()) r.clima: r};
      expect(c.keys, ClimaSalida.values);
      expect(c[ClimaSalida.lluvia]!.casilla, 'Posible lluvia');
      expect(
        c[ClimaSalida.lluvia]!.texto,
        'Con lluvia el piso resbala y se ve menos. Considera dejarlo para '
        'otro día o salir en calle por un rato corto.',
      );
      expect(c[ClimaSalida.calor]!.casilla, 'Mucho calor');
      expect(
        c[ClimaSalida.calor]!.texto,
        'Con mucho calor, sal más temprano o acorta la salida, y lleva agua.',
      );
      expect(c[ClimaSalida.frio]!.casilla, 'Frío');
      expect(
        c[ClimaSalida.frio]!.texto,
        'Con frío, abrígate por capas y calienta con calma.',
      );
      expect(c[ClimaSalida.despejado]!.casilla, 'Despejado');
      expect(c[ClimaSalida.nublado]!.casilla, 'Nublado');
      expect(
        c[ClimaSalida.despejado]!.texto,
        startsWith('Buen día para salir. Cuídate en las calles'),
      );
      expect(c[ClimaSalida.nublado]!.texto, c[ClimaSalida.despejado]!.texto);
    });

    test('ninguna casilla bloquea; lluvia y calor sugieren y no obligan', () {
      for (final r in casillasDeClima()) {
        expect(r.bloquea, isFalse);
      }
      expect(respuestaClima(ClimaSalida.lluvia).sugiere, isTrue);
      expect(respuestaClima(ClimaSalida.calor).sugiere, isTrue);
      expect(respuestaClima(ClimaSalida.despejado).sugiere, isFalse);
      expect(respuestaClima(ClimaSalida.nublado).sugiere, isFalse);
    });

    test('los ids son los de la columna `clima` del servidor', () {
      expect(ClimaSalida.values.map((c) => c.id), [
        'despejado',
        'nublado',
        'lluvia',
        'calor',
        'frio',
      ]);
      expect(ClimaSalida.deId('lluvia'), ClimaSalida.lluvia);
      expect(ClimaSalida.deId('tormenta'), isNull);
    });

    test('el enlace de clima NO se guarda en la salida (ni nada de lugar)', () {
      final s = Salida(
        id: 's',
        fecha: dia(2026, 12, 5),
        clima: ClimaSalida.lluvia,
      );
      final j = s.aJson();
      expect(j['clima'], 'lluvia');
      for (final k in j.keys) {
        expect(k, isNot(contains('enlace')));
        expect(k, isNot(contains('url')));
      }
    });

    test('funciona sin red: es una función pura sin dependencias', () {
      expect(respuestaClima(ClimaSalida.frio).texto, isNotEmpty);
    });

    test('los textos de clima no traen cifras de líquidos ni diagnóstico', () {
      for (final r in casillasDeClima()) {
        expect(palabrasProhibidasEn(r.texto), isEmpty);
        expect(palabrasProhibidasEn(r.casilla), isEmpty);
      }
    });
  });
}
