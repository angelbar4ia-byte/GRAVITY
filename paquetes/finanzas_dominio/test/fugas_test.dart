// Fase 8, bloque 6: fugas silenciosas (DF-01 a DF-27 de
// docs/specs/fase-8-fugas-y-deudas.md, sección 10.1). Los montos son
// ilustrativos e inventados; no hay datos reales.
import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:test/test.dart';

// Lunes: las 4 semanas terminadas son del 19/oct al 15/nov de 2026.
final hoy = Fecha(2026, 11, 16);

const categorias = <String, CategoriaFuga>{
  'cafe': CategoriaFuga('cafe'),
  'despensa': CategoriaFuga('despensa', recortable: false),
  'streaming': CategoriaFuga('streaming'),
  'gimnasio': CategoriaFuga('gimnasio'),
  'seguros': CategoriaFuga('seguros', seguro: true),
  'agua': CategoriaFuga('agua', recortable: false, servicioHogar: true),
  'luz': CategoriaFuga('luz', recortable: false, servicioHogar: true),
  'comisiones': CategoriaFuga(
    'comisiones',
    recortable: false,
    cargoFinanciero: true,
  ),
};

int _n = 0;
GastoFuga g(
  Fecha fecha,
  int monto,
  String cat, {
  String? comercio,
  bool auto = false,
}) => GastoFuga(
  id: 'g${_n++}',
  fecha: fecha,
  monto: monto,
  categoriaId: cat,
  comercio: comercio,
  cobroAutomatico: auto,
);

/// [n] gastos de [monto] repartidos en las 4 semanas de la ventana.
List<GastoFuga> repartidos(int n, int monto, String cat) => [
  for (var i = 0; i < n; i++)
    g(Fecha(2026, 10, 19).sumarDias((i % 4) * 7 + (i ~/ 4) % 7), monto, cat),
];

/// Cobros automáticos de [monto]; fechas dadas.
List<GastoFuga> cobros(
  String cat,
  String comercio,
  List<Fecha> fechas,
  List<int> montos, {
  bool auto = true,
}) => [
  for (var i = 0; i < fechas.length; i++)
    g(fechas[i], montos[i], cat, comercio: comercio, auto: auto),
];

final tresMeses = [Fecha(2026, 8, 5), Fecha(2026, 9, 5), Fecha(2026, 10, 5)];
final cuatroMeses = [...tresMeses, Fecha(2026, 11, 5)];

RespuestaFuga resp(
  String clave,
  PreguntaFuga q,
  RespuestaPersona r,
  Fecha lunes, {
  String? id,
  String? reemplazaA,
}) => RespuestaFuga(
  id: id ?? 'r${_n++}',
  clave: clave,
  pregunta: q,
  respuesta: r,
  periodoLunes: lunes,
  registradoEn: DateTime(lunes.anio, lunes.mes, lunes.dia, 9),
  reemplazaA: reemplazaA,
);

ResultadoFugas analiza(
  List<GastoFuga> gastos, {
  int ingresoSemanal = 500000,
  List<RespuestaFuga> respuestas = const [],
  List<PatronDeclarado> declarados = const [],
  List<DecisionFuga> decisiones = const [],
  List<CorteDeTarjeta> cortes = const [],
}) => analizarFugas(
  EntradaFugas(
    hoy: hoy,
    ingresoSemanalCentavos: ingresoSemanal,
    gastos: gastos,
    categorias: categorias,
    respuestas: respuestas,
    declarados: declarados,
    decisiones: decisiones,
    cortes: cortes,
  ),
);

EstadoDeCuenta estado(
  String id,
  Fecha corte, {
  int intereses = 0,
  int cargos = 0,
  int sinIntereses = 300000,
  int minimo = 30000,
}) => EstadoDeCuenta(
  id: id,
  libroId: 'L',
  deudaId: 'tc',
  fechaCorte: corte,
  fechaLimitePago: corte.sumarDias(20),
  saldoAlCorte: 500000,
  pagoMinimo: minimo,
  pagoSinIntereses: sinIntereses,
  intereses: intereses,
  cargos: cargos,
  registradoEn: DateTime(corte.anio, corte.mes, corte.dia),
);

