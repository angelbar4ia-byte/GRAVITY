import 'package:ingles/ingles.dart';
import 'package:test/test.dart';

import 'apoyo/ayudas.dart';
import 'apoyo/curso.dart';

const _sesion = 'formatos/gravity-sesion-60.yaml';
const _escalon = 'formatos/gravity-escalon.yaml';
const _ubicacion = 'formatos/gravity-ubicacion.yaml';
const _niveles = 'niveles.yaml';

Doc _parte(Doc contrato, String id) {
  for (final s in lista(contrato['secciones'])) {
    for (final p in lista(mapa(s)['partes'])) {
      if (mapa(p)['id'] == id) return mapa(p);
    }
  }
  throw StateError('no hay la parte $id');
}

Doc _seccion(Doc contrato, String id) => mapa(lista(contrato['secciones']).firstWhere((s) => mapa(s)['id'] == id));

/// Los hallazgos V27 de cada archivo de contrato o de niveles, con los
/// contratos y niveles reales y el cambio que se indique.
List<Hallazgo> _v27({
  void Function(Doc)? sesion,
  void Function(Doc)? escalon,
  void Function(Doc)? ubicacion,
  void Function(Doc)? niveles,
}) {
  final s = contratoSesionConPruebas();
  final e = contratoReal('gravity-escalon');
  final u = contratoReal('gravity-ubicacion');
  final n = nivelesReales();
  sesion?.call(s);
  escalon?.call(e);
  ubicacion?.call(u);
  niveles?.call(n);
  return validarArchivos(baseDelCurso(sesion: s, escalon: e, ubicacion: u, niveles: n)).hallazgos.where((h) => h.codigo == 'V27').toList();
}

List<String> _err(List<Hallazgo> h, String archivo) => [for (final x in h) if (x.archivo == archivo && x.esError) x.mensaje];
List<String> _avi(List<Hallazgo> h, String archivo) => [for (final x in h) if (x.archivo == archivo && !x.esError) x.mensaje];

