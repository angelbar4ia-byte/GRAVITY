import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

List<Salida> cuatro(List<int> min, {List<int?>? km}) => [
  for (var i = 0; i < min.length; i++)
    Salida(
      id: 'h$i',
      fecha: dia(2026, 10, 3 + 7 * i),
      duracionMin: min[i],
      distanciaM: km?[i],
    ),
];

Salida actual(int min, {int? km}) => Salida(
  id: 'hoy',
  fecha: dia(2026, 12, 5),
  duracionMin: min,
  distanciaM: km,
);

void main() {
  final cuatroHoras = cuatro([240, 240, 240, 240]);

  group('CA-B-07 progresión informativa', () {
    test('5 h con promedio de 4 h (+25 %) y tope 20 %: muestra la nota', () {
      final p = evaluarProgresion(actual: actual(300), historial: cuatroHoras);
      expect(p.promedioDuracionMin, 240);
      expect(p.cambioDuracionPct, 25);
      expect(p.mostrarNota, isTrue);
      expect(p.bloquea, isFalse);
    });

    test('+15 % no muestra la nota (pero sí informa el cambio)', () {
      final p = evaluarProgresion(actual: actual(276), historial: cuatroHoras);
      expect(p.cambioDuracionPct, 15);
      expect(p.mostrarNota, isFalse);
    });

    test('exactamente el tope (+20 %) no muestra la nota: «pasa de»', () {
      final p = evaluarProgresion(actual: actual(288), historial: cuatroHoras);
      expect(p.cambioDuracionPct, 20);
      expect(p.mostrarNota, isFalse);
      expect(
        evaluarProgresion(
          actual: actual(289),
          historial: cuatroHoras,
        ).mostrarNota,
        isTrue,
      );
    });

    test('el tope es editable de 5 a 50', () {
      final p = evaluarProgresion(
        actual: actual(276),
        historial: cuatroHoras,
        reglas: const ReglasBicicleta(topeAumentoPct: 10),
      );
      expect(p.mostrarNota, isTrue);
      expect(const ReglasBicicleta(topeAumentoPct: 4).validar(), isNotEmpty);
      expect(const ReglasBicicleta(topeAumentoPct: 51).validar(), isNotEmpty);
      expect(const ReglasBicicleta(topeAumentoPct: 5).validar(), isEmpty);
    });

    test('con menos de cuatro salidas no hay nota ni comparación', () {
      for (final n in [0, 1, 2, 3]) {
        final p = evaluarProgresion(
          actual: actual(600),
          historial: cuatro(List.filled(n, 240)),
        );
        expect(p.mostrarNota, isFalse, reason: '$n salidas');
        expect(p.promedioDuracionMin, isNull);
        expect(p.cambioDuracionPct, isNull);
      }
    });

    test('NO se muestra en modo foco; nunca bloquea', () {
      final p = evaluarProgresion(
        actual: actual(600),
        historial: cuatroHoras,
        modoFoco: true,
      );
      expect(p.mostrarNota, isFalse);
      expect(p.enFoco, isTrue);
      expect(p.cambioDuracionPct, isNull);
      expect(p.bloquea, isFalse);
    });

    test('CASO MALO: una salida de 0 minutos no divide entre cero', () {
      // Un promedio de ceros no existe: no hay cuatro con dato.
      final p = evaluarProgresion(
        actual: actual(300),
        historial: cuatro([0, 0, 0, 0]),
      );
      expect(p.mostrarNota, isFalse);
      expect(p.promedioDuracionMin, isNull);
      // La salida actual de 0 min tampoco compara.
      final q = evaluarProgresion(actual: actual(0), historial: cuatroHoras);
      expect(q.cambioDuracionPct, isNull);
      // Con un 0 entre las cuatro previas, esa no entra: hace falta otra.
      final r = evaluarProgresion(
        actual: actual(300),
        historial: cuatro([0, 240, 240, 240, 240]),
      );
      expect(r.promedioDuracionMin, 240);
      expect(r.mostrarNota, isTrue);
    });

    test('solo cuentan las cuatro anteriores más recientes', () {
      final h = cuatro([60, 240, 240, 240, 240]);
      final p = evaluarProgresion(actual: actual(300), historial: h);
      expect(p.promedioDuracionMin, 240);
      // Una salida posterior a la evaluada no cuenta.
      final futura = Salida(id: 'f', fecha: dia(2027, 1, 2), duracionMin: 900);
      expect(
        evaluarProgresion(
          actual: actual(300),
          historial: [...h, futura],
        ).promedioDuracionMin,
        240,
      );
    });

    test('una omitida no entra al promedio', () {
      final h = [
        ...cuatroHoras,
        Salida(
          id: 'o',
          fecha: dia(2026, 11, 28),
          duracionMin: 10,
          estado: EstadoSalida.omitida,
        ),
      ];
      expect(
        evaluarProgresion(
          actual: actual(300),
          historial: h,
        ).promedioDuracionMin,
        240,
      );
    });

    test(
      'la misma salida dentro del historial no se compara consigo misma',
      () {
        final a = actual(300);
        final p = evaluarProgresion(actual: a, historial: [...cuatroHoras, a]);
        expect(p.promedioDuracionMin, 240);
      },
    );

    test('también compara la distancia (en metros) con el mismo tope', () {
      final h = cuatro([240, 240, 240, 240], km: [60000, 60000, 60000, 60000]);
      final p = evaluarProgresion(actual: actual(240, km: 80000), historial: h);
      expect(p.promedioDistanciaM, 60000);
      expect(p.cambioDistanciaPct, 33);
      expect(p.cambioDuracionPct, 0);
      expect(p.mostrarNota, isTrue); // por la distancia
    });

    test('un descenso da un cambio negativo y no muestra nota', () {
      final p = evaluarProgresion(actual: actual(180), historial: cuatroHoras);
      expect(p.cambioDuracionPct, -25);
      expect(p.mostrarNota, isFalse);
    });
  });
}
