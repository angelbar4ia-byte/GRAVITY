import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

import 'ayudas_bici.dart';

EncajeRevision encaje(
  int durMin, {
  int margen = 90,
  int revision = revision1430,
}) => encajeConRevision(
  inicioMin: 8 * 60,
  duracionMin: durMin,
  revisionMin: revision,
  reglas: ReglasBicicleta(margenRevisionMin: margen),
);

void main() {
  group('CA-B-03 regreso y revisión de las 14:30', () {
    test(
      'salida de 4 h: regreso 12:00, +90 = 13:30, cabe con 60 min de sobra',
      () {
        final e = encaje(240);
        expect(e.regresoMin, 12 * 60);
        expect(e.listoMin, 13 * 60 + 30);
        expect(e.cabe, isTrue);
        expect(e.sobranMin, 60);
        expect(e.faltanMin, 0);
        expect(e.propuestas, isEmpty);
      },
    );

    test(
      'salida de 5 h: regreso 13:00, +90 = 14:30, cabe justo (0 de sobra)',
      () {
        final e = encaje(300);
        expect(e.regresoMin, 13 * 60);
        expect(e.listoMin, 14 * 60 + 30);
        expect(e.cabe, isTrue);
        expect(e.sobranMin, 0);
      },
    );

    test('salida de 5 h 30 min: regreso 13:30, +90 = 15:00, NO cabe; faltan '
        '30 min, con las tres propuestas', () {
      final e = encaje(330);
      expect(e.regresoMin, 13 * 60 + 30);
      expect(e.listoMin, 15 * 60);
      expect(e.cabe, isFalse);
      expect(e.faltanMin, 30);
      expect(e.sobranMin, 0);
      expect(e.propuestas, [
        PropuestaRevision.acortarSalida,
        PropuestaRevision.revisionMasTarde,
        PropuestaRevision.revisionElDomingo,
      ]);
      // Los números de las propuestas: acortar hasta 5 h; revisión desde 15:00.
      expect(e.duracionMaximaQueCabeMin, 300);
      expect(e.revisionMasTardeMin, 15 * 60);
    });

    test('cambiar el margen o la hora de la revisión cambia el resultado', () {
      expect(encaje(300, margen: 120).cabe, isFalse);
      expect(encaje(300, margen: 120).faltanMin, 30);
      expect(encaje(330, revision: 15 * 60).cabe, isTrue);
      expect(encaje(240, margen: 0).sobranMin, 150);
      expect(encaje(300, revision: 14 * 60).cabe, isFalse);
    });

    test('CASO MALO: la regla NUNCA mueve la revisión sola', () {
      final e = encaje(330);
      expect(e.revisionMin, revision1430); // sigue donde está
      expect(e.mueveLaRevision, isFalse);
      // Cualquier duración: nunca mueve.
      for (final d in [60, 240, 300, 330, 600]) {
        expect(encaje(d).mueveLaRevision, isFalse);
        expect(encaje(d).revisionMin, revision1430);
      }
    });

    test('si aun sin salir no cabría, no se ofrece «acortar»', () {
      final e = encajeConRevision(
        inicioMin: 14 * 60,
        duracionMin: 120,
        revisionMin: revision1430,
      );
      expect(e.cabe, isFalse);
      expect(e.duracionMaximaQueCabeMin, isNull);
      expect(e.propuestas, [
        PropuestaRevision.revisionMasTarde,
        PropuestaRevision.revisionElDomingo,
      ]);
    });
  });

  group('Pasar mi revisión a más tarde (salida en curso)', () {
    bool ofrece(int ahora, {bool enCurso = true}) => ofrecerPasarRevision(
      ahoraMin: ahora,
      revisionMin: revision1430,
      salidaEnCurso: enCurso,
    );

    test('se ofrece pasadas las 13:15 (revisión − 75 min) y solo en curso', () {
      expect(14 * 60 + 30 - 75, 13 * 60 + 15);
      expect(ofrece(13 * 60 + 15), isFalse); // aún no pasan
      expect(ofrece(13 * 60 + 16), isTrue);
      expect(ofrece(12 * 60), isFalse);
      expect(ofrece(13 * 60 + 30, enCurso: false), isFalse);
    });
  });
}
