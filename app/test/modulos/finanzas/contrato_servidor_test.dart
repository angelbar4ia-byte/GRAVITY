// Contrato con el servidor (supabase/README.md, "Contrato para la app"):
// columnas que se mandan y columnas que pone el servidor, libros y cuentas de
// gasto del hogar, miembros con timestamptz, cierre antes de cerrar la semana
// con versión = reaperturas + 1, RPC de papá y de la cuenta maestra.
import 'dart:convert';

import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/finanzas/casos_uso/servicio_finanzas.dart'
    show LineaGasto;
import 'package:gravity/modulos/finanzas/datos/filas.dart';
import 'package:gravity/modulos/finanzas/datos/fuente_tablas.dart';
import 'package:gravity/modulos/finanzas/datos/ids.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_supabase.dart';
import 'package:gravity/modulos/finanzas/finanzas.dart' show tablasColaFinanzas;
import 'package:gravity/nucleo/base_local/base_local.dart';
import 'package:gravity/nucleo/cola/cola_sin_conexion.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';

import 'ayuda_finanzas.dart';

/// Fuente que recuerda el orden de las operaciones.
class FuenteConBitacora implements FuenteTablas {
  FuenteConBitacora(this.base);

  final FuenteTablasEnMemoria base;
  final List<String> operaciones = [];

  @override
  Future<List<Map<String, dynamic>>> leer(
    String tabla, {
    String columnas = '*',
  }) => base.leer(tabla, columnas: columnas);

  @override
  Future<void> guardar(
    String tabla,
    List<Map<String, Object?>> filas, {
    String conflicto = 'id',
    bool ignorarDuplicados = false,
  }) {
    operaciones.add('guardar:$tabla');
    return base.guardar(
      tabla,
      filas,
      conflicto: conflicto,
      ignorarDuplicados: ignorarDuplicados,
    );
  }

  @override
  Future<void> actualizar(
    String tabla,
    Map<String, Object?> cambios, {
    required Map<String, Object?> donde,
  }) {
    operaciones.add('actualizar:$tabla');
    return base.actualizar(tabla, cambios, donde: donde);
  }

  @override
  Future<void> borrar(String tabla, {required Map<String, Object?> donde}) {
    operaciones.add('borrar:$tabla');
    return base.borrar(tabla, donde: donde);
  }

  @override
  Future<Object?> rpc(String funcion, Map<String, Object?> parametros) {
    operaciones.add('rpc:$funcion');
    return base.rpc(funcion, parametros);
  }
}

class EnviadorGuarda implements Enviador {
  final Map<String, PeticionEnvio> enviados = {};

  @override
  Future<ResultadoEnvio> enviar(PeticionEnvio peticion) async {
    enviados.putIfAbsent(peticion.id, () => peticion);
    return ResultadoEnvio.enviado;
  }
}

/// Siembra la fuente con las filas que mandaría la app (así también se prueba
/// la ida y vuelta de cada fila).
void sembrar(
  FuenteTablasEnMemoria f,
  DatosFinanzas d, {
  required String hogar,
}) {
  var n = 0;
  String id() => '00000000-0000-4000-a000-${(++n).toString().padLeft(12, '0')}';
  for (final l in d.libros) {
    f.tabla(TablasFinanzas.libros).add(filaLibro(l, hogarId: hogar));
    for (final m in l.miembros) {
      f
          .tabla(TablasFinanzas.miembros)
          .add(filaMiembro(l.id, m, hogarId: hogar, id: id()));
    }
  }
  for (final p in d.parametros) {
    f.tabla(TablasFinanzas.parametros).add(filaParametros(p, hogarId: hogar));
  }
  for (final c in d.cuentas) {
    f.tabla(TablasFinanzas.cuentas).add(filaCuenta(c, hogarId: hogar));
  }
  for (final c in d.categorias) {
    f.tabla(TablasFinanzas.categorias).add(filaCategoria(c, hogarId: hogar));
  }
  for (final i in d.ingresos) {
    f.tabla(TablasFinanzas.ingresos).add(filaIngreso(i, hogarId: hogar));
    for (final v in i.vigencias) {
      f
          .tabla(TablasFinanzas.vigencias)
          .add(filaVigencia(v, hogarId: hogar, libroId: i.libroId));
    }
  }
  for (final c in d.compromisos) {
    f.tabla(TablasFinanzas.compromisos).add(filaCompromiso(c, hogarId: hogar));
  }
  for (final s in d.sobres) {
    f.tabla(TablasFinanzas.sobres).add(filaSobre(s, hogarId: hogar));
  }
  for (final x in d.deudas) {
    f.tabla(TablasFinanzas.deudas).add(filaDeuda(x, hogarId: hogar));
  }
  for (final s in d.semanas) {
    f.tabla(TablasFinanzas.semanas).add(filaSemana(s, hogarId: hogar));
    for (final p in s.partidas) {
      f
          .tabla(TablasFinanzas.partidasSemana)
          .add(filaPartidaSemana(p, hogarId: hogar, libroId: s.libroId));
    }
    for (final a in s.abonos) {
      f
          .tabla(TablasFinanzas.abonosSemana)
          .add(filaAbonoSemana(a, hogarId: hogar, libroId: s.libroId));
    }
  }
  for (final m in d.movimientos) {
    f.tabla(TablasFinanzas.movimientos).add(filaMovimiento(m, hogarId: hogar));
  }
  f.tabla('personas').addAll([
    {'id': IdsDemostracion.dueno, 'nombre_visible': 'Dueño de ejemplo'},
    {'id': IdsDemostracion.pareja, 'nombre_visible': 'Pareja de ejemplo'},
  ]);
  f.tabla('membresias').addAll([
    for (final p in [IdsDemostracion.dueno, IdsDemostracion.pareja])
      {
        'hogar_id': hogar,
        'persona_id': p,
        'rol': p == IdsDemostracion.dueno ? 'dueno' : 'coadministrador',
        'activa': true,
      },
  ]);
}

