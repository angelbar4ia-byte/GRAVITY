// Fase 2, deudas a detalle (criterios 2 a 7 de docs/specs/fase-2-finanzas.md).
// Las cuatro tarjetas son ilustrativas (5.3); datos inventados.
import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:test/test.dart';

DeudaPlan tarjeta(
  String id,
  int saldoPesos,
  int tasaPb, {
  int? manual,
  int minimo = 50000,
}) => DeudaPlan(
  id: id,
  nombre: 'Tarjeta $id',
  tipo: TipoDeuda.conCosto,
  abono: 100000,
  frecuencia: Frecuencia.mensual,
  minimo: minimo,
  tasaAnualPuntosBase: tasaPb,
  saldo: saldoPesos * 100,
  prioridadManual: manual,
);

void main() {
  final a = tarjeta('A', 20000, 4500);
  final b = tarjeta('B', 5000, 6000);
  final c = tarjeta('C', 12000, 3800);
  final d = tarjeta('D', 8000, 3000);

  group('Clases de deuda (criterio 2)', () {
    test('cada clase va con su tipo y su tasa', () {
      expect(
        () => ClaseDeuda.validar(ClaseDeuda.tarjeta, TipoDeuda.conCosto, 4500),
        returnsNormally,
      );
      expect(
        () => ClaseDeuda.validar(ClaseDeuda.msi, TipoDeuda.msi, 0),
        returnsNormally,
      );
      expect(
        () => ClaseDeuda.validar(ClaseDeuda.familiar, TipoDeuda.familiar, 0),
        returnsNormally,
      );
      expect(
        () => ClaseDeuda.validar(ClaseDeuda.msi, TipoDeuda.conCosto, 0),
        throwsArgumentError,
      );
      expect(
        () => ClaseDeuda.validar(ClaseDeuda.familiar, TipoDeuda.msi, 0),
        throwsArgumentError,
      );
      expect(
        () => ClaseDeuda.validar(ClaseDeuda.credito, TipoDeuda.conCosto, 0),
        throwsArgumentError,
      );
      expect(
        () => ClaseDeuda.validar(ClaseDeuda.msi, TipoDeuda.msi, 100),
        throwsArgumentError,
      );
    });
  });

  group('Orden de pago por costo (criterios 3 y 4)', () {
    test('el extra va en el orden B, A, C, D con el motivo de cada lugar', () {
      final orden = ordenConMotivo([a, b, c, d]);
      expect(orden.map((l) => l.deuda.id), ['B', 'A', 'C', 'D']);
      expect(orden.map((l) => l.motivo), [
        'tasa 60 %',
        'tasa 45 %',
        'tasa 38 %',
        'tasa 30 %',
      ]);
      expect(orden.map((l) => l.lugar), [1, 2, 3, 4]);
    });

    test('con prioridad manual en D, D primero', () {
      final orden = ordenConMotivo([
        a,
        b,
        c,
        tarjeta('D', 8000, 3000, manual: 1),
      ]);
      expect(orden.first.deuda.id, 'D');
      expect(orden.first.motivo, startsWith('manual'));
      expect(orden.skip(1).map((l) => l.deuda.id), ['B', 'A', 'C']);
    });

    test('un préstamo familiar al final y un MSI nunca', () {
      final familiar = DeudaPlan(
        id: 'F',
        nombre: 'Familiar',
        tipo: TipoDeuda.familiar,
        abono: 50000,
        frecuencia: Frecuencia.mensual,
        saldo: 300000,
      );
      final msi = DeudaPlan(
        id: 'M',
        nombre: 'MSI',
        tipo: TipoDeuda.msi,
        abono: 50000,
        frecuencia: Frecuencia.mensual,
        saldo: 600000,
      );
      final deudas = [familiar, msi, a, b];
      final orden = ordenConMotivo(deudas);
      expect(orden.map((l) => l.deuda.id), ['B', 'A', 'F']);
      expect(orden.last.motivo, 'familiar: al final');
      expect(msiSinExtra(deudas).map((x) => x.id), ['M']);
    });

    test('con grupo prioritario manda el grupo', () {
      final g = DeudaPlan(
        id: 'D',
        nombre: 'D',
        tipo: TipoDeuda.conCosto,
        abono: 100000,
        frecuencia: Frecuencia.mensual,
        tasaAnualPuntosBase: 3000,
        saldo: 800000,
        grupoPrioritario: true,
        ordenGrupo: 1,
      );
      final orden = ordenConMotivo([a, b, g]);
      expect(orden.map((l) => l.deuda.id), ['D']);
      expect(orden.single.motivo, 'grupo, lugar 1');
    });

    test('los mínimos de todas se cubren antes de cualquier extra', () {
      // 2,000 disponibles; mínimos de 4 tarjetas = 4 × 500 = 2,000: ni un peso de extra.
      final todas = [a, b, c, d];
      var aplicado = aplicarPagoConMinimosPrimero(todas, 200000);
      expect(aplicado.values.every((v) => v == 50000), isTrue);
      // Con 3,000 disponibles, el extra de 1,000 va a B (la de mayor tasa).
      aplicado = aplicarPagoConMinimosPrimero(todas, 300000);
      expect(aplicado['B'], 150000);
      expect(aplicado['A'], 50000);
      // Con menos que los mínimos, se cubren en el orden de la lista.
      aplicado = aplicarPagoConMinimosPrimero(todas, 120000);
      expect(
        [aplicado['A'], aplicado['B'], aplicado['C'], aplicado['D']],
        [50000, 50000, 20000, 0],
      );
    });

    test('el extra no pasa del saldo', () {
      final chica = tarjeta('B', 1000, 6000); // saldo $1,000
      final aplicado = aplicarPagoConMinimosPrimero([chica, a], 1000000);
      expect(aplicado['B'], 100000);
      expect(aplicado['A'], 900000);
    });
  });

  group('Costo de deber (criterio 5)', () {
    test('interés semanal estimado de las cuatro tarjetas: \$364.62', () {
      final costo = costoDeDeber([a, b, c, d]);
      expect(costo.semanal, 36462);
      expect(
        costo.porDeuda.values.fold(0, (x, y) => x + y),
        36462,
        reason: 'R2: suman exacto',
      );
      expect(costo.mensualDeReferencia, {
        'A': 75000,
        'B': 25000,
        'C': 38000,
        'D': 20000,
      });
    });

    test('familiares, MSI y deudas sin saldo no cuestan', () {
      final msi = DeudaPlan(
        id: 'M',
        nombre: 'MSI',
        tipo: TipoDeuda.msi,
        abono: 50000,
        frecuencia: Frecuencia.mensual,
        saldo: 600000,
      );
      expect(costoDeDeber([msi, tarjeta('Z', 0, 5000)]).semanal, 0);
    });
  });

  group('Uso del límite (criterio 6)', () {
    test('29.997 % verde; 30 % ámbar', () {
      final verde = usoDelLimite(saldo: 899900, limite: 3000000)!;
      expect(verde.semaforo, Semaforo.verde);
      expect(
        verde.puntosBase,
        3000,
        reason: 'redondeado se vería como 30 %, pero la fracción exacta manda',
      );
      expect(
        usoDelLimite(saldo: 900000, limite: 3000000)!.semaforo,
        Semaforo.ambar,
      );
    });

    test(
      'los MSI pendientes ocupan límite: 6,000 sobre 9,000 es 50 %, ámbar',
      () {
        final u = usoDelLimite(
          saldo: 900000,
          msiPendiente: 600000,
          limite: 3000000,
        )!;
        expect(u.usado, 1500000);
        expect(u.puntosBase, 5000);
        expect(u.semaforo, Semaforo.ambar);
        expect(
          usoDelLimite(
            saldo: 900000,
            msiPendiente: 600000,
            limite: 3000000,
            msiOcupanLimite: false,
          )!.puntosBase,
          3000,
        );
      },
    );

    test('60 % exacto es ámbar; arriba, rojo; sin límite no calcula', () {
      expect(
        usoDelLimite(saldo: 1800000, limite: 3000000)!.semaforo,
        Semaforo.ambar,
      );
      expect(
        usoDelLimite(saldo: 1800001, limite: 3000000)!.semaforo,
        Semaforo.rojo,
      );
      expect(usoDelLimite(saldo: 100, limite: null), isNull);
      expect(usoDelLimite(saldo: 100, limite: 0), isNull);
    });
  });

  group('MSI (criterio 7)', () {
    test(
      'mensualidades: 6,000 a 12 meses = 500; 1,000 a 3 meses suman exacto',
      () {
        expect(mensualidadesMsi(600000, 12), everyElement(50000));
        expect(mensualidadesMsi(100000, 3), [33333, 33333, 33334]);
        expect(mensualidadesMsi(100000, 3).fold(0, (x, y) => x + y), 100000);
        expect(() => mensualidadesMsi(100, 0), throwsArgumentError);
      },
    );

    test('lo pendiente sale de las mensualidades que faltan', () {
      final m = mensualidadesMsi(100000, 3);
      expect(pendienteDeMsi(m, 0), 100000);
      expect(pendienteDeMsi(m, 1), 66667);
      expect(pendienteDeMsi(m, 3), 0);
      expect(pendienteDeMsi(m, 9), 0);
    });

    test('la mensualidad del MSI cuenta completa como mínimo', () {
      final msi = DeudaPlan(
        id: 'M',
        nombre: 'MSI',
        tipo: TipoDeuda.msi,
        abono: 50000,
        frecuencia: Frecuencia.mensual,
      );
      expect(msi.minimo, 50000);
    });

    test('crédito sin permiso de pago anticipado no recibe extra', () {
      expect(puedeRecibirExtra(permitePagoAnticipado: null), isFalse);
      expect(puedeRecibirExtra(permitePagoAnticipado: false), isFalse);
      expect(puedeRecibirExtra(permitePagoAnticipado: true), isTrue);
    });
  });
}
