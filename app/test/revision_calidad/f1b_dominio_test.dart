// Revisión de calidad de la Fase 1b: el dominio de Finanzas contra un oráculo
// independiente (fechas calculadas aparte, con el calendario de Python y los
// festivos de la LFT art. 74 escritos a mano) y propiedades con datos al azar.
// Todas pasan hoy: son guardias.
//
// - Pensión de Papá (días 1 y 11) con el siguiente día hábil, 2026 y 2027, fines
//   de semana y festivos (incluidos 2/feb/2026 y 1/feb/2027, primer lunes de febrero).
// - `regla_inhabil` por pago: siguiente, anterior y sin cambio.
// - Pagos cada N meses con ancla en 31 (meses cortos, año bisiesto no: 2028).
// - Dos días fijos que coinciden (30 y último en febrero): 24 pagos al año.
// - `hasta` exclusivo de un miembro de libro.
// - Coma decimal: ida y vuelta con `formatearCentavos`, y los casos ambiguos.
// - Reparto del remanente con grupo de deudas prioritarias: conserva el dinero.
import 'dart:math';

import 'package:finanzas_dominio/finanzas_dominio.dart' hide formatearCentavos, Semaforo, TipoLibro, VisibilidadLibro, puntosBaseEnCien;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/formato.dart' show formatearCentavos;
import 'package:gravity/modulos/finanzas/pantallas/comunes.dart' show centavosDeTexto;

const _pensionSiguienteHabil = [
  '2026-01-01>2026-01-02', '2026-01-11>2026-01-12', '2026-02-01>2026-02-03', '2026-02-11>2026-02-11',
  '2026-03-01>2026-03-02', '2026-03-11>2026-03-11', '2026-04-01>2026-04-01', '2026-04-11>2026-04-13',
  '2026-05-01>2026-05-04', '2026-05-11>2026-05-11', '2026-06-01>2026-06-01', '2026-06-11>2026-06-11',
  '2026-07-01>2026-07-01', '2026-07-11>2026-07-13', '2026-08-01>2026-08-03', '2026-08-11>2026-08-11',
  '2026-09-01>2026-09-01', '2026-09-11>2026-09-11', '2026-10-01>2026-10-01', '2026-10-11>2026-10-12',
  '2026-11-01>2026-11-02', '2026-11-11>2026-11-11', '2026-12-01>2026-12-01', '2026-12-11>2026-12-11',
  '2027-01-01>2027-01-04', '2027-01-11>2027-01-11', '2027-02-01>2027-02-02', '2027-02-11>2027-02-11',
  '2027-03-01>2027-03-01', '2027-03-11>2027-03-11', '2027-04-01>2027-04-01', '2027-04-11>2027-04-12',
  '2027-05-01>2027-05-03', '2027-05-11>2027-05-11', '2027-06-01>2027-06-01', '2027-06-11>2027-06-11',
  '2027-07-01>2027-07-01', '2027-07-11>2027-07-12', '2027-08-01>2027-08-02', '2027-08-11>2027-08-11',
  '2027-09-01>2027-09-01', '2027-09-11>2027-09-13', '2027-10-01>2027-10-01', '2027-10-11>2027-10-11',
  '2027-11-01>2027-11-01', '2027-11-11>2027-11-11', '2027-12-01>2027-12-01', '2027-12-11>2027-12-13',
];

