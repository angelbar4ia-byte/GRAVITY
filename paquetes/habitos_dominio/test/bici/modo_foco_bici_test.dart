import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

import 'ayudas_bici.dart';

TarjetaHoyBici tarjeta({required bool foco}) => tarjetaHoyBici(
  hoy: sabado5dic,
  equipo: EquipoBici.celular,
  duracionMin: 240,
  revisionMin: revision1430,
  modoFoco: foco,
);

void main() {
  group('CA-B-12 modo foco', () {
    test(
      'con foco no hay nota de progresión (aunque el aumento sea grande)',
      () {
        final hist = [
          for (var i = 0; i < 4; i++)
            Salida(
              id: 'h$i',
              fecha: dia(2026, 10, 3 + 7 * i),
              duracionMin: 240,
            ),
        ];
        final hoy = Salida(id: 'hoy', fecha: sabado5dic, duracionMin: 600);
        expect(
          evaluarProgresion(actual: hoy, historial: hist).mostrarNota,
          isTrue,
        );
        final p = evaluarProgresion(
          actual: hoy,
          historial: hist,
          modoFoco: true,
        );
        expect(p.mostrarNota, isFalse);
        expect(p.enFoco, isTrue);
      },
    );

    test('la salida sigue disponible y la tarjeta dice «ambos están bien»', () {
      final c = tarjeta(foco: true);
      expect(c.salidaDisponible, isTrue);
      expect(c.enFoco, isTrue);
      expect(c.mensaje, 'Hoy puedes salir o dejarlo: ambos están bien.');
      expect(c.tipo, TipoTarjetaBici.salida);
      expect(c.regresoMin, 12 * 60);
    });

    test('los textos de seguridad SIGUEN visibles (también en foco)', () {
      expect(tarjeta(foco: true).textosSeguridadVisibles, isTrue);
      expect(tarjeta(foco: false).textosSeguridadVisibles, isTrue);
      // La preparación del viernes también se muestra en foco.
      final v = tarjetaHoyBici(
        hoy: dia(2026, 12, 4),
        equipo: EquipoBici.celular,
        duracionMin: 240,
        revisionMin: revision1430,
        modoFoco: true,
      );
      expect(v.tipo, TipoTarjetaBici.preparaTuSalida);
      expect(v.textosSeguridadVisibles, isTrue);
      expect(puntosPreparacion(), isNotEmpty);
    });

    test('sin foco la tarjeta dice lo de siempre', () {
      expect(tarjeta(foco: false).mensaje, MensajesBici.hoyTocaSalida);
      expect(tarjeta(foco: false).enFoco, isFalse);
    });

    test(
      'la bicicleta recibe solo un booleano: no sabe qué hábito lo causó',
      () {
        // El parámetro es `bool modoFoco`; ningún tipo de la bicicleta nombra
        // hábitos a eliminar ni su causa.
        final c = tarjeta(foco: true);
        expect(c.enFoco, isA<bool>());
      },
    );
  });
}
