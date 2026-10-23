// Respuestas del dueño del 23/oct/2026 en pantalla: la hoja (+) Gasto sale de
// una cuenta existente (o crea la primera ahí mismo) y la categoría es
// opcional; la deuda elige su regla de día inhábil; Libros y albaceas pide
// Pública o Privada al crear, deja salirse y administra los miembros.
// Datos de ejemplo inventados (hogar de Ana y Alex).
import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide Semaforo, formatearCentavos, TipoLibro, VisibilidadLibro, puntosBaseEnCien;
import 'package:finanzas_dominio/finanzas_dominio.dart' as dom
    show TipoLibro, VisibilidadLibro;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/app/router.dart';
import 'package:gravity/diseno/diseno.dart' as dis
    show AccesoLibro, TecladoMonto, VisibilidadLibro, montosVisiblesProvider;
import 'package:gravity/modulos/finanzas/casos_uso/sugerencias.dart';
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_memoria.dart';
import 'package:gravity/modulos/finanzas/estado/proveedores.dart';
import 'package:gravity/modulos/finanzas/finanzas.dart' show SeccionFinanzas;
import 'package:gravity/modulos/finanzas/pantallas/comunes.dart' show opcionDe;
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';

import '../../app/ayuda_plataforma.dart';
import '../../revision_calidad/ayuda_calidad.dart';
import 'ayuda_finanzas.dart';

ProviderContainer _contenedor(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AppGravity)));

Future<void> _teclear(WidgetTester tester, String digitos) async {
  for (final d in digitos.split('')) {
    await tester.tap(
      find.descendant(of: find.byType(dis.TecladoMonto), matching: find.text(d)),
    );
  }
  await tester.pump();
}

/// El hogar de ejemplo del [sesion], pero con el libro del dueño sin cuentas
/// para pagar (efectivo, banco ni tarjeta) y sin gastos: la hoja debe ofrecer
/// crear la primera.
RepositorioFinanzasEnMemoria _sinCuentasParaPagar(Sesion sesion) {
  final base = repositorioDe(sesion);
  final d = base.datos;
  final pagables = {
    for (final c in d.cuentasDe(IdsDemostracion.libroDueno))
      if (c.clase == ClaseCuenta.activo || c.clase == ClaseCuenta.pasivo) c.id,
  };
  return RepositorioFinanzasEnMemoria(
    datos: d.copiar(
      cuentas: [
        for (final c in d.cuentas)
          if (!pagables.contains(c.id)) c,
      ],
      movimientos: [
        for (final m in d.movimientos)
          if (!pagables.contains(m.cuentaOrigenId) &&
              !pagables.contains(m.cuentaDestinoId))
            m,
      ],
      ingresos: const [],
      compromisos: const [],
      sobres: const [],
      deudas: const [],
      semanas: const [],
    ),
    personaId: sesion.persona.id,
    personas: personasDeDemostracion(),
    adultosConFinanzas: adultosDeEjemplo,
    reloj: () => ahoraDePrueba,
  );
}

/// Sin historial de gastos en el libro del dueño (primera vez que registra).
RepositorioFinanzasEnMemoria _sinHistorial(Sesion sesion) {
  final base = repositorioDe(sesion);
  final d = base.datos;
  final cuentasDelLibro = {
    for (final c in d.cuentasDe(IdsDemostracion.libroDueno)) c.id,
  };
  return RepositorioFinanzasEnMemoria(
    datos: d.copiar(
      movimientos: [
        for (final m in d.movimientos)
          if (m.tipo != TipoMovimiento.gasto ||
              !cuentasDelLibro.contains(m.cuentaOrigenId))
            m,
      ],
    ),
    personaId: sesion.persona.id,
    personas: personasDeDemostracion(),
    adultosConFinanzas: adultosDeEjemplo,
    reloj: () => ahoraDePrueba,
  );
}

Future<void> _montarTelefono(
  WidgetTester tester,
  RepositorioFinanzasEnMemoria repo,
  Sesion sesion,
) async {
  addTearDown(repo.cerrar);
  await montarApp(
    tester,
    dispositivo: TipoDispositivo.telefono,
    sesion: ServicioSesionDemostracion(inicial: sesion),
    extras: [repositorioFinanzasProvider.overrideWithValue(repo)],
  );
  tester.view.physicalSize = const Size(411, 850);
  _contenedor(tester).read(dis.montosVisiblesProvider.notifier).fijar(true);
  await tester.pump();
}

