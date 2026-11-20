// Revisión de calidad del bloque 6 de Finanzas (Fase 8). Pruebas de guardia
// NUEVAS: demuestran bordes que las pruebas del bloque no cubren. Una prueba que
// falla aquí es un defecto confirmado (ver docs/revisiones/finanzas-bloque-6.md);
// cuando se corrija, la prueba debe pasar.
import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:test/test.dart';

final hoy = Fecha(2026, 11, 16); // lunes; ventana hormiga: 19/oct a 15/nov

const categorias = <String, CategoriaFuga>{
  'streaming': CategoriaFuga('streaming'),
};

int _n = 0;
GastoFuga g(Fecha f, int monto, String cat,
        {String? comercio, bool auto = false}) =>
    GastoFuga(
      id: 'g${_n++}',
      fecha: f,
      monto: monto,
      categoriaId: cat,
      comercio: comercio,
      cobroAutomatico: auto,
    );

ResultadoFugas analiza(
  List<GastoFuga> gastos, {
  List<RespuestaFuga> respuestas = const [],
  List<DecisionFuga> decisiones = const [],
}) =>
    analizarFugas(EntradaFugas(
      hoy: hoy,
      ingresoSemanalCentavos: 500000,
      gastos: gastos,
      categorias: categorias,
      respuestas: respuestas,
      decisiones: decisiones,
    ));

void main() {
  _correccionesPagosAlCorte();
  test('H-04: un gasto sostiene a UNA sola fuga (no a una hormiga y a un fantasma)',
      () {
    // Un cobro mensual de 129 pesos: tres meses automáticos y el de noviembre
    // capturado a mano (por ejemplo, la persona lo pagó en la app del servicio).
    final mensual = [
      g(Fecha(2026, 8, 5), 12900, 'streaming', comercio: 'Netflix', auto: true),
      g(Fecha(2026, 9, 5), 12900, 'streaming', comercio: 'Netflix', auto: true),
      g(Fecha(2026, 10, 5), 12900, 'streaming', comercio: 'Netflix', auto: true),
      g(Fecha(2026, 11, 5), 12900, 'streaming', comercio: 'Netflix', auto: false),
    ];
    // Siete compras chicas a mano de la misma categoría en 3 semanas distintas.
    final chicas = [
      for (var i = 0; i < 7; i++)
        g(Fecha(2026, 10, 19).sumarDias(i * 3), 5000, 'streaming'),
    ];
    final clave = analiza(mensual).todas
        .firstWhere((f) => f.comercioNorm == 'netflix')
        .clave;
    final r = analiza(
      [...mensual, ...chicas],
      respuestas: [
        RespuestaFuga(
          id: 'r1',
          clave: clave,
          pregunta: PreguntaFuga.reconoce,
          respuesta: RespuestaPersona.no,
          periodoLunes: Fecha(2026, 11, 9),
          registradoEn: DateTime(2026, 11, 9, 9),
        ),
      ],
    );
    final ids = r.gastoIdsEnFugas;
    expect(r.deTipo(TipoFuga.fantasma), isNotEmpty, reason: 'F3 confirmada');
    expect(r.deTipo(TipoFuga.hormiga), isNotEmpty, reason: 'H confirmada');
    expect(ids.toSet().length, ids.length,
        reason: 'un gasto, una sola fuga: hay gastos repetidos en '
            '${r.confirmadas.map((f) => f.toString()).toList()} -> '
            '${ids.where((i) => ids.where((j) => j == i).length > 1).toSet()}');
  });

  test('H-02: un corte sin pagos capturados no se lee como "pagó cero" '
      '(V-D y B6b)', () {
    EstadoDeCuenta estado(String id, Fecha corte, {int intereses = 0}) =>
        EstadoDeCuenta(
          id: id,
          libroId: 'L',
          deudaId: 'tc',
          fechaCorte: corte,
          fechaLimitePago: corte.sumarDias(20),
          saldoAlCorte: 500000,
          pagoMinimo: 30000,
          pagoSinIntereses: 300000,
          intereses: intereses,
          cargos: 0,
          registradoEn: DateTime(corte.anio, corte.mes, corte.dia),
        );
    // Dos cortes importados de un estado de cuenta: nadie capturó los pagos
    // (la columna del servidor es `not null default 0`, así que llegan como 0).
    final cortes = [
      CorteDeTarjeta(estado: estado('e1', Fecha(2026, 10, 10))),
      CorteDeTarjeta(estado: estado('e2', Fecha(2026, 11, 10), intereses: 9000)),
    ];
    final r = analiza(const [], decisiones: const []);
    expect(r.todas, isEmpty);
    final r2 = analizarFugas(EntradaFugas(
      hoy: hoy,
      ingresoSemanalCentavos: 500000,
      gastos: const [],
      categorias: categorias,
      cortes: cortes,
    ));
    final cargo = r2.todas.firstWhere((f) => f.clave == claveCargo('tc'));
    expect(cargo.regla, isNot('VD'),
        reason: 'sin dato de pagos no se puede acusar "pagó solo el mínimo"');
    expect(senalPagoTarjeta(cortesVigentes(cortes, 'tc')), NivelSenal.sinDato,
        reason: 'B6b: sin pagos capturados la señal es "sin dato", no rojo');
  });
}

