// La cola sin conexión cumple el contrato del servidor de Finanzas
// (supabase/README.md, «Contrato para la app»), probada contra un PostgREST
// simulado (postgrest_simulado.dart) que aplica las reglas del servidor:
//
// - 23503 (falta algo de lo que depende) se REINTENTA; no va a "requiere
//   atención" y no detiene al resto de la ronda.
// - 23505 con el mismo id y otro contenido es un duplicado real (requiere
//   atención); el mismo id con el mismo contenido no hace nada y no falla.
// - 23514, 22023, 55000 y 42501 son permanentes (requieren atención).
// - Orden de subida por dependencia: cuentas antes que movimientos; el ajuste
//   antes que su conciliación; el cierre (con sus partidas y abonos) antes de
//   marcar la semana cerrada.
// - La carga nunca lleva columnas que pone el servidor.
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/base_local/base_local.dart';
import 'package:gravity/nucleo/cola/cola_sin_conexion.dart';
import 'package:gravity/nucleo/cola/contrato_servidor.dart';
import 'package:gravity/nucleo/cola/enviador_supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'postgrest_simulado.dart';

const _tablas = {
  'finanzas.cuenta': 'fin_cuentas',
  'finanzas.movimiento': 'fin_movimientos',
  'finanzas.conciliacion': 'fin_conciliaciones',
  'finanzas.cierre': 'fin_cierres',
  'finanzas.cierre_partida': 'fin_cierre_partidas',
  'finanzas.cierre_abono': 'fin_cierre_abonos',
  'finanzas.importacion': 'fin_importaciones',
};
const _actualizaciones = {'finanzas.semana_cerrada': 'fin_semanas'};

// ---------------------------------------------------------------- filas

Map<String, Object?> cuenta(String id) => {
  'id': id,
  'hogar_id': 'h1',
  'libro_id': 'l1',
  'nombre': 'Cuenta $id',
  'tipo': 'banco',
  'estado': 'activa',
};

Map<String, Object?> mov(
  String id, {
  String origen = 'c1',
  String destino = 'c2',
  int monto = 18500,
  String? anulaA,
}) => {
  'id': id,
  'hogar_id': 'h1',
  'tipo': anulaA == null ? 'gasto' : 'anulacion',
  'fecha': '2026-10-22',
  'registrado_en': '2026-10-22T14:00:00.000Z',
  'cuenta_origen_id': origen,
  'cuenta_destino_id': destino,
  'monto_centavos': monto,
  'realizado_por': 'p1',
  'registrado_por': 'p1',
  'via': 'manual',
  'anula_a': anulaA,
};

Map<String, Object?> conciliacion(String id, {String? ajuste}) => {
  'id': id,
  'hogar_id': 'h1',
  'libro_id': 'l1',
  'cuenta_id': 'c1',
  'fecha': '2026-10-22',
  'saldo_declarado': 1000,
  'saldo_calculado': 900,
  'ajuste_movimiento_id': ajuste,
  'persona_id': 'p1',
  'creado_en': '2026-10-22T14:00:00.000Z',
};

Map<String, Object?> importacion(String id) => {
  'id': id,
  'hogar_id': 'h1',
  'archivo': 'presupuesto.xlsx',
  'hoja': 'Hoja 1',
  'filas_leidas': 10,
  'filas_creadas': 9,
  'filas_omitidas': 1,
  'persona_id': 'p1',
  'creado_en': '2026-10-22T14:00:00.000Z',
};

Map<String, Object?> cierre(
  String id, {
  String semana = 's1',
  String hora = '14',
}) => {
  'id': id,
  'hogar_id': 'h1',
  'libro_id': 'l1',
  'semana_id': semana,
  'version': 1,
  'ingreso_real': 100,
  'cerrado_en': '2026-10-22T$hora:00:00.000Z',
};

Map<String, Object?> cierrePartida(String id, String cierreId) => {
  'id': id,
  'hogar_id': 'h1',
  'libro_id': 'l1',
  'cierre_id': cierreId,
  'partida_id': 'pt1',
  'gastado': 100,
};

