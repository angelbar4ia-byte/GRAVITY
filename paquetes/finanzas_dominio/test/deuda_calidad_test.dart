// Fase 8, bloque 6: deuda buena o mala (DD-01 a DD-20 de
// docs/specs/fase-8-fugas-y-deudas.md, sección 10.2). Ingreso mensual de
// referencia $20,000. Montos ilustrativos e inventados.
import 'dart:io';

import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:test/test.dart';

final hoy = Fecha(2026, 11, 16);
const ingreso = 2000000; // $20,000.00

const laptop = DeclaracionDeuda(
  proposito: PropositoDeuda.generaIngreso,
  vidaUtilMeses: 48,
);

/// Una compra a MSI con su deuda.
DeudaParaCalidad msi(
  String id, {
  int total = 1200000,
  int plazo = 12,
  int pagadas = 3,
  Fecha? compra,
  int? precioContado,
  DeclaracionDeuda? decl = laptop,
  List<EstadoOcurrencia>? pagos,
  String tarjeta = 'tc',
}) => DeudaParaCalidad(
  id: id,
  nombre: 'Compra $id',
  clase: ClaseDeuda.msi,
  msi: MsiParaCalidad(
    id: id,
    tarjetaId: tarjeta,
    fechaCompra: compra ?? Fecha(2026, 8, 10),
    totalCentavos: total,
    plazoMeses: plazo,
    pagadas: pagadas,
    precioContadoCentavos: precioContado,
  ),
  declaracion: decl,
  estadosDePagos: pagos ?? List.filled(3, EstadoOcurrencia.cumplida),
);

const tarjeta = DeudaParaCalidad(
  id: 'tc',
  nombre: 'Tarjeta',
  clase: ClaseDeuda.tarjeta,
);

EstadoDeCuenta estado(
  Fecha corte, {
  int intereses = 0,
  int sinIntereses = 300000,
  int minimo = 30000,
}) => EstadoDeCuenta(
  id: 'e${corte.toString()}',
  libroId: 'L',
  deudaId: 'tc',
  fechaCorte: corte,
  fechaLimitePago: corte.sumarDias(20),
  saldoAlCorte: 500000,
  pagoMinimo: minimo,
  pagoSinIntereses: sinIntereses,
  intereses: intereses,
  registradoEn: DateTime(corte.anio, corte.mes, corte.dia),
);

CorteDeTarjeta corte(
  Fecha f, {
  int intereses = 0,
  int? pagos,
  int sinIntereses = 300000,
  int minimo = 30000,
}) => CorteDeTarjeta(
  estado: estado(
    f,
    intereses: intereses,
    sinIntereses: sinIntereses,
    minimo: minimo,
  ),
  pagosAlCorteCentavos: pagos ?? sinIntereses,
);

EntradaCalidadDeuda entrada(
  List<DeudaParaCalidad> deudas, {
  List<CorteDeTarjeta>? cortes,
  int limite = 4500000,
  int saldo = 0,
}) => EntradaCalidadDeuda(
  hoy: hoy,
  ingresoMensualCentavos: ingreso,
  deudas: deudas,
  tarjetas: [
    TarjetaParaCalidad(
      deudaId: 'tc',
      saldoCentavos: saldo,
      limiteCentavos: limite,
    ),
  ],
  cortes: cortes ?? [corte(Fecha(2026, 11, 10))],
);

CalidadDeuda evalua(EntradaCalidadDeuda e, String id) =>
    evaluarDeudas(e).firstWhere((c) => c.deudaId == id);