void main() {
  const libroDueno = IdsDemostracion.libroDueno;
  const casa = IdsDemostracion.libroCasa;
  final dueno = sesionDe(Rol.dueno);
  final pareja = sesionDe(Rol.coadministrador);

  group('(+) Gasto: sale de una cuenta existente del libro activo', () {
    testWidgets('ofrece las cuentas del libro activo, no las de otros libros',
        (tester) async {
      final repo = repositorioDe(dueno);
      await _montarTelefono(tester, repo, dueno);
      await abrirRegistroDelTelefono(tester, 'Gasto');
      final esperadas = cuentasParaPagar(repo.datos, libroDueno);
      expect(esperadas, isNotEmpty);
      for (final c in esperadas) {
        expect(find.byKey(ValueKey('gasto-cuenta-${c.id}')), findsOneWidget, reason: c.nombre);
      }
      final deOtros = repo.datos.cuentas.where(
        (c) => c.libroId != null && c.libroId != libroDueno && cuentasParaPagar(repo.datos, c.libroId!).contains(c),
      );
      for (final c in deOtros) {
        expect(find.byKey(ValueKey('gasto-cuenta-${c.id}')), findsNothing, reason: c.nombre);
      }
      // El formulario de cuenta nueva no estorba hasta que se pide.
      expect(find.byKey(const ValueKey('cuenta-nueva')), findsNothing);
      expect(find.byKey(const ValueKey('gasto-cuenta-nueva')), findsOneWidget);
    });

    testWidgets('sin cuentas, la hoja ofrece "Crear cuenta nueva" ahí mismo y '
        'sigue con el gasto', (tester) async {
      final repo = _sinCuentasParaPagar(dueno);
      await _montarTelefono(tester, repo, dueno);
      await abrirRegistroDelTelefono(tester, 'Gasto');
      expect(find.byKey(const ValueKey('gasto-sin-cuentas')), findsOneWidget);
      expect(find.byKey(const ValueKey('cuenta-nueva')), findsOneWidget);

      // Nombre, tipo (efectivo) y saldo inicial opcional.
      await tester.enterText(
        find.byKey(const ValueKey('cuenta-nueva-nombre')),
        'Efectivo de la cartera',
      );
      await tester.enterText(find.byKey(const ValueKey('cuenta-nueva-saldo')), '200');
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('cuenta-nueva-crear')));
      await tester.tap(find.byKey(const ValueKey('cuenta-nueva-crear')));
      await tester.pump(const Duration(milliseconds: 600));

      final cuenta = repo.datos
          .cuentasDe(libroDueno)
          .firstWhere((c) => c.nombre == 'Efectivo de la cartera');
      expect(cuenta.tipo, TipoCuenta.efectivo);
      final apertura = repo.datos.movimientos.firstWhere(
        (m) => m.cuentaDestinoId == cuenta.id,
      );
      expect((apertura.tipo, apertura.monto), (TipoMovimiento.apertura, 20000));
      // Quedó elegida: el formulario se cierra y la cuenta se ve como chip.
      expect(find.byKey(const ValueKey('cuenta-nueva')), findsNothing);
      expect(
        tester.widget<ChoiceChip>(find.byKey(ValueKey('gasto-cuenta-${cuenta.id}'))).selected,
        isTrue,
      );

      // Y se sigue con el gasto: monto → Guardar.
      await _teclear(tester, '85');
      await tester.tap(find.byKey(const ValueKey('gasto-guardar')));
      await tester.pump(const Duration(milliseconds: 600));
      final gasto = repo.datos.movimientos.last;
      expect(gasto.tipo, TipoMovimiento.gasto);
      expect(gasto.cuentaOrigenId, cuenta.id);
      expect(gasto.monto, 8500);
    });

    testWidgets('el tipo de la cuenta nueva puede ser tarjeta (lo que debes)',
        (tester) async {
      final repo = _sinCuentasParaPagar(dueno);
      await _montarTelefono(tester, repo, dueno);
      await abrirRegistroDelTelefono(tester, 'Gasto');
      await tester.enterText(find.byKey(const ValueKey('cuenta-nueva-nombre')), 'Tarjeta A');
      await tester.ensureVisible(find.text('Tarjeta'));
      await tester.pump();
      await tester.tap(find.text('Tarjeta'));
      await tester.pump();
      expect(find.text('Lo que debes hoy (opcional)'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('cuenta-nueva-crear')));
      await tester.tap(find.byKey(const ValueKey('cuenta-nueva-crear')));
      await tester.pump(const Duration(milliseconds: 600));
      final cuenta = repo.datos.cuentasDe(libroDueno).firstWhere((c) => c.nombre == 'Tarjeta A');
      expect(cuenta.tipo, TipoCuenta.tarjeta);
      expect(repo.datos.movimientos.where((m) => m.cuentaOrigenId == cuenta.id || m.cuentaDestinoId == cuenta.id), isEmpty,
          reason: 'sin saldo, sin saldo inicial');
    });

    testWidgets('un nombre repetido se explica y no crea nada', (tester) async {
      final repo = repositorioDe(dueno);
      await _montarTelefono(tester, repo, dueno);
      await abrirRegistroDelTelefono(tester, 'Gasto');
      final existente = cuentasParaPagar(repo.datos, libroDueno).first;
      await tester.ensureVisible(find.byKey(const ValueKey('gasto-cuenta-nueva')));
      await tester.tap(find.byKey(const ValueKey('gasto-cuenta-nueva')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(find.byKey(const ValueKey('cuenta-nueva-nombre')), existente.nombre);
      await tester.pump();
      final antes = repo.datos.cuentas.length;
      await tester.ensureVisible(find.byKey(const ValueKey('cuenta-nueva-crear')));
      await tester.tap(find.byKey(const ValueKey('cuenta-nueva-crear')));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Ya hay una cuenta con ese nombre.'), findsOneWidget);
      expect(repo.datos.cuentas, hasLength(antes));
    });
  });

  group('(+) Gasto: la categoría es opcional', () {
    testWidgets('sin historial no hay categoría elegida y el gasto queda en '
        '"Por clasificar"', (tester) async {
      final repo = _sinHistorial(dueno);
      await _montarTelefono(tester, repo, dueno);
      await abrirRegistroDelTelefono(tester, 'Gasto');
      expect(find.text('CATEGORÍA (OPCIONAL)'), findsOneWidget);
      final elegidas = tester
          .widgetList<ChoiceChip>(find.byWidgetPredicate(
            (w) => w is ChoiceChip && '${w.key}'.contains('gasto-categoria-'),
          ))
          .where((c) => c.selected);
      expect(elegidas, isEmpty, reason: 'no se adivina una categoría');
      await _teclear(tester, '40');
      await tester.tap(find.byKey(const ValueKey('gasto-guardar')));
      await tester.pump(const Duration(milliseconds: 600));
      final gasto = repo.datos.movimientos.last;
      expect(gasto.tipo, TipoMovimiento.gasto);
      expect(gasto.categoriaId, isNull);
      final porClasificar = repo.datos.parametrosDe(libroDueno).cuentaPorClasificarId;
      expect(gasto.cuentaDestinoId, porClasificar);
    });

    testWidgets('tocar la categoría preseleccionada la quita', (tester) async {
      final repo = repositorioDe(dueno);
      await _montarTelefono(tester, repo, dueno);
      await abrirRegistroDelTelefono(tester, 'Gasto');
      final chips = find.byWidgetPredicate(
        (w) => w is ChoiceChip && '${w.key}'.contains('gasto-categoria-'),
      );
      final elegida = tester.widgetList<ChoiceChip>(chips).firstWhere((c) => c.selected);
      await tester.tap(find.byKey(elegida.key!));
      await tester.pump();
      expect(tester.widgetList<ChoiceChip>(chips).where((c) => c.selected), isEmpty);
      await _teclear(tester, '15');
      await tester.tap(find.byKey(const ValueKey('gasto-guardar')));
      await tester.pump(const Duration(milliseconds: 600));
      expect(repo.datos.movimientos.last.categoriaId, isNull);
    });
  });

  group('(+) Ingreso extra: cuenta existente o crear la primera', () {
    testWidgets('sin cuentas donde entre el dinero, ofrece crearla', (tester) async {
      final repo = _sinCuentasParaPagar(dueno);
      await _montarTelefono(tester, repo, dueno);
      await abrirRegistroDelTelefono(tester, 'Ingreso extra');
      expect(find.byKey(const ValueKey('extra-sin-cuentas')), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('cuenta-nueva-nombre')), 'Banco de ejemplo');
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('cuenta-nueva-crear')));
      await tester.tap(find.byKey(const ValueKey('cuenta-nueva-crear')));
      await tester.pump(const Duration(milliseconds: 600));
      final cuenta = repo.datos.cuentasDe(libroDueno).firstWhere((c) => c.nombre == 'Banco de ejemplo');
      expect(cuenta.tipo, TipoCuenta.efectivo, reason: 'el primero de los tipos ofrecidos');
      await _teclear(tester, '300');
      await tester.tap(find.byKey(const ValueKey('extra-guardar')));
      await tester.pump(const Duration(milliseconds: 600));
      final ingreso = repo.datos.movimientos.last;
      expect(ingreso.tipo, TipoMovimiento.ingreso);
      expect(ingreso.cuentaDestinoId, cuenta.id);
      expect(ingreso.monto, 30000);
    });
  });

  group('Marcas del selector de libros', () {
    final hoy = hoyDePrueba;
    Libro compartido({
      dom.VisibilidadLibro v = dom.VisibilidadLibro.privada,
      bool activo = true,
    }) => Libro(
      id: 'c',
      nombre: 'Viaje',
      tipo: dom.TipoLibro.compartido,
      creadoPor: IdsDemostracion.dueno,
      visibilidad: v,
      activo: activo,
      miembros: [
        MiembroLibro(personaId: IdsDemostracion.dueno, papel: PapelLibro.miembro),
        MiembroLibro(personaId: 'otra', papel: PapelLibro.miembro),
      ],
    );

    test('un compartido privado y uno público', () {
      final privado = compartido();
      final publico = compartido(v: dom.VisibilidadLibro.publica);
      final op = opcionDe(
        privado,
        permisoEnLibro(privado, IdsDemostracion.dueno, hoy: hoy),
        IdsDemostracion.dueno,
      );
      final oc = opcionDe(
        publico,
        permisoEnLibro(publico, IdsDemostracion.dueno, hoy: hoy),
        IdsDemostracion.dueno,
      );
      expect(op.visibilidad, dis.VisibilidadLibro.privada);
      expect(oc.visibilidad, dis.VisibilidadLibro.publica);
      expect(op.marcaVisibilidad, 'Privada');
      expect(oc.marcaVisibilidad, 'Pública');
    });

    test('el adulto que lo lee sin ser miembro es lector (solo lectura)', () {
      final publico = compartido(v: dom.VisibilidadLibro.publica);
      final o = opcionDe(
        publico,
        permisoEnLibro(publico, IdsDemostracion.pareja, hoy: hoy),
        IdsDemostracion.pareja,
      );
      expect(o.acceso, dis.AccesoLibro.lector);
      expect(o.soloLectura, isTrue);
      expect(o.sinEscritura, isTrue);
    });

    test('archivado se marca y nadie registra', () {
      final archivado = compartido(activo: false);
      final o = opcionDe(
        archivado,
        permisoEnLibro(archivado, IdsDemostracion.dueno, hoy: hoy),
        IdsDemostracion.dueno,
      );
      expect(o.archivado, isTrue);
      expect(o.sinEscritura, isTrue);
      expect(o.marca, 'Archivado');
    });

    test('la cuenta maestra lo ve como solo lectura', () {
      final privado = compartido();
      final o = opcionDe(
        privado,
        permisoEnLibro(privado, 'maestra', hoy: hoy, esMaestra: true),
        'maestra',
      );
      expect(o.acceso, dis.AccesoLibro.soloLectura);
    });
  });

  group('Libros y albaceas en Ajustes', () {
    Future<RepositorioFinanzasEnMemoria> montarAjustes(
      WidgetTester tester,
      Sesion sesion,
    ) async {
      final repo = repositorioDe(sesion);
      addTearDown(repo.cerrar);
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: ServicioSesionDemostracion(inicial: sesion),
        extras: [repositorioFinanzasProvider.overrideWithValue(repo)],
      );
      tester.view.physicalSize = const Size(1440, 4000);
      _contenedor(tester).read(dis.montosVisiblesProvider.notifier).fijar(true);
      _contenedor(tester).read(routerProvider).go(SeccionFinanzas.ajustes.ruta);
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('al crear un compartido se elige Privada (por omisión) o '
        'Pública', (tester) async {
      final repo = await montarAjustes(tester, dueno);
      final boton = find.byKey(const ValueKey('ajustes-nuevo-compartido'));
      await tester.ensureVisible(boton);
      await tester.tap(boton);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('libro-visibilidad')), findsOneWidget);
      final selector = tester.widget<SegmentedButton<dom.VisibilidadLibro>>(
        find.byKey(const ValueKey('libro-visibilidad')),
      );
      expect(selector.selected, {dom.VisibilidadLibro.privada});
      expect(find.textContaining('El dueño no entra si no es miembro'), findsOneWidget);

      await tester.tap(find.text('Pública'));
      await tester.pump();
      expect(find.textContaining('Además la leen, sin escribir'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('compartido-nombre')), 'Gastos abiertos');
      await tester.tap(find.byKey(ValueKey('compartido-miembro-${IdsDemostracion.pareja}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('compartido-crear')));
      await tester.pumpAndSettle();
      final nuevo = repo.datos.libros.firstWhere((l) => l.nombre == 'Gastos abiertos');
      expect(nuevo.visibilidad, dom.VisibilidadLibro.publica);
      expect(nuevo.esAdministrador(IdsDemostracion.dueno), isTrue);
    });

    testWidgets('un compartido nuevo sin tocar la visibilidad queda privado',
        (tester) async {
      final repo = await montarAjustes(tester, dueno);
      final boton = find.byKey(const ValueKey('ajustes-nuevo-compartido'));
      await tester.ensureVisible(boton);
      await tester.tap(boton);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('compartido-nombre')), 'Cerrado');
      await tester.tap(find.byKey(ValueKey('compartido-miembro-${IdsDemostracion.pareja}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('compartido-crear')));
      await tester.pumpAndSettle();
      expect(
        repo.datos.libros.firstWhere((l) => l.nombre == 'Cerrado').visibilidad,
        dom.VisibilidadLibro.privada,
      );
    });

    testWidgets('el administrador ve "Administrar" y la visibilidad en la fila; '
        'quien no lo es, solo "Salir del libro"', (tester) async {
      await montarAjustes(tester, dueno);
      final fila = find.byKey(const ValueKey('ajustes-libro-$casa'));
      await tester.ensureVisible(fila);
      expect(find.descendant(of: fila, matching: find.textContaining('Privada')), findsOneWidget);
      expect(find.descendant(of: fila, matching: find.textContaining('administrador')), findsOneWidget);
      expect(find.byKey(const ValueKey('libro-miembros-$casa')), findsOneWidget);
      expect(find.byKey(const ValueKey('libro-salir-$casa')), findsOneWidget);
    });

    testWidgets('la pareja no administra el compartido que creó el dueño',
        (tester) async {
      await montarAjustes(tester, pareja);
      final fila = find.byKey(const ValueKey('ajustes-libro-$casa'));
      await tester.ensureVisible(fila);
      expect(find.byKey(const ValueKey('libro-miembros-$casa')), findsNothing);
      expect(find.byKey(const ValueKey('libro-salir-$casa')), findsOneWidget);
    });

    testWidgets('salirse avisa que el presupuesto queda privado si quedan menos '
        'de 2, informa el saldo y lo deja privado y activo', (tester) async {
      final repo = await montarAjustes(tester, pareja);
      final casaAntes = repo.datos.libro(casa)!;
      final saldo = repo.datos.vista(casa).balance().patrimonio;
      expect(saldo, isNot(0), reason: 'el ejemplo tiene dinero en la casa');
      final salir = find.byKey(const ValueKey('libro-salir-$casa'));
      await tester.ensureVisible(salir);
      await tester.tap(salir);
      await tester.pumpAndSettle();
      expect(find.textContaining('el presupuesto queda privado'), findsOneWidget);
      expect(find.textContaining('archivado'), findsNothing, reason: 'ya no se archiva');
      expect(find.textContaining('El presupuesto tiene'), findsOneWidget);
      expect(find.textContaining('lo que aportaste se queda aquí'), findsOneWidget);
      await tester.tap(find.text('Salir del libro').last);
      await tester.pumpAndSettle();
      final libro = repo.datos.libro(casa)!;
      expect(casaAntes.visibilidad, dom.VisibilidadLibro.privada);
      expect(libro.archivado, isFalse);
      expect(libro.visibilidad, dom.VisibilidadLibro.privada);
      expect(libro.papelDe(IdsDemostracion.pareja, hoyDePrueba), isNull);
      expect(libro.esAdministrador(IdsDemostracion.dueno), isTrue);
    });

    testWidgets('el último miembro no ve "Salir del libro" y se le explica',
        (tester) async {
      final repo = await montarAjustes(tester, dueno);
      await servicioDe(repo, dueno).quitarMiembroLibro(casa, IdsDemostracion.pareja);
      await tester.pumpAndSettle();
      final fila = find.byKey(const ValueKey('ajustes-libro-$casa'));
      await tester.ensureVisible(fila);
      expect(find.byKey(const ValueKey('libro-salir-$casa')), findsNothing);
      expect(find.textContaining('Eres el último miembro'), findsOneWidget);
      expect(find.byKey(const ValueKey('libro-miembros-$casa')), findsOneWidget,
          reason: 'el administrador sigue pudiendo archivarlo');
    });

    testWidgets('quien administra elige a quién agregar entre los adultos con '
        'Finanzas del hogar, aunque no sea el dueño', (tester) async {
      final repo = await montarAjustes(tester, pareja);
      // La pareja crea su propio compartido con otra persona de ejemplo.
      await servicioDe(repo, pareja).crearLibroCompartido('Viaje', ['otra-persona']);
      final id = repo.datos.libros.firstWhere((l) => l.nombre == 'Viaje').id;
      await tester.pumpAndSettle();
      final admin = find.byKey(ValueKey('libro-miembros-$id'));
      await tester.ensureVisible(admin);
      await tester.tap(admin);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('miembro-agregar')));
      await tester.pumpAndSettle();
      // El dueño aparece aunque la pareja no pueda leer sus membresías.
      expect(find.text(repo.actual.nombreDe(IdsDemostracion.dueno)).last, findsOneWidget);
    });

    testWidgets('el administrador cambia la visibilidad, saca y agrega '
        'miembros y archiva el libro', (tester) async {
      final repo = await montarAjustes(tester, dueno);
      // Un tercer miembro para poder sacar a alguien sin dejar menos de 2.
      await repo.agregarMiembro(casa, 'persona-extra');
      await tester.pumpAndSettle();
      final admin = find.byKey(const ValueKey('libro-miembros-$casa'));
      await tester.ensureVisible(admin);
      await tester.tap(admin);
      await tester.pumpAndSettle();
      expect(find.text('Administrador'), findsOneWidget);

      await tester.tap(find.text('Pública'));
      await tester.pumpAndSettle();
      expect(repo.datos.libro(casa)!.visibilidad, dom.VisibilidadLibro.publica);

      await tester.tap(find.byKey(const ValueKey('miembro-quitar-persona-extra')));
      await tester.pumpAndSettle();
      expect(repo.datos.libro(casa)!.papelDe('persona-extra', hoyDePrueba), isNull);
      // Con 2 miembros también se puede sacar a uno: avisa que el presupuesto
      // queda privado para quien se queda.
      await tester.tap(find.byKey(ValueKey('miembro-quitar-${IdsDemostracion.pareja}')));
      await tester.pumpAndSettle();
      expect(find.textContaining('pasa a privado'), findsOneWidget);
      await tester.tap(find.text('Sacar').last);
      await tester.pumpAndSettle();
      final solo = repo.datos.libro(casa)!;
      expect(solo.vigentes(hoyDePrueba), hasLength(1));
      expect(solo.visibilidad, dom.VisibilidadLibro.privada);
      expect(solo.archivado, isFalse);
      expect(solo.esAdministrador(IdsDemostracion.dueno), isTrue);

      await tester.ensureVisible(find.byKey(const ValueKey('libro-archivar')));
      await tester.tap(find.byKey(const ValueKey('libro-archivar')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archivar').last);
      await tester.pumpAndSettle();
      expect(repo.datos.libro(casa)!.archivado, isTrue);
      expect(find.byKey(const ValueKey('libro-archivado-aviso')), findsOneWidget);
      // Y lo reactiva.
      await tester.ensureVisible(find.byKey(const ValueKey('libro-reactivar')));
      await tester.tap(find.byKey(const ValueKey('libro-reactivar')));
      await tester.pumpAndSettle();
      expect(repo.datos.libro(casa)!.archivado, isFalse);
    });
  });

  group('Deuda: la regla de día inhábil se elige por deuda', () {
    testWidgets('por omisión paga en su fecha; se puede pasar al siguiente '
        'día hábil', (tester) async {
      final repo = repositorioDe(dueno);
      addTearDown(repo.cerrar);
      await servicioDe(repo, dueno).crearCuenta(
        libroId: libroDueno,
        nombre: 'Tarjeta de ejemplo',
        tipo: TipoCuenta.tarjeta,
      );
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: ServicioSesionDemostracion(inicial: dueno),
        extras: [repositorioFinanzasProvider.overrideWithValue(repo)],
      );
      tester.view.physicalSize = const Size(1440, 4000);
      _contenedor(tester).read(dis.montosVisiblesProvider.notifier).fijar(true);
      _contenedor(tester).read(routerProvider).go(SeccionFinanzas.compromisos.ruta);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('compromisos-nueva-deuda')));
      await tester.pumpAndSettle();
      final regla = find.byKey(const ValueKey('calendario-regla'));
      expect(regla, findsOneWidget);
      expect(
        tester.widget<DropdownButtonFormField<ReglaDiaInhabil>>(regla).initialValue,
        ReglaDiaInhabil.sinCambio,
        reason: 'los pagos que salen se quedan en su fecha',
      );
      expect(find.textContaining('En su fecha'), findsWidgets);
      await tester.tap(regla);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Siguiente día hábil').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('deuda-nombre')), 'Crédito de ejemplo');
      await tester.enterText(find.byKey(const ValueKey('deuda-abono')), '1500');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tasa anual (del estado de cuenta)'),
        '24',
      );
      final pasivos = repo.datos
          .cuentasDe(libroDueno)
          .where((c) => c.clase == ClaseCuenta.pasivo)
          .toList();
      expect(pasivos, isNotEmpty);
      await tester.tap(find.text('Cuenta (tarjeta o préstamo)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(pasivos.first.nombre).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dialogo-guardar')));
      await tester.pumpAndSettle();
      final deuda = repo.datos.deudas.firstWhere((d) => d.nombre == 'Crédito de ejemplo');
      expect(deuda.calendario!.regla, ReglaDiaInhabil.siguienteDiaHabil);
      expect(deuda.reglaInhabil, ReglaDiaInhabil.siguienteDiaHabil);
    });

    test('una deuda "en su fecha" no se mueve y la del siguiente día hábil sí',
        () {
      // El lunes 2 de noviembre es un día inhábil propio de este ejemplo.
      final inhabiles = CalendarioFijo([Fecha(2026, 11, 2)]);
      Deuda deuda(ReglaDiaInhabil r) => Deuda(
        id: 'd',
        libroId: 'l',
        nombre: 'Crédito de ejemplo',
        tipo: TipoDeuda.conCosto,
        abono: 150000,
        frecuencia: Frecuencia.mensual,
        calendario: CalendarioConfig.mensual(const [2], regla: r),
        tasaAnualPuntosBase: 1500,
      );
      final desde = Fecha(2026, 11, 1);
      final hasta = Fecha(2026, 11, 30);
      final enSuFecha = deuda(ReglaDiaInhabil.sinCambio).pagosEntre(desde, hasta, inhabiles);
      final siguiente = deuda(ReglaDiaInhabil.siguienteDiaHabil).pagosEntre(desde, hasta, inhabiles);
      expect(enSuFecha.single.ajustada, Fecha(2026, 11, 2));
      expect(siguiente.single.programada, Fecha(2026, 11, 2));
      expect(siguiente.single.ajustada, Fecha(2026, 11, 3));
    });
  });
}
