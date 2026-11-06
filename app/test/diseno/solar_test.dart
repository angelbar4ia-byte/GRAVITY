import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';

void main() {
  void cerca(int real, int esperado, String que, {int tolerancia = 10}) {
    expect(
      (real - esperado).abs(),
      lessThanOrEqualTo(tolerancia),
      reason: '$que: $real min, esperado ~$esperado',
    );
  }

  int hm(int h, int m) => h * 60 + m;

  group('Tabla solar sin red', () {
    test('Ciudad de México, 20/oct/2026: amanecer ~06:40 y atardecer ~18:00', () {
      final sol = solDelDia(DateTime(2026, 10, 20), lugarSolarPorDefecto);
      // ignore: avoid_print
      print('CDMX 20 oct: $sol');
      cerca(sol.amanecerMin, hm(6, 41), 'amanecer');
      cerca(sol.atardecerMin, hm(18, 1), 'atardecer');
    });

    test('solsticios: el día es más largo en junio que en diciembre', () {
      final junio = solDelDia(DateTime(2026, 6, 21), lugarSolarPorDefecto);
      final diciembre = solDelDia(DateTime(2026, 12, 21), lugarSolarPorDefecto);
      final largoJunio = junio.atardecerMin - junio.amanecerMin;
      final largoDic = diciembre.atardecerMin - diciembre.amanecerMin;
      expect(largoJunio, greaterThan(largoDic));
      // A 19.4° N la diferencia es de unos 100 minutos (13:13 contra 11:03).
      cerca(largoJunio, hm(13, 14), 'día de junio', tolerancia: 8);
      cerca(largoDic, hm(11, 2), 'día de diciembre', tolerancia: 8);
    });

    test('los siete lugares dan un amanecer antes del mediodía y un '
        'atardecer después', () {
      for (final lugar in lugaresSolares) {
        for (final mes in [1, 4, 7, 10]) {
          final sol = solDelDia(DateTime(2026, mes, 15), lugar);
          expect(sol.amanecerMin, inInclusiveRange(hm(5, 0), hm(8, 0)),
              reason: '${lugar.nombre} mes $mes');
          expect(sol.atardecerMin, inInclusiveRange(hm(17, 0), hm(20, 30)),
              reason: '${lugar.nombre} mes $mes');
        }
      }
    });

    test('esDeDiaSolar: el amanecer es de día y el atardecer ya es de noche',
        () {
      final sol = solDelDia(DateTime(2026, 10, 20), lugarSolarPorDefecto);
      DateTime a(int minutos) =>
          DateTime(2026, 10, 20, minutos ~/ 60, minutos % 60);
      expect(esDeDiaSolar(a(sol.amanecerMin - 1), lugarSolarPorDefecto), isFalse);
      expect(esDeDiaSolar(a(sol.amanecerMin), lugarSolarPorDefecto), isTrue);
      expect(esDeDiaSolar(a(sol.atardecerMin - 1), lugarSolarPorDefecto), isTrue);
      expect(esDeDiaSolar(a(sol.atardecerMin), lugarSolarPorDefecto), isFalse);
      expect(esDeDiaSolar(DateTime(2026, 10, 20, 12), lugarSolarPorDefecto), isTrue);
      expect(esDeDiaSolar(DateTime(2026, 10, 20, 2), lugarSolarPorDefecto), isFalse);
    });

    test('un id desconocido regresa el lugar por omisión', () {
      expect(lugarSolarPorId('luna'), lugarSolarPorDefecto);
      expect(lugarSolarPorId('cancun').utcHoras, -5);
    });
  });
}
