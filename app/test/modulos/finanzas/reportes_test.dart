// Reportes y gasto desde recibo (Fase 8, bloque 4; D3, D19): cada reporte
// muestra solo lo del libro de quien lo pide; el gasto propuesto no se guarda
// sin confirmar; el comprobante queda ligado al gasto y nada sale a la red.
// Datos de ejemplo inventados.
import 'dart:io';
import 'dart:typed_data';

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide
        Semaforo,
        formatearCentavos,
        TipoLibro,
        VisibilidadLibro,
        puntosBaseEnCien;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/app/router.dart';
import 'package:gravity/diseno/diseno.dart' show montosVisiblesProvider;
import 'package:gravity/modulos/finanzas/casos_uso/gasto_desde_recibo.dart';
import 'package:gravity/modulos/finanzas/casos_uso/reportes.dart';
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/modulos/finanzas/datos/patrimonio.dart';
import 'package:gravity/modulos/finanzas/datos/transferencias.dart';
import 'package:gravity/modulos/finanzas/estado/proveedores_recibo.dart';
import 'package:gravity/modulos/finanzas/finanzas.dart'
    show hojaGastoDesdeRecibo;
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';
import 'package:gravity/modulos/finanzas/estado/proveedores.dart'
    show repositorioFinanzasProvider;

import '../../app/ayuda_plataforma.dart';
import 'ayuda_finanzas.dart';

