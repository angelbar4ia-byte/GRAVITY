import 'package:ingles/ingles.dart';
import 'package:test/test.dart';

import 'apoyo/ayudas.dart';
import 'apoyo/curso.dart';

String _informe(List<Doc> docs) => Informe.de([
      ...baseDelCurso(),
      for (var i = 0; i < docs.length; i++) leerMapa('doc$i.yaml', clonar(docs[i])),
    ]).aTexto();

void main() {
  group('informe · rango por etapa (palabras_estimulo.por_nivel)', () {
    test('el rango de cada etapa sustituye al «sin rango» de las partes de los contratos propios', () {
      final t = _informe([]);
      final fila = t.split('\n').firstWhere((l) => l.startsWith('  traslado-audio'));
      expect(fila, contains('A1 60 a 120; A2 120 a 200; B1 200 a 350; B2 350 a 500'));
      expect(fila, isNot(contains('sin rango')));
    });
    test('un rango por etapa con un dato pendiente dentro lo dice', () {
      final c = contratoSesionConPruebas();
      final pe = mapa(mapa(lista(mapa(lista(c['secciones'])[1])['partes']).first)['palabras_estimulo']);
      pe['pendiente'] = true;
      final t = Informe.de([...baseDelCurso(sesion: c)]).aTexto();
      expect(t.split('\n').firstWhere((l) => l.startsWith('  traslado-audio')), contains('(pendiente)'));
    });
    test('los contratos de examen siguen mostrando su rango y su origen', () {
      final t = Informe.de(leerRuta('../../data/ingles')).aTexto();
      expect(t, contains('300 a 400 (medido)'));
    });
  });

  group('informe · cobertura por etapa', () {
    test('suma los escalones de la etapa sin contar dos veces una sesión ni un audio', () {
      final docs = juntar([
        sesionDelCurso(dia: 'lunes', semana: 1),
        sesionDelCurso(dia: 'martes', semana: 1),
        sesionDelCurso(dia: 'lunes', semana: 1, escalon: 'A2.2'),
      ]);
      final t = _informe(docs);
      final seccion = t.substring(t.indexOf('4. Cobertura por etapa'), t.indexOf('5. Datos pendientes'));
      expect(seccion, contains('A1: 2 escalones, 0 sesiones, 0 audios de traslado; 0 unidades de examen con 0 preguntas'));
      expect(seccion, contains('A2: 3 escalones, 3 sesiones, 4 audios de traslado'));
      expect(seccion, contains('B1: 4 escalones, 0 sesiones'));
      expect(seccion, contains('B2: 4 escalones, 0 sesiones'));
      // Tres sesiones de lección con 14 preguntas cada una (diez de opción múltiple y cuatro de respuesta corta).
      expect(seccion, matches(RegExp(r'gramatica\s+3\s+42')));
    });
    test('cuenta las unidades de examen que declaran la etapa', () {
      final t = Informe.de(leerRuta('../../data/ingles')).aTexto();
      final seccion = t.substring(t.indexOf('4. Cobertura por etapa'), t.indexOf('5. Datos pendientes'));
      expect(seccion, contains('B1: 4 escalones, 1 sesión, 2 audios de traslado; 2 unidades de examen con 15 preguntas'));
      expect(seccion, contains('B2: 4 escalones, 0 sesiones, 0 audios de traslado; 4 unidades de examen con 28 preguntas'));
    });
    test('sin niveles.yaml lo dice', () {
      final t = Informe.de([leerMapa('c.yaml', contratoReal('gravity-sesion-60'))]).aTexto();
      expect(t, contains('4. Cobertura por etapa\n   sin niveles'));
    });
  });

  group('informe · datos pendientes de los contratos', () {
    test('cuenta las marcas a cualquier profundidad y lista las rutas de cada contrato', () {
      final t = _informe([]);
      final seccion = t.substring(t.indexOf('5. Datos pendientes'));
      expect(seccion, contains('gravity-sesion-60: 14 datos pendientes'));
      expect(seccion, contains('- secciones.0.partes.1.por_dia.martes'));
      expect(seccion, contains('- viernes.estructura_de_la_conversacion_guiada'));
      expect(seccion, contains('gravity-escalon: 10 datos pendientes'));
      expect(seccion, matches(RegExp(r'niveles: \d+ datos pendientes')));
    });
    test('un contrato sin pendientes no aparece, y sin ninguno dice «ninguno»', () {
      final c = contratoReal('gravity-ubicacion');
      final limpio = Informe.de([
        leerMapa('formatos/c.yaml', {
          ...c,
          'secciones': [
            for (final s in lista(c['secciones']))
              {
                ...mapa(s),
                'partes': [
                  for (final p in lista(mapa(s)['partes'])) {...mapa(p)}..remove('pendiente'),
                ],
              },
          ],
          'banco': {'preguntas_por_etapa': 18, 'preguntas_total': 72},
        }),
      ]).aTexto();
      expect(limpio, contains('5. Datos pendientes de los contratos y de niveles.yaml\n   ninguno'));
    });
  });

  group('informe · fidelidad (no aplica a las mini pruebas)', () {
    test('una mini prueba dice que la fidelidad no aplica', () {
      final docs = [
        ...sesionDelCurso(dia: 'viernes', semana: 1),
      ];
      final t = _informe(docs);
      expect(t, contains('mini-a21-s01 (mini, gravity-sesion-60, borrador): no aplica'));
    });
  });
}
