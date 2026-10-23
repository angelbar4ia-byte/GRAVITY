// Revisión de calidad de la Fase 1 (docs/revisiones/fase-1.md): lo que le toca
// a Finanzas. I6 (hojas y fila de movimiento), I8 (Guardar siempre a la vista),
// I10 (sin reintentos automáticos), M2 (coma decimal), M5 (copia local),
// M4 (dos pagos el mismo día) y el contrato nuevo del servidor: motivo y
// `en_nombre_de` en todo movimiento del libro de papá, y la consulta de la
// cuenta maestra con vigencia de 30 minutos que se renueva.
import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/finanzas/casos_uso/servicio_finanzas.dart';
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_memoria.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_supabase.dart'
    show CopiaLocalFinanzas;
import 'package:gravity/modulos/finanzas/estado/proveedores.dart';
import 'package:gravity/modulos/finanzas/finanzas.dart'
    show SeccionFinanzas, limpiarCopiaLocalFinanzas;
import 'package:gravity/modulos/finanzas/pantallas/comunes.dart'
    show centavosDeTexto;
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/limpieza_local.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';

import '../../app/ayuda_plataforma.dart';
import '../../revision_calidad/ayuda_calidad.dart';
import 'ayuda_finanzas.dart';

class _AlmacenQueFalla extends AlmacenSeguroEnMemoria {
  @override
  Future<void> borrar(String clave) async => throw StateError('sin acceso');
}

/// Repositorio cuya carga falla mientras [falla] sea verdadero.
class _RepoQueFalla extends RepositorioFinanzasEnMemoria {
  _RepoQueFalla(DatosFinanzas datos) : super(datos: datos);

  bool falla = true;
  int intentos = 0;

  @override
  Future<CargaFinanzas> cargar() async {
    intentos++;
    if (falla) throw ErrorFinanzas.conexion;
    return super.cargar();
  }
}

