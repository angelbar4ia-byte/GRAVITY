import 'dart:io';

import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

final h = [sesionHecha(fecha: dia(2026, 12, 1))]; // 12-12-12 en la placa 5

void main() {
  group('CA-G-20 modo foco', () {
    test(
      'sin incrementos de carga, repeticiones ni series; tipo de semana foco',
      () {
        final s = generar('A', historial: h, modoFoco: true);
        expect(s.semanaTipo, TipoSemana.foco);
        final e = s.ejercicios.first;
        expect(e.cargaPasos, 5); // sin foco subiría a 6
        expect(e.series, 3);
        expect(e.rangoMax, 12);
        expect(e.motivo, MotivoProgresion.repiteCargas);
        expect(s.semana.incrementos, isFalse);
        // Sin foco, sí sube.
        expect(generar('A', historial: h).ejercicios.first.cargaPasos, 6);
      },
    );

    test('con el tope confirmado tampoco sube repeticiones ni series (escalera detenida)', () {
      final inv = inventarioBase().confirmando(CamposAparato.pasosMax, 10);
      final hh = [sesionHecha(fecha: dia(2026, 12, 1), carga: 10)];
      final foco = generar(
        'A',
        historial: hh,
        inventario: inv,
        modoFoco: true,
      ).ejercicios.first;
      expect((foco.rangoMax, foco.series, foco.tempo), (12, 3, '2-1-1'));
      final normal = generar(
        'A',
        historial: hh,
        inventario: inv,
      ).ejercicios.first;
      expect(normal.rangoMax, 15);
    });

    test(
      'la sesión sigue disponible, con la versión corta sugerida y sin culpa',
      () {
        final s = generar(
          'A',
          historial: h,
          modoFoco: true,
          version: VersionSesion.larga,
        );
        expect(s.ejercicios, isNotEmpty);
        expect(s.versionSugerida, VersionSesion.corta);
        expect(s.tiene(CodigoAviso.modoFoco), isTrue);
        expect(s.tiene(CodigoAviso.versionCortaSugerida), isTrue);
        final corta = generar(
          'A',
          historial: h,
          modoFoco: true,
          version: VersionSesion.corta,
        );
        expect(corta.tiene(CodigoAviso.versionCortaSugerida), isFalse);
        expect(MensajesGimnasio.modoFoco, isNot(contains('!')));
      },
    );

    test('el contador del ciclo no avanza durante el foco y retoma donde estaba', () {
      final foco = [dia(2026, 12, 7)];
      // Sin foco: 30/nov=1, 7/dic=2, 14/dic=3, 21/dic=4 (descarga).
      // Con la semana del 7/dic en foco: no cuenta, así que 14/dic=2, 21/dic=3
      // y la descarga cae el 28/dic.
      SemanaCiclo c(DateTime d) => semanaDelCiclo(
        hoy: d,
        inicioCiclo: lunes30nov,
        cicloSemanas: 4,
        lunesEnFoco: foco,
      )!;
      expect(c(dia(2026, 11, 30)).numero, 1);
      expect(
        c(dia(2026, 12, 7)).numero,
        2,
      ); // la semana de foco misma: se queda
      expect(c(dia(2026, 12, 14)).numero, 2);
      expect(c(dia(2026, 12, 21)).numero, 3);
      expect(c(dia(2026, 12, 21)).descarga, isFalse);
      expect(c(dia(2026, 12, 28)).descarga, isTrue);
    });

    test(
      'en una semana de descarga, el foco manda: tipo foco y sin bajar carga',
      () {
        final p = PerfilGimnasio(
          nivel: NivelGimnasio.intermedio,
          inicioCiclo: lunes30nov,
        );
        final hh = [sesionHecha(fecha: dia(2026, 12, 18))];
        final s = generar(
          'A',
          historial: hh,
          perfil: p,
          hoy: dia(2026, 12, 21),
          modoFoco: true,
        );
        expect(s.semanaTipo, TipoSemana.foco);
        expect(s.ejercicios.first.cargaPasos, 5);
        expect(s.ejercicios.first.series, 3);
      },
    );

    test(
      'CASO MALO: el generador no recibe ni expone qué hábito causó el foco',
      () {
        // El único parámetro es un booleano...
        final lib = Directory('lib/src/gimnasio');
        expect(lib.existsSync(), isTrue);
        final gen = File('lib/src/gimnasio/generador.dart').readAsStringSync();
        expect(RegExp(r'bool modoFoco\b').hasMatch(gen), isTrue);
        // ...y ningún archivo del gimnasio sabe de los hábitos a eliminar.
        for (final f in lib.listSync().whereType<File>()) {
          final src = f.readAsStringSync();
          for (final prohibido in [
            'PlanCigarrillo',
            'habito_eliminar',
            'RachaLibre',
            'FaseHabito',
            'sos.dart',
          ]) {
            expect(
              src.contains(prohibido),
              isFalse,
              reason: '${f.path} menciona $prohibido',
            );
          }
        }
        // La salida tampoco lleva causa: solo el tipo `foco` y un aviso de código.
        final s = generar('A', historial: h, modoFoco: true);
        expect(s.avisos.map((a) => a.codigo.name), contains('modoFoco'));
      },
    );
  });
}
