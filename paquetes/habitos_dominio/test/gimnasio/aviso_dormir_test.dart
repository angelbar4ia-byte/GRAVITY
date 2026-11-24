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

  group('G6-M4 hora de dormir pasada la medianoche', () {
    const dormir0030 = 30; // 00:30 de la madrugada siguiente

    test('dormir a las 00:30: termina a las 20:15, sin aviso', () {
      expect(avisoDormir(finMin: 20 * 60 + 15, dormirMin: dormir0030), isNull);
    });

    test('dormir a las 00:30: termina a las 23:00, justo 90 min, sin aviso', () {
      expect(avisoDormir(finMin: 23 * 60, dormirMin: dormir0030), isNull);
    });

    test('dormir a las 00:30: termina a las 23:01, avisa con 89 min', () {
      final a = avisoDormir(finMin: 23 * 60 + 1, dormirMin: dormir0030)!;
      expect(a.minutosAntesDeDormir, 89);
    });

    test('dormir a las 00:30: termina a las 00:10, avisa con 20 min', () {
      // Una sesión que cruza la medianoche termina en 1450 (00:10 siguiente).
      final a = avisoDormir(finMin: 24 * 60 + 10, dormirMin: dormir0030)!;
      expect(a.minutosAntesDeDormir, 20);
    });

    test('dormir a las 00:00 y a las 01:00 también son del día siguiente', () {
      expect(avisoDormir(finMin: 22 * 60, dormirMin: 0), isNull);
      expect(avisoDormir(finMin: 22 * 60, dormirMin: 60), isNull);
      // 01:00 siguiente = 1500: a las 23:30 (1410) quedan 90 → sin aviso.
      expect(avisoDormir(finMin: 23 * 60 + 30, dormirMin: 60), isNull);
      expect(
        avisoDormir(finMin: 23 * 60 + 31, dormirMin: 60)!.minutosAntesDeDormir,
        89,
      );
    });

    test('CASO MALO: con dormir a las 22:00 nada cambia (no se suma un día)', () {
      expect(dormirNormalizadoMin(22 * 60), 22 * 60);
      expect(avisoDormir(finMin: 22 * 60 + 30, dormirMin: dormir22), isNotNull);
      expect(
        avisoDormir(finMin: 22 * 60 + 30, dormirMin: dormir22)!
            .minutosAntesDeDormir,
        -30,
      );
    });

    test('dormirNormalizadoMin: módulo 1440 y madrugada = día siguiente', () {
      expect(dormirNormalizadoMin(30), 1470);
      expect(dormirNormalizadoMin(0), 1440);
      expect(dormirNormalizadoMin(1440), 1440);
      expect(dormirNormalizadoMin(1470), 1470);
      expect(dormirNormalizadoMin(23 * 60 + 59), 23 * 60 + 59);
      expect(dormirNormalizadoMin(3 * 60), 1620);
      // Con una hora de despertar conocida.
      expect(dormirNormalizadoMin(6 * 60 + 30, despertarMin: 7 * 60), 1830);
      expect(dormirNormalizadoMin(22 * 60, despertarMin: 7 * 60), 22 * 60);
    });

    test('la ventana de mañana no avisa ni con dormir pasada la medianoche', () {
      expect(
        avisoDormir(
          finMin: 9 * 60,
          dormirMin: dormir0030,
          ventana: VentanaEntrenamiento.manana,
        ),
        isNull,
      );
    });
  });
}