void main() {
  const libroDueno = IdsDemostracion.libroDueno;
  const libroPapa = IdsDemostracion.libroPapa;
  final dueno = sesionDe(Rol.dueno);

  group('M2: la coma decimal', () {
    test('"12,5" es \$12.50 y "85,50" es \$85.50', () {
      expect(centavosDeTexto('12,5'), 1250);
      expect(centavosDeTexto('85,50'), 8550);
      expect(centavosDeTexto('0,5'), 50);
      expect(centavosDeTexto('7,'), 700);
    });

    test('la coma de miles sigue valiendo: grupos de tres dígitos', () {
      expect(centavosDeTexto('1,234'), 123400);
      expect(centavosDeTexto('12,345,678'), 1234567800);
      expect(centavosDeTexto('1,234.50'), 123450);
      expect(centavosDeTexto(r'$ 1,234.5'), 123450);
    });

    test('al estilo español: punto de miles y coma decimal', () {
      expect(centavosDeTexto('1.234,50'), 123450);
      expect(centavosDeTexto('12.345.678,9'), 1234567890);
    });

    test('el punto decimal de siempre', () {
      expect(centavosDeTexto('85'), 8500);
      expect(centavosDeTexto('85.5'), 8550);
      expect(centavosDeTexto('85.55'), 8555);
      expect(centavosDeTexto('.5'), 50);
      expect(centavosDeTexto(r'$85'), 8500);
    });

    test('lo que no es un monto, no se adivina', () {
      for (final raro in [
        '',
        ' ',
        'abc',
        '1,2345',
        '1,23,456',
        '12,345,67',
        '1.2.3',
        '1,234.567',
        '85.555',
        '1234567890',
        '1,,5',
        '-5',
      ]) {
        expect(centavosDeTexto(raro), isNull, reason: '"$raro"');
      }
    });
  });

  group('M5: la copia local de Finanzas', () {
    test('limpiarCopiaLocalFinanzas borra la de esa persona y no la de otra',
        () async {
      final almacen = AlmacenSeguroEnMemoria();
      final deDueno = CopiaLocalFinanzas(almacen, personaId: dueno.persona.id);
      final deOtra = CopiaLocalFinanzas(almacen, personaId: 'otra-persona');
      await deDueno.guardar({'fin_libros': <Object>[]});
      await deOtra.guardar({'fin_libros': <Object>[]});
      await limpiarCopiaLocalFinanzas(dueno.persona.id, almacen: almacen);
      expect(await deDueno.leer(), isNull);
      expect(await deOtra.leer(), isNotNull);
    });

    test('la clave es la convención de plataforma (finanzas.copia.<persona>)',
        () async {
      final almacen = AlmacenSeguroEnMemoria();
      await CopiaLocalFinanzas(
        almacen,
        personaId: 'p1',
      ).guardar({'fin_libros': <Object>[]});
      expect(almacen.datos.keys, [claveCopiaLocal(Modulo.finanzas, 'p1')]);
      expect(almacen.datos.keys.single, 'finanzas.copia.p1');
    });

    test('un almacén que no deja borrar no impide salir ni quitar a nadie',
        () async {
      await expectLater(
        limpiarCopiaLocalFinanzas('p1', almacen: _AlmacenQueFalla()),
        completes,
      );
    });

    test('la limpieza de plataforma la borra al quitar a la persona', () async {
      final almacen = AlmacenSeguroEnMemoria();
      final copia = CopiaLocalFinanzas(almacen, personaId: 'p1');
      await copia.guardar({'fin_libros': <Object>[]});
      await LimpiezaLocal(almacen).alQuitarPersona('p1');
      expect(await copia.leer(), isNull);
    });
  });

  group('Libro de papá: motivo y en_nombre_de en todo movimiento', () {
    test('una aportación desde el libro personal hacia papá pide motivo y va '
        'en su nombre', () async {
      final repo = repositorioDe(dueno);
      final servicio = servicioDe(repo, dueno);
      final origen = repo.cuentaDe(libroDueno, 'Mi banco').id;
      final destino = repo.cuentaDe(libroPapa, 'Cuenta de la pensión').id;
      await expectLater(
        servicio.registrarMovimiento(
          tipo: TipoMovimiento.transferencia,
          cuentaOrigenId: origen,
          cuentaDestinoId: destino,
          monto: 50000,
        ),
        throwsA(isA<ErrorFinanzas>()),
        reason: 'sin motivo',
      );
      final r = await servicio.registrarMovimiento(
        tipo: TipoMovimiento.transferencia,
        cuentaOrigenId: origen,
        cuentaDestinoId: destino,
        monto: 50000,
        motivo: 'Para las medicinas',
      );
      expect(r.movimientos.single.enNombreDe, IdsDemostracion.papa);
      expect(r.movimientos.single.motivo, 'Para las medicinas');
    });

    test('la anulación de un movimiento de papá también va en su nombre',
        () async {
      final repo = repositorioDe(dueno);
      final servicio = servicioDe(repo, dueno);
      final original = repo.datos.movimientos.firstWhere(
        (m) =>
            m.tipo == TipoMovimiento.gasto &&
            repo.datos.cuenta(m.cuentaOrigenId)?.libroId == libroPapa,
      );
      final contra = await servicio.anular(original.id, motivo: 'Se capturó mal');
      expect(contra.enNombreDe, IdsDemostracion.papa);
      expect(contra.motivo, 'Se capturó mal');
    });

    test('las salidas y los demás movimientos del libro sin motivo se rechazan '
        '(gasto, ingreso extra, remanente)', () async {
      final repo = repositorioDe(dueno);
      final servicio = servicioDe(repo, dueno);
      final banco = repo.cuentaDe(libroPapa, 'Cuenta de la pensión').id;
      await expectLater(
        servicio.registrarGasto(
          libroId: libroPapa,
          cuentaOrigenId: banco,
          lineas: const [LineaGasto(monto: 100)],
        ),
        throwsA(isA<ErrorFinanzas>()),
      );
      await expectLater(
        servicio.registrarIngresoExtra(
          libroId: libroPapa,
          monto: 100,
          cuentaDestinoId: banco,
        ),
        throwsA(isA<ErrorFinanzas>()),
      );
      await expectLater(
        servicio.registrarIngresoExtra(
          libroId: libroPapa,
          monto: 100,
          cuentaDestinoId: banco,
          motivo: '   ',
        ),
        throwsA(isA<ErrorFinanzas>()),
        reason: 'un motivo en blanco no vale',
      );
    });

    testWidgets('la hoja (+) Gasto pide el motivo siempre en el libro de papá',
        (tester) async {
      final sesion = dueno;
      final repo = repositorioDe(sesion);
      addTearDown(repo.cerrar);
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: ServicioSesionDemostracion(inicial: sesion),
        extras: [repositorioFinanzasProvider.overrideWithValue(repo)],
      );
      await abrirRegistroDelTelefono(tester, 'Gasto');
      await tester.tap(find.byKey(const ValueKey('gasto-libro-$libroPapa')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('gasto-motivo')), findsOneWidget);
      // Con monto y cuenta, Guardar sigue inactivo mientras falte el motivo.
      final teclas = find.descendant(
        of: find.byKey(const ValueKey('registro-gasto')),
        matching: find.text('5'),
      );
      await tester.tap(teclas.first);
      await tester.pump();
      FilledButton guardar() => tester.widget<FilledButton>(
        find.byKey(const ValueKey('gasto-guardar')),
      );
      expect(guardar().onPressed, isNull);
    });
  });

  group('Cuenta maestra: la consulta se renueva (vigencia de 30 min)', () {
    final maestra = sesionDe(Rol.dueno, maestra: true);

    testWidgets('se renueva a los 25 minutos mientras el libro sigue abierto y '
        'la pantalla no se tapa con "Cargando"', (tester) async {
      final repo = repositorioDe(maestra);
      addTearDown(repo.cerrar);
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: ServicioSesionDemostracion(inicial: maestra),
        extras: [repositorioFinanzasProvider.overrideWithValue(repo)],
      );
      await irA(tester, Rutas.finanzas);
      expect(repo.consultasMaestra, hasLength(1));
      final cargas = repo.vecesCargado;
      expect(cargas, greaterThanOrEqualTo(2),
          reason: 'con la consulta registrada se vuelven a pedir los datos');

      await tester.pump(const Duration(minutes: 24));
      expect(repo.consultasMaestra, hasLength(1), reason: 'aún vigente');

      await tester.pump(const Duration(minutes: 2));
      expect(repo.consultasMaestra, hasLength(2), reason: 'renovada a los 25');
      expect(repo.consultasMaestra.toSet(), hasLength(1));
      expect(find.text('Cargando Finanzas…'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(repo.vecesCargado, greaterThan(cargas));

      await tester.pump(const Duration(minutes: 25));
      expect(repo.consultasMaestra, hasLength(3));
    });

    testWidgets('al salir de Finanzas la renovación se detiene; al volver se '
        'registra de nuevo', (tester) async {
      final repo = repositorioDe(maestra);
      addTearDown(repo.cerrar);
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: ServicioSesionDemostracion(inicial: maestra),
        extras: [repositorioFinanzasProvider.overrideWithValue(repo)],
      );
      await irA(tester, Rutas.finanzas);
      expect(repo.consultasMaestra, hasLength(1));
      await irA(tester, Rutas.inicio);
      await tester.pump(const Duration(minutes: 60));
      expect(repo.consultasMaestra, hasLength(1), reason: 'sin libro abierto');
      await irA(tester, SeccionFinanzas.movimientos.ruta);
      expect(repo.consultasMaestra, hasLength(2));
    });

    testWidgets('si no se puede registrar, no se muestra el libro y se puede '
        'reintentar a mano', (tester) async {
      final repo = _ConsultaQueFalla(repositorioDe(maestra).datos);
      addTearDown(repo.cerrar);
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: ServicioSesionDemostracion(inicial: maestra),
        extras: [repositorioFinanzasProvider.overrideWithValue(repo)],
      );
      await irA(tester, Rutas.finanzas);
      await tester.pump(const Duration(seconds: 10));
      expect(repo.intentos, 1, reason: 'sin reintentos automáticos');
      expect(find.text('Reintentar'), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      repo.falla = false;
      await tester.tap(find.text('Reintentar').first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(repo.intentos, 2);
      expect(repo.consultasMaestra, hasLength(1));
    });
  });

  group('I10: sin reintentos automáticos', () {
    test('la carga que falla queda en error al instante y se reintenta a mano',
        () async {
      final repo = _RepoQueFalla(datosDeDemostracion(hoy: hoyDePrueba));
      addTearDown(repo.cerrar);
      final contenedor = ProviderContainer(
        overrides: [
          repositorioFinanzasProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(contenedor.dispose);
      await expectLater(
        contenedor.read(cargaFinanzasProvider.future),
        throwsA(isA<ErrorFinanzas>()),
      );
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(repo.intentos, 1, reason: 'sin reintentos automáticos');
      expect(contenedor.read(cargaFinanzasProvider).hasError, isTrue);
      repo.falla = false;
      await contenedor.read(cargaFinanzasProvider.notifier).recargar();
      expect(contenedor.read(cargaFinanzasProvider).hasValue, isTrue);
      expect(repo.intentos, 2);
    });
  });

  group('I6 e I8: las hojas del (+) con letra grande', () {
    testWidgets('con letra 2.0 en 360 dp, Guardar se ve, cabe y queda arriba de '
        'Cancelar (apilados)', (tester) async {
      await montarFinanzasConTamano(
        tester,
        dispositivo: TipoDispositivo.telefono,
        tamano: const Size(360, 800),
        escalaDeLetra: 2.0,
      );
      final errores = await recolectar(
        () => abrirRegistroDelTelefono(tester, 'Gasto'),
      );
      expect(errores.desbordes, isEmpty);
      final guardar = find.byKey(const ValueKey('gasto-guardar'));
      expect(guardar.hitTestable(), findsOneWidget);
      final cancelar = find.text('Cancelar');
      expect(cancelar.hitTestable(), findsOneWidget);
      final g = tester.getRect(guardar);
      final c = tester.getRect(cancelar);
      expect(g.right, lessThanOrEqualTo(360), reason: 'no se corta');
      expect(g.bottom, lessThanOrEqualTo(c.top + 1), reason: 'Guardar arriba');
    });

    testWidgets('con letra normal Cancelar y Guardar van en una sola fila',
        (tester) async {
      await montarFinanzasConTamano(
        tester,
        dispositivo: TipoDispositivo.telefono,
        tamano: const Size(411, 850),
      );
      await abrirRegistroDelTelefono(tester, 'Ingreso extra');
      final g = tester.getRect(find.byKey(const ValueKey('extra-guardar')));
      final c = tester.getRect(find.text('Cancelar'));
      expect((g.center.dy - c.center.dy).abs(), lessThan(8));
      expect(c.right, lessThan(g.left));
    });

    testWidgets('con el teclado del sistema abierto, la barra queda encima',
        (tester) async {
      await montarFinanzasConTamano(
        tester,
        dispositivo: TipoDispositivo.telefono,
        tamano: const Size(360, 800),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await abrirRegistroDelTelefono(tester, 'Gasto');
      await tester.pump(const Duration(milliseconds: 500));
      final guardar = tester.getRect(find.byKey(const ValueKey('gasto-guardar')));
      expect(guardar.bottom, lessThanOrEqualTo(800 - 300 + 1));
      expect(find.byKey(const ValueKey('gasto-guardar')).hitTestable(), findsOneWidget);
    });

    testWidgets('la fila de un movimiento con letra 2.0 muestra el monto sin '
        'desbordes', (tester) async {
      await montarFinanzasConTamano(
        tester,
        dispositivo: TipoDispositivo.telefono,
        tamano: const Size(360, 840),
        escalaDeLetra: 2.0,
      );
      final errores = await recolectar(
        () => irA(tester, SeccionFinanzas.movimientos.ruta),
      );
      expect(errores.desbordes, isEmpty);
      final fila = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey &&
            '${(w.key! as ValueKey).value}'.startsWith('movimiento-') &&
            !'${(w.key! as ValueKey).value}'.startsWith('movimiento-menu-'),
      );
      expect(fila, findsWidgets);
      final montos = find.descendant(of: fila.first, matching: find.textContaining(r'$'));
      expect(montos, findsWidgets);
      expect(tester.getRect(montos.first).right, lessThanOrEqualTo(360));
    });

    testWidgets('anular sigue disponible desde la fila (menú con su llave)',
        (tester) async {
      final repo = await montarFinanzasConTamano(
        tester,
        dispositivo: TipoDispositivo.telefono,
        tamano: const Size(360, 840),
      );
      await irA(tester, SeccionFinanzas.movimientos.ruta);
      final menu = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey &&
            '${(w.key! as ValueKey).value}'.startsWith('movimiento-menu-'),
      );
      expect(menu, findsWidgets);
      expect(repo.datos.movimientos, isNotEmpty);
    });
  });

  group('M4: dos pagos el mismo día se marcan juntos', () {
    test('la ocurrencia de un ingreso con dos pagos el 28/feb vale los dos',
        () async {
      final repo = repositorioDe(dueno);
      final febrero = DateTime(2026, 2, 24, 10);
      final servicio = servicioDe(repo, dueno, ahora: febrero);
      final banco = repo.cuentaDe(libroDueno, 'Mi banco');
      final origen = repo.cuentaDe(libroDueno, 'Honorarios');
      await repo.guardarIngreso(
        Ingreso(
          id: 'ing-dos-dias',
          libroId: libroDueno,
          nombre: 'Pago de ejemplo',
          cuentaOrigenId: origen.id,
          cuentaDestinoId: banco.id,
          vigencias: [
            VigenciaIngreso(
              id: 'vig-dos-dias',
              ingresoId: 'ing-dos-dias',
              montoNeto: 100000,
              calendario: const CalendarioConfig.mensual([
                30,
                0,
              ], regla: ReglaDiaInhabil.sinCambio),
              desde: Fecha(2026, 1, 1),
            ),
          ],
        ),
      );
      final vence = vencimientosEntre(
        repo.datos,
        libroDueno,
        Fecha(2026, 2, 23),
        Fecha(2026, 3, 1),
      ).where((v) => v.origenId == 'ing-dos-dias').toList();
      expect(vence, hasLength(2));
      await servicio.marcarIngreso(libroDueno, vence.first, EstadoOcurrencia.noLlegara);
      final o = repo.datos.ocurrencias.single;
      expect(o.montoEsperado, 200000, reason: 'los dos pagos del día');
      expect(o.fechaProgramada, Fecha(2026, 2, 28));
    });
  });
}

/// Repositorio cuyo registro de la consulta de la cuenta maestra falla
/// mientras [falla] sea verdadero.
class _ConsultaQueFalla extends RepositorioFinanzasEnMemoria {
  _ConsultaQueFalla(DatosFinanzas datos)
    : super(datos: datos, personaId: personaMaestra.id, esMaestra: true);

  bool falla = true;
  int intentos = 0;

  @override
  Future<void> registrarConsultaMaestra(String libroId) async {
    intentos++;
    if (falla) throw ErrorFinanzas.conexion;
    await super.registrarConsultaMaestra(libroId);
  }
}
