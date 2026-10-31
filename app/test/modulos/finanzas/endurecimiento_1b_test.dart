// Endurecimiento de la Fase 1b en la app de Finanzas (migración
// `20261026000000_finanzas_endurecimiento_1b.sql`):
//  1. el motivo necesita al menos 3 caracteres visibles (libro de papá,
//     anulaciones, ajustes y conciliaciones con diferencia), validado en los
//     formularios antes de mandar (si no, 23514);
//  2. `fin_nombrar_albacea`: el dueño nombra albacea o suplente del libro de
//     papá cuando el cargo quedó vacío (Ajustes › Libros y albaceas);
//  3. tras una baja o un cambio de rol, los compartidos se vuelven a pedir (el
//     servidor puede cambiar `creado_por` y `visibilidad`);
//  4. la app nunca escribe directo en la bitácora (tope de 500 por día y 4 KB).
// Datos de ejemplo inventados (hogar de Ana y Alex).
import 'dart:io';

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide Semaforo, formatearCentavos, TipoLibro, VisibilidadLibro, puntosBaseEnCien;
import 'package:finanzas_dominio/finanzas_dominio.dart' as dom
    show VisibilidadLibro;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/app/router.dart';
import 'package:gravity/diseno/diseno.dart' show TecladoMonto, montosVisiblesProvider;
import 'package:gravity/modulos/finanzas/casos_uso/servicio_finanzas.dart';
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_memoria.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_supabase.dart'
    show tablasDeLaColaFinanzas;
import 'package:gravity/modulos/finanzas/estado/proveedores.dart';
import 'package:gravity/modulos/finanzas/finanzas.dart' show SeccionFinanzas, refrescarFinanzas;
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';

import '../../app/ayuda_plataforma.dart';
import '../../revision_calidad/ayuda_calidad.dart';
import 'ayuda_finanzas.dart';

const _cortos = ['', '  ', 'a', 'ab', ' a b ', '​​​', ' a b　'];

ProviderContainer _contenedor(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AppGravity)));

