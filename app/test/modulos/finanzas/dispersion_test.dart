// Fase 8 (F8-6.4): dispersión de ingresos con confirmación
// (docs/specs/fase-8-finanzas-dispersion.md). Servicio, «Quedan» con lo por
// repartir, la hoja «Repartir ingreso» y «Cambiar tipo…» en teléfono y
// laptop. Datos de ejemplo inventados.
import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide Semaforo, formatearCentavos, TipoLibro, puntosBaseEnCien;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/diseno/diseno.dart'
    show formatearCentavos, montosVisiblesProvider;
import 'package:gravity/modulos/finanzas/casos_uso/servicio_dispersion.dart';
import 'package:gravity/modulos/finanzas/casos_uso/servicio_finanzas.dart';
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/modulos/finanzas/datos/ids.dart'
    show ClavesId, claveDeLineaDispersion, idEstable;
import 'package:gravity/modulos/finanzas/datos/repositorio.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_dispersiones.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_memoria.dart';
import 'package:gravity/modulos/finanzas/estado/proveedores.dart';
import 'package:gravity/modulos/finanzas/estado/proveedores_dispersion.dart';
import 'package:gravity/modulos/finanzas/estado/resumen_hoy.dart';
import 'package:gravity/modulos/finanzas/finanzas.dart' show SeccionFinanzas;
import 'package:gravity/modulos/finanzas/pantallas/tarjeta_hoy.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart'
    show hogarDeEjemplo;

import '../../revision_calidad/ayuda_calidad.dart';
import 'ayuda_finanzas.dart';

const _libro = IdsDemostracion.libroDueno;
const _papa = IdsDemostracion.libroPapa;

/// Viernes de la semana anterior a "hoy" (martes 20/oct/2026): el caso del
/// dueño con su sueldo del viernes 13/nov, trasladado a las fechas de prueba.
final _viernesPasado = Fecha(2026, 10, 16);

class _Mundo {
  _Mundo(this.repo, this.finanzas, this.reparto, this.servicio);

  final RepositorioFinanzasEnMemoria repo;
  final ServicioFinanzas finanzas;
  final RepositorioDispersionesEnMemoria reparto;
  final ServicioDispersion servicio;

  DatosFinanzas get datos => repo.datos;
}

_Mundo _mundo({bool soloLectura = false}) {
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
  final reparto = RepositorioDispersionesEnMemoria();
  return _Mundo(
    repo,
    finanzas,
    reparto,
    ServicioDispersion(finanzas: finanzas, repositorio: reparto),
  );
}

String _banco(_Mundo m, String libro) =>
    m.datos.cuentasDe(libro).firstWhere((c) => c.tipo == TipoCuenta.banco).id;

/// El sueldo del viernes pasado, registrado como «ingreso extra».
Future<String> _sueldoComoExtra(_Mundo m, {int monto = 900000}) async {
  final r = await m.finanzas.registrarIngresoExtra(
    libroId: _libro,
    monto: monto,
    cuentaDestinoId: _banco(m, _libro),
    fecha: _viernesPasado,
    nota: 'Sueldo',
  );
  return r.movimientos.single.id;
}

Future<Deuda> _tarjeta(_Mundo m, {int saldo = 300000}) async {
  final cuenta = await m.finanzas.crearCuenta(
    libroId: _libro,
    nombre: 'Tarjeta de ejemplo',
    tipo: TipoCuenta.tarjeta,
    saldoInicial: saldo,
    limiteCentavos: 1000000,
  );
  final d = Deuda(
    id: m.finanzas.nuevoId(),
    libroId: _libro,
    nombre: 'Tarjeta de ejemplo',
    tipo: TipoDeuda.conCosto,
    clase: ClaseDeuda.tarjeta,
    cuentaPasivoId: cuenta.id,
    abono: 50000,
    minimo: 15000,
    frecuencia: Frecuencia.mensual,
    calendario: const CalendarioConfig.mensual([
      25,
    ], regla: ReglaDiaInhabil.sinCambio),
    tasaAnualPuntosBase: 4500,
  );
  await m.finanzas.guardarDeuda(d);
  return d;
}

