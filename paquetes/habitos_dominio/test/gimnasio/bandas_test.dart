import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

bool ofrece(Inventario inv, String variante) =>
    inv.varianteDisponible(cat.variante(variante)!, cat);

void main() {
  group('CA-G-07 bandas y anclajes', () {
    test('ancla puerta: solo con `ancla_puerta` disponible', () {
      expect(ofrece(conBandas(), 'press_pecho_banda_puerta'), isFalse);
      expect(
        ofrece(conBandas(ancla: true), 'press_pecho_banda_puerta'),
        isTrue,
      );
      expect(
        ofrece(
          conBandas().conItem('ancla_puerta', EstadoItem.noDisponible),
          'jalon_banda_puerta',
        ),
        isFalse,
      );
    });

    test('ancla estación: solo si se confirmó el punto de anclaje', () {
      expect(
        ofrece(conBandas(ancla: true), 'press_pecho_banda_estacion'),
        isFalse,
      );
      final conf = conBandas().confirmando(CamposAparato.anclajeEstacion, 1);
      expect(ofrece(conf, 'press_pecho_banda_estacion'), isTrue);
      expect(ofrece(conf, 'face_pull_banda_estacion'), isTrue);
    });

    test('pisar: siempre que haya bandas', () {
      expect(ofrece(conBandas(), 'elevacion_lateral_banda'), isTrue);
      expect(ofrece(conBandas(), 'remo_banda_pisada'), isTrue);
      expect(ofrece(conBandas(), 'curl_banda'), isTrue);
    });

    test('sin ninguna banda activa no se ofrece ninguna variante de banda', () {
      final inv = inventarioBase()
          .conItem('ancla_puerta', EstadoItem.disponible)
          .confirmando(CamposAparato.anclajeEstacion, 1);
      for (final e in cat.ejercicios) {
        for (final v in e.variantes) {
          if (v.esDeBanda) expect(ofrece(inv, v.id), isFalse, reason: v.id);
        }
      }
    });

    test('CASO MALO: una banda con cantidad 0 o inactiva no cuenta', () {
      const cero = BandaInventario(id: 'z', nombre: 'z', orden: 1, cantidad: 0);
      const inactiva = BandaInventario(
        id: 'y',
        nombre: 'y',
        orden: 2,
        activa: false,
      );
      expect(cero.cuenta, isFalse);
      expect(inactiva.cuenta, isFalse);
      final inv = inventarioBase().conBandas(const [cero, inactiva]);
      expect(inv.hayBandas, isFalse);
      expect(ofrece(inv, 'elevacion_lateral_banda'), isFalse);
      // Con una banda buena al lado sí.
      expect(
        ofrece(inv.conBandas(const [cero, banda2]), 'elevacion_lateral_banda'),
        isTrue,
      );
    });

    test(
      'secuencia de progresión: banda, dos iguales juntas, la siguiente',
      () {
        final s = secuenciaBandas(const [banda2, banda1]);
        expect(s, [
          const PasoBanda('b1'),
          const PasoBanda('b1', doble: true),
          const PasoBanda('b2'),
        ]);
        expect(
          siguientePasoBanda(const PasoBanda('b1'), const [banda1, banda2]),
          const PasoBanda('b1', doble: true),
        );
        expect(
          siguientePasoBanda(const PasoBanda('b2'), const [banda1, banda2]),
          isNull,
        );
        expect(
          anteriorPasoBanda(const PasoBanda('b2'), const [banda1, banda2]),
          const PasoBanda('b1', doble: true),
        );
      },
    );

    test('aviso de seguridad de la banda: la primera vez y cada 4 semanas', () {
      final inv = sinEstacion(conBandas());
      expect(
        generar('A', inventario: inv).tiene(CodigoAviso.seguridadBanda),
        isTrue,
      );
      final reciente = sesionHecha(
        fecha: dia(2026, 12, 1),
        ejercicio: 'elevacion_lateral',
        variante: 'elevacion_lateral_banda',
        carga: null,
        bandaId: 'b1',
        repsMin: 12,
        repsMax: 15,
        reps: const [12, 12, 12],
      );
      expect(
        generar(
          'A',
          inventario: inv,
          historial: [reciente],
          hoy: dia(2026, 12, 10),
        ).avisos.where(
          (a) => a.codigo == CodigoAviso.seguridadBanda && a.slotId == 'A2',
        ),
        isEmpty,
      );
      expect(
        generar(
          'A',
          inventario: inv,
          historial: [reciente],
          hoy: dia(2026, 12, 30),
        ).avisos.where(
          (a) => a.codigo == CodigoAviso.seguridadBanda && a.slotId == 'A2',
        ),
        isNotEmpty,
      );
    });
  });
}