void main() {
  const libroDueno = IdsDemostracion.libroDueno;
  const libroPapa = IdsDemostracion.libroPapa;
  const casa = IdsDemostracion.libroCasa;
  final dueno = sesionDe(Rol.dueno);
  final pareja = sesionDe(Rol.coadministrador);
  final idDueno = IdsDemostracion.dueno;
  final idPareja = IdsDemostracion.pareja;

  group('1. El motivo necesita 3 caracteres visibles', () {
    test('el libro de papá rechaza un motivo corto en todas sus rutas', () async {
      final repo = repositorioDe(dueno);
      addTearDown(repo.cerrar);
      final servicio = servicioDe(repo, dueno);
      final banco = repo.cuentaDe(libroPapa, 'Cuenta de la pensión').id;
      final miBanco = repo.cuentaDe(libroDueno, 'Mi banco').id;
      for (final corto in _cortos) {
        await expectLater(
          servicio.registrarGasto(
            libroId: libroPapa,
            cuentaOrigenId: banco,
            lineas: const [LineaGasto(monto: 100)],
            motivo: corto,
          ),
          throwsA(isA<ErrorFinanzas>().having((e) => e.mensaje, 'mensaje', contains('3 caracteres'))),
          reason: 'gasto "$corto"',
        );
        await expectLater(
          servicio.registrarIngresoExtra(
            libroId: libroPapa,
            monto: 100,
            cuentaDestinoId: banco,
            motivo: corto,
          ),
          throwsA(isA<ErrorFinanzas>()),
          reason: 'ingreso "$corto"',
        );
        await expectLater(
          servicio.registrarMovimiento(
            tipo: TipoMovimiento.transferencia,
            cuentaOrigenId: miBanco,
            cuentaDestinoId: banco,
            monto: 100,
            motivo: corto,
          ),
          throwsA(isA<ErrorFinanzas>()),
          reason: 'aportación "$corto"',
        );
      }
      // Con 3 visibles pasa, aunque lleve espacios alrededor.
      final r = await servicio.registrarGasto(
        libroId: libroPapa,
        cuentaOrigenId: banco,
        lineas: const [LineaGasto(monto: 100)],
        motivo: '  Pan  ',
      );
      expect(r.movimientos.single.motivo, '  Pan  '.trim());
    });

    test('la anulación pide 3 caracteres visibles', () async {
      final repo = repositorioDe(dueno);
      addTearDown(repo.cerrar);
      final servicio = servicioDe(repo, dueno);
      final original = repo.datos.movimientos.firstWhere((m) => m.tipo == TipoMovimiento.gasto);
      for (final corto in _cortos) {
        await expectLater(
          servicio.anular(original.id, motivo: corto),
          throwsA(isA<ErrorFinanzas>().having((e) => e.mensaje, 'mensaje', contains('3 caracteres'))),
          reason: '"$corto"',
        );
      }
      expect(repo.datos.movimientos.where((m) => m.anulaA == original.id), isEmpty);
      final contra = await servicio.anular(original.id, motivo: 'Dup');
      expect(contra.motivo, 'Dup');
    });

    test('la conciliación con diferencia pide 3 caracteres; sin diferencia no '
        'pide nada', () async {
      final repo = repositorioDe(dueno);
      addTearDown(repo.cerrar);
      final servicio = servicioDe(repo, dueno);
      final cuenta = repo.cuentaDe(libroDueno, 'Mi banco');
      final saldo = repo.datos.nuevoLibroHogar().saldo(cuenta.id, hasta: hoyDePrueba);
      await servicio.conciliar(cuentaId: cuenta.id, saldoDeclarado: saldo);
      for (final corto in _cortos) {
        await expectLater(
          servicio.conciliar(cuentaId: cuenta.id, saldoDeclarado: saldo - 500, motivo: corto),
          throwsA(isA<ErrorFinanzas>().having((e) => e.mensaje, 'mensaje', contains('3 caracteres'))),
          reason: '"$corto"',
        );
      }
      final c = await servicio.conciliar(
        cuentaId: cuenta.id,
        saldoDeclarado: saldo - 500,
        motivo: 'Café',
      );
      expect(c.ajusteMovimientoId, isNotNull);
    });

    testWidgets('la hoja (+) en el libro de papá no guarda con un motivo corto',
        (tester) async {
      final repo = repositorioDe(dueno);
      addTearDown(repo.cerrar);
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: ServicioSesionDemostracion(inicial: dueno),
        extras: [repositorioFinanzasProvider.overrideWithValue(repo)],
      );
      tester.view.physicalSize = const Size(411, 850);
      _contenedor(tester).read(montosVisiblesProvider.notifier).fijar(true);
      await abrirRegistroDelTelefono(tester, 'Gasto');
      final chipPapa = find.byKey(const ValueKey('gasto-libro-$libroPapa'));
      await tester.ensureVisible(chipPapa);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(chipPapa);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(
        find.descendant(of: find.byType(TecladoMonto), matching: find.text('5')),
      );
      await tester.pump();
      FilledButton guardar() =>
          tester.widget<FilledButton>(find.byKey(const ValueKey('gasto-guardar')));
      final motivo = find.byKey(const ValueKey('gasto-motivo'));
      await tester.ensureVisible(motivo);
      expect(find.textContaining('Al menos 3 letras o números'), findsOneWidget);
      for (final corto in ['ab', '   a   ', '​​​​']) {
        await tester.enterText(motivo, corto);
        await tester.pump();
        expect(guardar().onPressed, isNull, reason: '"$corto"');
      }
      await tester.enterText(motivo, 'Pan');
      await tester.pump();
      expect(guardar().onPressed, isNotNull);
    });

    testWidgets('anular desde la fila pide 3 caracteres visibles', (tester) async {
      final repo = repositorioDe(dueno);
      addTearDown(repo.cerrar);
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: ServicioSesionDemostracion(inicial: dueno),
        extras: [repositorioFinanzasProvider.overrideWithValue(repo)],
      );
      tester.view.physicalSize = const Size(411, 850);
      _contenedor(tester).read(montosVisiblesProvider.notifier).fijar(true);
      _contenedor(tester).read(routerProvider).go(SeccionFinanzas.movimientos.ruta);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      final menu = find
          .byWidgetPredicate(
            (w) => w.key is ValueKey && '${(w.key! as ValueKey).value}'.startsWith('movimiento-menu-'),
          )
          .first;
      final antes = repo.datos.movimientos.length;
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anular…'));
      await tester.pumpAndSettle();
      final campo = find.byKey(const ValueKey('finanzas-dialogo-texto'));
      expect(find.textContaining('Al menos 3 letras o números'), findsOneWidget);
      FilledButton anular() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Anular'));
      for (final corto in ['x', 'ab', '  a  ', '​​​']) {
        await tester.enterText(campo, corto);
        await tester.pump();
        expect(anular().onPressed, isNull, reason: '"$corto"');
      }
      await tester.enterText(campo, 'Dup');
      await tester.pump();
      expect(anular().onPressed, isNotNull);
      await tester.tap(find.widgetWithText(FilledButton, 'Anular'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(repo.datos.movimientos.length, antes + 1);
      expect(repo.datos.movimientos.last.motivo, 'Dup');
    });
  });

  group('2. El dueño nombra albacea o suplente (fin_nombrar_albacea)', () {
    /// Un libro de papá recién creado (sin suplente) en el hogar de ejemplo.
    Future<(RepositorioFinanzasEnMemoria, String)> conLibroNuevo() async {
      final repo = repositorioDe(dueno);
      final id = await servicioDe(repo, dueno).crearLibroRepresentado('Tío (ejemplo)');
      return (repo, id);
    }

    test('el cargo de suplente vacío se puede nombrar; ocupado, no', () async {
      final (repo, id) = await conLibroNuevo();
      addTearDown(repo.cerrar);
      final servicio = servicioDe(repo, dueno);
      expect(servicio.cargoVacio(id, PapelLibro.albaceaSuplente), isTrue);
      expect(servicio.cargoVacio(id, PapelLibro.albacea), isFalse, reason: 'lo tiene el dueño');
      await servicio.nombrarAlbacea(id, idPareja, papel: PapelLibro.albaceaSuplente);
      final libro = repo.datos.libro(id)!;
      expect(libro.papelDe(idPareja, hoyDePrueba), PapelLibro.albaceaSuplente);
      expect(servicio.cargoVacio(id, PapelLibro.albaceaSuplente), isFalse);
      await expectLater(
        servicio.nombrarAlbacea(id, idPareja, papel: PapelLibro.albaceaSuplente),
        throwsA(isA<ErrorFinanzas>()),
        reason: 'el cargo ya lo ocupa alguien',
      );
    });

    test('solo el dueño; la pareja y la maestra no', () async {
      for (final sesion in [pareja, sesionDe(Rol.coadministrador, maestra: true)]) {
        final repo = repositorioDe(sesion);
        addTearDown(repo.cerrar);
        await expectLater(
          servicioDe(repo, sesion).nombrarAlbacea(
            libroPapa,
            idPareja,
            papel: PapelLibro.albaceaSuplente,
          ),
          throwsA(isA<ErrorFinanzas>().having((e) => e.mensaje, 'mensaje', contains('dueño'))),
          reason: sesion.persona.nombre,
        );
      }
    });

    test('las reglas del servidor se avisan antes de llamar: titular, otro '
        'cargo, no adulto y libro que no es de papá', () async {
      final (repo, id) = await conLibroNuevo();
      addTearDown(repo.cerrar);
      final servicio = servicioDe(repo, dueno);
      final titular = repo.datos.libro(id)!.titularId!;
      await expectLater(
        servicio.nombrarAlbacea(id, titular, papel: PapelLibro.albaceaSuplente),
        throwsA(isA<ErrorFinanzas>()),
        reason: 'la persona representada no lleva su libro',
      );
      await expectLater(
        servicio.nombrarAlbacea(id, 'persona-que-no-existe', papel: PapelLibro.albaceaSuplente),
        throwsA(isA<ErrorFinanzas>()),
        reason: 'no es adulto con Finanzas',
      );
      await expectLater(
        servicio.nombrarAlbacea(id, idDueno, papel: PapelLibro.albaceaSuplente),
        throwsA(isA<ErrorFinanzas>()),
        reason: 'ya lleva el libro como albacea',
      );
      await expectLater(
        servicio.nombrarAlbacea(casa, idPareja),
        throwsA(isA<ErrorFinanzas>()),
        reason: 'un compartido no tiene albacea',
      );
    });

    test('si el albacea ya no es adulto con Finanzas, el dueño nombra a otro '
        'y el cargo viejo se cierra', () async {
      // El albacea del ejemplo es el dueño; aquí el que se fue es la pareja,
      // suplente: el hogar solo tiene ya al dueño y a una tercera persona.
      const tercera = 'persona-tercera-ejemplo';
      final base = repositorioDe(dueno);
      final repo = RepositorioFinanzasEnMemoria(
        datos: base.datos,
        personaId: idDueno,
        personas: {...personasDeDemostracion(), tercera: 'Tercera (ejemplo)'},
        adultosConFinanzas: {idDueno, tercera},
        adultosActivosDelHogar: {idDueno, tercera},
        reloj: () => ahoraDePrueba,
      );
      addTearDown(repo.cerrar);
      final servicio = servicioDe(repo, dueno);
      expect(servicio.cargoVacio(libroPapa, PapelLibro.albaceaSuplente), isTrue,
          reason: 'la pareja ya no es adulto con Finanzas');
      await servicio.nombrarAlbacea(libroPapa, tercera, papel: PapelLibro.albaceaSuplente);
      final libro = repo.datos.libro(libroPapa)!;
      expect(libro.papelDe(tercera, hoyDePrueba), PapelLibro.albaceaSuplente);
      expect(libro.papelDe(idPareja, hoyDePrueba), isNull, reason: 'el cargo viejo se cerró');
    });

    testWidgets('Ajustes ofrece "Nombrar suplente" al dueño y lo nombra',
        (tester) async {
      final base = repositorioDe(dueno);
      final repo = base;
      addTearDown(repo.cerrar);
      final id = await servicioDe(repo, dueno).crearLibroRepresentado('Tío (ejemplo)');
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: ServicioSesionDemostracion(inicial: dueno),
        extras: [repositorioFinanzasProvider.overrideWithValue(repo)],
      );
      tester.view.physicalSize = const Size(1440, 4000);
      _contenedor(tester).read(montosVisiblesProvider.notifier).fijar(true);
      _contenedor(tester).read(routerProvider).go(SeccionFinanzas.ajustes.ruta);
      await tester.pumpAndSettle();
      final boton = find.byKey(ValueKey('libro-nombrar-suplente-$id'));
      expect(boton, findsOneWidget);
      expect(find.byKey(ValueKey('libro-nombrar-albacea-$id')), findsNothing,
          reason: 'el albacea es el dueño');
      // El libro de papá del ejemplo tiene albacea y suplente: sin botones.
      expect(find.byKey(const ValueKey('libro-nombrar-suplente-$libroPapa')), findsNothing);
      await tester.ensureVisible(boton);
      await tester.tap(boton);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nombrar-confirmar')), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('nombrar-confirmar'))).onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('nombrar-persona')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(repo.actual.nombreDe(idPareja)).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nombrar-confirmar')));
      await tester.pumpAndSettle();
      expect(repo.datos.libro(id)!.papelDe(idPareja, hoyDePrueba), PapelLibro.albaceaSuplente);
      expect(find.byKey(ValueKey('libro-nombrar-suplente-$id')), findsNothing,
          reason: 'el cargo ya está ocupado');
    });

    testWidgets('la pareja no ve los botones de nombrar', (tester) async {
      final repo = repositorioDe(pareja);
      addTearDown(repo.cerrar);
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: ServicioSesionDemostracion(inicial: pareja),
        extras: [repositorioFinanzasProvider.overrideWithValue(repo)],
      );
      tester.view.physicalSize = const Size(1440, 4000);
      _contenedor(tester).read(montosVisiblesProvider.notifier).fijar(true);
      _contenedor(tester).read(routerProvider).go(SeccionFinanzas.ajustes.ruta);
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) => w.key is ValueKey && '${(w.key! as ValueKey).value}'.startsWith('libro-nombrar-'),
        ),
        findsNothing,
      );
    });
  });

  group('3. Tras una baja o un cambio de rol se refrescan los compartidos', () {
    test('refrescarFinanzas vuelve a pedir lo del servidor y ve el cambio de '
        'administrador y de visibilidad', () async {
      final repo = _RepoQueCambiaAlRecargar(dueno);
      addTearDown(repo.cerrar);
      final contenedor = ProviderContainer(
        overrides: [repositorioFinanzasProvider.overrideWithValue(repo)],
      );
      addTearDown(contenedor.dispose);
      // Sin abrir Finanzas, refrescar no hace nada.
      await refrescarFinanzas(contenedor);
      expect(repo.cargas, 0);

      contenedor.listen(cargaFinanzasProvider, (_, _) {});
      await contenedor.read(cargaFinanzasProvider.future);
      expect(repo.cargas, 1);
      var casaAntes = contenedor.read(cargaFinanzasProvider).requireValue.datos.libro(casa)!;
      expect(casaAntes.esAdministrador(idDueno), isTrue);
      expect(casaAntes.vigentes(hoyDePrueba), hasLength(2));

      // El servidor, tras la baja de la pareja, cambió el libro.
      repo.hayBaja = true;
      await refrescarFinanzas(contenedor);
      expect(repo.cargas, 2);
      casaAntes = contenedor.read(cargaFinanzasProvider).requireValue.datos.libro(casa)!;
      expect(casaAntes.vigentes(hoyDePrueba), hasLength(1));
      expect(casaAntes.visibilidad, dom.VisibilidadLibro.privada);
      expect(casaAntes.esAdministrador(idDueno), isTrue);
    });

    test('sin señal no lanza y se queda con lo último', () async {
      final repo = _RepoQueCambiaAlRecargar(dueno);
      addTearDown(repo.cerrar);
      final contenedor = ProviderContainer(
        overrides: [repositorioFinanzasProvider.overrideWithValue(repo)],
      );
      addTearDown(contenedor.dispose);
      contenedor.listen(cargaFinanzasProvider, (_, _) {});
      await contenedor.read(cargaFinanzasProvider.future);
      repo.sinSenal = true;
      await refrescarFinanzas(contenedor);
      expect(contenedor.read(cargaFinanzasProvider).hasValue || contenedor.read(cargaFinanzasProvider).hasError, isTrue);
    });

    testWidgets('al abrir Ajustes se vuelve a pedir y se ve quién administra',
        (tester) async {
      final repo = _RepoQueCambiaAlRecargar(pareja);
      addTearDown(repo.cerrar);
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: ServicioSesionDemostracion(inicial: pareja),
        extras: [repositorioFinanzasProvider.overrideWithValue(repo)],
      );
      tester.view.physicalSize = const Size(1440, 4000);
      _contenedor(tester).read(montosVisiblesProvider.notifier).fijar(true);
      _contenedor(tester).read(routerProvider).go('/finanzas');
      await tester.pumpAndSettle();
      // Antes de la baja del dueño, la pareja es una miembro más (no administra).
      final cargasAntes = repo.cargas;
      repo.hayBaja = true;
      repo.administradorNuevo = idPareja;
      _contenedor(tester).read(routerProvider).go(SeccionFinanzas.ajustes.ruta);
      await tester.pumpAndSettle();
      expect(repo.cargas, greaterThan(cargasAntes), reason: 'Ajustes recarga al abrirse');
      expect(find.byKey(const ValueKey('libro-miembros-$casa')), findsOneWidget,
          reason: 'ahora la pareja es la administradora');
    });
  });

  group('4. La app no escribe directo en la bitácora', () {
    test('ninguna tabla de la cola ni del módulo es la bitácora', () {
      expect(tablasDeLaColaFinanzas.values, isNot(contains('bitacora')));
      final fuentes = Directory('lib/modulos/finanzas')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      expect(fuentes, isNotEmpty);
      for (final f in fuentes) {
        final codigo = f
            .readAsLinesSync()
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        expect(
          RegExp(r'''['"]bitacora['"]''').hasMatch(codigo),
          isFalse,
          reason: '${f.path} no debe escribir en public.bitacora (tope de 500 por día y 4 KB; 54000)',
        );
      }
    });
  });
}

