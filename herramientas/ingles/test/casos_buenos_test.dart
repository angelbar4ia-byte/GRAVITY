import 'package:ingles/ingles.dart';
import 'package:test/test.dart';

import 'apoyo/ayudas.dart';
import 'apoyo/casos.dart';

void main() {
  final buenos = <String, List<Doc>>{
    'opción múltiple': [opcionMultiple()],
    'ocho preguntas': [ochoPreguntas()],
    'hueco de opciones': [huecoOpciones()],
    'hueco abierto': [huecoAbierto()],
    'formación de palabra': [formacionPalabra()],
    'transformación': [transformacion()],
    'oración omitida': [oracionOmitida()],
    'correspondencia': [correspondencia()],
    'emparejar': [emparejar()],
    'completar nota': [completarNota()],
    'completar palabras': [completarPalabras()],
    'variadas': [variadas()],
    'sesión con su audio': sesionConAudio(),
    'forma': [forma(), opcionMultiple()],
  };

  group('los casos buenos no dejan ningún hallazgo', () {
    buenos.forEach((nombre, docs) {
      test(nombre, () => expect(propios(correr(docs)), isEmpty));
    });
  });

  group('cada tipo de pregunta tiene su clase', () {
    final esperadas = <String, Type>{
      'opcion_multiple': OpcionMultiple,
      'hueco_opciones': HuecoOpciones,
      'hueco_abierto': HuecoAbierto,
      'formacion_palabra': FormacionPalabra,
      'transformacion': Transformacion,
      'oracion_omitida': OracionOmitidaPregunta,
      'correspondencia': Correspondencia,
      'emparejar': Emparejar,
      'completar_nota': CompletarNota,
      'completar_palabras': CompletarPalabras,
      'ordenar_palabras': OrdenarPalabras,
      'respuesta_corta': RespuestaCorta,
      'repetir': Repetir,
      'pronunciacion': PronunciacionPregunta,
      'produccion': Produccion,
    };
    test('los 15 tipos de la tabla 4.2 están cubiertos', () {
      final docs = [
        opcionMultiple(), huecoOpciones(), huecoAbierto(), formacionPalabra(),
        transformacion(), oracionOmitida(), correspondencia(), emparejar(),
        completarNota(), completarPalabras(), variadas(),
      ];
      final tipos = <String, Type>{};
      for (final d in docs) {
        final u = leerMapa('x.yaml', clonar(d)) as Unidad;
        for (final q in u.preguntas) {
          tipos[q.tipo] = q.runtimeType;
        }
      }
      expect(tipos, esperadas);
    });
  });

  test('una sesión se lee con sus bloques, su tarea y sus tarjetas', () {
    final s = leerMapa('s.yaml', clonar(sesion())) as Sesion;
    expect(s.bloques.map((b) => b.tipo), ['repaso', 'leccion', 'produccion', 'traslado']);
    expect(s.preguntas.map((q) => q.id), ['t-s01-lun-01', 't-s01-lun-prod']);
    expect(s.tarjetas.single.id, 't-s01-tarjeta-0001');
  });

  test('un contrato se lee con sus partes', () {
    final f = contratoPrueba() as ArchivoFormato;
    expect(f.contrato.parte('p-om')!.opciones, 4);
    expect(f.contrato.parte('p-oo')!.preguntasPorUnidad!.min, 3);
    expect(f.contrato.parte('p-cp-provisional')!.ocultar!.pendiente, isTrue);
    expect(f.contrato.parte('no-existe'), isNull);
  });
}