void main() {
  const casa = IdsDemostracion.libroCasa;
  const libroDueno = IdsDemostracion.libroDueno;
  const libroPareja = IdsDemostracion.libroPareja;
  const libroPapa = IdsDemostracion.libroPapa;
  final dueno = sesionDe(Rol.dueno);
  final pareja = sesionDe(Rol.coadministrador);
  final octubre = RangoReporte.mes(2026, 10);

  group('gasto por categoría: solo el libro de quien lo pide (D19)', () {
    test('el dueño ve su libro; la pareja no ve ese gasto ni lo suma', () {
      final deDueno = repositorioDe(dueno);
      final dePareja = repositorioDe(pareja);
      addTearDown(deDueno.cerrar);
      addTearDown(dePareja.cerrar);
      final suyo = gastoPorCategoria(deDueno.datos, libroDueno, octubre);
      expect(suyo.totalCentavos, 18000);
      expect(suyo.lineas.single.nombre, 'Entretenimiento');
      // La pareja pide el mismo libro: la RLS no se lo dio, no hay nada.
      final ajeno = gastoPorCategoria(dePareja.datos, libroDueno, octubre);
      expect(ajeno.totalCentavos, 0);
      expect(ajeno.lineas, isEmpty);
      // Y en su propio libro no aparece el gasto del dueño.
      expect(
        gastoPorCategoria(dePareja.datos, libroPareja, octubre).totalCentavos,
        0,
      );
    });

    test('un libro que la persona no ve no suma nada', () {
      for (final sesion in [dueno, pareja]) {
        final repo = repositorioDe(sesion);
        addTearDown(repo.cerrar);
        final visibles = repo.datos.libros.map((l) => l.id).toSet();
        for (final libro in [casa, libroDueno, libroPareja, libroPapa]) {
          final total = gastoPorCategoria(
            repo.datos,
            libro,
            octubre,
          ).totalCentavos;
          if (!visibles.contains(libro)) {
            expect(total, 0, reason: '${sesion.rol.name} no ve $libro');
          }
        }
      }
      // Papá: lo ve el albacea (32,000) y quien no es de su libro no suma.
      final repo = repositorioDe(dueno);
      addTearDown(repo.cerrar);
      expect(
        gastoPorCategoria(repo.datos, libroPapa, octubre).totalCentavos,
        32000,
      );
    });

    test('la casa es de los dos: mismo total; no mezcla libros propios', () {
      final deDueno = repositorioDe(dueno);
      final dePareja = repositorioDe(pareja);
      addTearDown(deDueno.cerrar);
      addTearDown(dePareja.cerrar);
      final a = gastoPorCategoria(deDueno.datos, casa, octubre);
      final b = gastoPorCategoria(dePareja.datos, casa, octubre);
      expect(a.totalCentavos, b.totalCentavos);
      expect(a.totalCentavos, greaterThan(0));
      // Los 18,000 de "Salidas" del libro del dueño no están en la casa.
      expect(a.lineas.any((l) => l.nombre == 'Entretenimiento'), isFalse);
    });
  });

  group('aportación de la casa', () {
    final subs = [
      const SubcuentaCasa(id: 'luz', nombre: 'Luz'),
      const SubcuentaCasa(id: 'tel', nombre: 'Teléfono'),
    ];
    Transferencia t(
      String id,
      RutaTransferencia ruta,
      String origen,
      int monto,
      EstadoTransferencia estado,
      DateTime cuando,
      String? sub,
    ) => Transferencia(
      id: id,
      ruta: ruta,
      origenId: origen,
      receptorId: 'x',
      montoCentavos: monto,
      estado: estado,
      creadaEn: cuando,
      subcuentaId: sub,
    );

    test('referencia y aportado por persona y por subcuenta', () {
      final repo = repositorioDe(dueno);
      addTearDown(repo.cerrar);
      final ahora = DateTime(2026, 10, 12);
      final r = reporteDeAportacion(
        datos: repo.datos,
        libroCasaId: casa,
        rango: octubre,
        transferencias: [
          t(
            '1',
            RutaTransferencia.duenoACasa,
            IdsDemostracion.dueno,
            30000,
            EstadoTransferencia.confirmada,
            ahora,
            'luz',
          ),
          t(
            '2',
            RutaTransferencia.parejaACasa,
            IdsDemostracion.pareja,
            10000,
            EstadoTransferencia.confirmada,
            ahora,
            'luz',
          ),
          t(
            '3',
            RutaTransferencia.parejaACasa,
            IdsDemostracion.pareja,
            5000,
            EstadoTransferencia.confirmada,
            ahora,
            'tel',
          ),
          // No cuentan: pendiente, fuera del periodo y entre personas.
          t(
            '4',
            RutaTransferencia.duenoACasa,
            IdsDemostracion.dueno,
            99900,
            EstadoTransferencia.pendiente,
            ahora,
            'luz',
          ),
          t(
            '5',
            RutaTransferencia.duenoACasa,
            IdsDemostracion.dueno,
            88800,
            EstadoTransferencia.confirmada,
            DateTime(2026, 9, 30),
            'luz',
          ),
          t(
            '6',
            RutaTransferencia.parejaADueno,
            IdsDemostracion.pareja,
            7700,
            EstadoTransferencia.confirmada,
            ahora,
            null,
          ),
        ],
        subcuentas: subs,
        referencias: const {
          'tel': ReparteReferencia(papaPb: 4000, duenoPb: 3000, parejaPb: 3000),
        },
        duenoId: IdsDemostracion.dueno,
        parejaId: IdsDemostracion.pareja,
        nombreDe: (_) => '',
      );
      final total = totalGastoCasa(
        repo.datos,
        casa,
        octubre.desde,
        octubre.hasta,
      );
      expect(r.totalGastoCasa, total);
      expect(
        r.personas.map((f) => f.referencia).reduce((a, b) => a + b),
        total,
      );
      expect(r.personas.firstWhere((f) => f.clave == 'dueno').aportado, 30000);
      expect(r.personas.firstWhere((f) => f.clave == 'pareja').aportado, 15000);
      final luz = r.subcuentas.firstWhere((s) => s.subcuentaId == 'luz');
      expect(luz.aportadoDueno, 30000);
      expect(luz.aportadoPareja, 10000);
      expect(luz.reparto.papaPb, 5000, reason: 'por omisión 50/25/25');
      final tel = r.subcuentas.firstWhere((s) => s.subcuentaId == 'tel');
      expect(tel.aportadoTotal, 5000);
      expect(tel.reparto.papaPb, 4000);
    });
  });

  group('resumen de deudas y avance de objetivos', () {
    test('solo las deudas del libro pedido; sin datos no recomienda', () {
      final repo = repositorioDe(dueno);
      addTearDown(repo.cerrar);
      final r = resumenDeDeudas(repo.datos, casa, hoyDePrueba);
      final deLaCasa = repo.datos.deudasDe(casa).map((d) => d.id).toSet();
      expect(r.deudas, isNotEmpty);
      expect(r.deudas.every((d) => deLaCasa.contains(d.id)), isTrue);
      expect(r.saldoTotal, greaterThan(0));
      // Un libro sin deudas queda vacío y sin estrategia.
      final vacio = resumenDeDeudas(repo.datos, libroPareja, hoyDePrueba);
      expect(vacio.deudas, isEmpty);
      expect(vacio.recomendada, isNull);
    });

    test('la pareja no recibe las deudas del libro del dueño', () {
      final repo = repositorioDe(pareja);
      addTearDown(repo.cerrar);
      expect(
        resumenDeDeudas(repo.datos, libroDueno, hoyDePrueba).deudas,
        isEmpty,
      );
    });

    test('objetivos: lo que falta y las semanas, solo los del libro', () {
      final repo = repositorioDe(dueno);
      addTearDown(repo.cerrar);
      final avances = reporteDeObjetivos(
        datos: repo.datos,
        libroId: libroDueno,
        hoy: hoyDePrueba,
        objetivos: const [
          Objetivo(
            id: 'o1',
            libroId: libroDueno,
            nombre: 'Viaje',
            metaCentavos: 500000,
          ),
          Objetivo(
            id: 'o2',
            libroId: libroPareja,
            nombre: 'De la pareja',
            metaCentavos: 100000,
          ),
        ],
      );
      expect(avances.map((a) => a.objetivo.id), ['o1']);
      expect(avances.single.avance.falta, 500000);
      expect(
        avances.single.avance.semanasParaAlcanzar,
        isNull,
        reason: 'sin apartado no se inventa una estimación',
      );
    });
  });

  group('recibo: la propuesta', () {
    const texto =
        'SÚPER LA ESQUINA\n'
        'Folio 12345\n'
        '18/10/2026 13:45\n'
        'Subtotal 202.16\n'
        'IVA 32.34\n'
        'TOTAL \$234.50\n'
        'Efectivo 300.00\n';

    test('propone monto, concepto y fecha', () {
      final p = proponerGastoDeRecibo(texto, hoyDePrueba);
      expect(p.montoCentavos, 23450);
      expect(p.concepto, 'SÚPER LA ESQUINA');
      expect(p.fecha, Fecha(2026, 10, 18));
    });

    test('sin total, el mayor monto con centavos; sin nada, no inventa', () {
      expect(
        proponerGastoDeRecibo('Café\n45.00\n12.50', hoyDePrueba).montoCentavos,
        4500,
      );
      final vacio = proponerGastoDeRecibo('', hoyDePrueba);
      expect(vacio.montoCentavos, isNull);
      expect(vacio.fecha, isNull);
      expect(vacio.concepto, '');
      expect(
        proponerGastoDeRecibo('Folio 123456', hoyDePrueba).montoCentavos,
        isNull,
      );
    });

    test('una fecha futura o imposible se descarta', () {
      expect(
        proponerGastoDeRecibo('Tienda\n25/12/2030', hoyDePrueba).fecha,
        isNull,
      );
      expect(
        proponerGastoDeRecibo('Tienda\n31/02/2026', hoyDePrueba).fecha,
        isNull,
      );
    });
  });

  group('recibo: confirmar, comprobante y red', () {
    final foto = Uint8List.fromList([1, 2, 3, 4, 5]);
    final recibo = ReciboImagenEnMemoria(
      foto: foto,
      textoLeido: 'Papelería\n18/10/2026\nTOTAL 85.50',
    );

    test(
      'proponer no guarda nada; confirmar guarda y liga el comprobante',
      () async {
        final repo = repositorioDe(dueno);
        addTearDown(repo.cerrar);
        final servicio = servicioDe(repo, dueno);
        final comprobantes = ComprobanteLocalEnMemoria();
        final antes = repo.datos.movimientos.length;

        final p = proponerGastoDeRecibo(recibo.textoLeido, hoyDePrueba);
        expect(p.montoCentavos, 8550);
        expect(
          repo.datos.movimientos,
          hasLength(antes),
          reason: 'solo propone',
        );
        expect(comprobantes.cantidad, 0);

        final cuenta = repo.cuentaDe(libroDueno, 'Mi banco');
        final r = await confirmarGastoDeRecibo(
          servicio: servicio,
          comprobantes: comprobantes,
          personaId: dueno.persona.id,
          recibo: recibo,
          libroId: libroDueno,
          cuentaOrigenId: cuenta.id,
          montoCentavos: p.montoCentavos!,
          concepto: p.concepto,
          fecha: p.fecha!,
        );
        expect(repo.datos.movimientos, hasLength(antes + 1));
        final m = repo.datos.movimientos.last;
        expect(m.monto, 8550);
        expect(m.via, ViaCaptura.imagen);
        expect(m.nota, 'Papelería');
        expect(r.movimientos.single.id, m.id);
        expect(
          await comprobantes.leer(
            personaId: dueno.persona.id,
            movimientoId: m.id,
          ),
          foto,
        );
        // Solo en el teléfono de quien lo registró: otra persona no lo tiene.
        expect(
          await comprobantes.leer(
            personaId: pareja.persona.id,
            movimientoId: m.id,
          ),
          isNull,
        );
      },
    );

    test('si el gasto falla, la foto no se guarda', () async {
      final repo = repositorioDe(dueno);
      addTearDown(repo.cerrar);
      final comprobantes = ComprobanteLocalEnMemoria();
      await expectLater(
        confirmarGastoDeRecibo(
          servicio: servicioDe(repo, dueno),
          comprobantes: comprobantes,
          personaId: dueno.persona.id,
          recibo: recibo,
          libroId: libroDueno,
          cuentaOrigenId: 'cuenta-que-no-existe',
          montoCentavos: 8550,
          concepto: 'x',
          fecha: hoyDePrueba,
        ),
        throwsA(anything),
      );
      expect(comprobantes.cantidad, 0);
    });

    test('ninguna llamada de red con la imagen ni con el texto', () async {
      final conexiones = <String>[];
      await HttpOverrides.runZoned(
        () async {
          final repo = repositorioDe(dueno);
          addTearDown(repo.cerrar);
          final comprobantes = ComprobanteLocalEnMemoria();
          final cuenta = repo.cuentaDe(libroDueno, 'Mi banco');
          final p = proponerGastoDeRecibo(recibo.textoLeido, hoyDePrueba);
          await confirmarGastoDeRecibo(
            servicio: servicioDe(repo, dueno),
            comprobantes: comprobantes,
            personaId: dueno.persona.id,
            recibo: recibo,
            libroId: libroDueno,
            cuentaOrigenId: cuenta.id,
            montoCentavos: p.montoCentavos!,
            concepto: p.concepto,
            fecha: p.fecha!,
          );
        },
        createHttpClient: (contexto) {
          conexiones.add('HttpClient');
          throw StateError('Sin red en esta prueba');
        },
      );
      expect(conexiones, isEmpty);
    });

    test('el código del recibo no importa red ni nube (D3)', () {
      final fuente = File(
        'lib/modulos/finanzas/casos_uso/gasto_desde_recibo.dart',
      ).readAsStringSync();
      final importaciones = fuente
          .split('\n')
          .where((l) => l.startsWith('import '))
          .join('\n');
      for (final prohibido in [
        'dart:io',
        'http',
        'supabase',
        'dio',
        'socket',
      ]) {
        expect(importaciones, isNot(contains(prohibido)), reason: prohibido);
      }
      final hoja = File(
        'lib/modulos/finanzas/pantallas/registro/hoja_recibo.dart',
      ).readAsStringSync();
      expect(hoja, isNot(contains('supabase')));
      expect(hoja, isNot(contains('http')));
    });
  });

  group('pantallas', () {
    Future<void> montar(
      WidgetTester tester, {
      required TipoDispositivo dispositivo,
      required dynamic sesion,
      ComprobanteLocalEnMemoria? comprobantes,
    }) async {
      final repo = repositorioDe(sesion);
      addTearDown(repo.cerrar);
      await montarApp(
        tester,
        dispositivo: dispositivo,
        sesion: ServicioSesionDemostracion(inicial: sesion),
        extras: [
          repositorioFinanzasProvider.overrideWithValue(repo),
          if (comprobantes != null)
            comprobanteLocalProvider.overrideWithValue(comprobantes),
        ],
      );
      ProviderScope.containerOf(tester.element(find.byType(AppGravity)))
          .read(montosVisiblesProvider.notifier)
          .fijar(true);
      await tester.pump();
    }

    Future<void> ir(WidgetTester tester, String ruta) async {
      ProviderScope.containerOf(tester.element(find.byType(AppGravity)))
          .read(routerProvider)
          .go(ruta);
      await tester.pumpAndSettle();
    }

    for (final disp in [TipoDispositivo.laptop, TipoDispositivo.telefono]) {
      testWidgets('los reportes abren en ${disp.name} con el libro de quien '
          'los pide', (tester) async {
        await montar(tester, dispositivo: disp, sesion: dueno);
        await ir(tester, '${Rutas.finanzas}/reportes');
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('reporte-gasto-categoria')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('reportes-periodos')), findsOneWidget);
        await tester.dragUntilVisible(
          find.byKey(const ValueKey('reporte-deudas')),
          find.byType(Scrollable).last,
          const Offset(0, -300),
        );
        expect(find.byKey(const ValueKey('reporte-deudas')), findsOneWidget);
      });
    }

    testWidgets('el reporte de la pareja no muestra el gasto del dueño', (
      tester,
    ) async {
      await montar(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: pareja,
      );
      tester.view.physicalSize = Size(tester.view.physicalSize.width, 4000);
      await ir(tester, '${Rutas.finanzas}/reportes');
      expect(find.text('Entretenimiento', skipOffstage: false), findsNothing);
      expect(
        find.byKey(const ValueKey('reporte-gasto-vacio'), skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('la hoja del recibo propone, no guarda hasta confirmar y deja '
        'el comprobante', (tester) async {
      final comprobantes = ComprobanteLocalEnMemoria();
      await montar(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: dueno,
        comprobantes: comprobantes,
      );
      final repo = ProviderScope.containerOf(
        tester.element(find.byType(AppGravity)),
      ).read(repositorioFinanzasProvider);
      final antes = repo.actual!.datos.movimientos.length;
      final contexto = tester.element(find.byType(Scaffold).first);
      showModalBottomSheet<void>(
        context: contexto,
        isScrollControlled: true,
        builder: (_) => hojaGastoDesdeRecibo(
          ReciboImagenEnMemoria(
            foto: Uint8List.fromList([9, 9, 9]),
            textoLeido: 'Papelería\n18/10/2026\nTOTAL 85.50',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('recibo-monto')))
            .controller!
            .text,
        '85.50',
      );
      expect(repo.actual!.datos.movimientos, hasLength(antes));
      final cuenta = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey &&
            '${(w.key! as ValueKey).value}'.startsWith('recibo-cuenta-'),
      );
      await tester.ensureVisible(cuenta.first);
      await tester.tap(cuenta.first);
      await tester.pump();
      expect(repo.actual!.datos.movimientos, hasLength(antes));
      expect(comprobantes.cantidad, 0);
      final guardar = find.byKey(const ValueKey('recibo-guardar'));
      await tester.ensureVisible(guardar);
      await tester.tap(guardar);
      await tester.pumpAndSettle();
      expect(repo.actual!.datos.movimientos, hasLength(antes + 1));
      expect(comprobantes.cantidad, 1);
      final m = repo.actual!.datos.movimientos.last;
      expect(m.monto, 8550);
      expect(
        await comprobantes.leer(
          personaId: dueno.persona.id,
          movimientoId: m.id,
        ),
        Uint8List.fromList([9, 9, 9]),
      );
    });
  });
}
