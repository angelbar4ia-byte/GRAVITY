// Pantallas de Finanzas dentro de la app: rutas y permisos (D19), cuenta
// maestra de solo lectura con su consulta en la bitácora, asistente de
// arranque con los ingresos de papá, importación, ajustes y el flujo F1 del
// teléfono (registrar un gasto y deshacerlo).
import 'dart:io';
import 'dart:typed_data';

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide
        Semaforo,
        formatearCentavos,
        TipoLibro,
        VisibilidadLibro,
        puntosBaseEnCien;
import 'package:finanzas_dominio/finanzas_dominio.dart' as dom show TipoLibro;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/app/router.dart';
import 'package:gravity/diseno/diseno.dart'
    show TecladoMonto, montosVisiblesProvider;
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/modulos/finanzas/datos/ids.dart' show idEstable;
import 'package:gravity/modulos/finanzas/datos/repositorio_memoria.dart';
import 'package:gravity/modulos/finanzas/estado/proveedores.dart';
import 'package:gravity/modulos/finanzas/finanzas.dart';
import 'package:gravity/modulos/finanzas/pantallas/registro/hoja_gasto.dart'
    show librosParaRegistrar;
import 'package:gravity/modulos/finanzas/pantallas/laptop/importar.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';
import 'package:gravity/nucleo/permisos/permisos.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';

import '../../app/ayuda_plataforma.dart';
import 'ayuda_finanzas.dart';

GoRouter _router(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AppGravity)))
        .read(routerProvider);

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

/// Deja los montos a la vista (se abren ocultos, como en la app): sin la marca
/// "Montos ocultos" estorbando al tocar.
Future<void> _verMontos(WidgetTester tester) async {
  _contenedor(tester).read(montosVisiblesProvider.notifier).fijar(true);
  await tester.pump();
}

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
  await _verMontos(tester);
  return repo;
}

