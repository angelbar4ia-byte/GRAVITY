import 'dart:convert';
import 'dart:io';

import 'package:ingles/ingles.dart';
import 'package:test/test.dart';

import 'apoyo/ayudas.dart';
import 'apoyo/casos.dart';

void main() {
  group('V24 · estados (la parte que no depende de revisiones)', () {
    test('bueno: un archivo validado sin errores', () {
      final d = opcionMultiple()..['estado'] = 'validado';
      expect(propios(correr([d])), isEmpty);
    });
    test('malo: validado con un error', () {
      final d = opcionMultiple()..['estado'] = 'validado';
      mapa(lista(mapa(lista(d['preguntas']).first)['opciones']).first).remove('porque');
      final h = errores(correr([d]), 'V24');
      expect(h.single.mensaje, contains('un archivo validado no puede tener errores'));
      expect(h.single.mensaje, contains('tiene 1 error:'));
    });
    test('malo: validado con avisos solamente no es error', () {
      final d = ochoPreguntas(masLargas: 6)..['estado'] = 'validado';
      final h = correr([d]);
      expect(avisos(h, 'V05'), hasLength(1));
      expect(errores(h, 'V24'), isEmpty);
    });
    test('malo: validado sin contrato es error y por tanto V24', () {
      final d = opcionMultiple()
        ..['estado'] = 'validado'
        ..['formato'] = 'no-existe';
      final h = correr([d]);
      expect(errores(h, 'V02'), hasLength(1));
      expect(errores(h, 'V24'), hasLength(1));
    });
    test('malo: revisado (todavía no existe comparar)', () {
      final d = opcionMultiple()..['estado'] = 'revisado';
      expect(errores(correr([d]), 'V24').single.mensaje, contains('no hay revisión a ciegas vigente'));
    });
    test('malo: aprobado', () {
      final d = opcionMultiple()..['estado'] = 'aprobado';
      expect(errores(correr([d]), 'V24').single.mensaje, contains('"aprobado"'));
    });
    test('bueno: borrador con errores no tiene V24', () {
      final d = opcionMultiple();
      mapa(lista(mapa(lista(d['preguntas']).first)['opciones']).first).remove('porque');
      final h = correr([d]);
      expect(errores(h, 'V04'), isNotEmpty);
      expect(de(h, 'V24'), isEmpty);
    });
    test('un archivo retirado solo pasa V01 y V02', () {
      final d = opcionMultiple()..['estado'] = 'retirado';
      mapa(lista(mapa(lista(d['preguntas']).first)['opciones']).first).remove('porque');
      final h = correr([d]);
      expect(propios(h), isEmpty);
      mapa(lista(d['preguntas']).first)['id'] = 'otro-a';
      expect(errores(correr([d]), 'V02'), hasLength(1));
    });
  });

  group('validar una carpeta', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('ingles_validar_'));
    tearDown(() => dir.deleteSync(recursive: true));

    void escribe(String ruta, Object contenido) {
      final f = File('${dir.path}/$ruta')..createSync(recursive: true);
      f.writeAsStringSync(contenido is String ? contenido : jsonEncode(contenido));
    }

    test('lee solo los .yaml, salta revisiones/ y carpetas ocultas', () {
      escribe('unidades/uno.yaml', opcionMultiple());
      escribe('LEEME.md', '# no es yaml');
      escribe('revisiones/x/r.yaml', 'cualquier cosa: sin esquema');
      escribe('.oculta/y.yaml', 'otra: cosa');
      final r = validarRuta(dir.path);
      expect(r.archivos.map((a) => a.ruta), ['unidades/uno.yaml']);
    });
    test('los avisos no impiden salir en limpio; un error, sí', () {
      escribe('uno.yaml', opcionMultiple());
      var r = validarRuta(dir.path);
      expect(r.limpio, isTrue);
      expect(r.avisos, greaterThan(0));
      escribe('dos.yaml', huecoAbierto()..['nivel'] = 'C1');
      r = validarRuta(dir.path);
      expect(r.limpio, isFalse);
      expect(r.errores, 1);
    });
    test('una ruta que no existe lanza FileSystemException', () {
      expect(() => validarRuta('${dir.path}/no-existe'), throwsA(isA<FileSystemException>()));
    });

    test('la orden validar imprime una línea por hallazgo y sale con 1 si hay errores', () async {
      escribe('uno.yaml', opcionMultiple());
      escribe('dos.yaml', huecoAbierto()..['nivel'] = 'C1');
      final p = await Process.run(Platform.resolvedExecutable, ['run', 'bin/ingles.dart', 'validar', dir.path]);
      expect(p.exitCode, 1);
      final lineas = (p.stdout as String).trim().split('\n');
      expect(lineas, contains(startsWith('dos.yaml [t-ha-0001] V01 error: nivel:')));
      expect(lineas.any((l) => l.startsWith('uno.yaml [t-om-0001] V02 aviso: sin contrato')), isTrue);
      expect(lineas.last, 'Resumen: 2 archivos leídos, 1 errores, ${lineas.length - 2} avisos.');
    });
    test('la orden validar sale con 0 si solo hay avisos', () async {
      escribe('uno.yaml', opcionMultiple());
      final p = await Process.run(Platform.resolvedExecutable, ['run', 'bin/ingles.dart', 'validar', dir.path]);
      expect(p.exitCode, 0);
      expect(p.stdout as String, contains('0 errores'));
    });
    test('una orden desconocida sale con 64', () async {
      final p = await Process.run(Platform.resolvedExecutable, ['run', 'bin/ingles.dart', 'exportar']);
      expect(p.exitCode, 64);
    });
  });
}
