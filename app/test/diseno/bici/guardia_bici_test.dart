// Guardias de «Bicicleta» (B4): sin colores fijos, sin dependencias de
// dominio, de red, de ubicación, de mapas ni de sonido, sin Timer.periodic,
// tono sin culpa, sin contenido médico ni cifras de comida o líquidos, textos
// de seguridad con sus frases fijas y contraste de las superficies propias de
// los componentes en cada estilo (con la personalidad Sport de la bici).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';
import 'package:gravity/nucleo/contratos/roles.dart';

import 'ayuda_bici.dart';

List<File> _fuentes() =>
    Directory('lib/diseno/bici')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

String _sinComentarios(File f) =>
    f.readAsLinesSync().where((l) => !l.trimLeft().startsWith('//')).join('\n');

Map<String, String> _constantes(String archivo) {
  final fuente = File(archivo).readAsStringSync();
  final constantes = RegExp(
    r"static const (\w+) =\s*((?:'[^']*'\s*)+);",
    multiLine: true,
  ).allMatches(fuente);
  return {
    for (final m in constantes)
      m.group(1)!: RegExp(
        r"'([^']*)'",
      ).allMatches(m.group(2)!).map((x) => x.group(1)!).join(),
  };
}

void main() {
  test('hay componentes que revisar y están exportados', () {
    expect(_fuentes().length, greaterThanOrEqualTo(14));
    final barril = File('lib/diseno/diseno.dart').readAsStringSync();
    expect(barril, contains("export 'bici/bici.dart';"));
  });

  test('ningún componente usa Color(0x…) ni Colors.*: todo sale del tema', () {
    final patron = RegExp(r'Color\(0x|Colors\.(?!transparent)[a-zA-Z]');
    final fallas = <String>[];
    for (final f in _fuentes()) {
      final lineas = f.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        final l = lineas[i].trimLeft();
        if (l.startsWith('//')) continue;
        if (patron.hasMatch(l)) fallas.add('${f.path}:${i + 1}: $l');
      }
    }
    expect(fallas, isEmpty, reason: fallas.join('\n'));
  });

  test('los componentes no importan el dominio, los módulos, la red, la '
      'ubicación, los mapas ni el sonido', () {
    final prohibido = RegExp(
      r"^import '(package:(habitos_dominio|finanzas_dominio|http|dio|"
      r"supabase_flutter|audioplayers|just_audio|flutter_tts|share_plus|"
      r"url_launcher|connectivity_plus|geolocator|flutter_foreground_task|"
      r"wakelock_plus|flutter_map|latlong2|maplibre_gl|gpx|health|"
      r"spotify_sdk|flutter_blue_plus|file_picker)/|dart:io|"
      r"[./]*/?(modulos|nucleo/(sesion|cola|herramientas|sensibles|avisos|"
      r"seguridad)))",
      multiLine: true,
    );
    for (final f in _fuentes()) {
      expect(prohibido.hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
    }
  });

  test('sin Timer.periodic, sin sonidos y sin llamadas a la red', () {
    for (final f in _fuentes()) {
      final codigo = _sinComentarios(f);
      expect(codigo.contains('Timer.periodic'), isFalse, reason: f.path);
      expect(codigo.contains('SystemSound'), isFalse, reason: f.path);
      expect(codigo.contains('HttpClient'), isFalse, reason: f.path);
      expect(codigo.contains('launchUrl'), isFalse, reason: f.path);
    }
  });

  test('el cronómetro programa solo avisos de un disparo y los cancela', () {
    final codigo = _sinComentarios(File('lib/diseno/bici/cronometro.dart'));
    expect(codigo.contains('Timer('), isTrue);
    expect(codigo.contains('_aviso?.cancel()'), isTrue);
    expect(codigo.contains('removeObserver'), isTrue);
  });

  test('ningún texto escrito en los componentes lleva signos de exclamación, '
      'palabras que culpan, contenido médico ni cifras de comida', () {
    final cadenas = RegExp(r"'([^'\n]*)'");
    for (final f in _fuentes()) {
      for (final linea in _sinComentarios(f).split('\n')) {
        for (final m in cadenas.allMatches(linea)) {
          final texto = m.group(1)!;
          expect(
            texto.contains('!') && !texto.contains('!='),
            isFalse,
            reason: '${f.path}: $texto',
          );
          for (final p in palabrasProhibidas) {
            expect(
              texto.toLowerCase().contains(p),
              isFalse,
              reason: '${f.path}: $texto',
            );
          }
          expect(
            patronMedico.hasMatch(texto),
            isFalse,
            reason: '${f.path}: $texto',
          );
          // Nada se llama «vencida»: sin registro no es una falta (4.8).
          expect(
            RegExp('vencid', caseSensitive: false).hasMatch(texto),
            isFalse,
            reason: '${f.path}: $texto',
          );
          // Sin racha semanal (4.11).
          expect(
            RegExp('racha', caseSensitive: false).hasMatch(texto),
            isFalse,
            reason: '${f.path}: $texto',
          );
        }
      }
    }
  });

  group('textos de seguridad (CA-B-01)', () {
    final textos = _constantes('lib/diseno/bici/textos_bici.dart');

    test('hay textos fijos que revisar', () {
      expect(textos.length, greaterThanOrEqualTo(60));
    });

    test('los textos fijos no tienen contenido médico', () {
      for (final MapEntry(key: nombre, value: texto) in textos.entries) {
        expect(
          patronMedico.hasMatch(texto),
          isFalse,
          reason: '$nombre: $texto',
        );
      }
    });

    test('«si te sientes mal» no nombra síntomas y manda a emergencias o a un '
        'médico', () {
      final t = textos['siTeSientesMal']!;
      expect(patronSintomas.hasMatch(t), isFalse);
      expect(RegExp('emergencias').hasMatch(t), isTrue);
      expect(RegExp('médico').hasMatch(t), isTrue);
      expect(t, TextosBici.siTeSientesMal);
    });

    test('la guía fija dice que no sustituye la prudencia ni a un '
        'profesional', () {
      expect(TextosBici.guiaNoSustituye, contains('no sustituye'));
      expect(TextosBici.guiaNoSustituye, contains('profesional'));
      expect(TextosBici.guiaNoSustituyeCorta, contains('no sustituye'));
      expect(TextosBici.contenidoEnRevisionDetalle, contains('no sustituye'));
    });

    test('se dice con palabras que nadie vigila la salida', () {
      expect(TextosBici.nadieVigila, contains('no vigila'));
      expect(TextosBici.nadieVigila, contains('nadie recibe un aviso'));
    });

    test('los esfuerzos van de 1 a 5 y de «muy ligero» a «al límite»', () {
      expect(TextosBici.esfuerzos, hasLength(5));
      expect(TextosBici.esfuerzos.first, 'Muy ligero');
      expect(TextosBici.esfuerzos.last, 'Al límite');
    });

    test('los estados de mantenimiento nunca dicen «vencida»', () {
      for (final e in EstadoTarea.values) {
        expect(e.texto.toLowerCase(), isNot(contains('venc')));
      }
      expect(EstadoTarea.sinRegistro.texto, 'Sin registro');
    });
  });

  test('B10 y B11 están marcadas «V2, no aprobado» y no tienen nada tocable', () {
    final fuente = _sinComentarios(File('lib/diseno/bici/maquetas.dart'));
    for (final clase in ['_B10EnVivo', '_B11Resumen']) {
      final inicio = fuente.indexOf('class $clase');
      expect(inicio, greaterThan(0), reason: clase);
      final fin = fuente.indexOf('\nclass ', inicio + 1);
      final cuerpo = fuente.substring(inicio, fin < 0 ? null : fin);
      expect(cuerpo.contains('IgnorePointer'), isTrue, reason: clase);
      expect(cuerpo.contains('ExcludeSemantics'), isTrue, reason: clase);
      for (final prohibido in [
        'FilledButton',
        'OutlinedButton',
        'TextButton',
        'InkWell',
        'onPressed',
        'onTap',
      ]) {
        expect(cuerpo.contains(prohibido), isFalse, reason: '$clase $prohibido');
      }
    }
    expect(TextosBici.v2NoAprobado, 'V2, no aprobado');
  });

  group('contraste de las superficies de los componentes', () {
    test('la bici usa siempre la personalidad Sport (alto contraste)', () {
      final p = PersonalidadModulo.automatica(Modulo.habitos, Submodulo.bici);
      expect(p, PersonalidadModulo.sport);
      expect(p.altoContraste, isTrue);
    });

    for (final estilo in todosLosEstilos) {
      for (final brillo in Brightness.values) {
        for (final p in [
          PersonalidadModulo.igualAlEstilo,
          PersonalidadModulo.sport,
        ]) {
          test('${estilo.id} ${brillo.name} · ${p.id}', () {
            final v = valoresPara(
              estilo: estilo,
              brillo: p.brilloEfectivo(brillo),
              personalidad: p,
            );
            // Superficies teñidas que usan los componentes (marcas con
            // relleno, avisos, opción elegida, tarea que toca).
            final tintes = <String, Color>{
              'panel': v.panel,
              'chipSeleccionado': v.chipSeleccionado,
              for (final (nombre, color) in [
                ('alerta', v.alerta),
                ('exito', v.exito),
                ('acento', v.acento),
              ])
                for (final a in [0.06, 0.08, 0.10, 0.12, 0.14])
                  '$nombre $a': Color.alphaBlend(
                    color.withValues(alpha: a),
                    v.panel,
                  ),
            };
            for (final MapEntry(key: nombre, value: fondo) in tintes.entries) {
              expect(
                razonContraste(v.textoFuerte, fondo),
                greaterThanOrEqualTo(contrasteMinimoTexto),
                reason: 'textoFuerte sobre $nombre',
              );
              expect(
                razonContraste(v.texto, fondo),
                greaterThanOrEqualTo(contrasteMinimoTexto),
                reason: 'texto sobre $nombre',
              );
            }
            for (final fondo in [v.fondo, v.panel, v.chipSeleccionado]) {
              expect(
                razonContraste(v.textoTenue, fondo),
                greaterThanOrEqualTo(contrasteMinimoTexto),
                reason: 'textoTenue',
              );
            }
            // Iconos, bordes y barras: 3:1 contra el panel y el avance
            // contra su pista.
            for (final (nombre, color) in [
              ('acento', v.acento),
              ('exito', v.exito),
              ('alerta', v.alerta),
              ('textoTenue', v.textoTenue),
            ]) {
              expect(
                razonContraste(color, v.panel),
                greaterThanOrEqualTo(contrasteMinimoGrande),
                reason: '$nombre sobre el panel',
              );
            }
            expect(
              razonContraste(v.acento, v.pista),
              greaterThanOrEqualTo(contrasteMinimoGrande),
              reason: 'avance de las barras contra su pista',
            );
            if (p == PersonalidadModulo.sport) {
              expect(v.altoContraste, isTrue);
              expect(
                razonContraste(v.sobreAcento, v.acento),
                greaterThanOrEqualTo(contrasteMinimoAlto),
                reason: 'texto de Salí y Terminar sobre el acento (Sport)',
              );
              expect(
                razonContraste(v.textoFuerte, v.panel),
                greaterThanOrEqualTo(contrasteMinimoAlto),
                reason: 'los números grandes se leen al sol (Sport)',
              );
            } else {
              expect(
                razonContraste(v.sobreAcento, v.acento),
                greaterThanOrEqualTo(contrasteMinimoTexto),
                reason: 'texto de los botones sobre el acento',
              );
            }
          });
        }
      }
    }
  });
}