void main() {
  group('Deuda buena (DD-01, DD-20)', () {
    test(
      'DD-01 MSI de \$12,000 a 12 meses para una laptop de trabajo: buena',
      () {
        // 3 pagadas: pendiente 9 x 1,000 = 9,000 sobre un límite de 45,000 = 20 %.
        final e = entrada([tarjeta, msi('m1')]);
        final c = evalua(e, 'm1');
        expect(c.estado, EstadoCalidad.buena);
        expect(c.estado.etiqueta, 'Deuda buena');
        expect(c.semaforo, Semaforo.verde);
        expect(c.senal('B1')!.nivel, NivelSenal.verde);
        expect(c.senal('B3')!.nivel, NivelSenal.verde);
        expect(c.senal('B6a')!.nivel, NivelSenal.verde);
        expect(c.senal('B6b')!.nivel, NivelSenal.verde);
        expect(c.senal('B7')!.nivel, NivelSenal.verde);
        expect(c.senal('B2')!.nivel, NivelSenal.sinDato);
        expect(c.deterioros, isEmpty);
      },
    );

    test('DD-20 crédito automotriz con propósito genera_ingreso: verde; sin propósito: gris', () {
      DeudaParaCalidad auto(DeclaracionDeuda? d) => DeudaParaCalidad(
        id: 'auto',
        nombre: 'Auto',
        clase: ClaseDeuda.credito,
        plazoMeses: 48,
        mensualidadesPendientes: 30,
        pagoMensualCentavos: 300000, // 15 % del ingreso
        declaracion: d,
        estadosDePagos: List.filled(6, EstadoOcurrencia.cumplida),
      );
      const trabajo = DeclaracionDeuda(
        proposito: PropositoDeuda.generaIngreso,
        vidaUtilMeses: 96,
      );
      final bueno = evalua(entrada([auto(trabajo)]), 'auto');
      expect(bueno.estado, EstadoCalidad.buena);
      expect(bueno.senal('B2')!.nivel, NivelSenal.verde);
      expect(
        bueno.senal('B3')!.nivel,
        NivelSenal.verde,
      ); // 48 > 18 no aplica a un crédito
      expect(bueno.senal('B4a')!.nivel, NivelSenal.verde);

      final gris = evalua(entrada([auto(null)]), 'auto');
      expect(gris.estado, EstadoCalidad.porDeclarar);
      expect(gris.semaforo, isNull);
    });
  });

  group('Umbrales (DD-02 a DD-04)', () {
    test('DD-02 MSI sobre el ingreso: 10 % verde, \$2,001 ámbar, 20 % ámbar, \$4,001 rojo', () {
      NivelSenal n(int m) => senalMsiSobreIngreso(m, ingreso);
      expect(n(200000), NivelSenal.verde);
      expect(n(200100), NivelSenal.ambar);
      expect(n(400000), NivelSenal.ambar);
      expect(n(400100), NivelSenal.rojo);
      expect(senalMsiSobreIngreso(1, 0), NivelSenal.sinDato);
    });

    test('DD-03 MSI activos: 2 verde, 3 ámbar, 4 rojo', () {
      expect(senalMsiActivos(0), NivelSenal.verde);
      expect(senalMsiActivos(2), NivelSenal.verde);
      expect(senalMsiActivos(3), NivelSenal.ambar);
      expect(senalMsiActivos(4), NivelSenal.rojo);
      expect(senalMsiActivos(7), NivelSenal.rojo);
    });

    test('DD-04 carga total (semáforo existente): 34.99 % y 35 % ámbar; 35.005 % rojo', () {
      expect(senalCargaTotal(699900, ingreso), NivelSenal.ambar);
      expect(senalCargaTotal(700000, ingreso), NivelSenal.ambar);
      expect(senalCargaTotal(700100, ingreso), NivelSenal.rojo);
      expect(senalCargaTotal(399900, ingreso), NivelSenal.verde);
      expect(senalCargaTotal(400000, ingreso), NivelSenal.ambar);
      expect(senalCargaTotal(100, 0), NivelSenal.sinDato);
    });

    test('los umbrales se cambian en ParametrosFugas', () {
      const p = ParametrosFugas(msiAmbarPb: 500, msiRojoPb: 1000);
      expect(
        senalMsiSobreIngreso(200000, ingreso, parametros: p),
        NivelSenal.ambar,
      );
      expect(
        senalMsiSobreIngreso(200100, ingreso, parametros: p),
        NivelSenal.rojo,
      );
    });

    test('el uso del límite reutiliza 30 y 60 % (B7)', () {
      EntradaCalidadDeuda con(int saldo) => entrada(
        [tarjeta, msi('m1', pagadas: 12 - 3)],
        saldo: saldo,
        limite: 1000000,
      );
      // MSI pendiente: 3 x 1,000 = 3,000. Saldo 0 -> 30 % exacto = ámbar.
      expect(evalua(con(0), 'm1').senal('B7')!.nivel, NivelSenal.ambar);
      expect(
        evalua(con(300000), 'm1').senal('B7')!.nivel,
        NivelSenal.ambar,
      ); // 60 % exacto
      expect(evalua(con(300100), 'm1').senal('B7')!.nivel, NivelSenal.rojo);
    });
  });

  group('Deterioro (DD-05 a DD-11)', () {
    test('DD-05 encadenamiento: 1 y luego 3 en 12 meses (rojo)', () {
      MsiParaCalidad m(String id, Fecha f, {int plazo = 6, int pagadas = 0}) =>
          MsiParaCalidad(
            id: id,
            tarjetaId: 'tc',
            fechaCompra: f,
            totalCentavos: 600000,
            plazoMeses: plazo,
            pagadas: pagadas,
          );
      // A de 6 mensualidades con 5 pagadas (1 pendiente) y B comprado ese día.
      final a = m('A', Fecha(2026, 5, 10), pagadas: 5);
      final b = m('B', Fecha(2026, 10, 10));
      expect(encadenamientosMsi([a, b], tarjetaId: 'tc', hoy: hoy), 1);
      // Otra tarjeta no encadena.
      expect(encadenamientosMsi([a, b], tarjetaId: 'otra', hoy: hoy), 0);

      // Tres encadenamientos en 12 meses: rojo.
      final cadena = [
        m('A', Fecha(2026, 1, 10)),
        m('B', Fecha(2026, 6, 10)),
        m('C', Fecha(2026, 10, 10)),
        m('D', Fecha(2026, 11, 10)),
      ];
      expect(encadenamientosMsi(cadena, tarjetaId: 'tc', hoy: hoy), 3);
      final deudas = [
        tarjeta,
        for (final x in cadena)
          DeudaParaCalidad(
            id: x.id,
            nombre: x.id,
            clase: ClaseDeuda.msi,
            msi: x,
            declaracion: laptop,
            estadosDePagos: List.filled(3, EstadoOcurrencia.cumplida),
          ),
      ];
      final c = evalua(entrada(deudas), 'D');
      expect(c.senal('M1')!.nivel, NivelSenal.rojo);
      expect(c.estado, EstadoCalidad.seVolvioMala);
      expect(
        c.deterioros.any((d) => d.codigo == 'M1' && d.nivel == NivelSenal.rojo),
        isTrue,
      );
    });

    test('DD-05 bis: dos encadenamientos son ámbar; uno solo es verde', () {
      MsiParaCalidad m(String id, Fecha f) => MsiParaCalidad(
        id: id,
        tarjetaId: 'tc',
        fechaCompra: f,
        totalCentavos: 600000,
        plazoMeses: 6,
      );
      final dos = [
        m('A', Fecha(2026, 1, 10)),
        m('B', Fecha(2026, 6, 10)),
        m('C', Fecha(2026, 10, 10)),
      ];
      expect(encadenamientosMsi(dos, tarjetaId: 'tc', hoy: hoy), 2);
      // Una compra tras 31 días del fin no encadena (terminó hace más de 30).
      final lejos = [m('A', Fecha(2026, 1, 10)), m('B', Fecha(2026, 8, 10))];
      expect(encadenamientosMsi(lejos, tarjetaId: 'tc', hoy: hoy), 0);
      // Terminó hace 30 días o menos (el 10/jul + 30 = 9/ago): sí encadena.
      final justo = [m('A', Fecha(2026, 1, 10)), m('B', Fecha(2026, 8, 9))];
      expect(encadenamientosMsi(justo, tarjetaId: 'tc', hoy: hoy), 1);
    });

    test(
      'DD-06 objetivo que ya no existe: rojo con M3 si quedan pendientes',
      () {
        const vendido = DeclaracionDeuda(
          proposito: PropositoDeuda.bienDuradero,
          vidaUtilMeses: 48,
          estado: EstadoObjetivo.yaNoExiste,
        );
        final conPendientes = evalua(
          entrada([tarjeta, msi('m1', pagadas: 7, decl: vendido)]),
          'm1',
        );
        expect(conPendientes.estado, EstadoCalidad.seVolvioMala);
        expect(conPendientes.senal('B1')!.nivel, NivelSenal.rojo);
        expect(conPendientes.senal('B5')!.nivel, NivelSenal.rojo);
        expect(conPendientes.deterioros.map((d) => d.codigo), contains('M3'));

        // Con 0 pendientes no se enciende.
        final liquidada = evalua(
          entrada([tarjeta, msi('m1', pagadas: 12, decl: vendido)]),
          'm1',
        );
        expect(liquidada.estado, EstadoCalidad.liquidada);
        expect(liquidada.deterioros, isEmpty);
        expect(liquidada.senales, isEmpty);
      },
    );

    test('un objetivo que cambió también enciende M3', () {
      const cambio = DeclaracionDeuda(
        proposito: PropositoDeuda.bienDuradero,
        estado: EstadoObjetivo.cambio,
      );
      final c = evalua(entrada([tarjeta, msi('m1', decl: cambio)]), 'm1');
      expect(c.deterioros.map((d) => d.codigo), contains('M3'));
    });

    test('DD-07 solo el mínimo: B6b roja', () {
      final c = evalua(
        entrada(
          [tarjeta, msi('m1')],
          cortes: [corte(Fecha(2026, 11, 10), pagos: 30000)],
        ),
        'm1',
      );
      expect(c.senal('B6b')!.nivel, NivelSenal.rojo);
      expect(
        c.deterioros.any((d) => d.codigo == 'M2' && d.nivel == NivelSenal.rojo),
        isTrue,
      );
      expect(c.estado, EstadoCalidad.seVolvioMala);
      expect(
        clasificarPago(corte(Fecha(2026, 11, 10), pagos: 30000)),
        PagoDeTarjeta.soloElMinimo,
      );
      expect(
        clasificarPago(corte(Fecha(2026, 11, 10), pagos: 100000)),
        PagoDeTarjeta.menosQueElTotal,
      );
    });

    test('DD-08 intereses en 2 cortes seguidos: rojo; en uno: ámbar', () {
      final dos = evalua(
        entrada(
          [tarjeta, msi('m1')],
          cortes: [
            corte(Fecha(2026, 10, 10), intereses: 20000),
            corte(Fecha(2026, 11, 10), intereses: 20000),
          ],
        ),
        'm1',
      );
      expect(dos.senal('B6b')!.nivel, NivelSenal.rojo);
      final uno = evalua(
        entrada(
          [tarjeta, msi('m1')],
          cortes: [
            corte(Fecha(2026, 10, 10)),
            corte(Fecha(2026, 11, 10), intereses: 20000),
          ],
        ),
        'm1',
      );
      expect(uno.senal('B6b')!.nivel, NivelSenal.ambar);
      expect(uno.estado, EstadoCalidad.enVigilancia);
    });

    test('DD-09 plazo mayor que la vida útil: rojo (M7); plazo largo sin vida útil: ámbar', () {
      const corta = DeclaracionDeuda(
        proposito: PropositoDeuda.bienDuradero,
        vidaUtilMeses: 18,
      );
      final rojo = evalua(
        entrada([tarjeta, msi('m1', total: 2400000, plazo: 24, decl: corta)]),
        'm1',
      );
      expect(rojo.senal('B3')!.nivel, NivelSenal.rojo);
      expect(
        rojo.deterioros.any(
          (d) => d.codigo == 'M7' && d.nivel == NivelSenal.rojo,
        ),
        isTrue,
      );

      const sinVida = DeclaracionDeuda(proposito: PropositoDeuda.bienDuradero);
      final ambar = evalua(
        entrada([tarjeta, msi('m1', total: 2400000, plazo: 24, decl: sinVida)]),
        'm1',
      );
      expect(ambar.senal('B3')!.nivel, NivelSenal.ambar);
    });

    test('DD-10 sobreprecio: contado \$10,000 y total \$10,500 es ámbar; sin contado, sin dato', () {
      final con = evalua(
        entrada([
          tarjeta,
          msi(
            'm1',
            total: 1050000,
            plazo: 10,
            pagadas: 2,
            precioContado: 1000000,
          ),
        ]),
        'm1',
      );
      expect(con.senal('B2')!.nivel, NivelSenal.ambar);
      expect(
        con.deterioros.any(
          (d) => d.codigo == 'M7' && d.nivel == NivelSenal.ambar,
        ),
        isTrue,
      );
      final sin = evalua(
        entrada([tarjeta, msi('m1', total: 1050000, plazo: 10, pagadas: 2)]),
        'm1',
      );
      expect(sin.senal('B2')!.nivel, NivelSenal.sinDato);
      // Un contado igual al total no es sobreprecio.
      final igual = evalua(
        entrada([
          tarjeta,
          msi(
            'm1',
            total: 1000000,
            plazo: 10,
            pagadas: 2,
            precioContado: 1000000,
          ),
        ]),
        'm1',
      );
      expect(igual.senal('B2')!.nivel, NivelSenal.verde);
    });

    test('DD-11 tarjeta con intereses: mala por omisión (T1)', () {
      final c = evalua(
        entrada(
          [tarjeta],
          cortes: [corte(Fecha(2026, 11, 10), intereses: 35000)],
        ),
        'tc',
      );
      expect(c.estado, EstadoCalidad.seVolvioMala);
      expect(c.senal('T1')!.nivel, NivelSenal.rojo);
      expect(c.estado.etiqueta, 'Se volvió mala');
      // Sin intereses ni propósito: no se declara y no es mala.
      final ok = evalua(entrada([tarjeta]), 'tc');
      expect(ok.estado, EstadoCalidad.buena);
    });
  });

  group('Sin declarar, sin costo y sin dato (DD-12 a DD-14)', () {
    test('DD-12 MSI sin propósito: gris "Por declarar", no se juzga', () {
      final c = evalua(entrada([tarjeta, msi('m1', decl: null)]), 'm1');
      expect(c.estado, EstadoCalidad.porDeclarar);
      expect(c.senal('B1')!.nivel, NivelSenal.porDeclarar);
      expect(c.sugerencias, contains('Declara para qué fue.'));
    });

    test('DD-12 bis: un rojo gana al gris', () {
      final c = evalua(
        entrada(
          [tarjeta, msi('m1', decl: null)],
          cortes: [corte(Fecha(2026, 11, 10), pagos: 30000)],
        ),
        'm1',
      );
      expect(c.estado, EstadoCalidad.seVolvioMala);
    });

    test(
      'DD-13 préstamo familiar: sin costo, pero sí entra a la carga total',
      () {
        const papa = DeudaParaCalidad(
          id: 'papa',
          nombre: 'Préstamo familiar',
          clase: ClaseDeuda.familiar,
          pagoMensualCentavos: 500000,
          mensualidadesPendientes: 10,
        );
        final e = entrada([tarjeta, papa, msi('m1')]);
        final c = evalua(e, 'papa');
        expect(c.estado, EstadoCalidad.sinCosto);
        expect(c.senales, isEmpty);
        // Carga: 5,000 (familiar) + 1,000 (MSI) = 30 %: ámbar para las demás.
        expect(e.pagosDeudaMensuales, 600000);
        expect(evalua(e, 'm1').senal('B4a')!.nivel, NivelSenal.ambar);
      },
    );

    test(
      'DD-14 sin estado de cuenta: B6b dice "sin dato" y no suma al nivel',
      () {
        final c = evalua(entrada([tarjeta, msi('m1')], cortes: const []), 'm1');
        expect(c.senal('B6b')!.nivel, NivelSenal.sinDato);
        expect(
          c.senal('B6b')!.explicacion,
          'Falta el estado de cuenta para saberlo.',
        );
        expect(c.estado, EstadoCalidad.buena);
      },
    );

    test('sin límite capturado B7 es "sin dato"', () {
      final e = EntradaCalidadDeuda(
        hoy: hoy,
        ingresoMensualCentavos: ingreso,
        deudas: [tarjeta, msi('m1')],
        tarjetas: const [TarjetaParaCalidad(deudaId: 'tc', saldoCentavos: 0)],
        cortes: [corte(Fecha(2026, 11, 10))],
      );
      expect(evalua(e, 'm1').senal('B7')!.nivel, NivelSenal.sinDato);
    });
  });

  group('Histéresis y peor señal (DD-15, DD-16)', () {
    test('DD-15 rojo sin señales rojas una semana sigue rojo; baja tras 2 seguidas', () {
      var h = const HistorialNivel(EstadoCalidad.seVolvioMala);
      h = aplicarHisteresis(previo: h, calculado: EstadoCalidad.enVigilancia);
      expect(h.nivel, EstadoCalidad.seVolvioMala);
      expect(h.bajasSeguidas, 1);
      h = aplicarHisteresis(previo: h, calculado: EstadoCalidad.enVigilancia);
      expect(h.nivel, EstadoCalidad.enVigilancia);
      expect(h.bajasSeguidas, 0);
    });

    test(
      'subir es inmediato y una semana mala interrumpe la cuenta de bajada',
      () {
        var h = const HistorialNivel(EstadoCalidad.buena);
        h = aplicarHisteresis(previo: h, calculado: EstadoCalidad.seVolvioMala);
        expect(h.nivel, EstadoCalidad.seVolvioMala);
        h = aplicarHisteresis(previo: h, calculado: EstadoCalidad.buena);
        expect(h.bajasSeguidas, 1);
        h = aplicarHisteresis(previo: h, calculado: EstadoCalidad.seVolvioMala);
        expect(h.nivel, EstadoCalidad.seVolvioMala);
        expect(h.bajasSeguidas, 0);
        h = aplicarHisteresis(previo: h, calculado: EstadoCalidad.buena);
        expect(h.nivel, EstadoCalidad.seVolvioMala); // vuelve a empezar
      },
    );

    test('las evaluaciones para bajar son un parámetro', () {
      const p = ParametrosFugas(bajaNivelEvaluaciones: 3);
      var h = const HistorialNivel(EstadoCalidad.seVolvioMala);
      h = aplicarHisteresis(
        previo: h,
        calculado: EstadoCalidad.buena,
        parametros: p,
      );
      h = aplicarHisteresis(
        previo: h,
        calculado: EstadoCalidad.buena,
        parametros: p,
      );
      expect(h.nivel, EstadoCalidad.seVolvioMala);
      h = aplicarHisteresis(
        previo: h,
        calculado: EstadoCalidad.buena,
        parametros: p,
      );
      expect(h.nivel, EstadoCalidad.buena);
    });

    test('DD-16 peor señal: un rojo y varios verdes dan rojo', () {
      final c = evalua(
        entrada(
          [tarjeta, msi('m1')],
          cortes: [corte(Fecha(2026, 11, 10), pagos: 30000)],
        ),
        'm1',
      );
      final niveles = c.senales.map((s) => s.nivel).toList();
      expect(niveles.where((n) => n == NivelSenal.rojo), hasLength(1));
      expect(
        niveles.where((n) => n == NivelSenal.verde).length,
        greaterThanOrEqualTo(3),
      );
      expect(c.estado, EstadoCalidad.seVolvioMala);
    });

    test('un atraso es ámbar y dos son rojo (B6a)', () {
      final uno = evalua(
        entrada([
          tarjeta,
          msi(
            'm1',
            pagos: [EstadoOcurrencia.cumplida, EstadoOcurrencia.retrasada],
          ),
        ]),
        'm1',
      );
      expect(uno.senal('B6a')!.nivel, NivelSenal.ambar);
      expect(uno.estado, EstadoCalidad.enVigilancia);
      final dos = evalua(
        entrada([
          tarjeta,
          msi(
            'm1',
            pagos: [EstadoOcurrencia.retrasada, EstadoOcurrencia.retrasada],
          ),
        ]),
        'm1',
      );
      expect(dos.senal('B6a')!.nivel, NivelSenal.rojo);
      // Un atraso de hace más de 6 pagos ya no cuenta.
      final viejo = evalua(
        entrada([
          tarjeta,
          msi(
            'm1',
            pagos: [
              EstadoOcurrencia.retrasada,
              ...List.filled(6, EstadoOcurrencia.cumplida),
            ],
          ),
        ]),
        'm1',
      );
      expect(viejo.senal('B6a')!.nivel, NivelSenal.verde);
    });

    test(
      'los estados de pago salen de las ocurrencias de la deuda hasta hoy',
      () {
        Ocurrencia o(String origenId, Fecha f, EstadoOcurrencia e) =>
            Ocurrencia(
              id: '${origenId}_$f',
              libroId: 'L',
              origen: OrigenOcurrencia.deuda,
              origenId: origenId,
              fechaProgramada: f,
              fechaAjustada: f,
              montoEsperado: 1,
              estado: e,
            );
        final r = estadosDePagos(
          [
            o('m1', Fecha(2026, 10, 10), EstadoOcurrencia.retrasada),
            o('m1', Fecha(2026, 9, 10), EstadoOcurrencia.cumplida),
            o('m1', Fecha(2026, 12, 10), EstadoOcurrencia.esperada), // futura
            o('otra', Fecha(2026, 9, 10), EstadoOcurrencia.retrasada),
          ],
          deudaId: 'm1',
          hoy: hoy,
        );
        expect(r, [EstadoOcurrencia.cumplida, EstadoOcurrencia.retrasada]);
      },
    );
  });

  group('Vista previa y "solo avisa" (DD-17 a DD-19)', () {
    test('DD-17 con 2 MSI de \$1,000 al mes, un tercero de \$200: 11 %, 3 a la vez, ámbar', () {
      final actuales = [
        for (final id in ['a', 'b'])
          MsiParaCalidad(
            id: id,
            tarjetaId: 'tc',
            fechaCompra: Fecha(2026, 9, 1),
            totalCentavos: 1200000,
            plazoMeses: 12,
          ),
      ];
      final v = vistaPreviaMsiNuevo(
        activosActuales: actuales,
        mensualidadNuevaCentavos: 20000,
        ingresoMensualCentavos: ingreso,
      );
      expect(v.puntosBase, 1100);
      expect(v.activos, 3);
      expect(v.sobreIngreso, NivelSenal.ambar);
      expect(v.activosANivel, NivelSenal.ambar);
      expect(v.nivel, NivelSenal.ambar);
      // Sin el tercero: 10 % exacto y 2 a la vez, verde.
      final dos = vistaPreviaMsiNuevo(
        activosActuales: [actuales.first],
        mensualidadNuevaCentavos: 100000,
        ingresoMensualCentavos: ingreso,
      );
      expect(dos.puntosBase, 1000);
      expect(dos.nivel, NivelSenal.verde);
    });

    test(
      'DD-17 bis: ejemplo 5.5 bis, tres MSI = 11 %; un MSI liquidado no cuenta',
      () {
        final liquidado = MsiParaCalidad(
          id: 'x',
          tarjetaId: 'tc',
          fechaCompra: Fecha(2025, 1, 1),
          totalCentavos: 600000,
          plazoMeses: 6,
          pagadas: 6,
        );
        final v = vistaPreviaMsiNuevo(
          activosActuales: [liquidado],
          mensualidadNuevaCentavos: 100000,
          ingresoMensualCentavos: ingreso,
        );
        expect(v.activos, 1);
        expect(v.puntosBase, 500);
      },
    );

    test('DD-19 una deuda mala solo avisa: nunca bloquea ni pide confirmación extra', () {
      final mala = evalua(
        entrada(
          [tarjeta, msi('m1')],
          cortes: [corte(Fecha(2026, 11, 10), pagos: 30000)],
        ),
        'm1',
      );
      expect(mala.esMala, isTrue);
      expect(mala.bloquea, isFalse);
      expect(mala.sugerencias, isNotEmpty);
      final v = vistaPreviaMsiNuevo(
        activosActuales: const [],
        mensualidadNuevaCentavos: 900000,
        ingresoMensualCentavos: ingreso,
      );
      expect(v.nivel, NivelSenal.rojo);
      expect(v.bloquea, isFalse);
    });
  });

  group('Solo reglas locales (DD-18)', () {
    test('DD-18 ningún archivo del bloque importa red, IA ni E/S', () {
      const archivos = [
        'lib/src/fugas.dart',
        'lib/src/deuda_calidad.dart',
        'lib/src/parametros_fugas.dart',
      ];
      const prohibidos = [
        'dart:io',
        'dart:html',
        'dart:js',
        'package:http',
        'package:dio',
        'package:supabase',
        'package:flutter',
        'package:google_generative_ai',
        'package:anthropic',
      ];
      for (final a in archivos) {
        final imports = File(a)
            .readAsLinesSync()
            .where((l) => l.trimLeft().startsWith('import '))
            .toList();
        expect(imports, isNotEmpty, reason: a);
        for (final i in imports) {
          for (final p in prohibidos) {
            expect(i.contains(p), isFalse, reason: '$a importa $p');
          }
          // Solo importaciones relativas dentro del paquete.
          expect(i.contains("'package:"), isFalse, reason: '$a: $i');
        }
        final fuente = File(a).readAsStringSync();
        expect(RegExp(r'https?://').hasMatch(fuente), isFalse, reason: a);
      }
    });

    test('el texto del objetivo: hasta 80 caracteres y sin cifras', () {
      expect(
        () => validarObjetivoTexto('Laptop para el trabajo'),
        returnsNormally,
      );
      expect(
        () => validarObjetivoTexto('Laptop de 12000'),
        throwsArgumentError,
      );
      expect(() => validarObjetivoTexto('x' * 81), throwsArgumentError);
      expect(() => validarObjetivoTexto('x' * 80), returnsNormally);
    });

    test(
      'las explicaciones de las señales no llevan cifras ni signos de moneda',
      () {
        final c = evalua(
          entrada(
            [tarjeta, msi('m1', decl: null)],
            cortes: [corte(Fecha(2026, 11, 10), intereses: 100, pagos: 30000)],
          ),
          'm1',
        );
        for (final s in c.senales) {
          expect(
            RegExp(r'[\d\$]').hasMatch(s.explicacion),
            isFalse,
            reason: s.explicacion,
          );
          if (s.sugerencia != null) {
            expect(
              RegExp(r'[\d\$]').hasMatch(s.sugerencia!),
              isFalse,
              reason: s.sugerencia,
            );
          }
        }
      },
    );
  });

  group('Mensualidades', () {
    test(
      'la mensualidad es total / meses con R1 y lo pendiente sale de la tabla',
      () {
        final m = MsiParaCalidad(
          id: 'x',
          tarjetaId: 'tc',
          fechaCompra: Fecha(2026, 8, 10),
          totalCentavos: 1000,
          plazoMeses: 3,
          pagadas: 1,
        );
        expect(m.mensualidad, 333);
        expect(m.pendientes, 2);
        expect(m.pendienteCentavos, 667); // 333 + 334 (la última absorbe)
        expect(m.fechaFin, Fecha(2026, 11, 10));
      },
    );

    test('se arma desde el Msi guardado', () {
      final guardado = Msi(
        id: 'i',
        libroId: 'L',
        deudaId: 'd',
        cuentaPasivoId: 'p',
        fechaCompra: Fecha(2026, 8, 10),
        montoTotal: 1200000,
        mensualidades: 12,
      );
      final m = MsiParaCalidad.deMsi(guardado, tarjetaId: 'tc', pagadas: 2);
      expect(m.id, 'd');
      expect(m.mensualidad, 100000);
    });
  });
}