void main() {
  test('la fecha de prueba es lunes', () {
    expect(hoy.diaSemana, DateTime.monday);
  });

  group('Normalización de comercio', () {
    test('minúsculas, sin acentos y sin números de referencia', () {
      expect(normalizarComercio('  CAFÉ Ñandú  '), 'cafe nandu');
      expect(normalizarComercio('NETFLIX.COM 12345678'), 'netflix com');
      expect(normalizarComercio('Spotify*AB123 Ref 9988'), 'spotify');
      expect(normalizarComercio('Folio 0045 Gimnasio Sol'), 'gimnasio sol');
      expect(normalizarComercio(null), '');
      expect(normalizarComercio('   '), '');
    });

    test('un número corto que es parte del nombre se conserva', () {
      expect(normalizarComercio('7 Eleven'), '7 eleven');
    });

    test('diccionario del hogar', () {
      const dic = {'Netflix': 'Servicio de video'};
      expect(
        normalizarComercio('NETFLIX 123456', diccionario: dic),
        'servicio de video',
      );
      expect(normalizarComercio('netflixx', diccionario: dic), 'netflixx');
    });

    test('mediana con cantidad par se redondea con R1', () {
      expect(mediana([100, 300, 200]), 200);
      expect(mediana([101, 102]), 102); // 101.5 -> 102
    });
  });

  group('Hormiga (H1 a H5)', () {
    test('DF-01 positiva', () {
      // 10 gastos de $45 en 4 semanas; ingreso semanal $5,000.
      final r = analiza(repartidos(10, 4500, 'cafe'));
      expect(r.ingresoMensualReferencia, 2166667); // $21,666.67
      final h = r.deTipo(TipoFuga.hormiga);
      expect(h, hasLength(1));
      expect(h.single.totalCentavos, 45000);
      expect(h.single.semanalCentavos, 11250); // $112.50
      expect(h.single.anualCentavos, 585000); // $5,850
      expect(h.single.regla, 'H');
      // 2.07 % del ingreso.
      expect(proporcionEnPuntosBase(45000, r.ingresoMensualReferencia), 208);
    });

    test('DF-02 frecuencia insuficiente: 7 gastos no son hormiga', () {
      expect(
        analiza(repartidos(7, 4500, 'cafe')).deTipo(TipoFuga.hormiga),
        isEmpty,
      );
    });

    test('DF-03 sobre el tope: 8 gastos de \$151 no cuentan', () {
      expect(
        analiza(repartidos(8, 15100, 'cafe')).deTipo(TipoFuga.hormiga),
        isEmpty,
      );
    });

    test('DF-04 concentrados en una sola semana: no es hormiga', () {
      final gastos = [
        for (var i = 0; i < 8; i++)
          g(Fecha(2026, 11, 9).sumarDias(i % 7), 5000, 'cafe'),
      ];
      expect(analiza(gastos).deTipo(TipoFuga.hormiga), isEmpty);
    });

    test('DF-04 bis: con 2 semanas distintas tampoco; con 3 sí', () {
      List<GastoFuga> enSemanas(int semanas) => [
        for (var i = 0; i < 8; i++)
          g(
            Fecha(2026, 10, 19).sumarDias((i % semanas) * 7 + i ~/ semanas),
            5000,
            'cafe',
          ),
      ];
      expect(analiza(enSemanas(2)).deTipo(TipoFuga.hormiga), isEmpty);
      expect(analiza(enSemanas(3)).deTipo(TipoFuga.hormiga), hasLength(1));
    });

    test('DF-05 no pesa: 8 gastos de \$20 con ingreso semanal de \$25,000', () {
      final r = analiza(repartidos(8, 2000, 'cafe'), ingresoSemanal: 2500000);
      expect(r.ingresoMensualReferencia, 10833333);
      expect(r.deTipo(TipoFuga.hormiga), isEmpty);
    });

    test('DF-05 bis: justo en el 1 % sí pesa (comparación exacta)', () {
      // 1 % de 2166667 = 21666.67: 8 gastos de 2709 suman 21672 (arriba).
      expect(
        analiza(repartidos(8, 2709, 'cafe')).deTipo(TipoFuga.hormiga),
        hasLength(1),
      );
      // 8 de 2708 suman 21664 (debajo).
      expect(
        analiza(repartidos(8, 2708, 'cafe')).deTipo(TipoFuga.hormiga),
        isEmpty,
      );
    });

    test('DF-06 categoría necesaria no es hormiga', () {
      expect(
        analiza(repartidos(12, 3000, 'despensa')).deTipo(TipoFuga.hormiga),
        isEmpty,
      );
    });

    test('DF-07 límite exacto del tope: \$150.00 cuenta y \$150.01 no', () {
      List<GastoFuga> con(int ultimo) => [
        ...repartidos(7, 4500, 'cafe'),
        g(Fecha(2026, 11, 13), ultimo, 'cafe'),
      ];
      expect(analiza(con(15000)).deTipo(TipoFuga.hormiga), hasLength(1));
      expect(analiza(con(15001)).deTipo(TipoFuga.hormiga), isEmpty);
    });

    test('un cobro automático nunca es hormiga (va por fantasma o zombie)', () {
      final gastos = [
        for (var i = 0; i < 10; i++)
          g(Fecha(2026, 10, 19).sumarDias(i * 2), 4500, 'cafe', auto: true),
      ];
      expect(analiza(gastos).deTipo(TipoFuga.hormiga), isEmpty);
    });

    test('alerta de conjunto: más de 5 % del ingreso mensual', () {
      // 5 % de 2166667 = 108333: 10 gastos de 11000 (110000) la encienden.
      final alta = analiza(repartidos(10, 11000, 'cafe'));
      expect(alta.alertaConjuntoHormiga, isTrue);
      expect(
        analiza(repartidos(10, 4500, 'cafe')).alertaConjuntoHormiga,
        isFalse,
      );
    });

    test('DF-22 semana en lunes: el domingo cuenta; el lunes siguiente no', () {
      final v = ventanaDeSemanas(hoy, 4);
      expect(v.inicio, Fecha(2026, 10, 19)); // lunes
      expect(v.fin, Fecha(2026, 11, 15)); // domingo
      expect(v.inicio.diaSemana, DateTime.monday);
      expect(v.fin.diaSemana, DateTime.sunday);
      // Un domingo pertenece a la semana que empezó el lunes anterior.
      expect(Semana.de(Fecha(2026, 11, 15)).inicio, Fecha(2026, 11, 9));

      List<GastoFuga> con(Fecha ultimo) => [
        for (var i = 0; i < 7; i++)
          g(Fecha(2026, 10, 20).sumarDias(i * 4), 4500, 'cafe'),
        g(ultimo, 4500, 'cafe'),
      ];
      expect(
        analiza(con(Fecha(2026, 11, 15))).deTipo(TipoFuga.hormiga),
        hasLength(1),
      );
      // El lunes 16 ya es la semana en curso: no cuenta.
      expect(
        analiza(con(Fecha(2026, 11, 16))).deTipo(TipoFuga.hormiga),
        isEmpty,
      );
      // El domingo 18 de octubre es de la semana anterior a la ventana.
      expect(
        analiza(con(Fecha(2026, 10, 18))).deTipo(TipoFuga.hormiga),
        isEmpty,
      );
    });

    test('DF-20 la hormiga se detecta sin comercio', () {
      final r = analiza(repartidos(10, 4500, 'cafe'));
      expect(r.deTipo(TipoFuga.hormiga).single.comercioNorm, isNull);
    });
  });

  group('Fantasma', () {
    final fechas = tresMeses;

    test('DF-08 fantasma: por reconocer, luego confirmado o sano', () {
      final gastos = cobros('streaming', 'Seguro Celular', fechas, [
        8900,
        8900,
        8900,
      ]);
      final clave = detectarPatrones(
        gastos,
        categorias: categorias,
      ).single.clave;
      // Cadencia mensual (intervalos de 31 y 30 días).
      expect(detectarPatrones(gastos).single.cadencia, CadenciaCobro.mensual);

      final base = analiza(gastos);
      expect(base.porReconocer, hasLength(1));
      expect(base.de(clave)!.fuga, TipoFuga.fantasma);
      expect(base.de(clave)!.estado, EstadoFuga.porReconocer);
      expect(base.deTipo(TipoFuga.fantasma), isEmpty);

      final no = analiza(
        gastos,
        respuestas: [
          resp(
            clave,
            PreguntaFuga.reconoce,
            RespuestaPersona.no,
            Fecha(2026, 11, 9),
          ),
        ],
      );
      expect(no.deTipo(TipoFuga.fantasma), hasLength(1));
      expect(no.deTipo(TipoFuga.fantasma).single.regla, 'F3');

      final si = analiza(
        gastos,
        respuestas: [
          resp(
            clave,
            PreguntaFuga.reconoce,
            RespuestaPersona.si,
            Fecha(2026, 11, 9),
          ),
          resp(
            clave,
            PreguntaFuga.uso,
            RespuestaPersona.si,
            Fecha(2026, 11, 9),
          ),
        ],
      );
      expect(si.confirmadas, isEmpty);
      expect(si.de(clave)!.fuga, TipoFuga.ninguna);
      expect(si.porReconocer, isEmpty);
    });

    test('un compromiso declarado cuenta como reconocido', () {
      final gastos = cobros('streaming', 'Plataforma', fechas, [
        8900,
        8900,
        8900,
      ]);
      final clave = detectarPatrones(gastos).single.clave;
      final r = analiza(
        gastos,
        declarados: [PatronDeclarado(clave, compromisoId: 'c1')],
      );
      expect(r.porReconocer, isEmpty);
      expect(r.confirmadas, isEmpty);
    });

    test('DF-09 monto estable: 89, 89 y 97 sí; 89, 89 y 99 no', () {
      final si = detectarPatrones(
        cobros('streaming', 'Plataforma', fechas, [8900, 8900, 9700]),
      ).single;
      expect(si.esRecurrente, isTrue);
      final no = detectarPatrones(
        cobros('streaming', 'Plataforma', fechas, [8900, 8900, 9900]),
      ).single;
      expect(no.cadencia, CadenciaCobro.mensual);
      expect(no.esRecurrente, isFalse);
    });

    test('dos cobros no bastan para ser recurrente', () {
      final p = detectarPatrones(
        cobros('streaming', 'Plataforma', fechas.take(2).toList(), [
          8900,
          8900,
        ]),
      ).single;
      expect(p.esRecurrente, isFalse);
    });

    test('las tolerancias de cada cadencia se respetan', () {
      CadenciaCobro cad(List<int> dias) {
        var f = Fecha(2026, 1, 1);
        final fs = [f];
        for (final d in dias) {
          f = f.sumarDias(d);
          fs.add(f);
        }
        return detectarPatrones(
          cobros('streaming', 'X', fs, List.filled(fs.length, 1000)),
        ).single.cadencia;
      }

      expect(cad([6, 8]), CadenciaCobro.semanal);
      expect(cad([5, 7]), CadenciaCobro.irregular);
      expect(cad([13, 17]), CadenciaCobro.quincenal);
      expect(cad([27, 33]), CadenciaCobro.mensual);
      expect(cad([34, 30]), CadenciaCobro.irregular);
      expect(cad([57, 65]), CadenciaCobro.bimestral);
      expect(cad([358, 372]), CadenciaCobro.anual);
    });

    test(
      'DF-10 sin respuesta no acusa: cuatro "Después" siguen por reconocer',
      () {
        final gastos = cobros('streaming', 'Plataforma', fechas, [
          8900,
          8900,
          8900,
        ]);
        final clave = detectarPatrones(gastos).single.clave;
        final r = analiza(
          gastos,
          respuestas: [
            resp(
              clave,
              PreguntaFuga.reconoce,
              RespuestaPersona.despues,
              Fecha(2026, 8, 17),
            ),
            resp(
              clave,
              PreguntaFuga.reconoce,
              RespuestaPersona.despues,
              Fecha(2026, 9, 14),
            ),
            resp(
              clave,
              PreguntaFuga.reconoce,
              RespuestaPersona.despues,
              Fecha(2026, 10, 12),
            ),
            resp(
              clave,
              PreguntaFuga.reconoce,
              RespuestaPersona.despues,
              Fecha(2026, 11, 9),
            ),
          ],
        );
        expect(r.porReconocer, hasLength(1));
        expect(r.deTipo(TipoFuga.fantasma), isEmpty);
      },
    );

    test('DF-17 cobro tras cancelar: fantasma con la marca', () {
      final gastos = cobros('streaming', 'Plataforma', fechas, [
        8900,
        8900,
        8900,
      ]);
      final clave = detectarPatrones(gastos).single.clave;
      final r = analiza(
        gastos,
        declarados: [
          PatronDeclarado(
            clave,
            canceladoEn: Fecha(2026, 9, 10),
            folio: 'ABC-123',
          ),
        ],
        respuestas: [
          resp(
            clave,
            PreguntaFuga.reconoce,
            RespuestaPersona.si,
            Fecha(2026, 9, 7),
          ),
        ],
      );
      final f = r.de(clave)!;
      expect(f.fuga, TipoFuga.fantasma);
      expect(f.estado, EstadoFuga.confirmada);
      expect(f.marcas, contains(MarcaFuga.cobradoTrasCancelar));
    });

    test('cancelado sin cobros nuevos: queda cancelado, con o sin folio', () {
      final gastos = cobros('streaming', 'Plataforma', fechas, [
        8900,
        8900,
        8900,
      ]);
      final clave = detectarPatrones(gastos).single.clave;
      final conFolio = analiza(
        gastos,
        declarados: [
          PatronDeclarado(
            clave,
            canceladoEn: Fecha(2026, 10, 10),
            folio: 'ABC-123',
          ),
        ],
      ).de(clave)!;
      expect(conFolio.estado, EstadoFuga.cancelada);
      expect(conFolio.marcas, isNot(contains(MarcaFuga.canceladoSinFolio)));
      final sin = analiza(
        gastos,
        declarados: [PatronDeclarado(clave, canceladoEn: Fecha(2026, 10, 10))],
      ).de(clave)!;
      expect(sin.marcas, contains(MarcaFuga.canceladoSinFolio));
    });

    test('DF-20 un patrón recurrente sin comercio se agrupa por subcategoría y monto', () {
      final gastos = [
        for (final f in fechas) g(f, 8900, 'streaming', auto: true),
      ];
      final p = detectarPatrones(gastos, categorias: categorias).single;
      expect(p.agrupadoSinComercio, isTrue);
      expect(p.comercioNorm, isNull);
      expect(p.esRecurrente, isTrue);
      final f = analiza(gastos).porReconocer.single;
      expect(f.marcas, contains(MarcaFuga.agrupadoSinComercio));
    });

    test('un comercio con otro texto de referencia es el mismo patrón', () {
      final gastos = [
        g(
          fechas[0],
          8900,
          'streaming',
          comercio: 'NETFLIX 11111111',
          auto: true,
        ),
        g(
          fechas[1],
          8900,
          'streaming',
          comercio: 'Netflix 22222222',
          auto: true,
        ),
        g(
          fechas[2],
          8900,
          'streaming',
          comercio: 'netflix 33333333',
          auto: true,
        ),
      ];
      expect(detectarPatrones(gastos), hasLength(1));
    });
  });

  group('Vampiro', () {
    final reconocido = [
      resp(
        'netflix|streaming',
        PreguntaFuga.reconoce,
        RespuestaPersona.si,
        Fecha(2026, 11, 9),
      ),
    ];

    List<GastoFuga> stream(int ultimo) => cobros(
      'streaming',
      'Netflix',
      cuatroMeses,
      [19900, 19900, 19900, ultimo],
    );

    test(
      'DF-11 prioridad: \$219 con dos "No lo usé" es zombie; con uso, vampiro',
      () {
        final zombie = analiza(
          stream(21900),
          respuestas: [
            ...reconocido,
            resp(
              'netflix|streaming',
              PreguntaFuga.uso,
              RespuestaPersona.no,
              Fecha(2026, 10, 12),
            ),
            resp(
              'netflix|streaming',
              PreguntaFuga.uso,
              RespuestaPersona.no,
              Fecha(2026, 11, 9),
            ),
          ],
        );
        expect(zombie.deTipo(TipoFuga.zombie), hasLength(1));
        expect(zombie.deTipo(TipoFuga.vampiro), isEmpty);

        final vampiro = analiza(
          stream(21900),
          respuestas: [
            ...reconocido,
            resp(
              'netflix|streaming',
              PreguntaFuga.uso,
              RespuestaPersona.si,
              Fecha(2026, 11, 9),
            ),
          ],
        );
        expect(vampiro.deTipo(TipoFuga.vampiro).single.regla, 'VB');
        expect(vampiro.deTipo(TipoFuga.zombie), isEmpty);

        // \$218 (9.55 %): ninguna.
        final nada = analiza(stream(21800), respuestas: reconocido);
        expect(nada.confirmadas, isEmpty);
      },
    );

    test('tres aumentos seguidos también son vampiro', () {
      final r = analiza(
        cobros('streaming', 'Netflix', cuatroMeses, [
          10000,
          10300,
          10600,
          10900,
        ]),
        respuestas: reconocido,
      );
      expect(r.deTipo(TipoFuga.vampiro), hasLength(1));
    });

    test('DF-13 cargo financiero: aparece en 2 de 3 cortes', () {
      CorteDeTarjeta c(EstadoDeCuenta e) =>
          CorteDeTarjeta(estado: e, pagosAlCorteCentavos: 300000);
      final r = analiza(
        [],
        cortes: [
          c(estado('a', Fecha(2026, 9, 10), intereses: 35000)),
          c(estado('b', Fecha(2026, 10, 10))),
          c(estado('c', Fecha(2026, 11, 10), intereses: 41000)),
        ],
      );
      expect(r.deTipo(TipoFuga.vampiro), hasLength(1));
      expect(r.deTipo(TipoFuga.vampiro).single.regla, 'VA');
      expect(r.deTipo(TipoFuga.vampiro).single.anualCentavos, 76000);

      final uno = analiza(
        [],
        cortes: [
          c(estado('a', Fecha(2026, 9, 10))),
          c(estado('b', Fecha(2026, 10, 10))),
          c(estado('c', Fecha(2026, 11, 10), intereses: 41000)),
        ],
      );
      expect(uno.confirmadas, isEmpty);
    });

    test('DF-13 bis: comisiones como gasto, 2 de los últimos 3 meses', () {
      final dos = analiza([
        g(Fecha(2026, 9, 12), 14900, 'comisiones'),
        g(Fecha(2026, 11, 12), 14900, 'comisiones'),
      ]);
      expect(dos.deTipo(TipoFuga.vampiro), hasLength(1));
      final uno = analiza([g(Fecha(2026, 11, 12), 14900, 'comisiones')]);
      expect(uno.confirmadas, isEmpty);
    });

    test('Z4: "ya no la quiero" convierte el cargo en zombie', () {
      final r = analiza(
        [],
        cortes: [
          CorteDeTarjeta(
            estado: estado('a', Fecha(2026, 10, 10), intereses: 100),
            pagosAlCorteCentavos: 300000,
          ),
          CorteDeTarjeta(
            estado: estado('b', Fecha(2026, 11, 10), intereses: 100),
            pagosAlCorteCentavos: 300000,
          ),
        ],
        respuestas: [
          resp(
            claveCargo('tc'),
            PreguntaFuga.yaNoLaQuiero,
            RespuestaPersona.si,
            Fecha(2026, 11, 9),
          ),
        ],
      );
      expect(r.deTipo(TipoFuga.zombie).single.regla, 'Z4');
      expect(r.deTipo(TipoFuga.vampiro), isEmpty);
    });

    List<GastoFuga> aguaMensual(List<int> pesos) {
      // Un recibo por mes terminando en noviembre de 2026.
      final fin = pesos.length;
      return [
        for (var i = 0; i < fin; i++)
          g(
            Fecha.enMes(2026, 11 - (fin - 1 - i), 3),
            pesos[i] * 100,
            'agua',
            comercio: 'Agua Municipal',
            auto: true,
          ),
      ];
    }

    test('DF-23 servicio que se infla (V-C): 2 de los últimos 3 sobre la mediana + 25 %', () {
      final serie = [
        280,
        290,
        300,
        300,
        300,
        300,
        300,
        310,
        310,
        320,
        380,
        390,
      ];
      final r = analiza(aguaMensual(serie));
      final v = r.deTipo(TipoFuga.vampiro);
      expect(v, hasLength(1));
      expect(v.single.regla, 'VC');
      expect(v.single.marcas, contains(MarcaFuga.servicioDelHogar));

      // Con 370 y 390 solo uno supera el umbral de \$375: ninguna.
      final uno = analiza(
        aguaMensual([
          280,
          290,
          300,
          300,
          300,
          300,
          300,
          310,
          310,
          320,
          370,
          390,
        ]),
      );
      expect(uno.confirmadas, isEmpty);

      // Con 5 periodos de historia: sin dato.
      final pocos = analiza(aguaMensual([300, 300, 300, 380, 390]));
      expect(pocos.confirmadas, isEmpty);
      expect(pocos.todas.single.estado, EstadoFuga.sinDato);
    });

    test('DF-23 borde: exactamente 25 % sobre la mediana cuenta', () {
      // Mediana 300: umbral 375.00 exacto.
      final r = analiza(
        aguaMensual([
          300,
          300,
          300,
          300,
          300,
          300,
          300,
          300,
          300,
          300,
          375,
          375,
        ]),
      );
      expect(r.deTipo(TipoFuga.vampiro), hasLength(1));
      final menos = analiza(
        aguaMensual([
          300,
          300,
          300,
          300,
          300,
          300,
          300,
          300,
          300,
          300,
          374,
          375,
        ]),
      );
      expect(menos.confirmadas, isEmpty);
    });

    test('"es por la temporada" deja el servicio en vigilancia ese año', () {
      final serie = [
        280,
        290,
        300,
        300,
        300,
        300,
        300,
        310,
        310,
        320,
        380,
        390,
      ];
      final gastos = aguaMensual(serie);
      final clave = detectarPatrones(
        gastos,
        categorias: categorias,
      ).single.clave;
      final r = analiza(
        gastos,
        respuestas: [
          resp(
            clave,
            PreguntaFuga.temporada,
            RespuestaPersona.si,
            Fecha(2026, 11, 9),
          ),
        ],
      );
      expect(r.confirmadas, isEmpty);
      expect(r.todas.single.estado, EstadoFuga.enVigilancia);
      expect(r.todas.single.marcas, contains(MarcaFuga.porTemporada));
    });

    test('DF-24 un servicio nunca es fantasma ni zombie', () {
      final gastos = cobros('luz', 'CFE', cuatroMeses, [
        90000,
        90000,
        90000,
        90000,
      ]);
      final r = analiza(gastos);
      expect(r.deTipo(TipoFuga.fantasma), isEmpty);
      expect(r.deTipo(TipoFuga.zombie), isEmpty);
      expect(r.porReconocer, isEmpty);
      // Aun con "ya no me sirve" confirmado.
      final clave = detectarPatrones(gastos).single.clave;
      final z = analiza(
        gastos,
        respuestas: [
          resp(
            clave,
            PreguntaFuga.yaNoSirve,
            RespuestaPersona.si,
            Fecha(2026, 11, 9),
          ),
        ],
      );
      expect(z.deTipo(TipoFuga.zombie), isEmpty);
      // Solo la regla V-C lo puede volver vampiro.
      final infla = analiza(
        aguaMensual([
          300,
          300,
          300,
          300,
          300,
          300,
          300,
          300,
          300,
          300,
          400,
          400,
        ]),
      );
      expect(infla.deTipo(TipoFuga.vampiro).single.regla, 'VC');
    });

    test('DF-25 intereses por pagar solo el mínimo (V-D): basta un corte', () {
      final solo = analiza(
        [],
        cortes: [
          CorteDeTarjeta(
            estado: estado('a', Fecha(2026, 11, 10), intereses: 41000),
            pagosCicloAnteriorCentavos: 30000,
          ),
        ],
      );
      final v = solo.deTipo(TipoFuga.vampiro).single;
      expect(v.regla, 'VD');
      expect(v.marcas, contains(MarcaFuga.porPagarSoloElMinimo));

      final total = analiza(
        [],
        cortes: [
          CorteDeTarjeta(
            estado: estado('a', Fecha(2026, 11, 10), intereses: 41000),
            pagosCicloAnteriorCentavos: 300000,
          ),
        ],
      );
      expect(total.confirmadas, isEmpty);
    });

    test('DF-25 bis: con el estado anterior capturado se usa su pago', () {
      final r = analiza(
        [],
        cortes: [
          CorteDeTarjeta(
            estado: estado('a', Fecha(2026, 10, 10)),
            pagosAlCorteCentavos: 30000, // solo el mínimo
          ),
          CorteDeTarjeta(
            estado: estado('b', Fecha(2026, 11, 10), intereses: 41000),
          ),
        ],
      );
      expect(
        r.deTipo(TipoFuga.vampiro).single.marcas,
        contains(MarcaFuga.porPagarSoloElMinimo),
      );
    });

    test('un mismo corte capturado dos veces vale el más reciente', () {
      final viejo = CorteDeTarjeta(
        estado: estado('v', Fecha(2026, 11, 10), intereses: 5),
      );
      final nuevo = CorteDeTarjeta(
        estado: EstadoDeCuenta(
          id: 'n',
          libroId: 'L',
          deudaId: 'tc',
          fechaCorte: Fecha(2026, 11, 10),
          fechaLimitePago: Fecha(2026, 11, 30),
          saldoAlCorte: 1,
          pagoMinimo: 1,
          pagoSinIntereses: 1,
          registradoEn: DateTime(2026, 11, 20),
        ),
      );
      final v = cortesVigentes([viejo, nuevo], 'tc');
      expect(v, hasLength(1));
      expect(v.single.estado.id, 'n');
    });
  });

  group('Zombie', () {
    List<GastoFuga> gym() => cobros('gimnasio', 'Gimnasio Sol', cuatroMeses, [
      45000,
      45000,
      45000,
      45000,
    ]);
    const claveGym = 'gimnasio sol|gimnasio';
    final conoce = resp(
      claveGym,
      PreguntaFuga.reconoce,
      RespuestaPersona.si,
      Fecha(2026, 10, 5),
    );

    test('DF-14 por respuesta: dos "No lo usé" seguidas; \$5,400 al año', () {
      final r = analiza(
        gym(),
        respuestas: [
          conoce,
          resp(
            claveGym,
            PreguntaFuga.uso,
            RespuestaPersona.no,
            Fecha(2026, 10, 12),
          ),
          resp(
            claveGym,
            PreguntaFuga.uso,
            RespuestaPersona.no,
            Fecha(2026, 11, 9),
          ),
        ],
      );
      final z = r.deTipo(TipoFuga.zombie).single;
      expect(z.regla, 'Z1');
      expect(z.anualCentavos, 540000);
      expect(z.semanalCentavos, 10385); // DF-21
    });

    test(
      'una sola "No lo usé" no basta; un "Lo usé" en medio rompe la racha',
      () {
        expect(
          analiza(
            gym(),
            respuestas: [
              conoce,
              resp(
                claveGym,
                PreguntaFuga.uso,
                RespuestaPersona.no,
                Fecha(2026, 11, 9),
              ),
            ],
          ).deTipo(TipoFuga.zombie),
          isEmpty,
        );
        expect(
          analiza(
            gym(),
            respuestas: [
              conoce,
              resp(
                claveGym,
                PreguntaFuga.uso,
                RespuestaPersona.no,
                Fecha(2026, 9, 14),
              ),
              resp(
                claveGym,
                PreguntaFuga.uso,
                RespuestaPersona.si,
                Fecha(2026, 10, 12),
              ),
              resp(
                claveGym,
                PreguntaFuga.uso,
                RespuestaPersona.no,
                Fecha(2026, 11, 9),
              ),
            ],
          ).deTipo(TipoFuga.zombie),
          isEmpty,
        );
      },
    );

    test('un "Después" no cuenta ni a favor ni en contra', () {
      final r = analiza(
        gym(),
        respuestas: [
          conoce,
          resp(
            claveGym,
            PreguntaFuga.uso,
            RespuestaPersona.no,
            Fecha(2026, 9, 14),
          ),
          resp(
            claveGym,
            PreguntaFuga.uso,
            RespuestaPersona.despues,
            Fecha(2026, 10, 12),
          ),
          resp(
            claveGym,
            PreguntaFuga.uso,
            RespuestaPersona.no,
            Fecha(2026, 11, 9),
          ),
        ],
      );
      expect(r.deTipo(TipoFuga.zombie), hasLength(1));
    });

    test('una respuesta corregida con reemplaza_a deja de contar', () {
      final r = analiza(
        gym(),
        respuestas: [
          conoce,
          resp(
            claveGym,
            PreguntaFuga.uso,
            RespuestaPersona.no,
            Fecha(2026, 10, 12),
            id: 'u1',
          ),
          resp(
            claveGym,
            PreguntaFuga.uso,
            RespuestaPersona.no,
            Fecha(2026, 11, 9),
            id: 'u2',
          ),
          resp(
            claveGym,
            PreguntaFuga.uso,
            RespuestaPersona.si,
            Fecha(2026, 11, 9),
            id: 'u3',
            reemplazaA: 'u2',
          ),
        ],
      );
      expect(r.deTipo(TipoFuga.zombie), isEmpty);
      expect(
        respuestasVigentes([
          resp(
            'x',
            PreguntaFuga.uso,
            RespuestaPersona.no,
            Fecha(2026, 10, 12),
            id: 'a',
          ),
          resp(
            'x',
            PreguntaFuga.uso,
            RespuestaPersona.si,
            Fecha(2026, 10, 12),
            id: 'b',
            reemplazaA: 'a',
          ),
        ]).map((e) => e.id),
        ['b'],
      );
    });

    test('DF-15 "ya no me sirve" una sola vez: zombie', () {
      final r = analiza(
        gym(),
        respuestas: [
          conoce,
          resp(
            claveGym,
            PreguntaFuga.yaNoSirve,
            RespuestaPersona.si,
            Fecha(2026, 11, 9),
          ),
        ],
      );
      expect(r.deTipo(TipoFuga.zombie).single.regla, 'Z1');
    });

    test('DF-16 duplicado: la app propone, la persona confirma', () {
      final gastos = [
        ...cobros('seguros', 'Seguro Celular Alfa', tresMeses, [
          8900,
          8900,
          8900,
        ]),
        ...cobros('seguros', 'Seguro Celular Beta', tresMeses, [
          9900,
          9900,
          9900,
        ]),
      ];
      const a = 'seguro celular alfa|seguros';
      const b = 'seguro celular beta|seguros';
      final base = [
        resp(a, PreguntaFuga.reconoce, RespuestaPersona.si, Fecha(2026, 10, 5)),
        resp(b, PreguntaFuga.reconoce, RespuestaPersona.si, Fecha(2026, 10, 5)),
      ];
      final r = analiza(gastos, respuestas: base);
      expect(r.deTipo(TipoFuga.zombie), isEmpty);
      expect(
        r.propuestas
            .where((p) => p.tipo == TipoPropuesta.duplicado)
            .map((p) => p.clave),
        unorderedEquals([a, b]),
      );
      final confirmado = analiza(
        gastos,
        respuestas: [
          ...base,
          resp(
            b,
            PreguntaFuga.duplicado,
            RespuestaPersona.si,
            Fecha(2026, 11, 9),
          ),
        ],
      );
      expect(confirmado.deTipo(TipoFuga.zombie).single.clave, b);
      expect(confirmado.deTipo(TipoFuga.zombie).single.regla, 'Z2');
    });

    test('Z3: mismo comercio en dos patrones: propone el más antiguo', () {
      final gastos = [
        ...cobros('streaming', 'Plataforma', cuatroMeses, [
          8900,
          8900,
          8900,
          8900,
        ]),
        ...cobros(
          'gimnasio',
          'Plataforma',
          tresMeses.map((f) => f.sumarDias(2)).toList(),
          [14900, 14900, 14900],
        ),
      ];
      final r = analiza(
        gastos,
        respuestas: [
          resp(
            'plataforma|streaming',
            PreguntaFuga.reconoce,
            RespuestaPersona.si,
            Fecha(2026, 10, 5),
          ),
          resp(
            'plataforma|gimnasio',
            PreguntaFuga.reconoce,
            RespuestaPersona.si,
            Fecha(2026, 10, 5),
          ),
        ],
      );
      final viejo = r.propuestas.where(
        (p) => p.tipo == TipoPropuesta.planViejo,
      );
      expect(viejo, hasLength(1));
      expect(r.deTipo(TipoFuga.zombie), isEmpty);
    });

    test('DF-27 "ya no existe": con confirmación es zombie; sin ella, solo propuesta', () {
      final gastos = cobros('seguros', 'Seguro Auto', tresMeses, [
        58000,
        58000,
        58000,
      ]);
      const clave = 'seguro auto|seguros';
      final conoceAuto = resp(
        clave,
        PreguntaFuga.reconoce,
        RespuestaPersona.si,
        Fecha(2026, 10, 5),
      );
      final propuesta = analiza(
        gastos,
        respuestas: [conoceAuto],
        declarados: [const PatronDeclarado(clave, bienYaNoExiste: true)],
      );
      expect(propuesta.deTipo(TipoFuga.zombie), isEmpty);
      expect(
        propuesta.propuestas.where((p) => p.tipo == TipoPropuesta.yaNoExiste),
        hasLength(1),
      );
      final confirmada = analiza(
        gastos,
        respuestas: [
          conoceAuto,
          resp(
            clave,
            PreguntaFuga.yaNoExiste,
            RespuestaPersona.si,
            Fecha(2026, 11, 9),
          ),
        ],
      );
      expect(confirmada.deTipo(TipoFuga.zombie).single.regla, 'Z5');
    });

    test('DF-26 folio de cancelación', () {
      expect(
        estadoCancelacion(canceladoEn: Fecha(2026, 11, 1), folio: 'ABC-123'),
        EstadoCancelacion.cancelado,
      );
      expect(
        estadoCancelacion(canceladoEn: Fecha(2026, 11, 1)),
        EstadoCancelacion.canceladoSinFolio,
      );
      expect(estadoCancelacion(), EstadoCancelacion.noCancelado);
      expect(() => validarFolio('ABC 123'), throwsArgumentError);
      expect(() => validarFolio('A' * 41), throwsArgumentError);
      expect(() => validarFolio('Á1'), throwsArgumentError);
      expect(() => validarFolio('A' * 40), returnsNormally);
      expect(
        () => estadoCancelacion(canceladoEn: Fecha(2026, 11, 1), folio: 'a b'),
        throwsArgumentError,
      );
    });
  });

  group('La persona gana, una sola fuga, anulación', () {
    final gastos = cobros('streaming', 'Plataforma', tresMeses, [
      8900,
      8900,
      8900,
    ]);
    final clave = detectarPatrones(gastos).single.clave;

    test('DF-18 "No es una fuga": protegido; un cambio de 10 % solo vuelve a preguntar', () {
      final d = DecisionFuga(
        id: 'd1',
        clave: clave,
        fuga: TipoFuga.ninguna,
        motivo: 'lo uso para trabajar',
        decididaEn: DateTime(2026, 10, 20),
        montoAlDecidir: 8900,
      );
      final r = analiza(gastos, decisiones: [d]);
      final f = r.de(clave)!;
      expect(f.fuga, TipoFuga.ninguna);
      expect(f.estado, EstadoFuga.protegida);
      expect(f.origen, OrigenFuga.persona);
      expect(f.requiereRevision, isFalse);
      expect(r.porReconocer, isEmpty);

      // Sube 10 % o más: no cambia la etiqueta, solo vuelve a preguntar.
      final sube = analiza(
        cobros('streaming', 'Plataforma', cuatroMeses, [
          8900,
          8900,
          8900,
          9790,
        ]),
        decisiones: [d],
      ).de(clave)!;
      expect(sube.fuga, TipoFuga.ninguna);
      expect(sube.estado, EstadoFuga.protegida);
      expect(sube.requiereRevision, isTrue);
      // 9.99 % no es cambio material.
      final casi = analiza(
        cobros('streaming', 'Plataforma', cuatroMeses, [
          8900,
          8900,
          8900,
          9789,
        ]),
        decisiones: [d],
      ).de(clave)!;
      expect(casi.requiereRevision, isFalse);
    });

    test('pasan 12 meses: vuelve a preguntar sin cambiar la etiqueta', () {
      final d = DecisionFuga(
        id: 'd1',
        clave: clave,
        fuga: TipoFuga.ninguna,
        motivo: 'lo uso para trabajar',
        decididaEn: DateTime(2025, 11, 16),
      );
      final f = analiza(gastos, decisiones: [d]).de(clave)!;
      expect(f.requiereRevision, isTrue);
      expect(f.fuga, TipoFuga.ninguna);
    });

    test(
      '"Es de otro tipo" y "Vigilar" (a los 3 meses vuelve a preguntar)',
      () {
        final otro = analiza(
          gastos,
          decisiones: [
            DecisionFuga(
              id: 'd1',
              clave: clave,
              fuga: TipoFuga.zombie,
              motivo: 'ya no lo uso',
              decididaEn: DateTime(2026, 11, 1),
            ),
          ],
        );
        expect(otro.deTipo(TipoFuga.zombie).single.origen, OrigenFuga.persona);

        final vigila = DecisionFuga(
          id: 'd2',
          clave: clave,
          fuga: TipoFuga.ninguna,
          vigilar: true,
          decididaEn: DateTime(2026, 8, 1),
        );
        final f = analiza(gastos, decisiones: [vigila]).de(clave)!;
        expect(f.estado, EstadoFuga.enVigilancia);
        expect(f.requiereRevision, isTrue);
      },
    );

    test('la decisión más reciente reemplaza a la anterior', () {
      final r = analiza(
        gastos,
        decisiones: [
          DecisionFuga(
            id: 'a',
            clave: clave,
            fuga: TipoFuga.ninguna,
            motivo: 'uno',
            decididaEn: DateTime(2026, 10, 1),
          ),
          DecisionFuga(
            id: 'b',
            clave: clave,
            fuga: TipoFuga.zombie,
            reemplazaA: 'a',
            motivo: 'dos',
            decididaEn: DateTime(2026, 11, 1),
          ),
        ],
      );
      expect(r.deTipo(TipoFuga.zombie), hasLength(1));
    });

    test('motivo obligatorio si la decisión contradice la regla (3 a 200)', () {
      final d = DecisionFuga(
        id: 'd',
        clave: clave,
        fuga: TipoFuga.ninguna,
        decididaEn: DateTime(2026, 11, 1),
      );
      expect(decisionContradice(d, TipoFuga.fantasma), isTrue);
      expect(decisionContradice(d, TipoFuga.ninguna), isFalse);
      expect(
        () => validarMotivoDecision(null, contradiceLaRegla: true),
        throwsArgumentError,
      );
      expect(
        () => validarMotivoDecision('ab', contradiceLaRegla: true),
        throwsArgumentError,
      );
      expect(
        () => validarMotivoDecision('x' * 201, contradiceLaRegla: true),
        throwsArgumentError,
      );
      expect(
        () => validarMotivoDecision('abc', contradiceLaRegla: true),
        returnsNormally,
      );
      expect(
        () => validarMotivoDecision(null, contradiceLaRegla: false),
        returnsNormally,
      );
      expect(
        () => validarMotivoDecision('x' * 201, contradiceLaRegla: false),
        throwsArgumentError,
      );
    });

    test('DF-12 anular con contraasiento: 3 de 10 gastos dejan 7 y ya no es hormiga', () {
      final movs = <Movimiento>[];
      final fechas = [
        for (var i = 0; i < 10; i++)
          Fecha(2026, 10, 19).sumarDias((i % 4) * 7 + (i ~/ 4) % 7),
      ];
      for (var i = 0; i < 10; i++) {
        movs.add(
          Movimiento(
            id: 'm$i',
            tipo: TipoMovimiento.gasto,
            fecha: fechas[i],
            registradoEn: DateTime(2026, 11, 1, 8, i),
            cuentaOrigenId: 'efectivo',
            cuentaDestinoId: 'cafe',
            monto: 4500,
            realizadoPor: 'ana',
            categoriaId: 'cafe',
          ),
        );
      }
      ResultadoFugas analizaMovs(List<Movimiento> m) => analizarFugas(
        EntradaFugas(
          hoy: hoy,
          ingresoSemanalCentavos: 500000,
          gastos: gastosVigentesParaFugas(m),
          categorias: categorias,
        ),
      );
      expect(analizaMovs(movs).deTipo(TipoFuga.hormiga), hasLength(1));

      final anulaciones = [
        for (var i = 0; i < 3; i++)
          Movimiento(
            id: 'a$i',
            tipo: TipoMovimiento.anulacion,
            fecha: Fecha(2026, 11, 2),
            registradoEn: DateTime(2026, 11, 2, 8, i),
            cuentaOrigenId: 'cafe',
            cuentaDestinoId: 'efectivo',
            monto: 4500,
            realizadoPor: 'ana',
            categoriaId: 'cafe',
            anulaA: 'm$i',
            motivo: 'duplicado',
          ),
      ];
      final todos = [...movs, ...anulaciones];
      expect(gastosVigentesParaFugas(todos), hasLength(7));
      expect(analizaMovs(todos).deTipo(TipoFuga.hormiga), isEmpty);
      // El libro conserva los 10 gastos y las 3 anulaciones.
      expect(todos, hasLength(13));
    });

    test('los movimientos importados cuentan como cobro automático', () {
      final m = Movimiento(
        id: 'i1',
        tipo: TipoMovimiento.gasto,
        fecha: Fecha(2026, 10, 5),
        registradoEn: DateTime(2026, 10, 5),
        cuentaOrigenId: 'tc',
        cuentaDestinoId: 'streaming',
        monto: 8900,
        realizadoPor: 'ana',
        categoriaId: 'streaming',
        via: ViaCaptura.importacion,
      );
      final v = gastosVigentesParaFugas([m], comercios: {'i1': 'Netflix'});
      expect(v.single.cobroAutomatico, isTrue);
      expect(v.single.comercio, 'Netflix');
      // Un pago de deuda o un ingreso nunca son fuga.
      expect(
        gastosVigentesParaFugas([
          Movimiento(
            id: 'p',
            tipo: TipoMovimiento.pagoDeuda,
            fecha: Fecha(2026, 10, 5),
            registradoEn: DateTime(2026, 10, 5),
            cuentaOrigenId: 'banco',
            cuentaDestinoId: 'tc',
            monto: 1000,
            realizadoPor: 'ana',
          ),
        ]),
        isEmpty,
      );
    });

    test(
      'DF-19 una sola fuga: ningún gasto en dos fugas ni más que el total',
      () {
        final gastos = [
          ...repartidos(10, 4500, 'cafe'),
          ...cobros('streaming', 'Plataforma', cuatroMeses, [
            8900,
            8900,
            8900,
            8900,
          ]),
          ...cobros('gimnasio', 'Gimnasio Sol', cuatroMeses, [
            45000,
            45000,
            45000,
            45000,
          ]),
          ...cobros('streaming', 'Netflix', cuatroMeses, [
            19900,
            19900,
            19900,
            21900,
          ]),
          g(Fecha(2026, 11, 12), 90000, 'despensa'),
        ];
        final r = analiza(
          gastos,
          respuestas: [
            resp(
              'plataforma|streaming',
              PreguntaFuga.reconoce,
              RespuestaPersona.no,
              Fecha(2026, 11, 9),
            ),
            resp(
              'gimnasio sol|gimnasio',
              PreguntaFuga.reconoce,
              RespuestaPersona.si,
              Fecha(2026, 11, 9),
            ),
            resp(
              'gimnasio sol|gimnasio',
              PreguntaFuga.yaNoSirve,
              RespuestaPersona.si,
              Fecha(2026, 11, 9),
            ),
            resp(
              'netflix|streaming',
              PreguntaFuga.reconoce,
              RespuestaPersona.si,
              Fecha(2026, 11, 9),
            ),
          ],
        );
        expect(r.deTipo(TipoFuga.fantasma), hasLength(1));
        expect(r.deTipo(TipoFuga.zombie), hasLength(1));
        expect(r.deTipo(TipoFuga.vampiro), hasLength(1));
        expect(r.deTipo(TipoFuga.hormiga), hasLength(1));

        final ids = r.gastoIdsEnFugas;
        expect(ids.toSet().length, ids.length, reason: 'un gasto en dos fugas');
        final porId = {for (final x in gastos) x.id: x.monto};
        final enFugas = ids.fold<int>(0, (a, id) => a + porId[id]!);
        final total = gastos.fold<int>(0, (a, x) => a + x.monto);
        expect(enFugas, lessThanOrEqualTo(total));
      },
    );
  });

  group('Preguntas de la revisión mensual (D25)', () {
    test('máximo 7 por revisión y "Después" no repite en el mes', () {
      final gastos = [
        for (var i = 0; i < 9; i++)
          ...cobros('streaming', 'Servicio $i', tresMeses, [8900, 8900, 8900]),
      ];
      final entrada = EntradaFugas(
        hoy: hoy,
        ingresoSemanalCentavos: 500000,
        gastos: gastos,
        categorias: categorias,
      );
      final r = analizarFugas(entrada);
      expect(r.porReconocer, hasLength(9));
      expect(preguntasDeRevision(r, entrada), hasLength(7));

      final claves = r.porReconocer.map((f) => f.clave).toList();
      final conDespues = EntradaFugas(
        hoy: hoy,
        ingresoSemanalCentavos: 500000,
        gastos: gastos,
        categorias: categorias,
        respuestas: [
          resp(
            claves.first,
            PreguntaFuga.reconoce,
            RespuestaPersona.despues,
            Fecha(2026, 11, 9),
          ),
        ],
      );
      final q = preguntasDeRevision(analizarFugas(conDespues), conDespues);
      expect(q.map((p) => p.clave), isNot(contains(claves.first)));
    });

    test('uso: una pregunta por patrón reconocido y no antes de 30 días', () {
      final gastos = cobros('gimnasio', 'Gimnasio Sol', cuatroMeses, [
        45000,
        45000,
        45000,
        45000,
      ]);
      const clave = 'gimnasio sol|gimnasio';
      EntradaFugas con(List<RespuestaFuga> rs) => EntradaFugas(
        hoy: hoy,
        ingresoSemanalCentavos: 500000,
        gastos: gastos,
        categorias: categorias,
        respuestas: rs,
      );
      final conoce = resp(
        clave,
        PreguntaFuga.reconoce,
        RespuestaPersona.si,
        Fecha(2026, 9, 7),
      );
      var e = con([conoce]);
      expect(
        preguntasDeRevision(analizarFugas(e), e).single.tipo,
        TipoPregunta.uso,
      );
      e = con([
        conoce,
        resp(clave, PreguntaFuga.uso, RespuestaPersona.si, Fecha(2026, 11, 2)),
      ]);
      expect(preguntasDeRevision(analizarFugas(e), e), isEmpty);
      e = con([
        conoce,
        resp(clave, PreguntaFuga.uso, RespuestaPersona.si, Fecha(2026, 10, 12)),
      ]);
      expect(preguntasDeRevision(analizarFugas(e), e), hasLength(1));
    });

    test('anual: se pregunta 30 días antes del cobro esperado', () {
      final anuales = cobros(
        'seguros',
        'Antivirus',
        [Fecha(2023, 12, 20), Fecha(2024, 12, 20), Fecha(2025, 12, 20)],
        [79900, 79900, 79900],
      );
      const clave = 'antivirus|seguros';
      EntradaFugas en(Fecha h) => EntradaFugas(
        hoy: h,
        ingresoSemanalCentavos: 500000,
        gastos: anuales,
        categorias: categorias,
        respuestas: [
          resp(
            clave,
            PreguntaFuga.reconoce,
            RespuestaPersona.si,
            Fecha(2026, 1, 5),
          ),
        ],
      );
      // Esperado hacia el 20/dic/2026 (365 días tras el último).
      final cerca = en(Fecha(2026, 11, 30)); // faltan ~20 días
      expect(preguntasDeRevision(analizarFugas(cerca), cerca), hasLength(1));
      final lejos = en(Fecha(2026, 9, 7));
      expect(preguntasDeRevision(analizarFugas(lejos), lejos), isEmpty);
    });
  });

  group('Equivalentes (DF-21) y parámetros', () {
    test(
      'DF-21 \$450 al mes = \$103.85 a la semana y los renglones suman exacto',
      () {
        expect(Equivalente.de(45000, Frecuencia.mensual).semanal, 10385);
        final renglones = [
          Equivalente.de(45000, Frecuencia.mensual),
          Equivalente.de(8900, Frecuencia.mensual),
          Equivalente.de(19900, Frecuencia.mensual),
        ];
        final partes = semanalesQueSuman(renglones);
        expect(
          partes.fold<int>(0, (a, b) => a + b),
          Equivalente.suma(renglones).semanal,
        );
      },
    );

    test('los umbrales se editan por libro sin tocar el código', () {
      const estricto = ParametrosFugas(
        topeHormigaCentavos: 4000,
        hormigaMinGastos: 5,
      );
      final gastos = repartidos(6, 4500, 'cafe');
      final porDefecto = analiza(gastos);
      expect(porDefecto.deTipo(TipoFuga.hormiga), isEmpty); // 6 < 8
      final propio = analizarFugas(
        EntradaFugas(
          hoy: hoy,
          ingresoSemanalCentavos: 500000,
          gastos: gastos,
          categorias: categorias,
          parametros: const ParametrosFugas(hormigaMinGastos: 5),
        ),
      );
      expect(propio.deTipo(TipoFuga.hormiga), hasLength(1));
      final tope = analizarFugas(
        EntradaFugas(
          hoy: hoy,
          ingresoSemanalCentavos: 500000,
          gastos: gastos,
          categorias: categorias,
          parametros: estricto,
        ),
      );
      expect(tope.deTipo(TipoFuga.hormiga), isEmpty); // 45 > 40
    });

    test('ingresoMensualDeReferencia = semanal x 52 / 12 con R1', () {
      expect(ingresoMensualDeReferencia(500000), 2166667);
      expect(ingresoMensualDeReferencia(2500000), 10833333);
    });

    test('totales por fuga: semanal sale del anual exacto', () {
      final r = analiza(
        [
          ...cobros('gimnasio', 'Gimnasio Sol', cuatroMeses, [
            45000,
            45000,
            45000,
            45000,
          ]),
        ],
        respuestas: [
          resp(
            'gimnasio sol|gimnasio',
            PreguntaFuga.reconoce,
            RespuestaPersona.si,
            Fecha(2026, 11, 9),
          ),
          resp(
            'gimnasio sol|gimnasio',
            PreguntaFuga.yaNoSirve,
            RespuestaPersona.si,
            Fecha(2026, 11, 9),
          ),
        ],
      );
      final t = r.total(TipoFuga.zombie);
      expect(t.elementos, 1);
      expect(t.anualCentavos, 540000);
      expect(t.semanalCentavos, 10385);
    });
  });
}