void main() {
  const hogar = '00000000-0000-4000-8000-0000000000aa';
  const libroCasa = IdsDemostracion.libroCasa;
  final dueno = sesionDe(Rol.dueno);
  final semana = Semana.de(hoyDePrueba);
  late FuenteTablasEnMemoria memoria;
  late FuenteConBitacora fuente;
  late BaseLocal base;
  late EnviadorGuarda enviador;
  late ColaSinConexion cola;
  late RepositorioFinanzasSupabase repo;
  late DatosFinanzas demo;

  setUp(() {
    demo = datosDeDemostracion(hoy: hoyDePrueba);
    memoria = FuenteTablasEnMemoria();
    fuente = FuenteConBitacora(memoria);
    sembrar(memoria, demo, hogar: hogar);
    base = BaseLocal.enMemoria();
    enviador = EnviadorGuarda();
    cola = ColaSinConexion(base: base, enviador: enviador);
    repo = RepositorioFinanzasSupabase(
      fuente: fuente,
      cola: cola,
      hogarId: hogar,
      personaId: dueno.persona.id,
      esperaSubida: const Duration(seconds: 2),
    );
    addTearDown(base.close);
    addTearDown(repo.cerrar);
  });

  test(
    'la cola de Finanzas sube a sus tablas (solo los libros solo agregar)',
    () {
      expect(tablasColaFinanzas, {
        'finanzas.movimiento': 'fin_movimientos',
        'finanzas.conciliacion': 'fin_conciliaciones',
        'finanzas.importacion': 'fin_importaciones',
      });
    },
  );

  group('Ida y vuelta de las filas', () {
    test('cargar arma los mismos datos que se sembraron', () async {
      final carga = await repo.cargar();
      final d = carga.datos;
      expect(
        d.libros.map((l) => l.id).toSet(),
        demo.libros.map((l) => l.id).toSet(),
      );
      expect(d.cuentas, hasLength(demo.cuentas.length));
      expect(d.movimientos, hasLength(demo.movimientos.length));
      expect(d.ingresos, hasLength(demo.ingresos.length));
      expect(d.semanas, hasLength(1));
      expect(
        d.semanas.single.partidas,
        hasLength(demo.semanas.single.partidas.length),
      );
      expect(d.semanas.single.reaperturas, 0);
      expect(carga.adultosConFinanzas, adultosDeEjemplo);
      expect(carga.personas[IdsDemostracion.dueno], 'Dueño de ejemplo');
    });

    test(
      'los ingresos de papá conservan sus formas: días 1 y 11 y cada 2 meses',
      () async {
        final d = (await repo.cargar()).datos;
        final pension = d.ingresos.firstWhere(
          (i) => i.nombre.startsWith('Pensión'),
        );
        final apoyo = d.ingresos.firstWhere(
          (i) => i.nombre.startsWith('Apoyo'),
        );
        expect(pension.vigenciaActual!.calendario.diasMes, [1, 11]);
        expect(pension.vigenciaActual!.calendario.forma, FormaPago.mensual);
        expect(apoyo.vigenciaActual!.calendario.forma, FormaPago.cadaMeses);
        expect(apoyo.vigenciaActual!.calendario.intervaloMeses, 2);
        expect(apoyo.certeza, Certeza.probable);
      },
    );

    test(
      'los miembros del libro de papá: albacea y suplente vigentes',
      () async {
        final d = (await repo.cargar()).datos;
        final papa = d.libro(IdsDemostracion.libroPapa)!;
        expect(
          papa.papelDe(IdsDemostracion.dueno, hoyDePrueba),
          PapelLibro.albacea,
        );
        expect(
          papa.papelDe(IdsDemostracion.pareja, hoyDePrueba),
          PapelLibro.albaceaSuplente,
        );
      },
    );
  });

  group('Movimientos por la cola', () {
    test('mandan registrado_en y no mandan lo que pone el servidor', () async {
      await repo.cargar();
      final servicio = servicioDe(repo, dueno);
      final r = await servicio.registrarGasto(
        libroId: IdsDemostracion.libroDueno,
        cuentaOrigenId:
            memoria
                    .tabla(TablasFinanzas.cuentas)
                    .firstWhere((c) => c['nombre'] == 'Mi efectivo')['id']!
                as String,
        lineas: const [LineaGasto(monto: 12550)],
      );
      expect(r.enCola, isFalse, reason: 'con señal sube de inmediato');
      final enviada = enviador.enviados[r.movimientos.single.id]!;
      final fila = enviada.carga;
      for (final prohibida in [
        'recibido_en',
        'libro_origen_id',
        'libro_destino_id',
        'clase',
        'liquida',
      ]) {
        expect(fila.containsKey(prohibida), isFalse, reason: prohibida);
      }
      expect(fila['registrado_en'], isNotNull);
      expect(DateTime.parse('${fila['registrado_en']}').isUtc, isTrue);
      expect(fila['monto_centavos'], 12550);
      expect(fila['hogar_id'], hogar);
      expect(() => jsonEncode(fila), returnsNormally);
    });
  });

  group('Cuentas', () {
    test('solo las de gasto van sin libro', () {
      for (final c in demo.cuentas) {
        final fila = filaCuenta(c, hogarId: hogar);
        final delHogar =
            c.tipo == TipoCuenta.deGasto ||
            c.tipo == TipoCuenta.gastoFinanciero;
        expect(fila['libro_id'] == null, delHogar, reason: c.nombre);
        expect(fila.containsKey('clase'), isFalse);
        expect(fila.containsKey('liquida'), isFalse);
      }
    });

    test(
      'una cuenta de banco sin libro o una de gasto con libro no se manda',
      () {
        expect(
          () => filaCuenta(
            const Cuenta(id: 'x', nombre: 'Banco', tipo: TipoCuenta.banco),
            hogarId: hogar,
          ),
          throwsArgumentError,
        );
        expect(
          () => filaCuenta(
            const Cuenta(
              id: 'y',
              nombre: 'Salud',
              tipo: TipoCuenta.deGasto,
              libroId: libroCasa,
            ),
            hogarId: hogar,
          ),
          throwsArgumentError,
        );
        expect(
          () => filaCuenta(
            Cuenta(
              id: idCuentaOtroLibro(libroCasa),
              nombre: 'Otro libro',
              tipo: TipoCuenta.otroLibro,
              libroId: libroCasa,
            ),
            hogarId: hogar,
          ),
          throwsArgumentError,
        );
      },
    );

    test(
      'guardarCuentas lo dice con un mensaje y no llama al servidor',
      () async {
        await repo.cargar();
        await expectLater(
          repo.guardarCuentas(const [
            Cuenta(id: 'z', nombre: 'Sin libro', tipo: TipoCuenta.efectivo),
          ]),
          throwsA(isA<ErrorFinanzas>()),
        );
        expect(
          fuente.operaciones.where((o) => o == 'guardar:fin_cuentas'),
          isEmpty,
        );
      },
    );
  });

  group('Miembros: desde y hasta son timestamptz', () {
    test(
      'una fecha se manda como hora ISO en UTC y se lee como fecha local',
      () {
        final fila = filaMiembro(
          libroCasa,
          MiembroLibro(
            personaId: IdsDemostracion.pareja,
            papel: PapelLibro.miembro,
            desde: Fecha(2026, 10, 1),
            hasta: Fecha(2026, 12, 31),
          ),
          hogarId: hogar,
          id: 'm1',
        );
        expect('${fila['desde']}', contains('T'));
        expect(DateTime.parse('${fila['desde']}').isUtc, isTrue);
        expect(DateTime.parse('${fila['hasta']}').isUtc, isTrue);
        final libro = libroDeFila(
          {
            'id': libroCasa,
            'nombre': 'Casa',
            'tipo': 'compartido',
            'activo': true,
          },
          [
            {
              'libro_id': libroCasa,
              'persona_id': IdsDemostracion.pareja,
              'papel': 'miembro',
              'desde': fila['desde'],
              'hasta': fila['hasta'],
            },
          ],
        );
        final m = libro.miembros.single;
        expect(m.desde, Fecha(2026, 10, 1));
        expect(m.hasta, Fecha(2026, 12, 31));
      },
    );

    test('sin desde no se manda: el servidor pone now()', () {
      final fila = filaMiembro(
        libroCasa,
        const MiembroLibro(personaId: 'p', papel: PapelLibro.miembro),
        hogarId: hogar,
        id: 'm2',
      );
      expect(fila.containsKey('desde'), isFalse);
      expect(fila['hasta'], isNull);
    });

    test('el libro compartido agrega a los demás con ids estables', () async {
      await repo.cargar();
      await repo.crearLibroCompartido(
        id: 'libro-nuevo',
        nombre: 'Vacaciones',
        otrosMiembros: [IdsDemostracion.pareja],
      );
      final fila = memoria
          .tabla(TablasFinanzas.miembros)
          .firstWhere((m) => m['libro_id'] == 'libro-nuevo');
      expect(
        fila['id'],
        idEstable(
          ClavesId.miembro('libro-nuevo', IdsDemostracion.pareja, 'miembro'),
        ),
      );
    });
  });

  group('Calendarios con su regla efectiva', () {
    test('un ingreso sin regla elegida manda siguiente_dia_habil; un '
        'compromiso o una deuda, sin_cambio', () {
      const sinElegir = CalendarioConfig.mensual([1, 11]);
      expect(
        filaCalendario(sinElegir, porOmision: CalendarioConfig.reglaDeIngreso),
        containsPair('regla_inhabil', 'siguiente_dia_habil'),
      );
      expect(
        filaCalendario(sinElegir, porOmision: CalendarioConfig.reglaDeSalida),
        containsPair('regla_inhabil', 'sin_cambio'),
      );
      expect(
        filaCalendario(
          CalendarioConfig.mensual([
            1,
          ], regla: ReglaDiaInhabil.siguienteDiaHabil),
          porOmision: CalendarioConfig.reglaDeSalida,
        ),
        containsPair('regla_inhabil', 'siguiente_dia_habil'),
        reason: 'la caja: la regla elegida manda',
      );
    });

    test(
      'varios días fijos viajan como lista y cada N meses con su intervalo',
      () {
        final fila = filaCalendario(
          const CalendarioConfig.mensual([1, 11]),
          porOmision: CalendarioConfig.reglaDeIngreso,
        );
        expect(fila['forma'], 'mensual');
        expect(fila['dias_mes'], [1, 11]);
        final cada = filaCalendario(
          CalendarioConfig.cadaMeses(Fecha(2026, 9, 1), 2),
          porOmision: CalendarioConfig.reglaDeIngreso,
        );
        expect(cada['forma'], 'cada_meses');
        expect(cada['intervalo_meses'], 2);
        expect(cada['fecha_ancla'], '2026-09-01');
        expect(cada['dias_mes'], isNull);
      },
    );
  });

  group('Parámetros', () {
    test('se cambian con UPDATE y sin las cuentas de sistema', () async {
      await repo.cargar();
      final p = ParametrosFinanzas(
        libroId: libroCasa,
        metaRemanentePuntosBase: 2500,
        cierreAutomaticoDias: 4,
      );
      await repo.guardarParametros(p);
      expect(fuente.operaciones, contains('actualizar:fin_parametros'));
      expect(fuente.operaciones, isNot(contains('guardar:fin_parametros')));
      final fila = memoria
          .tabla(TablasFinanzas.parametros)
          .firstWhere((f) => f['libro_id'] == libroCasa);
      expect(fila['meta_remanente_pb'], 2500);
      expect(fila['cierre_automatico_dias'], 4);
      expect(fila['cuenta_ajustes_id'], isNotNull, reason: 'no se tocó');
      expect(cambiosParametros(p).containsKey('cuenta_ajustes_id'), isFalse);
      expect(cambiosParametros(p).containsKey('libro_id'), isFalse);
    });
  });

  group('Cierre de la semana', () {
    test(
      'primero el cierre y sus renglones con id; después la semana a cerrada',
      () async {
        await repo.cargar();
        final g = demo.semanas.single;
        final servicio = servicioDe(repo, dueno);
        final cierre = await servicio.cerrarSemana(libroCasa, semana);
        expect(cierre.version, g.versionDelSiguienteCierre);
        final orden = fuente.operaciones
            .where((o) => o.contains('fin_c'))
            .toList();
        expect(orden, [
          'guardar:fin_cierres',
          'guardar:fin_cierre_partidas',
          'guardar:fin_cierre_abonos',
        ]);
        final iCierre = fuente.operaciones.indexOf('guardar:fin_cierres');
        final iSemana = fuente.operaciones.indexOf('actualizar:fin_semanas');
        expect(iCierre, lessThan(iSemana));
        final partidas = memoria.tabla(TablasFinanzas.cierrePartidas);
        expect(partidas, isNotEmpty);
        for (final p in partidas) {
          expect(p['id'], isNotNull, reason: 'fin_cierre_partidas lleva id');
          expect(p['libro_id'], libroCasa);
        }
        final abonos = memoria.tabla(TablasFinanzas.cierreAbonos);
        for (final a in abonos) {
          expect(a['id'], isNotNull, reason: 'fin_cierre_abonos lleva id');
          expect(a['libro_id'], libroCasa);
          expect(a.containsKey('diferido'), isFalse, reason: 'es generado');
        }
        expect(
          memoria
              .tabla(TablasFinanzas.semanas)
              .firstWhere((s) => s['id'] == g.id)['estado'],
          'cerrada',
        );
      },
    );

    test(
      'reintentar el cierre reusa los mismos ids de los renglones',
      () async {
        await repo.cargar();
        final servicio = servicioDe(repo, dueno);
        final cierre = await servicio.cerrarSemana(libroCasa, semana);
        final ids = [
          for (final p in memoria.tabla(TablasFinanzas.cierrePartidas)) p['id'],
        ];
        await repo.agregarCierre(cierre, libroId: libroCasa);
        final despues = [
          for (final p in memoria.tabla(TablasFinanzas.cierrePartidas)) p['id'],
        ];
        expect(despues, ids, reason: 'ignoreDuplicates: no se duplica');
      },
    );
  });

  group('RPC', () {
    test('el libro de papá se crea con la RPC y el suplente entra por '
        'fin_nombrar_albacea (el INSERT directo ya no pasa)', () async {
      await repo.cargar();
      await repo.crearLibroRepresentado(
        id: 'libro-papa-nuevo',
        nombreTitular: 'Papá (ejemplo)',
        nombreLibro: 'Libro de papá',
        suplenteId: IdsDemostracion.pareja,
      );
      final llamada = memoria.llamadas.firstWhere(
        (l) => l.$1 == 'fin_crear_libro_representado',
      );
      expect(llamada.$2, {
        'p_hogar_id': hogar,
        'p_nombre_titular': 'Papá (ejemplo)',
        'p_nombre_libro': 'Libro de papá',
        'p_libro_id': 'libro-papa-nuevo',
      });
      final nombrar = memoria.llamadas.singleWhere(
        (l) => l.$1 == 'fin_nombrar_albacea',
      );
      expect(nombrar.$2, {
        'p_libro_id': 'libro-papa-nuevo',
        'p_persona_id': IdsDemostracion.pareja,
        'p_papel': 'albacea_suplente',
      });
      expect(
        memoria
            .tabla(TablasFinanzas.miembros)
            .where((m) => m['libro_id'] == 'libro-papa-nuevo'),
        isEmpty,
        reason: 'la app no inserta en fin_libro_miembros para papá',
      );
    });

    test('nombrar albacea o suplente llama a la función con el cargo en '
        'snake_case', () async {
      await repo.cargar();
      await repo.nombrarAlbacea(
        libroId: IdsDemostracion.libroPapa,
        personaId: IdsDemostracion.pareja,
        papel: PapelLibro.albacea,
      );
      await repo.nombrarAlbacea(
        libroId: IdsDemostracion.libroPapa,
        personaId: IdsDemostracion.dueno,
        papel: PapelLibro.albaceaSuplente,
      );
      final llamadas = memoria.llamadas
          .where((l) => l.$1 == 'fin_nombrar_albacea')
          .toList();
      expect(llamadas.map((l) => l.$2['p_papel']), [
        'albacea',
        'albacea_suplente',
      ]);
      expect(llamadas.first.$2['p_libro_id'], IdsDemostracion.libroPapa);
      expect(
        llamadas.first.$2.keys,
        unorderedEquals(['p_libro_id', 'p_persona_id', 'p_papel']),
      );
    });

    test('un movimiento del libro de papá con motivo corto no entra a la cola '
        '(el servidor lo rechazaría con 23514)', () async {
      final carga = await repo.cargar();
      final banco = carga.datos
          .cuentasDe(IdsDemostracion.libroPapa)
          .firstWhere((c) => c.tipo == TipoCuenta.banco);
      final gasto = carga.datos.cuentas.firstWhere(
        (c) => c.tipo == TipoCuenta.deGasto,
      );
      Movimiento con(String motivo) => Movimiento(
        id: 'm-${motivo.length}',
        tipo: TipoMovimiento.gasto,
        fecha: hoyDePrueba,
        registradoEn: DateTime(2026, 10, 20, 10),
        cuentaOrigenId: banco.id,
        cuentaDestinoId: gasto.id,
        monto: 500,
        realizadoPor: IdsDemostracion.papa,
        registradoPor: dueno.persona.id,
        enNombreDe: IdsDemostracion.papa,
        motivo: motivo,
      );
      for (final corto in ['', '  ', 'ab', ' a \u200B b ']) {
        await expectLater(
          repo.agregarMovimientos([con(corto)]),
          throwsA(isA<ErrorFinanzas>()),
          reason: '"$corto"',
        );
      }
      expect(await cola.registros(), isEmpty);
      await repo.agregarMovimientos([con('Farmacia')]);
      expect((await cola.registros()).length, 1);
    });

    test(
      'la consulta de la cuenta maestra llama a fin_registrar_consulta_maestra',
      () async {
        await repo.registrarConsultaMaestra(IdsDemostracion.libroDueno);
        final llamada = memoria.llamadas.singleWhere(
          (l) => l.$1 == 'fin_registrar_consulta_maestra',
        );
        expect(llamada.$2, {'p_libro_id': IdsDemostracion.libroDueno});
      },
    );

    test('cargar lee quién es la cuenta maestra (cuenta_maestra)', () async {
      memoria.funciones['cuenta_maestra'] = (_) => [
        {'persona_id': 'x', 'nombre_visible': 'Cuenta maestra de ejemplo'},
      ];
      memoria.funciones['es_cuenta_maestra'] = (_) => false;
      final carga = await repo.cargar();
      expect(carga.cuentaMaestra, 'Cuenta maestra de ejemplo');
      expect(carga.esMaestra, isFalse);
    });

    test('sin cuenta maestra no hay nombre', () async {
      memoria.funciones['cuenta_maestra'] = (_) => <Object?>[];
      expect((await repo.cargar()).cuentaMaestra, isNull);
    });
  });

  group('Libros compartidos (respuestas del dueño del 23/oct/2026)', () {
    final ahora = DateTime.utc(2026, 10, 23, 15, 30);

    test('todos los libros mandan la visibilidad (privada por omisión)', () {
      for (final l in demo.libros) {
        expect(
          filaLibro(l, hogarId: hogar)['visibilidad'],
          'privada',
          reason: l.nombre,
        );
      }
      final publico = demo.libros
          .firstWhere((l) => l.id == libroCasa)
          .copiar(visibilidad: VisibilidadLibro.publica);
      expect(filaLibro(publico, hogarId: hogar)['visibilidad'], 'publica');
      // creado_por lo pone el servidor: no se manda.
      expect(
        filaLibro(publico, hogarId: hogar).containsKey('creado_por'),
        isFalse,
      );
    });

    test(
      'cargar lee la visibilidad y quién lo creó (el administrador)',
      () async {
        final fila = memoria
            .tabla(TablasFinanzas.libros)
            .firstWhere((l) => l['id'] == libroCasa);
        fila['visibilidad'] = 'publica';
        fila['creado_por'] = IdsDemostracion.dueno;
        final casa = (await repo.cargar()).datos.libro(libroCasa)!;
        expect(casa.visibilidad, VisibilidadLibro.publica);
        expect(casa.creadoPor, IdsDemostracion.dueno);
        expect(casa.esAdministrador(IdsDemostracion.dueno), isTrue);
        // Una fila vieja sin la columna se lee como privada.
        fila.remove('visibilidad');
        expect(
          (await repo.cargar()).datos.libro(libroCasa)!.visibilidad,
          VisibilidadLibro.privada,
        );
      },
    );

    test(
      'crear un compartido manda su visibilidad en el INSERT del libro',
      () async {
        await repo.cargar();
        await repo.crearLibroCompartido(
          id: 'libro-publico',
          nombre: 'Gastos abiertos',
          otrosMiembros: [IdsDemostracion.pareja],
          visibilidad: VisibilidadLibro.publica,
        );
        final fila = memoria
            .tabla(TablasFinanzas.libros)
            .firstWhere((l) => l['id'] == 'libro-publico');
        expect(fila['visibilidad'], 'publica');
        expect(fila['tipo'], 'compartido');
        expect(fila['titular_id'], isNull);
      },
    );

    test(
      'cambiar la visibilidad y archivar o reactivar son UPDATE del libro',
      () async {
        await repo.cargar();
        await repo.cambiarVisibilidadLibro(libroCasa, VisibilidadLibro.publica);
        var fila = memoria
            .tabla(TablasFinanzas.libros)
            .firstWhere((l) => l['id'] == libroCasa);
        expect(fila['visibilidad'], 'publica');
        expect(
          repo.actual!.datos.libro(libroCasa)!.visibilidad,
          VisibilidadLibro.publica,
        );
        await repo.archivarLibro(libroCasa, archivado: true);
        fila = memoria
            .tabla(TablasFinanzas.libros)
            .firstWhere((l) => l['id'] == libroCasa);
        expect(fila['activo'], isFalse);
        expect(repo.actual!.datos.libro(libroCasa)!.archivado, isTrue);
        await repo.archivarLibro(libroCasa, archivado: false);
        expect(
          memoria
              .tabla(TablasFinanzas.libros)
              .firstWhere((l) => l['id'] == libroCasa)['activo'],
          isTrue,
        );
      },
    );

    test('salirse es un UPDATE de la propia fila: hasta = ahora', () async {
      final yo = RepositorioFinanzasSupabase(
        fuente: fuente,
        cola: cola,
        hogarId: hogar,
        personaId: IdsDemostracion.pareja,
        esperaSubida: const Duration(seconds: 2),
        reloj: () => ahora,
      );
      addTearDown(yo.cerrar);
      await yo.cargar();
      fuente.operaciones.clear();
      await yo.salirDelLibro(libroCasa);
      expect(
        fuente.operaciones,
        contains('actualizar:${TablasFinanzas.miembros}'),
      );
      final propia = memoria
          .tabla(TablasFinanzas.miembros)
          .firstWhere(
            (m) =>
                m['libro_id'] == libroCasa &&
                m['persona_id'] == IdsDemostracion.pareja,
          );
      expect(propia['hasta'], ahora.toIso8601String());
      final ajena = memoria
          .tabla(TablasFinanzas.miembros)
          .firstWhere(
            (m) =>
                m['libro_id'] == libroCasa &&
                m['persona_id'] == IdsDemostracion.dueno,
          );
      expect(
        ajena['hasta'],
        isNull,
        reason: 'la fila de otra persona no se toca',
      );
    });

    test('el administrador saca a otro con el mismo UPDATE', () async {
      await repo.cargar();
      await repo.quitarMiembro(libroCasa, IdsDemostracion.pareja);
      final fila = memoria
          .tabla(TablasFinanzas.miembros)
          .firstWhere(
            (m) =>
                m['libro_id'] == libroCasa &&
                m['persona_id'] == IdsDemostracion.pareja,
          );
      expect(fila['hasta'], isNotNull);
    });

    test('agregar: id estable la primera vez y fila nueva si ya se había '
        'salido (no se reabre la anterior)', () async {
      await repo.cargar();
      await repo.agregarMiembro(libroCasa, 'persona-nueva');
      final primera = memoria
          .tabla(TablasFinanzas.miembros)
          .firstWhere((m) => m['persona_id'] == 'persona-nueva');
      expect(
        primera['id'],
        idEstable(ClavesId.miembro(libroCasa, 'persona-nueva', 'miembro')),
      );
      expect(primera['papel'], 'miembro');

      await repo.quitarMiembro(libroCasa, IdsDemostracion.pareja);
      await repo.agregarMiembro(libroCasa, IdsDemostracion.pareja);
      final filas = memoria
          .tabla(TablasFinanzas.miembros)
          .where(
            (m) =>
                m['libro_id'] == libroCasa &&
                m['persona_id'] == IdsDemostracion.pareja,
          )
          .toList();
      expect(filas, hasLength(2));
      expect(
        filas.first['hasta'],
        isNotNull,
        reason: 'la anterior sigue cerrada',
      );
      expect(filas.last['hasta'], isNull);
      expect(filas.last['id'], isNot(filas.first['id']));
    });

    test('la consulta de la cuenta maestra devuelve lo que dice el servidor '
        '(falso si el libro es propio)', () async {
      memoria.funciones['fin_registrar_consulta_maestra'] = (p) =>
          p['p_libro_id'] != IdsDemostracion.libroDueno;
      expect(
        await repo.registrarConsultaMaestra(IdsDemostracion.libroPareja),
        isTrue,
      );
      expect(
        await repo.registrarConsultaMaestra(IdsDemostracion.libroDueno),
        isFalse,
      );
      memoria.funciones['fin_registrar_consulta_maestra'] = (_) => null;
      expect(
        await repo.registrarConsultaMaestra(IdsDemostracion.libroPareja),
        isFalse,
      );
    });
  });

  group('Adultos con Finanzas del hogar (fin_adultos_con_finanzas)', () {
    test('cualquier adulto con Finanzas ve a los demás: se llama con '
        'p_hogar_id y se usa para elegir a quién agregar', () async {
      memoria.funciones['fin_adultos_con_finanzas'] = (_) => [
        {
          'persona_id': IdsDemostracion.dueno,
          'nombre_visible': 'Dueño de ejemplo',
          'rol': 'dueno',
        },
        {
          'persona_id': IdsDemostracion.pareja,
          'nombre_visible': 'Pareja de ejemplo',
          'rol': 'coadministrador',
        },
        {
          'persona_id': 'persona-tercera',
          'nombre_visible': 'Tercera de ejemplo',
          'rol': 'coadministrador',
        },
      ];
      // Una pareja que, por la RLS de las membresías, solo se ve a sí misma.
      memoria
          .tabla('membresias')
          .removeWhere((m) => m['persona_id'] == IdsDemostracion.dueno);
      final comoPareja = RepositorioFinanzasSupabase(
        fuente: fuente,
        cola: cola,
        hogarId: hogar,
        personaId: IdsDemostracion.pareja,
        esperaSubida: const Duration(seconds: 2),
      );
      addTearDown(comoPareja.cerrar);
      final carga = await comoPareja.cargar();
      final llamada = memoria.llamadas.firstWhere(
        (l) => l.$1 == 'fin_adultos_con_finanzas',
      );
      expect(llamada.$2, {'p_hogar_id': hogar});
      expect(carga.adultosConFinanzas, {
        IdsDemostracion.dueno,
        IdsDemostracion.pareja,
        'persona-tercera',
      });
      expect(carga.nombreDe('persona-tercera'), 'Tercera de ejemplo');
    });

    test('si la función no responde, se queda con las membresías que la '
        'sesión alcanza a leer', () async {
      final carga = await repo.cargar();
      expect(carga.adultosConFinanzas, {
        IdsDemostracion.dueno,
        IdsDemostracion.pareja,
      });
    });

    test('la lista se guarda en la copia para trabajar sin señal', () async {
      final almacen = AlmacenSeguroEnMemoria();
      memoria.funciones['fin_adultos_con_finanzas'] = (_) => [
        {
          'persona_id': IdsDemostracion.dueno,
          'nombre_visible': 'Dueño de ejemplo',
          'rol': 'dueno',
        },
        {
          'persona_id': 'persona-tercera',
          'nombre_visible': 'Tercera de ejemplo',
          'rol': 'coadministrador',
        },
      ];
      final conCopia = RepositorioFinanzasSupabase(
        fuente: fuente,
        cola: cola,
        hogarId: hogar,
        personaId: dueno.persona.id,
        copia: CopiaLocalFinanzas(almacen, personaId: dueno.persona.id),
        esperaSubida: const Duration(seconds: 2),
      );
      addTearDown(conCopia.cerrar);
      await conCopia.cargar();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      memoria.sinSenal = true;
      final otra = RepositorioFinanzasSupabase(
        fuente: fuente,
        cola: cola,
        hogarId: hogar,
        personaId: dueno.persona.id,
        copia: CopiaLocalFinanzas(almacen, personaId: dueno.persona.id),
        esperaSubida: const Duration(seconds: 2),
      );
      addTearDown(otra.cerrar);
      final sinSenal = await otra.cargar();
      expect(sinSenal.desdeCopia, isTrue);
      expect(sinSenal.adultosConFinanzas, {
        IdsDemostracion.dueno,
        'persona-tercera',
      });
    });
  });

  group('El suplente de papá: el permiso lo dice fin_puede (I4)', () {
    test('solo el suplente pregunta; el albacea no', () async {
      await repo.cargar(); // el dueño es el albacea
      expect(memoria.llamadas.where((l) => l.$1 == 'fin_puede'), isEmpty);

      memoria.funciones['fin_puede'] = (p) => p['p_accion'] == 'escribir';
      final suplente = RepositorioFinanzasSupabase(
        fuente: fuente,
        cola: cola,
        hogarId: hogar,
        personaId: IdsDemostracion.pareja,
        esperaSubida: const Duration(seconds: 2),
        reloj: () => DateTime(2026, 10, 20, 10),
      );
      addTearDown(suplente.cerrar);
      final carga = await suplente.cargar();
      final llamadas = memoria.llamadas
          .where((l) => l.$1 == 'fin_puede')
          .toList();
      expect(llamadas, hasLength(2));
      expect(
        {for (final l in llamadas) l.$2['p_accion']},
        {'escribir', 'administrar'},
      );
      expect(
        llamadas.every((l) => l.$2['p_libro_id'] == IdsDemostracion.libroPapa),
        isTrue,
      );
      final permiso = carga.permisosServidor[IdsDemostracion.libroPapa]!;
      expect((permiso.escribir, permiso.administrar), (true, false));
    });
  });

  group('Sin señal', () {
    test('cargar sin señal ni copia avisa; con lo último cargado, lo marca '
        'como copia', () async {
      final primera = await repo.cargar();
      expect(primera.desdeCopia, isFalse);
      memoria.sinSenal = true;
      final segunda = await repo.cargar();
      expect(segunda.desdeCopia, isTrue);
      expect(
        segunda.datos.movimientos,
        hasLength(primera.datos.movimientos.length),
      );
    });
  });
}
