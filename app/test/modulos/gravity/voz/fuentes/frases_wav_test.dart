// Partir un turno en frases y codificar el audio como WAV (fuente B).
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/gravity/voz/audio/wav.dart';
import 'package:gravity/modulos/gravity/voz/fuentes/modelo/frases.dart';

void main() {
  group('partirEnFrases', () {
    test('parte por la puntuación y conserva los signos', () {
      expect(partirEnFrases('Good morning. Are you ready? Yes! Let us go.'), [
        'Good morning.',
        'Are you ready?',
        'Yes!',
        'Let us go.',
      ]);
    });

    test('un texto sin puntuación es una sola frase', () {
      expect(partirEnFrases('hello there my friend'), [
        'hello there my friend',
      ]);
    });

    test('no corta en abreviaturas, iniciales ni números con punto', () {
      expect(
        partirEnFrases(
          'Mr. Smith lives at 3.5 miles from here. He is J. K. Rowling.',
        ),
        ['Mr. Smith lives at 3.5 miles from here.', 'He is J. K. Rowling.'],
      );
      expect(partirEnFrases('The bus leaves at 8 a.m. today.'), [
        'The bus leaves at 8 a.m. today.',
      ]);
    });

    test(
      'los puntos suspensivos y los cierres de comillas se quedan con su frase',
      () {
        expect(
          partirEnFrases('He said "no way!" and left... Then it rained.'),
          ['He said "no way!"', 'and left...', 'Then it rained.'],
        );
      },
    );

    test('un salto de línea también separa', () {
      expect(partirEnFrases('One\nTwo three'), ['One', 'Two three']);
    });

    test('un texto vacío o de puros espacios no da frases', () {
      expect(partirEnFrases(''), isEmpty);
      expect(partirEnFrases('   \n  '), isEmpty);
    });

    test(
      'un fragmento sin letras (solo signos) se pega a la frase anterior',
      () {
        expect(partirEnFrases('Really? ... Yes.'), ['Really? ...', 'Yes.']);
      },
    );

    test('una frase muy larga se corta en una coma sin pasar del máximo', () {
      final larga = List.filled(30, 'this is a clause').join(', ');
      final frases = partirEnFrases('$larga.');
      expect(frases.length, greaterThan(1));
      for (final f in frases) {
        expect(f.length, lessThanOrEqualTo(largoMaximoDeFrase));
      }
      expect(
        frases.join(' ').replaceAll(RegExp(r'\s+'), ' '),
        contains('this is a clause'),
      );
    });

    test('una palabra interminable se corta igual', () {
      final frases = partirEnFrases('a' * 500);
      for (final f in frases) {
        expect(f.length, lessThanOrEqualTo(largoMaximoDeFrase + 1));
      }
      expect(frases.join().length, 500);
    });
  });

  group('codificarWav', () {
    test(
      'escribe un encabezado WAV PCM de 16 bits mono con la frecuencia pedida',
      () {
        final wav = codificarWav(
          Float32List.fromList([0, 0.5, -0.5, 1, -1]),
          22050,
        );
        final v = ByteData.view(wav.buffer);
        expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
        expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
        expect(String.fromCharCodes(wav.sublist(12, 16)), 'fmt ');
        expect(v.getUint16(20, Endian.little), 1, reason: 'PCM');
        expect(v.getUint16(22, Endian.little), 1, reason: 'mono');
        expect(v.getUint32(24, Endian.little), 22050);
        expect(v.getUint32(28, Endian.little), 44100);
        expect(v.getUint16(34, Endian.little), 16);
        expect(String.fromCharCodes(wav.sublist(36, 40)), 'data');
        expect(v.getUint32(40, Endian.little), 10);
        expect(wav.length, 54);
        expect(v.getUint32(4, Endian.little), wav.length - 8);
      },
    );

    test('convierte las muestras a enteros de 16 bits y las acota', () {
      final wav = codificarWav(
        Float32List.fromList([0, 0.5, -0.5, 2, -2]),
        8000,
      );
      final v = ByteData.view(wav.buffer);
      int m(int i) => v.getInt16(44 + i * 2, Endian.little);
      expect(m(0), 0);
      expect(m(1), 16384);
      expect(m(2), -16384);
      expect(m(3), 32767, reason: 'se acota a 1.0');
      expect(m(4), -32767);
    });

    test('un audio vacío da solo el encabezado', () {
      expect(codificarWav(Float32List(0), 22050).length, 44);
    });

    test('duracionDe', () {
      expect(duracionDe(22050, 22050), const Duration(seconds: 1));
      expect(duracionDe(11025, 22050), const Duration(milliseconds: 500));
      expect(duracionDe(10, 0), Duration.zero);
    });
  });
}