// Pruebas de la corrección F8-6.8 (sin dato de pagos al corte).
void _correccionesPagosAlCorte() {
  EstadoDeCuenta estado(Fecha corte, {int intereses = 0}) => EstadoDeCuenta(
        id: 'e${corte.mes}',
        libroId: 'L',
        deudaId: 'tc',
        fechaCorte: corte,
        fechaLimitePago: corte.sumarDias(20),
        saldoAlCorte: 500000,
        pagoMinimo: 30000,
        pagoSinIntereses: 300000,
        intereses: intereses,
        cargos: 0,
        registradoEn: DateTime(corte.anio, corte.mes, corte.dia),
      );
  group('pagos al corte: nulo es sin dato, cero capturado es cero', () {
    test('clasificarPago distingue nulo de cero', () {
      final e = estado(Fecha(2026, 10, 10));
      expect(clasificarPago(CorteDeTarjeta(estado: e)), PagoDeTarjeta.sinDato);
      expect(clasificarPago(CorteDeTarjeta(estado: e, pagosAlCorteCentavos: 0)),
          PagoDeTarjeta.soloElMinimo);
      expect(
          clasificarPago(
              CorteDeTarjeta(estado: e, pagosAlCorteCentavos: 300000)),
          PagoDeTarjeta.totalSinIntereses);
    });
    test('un cero capturado SÍ acusa V-D y rojo en B6b', () {
      final cortes = [
        CorteDeTarjeta(
            estado: estado(Fecha(2026, 10, 10)), pagosAlCorteCentavos: 0),
        CorteDeTarjeta(
            estado: estado(Fecha(2026, 11, 10), intereses: 9000),
            pagosAlCorteCentavos: 0),
      ];
      final r = analizarFugas(EntradaFugas(
        hoy: hoy,
        ingresoSemanalCentavos: 500000,
        gastos: const [],
        categorias: categorias,
        cortes: cortes,
      ));
      expect(r.todas.firstWhere((f) => f.clave == claveCargo('tc')).regla,
          'VD');
      expect(senalPagoTarjeta(cortesVigentes(cortes, 'tc')), NivelSenal.rojo);
    });
    test('sin pagos en el corte previo se usa el dato del ciclo anterior', () {
      final cortes = [
        CorteDeTarjeta(estado: estado(Fecha(2026, 10, 10))),
        CorteDeTarjeta(
            estado: estado(Fecha(2026, 11, 10), intereses: 9000),
            pagosCicloAnteriorCentavos: 0),
      ];
      final r = analizarFugas(EntradaFugas(
        hoy: hoy,
        ingresoSemanalCentavos: 500000,
        gastos: const [],
        categorias: categorias,
        cortes: cortes,
      ));
      expect(r.todas.firstWhere((f) => f.clave == claveCargo('tc')).regla,
          'VD');
    });
  });
}