const _pensionHabilAnterior = [
  '2026-01-01>2025-12-31', '2026-01-11>2026-01-09', '2026-02-01>2026-01-30', '2026-02-11>2026-02-11',
  '2026-03-01>2026-02-27', '2026-03-11>2026-03-11', '2026-04-01>2026-04-01', '2026-04-11>2026-04-10',
  '2026-05-01>2026-04-30', '2026-05-11>2026-05-11', '2026-06-01>2026-06-01', '2026-06-11>2026-06-11',
  '2026-07-01>2026-07-01', '2026-07-11>2026-07-10', '2026-08-01>2026-07-31', '2026-08-11>2026-08-11',
  '2026-09-01>2026-09-01', '2026-09-11>2026-09-11', '2026-10-01>2026-10-01', '2026-10-11>2026-10-09',
  '2026-11-01>2026-10-30', '2026-11-11>2026-11-11', '2026-12-01>2026-12-01', '2026-12-11>2026-12-11',
  '2027-01-01>2026-12-31', '2027-01-11>2027-01-11', '2027-02-01>2027-01-29', '2027-02-11>2027-02-11',
  '2027-03-01>2027-03-01', '2027-03-11>2027-03-11', '2027-04-01>2027-04-01', '2027-04-11>2027-04-09',
  '2027-05-01>2027-04-30', '2027-05-11>2027-05-11', '2027-06-01>2027-06-01', '2027-06-11>2027-06-11',
  '2027-07-01>2027-07-01', '2027-07-11>2027-07-09', '2027-08-01>2027-07-30', '2027-08-11>2027-08-11',
  '2027-09-01>2027-09-01', '2027-09-11>2027-09-10', '2027-10-01>2027-10-01', '2027-10-11>2027-10-11',
  '2027-11-01>2027-11-01', '2027-11-11>2027-11-11', '2027-12-01>2027-12-01', '2027-12-11>2027-12-10',
];

Fecha _f(String texto) {
  final p = texto.split('-').map(int.parse).toList();
  return Fecha(p[0], p[1], p[2]);
}

List<String> _pares(List<FechaPago> pagos) => [
  for (final p in pagos) '${p.programada}>${p.ajustada}',
];

