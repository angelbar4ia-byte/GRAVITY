import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

SesionRegenerativa gen(String id, {Inventario? inventario}) =>
    generarRegenerativa(
      catalogo: cat,
      plantillaId: id,
      inventario: inventario ?? inventarioBase(),
    );

void main() {
  group('CA-G-25 regenerativa', () {
    test('R1 de ~28 min y R2 de ~37 min, dentro de 20 a 40', () {
      expect(gen('R1').minutos, 28);
      expect(gen('R2').minutos, 37);
      for (final r in cat.regenerativas) {
        expect(r.minutos >= 20 && r.minutos <= 40, isTrue, reason: r.id);
      }
    });

    test('contenido: R1 camina 15, cadera 5, hombros 5, respiración 3', () {
      expect(
        [for (final b in gen('R1').bloques) (b.bloqueId, b.minutos)],
        [
          ('caminata_suave', 15),
          ('movilidad_cadera', 5),
          ('movilidad_hombros', 5),
          ('respiracion', 3),
        ],
      );
      expect([for (final b in gen('R2').bloques) b.minutos], [20, 5, 7, 5]);
    });

    test('sin series, cargas ni récords: el tipo no tiene esos campos y no produce récords', () {
      final r = gen('R1');
      expect(r.bloques.every((b) => b.minutos > 0), isTrue);
      final registrada = SesionRegistrada(
        fecha: dia(2026, 12, 2),
        plantilla: 'R1',
        version: VersionSesion.estandar,
      );
      expect(registrada.series, isEmpty);
      expect(registrada.esDeFuerza, isFalse);
      expect(calcularRecords([registrada], cat), isEmpty);
    });

    test('«Cansado» propone R1; con otro ánimo, la del día', () {
      expect(proponerRegenerativa(EstadoAnimo.cansado), 'R1');
      expect(
        proponerRegenerativa(EstadoAnimo.cansado, plantillaDelDia: 'R2'),
        'R1',
      );
      expect(
        proponerRegenerativa(EstadoAnimo.normal, plantillaDelDia: 'R2'),
        'R2',
      );
      expect(proponerRegenerativa(EstadoAnimo.descansado), 'R1');
    });

    test('sin caminadora la caminata se cambia por marcha suave de la misma duración', () {
      final sin = gen(
        'R1',
        inventario: inventarioBase().conItem(
          'caminadora',
          EstadoItem.noDisponible,
        ),
      );
      expect(sin.bloques.first.bloqueId, 'marcha_suave');
      expect(sin.bloques.first.minutos, 15);
      expect(sin.minutos, 28);
      expect(gen('R1').bloques.first.bloqueId, 'caminata_suave');
    });

    test('nace en borrador: «Contenido en revisión»', () {
      expect(gen('R1').contenidoEnRevision, isTrue);
    });

    test('CASO MALO: una regenerativa fuera de 20 a 40 minutos falla la validación', () {
      final c = Catalogo(
        version: 1,
        items: cat.items,
        datosAparato: const [],
        ejercicios: const [],
        plantillas: const [],
        regenerativas: const [
          PlantillaRegenerativa(
            id: 'R1',
            nombre: 'corta',
            bloques: [BloqueRegenerativo('respiracion', 5)],
            revision: RevisionContenido.borrador,
          ),
        ],
        bloques: cat.bloques,
      );
      expect(
        validarCatalogo(c).map((e) => e.codigo),
        contains('regenerativa_fuera_de_20_40'),
      );
    });

    test('plantilla inexistente o de fuerza lanza un error claro', () {
      expect(() => gen('A'), throwsArgumentError);
    });
  });
}
