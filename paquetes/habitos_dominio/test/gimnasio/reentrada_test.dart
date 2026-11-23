import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

final ultima = dia(2026, 12, 1);

EjercicioPlanificado conPausa(int dias, {List<Pausa> pausas = const []}) =>
    generar(
      'A',
      historial: [sesionHecha(fecha: ultima)], // 12-12-12 en la placa 5
      hoy: sumarDias(ultima, dias),
      pausas: pausas,
      perfil: const PerfilGimnasio(nivel: NivelGimnasio.intermedio),
    ).ejercicios.first;

void main() {
  group('CA-G-19 reentrada tras una pausa', () {
    test('6 días: normal (sube a la placa 6)', () {
      final e = conPausa(6);
      expect(e.cargaPasos, 6);
      expect(e.series, 3);
      expect(e.motivo, MotivoProgresion.subeCarga);
    });

    test('7 y 13 días: se repiten las cargas de la última vez, sin subir', () {
      for (final d in [7, 13]) {
        final e = conPausa(d);
        expect(e.cargaPasos, 5, reason: '$d días');
        expect(e.series, 3);
        expect(e.motivo, MotivoProgresion.repiteCargas);
      }
    });

    test('14 días: semana de reentrada (2 series y una placa menos)', () {
      final s = generar(
        'A',
        historial: [sesionHecha(fecha: ultima)],
        hoy: sumarDias(ultima, 14),
        perfil: const PerfilGimnasio(nivel: NivelGimnasio.intermedio),
      );
      expect(s.semanaTipo, TipoSemana.reentrada);
      final e = s.ejercicios.first;
      expect(e.series, 2);
      expect(e.cargaPasos, 4);
      expect(e.motivo, MotivoProgresion.bajaUnPaso);
      expect(conPausa(55).series, 2);
    });

    test('56 días: como la primera vez, cargas de prueba', () {
      final e = conPausa(56);
      expect(e.cargaPasos, isNull);
      expect(e.motivo, MotivoProgresion.pruebas);
      expect(e.objetivo, e.rangoMin);
    });

    test('una pausa declarada no cuenta como días sin sesión', () {
      // 14 días calendario, 10 de ellos en pausa por viaje: 4 días efectivos.
      final pausa = Pausa(sumarDias(ultima, 1), sumarDias(ultima, 10));
      final e = conPausa(14, pausas: [pausa]);
      expect(e.cargaPasos, 6);
      expect(e.motivo, MotivoProgresion.subeCarga);
      expect(
        diasSinSesionFuerza(
          historial: [sesionHecha(fecha: ultima)],
          hoy: sumarDias(ultima, 14),
          pausas: [pausa],
        ),
        4,
      );
      // Sin la pausa serían 14.
      expect(
        diasSinSesionFuerza(
          historial: [sesionHecha(fecha: ultima)],
          hoy: sumarDias(ultima, 14),
        ),
        14,
      );
    });

    test(
      'CASO MALO: una pausa de otro objetivo sí cuenta como días sin sesión',
      () {
        final ajena = Pausa(
          sumarDias(ultima, 1),
          sumarDias(ultima, 10),
          objetivoId: 'azucar',
        );
        expect(
          diasSinSesionFuerza(
            historial: [sesionHecha(fecha: ultima)],
            hoy: sumarDias(ultima, 14),
            pausas: [ajena],
          ),
          14,
        );
      },
    );

    test(
      'solo las sesiones de fuerza terminadas cuentan; sin historial es null',
      () {
        expect(diasSinSesionFuerza(historial: const [], hoy: ultima), isNull);
        final regen = SesionRegistrada(
          fecha: sumarDias(ultima, 5),
          plantilla: 'R1',
          version: VersionSesion.estandar,
        );
        expect(
          diasSinSesionFuerza(
            historial: [
              sesionHecha(fecha: ultima),
              regen,
            ],
            hoy: sumarDias(ultima, 10),
          ),
          10,
        );
      },
    );

    test('el mensaje de reentrada es del catálogo', () {
      expect(
        MensajesGimnasio.reentrada,
        'Retomemos con calma. Hoy cuenta empezar.',
      );
    });
  });
}
