import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

void main() {
  group('CA-G-04 «confirmar en el aparato» no entra a los cálculos', () {
    test('sin confirmar: la carga se muestra en placas, sin kg ni tope', () {
      final inv = inventarioBase();
      final c = mostrarCargaPasos(5, inv);
      expect(c.texto, 'placa 5');
      expect(c.kgX10, isNull);
      expect(inv.pasosMax, isNull);
      expect(inv.kgPorPasoX10, isNull);
      expect(inv.enTopeDePila(5), isFalse);
      expect(inv.enTopeDePila(68), isFalse);
      expect(inv.enTopeDePila(1000), isFalse);
    });

    test(
      'CASO MALO: la pila de 68 kg del diseño se muestra «aprox.» y NO se usa '
      'para detectar el tope',
      () {
        final d = cat.datoAparato('pila_kg_aprox')!;
        expect(d.estado, EstadoDato.delDiseno);
        expect(d.valor, 68);
        expect(textoPilaAproximada(cat), 'aprox. 68 kg');
        final inv = inventarioBase();
        for (final pasos in [20, 68, 150]) {
          expect(inv.enTopeDePila(pasos), isFalse, reason: 'pasos $pasos');
        }
      },
    );

    test(
      'los datos del aparato nacen «confirmar» y solo la pila viene del diseño',
      () {
        for (final d in cat.datosAparato) {
          expect(
            d.estado,
            d.id == 'pila_kg_aprox'
                ? EstadoDato.delDiseno
                : EstadoDato.confirmar,
            reason: d.id,
          );
        }
      },
    );

    test('al confirmar sí: kg por paso y tope de la pila', () {
      final inv = inventarioBase()
          .confirmando(CamposAparato.pasosMax, 10)
          .confirmando(CamposAparato.kgPorPasoX10, 125);
      final c = mostrarCargaPasos(5, inv);
      expect(c.kgX10, 625);
      expect(c.texto, 'placa 5 · 62.5 kg');
      expect(inv.enTopeDePila(9), isFalse);
      expect(inv.enTopeDePila(10), isTrue);
      expect(inv.cargaValida(10), isTrue);
      expect(inv.cargaValida(11), isFalse);
    });

    test('sin confirmar el tope la progresión sube de placa en vez de usar la escalera', () {
      final h = [sesionHecha(fecha: dia(2026, 12, 1), carga: 68)];
      final s = generar('A', historial: h);
      final e = s.ejercicios.first;
      expect(e.motivo, MotivoProgresion.subeCarga);
      expect(e.cargaPasos, 69);
      expect(e.topeDePila, isFalse);
    });
  });
}