void main() {
  final calendario = CalendarioFijo.deDias([
    ...festivosOficialesMexico(2026),
    ...festivosOficialesMexico(2027),
  ]);

  group('pensión de Papá (1 y 11)', () {
    test('los festivos de 2026 y 2027 son los de la LFT art. 74', () {
      expect(
        [for (final a in [2026, 2027]) for (final d in festivosOficialesMexico(a)) d.fecha.toString()],
        [
          '2026-01-01', '2026-02-02', '2026-03-16', '2026-05-01', '2026-09-16', '2026-11-16', '2026-12-25',
          '2027-01-01', '2027-02-01', '2027-03-15', '2027-05-01', '2027-09-16', '2027-11-15', '2027-12-25',
        ],
      );
    });

    test('siguiente día hábil, 48 pagos en 2 años, contra el oráculo', () {
      final pension = CalendarioPago.diasFijos(
        [const DiaDelMes(1), const DiaDelMes(11)],
      );
      final pagos = pension.fechasDePago(_f('2026-01-01'), _f('2027-12-31'), calendario);
      expect(_pares(pagos), _pensionSiguienteHabil);
      expect(pension.vecesAlAnio, 24);
    });

    test('día hábil anterior (regla de un compromiso), contra el oráculo', () {
      final pension = CalendarioPago.diasFijos(
        [const DiaDelMes(1), const DiaDelMes(11)],
        regla: ReglaDiaInhabil.diaHabilAnterior,
      );
      // 1/ene/2026 pasa a 31/dic/2025: queda fuera del rango pedido por ajustada.
      final pagos = pension.fechasDePago(_f('2025-12-01'), _f('2027-12-31'), calendario);
      // El 1/ene/2028 (sábado) también se adelanta al 31/dic/2027, dentro del rango.
      final desdeEnero = _pares(pagos).skipWhile((p) => !p.startsWith('2026-01-01')).toList();
      expect(desdeEnero.take(48), _pensionHabilAnterior);
      expect(desdeEnero.skip(48), ['2028-01-01>2027-12-31']);
    });

    test('sin cambio: el pago se queda en su fecha aunque sea domingo o festivo', () {
      final pension = CalendarioPago.diasFijos(
        [const DiaDelMes(1), const DiaDelMes(11)],
        regla: ReglaDiaInhabil.sinCambio,
      );
      final pagos = pension.fechasDePago(_f('2026-01-01'), _f('2026-12-31'), calendario);
      expect(pagos, hasLength(24));
      expect(pagos.every((p) => !p.seMovio), isTrue);
    });
  });

  group('pagos cada N meses y días fijos', () {
    test('mensual con ancla el 31: febrero 28, abril 30…', () {
      final c = CalendarioPago.cadaMeses(_f('2026-01-31'), 1);
      expect(
        c.fechasNominales(_f('2026-01-01'), _f('2027-02-28')).map((f) => f.toString()).toList(),
        [
          '2026-01-31', '2026-02-28', '2026-03-31', '2026-04-30', '2026-05-31', '2026-06-30', '2026-07-31',
          '2026-08-31', '2026-09-30', '2026-10-31', '2026-11-30', '2026-12-31', '2027-01-31', '2027-02-28',
        ],
      );
    });

    test('bimestral con ancla el 31/dic: 28/feb, 30/abr, 30/jun…', () {
      final c = CalendarioPago.cadaMeses(_f('2026-12-31'), 2);
      expect(
        c.fechasNominales(_f('2026-12-01'), _f('2027-12-31')).map((f) => f.toString()).toList(),
        ['2026-12-31', '2027-02-28', '2027-04-30', '2027-06-30', '2027-08-31', '2027-10-31', '2027-12-31'],
      );
    });

    test('30 y último con febrero: los dos pagos caen el 28 y cuentan 24 al año (M4)', () {
      final c = CalendarioPago.diasFijos([const DiaDelMes(30), DiaDelMes.ultimo]);
      final feb = c.fechasNominales(_f('2027-02-01'), _f('2027-02-28'));
      expect(feb.map((f) => f.toString()), ['2027-02-28', '2027-02-28']);
      final anio = c.fechasNominales(_f('2027-01-01'), _f('2027-12-31'));
      expect(anio, hasLength(c.vecesAlAnio));
    });

    test('dos días fijos iguales son uno solo (12 al año)', () {
      final c = CalendarioPago.diasFijos([const DiaDelMes(5), const DiaDelMes(5)]);
      expect(c.vecesAlAnio, 12);
      expect(c.fechasNominales(_f('2026-01-01'), _f('2026-12-31')), hasLength(12));
    });

    test('más de dos días fijos o ninguno no se aceptan', () {
      expect(() => CalendarioPago.diasFijos([]), throwsArgumentError);
      expect(
        () => CalendarioPago.diasFijos([const DiaDelMes(1), const DiaDelMes(11), const DiaDelMes(21)]),
        throwsArgumentError,
      );
    });
  });

  test('hasta de un miembro de libro es exclusivo: el día del cambio ya no es vigente', () {
    final m = MiembroLibro(
      personaId: 'ana',
      papel: PapelLibro.albacea,
      desde: _f('2026-01-01'),
      hasta: _f('2026-10-20'),
    );
    expect(m.vigenteEn(_f('2026-10-19')), isTrue);
    expect(m.vigenteEn(_f('2026-10-20')), isFalse);
    expect(m.vigenteEn(_f('2025-12-31')), isFalse);
    expect(m.vigenteEn(_f('2026-01-01')), isTrue, reason: 'desde es inclusivo');
  });

  group('coma decimal', () {
    test('ida y vuelta con formatearCentavos para 20,000 importes al azar', () {
      final azar = Random(23102026);
      for (var i = 0; i < 20000; i++) {
        final magnitud = pow(10, azar.nextInt(8)).toInt(); // hasta 10 millones de pesos
        final c = azar.nextInt(magnitud * 100 + 1);
        final texto = formatearCentavos(c);
        expect(centavosDeTexto(texto), c, reason: texto);
        expect(centavosDeTexto(texto.replaceAll(r'$', '')), c, reason: texto);
        expect(centavosDeTexto(' $texto '), c);
      }
      for (final c in [0, 1, 99, 100, 99999999999]) {
        expect(centavosDeTexto(formatearCentavos(c)), c, reason: '$c centavos');
      }
    });

    test('los casos de la regla 67, y lo ambiguo se rechaza en lugar de adivinar', () {
      expect(centavosDeTexto('12,5'), 1250);
      expect(centavosDeTexto('85,50'), 8550);
      expect(centavosDeTexto('.5'), 50);
      expect(centavosDeTexto('1,234'), 123400);
      expect(centavosDeTexto('1.234,56'), 123456);
      expect(centavosDeTexto('12,345,678'), 1234567800);
      for (final ambiguo in ['1,2345', '85.555', '1,23,4', '1,,2', ',', '.', '1.2.3', 'abc', '12,5x', '--5', '1e3']) {
        expect(centavosDeTexto(ambiguo), isNull, reason: '"$ambiguo"');
      }
    });
  });

  group('reparto del remanente con grupo de deudas prioritarias', () {
    DeudaPlan deuda(int n, {bool grupo = false, int? orden, int? saldo, TipoDeuda tipo = TipoDeuda.conCosto}) =>
        DeudaPlan(
          id: 'd$n',
          nombre: 'Deuda $n',
          tipo: tipo,
          abono: 10000,
          frecuencia: Frecuencia.semanal,
          tasaAnualPuntosBase: tipo == TipoDeuda.conCosto ? 1000 + n * 100 : 0,
          saldo: saldo,
          grupoPrioritario: grupo,
          ordenGrupo: orden,
        );

    test('propiedades con 3,000 casos al azar: se conserva el dinero y se respetan el grupo y los saldos', () {
      final azar = Random(7);
      for (var caso = 0; caso < 3000; caso++) {
        final n = 1 + azar.nextInt(5);
        final hayGrupo = azar.nextBool();
        final deudas = [
          for (var i = 0; i < n; i++)
            deuda(
              i,
              grupo: hayGrupo && azar.nextBool(),
              orden: 1 + azar.nextInt(4),
              saldo: azar.nextInt(4) == 0 ? null : azar.nextInt(500000),
              tipo: azar.nextInt(5) == 0 ? TipoDeuda.familiar : TipoDeuda.conCosto,
            ),
        ];
        final aplicados = {for (final d in deudas) d: azar.nextInt(10001)};
        final remanente = azar.nextInt(400000) - 1000; // incluye negativos
        final liberado = azar.nextInt(50000) - 100;
        final minimoPb = azar.nextInt(3) == 0 ? azar.nextInt(10001) : 0;
        final destino = repartirRemanente(
          remanente,
          aplicados,
          parametros: ParametrosPlan(ahorroMinimoConDeudaPuntosBase: minimoPb),
          liberado: liberado,
        );
        final disponible = (remanente < 0 ? 0 : remanente) + (liberado < 0 ? 0 : liberado);
        expect(destino.totalAbonoExtra + destino.ahorro, disponible, reason: 'caso $caso: todo el dinero va a algún lado');
        expect(destino.ahorro, greaterThanOrEqualTo(0));
        final conGrupo = deudas.any((d) => d.grupoPrioritario);
        for (final extra in destino.abonosExtra) {
          expect(extra.monto, greaterThan(0));
          if (conGrupo) {
            expect(extra.deuda.grupoPrioritario, isTrue, reason: 'caso $caso: con grupo, solo el grupo recibe extra');
          }
          final saldo = extra.deuda.saldo;
          if (saldo != null) {
            expect(extra.monto + (aplicados[extra.deuda] ?? 0), lessThanOrEqualTo(max(saldo, aplicados[extra.deuda]!)),
                reason: 'caso $caso: nunca más que el saldo');
          }
        }
      }
    });

    test('con el grupo liquidado todo el dinero va a ahorro, aunque otra deuda siga cobrando interés', () {
      final liquidada = deuda(1, grupo: true, orden: 1, saldo: 0);
      final otra = deuda(2, saldo: 900000);
      final destino = repartirRemanente(150000, {liquidada: 0, otra: 10000}, liberado: 20000);
      expect(destino.abonosExtra, isEmpty);
      expect(destino.ahorro, 170000);
    });
  });
}
