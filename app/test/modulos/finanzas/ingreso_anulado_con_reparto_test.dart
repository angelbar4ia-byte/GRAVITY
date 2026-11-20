// Fase 8 (F8-6.9): ingreso anulado con reparto (hallazgo H-03 de la revisión del
// bloque 6; decisión del dueño del 20/nov/2026: opción B con alternativa A).
// Al anular un ingreso ya repartido, los movimientos del reparto siguen vigentes:
// la app NO deshace nada sola; avisa con una tarjeta y la persona elige «Deshacer
// reparto» (anula esos movimientos con motivo, sin borrar historial) o «Dejarlo
// así» (no toca dinero y no vuelve a avisar). Servicio (en memoria y sobre el
// servidor), repositorio de Supabase y la tarjeta en teléfono y laptop. Datos de
// ejemplo inventados.
import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide Semaforo, formatearCentavos, TipoLibro, puntosBaseEnCien;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/diseno/diseno.dart' show montosVisiblesProvider;
import 'package:gravity/modulos/finanzas/casos_uso/servicio_dispersion.dart';
import 'package:gravity/modulos/finanzas/casos_uso/servicio_finanzas.dart';
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/modulos/finanzas/datos/fuente_tablas.dart';
import 'package:gravity/modulos/finanzas/datos/ids.dart'
    show ClavesId, claveDeLineaDispersion, idEstable;
import 'package:gravity/modulos/finanzas/datos/repositorio.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_dispersiones.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_dispersiones_supabase.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_memoria.dart';
import 'package:gravity/modulos/finanzas/estado/proveedores.dart';
import 'package:gravity/modulos/finanzas/estado/proveedores_dispersion.dart';
import 'package:gravity/modulos/finanzas/finanzas.dart' show SeccionFinanzas;
import 'package:gravity/modulos/finanzas/pantallas/tarjeta_ingreso_anulado.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart'
    show hogarDeEjemplo;

import '../../revision_calidad/ayuda_calidad.dart';
import 'ayuda_finanzas.dart';

const _libro = IdsDemostracion.libroDueno;
const _papa = IdsDemostracion.libroPapa;

/// Viernes de la semana anterior a "hoy" (martes 20/oct/2026).
final _viernesPasado = Fecha(2026, 10, 16);

class _Mundo {
  _Mundo(this.repo, this.finanzas, this.reparto, this.servicio);

  final RepositorioFinanzasEnMemoria repo;
  final ServicioFinanzas finanzas;
  final RepositorioDispersiones reparto;
  final ServicioDispersion servicio;

  DatosFinanzas get datos => repo.datos;
}

_Mundo _mundo({RepositorioDispersiones? reparto, bool soloLectura = false}) {
  final dueno = sesionDe(Rol.dueno);
  final repo = repositorioDe(dueno);
  final finanzas = ServicioFinanzas(
    repositorio: repo,
    personaId: dueno.persona.id,
    hogarId: dueno.hogarId ?? hogarDeEjemplo,
    esDueno: true,
    soloLectura: soloLectura,
    reloj: () => ahoraDePrueba,
  );
  final r = reparto ?? RepositorioDispersionesEnMemoria();
  return _Mundo(
    repo,
    finanzas,
    r,
    ServicioDispersion(finanzas: finanzas, repositorio: r),
  );
}

String _banco(_Mundo m, String libro) =>
    m.datos.cuentasDe(libro).firstWhere((c) => c.tipo == TipoCuenta.banco).id;

Future<String> _ingresoExtra(
  _Mundo m, {
  String libro = _libro,
  int monto = 900000,
  String? motivo,
}) async {
  final r = await m.finanzas.registrarIngresoExtra(
    libroId: libro,
    monto: monto,
    cuentaDestinoId: _banco(m, libro),
    fecha: _viernesPasado,
    nota: 'Sueldo',
    motivo: motivo,
  );
  return r.movimientos.single.id;
}

Future<Cuenta> _ahorro(_Mundo m, [String libro = _libro]) async {
  final hay = m.datos
      .cuentasDe(libro)
      .where((c) => c.tipo == TipoCuenta.ahorro);
  if (hay.isNotEmpty) return hay.first;
  return m.finanzas.crearCuenta(
    libroId: libro,
    nombre: 'Mi ahorro',
    tipo: TipoCuenta.ahorro,
  );
}

