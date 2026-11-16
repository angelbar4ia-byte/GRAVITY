import 'dart:convert';
import 'dart:io';

import 'package:ingles/ingles.dart';
import 'package:test/test.dart';

import 'apoyo/ayudas.dart';
import 'apoyo/ayudas_b.dart';
import 'apoyo/casos_b.dart';

/// El conjunto de prueba: el contrato, las ocho unidades de la forma completa,
/// una sesión que usa uno de los audios, y dos formas, una completa y otra
/// reducida (solo trae `r-1` y un audio de `l-1`).
List<Doc> conjunto() => [
      ...unidadesCompletas(),
      formaCompleta(id: 'f-completa'),
      formaDe('f-reducida', {'r-1': ['u-r1-a', 'u-r1-b'], 'l-1': ['u-l1-a']}),
      sesionDe('t-s02-lun', audios: ['u-l1-a']),
    ];

Informe informe(List<Doc> docs, {Doc? contrato, bool niveles = true}) =>
    Informe.de(archivosB(docs, contrato: contrato, niveles: niveles));

FilaDeParte fila(Informe i, String parte) => i.contratos.single.filas.firstWhere((f) => f.parte.id == parte);

void main() {
  group('informe · cobertura por contrato y parte', () {
    final i = informe(conjunto());

    test('cuenta unidades y preguntas que hay frente a las que pide el contrato', () {
      final r1 = fila(i, 'r-1');
      expect([r1.unidades, r1.preguntas, r1.pideUnidades, r1.pidePreguntas], [2, 2, '2', '2']);
      final r2 = fila(i, 'r-2');
      expect([r2.unidades, r2.preguntas], [1, 2]);
      final tr = fila(i, 'r-tr');
      expect([tr.unidades, tr.preguntas, tr.pideUnidades], [3, 3, '3']);
      final oo = fila(i, 'r-oo');
      expect([oo.unidades, oo.preguntas], [1, 2]);
    });
    test('las palabras: mínimo, mediana y máximo frente al rango del contrato', () {
      final r1 = fila(i, 'r-1');
      expect(r1.palabras, [25, 30]);
      expect([r1.minimo, r1.mediana, r1.maximo], [25, 27.5, 30]);
      expect(r1.rango, '20 a 40 (medido)');
      final tr = fila(i, 'r-tr');
      expect(tr.palabras, [8, 8, 8]);
    });
    test('la mediana de una cantidad impar es la del medio', () {
      final f = FilaDeParte(parte: fila(i, 'r-1').parte, unidades: 3, preguntas: 3, palabras: [10, 20, 90]);
      expect(f.mediana, 20);
      expect(FilaDeParte(parte: fila(i, 'r-1').parte, unidades: 0, preguntas: 0, palabras: []).mediana, isNull);
    });
    test('el texto trae una línea por parte con las cifras alineadas', () {
      final t = i.aTexto();
      expect(t, contains('prueba-fidelidad · Examen de prueba para la fidelidad'));
      final lineas = t.split('\n');
      final r1 = lineas.firstWhere((l) => l.trimLeft().startsWith('r-1 '));
      expect(r1, contains('2 / 2'));
      expect(r1, contains('25 / 27.5 / 30'));
      expect(r1, contains('20 a 40 (medido)'));
      final l1 = lineas.firstWhere((l) => l.trimLeft().startsWith('l-1 '));
      expect(l1, contains('2 / 2'));
    });
    test('una parte sin unidades dice 0 y no tiene palabras', () {
      final vacio = informe([]);
      final r1 = fila(vacio, 'r-1');
      expect([r1.unidades, r1.preguntas, r1.palabras], [0, 0, isEmpty]);
      expect(vacio.aTexto(), contains('0 / 2'));
      expect(vacio.aTexto().split('\n').firstWhere((l) => l.trimLeft().startsWith('r-1 ')), contains(' -  '));
    });
    test('una parte pendiente o sin rango lo dice', () {
      final c = contratoCon('r-1', (p) => p['pendiente'] = true);
      expect(fila(informe([], contrato: c), 'r-1').rango, '20 a 40 (medido, pendiente)');
      final sin = contratoCon('r-1', (p) => p.remove('palabras_estimulo'));
      expect(fila(informe([], contrato: sin), 'r-1').rango, 'sin rango');
    });
    test('lo que el contrato no da se muestra con un signo de pregunta', () {
      final c = contratoCon('r-2', (p) {
        p.remove('unidades');
        p.remove('preguntas_total');
        p.remove('preguntas_por_unidad');
      });
      final r2 = fila(informe([], contrato: c), 'r-2');
      expect([r2.pideUnidades, r2.pidePreguntas], ['?', '?']);
    });
    test('las unidades retiradas no cuentan', () {
      final docs = [for (final d in unidadesCompletas()) d['id'] == 'u-r1-a' ? (clonar(d)..['estado'] = 'retirado') : d];
      expect(fila(informe(docs), 'r-1').unidades, 1);
    });
    test('las unidades de un formato sin contrato se cuentan aparte', () {
      final sin = lectura('u-x', formato: 'gravity-sesion-60', parte: 'traslado-audio', preguntas: 2);
      final t = informe([sin]).aTexto();
      expect(t, contains('Unidades de formatos sin contrato:'));
      expect(t, contains('gravity-sesion-60: 1 unidad, 2 preguntas'));
    });
    test('sin contratos lo dice', () {
      final t = Informe.de(archivosB([]).skip(1).toList()).aTexto();
      expect(t, contains('sin contratos'));
    });
  });

  group('informe · fidelidad de las formas', () {
    final i = informe(conjunto());
    test('una forma completa y otra reducida, cada una con sus motivos', () {
      expect(i.formas.map((f) => f.fidelidad.etiqueta), ['completa', 'reducida']);
      final t = i.aTexto();
      expect(t, contains('f-completa (simulacro, prueba-fidelidad, borrador): completa'));
      expect(t, contains('f-reducida (simulacro, prueba-fidelidad, borrador): reducida'));
      expect(t, contains('- faltan 4 partes del contrato: "r-2", "r-tr", "r-oo", "l-2"'));
      expect(t, contains('- la parte "l-1" tiene 1 unidad y el contrato pide 2'));
    });
    test('la forma completa no lleva motivos', () {
      final lineas = i.aTexto().split('\n');
      final k = lineas.indexWhere((l) => l.contains('f-completa'));
      expect(lineas[k + 1].trim(), isNot(startsWith('-')));
    });
    test('sin formas lo dice', () {
      final t = informe(unidadesCompletas()).aTexto();
      expect(t, contains('2. Fidelidad de las formas\n   sin formas'));
    });
    test('una forma retirada no se informa', () {
      final docs = conjunto();
      final retirada = [for (final d in docs) d['id'] == 'f-reducida' ? (clonar(d)..['estado'] = 'retirado') : d];
      expect(informe(retirada).formas.map((f) => f.forma.id), ['f-completa']);
    });
  });

  group('informe · cobertura por escalón', () {
    test('sin niveles.yaml dice "sin niveles"', () {
      final i = informe(conjunto(), niveles: false);
      expect(i.escalones, isNull);
      expect(i.aTexto(), contains('3. Cobertura por escalón\n   sin niveles'));
    });
    test('con niveles: sesiones y audios del escalón y preguntas por habilidad', () {
      final i = informe(conjunto());
      final e = i.escalones!;
      expect(e.map((x) => x.escalon), ['B1.1', 'B1.2']);
      final b11 = e.first;
      expect([b11.sesiones, b11.audios], [1, 1]);
      // Habilidades en el orden de niveles.yaml: escucha (el audio), escritura (la tarea), gramática (la pregunta).
      expect(b11.filas.map((f) => (f.habilidad, f.unidades, f.preguntas)), [('escucha', 1, 1), ('escritura', 1, 1), ('gramatica', 1, 1)]);
      expect(e.last.sesiones, 0);
      final t = i.aTexto();
      expect(t, contains('B1.1: 1 sesión, 1 audio de traslado'));
      expect(t, contains('B1.2: 0 sesiones, 0 audios de traslado'));
      expect(t, contains('sin preguntas'));
    });
    test('una sesión con un escalón que niveles.yaml no lista se cuenta aparte', () {
      final s = sesionDe('t-s03-lun', audios: ['u-l1-a'])..['escalon'] = 'B2.9';
      final i = informe([...conjunto(), s]);
      expect(i.sesionesSinEscalon, 1);
      expect(i.aTexto(), contains('1 sesión con un escalón que niveles.yaml no lista'));
    });
  });

  group('la orden informe', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('ingles_informe_'));
    tearDown(() => dir.deleteSync(recursive: true));

    void escribe(String ruta, Object contenido) {
      final f = File('${dir.path}/$ruta')..createSync(recursive: true);
      f.writeAsStringSync(contenido is String ? contenido : jsonEncode(contenido));
    }

    Future<ProcessResult> corre(List<String> args) =>
        Process.run(Platform.resolvedExecutable, ['run', 'bin/ingles.dart', 'informe', ...args]);

    test('imprime las tres secciones y sale con 0', () async {
      escribe('formatos/c.yaml', contratoFidelidad());
      escribe('unidades/u1.yaml', lectura('u-r1-a', parte: 'r-1', palabras: 30));
      final p = await corre([dir.path]);
      expect(p.exitCode, 0);
      final t = p.stdout as String;
      expect(t, contains('1. Cobertura por contrato y parte'));
      expect(t, contains('prueba-fidelidad · Examen de prueba para la fidelidad'));
      expect(t, contains('2. Fidelidad de las formas\n   sin formas'));
      expect(t, contains('3. Cobertura por escalón\n   sin niveles'));
    });
    test('sale con 0 aunque haya errores de validación: no es una validación', () async {
      escribe('formatos/c.yaml', contratoFidelidad());
      escribe('unidades/mala.yaml', lectura('u-r1-a', parte: 'r-1')..['nivel'] = 'C1');
      escribe('unidades/rota.yaml', 'esquema: [');
      final p = await corre([dir.path]);
      expect(p.exitCode, 0);
      expect(p.stdout as String, contains('1 ilegibles (corre validar)'));
    });
    test('una ruta que no existe sale con 66', () async {
      final p = await corre(['${dir.path}/no-existe']);
      expect(p.exitCode, 66);
    });
    test('de más argumentos sale con 64', () async {
      final p = await corre(['uno', 'dos']);
      expect(p.exitCode, 64);
    });
    test('la ayuda nombra la orden nueva y validar no cambió sus códigos de salida', () async {
      final ayuda = await Process.run(Platform.resolvedExecutable, ['run', 'bin/ingles.dart', '--help']);
      expect(ayuda.exitCode, 0);
      expect(ayuda.stdout as String, contains('informe [ruta]'));
      escribe('unidades/mala.yaml', lectura('u-r1-a', parte: 'r-1')..['nivel'] = 'C1');
      final v = await Process.run(Platform.resolvedExecutable, ['run', 'bin/ingles.dart', 'validar', dir.path]);
      expect(v.exitCode, 1);
      final ok = await Process.run(Platform.resolvedExecutable, ['run', 'bin/ingles.dart', 'validar', '${dir.path}/no-existe']);
      expect(ok.exitCode, 66);
    });
  });
}