void main() {
  final dueno = sesionDe(Rol.dueno);
  final pareja = sesionDe(Rol.coadministrador);
  // La cuenta maestra con login propio: otra persona (coadministrador), sin libro
  // propio, de solo lectura total (respuestas del dueño del 23/oct/2026).
  final maestra = sesionDe(Rol.coadministrador, maestra: true);

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
        SeccionFinanzas.values
            .where((s) => s.esDeConfiguracion)
            .map((s) => s.segmento),
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
      await _montar(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: dueno,
      );
      await _ir(tester, Rutas.finanzas);
      expect(
        find.byKey(const ValueKey('finanzas-semana-resumen')),
        findsOneWidget,
      );
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
      await _montar(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: pareja,
      );
      await _ir(tester, SeccionFinanzas.arranque.ruta);
      expect(_ubicacion(tester), SeccionFinanzas.arranque.ruta);
      expect(find.byKey(const ValueKey('arranque-pasos')), findsOneWidget);
    });
  });

  group('Cuenta maestra (D19)', () {
    testWidgets('entra por la portada: ve los libros sin leerlos y sin dejar '
        'consulta', (tester) async {
      final repo = await _montar(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: maestra,
      );
      await _ir(tester, Rutas.finanzas);
      expect(find.byKey(const ValueKey('finanzas-portada')), findsOneWidget);
      expect(
        repo.consultasMaestra,
        isEmpty,
        reason: 'ver la portada no consulta',
      );
      final c = _contenedor(tester).read(contextoFinanzasProvider).value!;
      expect(c.enPortada, isTrue);
      expect(c.libros, hasLength(4));
      for (final l in c.libros) {
        expect(
          find.byKey(ValueKey('finanzas-portada-libro-${l.id}')),
          findsOneWidget,
        );
      }
    });

    testWidgets('abrir un libro ajeno registra la consulta y no muestra '
        'botones de escribir', (tester) async {
      final repo = await _montar(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: maestra,
      );
      await _ir(tester, Rutas.finanzas);
      await tester.tap(
        find.byKey(
          const ValueKey(
            'finanzas-portada-libro-${IdsDemostracion.libroDueno}',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.consultasMaestra, [IdsDemostracion.libroDueno]);
      final c = _contenedor(tester).read(contextoFinanzasProvider).value!;
      expect(c.permiso.comoMaestra, isTrue);
      expect(c.libroId, IdsDemostracion.libroDueno);
      expect(c.puedeEscribir, isFalse);
      expect(c.puedeAdministrar, isFalse);
      expect(
        find.byKey(const ValueKey('finanzas-registrar-movimiento')),
        findsNothing,
        reason: 'ni (+) ni Registrar movimiento en lo ajeno',
      );
      // Sin asistente, importar ni ajustes: es de solo lectura total (M6).
      expect(
        find.byKey(const ValueKey('finanzas-seccion-arranque')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('finanzas-seccion-importar')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('finanzas-seccion-ajustes')),
        findsNothing,
      );
      // Puede volver a la portada.
      await tester.tap(find.byKey(const ValueKey('finanzas-todos-los-libros')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('finanzas-portada')), findsOneWidget);
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
      contenedor
          .read(libroElegidoProvider.notifier)
          .elegir(IdsDemostracion.libroDueno);
      await tester.pumpAndSettle();
      expect(repo.consultasMaestra, [IdsDemostracion.libroDueno]);
      await _ir(tester, SeccionFinanzas.movimientos.ruta);
      expect(
        repo.consultasMaestra.where((l) => l == IdsDemostracion.libroDueno),
        hasLength(1),
      );
      contenedor
          .read(libroElegidoProvider.notifier)
          .elegir(IdsDemostracion.libroCasa);
      await tester.pumpAndSettle();
      expect(repo.consultasMaestra, [
        IdsDemostracion.libroDueno,
        IdsDemostracion.libroCasa,
      ]);
    });

    testWidgets('Movimientos de lo ajeno: sin Anular', (tester) async {
      await _montar(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: maestra,
      );
      await _ir(tester, SeccionFinanzas.movimientos.ruta);
      _contenedor(tester)
          .read(libroElegidoProvider.notifier)
          .elegir(IdsDemostracion.libroDueno);
      await tester.pumpAndSettle();
      final c = _contenedor(tester).read(contextoFinanzasProvider).value!;
      expect(c.puedeEscribir, isFalse);
      expect(
        find.byKey(const ValueKey('finanzas-registrar-movimiento')),
        findsNothing,
      );
      expect(find.text('Anular…'), findsNothing);
    });

    testWidgets('la maestra que no es la dueña no abre Ajustes, Importar ni '
        'el asistente (solo lectura total)', (tester) async {
      await _montar(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: maestra,
      );
      for (final s in [
        SeccionFinanzas.ajustes,
        SeccionFinanzas.importar,
        SeccionFinanzas.arranque,
      ]) {
        await _ir(tester, s.ruta);
        expect(_ubicacion(tester), isNot(s.ruta), reason: s.segmento);
      }
    });

    testWidgets(
      'una maestra con libro propio (datos viejos) tampoco escribe en '
      'lo suyo',
      (tester) async {
        await _montar(
          tester,
          dispositivo: TipoDispositivo.laptop,
          sesion: sesionParejaMaestra(),
        );
        await _ir(tester, Rutas.finanzas);
        final c = _contenedor(tester).read(contextoFinanzasProvider).value!;
        expect(c.libroId, IdsDemostracion.libroPareja);
        expect(c.esLibroPropio, isTrue);
        expect(c.permiso.comoMaestra, isFalse);
        expect(c.soloLecturaTotal, isTrue);
        expect(c.puedeEscribir, isFalse);
        expect(c.puedeAdministrar, isFalse);
        expect(c.administraHogar, isFalse);
        expect(
          find.byKey(const ValueKey('finanzas-registrar-movimiento')),
          findsNothing,
        );
      },
    );

    testWidgets('el dueño que es también la maestra escribe en lo suyo y en '
        'lo ajeno solo lee, con consulta', (tester) async {
      final repo = await _montar(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: sesionDuenoMaestro(),
      );
      await _ir(tester, Rutas.finanzas);
      var c = _contenedor(tester).read(contextoFinanzasProvider).value!;
      expect(c.libroId, IdsDemostracion.libroDueno);
      expect(c.puedeEscribir, isTrue);
      expect(c.puedeAdministrar, isTrue);
      expect(c.administraHogar, isTrue);
      expect(repo.consultasMaestra, isEmpty, reason: 'lo suyo no se consulta');
      _contenedor(tester)
          .read(libroElegidoProvider.notifier)
          .elegir(IdsDemostracion.libroPareja);
      await tester.pumpAndSettle();
      c = _contenedor(tester).read(contextoFinanzasProvider).value!;
      expect(c.permiso.comoMaestra, isTrue);
      expect(c.puedeEscribir, isFalse);
      expect(repo.consultasMaestra, [IdsDemostracion.libroPareja]);
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
    testWidgets('el dueño cambia la meta de su libro y queda guardada', (
      tester,
    ) async {
      final repo = await _montar(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: dueno,
      );
      await _ir(tester, SeccionFinanzas.ajustes.ruta);
      final libroId = _contenedor(tester)
          .read(contextoFinanzasProvider)
          .value!
          .libroId;
      await tester.enterText(find.byKey(const ValueKey('ajustes-meta')), '25');
      await tester.ensureVisible(find.byKey(const ValueKey('ajustes-guardar')));
      await tester.tap(find.byKey(const ValueKey('ajustes-guardar')));
      await tester.pumpAndSettle();
      expect(repo.datos.parametrosDe(libroId).metaRemanentePuntosBase, 2500);
      expect(find.text('Ajustes guardados.'), findsOneWidget);
    });

    testWidgets('un porcentaje fuera de rango no se guarda', (tester) async {
      final repo = await _montar(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: dueno,
      );
      await _ir(tester, SeccionFinanzas.ajustes.ruta);
      final libroId = _contenedor(tester)
          .read(contextoFinanzasProvider)
          .value!
          .libroId;
      final antes = repo.datos.parametrosDe(libroId).metaRemanentePuntosBase;
      await tester.enterText(find.byKey(const ValueKey('ajustes-meta')), '150');
      await tester.ensureVisible(find.byKey(const ValueKey('ajustes-guardar')));
      await tester.tap(find.byKey(const ValueKey('ajustes-guardar')));
      await tester.pumpAndSettle();
      expect(repo.datos.parametrosDe(libroId).metaRemanentePuntosBase, antes);
      expect(find.text('De 0 a 100'), findsWidgets);
    });

    testWidgets(
      'lista los libros con sus albaceas y avisa de la cuenta maestra',
      (tester) async {
        await _montar(
          tester,
          dispositivo: TipoDispositivo.laptop,
          sesion: dueno,
        );
        _alto(tester);
        await _ir(tester, SeccionFinanzas.ajustes.ruta);
        final papa = find.byKey(
          const ValueKey('ajustes-libro-${IdsDemostracion.libroPapa}'),
        );
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
        expect(
          find.byKey(const ValueKey('ajustes-nuevo-compartido')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('ajustes-nuevo-representado')),
          findsNothing,
          reason: 'el libro de papá ya existe',
        );
        expect(
          find.textContaining('cuenta maestra (Cuenta maestra de ejemplo)'),
          findsOneWidget,
        );
      },
    );

    testWidgets('precargar los festivos del año los deja inactivos', (
      tester,
    ) async {
      final repo = await _montar(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: dueno,
      );
      await _ir(tester, SeccionFinanzas.ajustes.ruta);
      final boton = find.byKey(const ValueKey('ajustes-precargar'));
      await tester.ensureVisible(boton);
      await tester.tap(boton);
      await tester.pumpAndSettle();
      expect(repo.datos.diasInhabiles, isNotEmpty);
      expect(repo.datos.diasInhabiles.every((d) => !d.activo), isTrue);
      final primero = find.byKey(
        ValueKey(
          'ajustes-dia-${repo.datos.diasInhabiles.where((d) => d.fecha.anio == 2026).map((d) => d.fecha).reduce((a, b) => a.antesDe(b) ? a : b)}',
        ),
      );
      await tester.ensureVisible(primero);
      await tester.tap(primero);
      await tester.pumpAndSettle();
      expect(repo.datos.diasInhabiles.where((d) => d.activo), hasLength(1));
      expect(
        repo.datos.diasInhabiles.firstWhere((d) => d.activo).revisadoPor,
        dueno.persona.id,
      );
    });

    testWidgets('el dueño que es también la maestra ve en Privacidad que lo '
        'es', (tester) async {
      await _montar(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: sesionDuenoMaestro(),
      );
      _alto(tester);
      await _ir(tester, SeccionFinanzas.ajustes.ruta);
      expect(find.byKey(const ValueKey('ajustes-guardar')), findsOneWidget);
      expect(find.textContaining('cuenta maestra del hogar'), findsOneWidget);
    });

    testWidgets('un libro compartido nuevo queda elegido', (tester) async {
      final repo = await _montar(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: dueno,
      );
      _alto(tester);
      await _ir(tester, SeccionFinanzas.ajustes.ruta);
      final boton = find.byKey(const ValueKey('ajustes-nuevo-compartido'));
      await tester.ensureVisible(boton);
      await tester.tap(boton);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('compartido-nombre')),
        'Vacaciones',
      );
      await tester.tap(
        find.byKey(ValueKey('compartido-miembro-${IdsDemostracion.pareja}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('compartido-crear')));
      await tester.pumpAndSettle();
      final nuevo = repo.datos.libros.firstWhere(
        (l) => l.nombre == 'Vacaciones',
      );
      expect(nuevo.tipo, dom.TipoLibro.compartido);
      expect(
        nuevo.vigentes(hoyDePrueba).map((m) => m.personaId).toSet(),
        adultosDeEjemplo,
      );
      expect(_contenedor(tester).read(libroElegidoProvider), nuevo.id);
    });
  });

  group('Asistente de arranque', () {
    testWidgets('tiene los 5 pasos y el resumen con Activar semana', (
      tester,
    ) async {
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

    testWidgets(
      'en el libro de papá ofrece la pensión (días 1 y 11) y el apoyo '
      '60+, sin montos ni fechas inventados',
      (tester) async {
        final repo = await _montar(
          tester,
          dispositivo: TipoDispositivo.laptop,
          sesion: dueno,
        );
        await _ir(tester, SeccionFinanzas.arranque.ruta);
        _contenedor(tester)
            .read(libroElegidoProvider.notifier)
            .elegir(IdsDemostracion.libroPapa);
        await tester.pumpAndSettle();
        await tester.tap(find.text('2. Ingresos'));
        await tester.pumpAndSettle();
        final pension = find.byKey(
          const ValueKey('arranque-plantilla-Pensión'),
        );
        expect(pension, findsOneWidget);
        expect(
          find.byKey(const ValueKey('arranque-plantilla-Apoyo 60+')),
          findsOneWidget,
        );
        await tester.ensureVisible(pension);
        await tester.tap(pension);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('ingreso-ayuda-plantilla')),
          findsOneWidget,
        );
        EditableText campo(String llave) => tester.widget<EditableText>(
          find.descendant(
            of: find.byKey(ValueKey(llave)),
            matching: find.byType(EditableText),
          ),
        );
        expect(
          campo('ingreso-monto').controller.text,
          isEmpty,
          reason: 'el monto lo captura el dueño',
        );
        expect(campo('calendario-dias').controller.text, '1, 11');
        // El nombre viene de la plantilla; el ejemplo ya tiene una "Pensión".
        await tester.enterText(
          find.byKey(const ValueKey('ingreso-nombre')),
          'Pensión del IMSS (ejemplo)',
        );
        await tester.enterText(
          find.byKey(const ValueKey('ingreso-monto')),
          '3200',
        );
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
      },
    );

    testWidgets('el apoyo 60+ pide la fecha de un pago conocido antes de '
        'guardar', (tester) async {
      final repo = await _montar(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: dueno,
      );
      await _ir(tester, SeccionFinanzas.ingresos.ruta);
      _contenedor(tester)
          .read(libroElegidoProvider.notifier)
          .elegir(IdsDemostracion.libroPapa);
      await tester.pumpAndSettle();
      final antes = repo.datos.ingresosDe(IdsDemostracion.libroPapa).length;
      await tester.tap(
        find.byKey(const ValueKey('ingresos-plantilla-Apoyo 60+')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('ingreso-monto')),
        '6000',
      );
      await tester.tap(find.byKey(const ValueKey('dialogo-guardar')));
      await tester.pumpAndSettle();
      expect(
        find.text('Elige la fecha de un pago que ya conozcas'),
        findsOneWidget,
      );
      expect(
        repo.datos.ingresosDe(IdsDemostracion.libroPapa),
        hasLength(antes),
      );
    });

    testWidgets('activar la semana del libro del dueño la deja guardada', (
      tester,
    ) async {
      final repo = await _montar(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: dueno,
      );
      _alto(tester);
      await _ir(tester, SeccionFinanzas.arranque.ruta);
      final libroId = _contenedor(tester)
          .read(contextoFinanzasProvider)
          .value!
          .libroId;
      expect(
        repo.datos.semanaGuardada(libroId, Semana.de(hoyDePrueba)),
        isNull,
      );
      final boton = find.byKey(const ValueKey('arranque-activar'));
      await tester.ensureVisible(boton);
      await tester.tap(boton);
      await tester.pumpAndSettle();
      expect(
        repo.datos.semanaGuardada(libroId, Semana.de(hoyDePrueba)),
        isNotNull,
      );
      expect(_ubicacion(tester), SeccionFinanzas.semana.ruta);
    });
  });

  group('Importar datos (selector de archivos)', () {
    late Uint8List bytesSemilla;

    setUpAll(() async {
      // El archivo semilla real (sin autor): sigue importando con el selector.
      bytesSemilla = await File('../data/DATOS_SEMILLA_PRESUPUESTO.xlsx')
          .readAsBytes();
    });

    List<Override> conArchivo(ArchivoElegido? archivo) => [
      selectorArchivoProvider.overrideWithValue(() async => archivo),
    ];

    testWidgets('elegir archivo → vista previa → confirmar → resumen; ya no '
        'se escribe una ruta', (tester) async {
      final repo = repositorioSinCategorias(dueno);
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: ServicioSesionDemostracion(inicial: dueno),
        extras: [
          repositorioFinanzasProvider.overrideWithValue(repo),
          ...conArchivo(
            ArchivoElegido('DATOS_SEMILLA_PRESUPUESTO.xlsx', bytesSemilla),
          ),
        ],
      );
      addTearDown(repo.cerrar);
      await _verMontos(tester);
      _alto(tester);
      await _ir(tester, SeccionFinanzas.importar.ruta);
      expect(
        find.byKey(const ValueKey('importar-ruta')),
        findsNothing,
        reason: 'la ruta escrita quedó oculta (solo pruebas)',
      );
      expect(find.byKey(const ValueKey('importar-elegir')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('importar-elegir')));
      await tester.pumpAndSettle();
      expect(
        find.text('Archivo: DATOS_SEMILLA_PRESUPUESTO.xlsx'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('importar-previa')), findsOneWidget);
      expect(
        repo.datos.categorias,
        isEmpty,
        reason: 'la vista previa no guarda',
      );
      final confirmar = find.byKey(const ValueKey('importar-confirmar'));
      await tester.ensureVisible(confirmar);
      await tester.tap(confirmar);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('importar-resumen')), findsOneWidget);
      expect(repo.datos.categorias, isNotEmpty);
      expect(
        repo.datos.importaciones.single.archivo,
        'DATOS_SEMILLA_PRESUPUESTO.xlsx',
      );
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

    testWidgets('si la persona cancela el selector no pasa nada', (
      tester,
    ) async {
      final repo = repositorioSinCategorias(dueno);
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: ServicioSesionDemostracion(inicial: dueno),
        extras: [
          repositorioFinanzasProvider.overrideWithValue(repo),
          ...conArchivo(null),
        ],
      );
      addTearDown(repo.cerrar);
      await _ir(tester, SeccionFinanzas.importar.ruta);
      await tester.tap(find.byKey(const ValueKey('importar-elegir')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('importar-previa')), findsNothing);
      expect(find.byKey(const ValueKey('importar-error')), findsNothing);
      expect(find.byKey(const ValueKey('importar-archivo')), findsNothing);
    });

    testWidgets('un archivo que no es .xlsx ni .csv se explica', (
      tester,
    ) async {
      final repo = repositorioSinCategorias(dueno);
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: ServicioSesionDemostracion(inicial: dueno),
        extras: [
          repositorioFinanzasProvider.overrideWithValue(repo),
          ...conArchivo(ArchivoElegido('notas.docx', Uint8List(10))),
        ],
      );
      addTearDown(repo.cerrar);
      await _ir(tester, SeccionFinanzas.importar.ruta);
      await tester.tap(find.byKey(const ValueKey('importar-elegir')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('importar-error')), findsOneWidget);
      expect(find.textContaining('.xlsx o .csv'), findsWidgets);
      expect(repo.datos.categorias, isEmpty);
    });

    testWidgets('un .csv elegido con el selector también se lee', (
      tester,
    ) async {
      final repo = repositorioSinCategorias(dueno);
      final csv = Uint8List.fromList(
        'Nivel 1,Nivel 2,Nivel 3,Naturaleza,Prioridad,Protegida\n'
                'Vivienda y servicios,Luz,,fija,necesario,sí\n'
            .codeUnits,
      );
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: ServicioSesionDemostracion(inicial: dueno),
        extras: [
          repositorioFinanzasProvider.overrideWithValue(repo),
          ...conArchivo(ArchivoElegido('categorias.csv', csv)),
        ],
      );
      addTearDown(repo.cerrar);
      await _ir(tester, SeccionFinanzas.importar.ruta);
      await tester.tap(find.byKey(const ValueKey('importar-elegir')));
      await tester.pumpAndSettle();
      // O se entiende o se explica, pero no se rompe la pantalla.
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('importar-previa')).evaluate().isNotEmpty ||
            find.byKey(const ValueKey('importar-error')).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('ruta oculta (solo pruebas): un archivo que no existe se '
        'explica', (tester) async {
      final repo = repositorioSinCategorias(dueno);
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: ServicioSesionDemostracion(inicial: dueno),
        extras: [
          repositorioFinanzasProvider.overrideWithValue(repo),
          rutaManualProvider.overrideWithValue(true),
        ],
      );
      addTearDown(repo.cerrar);
      await _verMontos(tester);
      await _ir(tester, SeccionFinanzas.importar.ruta);
      await tester.enterText(
        find.byKey(const ValueKey('importar-ruta')),
        '/no/existe/archivo.xlsx',
      );
      await tester.pump(); // el botón se habilita al haber una ruta
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
          find.descendant(
            of: find.byType(TecladoMonto),
            matching: find.text(d),
          ),
        );
      }
      await tester.pump();
    }

    testWidgets('guardar un gasto y deshacerlo lo anula con su motivo', (
      tester,
    ) async {
      final repo = await _montar(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: dueno,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Registrar'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gasto'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('registro-gasto')), findsOneWidget);
      await teclear(tester, '85');
      final cuenta = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey &&
            '${(w.key! as ValueKey).value}'.startsWith('gasto-cuenta-'),
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
      expect(
        repo.datos.movimientos,
        hasLength(antes + 2),
        reason: 'nada se borra',
      );
    });

    testWidgets('la cuenta maestra no registra: la hoja del (+) solo avisa que '
        'es de solo lectura', (tester) async {
      await _montar(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: maestra,
      );
      await _ir(tester, Rutas.finanzas);
      final c = _contenedor(tester).read(contextoFinanzasProvider).value!;
      expect(c.puedeEscribir, isFalse);
      expect(librosParaRegistrar(c), isEmpty);
    });
  });
}