IngresoPorRepartir _ingreso(_Mundo m, String movimientoId, [String? libro]) => m
    .servicio
    .ingresos(libro ?? _libro)
    .firstWhere((i) => i.movimientoId == movimientoId);

/// Los ids de los movimientos que creó un reparto.
List<String> _movimientosDe(Dispersion d) => [
  for (final l in d.lineas)
    if (l.destino.mueveDinero && l.monto > 0)
      idEstable(ClavesId.dispersionMovimiento(d.id, claveDeLineaDispersion(l))),
];

/// Reparte un ingreso nuevo con ahorro. Devuelve (ingreso, reparto).
Future<(String, Dispersion)> _repartido(
  _Mundo m, {
  String libro = _libro,
  int monto = 900000,
  String? motivo,
}) async {
  final ahorro = await _ahorro(m, libro);
  final id = await _ingresoExtra(m, libro: libro, monto: monto, motivo: motivo);
  final ingreso = _ingreso(m, id, libro);
  final d = await m.servicio.aceptar(
    ingreso: ingreso,
    propuesta: m.servicio.proponer(ingreso),
    cuentaAhorroId: ahorro.id,
    motivo: motivo,
  );
  expect(_movimientosDe(d), isNotEmpty, reason: 'el reparto mueve dinero');
  return (id, d);
}

/// Anula el ingreso y refleja lo que hace el servidor: su reparto pasa a
/// «anulada» (los movimientos que creó siguen vigentes).
Future<void> _anularIngreso(
  _Mundo m,
  String ingresoId,
  Dispersion d, {
  String? motivo,
}) async {
  await m.finanzas.anular(ingresoId, motivo: motivo ?? 'Lo registré dos veces');
  await m.reparto.guardar(d.conEstado(EstadoDispersion.anulada));
}

bool _anulado(_Mundo m, String libro, String movimientoId) =>
    m.datos.vista(libro).estaAnulado(movimientoId);

ProviderContainer _contenedor(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(AppGravity)));