Map<String, Object?> cierreAbono(String id, String cierreId) => {
  'id': id,
  'hogar_id': 'h1',
  'libro_id': 'l1',
  'cierre_id': cierreId,
  'deuda_id': 'd1',
  'planeado': 100,
  'real': 100,
  'minimo': 50,
};

Map<String, Object?> semana(String id, {String estado = 'por_cerrar'}) => {
  'id': id,
  'hogar_id': 'h1',
  'libro_id': 'l1',
  'estado': estado,
};

void main() {
  late PostgrestSimulado servidor;
  late SupabaseClient cliente;
  late BaseLocal base;
  late DateTime ahora;
  late ColaSinConexion cola;

  ColaSinConexion colaCon(
    EnviadorSupabase enviador, {
    int intentosMaximos = 20,
    int intentosMaximosPorDependencia = 100,
  }) => ColaSinConexion(
    base: base,
    enviador: enviador,
    reloj: () => ahora,
    intentosMaximos: intentosMaximos,
    intentosMaximosPorDependencia: intentosMaximosPorDependencia,
  );

  EnviadorSupabase enviadorNormal() => EnviadorSupabase(
    cliente,
    tablas: _tablas,
    actualizaciones: _actualizaciones,
  );

  setUp(() async {
    servidor = await PostgrestSimulado.iniciar();
    cliente = await servidor.cliente('uid-ana');
    base = BaseLocal.enMemoria();
    ahora = DateTime(2026, 10, 22, 14);
    cola = colaCon(enviadorNormal());
  });

  tearDown(() async {
    await cliente.dispose();
    await base.close();
    await servidor.cerrar();
  });

  /// Encola [fila] (su `id` es el del registro).
  Future<void> poner(String tipo, Map<String, Object?> fila) =>
      cola.encolar(tipo: tipo, carga: fila, id: fila['id']! as String);

  Future<RegistroPendiente> registro(String id) async =>
      (await cola.registros()).singleWhere((r) => r.id == id);

  void sembrarCuentas() {
    servidor
      ..sembrar('fin_cuentas', cuenta('c1'))
      ..sembrar('fin_cuentas', cuenta('c2'));
  }

  List<String> idsEnviados(String tabla) => [
    for (final p in servidor.peticiones)
      if (p.metodo == 'POST' && p.tabla == tabla) p.id!,
  ];

  group('23503: falta algo de lo que depende', () {
    test('se reintenta, no requiere atención y la ronda sigue', () async {
      await poner('finanzas.movimiento', mov('m1')); // c1 y c2 aún no existen
      await poner('finanzas.importacion', importacion('i1')); // no depende

      final r = await cola.procesar();
      expect((r.enviados, r.reintentos, r.rechazados), (1, 1, 0));
      expect(servidor.idsDe('fin_importaciones'), ['i1']);

      final m1 = await registro('m1');
      expect(m1.estado, EstadoPendiente.pendiente);
      expect(m1.intentos, 1);
      expect(m1.siguienteIntento, ahora.add(const Duration(seconds: 5)));
      expect(m1.ultimoError, allOf(contains('23503'), contains('c1')));
      expect(await cola.requierenAtencion(), isEmpty);

      // Lo que faltaba llega (otro dispositivo): aún no pasa la espera.
      sembrarCuentas();
      final antes = servidor.peticiones.length;
      await cola.procesar();
      expect(servidor.peticiones, hasLength(antes));

      ahora = ahora.add(const Duration(seconds: 5));
      expect((await cola.procesar()).enviados, 1);
      expect(servidor.idsDe('fin_movimientos'), ['m1']);
      expect((await registro('m1')).estado, EstadoPendiente.enviado);
    });

    test('la espera crece con cada reintento', () async {
      await poner('finanzas.movimiento', mov('m1'));
      for (final segundos in const [5, 10, 20, 40]) {
        await cola.procesar();
        final m1 = await registro('m1');
        expect(
          m1.siguienteIntento,
          ahora.add(Duration(seconds: segundos)),
          reason: 'intento ${m1.intentos}',
        );
        ahora = m1.siguienteIntento!;
      }
    });

    test(
      'no cuenta contra el límite de fallos de red; tiene el suyo',
      () async {
        await poner('finanzas.movimiento', mov('m1'));
        for (var i = 0; i < 25; i++) {
          await cola.procesar();
          ahora = ahora.add(const Duration(hours: 1));
        }
        final m1 = await registro('m1');
        expect(m1.estado, EstadoPendiente.pendiente);
        expect(m1.intentos, 25);
        expect(await cola.requierenAtencion(), isEmpty);

        // Con su propio límite, pasado el cual lo ve la persona.
        final corta = colaCon(
          enviadorNormal(),
          intentosMaximosPorDependencia: 27,
        );
        await corta.procesar();
        ahora = ahora.add(const Duration(hours: 1));
        await corta.procesar();
        final fin = await registro('m1');
        expect(fin.estado, EstadoPendiente.rechazado);
        expect(
          fin.ultimoError,
          allOf(contains('Falló 27 veces'), contains('23503')),
        );
      },
    );
  });

  group('23505: mismo id', () {
    test(
      'con otro contenido es un duplicado real: requiere atención',
      () async {
        servidor.sembrar('fin_movimientos', mov('m1', monto: 100));
        await poner('finanzas.movimiento', mov('m1', monto: 200));

        final r = await cola.procesar();
        expect((r.enviados, r.reintentos, r.rechazados), (0, 0, 1));
        final m1 = await registro('m1');
        expect(m1.estado, EstadoPendiente.rechazado);
        expect(
          m1.ultimoError,
          allOf(
            contains('23505'),
            contains('otro contenido'),
            contains('duplicado'),
          ),
        );
        expect(await cola.requierenAtencion(), hasLength(1));
        // Lo que ya estaba no se pisa.
        expect(
          servidor.filas['fin_movimientos']!['m1']!['monto_centavos'],
          100,
        );

        // No se reintenta solo.
        ahora = ahora.add(const Duration(days: 1));
        final antes = servidor.peticiones.length;
        await cola.procesar();
        expect(servidor.peticiones, hasLength(antes));
      },
    );

    test('con el mismo contenido no hace nada y no falla', () async {
      servidor.sembrar('fin_movimientos', {
        ...mov('m1'),
        // Lo que puso el servidor: no se compara.
        'recibido_en': '2026-10-21T00:00:00Z',
        'libro_origen_id': 'l1',
      });
      await poner('finanzas.movimiento', mov('m1'));

      final r = await cola.procesar();
      expect((r.enviados, r.reintentos, r.rechazados), (1, 0, 0));
      expect(servidor.idsDe('fin_movimientos'), ['m1']);
      expect(
        servidor.filas['fin_movimientos']!['m1']!['recibido_en'],
        '2026-10-21T00:00:00Z',
      );
      expect(await cola.requierenAtencion(), isEmpty);
    });

    test(
      'la hora de cierre del dispositivo no cuenta como otro contenido',
      () async {
        servidor.sembrar('fin_cierres', cierre('z1', hora: '10'));
        await poner('finanzas.cierre', cierre('z1', hora: '14'));
        final r = await cola.procesar();
        expect((r.enviados, r.rechazados), (1, 0));
      },
    );

    test(
      'tras una respuesta perdida, el reenvío no duplica ni falla',
      () async {
        sembrarCuentas();
        await poner('finanzas.movimiento', mov('m1'));
        servidor.perderRespuestas = 1;

        // El servidor guardó, pero el teléfono no lo supo.
        expect((await cola.procesar()).reintentos, 1);
        expect(servidor.idsDe('fin_movimientos'), ['m1']);
        expect((await registro('m1')).estado, EstadoPendiente.pendiente);

        ahora = ahora.add(const Duration(seconds: 5));
        final r = await cola.procesar();
        expect((r.enviados, r.reintentos, r.rechazados), (1, 0, 0));
        expect(servidor.idsDe('fin_movimientos'), ['m1']);
        expect(idsEnviados('fin_movimientos'), ['m1', 'm1']);
      },
    );
  });

  group('permanentes: requieren atención y no se reintentan solos', () {
    for (final (codigo, texto, estado) in [
      ('23514', 'regla de la tabla', 400),
      ('22023', 'combinación', 400),
      ('55000', 'estado actual', 400),
      ('42501', 'Sin permiso', 403),
    ]) {
      test(codigo, () async {
        sembrarCuentas();
        servidor.fallar(
          'fin_movimientos',
          ErrorForzado(codigo, 'Mensaje del servidor $codigo', estado: estado),
        );
        await poner('finanzas.movimiento', mov('m1'));
        await poner('finanzas.importacion', importacion('i1'));

        final r = await cola.procesar();
        // Lo permanente no detiene al resto de la ronda.
        expect((r.enviados, r.reintentos, r.rechazados), (1, 0, 1));
        final m1 = await registro('m1');
        expect(m1.estado, EstadoPendiente.rechazado);
        expect(m1.ultimoError, allOf(contains(codigo), contains(texto)));
        expect(await cola.requierenAtencion(), hasLength(1));

        final antes = servidor.peticiones.length;
        ahora = ahora.add(const Duration(days: 1));
        await cola.procesar();
        expect(servidor.peticiones, hasLength(antes));

        // La persona decide reintentar (ya se corrigió) y sube.
        await cola.reintentar('m1');
        expect((await cola.procesar()).enviados, 1);
        expect(servidor.idsDe('fin_movimientos'), ['m1']);
      });
    }
  });

  test('servidor caído (503): se reintenta y se detiene la ronda', () async {
    servidor.caido = true;
    await poner('finanzas.movimiento', mov('m1'));
    await poner('finanzas.importacion', importacion('i1'));

    final r = await cola.procesar();
    expect((r.enviados, r.reintentos, r.rechazados), (0, 1, 0));
    expect(servidor.peticiones, hasLength(1));
    expect((await registro('m1')).estado, EstadoPendiente.pendiente);
    expect(await cola.requierenAtencion(), isEmpty);
  });

  group('orden de subida por dependencia', () {
    test(
      'cuentas antes que movimientos, aunque el movimiento se creó primero',
      () async {
        await poner('finanzas.movimiento', mov('m1'));
        await poner('finanzas.cuenta', cuenta('c1'));
        await poner('finanzas.cuenta', cuenta('c2'));

        final r = await cola.procesar();
        expect((r.enviados, r.reintentos, r.rechazados), (3, 0, 0));
        expect(servidor.ordenDeTablas, ['fin_cuentas', 'fin_movimientos']);
        expect(servidor.peticiones, hasLength(3)); // sin un solo 23503
        expect(idsEnviados('fin_cuentas'), ['c1', 'c2']);
      },
    );

    test('el ajuste antes que su conciliación', () async {
      sembrarCuentas();
      await poner('finanzas.conciliacion', conciliacion('k1', ajuste: 'aj1'));
      await poner('finanzas.movimiento', mov('aj1'));

      final r = await cola.procesar();
      expect((r.enviados, r.reintentos, r.rechazados), (2, 0, 0));
      expect(servidor.ordenDeTablas, ['fin_movimientos', 'fin_conciliaciones']);
    });

    test(
      'el cierre con sus partidas y abonos antes de marcar la semana cerrada',
      () async {
        servidor.sembrar('fin_semanas', semana('s1'));
        await poner('finanzas.semana_cerrada', {
          'id': 's1',
          'estado': 'cerrada',
        });
        await poner('finanzas.cierre_abono', cierreAbono('za1', 'z1'));
        await poner('finanzas.cierre_partida', cierrePartida('zp1', 'z1'));
        await poner('finanzas.cierre', cierre('z1'));

        final r = await cola.procesar();
        expect((r.enviados, r.reintentos, r.rechazados), (4, 0, 0));
        expect(servidor.ordenDeTablas, [
          'fin_cierres',
          'fin_cierre_abonos',
          'fin_cierre_partidas',
          'fin_semanas#PATCH',
        ]);
        expect(servidor.filas['fin_semanas']!['s1']!['estado'], 'cerrada');
      },
    );

    test('sin orden, la semana se marca antes del cierre y el servidor la '
        'rechaza (55000)', () async {
      servidor.sembrar('fin_semanas', semana('s1'));
      // Sin niveles (todo de nivel 0): solo cuenta el orden de creación.
      cola = colaCon(
        EnviadorSupabase(
          cliente,
          tablas: _tablas,
          actualizaciones: _actualizaciones,
          niveles: const {},
        ),
      );
      await poner('finanzas.semana_cerrada', {'id': 's1', 'estado': 'cerrada'});
      await poner('finanzas.cierre', cierre('z1'));

      final r = await cola.procesar();
      expect(r.rechazados, 1);
      final cerrar = await registro('s1');
      expect(cerrar.estado, EstadoPendiente.rechazado);
      expect(cerrar.ultimoError, contains('55000'));
    });

    test('dentro de un mismo nivel se conserva el orden de creación', () async {
      await poner('finanzas.movimiento', mov('m1'));
      await poner('finanzas.movimiento', mov('m2', anulaA: 'm1'));
      await poner('finanzas.movimiento', mov('m3', monto: 500));
      await poner('finanzas.cuenta', cuenta('c1'));
      await poner('finanzas.cuenta', cuenta('c2'));

      final r = await cola.procesar();
      expect((r.enviados, r.reintentos, r.rechazados), (5, 0, 0));
      // La anulación sube después del movimiento que anula, sin 23503.
      expect(idsEnviados('fin_movimientos'), ['m1', 'm2', 'm3']);
    });

    test('lo que no sabe de niveles sube en el orden de siempre', () async {
      sembrarCuentas();
      await poner('otro.tipo', {'id': 'x1'});
      await poner('finanzas.movimiento', mov('m1'));
      cola = colaCon(
        EnviadorSupabase(
          cliente,
          tablas: {..._tablas, 'otro.tipo': 'tabla_de_otro_modulo'},
        ),
      );
      await cola.procesar();
      // Nivel 0 (sin conocer): antes que los movimientos.
      expect(servidor.ordenDeTablas, [
        'tabla_de_otro_modulo',
        'fin_movimientos',
      ]);
    });
  });

  group('cambio de estado de la semana (idempotente)', () {
    setUp(() {
      servidor
        ..sembrar('fin_semanas', semana('s1'))
        ..sembrar('fin_cierres', cierre('z1'));
    });

    test('tras una respuesta perdida, el reenvío no da 55000', () async {
      await poner('finanzas.semana_cerrada', {'id': 's1', 'estado': 'cerrada'});
      servidor.perderRespuestas = 1;

      expect((await cola.procesar()).reintentos, 1);
      expect(servidor.filas['fin_semanas']!['s1']!['estado'], 'cerrada');

      ahora = ahora.add(const Duration(seconds: 5));
      final r = await cola.procesar();
      expect((r.enviados, r.reintentos, r.rechazados), (1, 0, 0));
      expect(await cola.requierenAtencion(), isEmpty);
    });

    test('si la semana aún no existe en el servidor, se reintenta', () async {
      servidor.filas['fin_semanas']!.clear();
      await poner('finanzas.semana_cerrada', {'id': 's1', 'estado': 'cerrada'});
      await poner('finanzas.importacion', importacion('i1'));

      final r = await cola.procesar();
      expect((r.enviados, r.reintentos, r.rechazados), (1, 1, 0));
      final cerrar = await registro('s1');
      expect(cerrar.estado, EstadoPendiente.pendiente);
      expect(cerrar.ultimoError, contains('aún no existe'));

      servidor.sembrar('fin_semanas', semana('s1'));
      ahora = ahora.add(const Duration(seconds: 5));
      expect((await cola.procesar()).enviados, 1);
      expect(servidor.filas['fin_semanas']!['s1']!['estado'], 'cerrada');
    });

    test('sin cierre en el servidor, el servidor lo rechaza (55000)', () async {
      servidor.filas['fin_cierres']!.clear();
      await poner('finanzas.semana_cerrada', {'id': 's1', 'estado': 'cerrada'});
      final r = await cola.procesar();
      expect(r.rechazados, 1);
      expect((await registro('s1')).ultimoError, contains('55000'));
    });
  });

  group('columnas que pone el servidor', () {
    test('la carga nunca las lleva', () async {
      servidor
        ..sembrar('fin_cierres', cierre('z1'))
        ..sembrar('fin_semanas', semana('s1'));
      // Como si quien encola hubiera copiado una fila leída del servidor.
      await poner('finanzas.cuenta', {
        ...cuenta('c1'),
        'clase': 'activo',
        'liquida': true,
        'creada_en': '2026-10-01T00:00:00Z',
      });
      await poner('finanzas.cuenta', cuenta('c2'));
      await poner('finanzas.movimiento', {
        ...mov('m1'),
        'recibido_en': '2026-10-22T14:00:01Z',
        'libro_origen_id': 'l1',
        'libro_destino_id': 'l1',
      });
      await poner('finanzas.conciliacion', {
        ...conciliacion('k1'),
        'diferencia': 100,
      });
      await poner('finanzas.cierre_abono', {
        ...cierreAbono('za1', 'z1'),
        'diferido': 0,
      });
      await poner('finanzas.semana_cerrada', {
        'id': 's1',
        'estado': 'cerrada',
        'reaperturas': 3,
      });

      final r = await cola.procesar();
      expect((r.enviados, r.reintentos, r.rechazados), (6, 0, 0));
      for (final p in servidor.peticiones) {
        final prohibidas = columnasQuePoneElServidor[p.tabla] ?? const {};
        expect(
          p.columnas.where(prohibidas.contains),
          isEmpty,
          reason: '${p.metodo} ${p.tabla} lleva columnas del servidor',
        );
      }
      // Y lo demás sí viaja.
      final movimiento = servidor.peticiones.firstWhere(
        (p) => p.tabla == 'fin_movimientos',
      );
      expect(
        movimiento.columnas,
        containsAll(['id', 'monto_centavos', 'registrado_en']),
      );
      expect(
        servidor.peticiones.firstWhere((p) => p.metodo == 'PATCH').columnas,
        {'estado'},
      );
    });

    test('el servidor simulado sí rechaza (42501) lo que las lleva', () async {
      // Sin la protección del enviador, esta carga se rechazaría para siempre.
      await expectLater(
        cliente
            .from('fin_movimientos')
            .upsert(
              {...mov('m1'), 'recibido_en': '2026-10-22T14:00:01Z'},
              onConflict: 'id',
              ignoreDuplicates: true,
            ),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'código', '42501'),
        ),
      );
    });

    test('registrado_en: si falta, sube la hora del dispositivo, siempre la '
        'misma', () async {
      sembrarCuentas();
      final registrada = ahora.toUtc().toIso8601String();
      final sin = mov('m1')..remove('registrado_en');
      await poner('finanzas.movimiento', sin);
      servidor.perderRespuestas = 1;

      await cola.procesar();
      ahora = ahora.add(const Duration(seconds: 5));
      final r = await cola.procesar();
      // Si cambiara entre reintentos, el reenvío sería "otro contenido" (23505).
      expect((r.enviados, r.rechazados), (1, 0));
      final horas = [
        for (final p in servidor.peticiones)
          if (p.metodo == 'POST') (p.cuerpo! as Map)['registrado_en'],
      ];
      expect(horas, hasLength(2));
      expect(horas.toSet(), {registrada});
    });
  });
}
