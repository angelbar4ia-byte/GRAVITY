import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

String huella(SesionPlanificada s) => [
  s.duracionEstimadaSeg,
  for (final e in s.ejercicios)
    '${e.varianteId}/${e.series}/${e.rangoMin}-${e.rangoMax}',
  s.omitidos.map((o) => o.slotId).join(','),
  s.avisos.join(','),
].join('|');

void main() {
  group('CA-G-09 el equipo futuro es solo dato', () {
    test('mancuernas en `futuro` generan exactamente las mismas sesiones', () {
      for (final base in [
        inventarioBase(),
        conBandas(ancla: true),
        sinEstacion(conBandas()),
      ]) {
        final futuro = base.conItem('mancuernas', EstadoItem.futuro);
        for (final p in ['A', 'B', 'C']) {
          for (final v in VersionSesion.values) {
            expect(
              huella(generar(p, version: v, inventario: futuro)),
              huella(generar(p, version: v, inventario: base)),
              reason: '$p ${v.name}',
            );
          }
        }
      }
    });

    test('la pantalla lo lista aparte («cuando lo tengas»)', () {
      final inv = inventarioBase().conItem('mancuernas', EstadoItem.futuro);
      expect(inv.equipoFuturo, ['mancuernas']);
      expect(inventarioBase().equipoFuturo, isEmpty);
    });

    test('el catálogo marca las mancuernas como solo dato', () {
      expect(cat.item('mancuernas')!.soloDato, isTrue);
    });

    test('CASO MALO: ninguna variante se ofrece por un aparato `futuro`', () {
      final c = miniCatalogo(requiereSegunda: const ['mancuernas']);
      final inv = inventarioBase().conItem('mancuernas', EstadoItem.futuro);
      expect(inv.varianteDisponible(c.variante('x1_b')!, c), isFalse);
      // Aun si la persona la marca como disponible por error de captura, el
      // validador del catálogo ya impide que alguna variante lo exija.
      expect(
        validarCatalogo(c).map((e) => e.codigo),
        contains('requiere_equipo_futuro'),
      );
    });

    test('lo `no_disponible` tampoco cuenta', () {
      final inv = inventarioBase().conItem(
        'banco_inclinado',
        EstadoItem.noDisponible,
      );
      expect(
        inv.varianteDisponible(cat.variante('fondos_banco_piernas')!, cat),
        isFalse,
      );
    });
  });
}
