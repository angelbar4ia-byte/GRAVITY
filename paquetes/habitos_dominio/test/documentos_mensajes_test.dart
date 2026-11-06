import 'dart:convert';

import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

ElementoDoc e(String id, int t, {bool el = false, String v = 'a'}) =>
    ElementoDoc(id: id, clase: 'registro', modificadoEn: t, eliminado: el,
        datos: {'v': v});

void main() {
  final c = CifradorFalso();
  final llave = List<int>.generate(32, (i) => i + 1);

  test('sobre: ida y vuelta y atado a id y revisión', () {
    final doc = DocumentoSensible({'1': e('1', 5)}).aJson();
    final s = sellarSobre(c, llaveDelTipo: llave, persona: 'p', tipo: 't',
        id: 'i', revision: 1, documento: doc);
    expect(s, isNot(contains('registro')));
    final r = abrirSobre(c, s, llaveDelTipo: llave, persona: 'p', tipo: 't',
        id: 'i', revision: 1);
    expect(DocumentoSensible.deJson(r).elementos['1']!.modificadoEn, 5);
    for (final malo in [
      () => abrirSobre(c, s, llaveDelTipo: llave, persona: 'p', tipo: 't', id: 'j', revision: 1),
      () => abrirSobre(c, s, llaveDelTipo: llave, persona: 'p', tipo: 't', id: 'i', revision: 2),
      () => abrirSobre(c, s, llaveDelTipo: llave, persona: 'q', tipo: 't', id: 'i', revision: 1),
    ]) {
      expect(malo, throwsFormatException);
    }
  });

  test('id opaco y estable', () {
    final a = idDeSobre(c, llave, 't', 'dia:2026-11-01');
    expect(a, idDeSobre(c, llave, 't', 'dia:2026-11-01'));
    expect(a, isNot(idDeSobre(c, llave, 't', 'dia:2026-11-02')));
    expect(a, matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(a, isNot(contains('2026')));
  });

  test('fusión: más reciente, tumba, conmutativa, idempotente', () {
    final a = DocumentoSensible({'1': e('1', 5, v: 'x'), '2': e('2', 1)});
    final b = DocumentoSensible({'1': e('1', 9, v: 'y'), '3': e('3', 2),
        '2': e('2', 3, el: true)});
    final ab = fusionarDocumentos(a, b);
    final ba = fusionarDocumentos(b, a);
    expect(ab.elementos['1']!.datos['v'], 'y');
    expect(ab.elementos['2']!.eliminado, isTrue);
    expect(ab.elementos.length, 3);
    expect(jsonEncode(ab.aJson()['elementos'] as Map), jsonEncode((ba.aJson()['elementos'] as Map)).isEmpty ? '' : jsonEncode(Map.fromEntries((ab.aJson()['elementos'] as Map).keys.map((k) => MapEntry(k, (ba.aJson()['elementos'] as Map)[k])))));
    expect(jsonEncode(fusionarDocumentos(ab, ab).aJson()), jsonEncode(ab.aJson()));
    final t1 = fusionarDocumentos(
        DocumentoSensible({'1': e('1', 5)}), DocumentoSensible({'1': e('1', 5, el: true)}));
    expect(t1.elementos['1']!.eliminado, isTrue);
  });

  test('mensajes sin culpa', () {
    for (final m in MensajesHabitos.todos) {
      for (final p in MensajesHabitos.prohibidas) {
        expect(m.toLowerCase(), isNot(contains(p)), reason: m);
      }
    }
    expect(MensajesHabitos.retomar, 'Retomemos hoy');
    for (final t in [
      TextosSos.pausa, TextosSos.cierreConsumo, TextosSos.cierreSuperado,
      TextosSos.sigue, TextosSos.registro, TextosSos.tecnica,
    ]) {
      for (final p in MensajesHabitos.prohibidas) {
        expect(t.toLowerCase(), isNot(contains(p)), reason: t);
      }
    }
  });

  test('avisos discretos (regla 114)', () {
    final textos = [...TextoAvisoHabitos.porTipo.values, TextoAvisoHabitos.generico];
    for (final t in textos) {
      expect(t.length, lessThanOrEqualTo(40), reason: t);
      expect(t, isNot(matches(RegExp(r'\d'))), reason: t);
      expect(t, isNot(contains(r'$')));
      for (final n in ['cigarr', 'fum', 'azúcar', 'azucar', 'refresco', 'antojo', 'orac']) {
        expect(t.toLowerCase(), isNot(contains(n)), reason: t);
      }
    }
    expect(TextoAvisoHabitos.paraTipo('hab_reservado'), 'Recordatorio');
    expect(TextoAvisoHabitos.paraTipo('otro'), TextoAvisoHabitos.generico);
    expect(TextoAvisoHabitos.conNombre('x' * 60).length, 40);
    final t = TextoAvisoHabitos.conNombre('${'a' * 39}😀 resto');
    final u = t.codeUnits.last;
    expect(u >= 0xD800 && u <= 0xDBFF, isFalse); // sin sustituto suelto (F3-8)
  });
}
