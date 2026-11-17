import 'package:ingles/ingles.dart';
import 'package:test/test.dart';

import 'apoyo/ayudas.dart';
import 'apoyo/curso.dart';

/// Lo que el validador lee de los contratos propios (P1.2c-1): rango por etapa,
/// `por_dia`, `tolerancias_de_minutos`, `tarjetas_nuevas`, `sin_audio`,
/// `asistencia`, los bloques nuevos de la sesión y los `pendiente: true` a
/// cualquier profundidad. Parte de los contratos reales de `data/ingles`.
void main() {
  Formato contrato(String id) => (leerMapa('$id.yaml', contratoReal(id)) as ArchivoFormato).contrato;
  ContratoSesion sesion() => ContratoSesion(contrato('gravity-sesion-60'));

  group('palabras_estimulo.por_nivel', () {
    test('se lee un rango por etapa', () {
      final p = contrato('gravity-sesion-60').parte('traslado-audio')!;
      expect(p.palabrasPorNivel.keys, ['A1', 'A2', 'B1', 'B2']);
      expect(describirRango(p.palabrasPorNivel['A1']!), '60 a 120');
      expect(describirRango(p.palabrasPorNivel['B2']!), '350 a 500');
    });
    test('rangoDePalabras da el de la etapa, y null sin etapa o con una etapa que el contrato no trae', () {
      final p = contrato('gravity-sesion-60').parte('traslado-audio')!;
      expect(describirRango(rangoDePalabras(p, nivel: 'B1')!), '200 a 350');
      expect(rangoDePalabras(p), isNull);
      expect(rangoDePalabras(p, nivel: 'C1'), isNull);
    });
    test('un contrato de examen sigue dando un solo rango, con o sin etapa', () {
      final p = contrato('cambridge-b1-preliminary').parte('reading-3')!;
      expect(p.palabrasPorNivel, isEmpty);
      expect(describirRango(rangoDePalabras(p, nivel: 'A1')!), describirRango(rangoDePalabras(p)!));
    });
    test('malo: una etapa que no existe en por_nivel es un error de esquema (V01)', () {
      final c = contratoReal('gravity-sesion-60');
      final pn = mapa(mapa(mapa(lista(mapa(lista(c['secciones'])[1])['partes']).first)['palabras_estimulo'])['por_nivel']);
      pn['C1'] = {'min': 1, 'max': 2};
      final a = leerMapa('c.yaml', c);
      expect(a.lectura.map((h) => h.mensaje), anyElement(contains('la etapa "C1" no es válida')));
    });

    group('V15 con el rango de la etapa de la unidad', () {
      List<Hallazgo> v15(String nivel, int palabrasDelAudio, {Doc? contratoSesion}) {
        final u = audioDeTraslado('au-x', palabrasDelAudio: palabrasDelAudio)..['nivel'] = nivel;
        return avisos(correrCurso([u], sesion: contratoSesion), 'V15');
      }

      test('bueno: 160 palabras en A2 (120 a 200)', () => expect(v15('A2', 160), isEmpty));
      test('malo: las mismas 160 palabras en B1 (200 a 350)', () {
        final h = v15('B1', 160);
        expect(h.single.mensaje, contains('tiene 160 palabras'));
        expect(h.single.mensaje, contains('pide 200 a 350'));
      });
      test('malo: las mismas 160 palabras en A1 (60 a 120)', () {
        expect(v15('A1', 160).single.mensaje, contains('pide 60 a 120'));
      });
      test('un contrato por etapa sin rango para la etapa de la unidad avisa que no puede comprobar', () {
        final c = contratoSesionConPruebas();
        final pn = mapa(mapa(mapa(lista(mapa(lista(c['secciones'])[1])['partes']).first)['palabras_estimulo'])['por_nivel']);
        pn.remove('B1');
        final h = v15('B1', 160, contratoSesion: c);
        expect(h.single.mensaje, contains('da rango de palabras por etapa (A1, A2, B2)'));
      });
    });
  });

  group('lo que el contrato propio declara', () {
    test('por_dia de la lección, la pronunciación y las tarjetas nuevas', () {
      final k = sesion();
      expect(k.ejemplosMinimos('lunes'), 6);
      expect(k.preguntasMinimasDeLeccion('lunes'), 10);
      expect(k.exigeErrorComun('lunes'), isTrue);
      expect(k.preguntasMinimasDeLeccion('martes'), 10);
      expect(k.elementosDeLeccion('miercoles'), 14);
      expect(k.estimuloDeLeccion('jueves'), 'texto');
      expect(k.leccionSustituidaPor('viernes'), 'conversacion_guiada');
      expect(k.repasoSustituidoPor('viernes'), 'mini_prueba');
      for (final d in k.dias) {
        expect(k.elementosDePronunciacion(d), 12, reason: d);
      }
      expect(k.dias, ['lunes', 'martes', 'miercoles', 'jueves', 'viernes']);
      expect([for (final d in k.dias) k.tarjetasNuevasDelDia(d)], [8, 8, 8, 8, 0]);
      expect(k.tarjetasNuevasPorSemana, 32);
    });
    test('minutos por parte, tolerancias, sin audio y asistencia', () {
      final k = sesion();
      expect([for (final p in ['repaso', 'leccion', 'pronunciacion', 'produccion']) k.minutosDeParte(p)], [5, 10, 8, 12]);
      expect([k.minutosTotales, k.minutosPrincipal, k.minutosTraslado], [60, 35, 25]);
      expect([k.porcentajeMinimoPorBloque, k.porcentajeMaximoPorBloque, k.totalMinimo, k.totalMaximo], [70, 150, 54, 66]);
      expect(k.bloquesQueCuentanSinAudio, ['principal']);
      expect(k.minutosSinAudio, 35);
      expect([k.minutosPlaneadosConAudio, k.minutosPlaneadosSinAudio, k.faltanteMaximoPorDia, k.diasFaltadosPorEscalon], [60, 35, 600, 3]);
    });
    test('el traslado: dos audios, dos reproducciones y veinte frases', () {
      final k = sesion();
      expect([k.audiosDeTraslado, k.reproduccionesDeTraslado, k.frasesMinimas], [2, 2, 20]);
      expect(k.mismosAudiosTodaLaSemana, isTrue);
      expect(k.pendienteDeMonologoYDialogo, isNotNull);
    });
    test('el viernes: mini prueba, prueba por unidad y su composición', () {
      final k = sesion();
      expect([k.preguntasDeMiniPrueba, k.aprobarMiniPruebaCon], [10, 8]);
      expect(k.semanasDeMiniPrueba, [1, 2, 3, 4, 5, 6, 7]);
      expect(k.semanasDePruebaPorUnidad, [2, 4, 6, 7]);
      expect(k.semanasDeRepeticion, [3, 5, 7, 8]);
      expect([k.preguntasDePruebaConAudio, k.preguntasDePruebaSinAudio, k.umbralDePruebaPorcentaje], [20, 15, 80]);
      expect(k.composicionDePrueba, {'gramatica_del_tema': 6, 'vocabulario': 4, 'lectura': 5, 'escucha': 5});
      expect(k.turnosMinimosDeConversacion, 12);
    });
    test('las fórmulas de estimación salen del contrato', () {
      final k = sesion();
      expect([k.palabrasPorMinuto, k.segundosPorEjemplo, k.segundosPorFrase, k.segundosPorElemento, k.segundosPorTarjetaNueva], [150, 15, 30, 30, 15]);
      expect(k.segundosDePregunta('opcion_multiple'), 40);
      expect(k.segundosDePregunta('hueco_abierto'), 40);
      expect(k.segundosDePregunta('respuesta_corta'), 60);
      expect(k.segundosDePregunta('completar_nota'), isNull, reason: 'el contrato no da el tiempo de ese tipo');
    });
    test('un contrato sin esa estructura no declara la sesión (V21 y V22 callan)', () {
      expect(ContratoSesion((contratoSesionPrueba() as ArchivoFormato).contrato).declaraLaSesion, isFalse);
      expect(sesion().declaraLaSesion, isTrue);
    });
  });

  group('pendiente: true a cualquier profundidad', () {
    test('pendientesEn encuentra las marcas con su ruta, su id y su nota', () {
      final p = pendientesEn({
        'a': {'pendiente': true, 'nota': 'falta uno'},
        'b': [
          {'id': 'x', 'c': {'pendiente': true}},
          {'pendiente': false},
        ],
      });
      expect([for (final d in p) d.ruta], ['a', 'b.0.c']);
      expect(p.first.nota, 'falta uno');
      final conId = pendientesEn({'partes': [{'id': 'r-1', 'pendiente': true}]});
      expect(conId.single.ruta, 'partes.0 (r-1)');
    });
    test('una parte de un contrato propio sabe sus pendientes de por_dia', () {
      final leccion = contrato('gravity-sesion-60').parte('leccion')!;
      expect(leccion.pendiente, isFalse, reason: 'la parte no está marcada, pero sí tres de sus días');
      expect(leccion.tienePendientes, isTrue);
      expect(leccion.pendientes.map((d) => d.ruta), ['por_dia.martes', 'por_dia.miercoles', 'por_dia.jueves']);
      expect(leccion.rangoPendiente, isFalse);
    });
    test('el contrato entero cuenta las suyas; los de examen traen las de su manual', () {
      expect(contrato('gravity-sesion-60').pendientes, isNotEmpty);
      expect(contrato('gravity-escalon').pendientes, isNotEmpty);
    });
    test('niveles.yaml cuenta sus pendientes', () {
      final n = (leerMapa('niveles.yaml', nivelesReales()) as ArchivoNiveles).niveles;
      expect(n.pendientes.length, greaterThan(40));
    });
    test('un pendiente dentro de palabras_estimulo hace pendiente el rango (V15 avisa)', () {
      final c = contratoSesionConPruebas();
      final pe = mapa(mapa(lista(mapa(lista(c['secciones'])[1])['partes']).first)['palabras_estimulo']);
      pe['por_nivel'] = {'A2': {'min': 120, 'max': 200, 'pendiente': true}};
      final u = audioDeTraslado('au-x');
      final h = avisos(correrCurso([u], sesion: c), 'V15');
      expect(h.single.mensaje, startsWith('rango pendiente'));
    });
  });

  group('los bloques y las formas nuevos se leen', () {
    test('mini prueba, conversación guiada y prueba por unidad', () {
      final docs = sesionDelCurso(dia: 'viernes', semana: 2);
      final s = leerMapa('s.yaml', clonar(sesionDeLista(docs))) as Sesion;
      expect([for (final b in s.bloques) b.tipo], ['mini_prueba', 'prueba_unidad', 'pronunciacion', 'produccion', 'traslado']);
      final mini = s.bloques.first as BloqueMiniPrueba;
      expect(mini.forma, 'mini-a21-s02');
      final pu = s.bloques[1] as BloquePruebaUnidad;
      expect((pu.forma, pu.repeticion), ('pu-a21-u1-a', 'pu-a21-u1-b'));
      final c = leerMapa('s.yaml', clonar(sesionDeLista(sesionDelCurso(dia: 'viernes', semana: 1)))) as Sesion;
      final conv = c.bloques[1] as BloqueConversacion;
      expect(conv.turnos.where((t) => t.esDePersona), hasLength(8));
      final t = conv.turnos.firstWhere((t) => t.esDePersona);
      expect(t.guia, isNotEmpty);
      expect((t.modelo.length, t.variantes.length, t.palabrasClave.length), (1, 2, 1));
    });
    test('una forma de prueba por unidad trae escalón, unidad, variante y audio', () {
      final docs = sesionDelCurso(dia: 'viernes', semana: 2);
      final f = leerMapa('f.yaml', clonar(formaDe(docs, 'pu-a21-u1-b'))) as Forma;
      expect((f.uso, f.escalon, f.unidadDelEscalon, f.variante, f.conAudio), ('prueba_unidad', 'A2.1', 1, 'b', true));
    });
    test('malo: un turno de la persona sin modelo y un rol que no existe son errores de esquema', () {
      final d = sesionDelCurso(dia: 'viernes', semana: 1).first;
      final turnos = lista(bloque(d, 'conversacion_guiada')['turnos']);
      mapa(turnos[1]).remove('modelo');
      mapa(turnos[2])['rol'] = 'profesor';
      final a = leerMapa('s.yaml', clonar(d));
      final m = a.lectura.map((h) => h.mensaje).join('\n');
      expect(m, contains('modelo'));
      expect(m, contains('valor "profesor" no permitido'));
    });
  });

  group('V02: las formas de prueba y sus unidades', () {
    test('bueno: la unidad es de la parte y del formato de su sección', () {
      final docs = sesionDelCurso(dia: 'viernes', semana: 2);
      expect(errores(correrCurso(docs), 'V02'), isEmpty);
    });
    test('malo: una unidad de otra parte que la de su sección', () {
      final docs = sesionDelCurso(dia: 'viernes', semana: 2);
      unidadDe(docs, 'pu-a21-u1-a-voc')['parte'] = 'mini';
      final h = errores(correrCurso(docs), 'V02');
      expect(h.single.mensaje, contains('es de la parte "mini" y la sección la usa en "prueba-unidad"'));
    });
    test('malo: una unidad de otro formato que el de la forma', () {
      final docs = sesionDelCurso(dia: 'viernes', semana: 2);
      unidadDe(docs, 'pu-a21-u1-a-voc')['formato'] = 'gravity-escalon';
      final h = errores(correrCurso(docs), 'V02').map((x) => x.mensaje);
      expect(h, anyElement(contains('es del formato "gravity-escalon" y la forma es de "gravity-sesion-60"')));
    });
    test('malo: el bloque de la sesión remite a una forma que no existe o a algo que no es una forma', () {
      final docs = sesionDelCurso(dia: 'viernes', semana: 2);
      bloque(docs.first, 'prueba_unidad')['repeticion'] = 'pu-no-existe';
      bloque(docs.first, 'mini_prueba')['forma'] = unidadDe(docs, 'pu-a21-u1-a-voc')['id'];
      final h = errores(correrCurso(docs), 'V02').map((x) => x.mensaje);
      expect(h, anyElement(contains('remite a la forma "pu-no-existe", que no existe')));
      expect(h, anyElement(contains('existe pero es unidad, no una forma')));
    });
  });
}
