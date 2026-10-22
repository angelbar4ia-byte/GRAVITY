// Pantallas de Finanzas dentro de la app: rutas y permisos (D19), cuenta
// maestra de solo lectura con su consulta en la bitácora, asistente de
// arranque con los ingresos de papá, importación, ajustes y el flujo F1 del
// teléfono (registrar un gasto y deshacerlo).
import 'package:finanzas_dominio/finanzas_dominio.dart' hide Semaforo, formatearCentavos, TipoLibro, puntosBaseEnCien;
import 'package:finanzas_dominio/finanzas_dominio.dart' as dom show TipoLibro;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/app/router.dart';
import 'package:gravity/diseno/diseno.dart' show TecladoMonto;
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/modulos/finanzas/datos/ids.dart' show idEstable;
import 'package:gravity/modulos/finanzas/datos/repositorio_memoria.dart';
import 'package:gravity/modulos/finanzas/estado/proveedores.dart';
import 'package:gravity/modulos/finanzas/finanzas.dart';
import 'package:gravity/modulos/finanzas/importacion/lector_xlsx.dart';
import 'package:gravity/modulos/finanzas/pantallas/laptop/importar.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';
import 'package:gravity/nucleo/permisos/permisos.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';

import '../../app/ayuda_plataforma.dart';
import 'ayuda_finanzas.dart';

GoRouter _router(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(AppGravity)),
).read(routerProvider);

String _ubicacion(WidgetTester tester) =>
    _router(tester).routerDelegate.currentConfiguration.uri.path;

Future<void> _ir(WidgetTester tester, String ruta) async {
  _router(tester).go(ruta);
  await tester.pumpAndSettle();
}

/// Una ventana muy alta: las listas perezosas arman todo y todo se alcanza.
void _alto(WidgetTester tester) {
  tester.view.physicalSize = Size(tester.view.physicalSize.width, 4000);
}

ProviderContainer _contenedor(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AppGravity)));

/// Monta la app con el hogar de ejemplo de [sesion] en memoria.
Future<RepositorioFinanzasEnMemoria> _montar(
  WidgetTester tester, {
  required TipoDispositivo dispositivo,
  required Sesion sesion,
  List<Override> extras = const [],
}) async {
  final repo = repositorioDe(sesion);
  await montarApp(
    tester,
    dispositivo: dispositivo,
    sesion: ServicioSesionDemostracion(inicial: sesion),
    extras: [repositorioFinanzasProvider.overrideWithValue(repo), ...extras],
  );
  addTearDown(repo.cerrar);
  return repo;
}

