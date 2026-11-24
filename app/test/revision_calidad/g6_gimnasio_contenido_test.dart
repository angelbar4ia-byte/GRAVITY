// G6 · Revisión de cierre del gimnasio: contenido y seguridad del equipo
// (docs/revisiones/fase-8-gimnasio.md).
//
// G6-M3: la especificación (3.2, fila del banco) pide un aviso ANTES de la
// primera vez que se use el banco («revisa la capacidad y la estabilidad del
// banco») y que la persona lo confirme. El código no lo tiene: solo hay una
// línea suelta dentro de la explicación de dos ejercicios. La prueba queda
// etiquetada `hallazgo` y falla hasta que se corrija.
//
// Para excluir solo los hallazgos que fallan hasta que se corrijan:
//   flutter test --exclude-tags hallazgo
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/gimnasio/textos_gimnasio.dart';
import 'package:habitos_dominio/habitos_dominio.dart';

void main() {
  group('G6-M3 · aviso del banco antes de la primera vez (spec 3.2)', () {
    test('existe un aviso del banco con «capacidad» o «estabilidad» fuera de la '
        'explicación de un ejercicio', () {
      // Los avisos de la sesión son los códigos de CodigoAviso: ninguno es del
      // banco. Se busca además un texto fijo del módulo que lo diga.
      final fijos = [
        ...MensajesGimnasio.todos,
        TextosGimnasio.contenidoEnRevisionDetalle,
        TextosGimnasio.confirmarEnElAparato,
      ].map((t) => t.toLowerCase());
      final hay = fijos.any(
        (t) =>
            t.contains('banco') &&
            (t.contains('capacidad') || t.contains('estabilidad')),
      );
      expect(
        hay,
        isTrue,
        reason:
            'ningún mensaje fijo pide revisar la capacidad y la estabilidad '
            'del banco antes de usarlo (fondos, subidas, sentadilla y puente '
            'lo usan); hoy solo dice «Revisa que el banco esté firme» dentro '
            'de la explicación de dos ejercicios',
      );
    }, tags: 'hallazgo');

    test('control: los ejercicios que suben al banco dicen que esté firme', () {
      final c = catalogoGimnasio;
      for (final id in ['fondos_banco', 'subida_banco']) {
        final e = c.ejercicios.firstWhere((x) => x.id == id);
        expect(e.explicacion.toLowerCase(), contains('firme'), reason: id);
      }
    });
  });

  group('G6 · lo que se sabe del contenido, como control', () {
    test('todo el catálogo sigue en borrador y la sesión lo dice', () {
      final c = catalogoGimnasio;
      expect(
        c.ejercicios.every((e) => e.revision == RevisionContenido.borrador),
        isTrue,
      );
      expect(
        c.ejercicios
            .expand((e) => e.variantes)
            .every((v) => v.revision == RevisionContenido.borrador),
        isTrue,
      );
      expect(
        TextosGimnasio.contenidoEnRevisionDetalle,
        contains('Todavía no la revisa un entrenador'),
      );
    });
  });
}