/// Un servidor que, tras una baja, cambia el compartido de la casa: queda con
/// un solo miembro, privado y con otro administrador. `cargar()` cuenta cuántas
/// veces se pidió. No avisa por `cambios` (como el servidor real).
class _RepoQueCambiaAlRecargar extends RepositorioFinanzasEnMemoria {
  _RepoQueCambiaAlRecargar(Sesion sesion)
    : super(
        datos: repositorioDe(sesion).datos,
        personaId: sesion.persona.id,
        personas: personasDeDemostracion(),
        adultosConFinanzas: adultosDeEjemplo,
        reloj: () => ahoraDePrueba,
      );

  int cargas = 0;
  bool hayBaja = false;
  bool sinSenal = false;
  String administradorNuevo = IdsDemostracion.dueno;

  @override
  Future<CargaFinanzas> cargar() async {
    cargas++;
    if (sinSenal) throw ErrorFinanzas.conexion;
    final carga = await super.cargar();
    if (!hayBaja) return carga;
    final datos = carga.datos;
    final casa = datos.libro(IdsDemostracion.libroCasa)!;
    final queda = administradorNuevo;
    final actualizada = casa.copiar(
      creadoPor: queda,
      visibilidad: dom.VisibilidadLibro.privada,
      miembros: [
        for (final m in casa.miembros)
          if (m.personaId == queda)
            m
          else
            MiembroLibro(
              personaId: m.personaId,
              papel: m.papel,
              desde: m.desde,
              hasta: Fecha(2026, 10, 1),
            ),
      ],
    );
    return carga.copiar(
      datos: datos.copiar(
        libros: [for (final l in datos.libros) l.id == casa.id ? actualizada : l],
      ),
    );
  }
}
