import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

void main() {
  group('CA-G-03 sin contenido médico', () {
    test('ningún texto del módulo tiene diagnóstico, tratamiento, medicamento, '
        'dosis ni nombre de lesión', () {
      final textos = textosDelModulo(cat);
      expect(textos.length, greaterThan(100));
      expect(validarContenidoMedico(textos), isEmpty);
    });

    test(
      'todo aviso de molestia incluye «profesional», «médico» o «entrenador»',
      () {
        expect(MensajesGimnasio.avisosDeMolestia, isNotEmpty);
        for (final t in MensajesGimnasio.avisosDeMolestia) {
          final s = t.toLowerCase();
          expect(
            s.contains('profesional') ||
                s.contains('médico') ||
                s.contains('entrenador'),
            isTrue,
            reason: t,
          );
        }
        expect(MensajesGimnasio.molestiaFuerte, contains('profesional'));
        expect(MensajesGimnasio.molestiaFuerte, contains('médico'));
        expect(MensajesGimnasio.molestiaFuerte, contains('entrenador'));
      },
    );

    test('CASO MALO: agregar «tendinitis» a un texto falla', () {
      final textos = [
        ...textosDelModulo(cat),
        'Esto puede ser una tendinitis.',
      ];
      final problemas = validarContenidoMedico(textos);
      expect(problemas, hasLength(1));
      expect(problemas.single, contains('tendinitis'));
    });

    test('CASO MALO: detecta mayúsculas, acentos y las demás categorías', () {
      for (final mala in [
        'TENDINITIS',
        'Toma ibuprofeno',
        'una dosis diaria',
        'Es un esguince',
        'el tratamiento indicado',
        'un diagnóstico claro',
        'Tienes una lesión',
        'ciática',
        'Pomada antiinflamatoria',
      ]) {
        expect(palabrasMedicasEn(mala), isNotEmpty, reason: mala);
      }
    });

    test('la frase «Esta guía no diagnostica» sigue permitida', () {
      expect(palabrasMedicasEn(MensajesGimnasio.molestiaCambio), isEmpty);
    });
  });

  group('CA-G-40 (parte de dominio) tono y mensajes', () {
    test('ningún mensaje usa palabras de culpa ni signos de exclamación', () {
      for (final t in MensajesGimnasio.todos) {
        for (final p in MensajesHabitos.prohibidas) {
          expect(
            t.toLowerCase().contains(p),
            isFalse,
            reason: '"$t" contiene "$p"',
          );
        }
      }
    });

    test(
      'los avisos discretos del descanso: sin dígitos y ≤ 40 caracteres',
      () {
        for (final t in TextoAvisoGimnasio.porTipo.values) {
          expect(t.length <= 40, isTrue);
          expect(RegExp(r'\d').hasMatch(t), isFalse);
        }
        expect(
          TextoAvisoGimnasio.porTipo['hab_descanso'],
          'Termina tu descanso',
        );
      },
    );

    test('textos de la especificación', () {
      expect(
        MensajesGimnasio.hoyToca('Fuerza A'),
        'Hoy toca Fuerza A. ¿Empezamos?',
      );
      expect(
        MensajesGimnasio.recordPersonal('press de pecho', 'placa 6'),
        'Nuevo récord personal en press de pecho: placa 6.',
      );
      expect(
        MensajesGimnasio.reentrada,
        'Retomemos con calma. Hoy cuenta empezar.',
      );
    });
  });
}
