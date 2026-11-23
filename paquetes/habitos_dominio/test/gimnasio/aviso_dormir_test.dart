import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

const dormir22 = 22 * 60;

void main() {
  group('CA-G-24 aviso de cercanía a la hora de dormir', () {
    test('con dormir a las 22:00 y margen 90: termina a las 20:15, sin aviso (105 min)', () {
      expect(avisoDormir(finMin: 20 * 60 + 15, dormirMin: dormir22), isNull);
    });

    test('termina a las 21:30: avisa (30 min) con las opciones en orden', () {
      final a = avisoDormir(finMin: 21 * 60 + 30, dormirMin: dormir22)!;
      expect(a.minutosAntesDeDormir, 30);
      expect(a.opciones, [
        OpcionDormir.versionMasCorta,
        OpcionDormir.regenerativa,
        OpcionDormir.empezarAntes,
        OpcionDormir.moverALaManana,
      ]);
    });

    test('exactamente 90 min antes: sin aviso; 89: con aviso', () {
      expect(avisoDormir(finMin: 20 * 60 + 30, dormirMin: dormir22), isNull);
      expect(avisoDormir(finMin: 20 * 60 + 31, dormirMin: dormir22), isNotNull);
    });

    test('cambiar el margen cambia el aviso', () {
      final fin = 20 * 60 + 15;
      expect(
        avisoDormir(finMin: fin, dormirMin: dormir22, margenMin: 60),
        isNull,
      );
      expect(
        avisoDormir(finMin: fin, dormirMin: dormir22, margenMin: 120),
        isNotNull,
      );
      expect(
        avisoDormir(finMin: fin, dormirMin: dormir22, margenMin: 105),
        isNull,
      );
      expect(
        avisoDormir(finMin: fin, dormirMin: dormir22, margenMin: 106),
        isNotNull,
      );
    });

    test('ya en la corta no se ofrece «versión más corta»', () {
      final a = avisoDormir(
        finMin: 21 * 60 + 30,
        dormirMin: dormir22,
        esCorta: true,
      )!;
      expect(a.opciones.first, OpcionDormir.regenerativa);
      expect(a.opciones, isNot(contains(OpcionDormir.versionMasCorta)));
    });

    test('CASO MALO: en la mañana no hay aviso de dormir', () {
      expect(
        avisoDormir(
          finMin: 21 * 60 + 30,
          dormirMin: dormir22,
          ventana: VentanaEntrenamiento.manana,
        ),
        isNull,
      );
    });

    test('con el día tipo del diseño: 19:15 + duración estimada, A estándar y larga de C', () {
      // A estándar (35.3 min) a las 19:15 termina a las 19:51: sin aviso.
      final a = generar('A');
      expect(
        avisoDormir(
          finMin: finEstimadoMin(19 * 60 + 15, a.duracionEstimadaSeg),
          dormirMin: dormir22,
        ),
        isNull,
      );
      // La larga de C (63.1 min) a las 20:30 termina a las 21:34: con aviso.
      final c = generar('C', version: VersionSesion.larga);
      expect(finEstimadoMin(20 * 60 + 30, c.duracionEstimadaSeg), 21 * 60 + 34);
      expect(
        avisoDormir(
          finMin: finEstimadoMin(20 * 60 + 30, c.duracionEstimadaSeg),
          dormirMin: dormir22,
        ),
        isNotNull,
      );
    });

    test('en la mañana el calentamiento sube a 8 minutos', () {
      final n = generar('A');
      final m = generar(
        'A',
        perfil: const PerfilGimnasio(ventana: VentanaEntrenamiento.manana),
      );
      expect(n.calentamientoMin, 6);
      expect(m.calentamientoMin, 8);
      expect(m.duracionEstimadaSeg - n.duracionEstimadaSeg, 120);
    });
  });
}