Future<Cuenta> _ahorro(_Mundo m) => m.finanzas.crearCuenta(
  libroId: _libro,
  nombre: 'Mi ahorro',
  tipo: TipoCuenta.ahorro,
);

IngresoPorRepartir _ingreso(_Mundo m, String movimientoId) => m.servicio
    .ingresos(_libro)
    .firstWhere((i) => i.movimientoId == movimientoId);

ProviderContainer _contenedor(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(AppGravity)));

void main() {
  group('Servicio: estados y arrastre', () {
    test('el sueldo registrado como extra pide reparto y se arrastra a la '
        'semana actual', () async {
      final m = _mundo();
      final id = await _sueldoComoExtra(m);
      final lista = m.servicio.ingresos(_libro);
      expect(lista, hasLength(1));
      expect(lista.single.estado, EstadoDispersion.porRepartir);
      expect(lista.single.pendiente, 900000);
      expect(lista.single.esSueldo, isFalse);
      expect(lista.single.movimientoId, id);
      final hoy = Fecha.deDateTime(ahoraDePrueba);
      expect(
        porRepartirArrastrado(lista, semana: Semana.de(hoy), hoy: hoy),
        900000,
      );
      expect(
        porRepartirArrastrado(lista, semana: Semana.de(hoy).anterior, hoy: hoy),
        0,
      );
    });

    test('lo anterior a la semana pasada se da por repartido', () async {
      final m = _mundo();
      await m.finanzas.registrarIngresoExtra(
        libroId: _libro,
        monto: 50000,
        cuentaDestinoId: _banco(m, _libro),
        fecha: Fecha(2026, 10, 5),
      );
      expect(m.servicio.ingresos(_libro), isEmpty);
    });

    test('la propuesta de un extra repasa la deuda y el ahorro y suma el '
        'monto', () async {
      final m = _mundo();
      final deuda = await _tarjeta(m);
      await _ahorro(m);
      final id = await _sueldoComoExtra(m);
      final p = m.servicio.proponer(_ingreso(m, id));
      expect(p.totalRepartido + p.quedaPorRepartir, 900000);
      expect(p.quedaPorRepartir, 0);
      // Un extra: sin presupuesto ni pagos apartados; abono extra topado por
      // el saldo de la tarjeta y el resto, a ahorro.
      expect(p.partidas, isEmpty);
      expect(p.pagosDeuda, isEmpty);
      expect(
        p.abonosExtra.where((l) => l.referenciaId == deuda.id).single.monto,
        300000,
      );
      expect(p.ahorro, 600000);
    });
  });

  group('Servicio: aceptar, dejar para después y deshacer', () {
    test('aceptar crea el abono extra y el ahorro con ids estables, y repetir '
        'no duplica', () async {
      final m = _mundo();
      final deuda = await _tarjeta(m);
      final ahorro = await _ahorro(m);
      final id = await _sueldoComoExtra(m);
      final ingreso = _ingreso(m, id);
      final propuesta = m.servicio.proponer(ingreso);
      final antes = m.datos.movimientos.length;

      final d = await m.servicio.aceptar(
        ingreso: ingreso,
        propuesta: propuesta,
        cuentaAhorroId: ahorro.id,
      );
      expect(d.estado, EstadoDispersion.confirmada);
      expect(m.datos.movimientos.length, antes + 2);
      final pago = m.datos.movimientos.firstWhere(
        (x) => x.tipo == TipoMovimiento.pagoDeuda && x.nota != null,
      );
      expect(pago.monto, 300000);
      expect(pago.cuentaOrigenId, _banco(m, _libro));
      expect(pago.cuentaDestinoId, deuda.cuentaPasivoId);
      expect(
        pago.id,
        idEstable(ClavesId.dispersionMovimiento(d.id, 'extra:${deuda.id}')),
      );
      final transf = m.datos.movimientos.firstWhere(
        (x) => x.cuentaDestinoId == ahorro.id,
      );
      expect(transf.tipo, TipoMovimiento.transferencia);
      expect(transf.monto, 600000);
      expect(
        transf.id,
        idEstable(ClavesId.dispersionMovimiento(d.id, 'ahorro')),
      );

      // Repetir Aceptar avisa y no duplica nada.
      await expectLater(
        m.servicio.aceptar(
          ingreso: ingreso,
          propuesta: propuesta,
          cuentaAhorroId: ahorro.id,
        ),
        throwsA(isA<ErrorFinanzas>()),
      );
      expect(m.datos.movimientos.length, antes + 2);
      // Ya no hay nada por repartir.
      expect(
        m.servicio.ingresos(_libro).single.estado,
        EstadoDispersion.confirmada,
      );
      expect(m.servicio.ingresos(_libro).single.pendiente, 0);
    });

    test('lo que no se reparte queda por repartir y se arrastra', () async {
      final m = _mundo();
      await _tarjeta(m);
      final id = await _sueldoComoExtra(m);
      final ingreso = _ingreso(m, id);
      var p = m.servicio.proponer(ingreso);
      final i = p.lineas.indexWhere(
        (l) => l.destino == DestinoLinea.abonoExtra,
      );
      p = p.editar(i, 100000);
      // El ahorro sin cuenta se quita; todo lo demás queda por repartir.
      final j = p.lineas.indexWhere((l) => l.destino == DestinoLinea.ahorro);
      if (j >= 0) p = p.editar(j, 0);
      await m.servicio.aceptar(ingreso: ingreso, propuesta: p);
      final despues = m.servicio.ingresos(_libro).single;
      expect(despues.estado, EstadoDispersion.confirmada);
      expect(despues.pendiente, 800000);
      final hoy = Fecha.deDateTime(ahoraDePrueba);
      expect(
        porRepartirArrastrado(
          m.servicio.ingresos(_libro),
          semana: Semana.de(hoy),
          hoy: hoy,
        ),
        800000,
      );
    });

    test('con ahorro y sin cuenta de ahorro, aceptar pide elegirla', () async {
      final m = _mundo();
      final id = await _sueldoComoExtra(m);
      final ingreso = _ingreso(m, id);
      final p = m.servicio.proponer(ingreso);
      expect(p.ahorro, 900000, reason: 'sin deuda, todo va a ahorro');
      await expectLater(
        m.servicio.aceptar(ingreso: ingreso, propuesta: p),
        throwsA(isA<ErrorFinanzas>()),
      );
    });

    test('dejar para después no crea movimientos; editada queda como '
        'propuesta y se reabre con sus ediciones', () async {
      final m = _mundo();
      await _tarjeta(m);
      final id = await _sueldoComoExtra(m);
      final ingreso = _ingreso(m, id);
      final antes = m.datos.movimientos.length;
      await m.servicio.dejarParaDespues(ingreso: ingreso);
      expect(m.datos.movimientos.length, antes);
      expect(
        m.servicio.ingresos(_libro).single.estado,
        EstadoDispersion.porRepartir,
      );

      var p = m.servicio.proponer(ingreso);
      final i = p.lineas.indexWhere(
        (l) => l.destino == DestinoLinea.abonoExtra,
      );
      p = p.editar(i, 50000);
      await m.servicio.dejarParaDespues(ingreso: ingreso, propuestaEditada: p);
      expect(m.datos.movimientos.length, antes);
      final guardado = m.servicio.ingresos(_libro).single;
      expect(guardado.estado, EstadoDispersion.propuesta);
      expect(guardado.pendiente, 900000, reason: 'sigue por repartir completo');
      final reabierta = m.servicio.proponer(guardado);
      expect(reabierta.totalAbonoExtra, 50000);
    });

    test(
      'deshacer anula los movimientos y el ingreso vuelve a por repartir',
      () async {
        final m = _mundo();
        await _tarjeta(m);
        final ahorro = await _ahorro(m);
        final id = await _sueldoComoExtra(m);
        final ingreso = _ingreso(m, id);
        final d = await m.servicio.aceptar(
          ingreso: ingreso,
          propuesta: m.servicio.proponer(ingreso),
          cuentaAhorroId: ahorro.id,
        );
        await m.servicio.deshacer(d.id);
        final libro = m.datos.vista(_libro);
        final creados = m.datos.movimientos.where(
          (x) =>
              x.tipo == TipoMovimiento.pagoDeuda ||
              x.cuentaDestinoId == ahorro.id,
        );
        expect(creados, isNotEmpty);
        expect(creados.every((x) => libro.estaAnulado(x.id)), isTrue);
        final i = m.servicio.ingresos(_libro).single;
        expect(i.estado, EstadoDispersion.porRepartir);
        expect(i.pendiente, 900000);
        // Y se puede volver a repartir con otro intento.
        final otra = await m.servicio.aceptar(
          ingreso: i,
          propuesta: m.servicio.proponer(i),
          cuentaAhorroId: ahorro.id,
        );
        expect(otra.id, isNot(d.id));
      },
    );
  });

  group('Servicio: permisos y libro de Papá', () {
    test(
      'sin permiso de escribir no se acepta ni se deja para después',
      () async {
        final m = _mundo();
        final id = await _sueldoComoExtra(m);
        final ingreso = _ingreso(m, id);
        final propuesta = m.servicio.proponer(ingreso);
        final lector = ServicioDispersion(
          finanzas: ServicioFinanzas(
            repositorio: m.repo,
            personaId: sesionDe(Rol.dueno).persona.id,
            soloLectura: true,
            reloj: () => ahoraDePrueba,
          ),
          repositorio: m.reparto,
        );
        await expectLater(
          lector.aceptar(ingreso: ingreso, propuesta: propuesta),
          throwsA(isA<ErrorFinanzas>()),
        );
        await expectLater(
          lector.dejarParaDespues(
            ingreso: ingreso,
            propuestaEditada: propuesta,
          ),
          throwsA(isA<ErrorFinanzas>()),
        );
        await expectLater(
          lector.cambiarTipo(
            movimientoId: id,
            cuentaOrigenId: 'x',
            motivo: 'Era el sueldo',
          ),
          throwsA(isA<ErrorFinanzas>()),
        );
        expect(m.reparto.actuales, isEmpty);
      },
    );

    test(
      'en el libro de Papá el albacea confirma en su nombre y con motivo',
      () async {
        final m = _mundo();
        final bancoPapa = _banco(m, _papa);
        final r = await m.finanzas.registrarIngresoExtra(
          libroId: _papa,
          monto: 200000,
          cuentaDestinoId: bancoPapa,
          fecha: _viernesPasado,
          motivo: 'Apoyo del hermano',
        );
        final ingreso = m.servicio
            .ingresos(_papa)
            .firstWhere((i) => i.movimientoId == r.movimientos.single.id);
        var p = m.servicio.proponer(ingreso);
        // Sin cuenta de ahorro en su libro: ese dinero queda por repartir.
        final j = p.lineas.indexWhere((l) => l.destino == DestinoLinea.ahorro);
        if (j >= 0) p = p.editar(j, 0);
        await expectLater(
          m.servicio.aceptar(ingreso: ingreso, propuesta: p),
          throwsA(isA<ErrorFinanzas>()),
          reason: 'el libro de Papá exige motivo',
        );
        final d = await m.servicio.aceptar(
          ingreso: ingreso,
          propuesta: p,
          motivo: 'Reparto del apoyo',
        );
        expect(d.enNombreDe, isNotNull);
        expect(d.motivo, 'Reparto del apoyo');
      },
    );
  });

  group('Servicio: modo automático (pregunta abierta P1)', () {
    test(
      'asigna lo comprometido y no mueve dinero ni toca el remanente',
      () async {
        final m = _mundo();
        await m.reparto.guardarParametros(
          _libro,
          ParametrosDispersion(
            modo: ModoDispersion.automatico,
            desde: Fecha(2026, 10, 12),
          ),
        );
        // Un sueldo del ingreso configurado (Honorarios) cubre su parte.
        final honorarios = m.datos
            .ingresosDe(_libro)
            .firstWhere((i) => i.nombre.startsWith('Honorarios'));
        final r = await m.finanzas.registrarMovimiento(
          tipo: TipoMovimiento.ingreso,
          cuentaOrigenId: honorarios.cuentaOrigenId,
          cuentaDestinoId: honorarios.cuentaDestinoId,
          monto: honorarios.vigenciaActual!.montoNeto,
          fecha: _viernesPasado,
        );
        final antes = m.datos.movimientos.length;
        final hechos = await m.servicio.aplicarAutomaticas(_libro);
        expect(m.datos.movimientos.length, antes, reason: 'no mueve dinero');
        final i = m.servicio
            .ingresos(_libro)
            .firstWhere((x) => x.movimientoId == r.movimientos.single.id);
        if (hechos == 1) {
          expect(i.estado, EstadoDispersion.automatica);
          expect(m.reparto.actuales.single.modo, ModoDispersion.automatico);
          expect(
            m.reparto.actuales.single.lineas.any((l) => l.destino.mueveDinero),
            isFalse,
          );
        } else {
          // No cubre todo: queda por repartir, nada se aplica solo.
          expect(i.estado, EstadoDispersion.porRepartir);
        }
      },
    );

    test('con confirmación (por omisión) no hace nada', () async {
      final m = _mundo();
      await _sueldoComoExtra(m);
      expect(await m.servicio.aplicarAutomaticas(_libro), 0);
      expect(m.reparto.actuales, isEmpty);
    });
  });

  group('Servicio: corregir el tipo de un ingreso', () {
    test('el sueldo pasa de extra a ingreso configurado sin perder el '
        'historial', () async {
      final m = _mundo();
      final id = await _sueldoComoExtra(m);
      final honorarios = m.datos
          .ingresosDe(_libro)
          .firstWhere((i) => i.nombre.startsWith('Honorarios'));
      final saldoAntes = m.datos
          .vista(_libro)
          .saldo(honorarios.cuentaDestinoId);
      final semana = Semana.de(_viernesPasado);
      expect(extrasDeLaSemana(m.datos, _libro, semana), 900000);

      final c = await m.servicio.cambiarTipo(
        movimientoId: id,
        cuentaOrigenId: honorarios.cuentaOrigenId,
        motivo: 'Era mi sueldo, no un extra',
      );
      expect(c.anulacion.anulaA, id);
      expect(c.nuevo.fecha, _viernesPasado);
      expect(c.nuevo.monto, 900000);
      expect(
        m.datos.movimientos.any((x) => x.id == id),
        isTrue,
        reason: 'el original no se borra',
      );
      final vista = m.datos.vista(_libro);
      expect(vista.estaAnulado(id), isTrue);
      expect(vista.saldo(honorarios.cuentaDestinoId), saldoAntes);
      expect(extrasDeLaSemana(m.datos, _libro, semana), 0);
      final i = m.servicio.ingresos(_libro).single;
      expect(i.esSueldo, isTrue);
      expect(i.estado, EstadoDispersion.porRepartir);
      expect(i.movimientoId, c.nuevo.id);
      // Una vez más no: ya está anulado.
      await expectLater(
        m.servicio.cambiarTipo(
          movimientoId: id,
          cuentaOrigenId: honorarios.cuentaOrigenId,
          motivo: 'Otra vez el mismo',
        ),
        throwsA(isA<ErrorFinanzas>()),
      );
    });

    test('exige motivo y, si el ingreso ya está repartido, deshace su reparto '
        'al corregirlo (P5)', () async {
      final m = _mundo();
      final ahorro = await _ahorro(m);
      final id = await _sueldoComoExtra(m);
      final honorarios = m.datos
          .ingresosDe(_libro)
          .firstWhere((i) => i.nombre.startsWith('Honorarios'));
      await expectLater(
        m.servicio.cambiarTipo(
          movimientoId: id,
          cuentaOrigenId: honorarios.cuentaOrigenId,
          motivo: ' ',
        ),
        throwsA(isA<ErrorFinanzas>()),
      );
      final ingreso = _ingreso(m, id);
      await m.servicio.aceptar(
        ingreso: ingreso,
        propuesta: m.servicio.proponer(ingreso),
        cuentaAhorroId: ahorro.id,
      );
      final repartido = m.servicio.repartoAplicadoDe(id)!;
      final movimientosDelReparto = [
        for (final l in repartido.lineas)
          if (l.destino.mueveDinero)
            idEstable(
              ClavesId.dispersionMovimiento(
                repartido.id,
                claveDeLineaDispersion(l),
              ),
            ),
      ];
      expect(movimientosDelReparto, isNotEmpty);
      final c = await m.servicio.cambiarTipo(
        movimientoId: id,
        cuentaOrigenId: honorarios.cuentaOrigenId,
        motivo: 'Era el sueldo',
      );
      // Sin movimientos huérfanos: lo que creó el reparto queda anulado.
      final vista = m.datos.vista(_libro);
      for (final mid in movimientosDelReparto) {
        expect(vista.estaAnulado(mid), isTrue);
      }
      expect(m.servicio.repartoAplicadoDe(id), isNull);
      expect(
        m.reparto.actuales.firstWhere((x) => x.id == repartido.id).estado,
        EstadoDispersion.anulada,
      );
      // El ingreso nuevo nace por repartir y se reparte como sueldo.
      final nuevo = _ingreso(m, c.nuevo.id);
      expect(nuevo.estado, EstadoDispersion.porRepartir);
      expect(nuevo.esSueldo, isTrue);
    });
  });

  group('«Quedan» con lo por repartir', () {
    testWidgets('Hoy y Mi semana suman lo por repartir al centavo', (
      tester,
    ) async {
      final repo = await montarFinanzasConTamano(
        tester,
        dispositivo: TipoDispositivo.telefono,
        tamano: const Size(360, 800),
      );
      final c = _contenedor(tester);
      final base = servicioDe(repo, sesionDe(Rol.dueno));
      final ctx = c.read(contextoFinanzasProvider).value!;
      final antes = c.read(cifrasMiSemanaProvider)!;
      expect(antes.porRepartir, 0);

      await base.registrarIngresoExtra(
        libroId: ctx.libroId,
        monto: 900000,
        cuentaDestinoId: ctx.datos
            .cuentasDe(ctx.libroId)
            .firstWhere((x) => x.tipo == TipoCuenta.banco)
            .id,
        fecha: _viernesPasado,
      );
      await avanzar(tester);
      final despues = c.read(cifrasMiSemanaProvider)!;
      expect(despues.porRepartir, 900000);
      expect(despues.disponible, antes.disponible);
      expect(despues.quedan, antes.disponible + 900000);
      final hoy = c
          .read(resumenFinanzasHoyProvider)
          .libros
          .firstWhere((l) => l.libroId == ctx.libroId)
          .cifras;
      expect(hoy, despues, reason: 'Hoy y Mi semana dan lo mismo');
    });

    testWidgets('la tarjeta de Hoy dice Quedan con lo por repartir y la '
        'línea Por repartir; con montos ocultos no hay cifras', (tester) async {
      final repo = await montarFinanzasConTamano(
        tester,
        dispositivo: TipoDispositivo.telefono,
        tamano: const Size(360, 800),
      );
      final c = _contenedor(tester);
      final base = servicioDe(repo, sesionDe(Rol.dueno));
      final ctx = c.read(contextoFinanzasProvider).value!;
      await base.registrarIngresoExtra(
        libroId: ctx.libroId,
        monto: 900000,
        cuentaDestinoId: ctx.datos
            .cuentasDe(ctx.libroId)
            .firstWhere((x) => x.tipo == TipoCuenta.banco)
            .id,
        fecha: _viernesPasado,
      );
      await avanzar(tester);
      c.read(montosVisiblesProvider.notifier).fijar(true);
      await tester.pump();
      final cifras = c.read(cifrasMiSemanaProvider)!;
      final tarjeta = await _montarTarjeta(tester);
      final quedan = find.byKey(ValueKey('finanzas-hoy-quedan-${ctx.libroId}'));
      expect(quedan, findsOneWidget);
      expect(
        find.descendant(
          of: quedan,
          matching: find.text(_formato(cifras.quedan)),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('finanzas-hoy-por-repartir-${ctx.libroId}')),
        findsOneWidget,
      );
      expect(tarjeta, isNotNull);
      c.read(montosVisiblesProvider.notifier).fijar(false);
      await tester.pump();
      expect(
        find.descendant(
          of: find.byKey(ValueKey('finanzas-hoy-por-repartir-${ctx.libroId}')),
          matching: find.textContaining(r'$'),
        ),
        findsNothing,
      );
    });
  });

  for (final e in {
    'teléfono': (TipoDispositivo.telefono, const Size(360, 800)),
    'laptop': (TipoDispositivo.laptop, const Size(1100, 800)),
  }.entries) {
    group('Pantallas en ${e.key}', () {
      Future<(RepositorioFinanzasEnMemoria, String)> preparar(
        WidgetTester tester, {
        double letra = 1.0,
        Rol rol = Rol.dueno,
      }) async {
        final repo = await montarFinanzasConTamano(
          tester,
          dispositivo: e.value.$1,
          tamano: e.value.$2,
          escalaDeLetra: letra,
          rol: rol,
        );
        final ctx = _contenedor(tester).read(contextoFinanzasProvider).value!;
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
        );
        _contenedor(tester).read(montosVisiblesProvider.notifier).fijar(true);
        return (repo, r.movimientos.single.id);
      }

      Future<void> ir(WidgetTester tester) => irA(
        tester,
        e.value.$1 == TipoDispositivo.laptop
            ? SeccionFinanzas.tablero.ruta
            : SeccionFinanzas.semana.ruta,
      );

      testWidgets('la tarjeta Por repartir muestra el estado y el total', (
        tester,
      ) async {
        final (_, id) = await preparar(tester);
        await ir(tester);
        expect(
          find.byKey(const ValueKey('finanzas-por-repartir')),
          findsOneWidget,
        );
        expect(find.byKey(ValueKey('por-repartir-estado-$id')), findsOneWidget);
        expect(find.text('Por repartir'), findsWidgets);
        expect(
          find.byKey(const ValueKey('por-repartir-total')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('Repartir abre la hoja y Aceptar la aplica', (tester) async {
        final (repo, id) = await preparar(tester);
        final base = servicioDe(repo, sesionDe(Rol.dueno));
        final ctx = _contenedor(tester).read(contextoFinanzasProvider).value!;
        await base.crearCuenta(
          libroId: ctx.libroId,
          nombre: 'Mi ahorro',
          tipo: TipoCuenta.ahorro,
        );
        await avanzar(tester);
        await ir(tester);
        final boton = find.byKey(ValueKey('por-repartir-repartir-$id'));
        await tester.ensureVisible(boton);
        await tester.pumpAndSettle();
        await tester.tap(boton);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('repartir-aceptar')), findsOneWidget);
        expect(find.byKey(const ValueKey('repartir-editar')), findsOneWidget);
        expect(find.byKey(const ValueKey('repartir-despues')), findsOneWidget);
        expect(find.byKey(const ValueKey('repartir-queda')), findsOneWidget);
        final antes = repo.datos.movimientos.length;
        await tester.tap(find.byKey(const ValueKey('repartir-aceptar')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('repartir-aceptar')), findsNothing);
        expect(repo.datos.movimientos.length, greaterThan(antes));
        expect(find.byKey(ValueKey('por-repartir-$id')), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Editar deja quitar un renglón y queda por repartir', (
        tester,
      ) async {
        final (repo, id) = await preparar(tester);
        final base = servicioDe(repo, sesionDe(Rol.dueno));
        final ctx = _contenedor(tester).read(contextoFinanzasProvider).value!;
        await base.crearCuenta(
          libroId: ctx.libroId,
          nombre: 'Mi ahorro',
          tipo: TipoCuenta.ahorro,
        );
        await avanzar(tester);
        await ir(tester);
        final boton = find.byKey(ValueKey('por-repartir-repartir-$id'));
        await tester.ensureVisible(boton);
        await tester.pumpAndSettle();
        await tester.tap(boton);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('repartir-editar')));
        await tester.pumpAndSettle();
        final campo = find.byKey(const ValueKey('repartir-linea-0'));
        expect(campo, findsOneWidget);
        await tester.enterText(campo, '0');
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('repartir-error')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('repartir-despues')));
        await tester.pumpAndSettle();
        // Sin movimientos nuevos; el ingreso sigue pendiente con su propuesta.
        final lista = _contenedor(tester).read(ingresosPendientesProvider);
        expect(lista.single.estado, EstadoDispersion.propuesta);
        expect(lista.single.pendiente, 900000);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Cambiar tipo pasa el extra a ingreso configurado', (
        tester,
      ) async {
        final (repo, id) = await preparar(tester);
        await ir(tester);
        final boton = find.byKey(ValueKey('por-repartir-tipo-$id'));
        await tester.ensureVisible(boton);
        await tester.pumpAndSettle();
        await tester.tap(boton);
        await tester.pumpAndSettle();
        final honorarios = repo.datos
            .ingresosDe(_libro)
            .firstWhere((i) => i.nombre.startsWith('Honorarios'));
        await tester.tap(
          find.byKey(ValueKey('cambiar-tipo-${honorarios.cuentaOrigenId}')),
        );
        await tester.pump();
        await tester.enterText(
          find.byKey(const ValueKey('cambiar-tipo-motivo')),
          'Era mi sueldo',
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('cambiar-tipo-guardar')));
        await tester.pumpAndSettle();
        expect(repo.datos.vista(_libro).estaAnulado(id), isTrue);
        final nuevo = _contenedor(tester).read(ingresosPendientesProvider);
        expect(nuevo.single.esSueldo, isTrue);
        expect(tester.takeException(), isNull);
      });

      testWidgets('letra grande: la hoja no se desborda y deja las acciones '
          'a la vista', (tester) async {
        final (_, id) = await preparar(tester, letra: 2.0);
        await ir(tester);
        final errores = await recolectar(() async {
          final boton = find.byKey(ValueKey('por-repartir-repartir-$id'));
          await tester.ensureVisible(boton);
          await tester.pumpAndSettle();
          await tester.tap(boton);
          await tester.pumpAndSettle();
        });
        expect(
          errores.desbordes,
          isEmpty,
          reason: errores.desbordes.join('\n'),
        );
        expect(find.byKey(const ValueKey('repartir-aceptar')), findsOneWidget);
        final r = tester.getRect(
          find.byKey(const ValueKey('repartir-aceptar')),
        );
        expect(r.bottom, lessThanOrEqualTo(e.value.$2.height));
      });

      testWidgets('con los montos ocultos la tarjeta no muestra cifras', (
        tester,
      ) async {
        await preparar(tester);
        _contenedor(tester).read(montosVisiblesProvider.notifier).fijar(false);
        await ir(tester);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('finanzas-por-repartir')),
            matching: find.textContaining(r'$'),
          ),
          findsNothing,
        );
      });
    });
  }
}

String _formato(int centavos) => formatearCentavos(centavos);

Future<Widget> _montarTarjeta(WidgetTester tester) async {
  final contexto = tester.element(find.byType(Scaffold).first);
  showDialog<void>(
    context: contexto,
    builder: (_) =>
        const Dialog(child: SingleChildScrollView(child: TarjetaFinanzasHoy())),
  );
  await avanzar(tester);
  return tester.widget(find.byType(TarjetaFinanzasHoy).first);
}