void main() {
  group('Servicio (en memoria): ingreso anulado con reparto', () {
    test('antes de anular el ingreso no hay nada que avisar', () async {
      final m = _mundo();
      await _repartido(m);
      expect(m.servicio.repartosAnuladosConMovimientos(_libro), isEmpty);
    });

    test('al anular el ingreso la app NO deshace nada sola: los movimientos '
        'del reparto siguen vigentes y se avisa', () async {
      final m = _mundo();
      final (id, d) = await _repartido(m);
      final hijos = _movimientosDe(d);
      final antes = m.datos.movimientos.length;
      await _anularIngreso(m, id, d);
      expect(
        m.datos.movimientos.length,
        antes + 1,
        reason: 'solo se agregó la anulación del ingreso',
      );
      expect(_anulado(m, _libro, id), isTrue);
      for (final h in hijos) {
        expect(_anulado(m, _libro, h), isFalse, reason: 'sigue vigente');
      }
      final pendientes = m.servicio.repartosAnuladosConMovimientos(_libro);
      expect(pendientes, hasLength(1));
      expect(pendientes.single.dispersionId, d.id);
      expect(pendientes.single.movimientoId, id);
      expect(pendientes.single.movimientosVigentes, hijos.length);
      expect(pendientes.single.fecha, _viernesPasado);
    });

    test('un reparto anulado por la vía normal (movimientos ya anulados) no '
        'sale', () async {
      final m = _mundo();
      final (_, d) = await _repartido(m);
      await m.servicio.deshacer(d.id);
      expect(m.servicio.repartosAnuladosConMovimientos(_libro), isEmpty);
    });

    test('otro libro no ve los del libro de Ana', () async {
      final m = _mundo();
      final (id, d) = await _repartido(m);
      await _anularIngreso(m, id, d);
      expect(m.servicio.repartosAnuladosConMovimientos(_papa), isEmpty);
    });

    test('«Deshacer reparto» anula exactamente los movimientos de ese reparto '
        'con contraasiento y motivo, sin borrar nada', () async {
      final m = _mundo();
      final (id, d) = await _repartido(m);
      // Otro ingreso repartido que NO se anula: no se debe tocar.
      final (id2, d2) = await _repartido(m, monto: 500000);
      await _anularIngreso(m, id, d);
      final hijos = _movimientosDe(d);
      final ajenos = _movimientosDe(d2);
      final antes = m.datos.movimientos.length;

      await m.servicio.deshacerRepartoAnulado(d.id, motivo: 'Anulé el ingreso');

      expect(
        m.datos.movimientos.length,
        antes + hijos.length,
        reason: 'solo las anulaciones de sus movimientos; nada se borra',
      );
      for (final h in hijos) {
        expect(_anulado(m, _libro, h), isTrue);
        final c = m.datos.vista(_libro).contraasientoDe(h)!;
        expect(c.motivo, 'Anulé el ingreso');
        expect(c.tipo, TipoMovimiento.anulacion);
      }
      for (final a in ajenos) {
        expect(_anulado(m, _libro, a), isFalse, reason: 'no es de ese reparto');
      }
      expect(_anulado(m, _libro, id2), isFalse);
      expect(m.servicio.repartosAnuladosConMovimientos(_libro), isEmpty);
      expect(
        m.reparto.actuales.firstWhere((x) => x.id == d.id).estado,
        EstadoDispersion.anulada,
        reason: 'el historial del reparto se conserva',
      );
    });

    test('deshacer sin motivo, fuera del libro de Papá, usa el de siempre; y '
        'repetirlo no anula nada más', () async {
      final m = _mundo();
      final (id, d) = await _repartido(m);
      await _anularIngreso(m, id, d);
      await m.servicio.deshacerRepartoAnulado(d.id);
      final h = _movimientosDe(d).first;
      expect(
        m.datos.vista(_libro).contraasientoDe(h)!.motivo,
        motivoDeshacerRepartoAnulado,
      );
      final antes = m.datos.movimientos.length;
      await m.servicio.deshacerRepartoAnulado(d.id);
      expect(m.datos.movimientos.length, antes, reason: 'idempotente');
    });

    test('«Dejarlo así» no toca dinero y el aviso no vuelve', () async {
      final m = _mundo();
      final (id, d) = await _repartido(m);
      await _anularIngreso(m, id, d);
      final antes = m.datos.movimientos.length;
      await m.servicio.dejarRepartoAnulado(d.id);
      expect(m.datos.movimientos.length, antes);
      for (final h in _movimientosDe(d)) {
        expect(_anulado(m, _libro, h), isFalse);
      }
      expect(m.reparto.repartosDejados, contains(d.id));
      expect(m.servicio.repartosAnuladosConMovimientos(_libro), isEmpty);
      // Repetirlo es inofensivo.
      await m.servicio.dejarRepartoAnulado(d.id);
      expect(m.servicio.repartosAnuladosConMovimientos(_libro), isEmpty);
    });

    test('lo que se dejó así todavía se puede deshacer después', () async {
      final m = _mundo();
      final (id, d) = await _repartido(m);
      await _anularIngreso(m, id, d);
      await m.servicio.dejarRepartoAnulado(d.id);
      await m.servicio.deshacerRepartoAnulado(d.id, motivo: 'Cambié de idea');
      for (final h in _movimientosDe(d)) {
        expect(_anulado(m, _libro, h), isTrue);
      }
    });

    test('solo se actúa sobre un reparto anulado', () async {
      final m = _mundo();
      final (_, d) = await _repartido(m);
      await expectLater(
        m.servicio.deshacerRepartoAnulado(d.id, motivo: 'Lo intento'),
        throwsA(isA<ErrorFinanzas>()),
      );
      await expectLater(
        m.servicio.dejarRepartoAnulado(d.id),
        throwsA(isA<ErrorFinanzas>()),
      );
      await expectLater(
        m.servicio.dejarRepartoAnulado('no-existe'),
        throwsA(isA<ErrorFinanzas>()),
      );
    });

    test('sin permiso de escribir (cuenta maestra, solo lectura) se rechaza '
        'y no cambia nada', () async {
      final m = _mundo();
      final (id, d) = await _repartido(m);
      await _anularIngreso(m, id, d);
      final lector = ServicioDispersion(
        finanzas: ServicioFinanzas(
          repositorio: m.repo,
          personaId: 'maestra',
          hogarId: hogarDeEjemplo,
          esMaestra: true,
          soloLectura: true,
          reloj: () => ahoraDePrueba,
        ),
        repositorio: m.reparto,
      );
      final antes = m.datos.movimientos.length;
      await expectLater(
        lector.deshacerRepartoAnulado(d.id, motivo: 'Lo intento'),
        throwsA(isA<ErrorFinanzas>()),
      );
      await expectLater(
        lector.dejarRepartoAnulado(d.id),
        throwsA(isA<ErrorFinanzas>()),
      );
      expect(m.datos.movimientos.length, antes);
      expect(m.reparto.repartosDejados, isEmpty);
    });

    test(
      'en el libro de Papá deshacer exige motivo y va en su nombre',
      () async {
        final m = _mundo();
        final (id, d) = await _repartido(
          m,
          libro: _papa,
          monto: 300000,
          motivo: 'Apoyo del hermano',
        );
        await _anularIngreso(m, id, d, motivo: 'Capturado por error');
        expect(m.servicio.repartosAnuladosConMovimientos(_papa), hasLength(1));
        await expectLater(
          m.servicio.deshacerRepartoAnulado(d.id),
          throwsA(isA<ErrorFinanzas>()),
          reason: 'el libro de Papá exige motivo',
        );
        await expectLater(
          m.servicio.deshacerRepartoAnulado(d.id, motivo: 'ab'),
          throwsA(isA<ErrorFinanzas>()),
        );
        for (final h in _movimientosDe(d)) {
          expect(_anulado(m, _papa, h), isFalse, reason: 'nada se tocó');
        }
        await m.servicio.deshacerRepartoAnulado(
          d.id,
          motivo: 'Anulé la pensión: deshago el reparto',
        );
        for (final h in _movimientosDe(d)) {
          final c = m.datos.vista(_papa).contraasientoDe(h)!;
          expect(c.motivo, 'Anulé la pensión: deshago el reparto');
          expect(c.enNombreDe, isNotNull, reason: 'en nombre de Papá');
        }
      },
    );
  });

  group('Repositorio de Supabase y servicio sobre el servidor', () {
    late FuenteTablasEnMemoria fuente;
    late RepositorioDispersionesSupabase reparto;
    late int recargas;

    setUp(() {
      fuente = FuenteTablasEnMemoria();
      recargas = 0;
      reparto = RepositorioDispersionesSupabase(
        fuente: fuente,
        alCambiarMovimientos: () async => recargas++,
      );
    });

    Map<String, Object?> fila(String id, String estado) => {
      'id': id,
      'libro_id': _libro,
      'movimiento_id': 'm-$id',
      'estado': estado,
      'modo': 'confirmacion',
      'version': 1,
      'creada_en': '2026-10-20T15:00:00+00:00',
    };

    test('cargar lee la lectura del servidor (solo ids y un conteo)', () async {
      fuente.tabla('fin_dispersiones').add(fila('a1', 'anulada'));
      fuente.funciones['fin_repartos_anulados_con_movimientos'] = (p) {
        expect(p, isEmpty, reason: 'sin libro: todos los que ve');
        return [
          {
            'dispersion_id': 'a1',
            'libro_id': _libro,
            'movimiento_id': 'm-a1',
            'movimientos_vigentes': 2,
          },
        ];
      };
      await reparto.cargar();
      final l = reparto.anuladosConMovimientosDelServidor!;
      expect(l, hasLength(1));
      expect(l.single.dispersionId, 'a1');
      expect(l.single.movimientosVigentes, 2);
    });

    test(
      'un servidor sin la lectura deja el cálculo en el dispositivo',
      () async {
        fuente.tabla('fin_dispersiones').add(fila('a1', 'anulada'));
        await reparto.cargar();
        expect(reparto.anuladosConMovimientosDelServidor, isNull);
      },
    );

    test('«Dejarlo así» llama a la RPC, no recarga el libro y lo quita de la '
        'lista', () async {
      fuente.tabla('fin_dispersiones').add(fila('a1', 'anulada'));
      fuente.funciones['fin_repartos_anulados_con_movimientos'] = (_) => [
        {
          'dispersion_id': 'a1',
          'libro_id': _libro,
          'movimiento_id': 'm-a1',
          'movimientos_vigentes': 1,
        },
      ];
      fuente.funciones['fin_dejar_reparto_anulado'] = (_) => {'dejado': true};
      await reparto.cargar();
      final m = _mundo(reparto: reparto);
      expect(m.servicio.repartosAnuladosConMovimientos(_libro), hasLength(1));
      await m.servicio.dejarRepartoAnulado('a1');
      final (funcion, args) = fuente.llamadas.last;
      expect(funcion, 'fin_dejar_reparto_anulado');
      expect(args, {'p_dispersion': 'a1'});
      expect(recargas, 0, reason: 'no se tocó dinero');
      expect(m.servicio.repartosAnuladosConMovimientos(_libro), isEmpty);
      expect(reparto.repartosDejados, contains('a1'));
    });

    test('«Deshacer reparto» llama a la RPC con el motivo, no agrega ni anula '
        'movimientos por su cuenta y recarga el libro', () async {
      fuente.tabla('fin_dispersiones').add(fila('a1', 'anulada'));
      fuente.funciones['fin_repartos_anulados_con_movimientos'] = (_) => [
        {
          'dispersion_id': 'a1',
          'libro_id': _libro,
          'movimiento_id': 'm-a1',
          'movimientos_vigentes': 2,
        },
      ];
      fuente.funciones['fin_deshacer_reparto_anulado'] = (_) => {
        'movimientos_anulados': 2,
      };
      await reparto.cargar();
      final m = _mundo(reparto: reparto);
      final antes = m.datos.movimientos.length;
      await m.servicio.deshacerRepartoAnulado('a1', motivo: 'Anulé el ingreso');
      final (funcion, args) = fuente.llamadas.last;
      expect(funcion, 'fin_deshacer_reparto_anulado');
      expect(args, {'p_dispersion': 'a1', 'p_motivo': 'Anulé el ingreso'});
      expect(m.datos.movimientos.length, antes, reason: 'lo anula el servidor');
      expect(recargas, 1, reason: 'Finanzas vuelve a cargar el libro');
      expect(m.servicio.repartosAnuladosConMovimientos(_libro), isEmpty);
    });

    test('sin señal necesita conexión y no cambia nada', () async {
      fuente.tabla('fin_dispersiones').add(fila('a1', 'anulada'));
      fuente.funciones['fin_repartos_anulados_con_movimientos'] = (_) => [
        {
          'dispersion_id': 'a1',
          'libro_id': _libro,
          'movimiento_id': 'm-a1',
          'movimientos_vigentes': 1,
        },
      ];
      await reparto.cargar();
      final m = _mundo(reparto: reparto);
      fuente.sinSenal = true;
      for (final accion in [
        () => m.servicio.deshacerRepartoAnulado('a1', motivo: 'Sin señal'),
        () => m.servicio.dejarRepartoAnulado('a1'),
      ]) {
        await expectLater(
          accion(),
          throwsA(
            isA<ErrorFinanzas>().having(
              (e) => e.sinConexion,
              'sinConexion',
              true,
            ),
          ),
        );
      }
      expect(m.servicio.repartosAnuladosConMovimientos(_libro), hasLength(1));
      expect(recargas, 0);
      expect(reparto.repartosDejados, isEmpty);
    });

    test('emite el aviso del catálogo sin cifras: tipo, ingreso por objeto y '
        'clave estable', () async {
      fuente.tabla('fin_dispersiones').add(fila('a1', 'anulada'));
      fuente.funciones['fin_repartos_anulados_con_movimientos'] = (_) => [
        {
          'dispersion_id': 'a1',
          'libro_id': _libro,
          'movimiento_id': 'm-a1',
          'movimientos_vigentes': 1,
        },
      ];
      await reparto.cargar();
      final m = _mundo(reparto: reparto);
      final hechas = await m.servicio.emitirAvisosRepartosAnulados(_libro);
      expect(hechas, {claveAvisoRepartoAnulado('m-a1')});
      expect(m.repo.avisosEmitidos, hasLength(1));
      final a = m.repo.avisosEmitidos.single;
      expect(a.tipo, 'ingreso_anulado_con_reparto');
      expect(a.objetoTipo, 'movimiento');
      expect(a.objetoId, 'm-a1');
      expect(a.clave, 'ingreso:m-a1:anulado_con_reparto');
      expect(a.clave, isNot(matches(r'\d{3,}')), reason: 'sin cifras');
    });
  });

  for (final e in {
    'teléfono': (TipoDispositivo.telefono, const Size(360, 800)),
    'laptop': (TipoDispositivo.laptop, const Size(1100, 800)),
  }.entries) {
    group('Tarjeta «Ingreso anulado con reparto» en ${e.key}', () {
      /// Un ingreso repartido y anulado (su reparto «anulado»), en el libro
      /// [libro] si se pide (el de Papá), y la pantalla lista para verlo.
      Future<({String id, Dispersion d, String libro})> preparar(
        WidgetTester tester, {
        double letra = 1.0,
        Rol rol = Rol.dueno,
        bool papa = false,
        bool anular = true,
      }) async {
        final repo = await montarFinanzasConTamano(
          tester,
          dispositivo: e.value.$1,
          tamano: e.value.$2,
          escalaDeLetra: letra,
          rol: rol,
        );
        final c = _contenedor(tester);
        if (papa) {
          c.read(libroElegidoProvider.notifier).elegir(_papa);
          await avanzar(tester);
        }
        final ctx = c.read(contextoFinanzasProvider).value!;
        final base = servicioDe(repo, sesionDe(Rol.dueno));
        final r = await base.registrarIngresoExtra(
          libroId: ctx.libroId,
          monto: 900000,
          cuentaDestinoId: ctx.datos
              .cuentasDe(ctx.libroId)
              .firstWhere((x) => x.tipo == TipoCuenta.banco)
              .id,
          fecha: _viernesPasado,
          nota: 'Sueldo',
          motivo: papa ? 'Apoyo del hermano' : null,
        );
        final ahorro = await base.crearCuenta(
          libroId: ctx.libroId,
          nombre: 'Mi ahorro',
          tipo: TipoCuenta.ahorro,
        );
        await avanzar(tester);
        c.read(montosVisiblesProvider.notifier).fijar(true);
        final servicio = c.read(servicioDispersionProvider);
        final id = r.movimientos.single.id;
        final ingreso = servicio
            .ingresos(ctx.libroId)
            .firstWhere((i) => i.movimientoId == id);
        final d = await servicio.aceptar(
          ingreso: ingreso,
          propuesta: servicio.proponer(ingreso),
          cuentaAhorroId: ahorro.id,
          motivo: papa ? 'Reparto del apoyo' : null,
        );
        if (anular) {
          await base.anular(id, motivo: 'Lo registré dos veces');
          await c
              .read(repositorioDispersionesProvider)
              .guardar(d.conEstado(EstadoDispersion.anulada));
        }
        await avanzar(tester);
        await irA(
          tester,
          e.value.$1 == TipoDispositivo.laptop
              ? SeccionFinanzas.tablero.ruta
              : SeccionFinanzas.semana.ruta,
        );
        return (id: id, d: d, libro: ctx.libroId);
      }

      final tarjeta = find.byKey(
        const ValueKey('finanzas-ingreso-anulado-reparto'),
      );

      testWidgets('sin ingreso anulado no hay tarjeta', (tester) async {
        await preparar(tester, anular: false);
        expect(tarjeta, findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('con un ingreso anulado que estaba repartido la tarjeta '
          'avisa con el texto del dueño y ofrece las dos acciones', (
        tester,
      ) async {
        final (:id, :d, :libro) = await preparar(tester);
        await tester.ensureVisible(tarjeta);
        expect(tarjeta, findsOneWidget);
        expect(
          find.text(
            'Anulaste un ingreso que ya estaba repartido. '
            'Los movimientos del reparto siguen vigentes.',
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('anulado-deshacer-${d.id}')),
          findsOneWidget,
        );
        expect(find.byKey(ValueKey('anulado-dejar-${d.id}')), findsOneWidget);
        expect(find.text('Deshacer reparto'), findsOneWidget);
        expect(find.text('Dejarlo así'), findsOneWidget);
        // Mientras no se elige, el dinero no se toca.
        final c = _contenedor(tester);
        final ctx = c.read(contextoFinanzasProvider).value!;
        for (final h in _movimientosDe(d)) {
          expect(ctx.datos.vista(libro).estaAnulado(h), isFalse);
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets('«Dejarlo así» oculta la tarjeta sin tocar dinero', (
        tester,
      ) async {
        final (:id, :d, :libro) = await preparar(tester);
        final c = _contenedor(tester);
        final antes = c
            .read(contextoFinanzasProvider)
            .value!
            .datos
            .movimientos
            .length;
        final boton = find.byKey(ValueKey('anulado-dejar-${d.id}'));
        await tester.ensureVisible(boton);
        await tester.tap(boton);
        await avanzar(tester);
        expect(tarjeta, findsNothing);
        expect(
          c.read(contextoFinanzasProvider).value!.datos.movimientos.length,
          antes,
        );
        for (final h in _movimientosDe(d)) {
          expect(
            c
                .read(contextoFinanzasProvider)
                .value!
                .datos
                .vista(libro)
                .estaAnulado(h),
            isFalse,
          );
        }
        expect(find.textContaining('lo dejé así'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('«Deshacer reparto» anula los movimientos del reparto y '
          'oculta la tarjeta', (tester) async {
        final (:id, :d, :libro) = await preparar(tester);
        final boton = find.byKey(ValueKey('anulado-deshacer-${d.id}'));
        await tester.ensureVisible(boton);
        await tester.tap(boton);
        await avanzar(tester);
        expect(tarjeta, findsNothing);
        final c = _contenedor(tester);
        final vista = c
            .read(contextoFinanzasProvider)
            .value!
            .datos
            .vista(libro);
        for (final h in _movimientosDe(d)) {
          expect(vista.estaAnulado(h), isTrue);
        }
        expect(find.textContaining('deshice el reparto'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('sin cifras: con los montos ocultos (y visibles) la tarjeta '
          'no dice montos, ni en el lector de pantalla', (tester) async {
        final semantica = tester.ensureSemantics();
        await preparar(tester);
        final c = _contenedor(tester);
        for (final visibles in [false, true]) {
          c.read(montosVisiblesProvider.notifier).fijar(visibles);
          await tester.pump();
          await tester.ensureVisible(tarjeta);
          expect(
            find.descendant(of: tarjeta, matching: find.textContaining(r'$')),
            findsNothing,
          );
          final textos = tester
              .widgetList<Text>(
                find.descendant(of: tarjeta, matching: find.byType(Text)),
              )
              .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '');
          for (final t in textos) {
            expect(t, isNot(matches(r'\d[\d,]*\.\d{2}')), reason: t);
          }
          final s = tester.getSemantics(tarjeta);
          expect(s.label, isNot(contains(r'$')));
          expect(s.label, isNot(matches(r'\d[\d,]*\.\d{2}')));
        }
        semantica.dispose();
      });

      testWidgets('letra grande: no se desborda y los botones quedan a la '
          'vista', (tester) async {
        final (:id, :d, :libro) = await preparar(tester, letra: 2.0);
        final errores = await recolectar(() async {
          await tester.ensureVisible(
            find.byKey(ValueKey('anulado-deshacer-${d.id}')),
          );
          await tester.pump();
        });
        expect(
          errores.desbordes,
          isEmpty,
          reason: errores.desbordes.join('\n'),
        );
        expect(find.byKey(ValueKey('anulado-dejar-${d.id}')), findsOneWidget);
      });

      testWidgets('en el libro de Papá «Deshacer reparto» pide el motivo '
          'antes de anular nada', (tester) async {
        final (:id, :d, :libro) = await preparar(tester, papa: true);
        expect(libro, _papa);
        final boton = find.byKey(ValueKey('anulado-deshacer-${d.id}'));
        await tester.ensureVisible(boton);
        await tester.tap(boton);
        await tester.pumpAndSettle();
        // Un diálogo pide el motivo; mientras no lo escribe no se anula nada.
        expect(find.text('Motivo (obligatorio)'), findsOneWidget);
        final c = _contenedor(tester);
        for (final h in _movimientosDe(d)) {
          expect(
            c
                .read(contextoFinanzasProvider)
                .value!
                .datos
                .vista(libro)
                .estaAnulado(h),
            isFalse,
          );
        }
        // Cancelar no anula nada.
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(tarjeta, findsOneWidget);
        // Con motivo, sí.
        await tester.tap(boton);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField).last,
          'Anulé la pensión: deshago el reparto',
        );
        await tester.pump();
        await tester.tap(find.text('Deshacer reparto').last);
        await avanzar(tester);
        expect(tarjeta, findsNothing);
        final vista = c
            .read(contextoFinanzasProvider)
            .value!
            .datos
            .vista(libro);
        for (final h in _movimientosDe(d)) {
          expect(vista.estaAnulado(h), isTrue);
        }
        expect(tester.takeException(), isNull);
      });
    });
  }

  test('el texto de la tarjeta es el que pidió el dueño', () {
    expect(
      textoIngresoAnuladoConReparto,
      'Anulaste un ingreso que ya estaba repartido. '
      'Los movimientos del reparto siguen vigentes.',
    );
  });
}