void main() {
  final dueno = sesionDe(Rol.dueno);
  final pareja = sesionDe(Rol.coadministrador);
  final maestra = sesionDe(Rol.dueno, maestra: true);

  group('Rutas de Finanzas (contrato con la plataforma)', () {
    test('la raíz es "/" y las de configuración exigen administrar', () {
      final rutas = rutasFinanzas().whereType<GoRoute>().toList();
      expect(rutas.where((r) => r.path == '/'), hasLength(1));
      final porSegmento = {for (final r in rutas) r.path: r};
      for (final s in SeccionFinanzas.values) {
        if (s == SeccionFinanzas.tablero) continue;
        final ruta = porSegmento[s.segmento];
        expect(ruta, isNotNull, reason: s.segmento);
        expect(
          accionExigida(ruta!.metadata ?? const {}),
          s.esDeConfiguracion ? Accion.administrar : isNull,
          reason: s.segmento,
        );
      }
      expect(
        SeccionFinanzas.values.where((s) => s.esDeConfiguracion).map((s) => s.segmento),
        unorderedEquals(['arranque', 'importar', 'ajustes']),
      );
    });

    testWidgets('el Tablero es el inicio en la laptop y todas las secciones '
        'abren', (tester) async {
      await _montar(tester, dispositivo: TipoDispositivo.laptop, sesion: dueno);
      for (final s in SeccionFinanzas.values) {
        await _ir(tester, s.ruta);
        expect(_ubicacion(tester), s.ruta, reason: s.segmento);
        expect(find.text('No encontramos esa pantalla.'), findsNothing);
        expect(tester.takeException(), isNull, reason: s.segmento);
      }
    });

    testWidgets('en el teléfono las secciones de la laptop regresan al inicio '
        'del módulo (D4)', (tester) async {
      await _montar(tester, dispositivo: TipoDispositivo.telefono, sesion: dueno);
      await _ir(tester, Rutas.finanzas);
      expect(find.byKey(const ValueKey('finanzas-semana-resumen')), findsOneWidget);
      for (final s in [
        SeccionFinanzas.cuentas,
        SeccionFinanzas.arranque,
        SeccionFinanzas.ajustes,
      ]) {
        await _ir(tester, s.ruta);
        expect(_ubicacion(tester), Rutas.finanzas, reason: s.segmento);
      }
      await _ir(tester, SeccionFinanzas.movimientos.ruta);
      expect(_ubicacion(tester), SeccionFinanzas.movimientos.ruta);
    });

    testWidgets('la pareja administra su libro: abre el asistente y los '
        'ajustes (D19)', (tester) async {
      await _montar(tester, dispositivo: TipoDispositivo.laptop, sesion: pareja);
      await _ir(tester, SeccionFinanzas.arranque.ruta);
      expect(_ubicacion(tester), SeccionFinanzas.arranque.ruta);
      expect(find.byKey(const ValueKey('arranque-pasos')), findsOneWidget);
    });
  });

  group('Cuenta maestra (D19)', () {
    testWidgets('abrir un libro ajeno registra la consulta y no muestra botones '
        'de escribir', (tester) async {
      final repo = await _montar(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: maestra,
      );
      await _ir(tester, Rutas.finanzas);
      // Su primer libro es ajeno: la consulta quedó en la bitácora.
      expect(repo.consultasMaestra, isNotEmpty);
      final c = _contenedor(tester).read(contextoFinanzasProvider).value!;
      expect(c.permiso.comoMaestra, isTrue);
      expect(repo.consultasMaestra.single, c.libroId);
      expect(c.puedeEscribir, isFalse);
      expect(c.puedeAdministrar, isFalse);
      expect(
        find.byKey(const ValueKey('finanzas-registrar-movimiento')),
        findsNothing,
        reason: 'ni (+) ni Registrar movimiento en lo ajeno',
      );
      // Sin asistente ni importar mientras ve lo ajeno.
      expect(find.byKey(const ValueKey('finanzas-seccion-arranque')), findsNothing);
      expect(find.byKey(const ValueKey('finanzas-seccion-importar')), findsNothing);
    });

    testWidgets('cada libro ajeno que abre deja su consulta; los pasos no la '
        'repiten sin cambiar de libro', (tester) async {
      final repo = await _montar(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: maestra,
      );
      await _ir(tester, Rutas.finanzas);
      final contenedor = _contenedor(tester);
      final libros = contenedor.read(contextoFinanzasProvider).value!.libros;
      expect(libros, hasLength(4));
      contenedor.read(libroElegidoProvider.notifier).elegir(IdsDemostracion.libroDueno);
      await tester.pumpAndSettle();
      expect(repo.consultasMaestra, contains(IdsDemostracion.libroDueno));
      final antes = repo.consultasMaestra.length;
      await _ir(tester, SeccionFinanzas.movimientos.ruta);
      expect(
        repo.consultasMaestra.where((l) => l == IdsDemostracion.libroDueno),
        hasLength(1),
      );
      expect(repo.consultasMaestra.length, greaterThanOrEqualTo(antes));
    });

    testWidgets('Movimientos de lo ajeno: sin Anular', (tester) async {
      await _montar(tester, dispositivo: TipoDispositivo.laptop, sesion: maestra);
      await _ir(tester, SeccionFinanzas.movimientos.ruta);
      final c = _contenedor(tester).read(contextoFinanzasProvider).value!;
      expect(c.puedeEscribir, isFalse);
      expect(find.byKey(const ValueKey('finanzas-registrar-movimiento')), findsNothing);
      expect(find.text('Anular…'), findsNothing);
    });

    testWidgets('el dueño sin la marca escribe en lo suyo y registra sin '
        'consulta', (tester) async {
      final repo = await _montar(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: dueno,
      );
      await _ir(tester, Rutas.finanzas);
      final c = _contenedor(tester).read(contextoFinanzasProvider).value!;
      expect(c.permiso.comoMaestra, isFalse);
      expect(c.puedeEscribir, isTrue);
      expect(c.esLibroPropio, isTrue);
      expect(repo.consultasMaestra, isEmpty);
      expect(
        find.byKey(const ValueKey('finanzas-registrar-movimiento')),
        findsOneWidget,
      );
    });
  });

  group('Ajustes de Finanzas', () {
    testWidgets('el dueño cambia la meta de su libro y queda guardada',
        (tester) async {
      final repo = await _montar(tester, dispositivo: TipoDispositivo.laptop, sesion: dueno);
      await _ir(tester, SeccionFinanzas.ajustes.ruta);
      final libroId = _contenedor(tester).read(contextoFinanzasProvider).value!.libroId;
      await tester.enterText(find.byKey(const ValueKey('ajustes-meta')), '25');
      await tester.ensureVisible(find.byKey(const ValueKey('ajustes-guardar')));
      await tester.tap(find.byKey(const ValueKey('ajustes-guardar')));
      await tester.pumpAndSettle();
      expect(repo.datos.parametrosDe(libroId).metaRemanentePuntosBase, 2500);
      expect(find.text('Ajustes guardados.'), findsOneWidget);
    });

    testWidgets('un porcentaje fuera de rango no se guarda', (tester) async {
      final repo = await _montar(tester, dispositivo: TipoDispositivo.laptop, sesion: dueno);
      await _ir(tester, SeccionFinanzas.ajustes.ruta);
      final libroId = _contenedor(tester).read(contextoFinanzasProvider).value!.libroId;
      final antes = repo.datos.parametrosDe(libroId).metaRemanentePuntosBase;
      await tester.enterText(find.byKey(const ValueKey('ajustes-meta')), '150');
      await tester.ensureVisible(find.byKey(const ValueKey('ajustes-guardar')));
      await tester.tap(find.byKey(const ValueKey('ajustes-guardar')));
      await tester.pumpAndSettle();
      expect(repo.datos.parametrosDe(libroId).metaRemanentePuntosBase, antes);
      expect(find.text('De 0 a 100'), findsWidgets);
    });

    testWidgets('lista los libros con sus albaceas y avisa de la cuenta maestra',
        (tester) async {
      await _montar(tester, dispositivo: TipoDispositivo.laptop, sesion: dueno);
      _alto(tester);
      await _ir(tester, SeccionFinanzas.ajustes.ruta);
      final papa = find.byKey(const ValueKey('ajustes-libro-${IdsDemostracion.libroPapa}'));
      await tester.ensureVisible(papa);
      expect(papa, findsOneWidget);
      expect(
        find.descendant(of: papa, matching: find.textContaining('Albacea')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: papa, matching: find.textContaining('Suplente')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('ajustes-nuevo-compartido')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('ajustes-nuevo-representado')),
        findsNothing,
        reason: 'el libro de papá ya existe',
      );
      expect(
        find.textContaining('cuenta maestra (Cuenta maestra de ejemplo)'),
        findsOneWidget,
      );
    });

    testWidgets('precargar los festivos del año los deja inactivos', (tester) async {
      final repo = await _montar(tester, dispositivo: TipoDispositivo.laptop, sesion: dueno);
      await _ir(tester, SeccionFinanzas.ajustes.ruta);
      final boton = find.byKey(const ValueKey('ajustes-precargar'));
      await tester.ensureVisible(boton);
      await tester.tap(boton);
      await tester.pumpAndSettle();
      expect(repo.datos.diasInhabiles, isNotEmpty);
      expect(repo.datos.diasInhabiles.every((d) => !d.activo), isTrue);
      final primero = find.byKey(ValueKey('ajustes-dia-${repo.datos.diasInhabiles
          .where((d) => d.fecha.anio == 2026)
          .map((d) => d.fecha)
          .reduce((a, b) => a.antesDe(b) ? a : b)}'));
      await tester.ensureVisible(primero);
      await tester.tap(primero);
      await tester.pumpAndSettle();
      expect(repo.datos.diasInhabiles.where((d) => d.activo), hasLength(1));
      expect(
        repo.datos.diasInhabiles.firstWhere((d) => d.activo).revisadoPor,
        dueno.persona.id,
      );
    });

    testWidgets('la cuenta maestra ve los ajustes del libro ajeno sin poder '
        'guardarlos', (tester) async {
      await _montar(tester, dispositivo: TipoDispositivo.laptop, sesion: maestra);
      _alto(tester);
      await _ir(tester, SeccionFinanzas.ajustes.ruta);
      expect(find.byKey(const ValueKey('ajustes-guardar')), findsNothing);
      expect(find.byKey(const ValueKey('ajustes-dias-inhabiles')), findsNothing);
      expect(find.text('Solo lectura: los cambia quien lleva este libro.'), findsOneWidget);
      expect(find.textContaining('cuenta maestra del hogar'), findsOneWidget);
    });

    testWidgets('un libro compartido nuevo queda elegido', (tester) async {
      final repo = await _montar(tester, dispositivo: TipoDispositivo.laptop, sesion: dueno);
      _alto(tester);
      await _ir(tester, SeccionFinanzas.ajustes.ruta);
      final boton = find.byKey(const ValueKey('ajustes-nuevo-compartido'));
      await tester.ensureVisible(boton);
      await tester.tap(boton);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('compartido-nombre')), 'Vacaciones');
      await tester.tap(find.byKey(ValueKey('compartido-miembro-${IdsDemostracion.pareja}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('compartido-crear')));
      await tester.pumpAndSettle();
      final nuevo = repo.datos.libros.firstWhere((l) => l.nombre == 'Vacaciones');
      expect(nuevo.tipo, dom.TipoLibro.compartido);
      expect(nuevo.vigentes(hoyDePrueba).map((m) => m.personaId).toSet(), adultosDeEjemplo);
      expect(_contenedor(tester).read(libroElegidoProvider), nuevo.id);
    });
  });

  group('Asistente de arranque', () {
    testWidgets('tiene los 5 pasos y el resumen con Activar semana',
        (tester) async {
      await _montar(tester, dispositivo: TipoDispositivo.laptop, sesion: dueno);
      await _ir(tester, SeccionFinanzas.arranque.ruta);
      for (final paso in [
        '1. Libro y cuentas',
        '2. Ingresos',
        '3. Compromisos y deudas',
        '4. Meta',
        '5. Sobres hasta el techo',
      ]) {
        expect(find.text(paso), findsOneWidget, reason: paso);
      }
      expect(find.byKey(const ValueKey('arranque-resumen')), findsOneWidget);
      expect(find.byKey(const ValueKey('arranque-activar')), findsOneWidget);
    });

    testWidgets('en el libro de papá ofrece la pensión (días 1 y 11) y el apoyo '
        '60+, sin montos ni fechas inventados', (tester) async {
      final repo = await _montar(tester, dispositivo: TipoDispositivo.laptop, sesion: dueno);
      await _ir(tester, SeccionFinanzas.arranque.ruta);
      _contenedor(tester).read(libroElegidoProvider.notifier).elegir(IdsDemostracion.libroPapa);
      await tester.pumpAndSettle();
      await tester.tap(find.text('2. Ingresos'));
      await tester.pumpAndSettle();
      final pension = find.byKey(const ValueKey('arranque-plantilla-Pensión'));
      expect(pension, findsOneWidget);
      expect(find.byKey(const ValueKey('arranque-plantilla-Apoyo 60+')), findsOneWidget);
      await tester.ensureVisible(pension);
      await tester.tap(pension);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ingreso-ayuda-plantilla')), findsOneWidget);
      EditableText campo(String llave) => tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(ValueKey(llave)),
          matching: find.byType(EditableText),
        ),
      );
      expect(campo('ingreso-monto').controller.text, isEmpty,
          reason: 'el monto lo captura el dueño');
      expect(campo('calendario-dias').controller.text, '1, 11');
      // El nombre viene de la plantilla; el ejemplo ya tiene una "Pensión".
      await tester.enterText(
        find.byKey(const ValueKey('ingreso-nombre')),
        'Pensión del IMSS (ejemplo)',
      );
      await tester.enterText(find.byKey(const ValueKey('ingreso-monto')), '3200');
      await tester.tap(find.byKey(const ValueKey('dialogo-guardar')));
      await tester.pumpAndSettle();
      final creado = repo.datos
          .ingresosDe(IdsDemostracion.libroPapa)
          .lastWhere((i) => i.nombre == 'Pensión del IMSS (ejemplo)');
      final v = creado.vigenciaActual!;
      expect(v.montoNeto, 320000);
      expect(v.calendario.forma, FormaPago.mensual);
      expect(v.calendario.diasMes, [1, 11]);
      expect(v.calendario.regla, ReglaDiaInhabil.siguienteDiaHabil);
      expect(creado.tipo, TipoIngreso.pension);
      // Equivalente semanal de dos pagos al mes: 24 pagos al año.
      expect(Equivalente.de(320000, v.calendario.frecuencia).semanal, 147692);
    });

    testWidgets('el apoyo 60+ pide la fecha de un pago conocido antes de '
        'guardar', (tester) async {
      final repo = await _montar(tester, dispositivo: TipoDispositivo.laptop, sesion: dueno);
      await _ir(tester, SeccionFinanzas.ingresos.ruta);
      _contenedor(tester).read(libroElegidoProvider.notifier).elegir(IdsDemostracion.libroPapa);
      await tester.pumpAndSettle();
      final antes = repo.datos.ingresosDe(IdsDemostracion.libroPapa).length;
      await tester.tap(find.byKey(const ValueKey('ingresos-plantilla-Apoyo 60+')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('ingreso-monto')), '6000');
      await tester.tap(find.byKey(const ValueKey('dialogo-guardar')));
      await tester.pumpAndSettle();
      expect(find.text('Elige la fecha de un pago que ya conozcas'), findsOneWidget);
      expect(repo.datos.ingresosDe(IdsDemostracion.libroPapa), hasLength(antes));
    });

    testWidgets('activar la semana del libro del dueño la deja guardada',
        (tester) async {
      final repo = await _montar(tester, dispositivo: TipoDispositivo.laptop, sesion: dueno);
      _alto(tester);
      await _ir(tester, SeccionFinanzas.arranque.ruta);
      final libroId = _contenedor(tester).read(contextoFinanzasProvider).value!.libroId;
      expect(repo.datos.semanaGuardada(libroId, Semana.de(hoyDePrueba)), isNull);
      final boton = find.byKey(const ValueKey('arranque-activar'));
      await tester.ensureVisible(boton);
      await tester.tap(boton);
      await tester.pumpAndSettle();
      expect(repo.datos.semanaGuardada(libroId, Semana.de(hoyDePrueba)), isNotNull);
      expect(_ubicacion(tester), SeccionFinanzas.semana.ruta);
    });
  });

  group('Importar datos', () {
    late LecturaPlantilla lectura;

    setUpAll(() async {
      lectura = await leerPlantillaDeRuta('../data/DATOS_SEMILLA_PRESUPUESTO.xlsx');
    });

    testWidgets('archivo → vista previa → confirmar → resumen', (tester) async {
      final repo = repositorioSinCategorias(dueno);
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: ServicioSesionDemostracion(inicial: dueno),
        extras: [
          repositorioFinanzasProvider.overrideWithValue(repo),
          lectorPlantillaProvider.overrideWithValue((ruta, hoja) async => lectura),
        ],
      );
      addTearDown(repo.cerrar);
      _alto(tester);
      await _ir(tester, SeccionFinanzas.importar.ruta);
      await tester.enterText(
        find.byKey(const ValueKey('importar-ruta')),
        r'C:\datos\DATOS_SEMILLA_PRESUPUESTO.xlsx',
      );
      await tester.tap(find.byKey(const ValueKey('importar-vista-previa')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('importar-previa')), findsOneWidget);
      expect(repo.datos.categorias, isEmpty, reason: 'la vista previa no guarda');
      final confirmar = find.byKey(const ValueKey('importar-confirmar'));
      await tester.ensureVisible(confirmar);
      await tester.tap(confirmar);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('importar-resumen')), findsOneWidget);
      expect(repo.datos.categorias, isNotEmpty);
      expect(repo.datos.importaciones.single.archivo, 'DATOS_SEMILLA_PRESUPUESTO.xlsx');
      final cuantas = repo.datos.categorias.length;
      // Reimportar: sin cambios.
      await tester.tap(find.byKey(const ValueKey('importar-vista-previa')));
      await tester.pumpAndSettle();
      final otra = find.byKey(const ValueKey('importar-confirmar'));
      await tester.ensureVisible(otra);
      expect(find.text('Registrar (sin cambios)'), findsOneWidget);
      await tester.tap(otra);
      await tester.pumpAndSettle();
      expect(repo.datos.categorias, hasLength(cuantas));
    });

    testWidgets('un archivo que no existe se explica', (tester) async {
      await _montar(tester, dispositivo: TipoDispositivo.laptop, sesion: dueno);
      await _ir(tester, SeccionFinanzas.importar.ruta);
      await tester.enterText(
        find.byKey(const ValueKey('importar-ruta')),
        '/no/existe/archivo.xlsx',
      );
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('importar-vista-previa')));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('importar-error')), findsOneWidget);
      expect(find.textContaining('No encontré el archivo'), findsOneWidget);
    });
  });

  group('(+) Gasto en el teléfono (F1)', () {
    Future<void> teclear(WidgetTester tester, String digitos) async {
      for (final d in digitos.split('')) {
        await tester.tap(
          find.descendant(of: find.byType(TecladoMonto), matching: find.text(d)),
        );
      }
      await tester.pump();
    }

    testWidgets('guardar un gasto y deshacerlo lo anula con su motivo',
        (tester) async {
      final repo = await _montar(tester, dispositivo: TipoDispositivo.telefono, sesion: dueno);
      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Registrar'),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gasto'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('registro-gasto')), findsOneWidget);
      await teclear(tester, '85');
      final cuenta = find.byWidgetPredicate(
        (w) => w.key is ValueKey && '${(w.key! as ValueKey).value}'.startsWith('gasto-cuenta-'),
      );
      await tester.ensureVisible(cuenta.first);
      await tester.tap(cuenta.first);
      await tester.pump();
      final guardar = find.byKey(const ValueKey('gasto-guardar'));
      await tester.ensureVisible(guardar);
      final antes = repo.datos.movimientos.length;
      await tester.tap(guardar);
      await tester.pumpAndSettle();
      expect(repo.datos.movimientos, hasLength(antes + 1));
      final nuevo = repo.datos.movimientos.last;
      expect(nuevo.tipo, TipoMovimiento.gasto);
      expect(nuevo.monto, 8500);
      expect(find.text('Guardado'), findsOneWidget);
      await tester.tap(find.text('Deshacer'));
      await tester.pumpAndSettle();
      final anulacion = repo.datos.movimientos.last;
      expect(anulacion.tipo, TipoMovimiento.anulacion);
      expect(anulacion.anulaA, nuevo.id);
      expect(anulacion.motivo, 'Deshecho al capturar');
      expect(anulacion.id, idEstable('anulacion:${nuevo.id}'));
      expect(repo.datos.movimientos, hasLength(antes + 2), reason: 'nada se borra');
    });

    testWidgets('la cuenta maestra no ve el (+) de Finanzas con lo ajeno',
        (tester) async {
      await _montar(tester, dispositivo: TipoDispositivo.telefono, sesion: maestra);
      await _ir(tester, Rutas.finanzas);
      final c = _contenedor(tester).read(contextoFinanzasProvider).value!;
      expect(c.puedeEscribir, isFalse);
    });
  });
}