void main() {
  group('V27 · los contratos y niveles reales', () {
    test('bueno: ninguno tiene un solo error de consistencia', () {
      final h = _v27();
      expect(h.where((x) => x.esError), isEmpty, reason: h.where((x) => x.esError).join('\n'));
    });
    test('los avisos que quedan son los mínimos que no alcanzan el 70 % con datos pendientes en el contrato', () {
      final a = _avi(_v27(), _sesion);
      expect(a, isNotEmpty);
      for (final m in a) {
        expect(m, contains('dato pendiente en el contrato'));
        expect(m, contains('V21 aceptaría sesiones que V22 rechaza'));
      }
      expect(a, anyElement(contains('la lección del martes')));
    });
  });

  group('V27 · gravity-sesion-60: sumas de minutos', () {
    test('malo: una sección declara más minutos que la suma de sus partes', () {
      final e = _err(_v27(sesion: (c) => _seccion(c, 'principal')['minutos'] = 36), _sesion);
      expect(e, contains('la sección "principal" declara 36 minutos y sus partes suman 35'));
    });
    test('malo: cambia una parte y la sección ya no suma', () {
      final e = _err(_v27(sesion: (c) => _parte(c, 'repaso')['minutos_parte'] = 6), _sesion);
      expect(e, contains('la sección "principal" declara 35 minutos y sus partes suman 36'));
    });
    test('malo: el total no es la suma de las secciones ni minutos_principal + minutos_traslado', () {
      final e = _err(_v27(sesion: (c) => mapa(c['totales'])['minutos'] = 61), _sesion);
      expect(e, anyElement(contains('totales.minutos y la suma de las secciones: 61 y 60 no coinciden')));
      expect(e, anyElement(contains('totales.minutos y minutos_principal + minutos_traslado: 61 y 60 no coinciden')));
    });
    test('malo: minutos_traslado no es el de la sección', () {
      final e = _err(_v27(sesion: (c) => mapa(c['totales'])['minutos_traslado'] = 20), _sesion);
      expect(e, anyElement(contains('totales.minutos_traslado y la sección traslado: 20 y 25 no coinciden')));
    });
    test('malo: el total queda fuera de las tolerancias', () {
      final e = _err(_v27(sesion: (c) => mapa(mapa(c['tolerancias_de_minutos'])['total'])['max'] = 58), _sesion);
      expect(e, anyElement(contains('queda fuera de tolerancias_de_minutos.total (54 a 58)')));
    });
    test('malo: los porcentajes por bloque no rodean el 100 %', () {
      final e = _err(_v27(sesion: (c) => mapa(mapa(c['tolerancias_de_minutos'])['por_bloque'])['maximo_porcentaje'] = 90), _sesion);
      expect(e, anyElement(contains('debe rodear el 100 %')));
    });
  });

  group('V27 · gravity-sesion-60: días, tarjetas, sin audio y asistencia', () {
    test('malo: sesiones por semana distinto de los días', () {
      final e = _err(_v27(sesion: (c) => mapa(c['totales'])['sesiones_por_semana'] = 4), _sesion);
      expect(e, anyElement(contains('totales.sesiones_por_semana y los días de dias.lista: 4 y 5 no coinciden')));
    });
    test('malo: las tarjetas por semana no suman las de los días', () {
      final e = _err(_v27(sesion: (c) => mapa(c['tarjetas_nuevas'])['por_semana'] = 30), _sesion);
      expect(e, anyElement(contains('tarjetas_nuevas.por_semana y la suma de las tarjetas por día: 30 y 32 no coinciden')));
    });
    test('malo: un día que no existe en las tarjetas por día', () {
      final e = _err(_v27(sesion: (c) => mapa(mapa(c['tarjetas_nuevas'])['por_dia'])['sabado'] = 8), _sesion);
      expect(e, anyElement(contains('trae días que no existen: sabado')));
    });
    test('malo: falta un día en la pronunciación', () {
      final e = _err(_v27(sesion: (c) => mapa(_parte(c, 'pronunciacion')['por_dia']).remove('jueves')), _sesion);
      expect(e, contains('pronunciacion.por_dia no trae el día jueves'));
    });
    test('malo: sin audio no cuenta solo el principal', () {
      var e = _err(_v27(sesion: (c) => mapa(c['sin_audio'])['minutos_que_cuentan_al_dia'] = 30), _sesion);
      expect(e, anyElement(contains('sin_audio.minutos_que_cuentan_al_dia y totales.minutos_principal: 30 y 35 no coinciden')));
      e = _err(_v27(sesion: (c) => mapa(c['sin_audio'])['cuentan'] = ['principal', 'traslado']), _sesion);
      expect(e, anyElement(contains('sin_audio.cuentan debe ser [principal]')));
    });
    test('malo: los minutos planeados de la asistencia no son los de la sesión', () {
      final e = _err(_v27(sesion: (c) => mapa(mapa(c['asistencia'])['minutos_planeados_por_dia'])['con_audio'] = 50), _sesion);
      expect(e, anyElement(contains('asistencia.minutos_planeados_por_dia.con_audio y totales.minutos: 50 y 60 no coinciden')));
    });
  });

  group('V27 · gravity-sesion-60: el viernes', () {
    test('malo: la repetición no va el lunes siguiente', () {
      final e = _err(_v27(sesion: (c) => mapa(mapa(mapa(c['viernes'])['prueba_por_unidad'])['repeticion'])['semanas'] = [3, 5, 7, 9]), _sesion);
      expect(e.single, contains('con las pruebas en las semanas 2, 4, 6, 7 debería ir en las 3, 5, 7, 8'));
    });
    test('malo: la composición no suma las preguntas con audio', () {
      final e = _err(_v27(sesion: (c) => mapa(mapa(mapa(c['viernes'])['prueba_por_unidad'])['composicion_con_audio'])['escucha'] = 6), _sesion);
      expect(e, anyElement(contains('con_audio y la suma de composicion_con_audio: 20 y 21 no coinciden')));
    });
    test('malo: las preguntas sin audio no son las de con audio menos las de escucha', () {
      final e = _err(_v27(sesion: (c) => mapa(mapa(mapa(c['viernes'])['prueba_por_unidad'])['preguntas'])['sin_audio'] = 16), _sesion);
      expect(e, anyElement(contains('preguntas.sin_audio y con_audio menos las de escucha: 16 y 15 no coinciden')));
    });
    test('malo: los minutos estimados que anota el contrato no son preguntas × 40 s', () {
      final e = _err(_v27(sesion: (c) => mapa(mapa(mapa(c['viernes'])['prueba_por_unidad'])['minutos_estimados'])['con_audio'] = 14), _sesion);
      expect(e.single, contains('anota 14 minutos y 20 preguntas de 40 segundos dan 13.3'));
    });
    test('malo: se aprueba con más aciertos que preguntas', () {
      final e = _err(_v27(sesion: (c) => mapa(mapa(c['viernes'])['mini_prueba'])['aprobar_con'] = 11), _sesion);
      expect(e, anyElement(contains('aprobar_con (11) debe estar entre 1 y las preguntas (10)')));
    });
    test('malo: más pruebas por unidad de las semanas que se listan', () {
      final e = _err(_v27(sesion: (c) => mapa(mapa(c['viernes'])['prueba_por_unidad'])['por_escalon'] = 5), _sesion);
      expect(e, anyElement(contains('por_escalon y las semanas de viernes_de_las_semanas: 5 y 4 no coinciden')));
    });
  });

  group('V27 · gravity-sesion-60: longitudes y mínimos que alcanzan el 70 %', () {
    test('malo: el audio de B1 no mide lo mismo en la tabla de longitudes y en el traslado', () {
      final e = _err(_v27(sesion: (c) => mapa(mapa(mapa(c['longitudes_por_etapa'])['B1'])['audio_palabras'])['max'] = 360), _sesion);
      expect(e.single, contains('el audio de B1 mide 200 a 360 en longitudes_por_etapa y 200 a 350 en traslado-audio.por_nivel'));
    });
    test('malo: un mínimo de pronunciación que estima el 50 % del bloque', () {
      final e = _err(_v27(sesion: (c) => mapa(mapa(_parte(c, 'pronunciacion')['por_dia'])['lunes'])['elementos'] = {'min': 8}), _sesion);
      expect(e.single, contains('la pronunciación del lunes estiman 4.0 minutos, el 50 % de los 8 declarados'));
    });
    test('malo: un mínimo de lección de lunes que no llega al 70 %', () {
      final e = _err(_v27(sesion: (c) => mapa(mapa(_parte(c, 'leccion')['por_dia'])['lunes'])['preguntas'] = {'min': 6}), _sesion);
      expect(e.single, contains('la lección del lunes estiman'));
      expect(e.single, contains('V21 aceptaría sesiones que V22 rechaza'));
    });
    test('malo: veinte frases a 30 s que ya no llenan los 10 minutos de repetición', () {
      final e = _err(_v27(sesion: (c) {
        mapa(_parte(c, 'traslado-repeticion')['frases'])['min'] = 10;
        // Se quita lo pendiente de las tarjetas para que la comprobación sea de error y no de aviso.
        mapa(c['tarjetas_nuevas']).remove('se_cuentan_en_el_bloque');
      }), _sesion);
      expect(e.single, contains('el traslado'));
    });
    test('los mínimos que dependen de un dato pendiente son aviso, no error', () {
      final h = _v27();
      expect(_err(h, _sesion), isEmpty);
      expect(_avi(h, _sesion).where((m) => m.contains('conversación guiada')), isEmpty, reason: 'con 12 turnos y 6 de la persona el mínimo alcanza el 75 %');
    });
  });

  group('V27 · un contrato al que le falta un dato', () {
    test('malo (aviso en borrador): falta totales.minutos', () {
      final a = _avi(_v27(sesion: (c) => mapa(c['totales']).remove('minutos')), _sesion);
      expect(a, anyElement(contains('el contrato no declara totales.minutos: V21 y V22 comparan con los 60 minutos')));
    });
    test('malo (error desde validado): falta totales.minutos y el contrato está validado', () {
      final e = _err(_v27(sesion: (c) {
        mapa(c['totales']).remove('minutos');
        c['estado'] = 'validado';
      }), _sesion);
      expect(e, anyElement(contains('el contrato no declara totales.minutos')));
    });
    test('un contrato mínimo (el de prueba de la sesión) deja sus avisos en el contrato, no en las sesiones', () {
      final archivos = <Archivo>[contratoSesionPrueba(), leerMapa('doc0.yaml', clonar(sesionDelCurso().first))];
      final h = validarArchivos(archivos).hallazgos;
      expect(h.where((x) => x.codigo == 'V27' && x.archivo == 'contrato-sesion-prueba.yaml'), isNotEmpty);
      expect(h.where((x) => (x.codigo == 'V21' || x.codigo == 'V22') && x.archivo == 'doc0.yaml'), isEmpty);
    });
  });

  group('V27 · gravity-escalon', () {
    test('malo: 12 escalones en lugar de 13', () {
      final e = _err(_v27(escalon: (c) => mapa(c['totales'])['escalones'] = 12), _escalon);
      expect(e, anyElement(contains('totales.escalones y escalera.escalones_total: 12 y 13 no coinciden')));
      expect(e, anyElement(contains('totales.horas_totales y horas_por_escalon × escalones: 520 y 480 no coinciden')));
    });
    test('malo: horas ≠ 40 × escalones', () {
      final e = _err(_v27(escalon: (c) => mapa(c['totales'])['horas_totales'] = 500), _escalon);
      expect(e, anyElement(contains('totales.horas_totales y horas_por_escalon × escalones: 500 y 520 no coinciden')));
    });
    test('malo: las horas del escalón no salen de semanas × días × minutos', () {
      final e = _err(_v27(escalon: (c) => mapa(c['escalera'])['semanas_por_escalon'] = 7), _escalon);
      expect(e, anyElement(contains('las horas por escalón y semanas × días × minutos ÷ 60: 40 y 35 no coinciden')));
    });
    test('malo: las horas acumuladas de una etapa', () {
      final e = _err(_v27(escalon: (c) => mapa(lista(c['etapas'])[1])['horas_acumuladas'] = 190), _escalon);
      expect(e.single, contains('la etapa A2 acumula 190 horas y 3 escalones más los anteriores dan 200'));
    });
    test('malo: una etapa que cierra en otro escalón', () {
      final e = _err(_v27(escalon: (c) => mapa(lista(c['etapas'])[2])['escalon_de_cierre'] = 'B1.3'), _escalon);
      expect(e.single, contains('la etapa B1 cierra en B1.3 y su último escalón es B1.4'));
    });
    test('malo: las formas de puerta no son puertas × 3', () {
      final e = _err(_v27(escalon: (c) => mapa(mapa(c['formas'])['total'])['formas_de_puerta'] = 38), _escalon);
      expect(e, anyElement(contains('formas.total.formas_de_puerta y puertas × formas por puerta: 38 y 39 no coinciden')));
    });
    test('malo: una oportunidad menos que las que dice el contrato de formas', () {
      final e = _err(_v27(escalon: (c) => mapa(c['oportunidades'])['por_puerta'] = 3), _escalon);
      expect(e, anyElement(contains('oportunidades.por_puerta y formas.oportunidades: 3 y 2 no coinciden')));
    });
    test('malo: las preguntas por escalón de las pruebas por unidad', () {
      final e = _err(_v27(escalon: (c) => mapa(mapa(mapa(c['formas'])['pruebas_por_unidad']))['preguntas_por_escalon'] = 150), _escalon);
      expect(e, anyElement(contains('preguntas_por_escalon y formas × preguntas con audio: 150 y 160 no coinciden')));
    });
    test('malo: la asistencia de gravity-escalon no es la de gravity-sesion-60', () {
      var e = _err(_v27(escalon: (c) => mapa(mapa(mapa(c['requisitos_para_subir'])['minutos']))['faltante_maximo_por_dia_segundos'] = 300), _escalon);
      expect(e.single, contains('el faltante máximo por día (segundos) de gravity-escalon y de gravity-sesion-60: 300 y 600 no coinciden'));
      e = _err(_v27(escalon: (c) => mapa(mapa(c['requisitos_para_subir'])['constancia'])['dias_faltados_maximos_por_escalon'] = 4), _escalon);
      expect(e.single, contains('los días faltados por escalón de gravity-escalon y de gravity-sesion-60: 4 y 3 no coinciden'));
    });
    test('malo: la misma asistencia cambiada del lado de la sesión', () {
      final e = _err(_v27(sesion: (c) => mapa(c['asistencia'])['dias_faltados_tolerados_por_escalon'] = 5), _escalon);
      expect(e.single, contains('de gravity-escalon y de gravity-sesion-60: 3 y 5 no coinciden'));
    });
    test('malo: la mini prueba de gravity-escalon no es la de la sesión', () {
      final e = _err(_v27(escalon: (c) => mapa(c['mini_prueba'])['aprobar_con'] = 7), _escalon);
      expect(e.single, contains('mini_prueba.aprobar_con de gravity-escalon y de gravity-sesion-60: 7 y 8 no coinciden'));
    });
    test('malo: las pruebas por unidad que hay que aprobar no son las del viernes', () {
      final e = _err(_v27(escalon: (c) => mapa(mapa(mapa(c['requisitos_para_subir'])['pruebas_aprobadas']))['unidades'] = 3), _escalon);
      expect(e.single, contains('las pruebas por unidad que hay que aprobar y las del viernes de gravity-sesion-60: 3 y 4 no coinciden'));
    });
    test('malo: la puerta anticipada no es más exigente que la puerta', () {
      final e = _err(_v27(escalon: (c) => mapa(c['puerta_anticipada'])['porcentaje_minimo_por_habilidad'] = 80), _escalon);
      expect(e, anyElement(contains('la puerta anticipada (80 %) debe ser más exigente que la puerta (80 %)')));
    });
    test('malo: las habilidades no suman 100 %', () {
      final e = _err(_v27(escalon: (c) => mapa(c['habilidades'])['peso_en_el_resultado'] = 20), _escalon);
      expect(e, anyElement(contains('las 4 habilidades de 20 % no suman 100 %')));
    });
    test('sin gravity-sesion-60 no se pueden contrastar (aviso)', () {
      final archivos = <Archivo>[leerMapa(_escalon, contratoReal('gravity-escalon'))];
      final h = validarArchivos(archivos).hallazgos.where((x) => x.codigo == 'V27' && !x.esError).map((x) => x.mensaje);
      expect(h, anyElement(contains('falta el contrato gravity-sesion-60')));
    });
  });

  group('V27 · gravity-ubicacion', () {
    test('malo: una etapa de 13 preguntas', () {
      final e = _err(_v27(ubicacion: (c) => mapa(lista(c['secciones'])[0])['preguntas_total'] = 13), _ubicacion);
      expect(e.single, contains('preguntas_total de la sección A1 y la suma de sus partes: 13 y 12 no coinciden'));
    });
    test('malo: una parte cuyas unidades × preguntas no son su total', () {
      final e = _err(_v27(ubicacion: (c) => _parte(c, 'a2-lectura')['preguntas_por_unidad'] = 4), _ubicacion);
      expect(e.single, contains('la parte a2-lectura tiene 1 unidades de 4 preguntas y declara 3'));
    });
    test('malo: 5 + 4 + 3 en lugar de 6 + 3 + 3', () {
      final e = _err(_v27(ubicacion: (c) {
        _parte(c, 'b1-gramatica-vocabulario')
          ..['unidades'] = 5
          ..['preguntas_total'] = 5;
        _parte(c, 'b1-lectura')
          ..['preguntas_por_unidad'] = 4
          ..['preguntas_total'] = 4;
      }), _ubicacion);
      expect(e, anyElement(contains('la sección B1 trae 5 preguntas con estímulo ninguno y el plan pide 6 (6 + 3 + 3)')));
      expect(e, anyElement(contains('la sección B1 trae 4 preguntas con estímulo texto y el plan pide 3 (6 + 3 + 3)')));
    });
    test('malo: el total de la ubicación no es 12 × 4', () {
      final e = _err(_v27(ubicacion: (c) => mapa(c['totales'])['preguntas'] = 40), _ubicacion);
      expect(e, anyElement(contains('totales.preguntas y etapas × preguntas por etapa: 40 y 48 no coinciden')));
    });
    test('malo: el banco no suma 18 por etapa', () {
      final e = _err(_v27(ubicacion: (c) => mapa(c['banco'])['preguntas_total'] = 70), _ubicacion);
      expect(e, anyElement(contains('banco.preguntas_total y etapas × banco.preguntas_por_etapa: 70 y 72 no coinciden')));
    });
    test('malo: el corte no es sobre las preguntas por etapa', () {
      final e = _err(_v27(ubicacion: (c) => mapa(c['corte'])['de'] = 10), _ubicacion);
      expect(e, anyElement(contains('corte.de (10) debe ser las preguntas por etapa (12)')));
    });
    test('malo: el rango de lectura de la ubicación no es el de la tabla de gravity-sesion-60', () {
      final e = _err(_v27(ubicacion: (c) => mapa(_parte(c, 'a1-lectura')['palabras_estimulo'])['max'] = 130), _ubicacion);
      expect(e.single, contains('a1-lectura mide 60 a 130 palabras y la tabla de gravity-sesion-60 da 60 a 120 para A1 (lectura_palabras)'));
    });
    test('malo: el rango de escucha cambiado del lado de la sesión', () {
      final e = _err(_v27(sesion: (c) => mapa(mapa(mapa(c['longitudes_por_etapa'])['B2'])['audio_palabras'])['max'] = 520), _ubicacion);
      expect(e.single, contains('b2-escucha mide 350 a 500 palabras y la tabla de gravity-sesion-60 da 350 a 520 para B2 (audio_palabras)'));
    });
    test('malo: las etapas fuera de orden', () {
      final e = _err(_v27(ubicacion: (c) {
        final s = lista(c['secciones']);
        final x = s[0];
        s[0] = s[1];
        s[1] = x;
      }), _ubicacion);
      expect(e, anyElement(contains('la sección 1 es de A2 y debería ser de A1')));
    });
  });

  group('V27 · niveles.yaml', () {
    Doc esc(Doc n, String id) => mapa(lista(n['escalones']).firstWhere((e) => mapa(e)['id'] == id));

    test('malo: doce escalones', () {
      final e = _err(_v27(niveles: (n) => lista(n['escalones']).removeLast()), _niveles);
      expect(e, anyElement(contains('los escalones de niveles.yaml y totales.escalones de gravity-escalon: 12 y 13 no coinciden')));
    });
    test('malo: un tema nuevo en dos escalones', () {
      final e = _err(_v27(niveles: (n) => lista(esc(n, 'A1.2')['gramatica_nueva']).add('gram.verbo_to_be')), _niveles);
      expect(e.single, contains('el tema gram.verbo_to_be es nuevo en A1.1 y en A1.2: un tema es nuevo en un solo escalón'));
    });
    test('malo: un escalón retoma un tema que es nuevo en uno posterior', () {
      final e = _err(_v27(niveles: (n) => lista(esc(n, 'A1.1')['gramatica_que_se_retoma']).add('gram.presente_continuo')), _niveles);
      expect(e.single, contains('A1.1 retoma gram.presente_continuo, que es nuevo en A2.1: un escalón solo retoma temas de escalones anteriores'));
    });
    test('malo: un escalón retoma un tema que él mismo enseña', () {
      final e = _err(_v27(niveles: (n) => lista(esc(n, 'A2.1')['gramatica_que_se_retoma']).add('gram.was_were')), _niveles);
      expect(e.single, contains('A2.1 retoma gram.was_were, que es nuevo en A2.1'));
    });
    test('malo: un escalón retoma un tema que no existe', () {
      final e = _err(_v27(niveles: (n) => lista(esc(n, 'A2.1')['gramatica_que_se_retoma']).add('gram.no_existe')), _niveles);
      expect(e.single, contains('A2.1 retoma gram.no_existe, que no es nuevo en ningún escalón'));
    });
    test('malo: un tema de la lista que no es nuevo en ningún escalón', () {
      final e = _err(_v27(niveles: (n) => lista(n['temas']).add({'id': 'gram.huerfano', 'nombre': 'Huérfano'})), _niveles);
      expect(e.single, contains('el tema gram.huerfano está en la lista de temas y no es nuevo en ningún escalón'));
    });
    test('malo: un tema nuevo que no está en la lista de temas', () {
      final e = _err(_v27(niveles: (n) => lista(esc(n, 'B2.4')['gramatica_nueva']).add('gram.sin_lista')), _niveles);
      expect(e.single, contains('el tema gram.sin_lista es nuevo en B2.4 y no está en la lista de temas'));
    });
    test('malo: las horas del escalón y las acumuladas', () {
      var e = _err(_v27(niveles: (n) => esc(n, 'A2.2')['horas'] = 39), _niveles);
      expect(e.single, contains('las horas de A2.2 y las de gravity-escalon: 39 y 40 no coinciden'));
      e = _err(_v27(niveles: (n) => esc(n, 'A2.2')['horas_acumuladas_al_cerrar'] = 150), _niveles);
      expect(e.single, contains('horas_acumuladas_al_cerrar de A2.2 y 40 × su orden: 150 y 160 no coinciden'));
    });
    test('malo: un escalón sin el descriptor de habla', () {
      final e = _err(_v27(niveles: (n) => mapa(esc(n, 'B1.1')['puedo']).remove('habla')), _niveles);
      expect(e.single, contains('el escalón B1.1 no trae el descriptor "puedo" de habla'));
    });
    test('malo: la etapa de un escalón no es la de gravity-escalon', () {
      final e = _err(_v27(niveles: (n) => esc(n, 'A2.3')['etapa'] = 'B1'), _niveles);
      expect(e, anyElement(contains('gravity-escalon no pone a A2.3 en la etapa B1')));
    });
    test('malo: la puerta de un escalón de cierre no es la de su etapa', () {
      final e = _err(_v27(niveles: (n) => mapa(esc(n, 'B1.4')['puerta'])['formato'] = 'cambridge-a2-key'), _niveles);
      expect(e.single, contains('la puerta de B1.4 usa cambridge-a2-key y gravity-escalon dice cambridge-b1-preliminary'));
    });
    test('malo: la etapa de niveles.yaml cierra en otro escalón que la de gravity-escalon', () {
      final e = _err(_v27(niveles: (n) => mapa(lista(n['niveles'])[1])['escalon_de_cierre'] = 'A2.2'), _niveles);
      expect(e.single, contains('la etapa A2 cierra en A2.2 en niveles.yaml y en A2.3 en gravity-escalon'));
    });
    test('malo: las horas totales de niveles.yaml no son las de gravity-escalon', () {
      final e = _err(_v27(niveles: (n) => mapa(n['totales'])['horas_totales'] = 500), _niveles);
      expect(e.single, contains('totales.horas_totales de niveles.yaml y de gravity-escalon: 500 y 520 no coinciden'));
    });

    group('temario por semana', () {
      Doc semanas(Doc n) => mapa(n['temario_por_semana']);
      test('malo: una semana retoma un tema antes de verlo', () {
        final e = _err(_v27(niveles: (n) => lista(mapa(lista(semanas(n)['A2.1'])[0])['retoma']).add('gram.going_to')), _niveles);
        expect(e.single, contains('la semana 1 de A2.1 retoma gram.going_to antes de verlo (es nuevo en A2.1)'));
      });
      test('malo: el reparto no cubre los temas nuevos del escalón', () {
        final e = _err(_v27(niveles: (n) => lista(mapa(lista(semanas(n)['A2.2'])[0])['gramatica_nueva']).clear()), _niveles);
        expect(e, anyElement(contains('el temario por semana de A2.2 reparte')));
      });
      test('malo: un tema nuevo en dos semanas', () {
        final e = _err(_v27(niveles: (n) => lista(mapa(lista(semanas(n)['A2.1'])[1])['gramatica_nueva']).add('gram.presente_continuo')), _niveles);
        expect(e, anyElement(contains('el tema gram.presente_continuo es nuevo en dos semanas de A2.1')));
      });
      test('malo: siete semanas en un escalón de ocho', () {
        final e = _err(_v27(niveles: (n) => lista(semanas(n)['A2.3']).removeLast()), _niveles);
        expect(e.first, contains('el temario de A2.3 trae 7 semanas y el escalón dura 8'));
      });
      test('malo: la semana numerada fuera de orden', () {
        final e = _err(_v27(niveles: (n) => mapa(lista(semanas(n)['A2.1'])[2])['semana'] = 5), _niveles);
        expect(e.single, contains('el número de la semana 3 del temario de A2.1: 5 y 3 no coinciden'));
      });
    });

    group('los inventarios de los manuales quedan vistos al cerrar la etapa', () {
      Doc cob(Doc n, String m) => mapa(mapa(n['cobertura_de_manuales'])[m]);
      test('malo: un elemento del inventario de A2 Key cubierto por un tema que se ve después de A2.3', () {
        final e = _err(_v27(niveles: (n) => mapa(lista(cob(n, 'cambridge-a2-key')['items']).first)['temas'] = ['gram.condicional_segunda']), _niveles);
        expect(e.single, contains('apunta a gram.condicional_segunda, que es nuevo en'));
        expect(e.single, contains('después de cerrar la etapa en A2.3'));
      });
      test('malo: un elemento que apunta a un tema que no existe', () {
        final e = _err(_v27(niveles: (n) => mapa(lista(cob(n, 'cambridge-b1-preliminary')['items']).first)['temas'] = ['gram.nada']), _niveles);
        expect(e.single, contains('apunta a gram.nada, que no es nuevo en ningún escalón'));
      });
      test('malo: un tema de vocabulario que se ve después de cerrar la etapa', () {
        final e = _err(_v27(niveles: (n) {
          final l = lista(mapa(mapa(n['cobertura_de_manuales'])['temas_de_vocabulario'])['cambridge-a2-key']);
          mapa(l.first)['escalon'] = 'B1.1';
        }), _niveles);
        expect(e.single, contains('se ve en B1.1, después de cerrar la etapa en A2.3'));
      });
      test('malo: una etapa que cierra en un escalón que no existe', () {
        final e = _err(_v27(niveles: (n) => cob(n, 'cambridge-a2-key')['cierra_en'] = 'A9.9'), _niveles);
        expect(e.first, contains('cierra_en A9.9 no es un escalón'));
      });
    });

    test('sin gravity-escalon no se pueden contrastar horas, etapas ni puertas (aviso)', () {
      final archivos = <Archivo>[leerMapa(_niveles, nivelesReales())];
      final h = validarArchivos(archivos).hallazgos.where((x) => x.codigo == 'V27' && !x.esError).map((x) => x.mensaje);
      expect(h, anyElement(contains('falta el contrato gravity-escalon')));
    });
  });
}
