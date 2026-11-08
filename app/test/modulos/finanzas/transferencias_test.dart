// Fase 8, bloque 1: transferencias con confirmación del receptor, aportación
// de referencia y periodo configurable. Datos de ejemplo inventados.
import 'package:finanzas_dominio/finanzas_dominio.dart' show Fecha;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/modulos/finanzas/datos/fuente_tablas.dart';
import 'package:gravity/modulos/finanzas/datos/transferencias.dart';
import 'package:gravity/modulos/finanzas/estado/proveedores_transferencias.dart';
import 'package:gravity/modulos/finanzas/pantallas/transferencias/aportacion_casa.dart';
import 'package:gravity/modulos/finanzas/pantallas/transferencias/transferencias.dart';

final _dueno = IdsDemostracion.dueno;
final _pareja = IdsDemostracion.pareja;
final _reloj = DateTime(2026, 11, 9, 10);

RepositorioTransferenciasEnMemoria _repo(String persona) =>
    RepositorioTransferenciasEnMemoria(
      personaId: persona,
      duenoId: _dueno,
      parejaId: _pareja,
      reloj: () => _reloj,
    );

void main() {
  group('rutas', () {
    test('se ofrecen solo las tres rutas permitidas', () {
      final todas = {
        ...rutasQueOfrece(ParteTransferencia.dueno),
        ...rutasQueOfrece(ParteTransferencia.pareja),
      };
      expect(todas, {
        RutaTransferencia.parejaADueno,
        RutaTransferencia.duenoACasa,
        RutaTransferencia.parejaACasa,
      });
      expect(rutasQueOfrece(ParteTransferencia.dueno), [
        RutaTransferencia.duenoACasa,
      ]);
      expect(rutasQueOfrece(ParteTransferencia.otra), isEmpty);
      expect(RutaTransferencia.values, hasLength(3));
    });

    test('la memoria rechaza una ruta que no es de la persona', () async {
      expect(
        () => _repo(_dueno)
            .proponer(ruta: RutaTransferencia.parejaADueno, montoCentavos: 100),
        throwsA(isA<Exception>()),
      );
      expect(
        () => _repo('otra')
            .proponer(ruta: RutaTransferencia.parejaACasa, montoCentavos: 100),
        throwsA(isA<Exception>()),
      );
    });

    test('monto en centavos mayor que cero y nota corta', () {
      expect(errorAlProponer(0, ''), isNotNull);
      expect(errorAlProponer(null, ''), isNotNull);
      expect(errorAlProponer(5000, 'x' * 81), isNotNull);
      expect(errorAlProponer(5000, 'Luz'), isNull);
    });
  });

  group('confirmar y rechazar', () {
    test('nada se mueve hasta confirmar; rechazar no mueve', () async {
      final pareja = _repo(_pareja);
      final dueno = pareja.comoPersona(_dueno);
      final id = await pareja.proponer(
        ruta: RutaTransferencia.parejaADueno,
        montoCentavos: 150000,
        nota: 'Súper',
      );
      expect(pareja.movimientosAplicados, 0);
      expect(
        (await dueno.listar()).single.estado,
        EstadoTransferencia.pendiente,
      );

      await dueno.responder(id, AccionTransferencia.rechazar);
      expect(pareja.movimientosAplicados, 0);
      expect(
        (await pareja.listar()).single.estado,
        EstadoTransferencia.rechazada,
      );
      // El registro queda (solo agregar) y ya no se puede confirmar.
      expect(
        () => dueno.responder(id, AccionTransferencia.confirmar),
        throwsA(isA<Exception>()),
      );
    });

    test('solo el receptor confirma; quien propuso puede cancelar', () async {
      final pareja = _repo(_pareja);
      final id = await pareja.proponer(
        ruta: RutaTransferencia.parejaADueno,
        montoCentavos: 5000,
      );
      expect(
        () => pareja.responder(id, AccionTransferencia.confirmar),
        throwsA(isA<Exception>()),
      );
      await pareja.responder(id, AccionTransferencia.cancelar);
      expect(
        (await pareja.listar()).single.estado,
        EstadoTransferencia.cancelada,
      );
    });

    test('confirmar llama la RPC fin_responder_transferencia', () async {
      final fuente = FuenteTablasEnMemoria();
      final repo = RepositorioTransferenciasSupabase(fuente);
      await repo.responder('t-1', AccionTransferencia.confirmar);
      await repo.responder('t-2', AccionTransferencia.rechazar);
      expect(fuente.llamadas.map((l) => l.$1).toSet(), {
        'fin_responder_transferencia',
      });
      expect(fuente.llamadas[0].$2, {
        'p_transferencia': 't-1',
        'p_accion': 'confirmar',
      });
      expect(fuente.llamadas[1].$2, {
        'p_transferencia': 't-2',
        'p_accion': 'rechazar',
      });
    });

    testWidgets('en pantalla: el receptor ve el botón y confirma', (t) async {
      final pareja = _repo(_pareja);
      await pareja.proponer(
        ruta: RutaTransferencia.parejaADueno,
        montoCentavos: 20000,
      );
      final dueno = pareja.comoPersona(_dueno);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            repositorioTransferenciasProvider.overrideWithValue(dueno),
            parteTransferenciaProvider.overrideWithValue(
              ParteTransferencia.dueno,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(body: CuerpoTransferencias(personaId: _dueno)),
          ),
        ),
      );
      await t.pumpAndSettle();
      // Ruta única del dueño y la pendiente por confirmar, sin automatismo.
      expect(find.byKey(const ValueKey('transf-ruta-dueno_a_casa')), findsOne);
      expect(
        find.byKey(const ValueKey('transf-ruta-pareja_a_dueno')),
        findsNothing,
      );
      expect(find.text('Confirmar'), findsOneWidget);
      expect(pareja.movimientosAplicados, 0);

      await t.tap(find.text('Confirmar'));
      await t.pumpAndSettle();
      expect(pareja.movimientosAplicados, 1);
      expect(find.text('Confirmar'), findsNothing);
      expect(find.textContaining('Confirmada'), findsOneWidget);
    });
  });

  group('aportación de referencia', () {
    test('la referencia suma 100% (50% Papá, 50% entre dueño y pareja)', () {
      for (final total in [0, 1, 99, 100001, 123457, 9999999]) {
        final r = ReferenciaAportacion.de(total);
        expect(r.sumaCentavos, total, reason: 'total $total');
        expect(r.papaCentavos, total ~/ 2);
        expect(
          (r.duenoCentavos - r.parejaCentavos).abs(),
          lessThanOrEqualTo(1),
        );
      }
      final r = ReferenciaAportacion.de(100000);
      expect(r.papaCentavos, 50000);
      expect(r.duenoCentavos, 25000);
      expect(r.parejaCentavos, 25000);
    });

    test(
      'lo aportado cuenta solo confirmadas a la casa dentro del periodo',
      () {
        Transferencia t(
          String id,
          EstadoTransferencia e,
          DateTime f, {
          RutaTransferencia ruta = RutaTransferencia.parejaACasa,
        }) => Transferencia(
          id: id,
          ruta: ruta,
          origenId: _pareja,
          receptorId: _dueno,
          montoCentavos: 1000,
          estado: e,
          creadaEn: f,
        );
        final lista = [
          t('a', EstadoTransferencia.confirmada, DateTime(2026, 11, 3)),
          t('b', EstadoTransferencia.rechazada, DateTime(2026, 11, 4)),
          t('c', EstadoTransferencia.pendiente, DateTime(2026, 11, 5)),
          t('d', EstadoTransferencia.confirmada, DateTime(2026, 10, 30)),
          t(
            'e',
            EstadoTransferencia.confirmada,
            DateTime(2026, 11, 6),
            ruta: RutaTransferencia.parejaADueno,
          ),
        ];
        final (d, h) = PeriodoAportacion.mes.rango(Fecha(2026, 11, 9));
        expect(aportadoPorPersona(lista, _pareja, d, h), 1000);
        final (d2, h2) = PeriodoAportacion.semestre.rango(Fecha(2026, 11, 9));
        expect(aportadoPorPersona(lista, _pareja, d2, h2), 2000);
      },
    );

    test('el periodo cambia el rango y por tanto el cálculo', () {
      final hoy = Fecha(2026, 11, 11); // miércoles
      expect(PeriodoAportacion.semana.rango(hoy), (
        Fecha(2026, 11, 9),
        Fecha(2026, 11, 15),
      ));
      expect(PeriodoAportacion.mes.rango(hoy), (
        Fecha(2026, 11, 1),
        Fecha(2026, 11, 30),
      ));
      expect(PeriodoAportacion.bimestre.rango(hoy), (
        Fecha(2026, 11, 1),
        Fecha(2026, 12, 31),
      ));
      expect(PeriodoAportacion.semestre.rango(hoy), (
        Fecha(2026, 7, 1),
        Fecha(2026, 12, 31),
      ));
      expect(PeriodoAportacion.anio.rango(hoy), (
        Fecha(2026, 1, 1),
        Fecha(2026, 12, 31),
      ));

      final datos = datosDeDemostracion(hoy: hoy);
      const casa = IdsDemostracion.libroCasa;
      final (sd, sh) = PeriodoAportacion.semana.rango(hoy);
      final (ad, ah) = PeriodoAportacion.anio.rango(hoy);
      final semana = totalGastoCasa(datos, casa, sd, sh);
      final anio = totalGastoCasa(datos, casa, ad, ah);
      expect(anio, greaterThanOrEqualTo(semana));
    });

    test('solo el dueño fija el periodo', () async {
      final dueno = _repo(_dueno);
      await dueno.fijarPeriodo(PeriodoAportacion.bimestre);
      expect(await dueno.periodo(), PeriodoAportacion.bimestre);
      expect(
        () => dueno.comoPersona(_pareja).fijarPeriodo(PeriodoAportacion.anio),
        throwsA(isA<Exception>()),
      );
    });

    test('las filas no marcan deudores: tres partes que suman el total', () {
      final filas = filasDeAportacion(
        total: 200001,
        transferencias: const [],
        duenoId: _dueno,
        parejaId: _pareja,
        desde: Fecha(2026, 11, 1),
        hasta: Fecha(2026, 11, 30),
        nombreDe: (_) => '',
      );
      expect(filas.fold<int>(0, (s, f) => s + f.referencia), 200001);
      expect(filas.map((f) => f.clave), ['dueno', 'pareja', 'papa']);
    });
  });

  group('subcuenta de la casa y referencia por subcuenta', () {
    test('a la casa exige subcuenta; pareja a dueño no la pide', () async {
      final dueno = _repo(_dueno);
      expect(
        () => dueno.proponer(
          ruta: RutaTransferencia.duenoACasa,
          montoCentavos: 1000,
        ),
        throwsA(isA<Exception>()),
      );
      await dueno.proponer(
        ruta: RutaTransferencia.duenoACasa,
        montoCentavos: 1000,
        subcuentaId: 'sub-luz',
      );
      expect((await dueno.listar()).single.subcuentaId, 'sub-luz');
      final pareja = dueno.comoPersona(_pareja);
      expect(
        () => pareja.proponer(
          ruta: RutaTransferencia.parejaACasa,
          montoCentavos: 1000,
        ),
        throwsA(isA<Exception>()),
      );
      await pareja.proponer(
        ruta: RutaTransferencia.parejaADueno,
        montoCentavos: 1000,
      );
      expect((await pareja.listar()).first.subcuentaId, isNull);
      expect(
        errorAlProponer(100, '', ruta: RutaTransferencia.parejaADueno),
        isNull,
      );
      expect(
        errorAlProponer(100, '', ruta: RutaTransferencia.parejaACasa),
        isNotNull,
      );
    });

    test('la RPC lleva p_subcuenta solo a la casa', () async {
      final fuente = FuenteTablasEnMemoria();
      final repo = RepositorioTransferenciasSupabase(fuente);
      await repo.proponer(
        ruta: RutaTransferencia.duenoACasa,
        montoCentavos: 500,
        subcuentaId: 's-1',
      );
      await repo.proponer(
        ruta: RutaTransferencia.parejaADueno,
        montoCentavos: 500,
        subcuentaId: 's-1',
      );
      expect(fuente.llamadas[0].$2['p_subcuenta'], 's-1');
      expect(fuente.llamadas[1].$2['p_subcuenta'], isNull);
    });

    test('el reparto por subcuenta suma 100% y no pasa de 100%', () {
      const r = ReparteReferencia.porOmision;
      expect([r.papaPb, r.duenoPb, r.parejaPb], [5000, 2500, 2500]);
      expect(r.sumaPb, 10000);
      expect(r.error, isNull);
      expect(r.repartir(100001).values.fold<int>(0, (a, b) => a + b), 100001);
      expect(const ReparteReferencia(papaPb: 6000).error, isNotNull);
    });

    test('solo el dueño cambia el reparto de una subcuenta', () async {
      final dueno = _repo(_dueno);
      const nuevo = ReparteReferencia(
        papaPb: 7000,
        duenoPb: 1500,
        parejaPb: 1500,
      );
      await dueno.fijarReferencia('sub-luz', nuevo);
      expect((await dueno.referencia('sub-luz')).papaPb, 7000);
      expect((await dueno.referencia('sub-telefono')).papaPb, 5000);
      expect(
        () => dueno.comoPersona(_pareja).fijarReferencia('sub-luz', nuevo),
        throwsA(isA<Exception>()),
      );
      expect(
        () => dueno.fijarReferencia(
          'sub-luz',
          const ReparteReferencia(papaPb: 9000),
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
