// Fase 4 (Pulido 1) de Finanzas: cifras reales en "Hoy" y "Mi semana" por
// libro y por rol (con montos ocultables), chip "+ Cuenta", motivo válido,
// avisos de la app (`fin_emitir_aviso`) sin dinero, cierre con ahorro
// automático deshacible, mensaje sin señal, sección de avisos y el gancho de
// la baja. Datos de ejemplo inventados.
import 'dart:async';

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide
        Semaforo,
        formatearCentavos,
        TipoLibro,
        VisibilidadLibro,
        puntosBaseEnCien;
import 'package:finanzas_dominio/finanzas_dominio.dart' as dom
    show Semaforo, TipoLibro;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/diseno/proveedores.dart' show RelojFijo;
import 'package:gravity/diseno/diseno.dart'
    as dis
    show MarcaMontosOcultos, formatearCentavos, montosVisiblesProvider;
import 'package:gravity/modulos/finanzas/casos_uso/emisor_avisos.dart';
import 'package:gravity/modulos/finanzas/casos_uso/servicio_fase2.dart';
import 'package:gravity/modulos/finanzas/casos_uso/servicio_finanzas.dart';
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_memoria.dart';
import 'package:gravity/modulos/finanzas/estado/proveedores.dart';
import 'package:gravity/modulos/finanzas/estado/resumen_hoy.dart';
import 'package:gravity/modulos/finanzas/finanzas.dart'
    show
        SeccionAvisosFinanzas,
        SeccionFinanzas,
        TarjetaFinanzasHoy,
        refrescarFinanzas;
import 'package:gravity/modulos/finanzas/pantallas/comunes.dart'
    show errorDeMotivo, escalonesDe, pedirTexto;
import 'package:gravity/nucleo/avisos/aviso.dart';
import 'package:gravity/nucleo/avisos/catalogo_avisos.dart';
import 'package:gravity/nucleo/avisos/proveedores_avisos.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';

import '../../app/ayuda_plataforma.dart';
import '../../revision_calidad/ayuda_calidad.dart';
import 'ayuda_finanzas.dart';

const _libroDueno = IdsDemostracion.libroDueno;
const _telefono = Size(360, 800);

ProviderContainer _contenedor(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AppGravity)));

/// Espera a que Finanzas esté cargado (en la app lo hace la propia tarjeta).
Future<ProviderContainer> _cargado(WidgetTester tester) async {
  final c = _contenedor(tester);
  await c.read(cargaFinanzasProvider.future);
  await avanzar(tester);
  return c;
}

/// Muestra la tarjeta de Hoy de Finanzas dentro de la app (la plataforma la
/// monta en "Hoy"; aquí se prueba sola).
Future<void> _mostrarTarjetaHoy(WidgetTester tester) async {
  final contexto = tester.element(find.byType(Scaffold).first);
  unawaited(
    showDialog<void>(
      context: contexto,
      builder: (_) => const Dialog(
        child: SingleChildScrollView(child: TarjetaFinanzasHoy()),
      ),
    ),
  );
  await avanzar(tester);
}

/// El hogar de ejemplo sin plan ni movimientos (libros y cuentas sí).
RepositorioFinanzasEnMemoria _sinPlan(Sesion sesion) {
  final base = repositorioDe(sesion);
  final d = base.datos;
  return RepositorioFinanzasEnMemoria(
    datos: d.copiar(
      ingresos: const [],
      compromisos: const [],
      sobres: const [],
      deudas: const [],
      semanas: const [],
      movimientos: const [],
    ),
    personaId: sesion.persona.id,
    personas: personasDeDemostracion(),
    adultosConFinanzas: adultosDeEjemplo,
    reloj: () => ahoraDePrueba,
  );
}

/// Monta la app con un repositorio propio (para controlar los datos).
Future<void> _montarConRepo(
  WidgetTester tester,
  RepositorioFinanzasEnMemoria repo, {
  Rol rol = Rol.dueno,
  Size tamano = _telefono,
}) async {
  addTearDown(repo.cerrar);
  await montarApp(
    tester,
    dispositivo: TipoDispositivo.telefono,
    sesion: ServicioSesionDemostracion(inicial: sesionDe(rol)),
    reloj: RelojFijo(DateTime(2026, 10, 20, 10)),
    extras: [repositorioFinanzasProvider.overrideWithValue(repo)],
  );
  tester.view.physicalSize = tamano;
  await tester.pump();
  await avanzar(tester);
}

String _todoElTexto(WidgetTester tester, Finder dentro) => tester
    .widgetList<Text>(find.descendant(of: dentro, matching: find.byType(Text)))
    .map((t) => t.data ?? '')
    .join(' · ');

void main() {
  final semana = Semana.de(hoyDePrueba);

  group('1. Cifras reales en "Hoy" y "Mi semana"', () {
    testWidgets('el dueño ve un renglón por cada libro que lleva, con las '
        'cifras del dominio al centavo', (tester) async {
      await montarFinanzasConTamano(
        tester,
        dispositivo: TipoDispositivo.telefono,
        tamano: _telefono,
      );
      final c = await _cargado(tester);
      final resumen = c.read(resumenFinanzasHoyProvider);
      final ctx = c.read(contextoFinanzasProvider).value!;
      expect(resumen.estado, EstadoResumenHoy.conLibros);
      final esperados = [
        for (final l in ctx.libros)
          if (ctx.permisoEn(l).leer &&
              !ctx.permisoEn(l).comoMaestra &&
              !ctx.permisoEn(l).comoLector &&
              !l.archivado)
            l.id,
      ];
      expect(resumen.libros.map((l) => l.libroId), esperados);
      for (final l in resumen.libros) {
        final v = vistaSemana(ctx.datos, l.libroId, semana, hoy: ctx.hoy);
        expect(l.cifras, CifrasSemana.de(v));
        expect(l.cifras.presupuesto, v.planSemanal.presupuesto);
        expect(l.cifras.gastado, v.real.gastoReal);
        expect(l.cifras.disponible, v.planSemanal.presupuesto - v.real.gastoReal);
      }
    });

    testWidgets('Hoy, Mi semana y la pantalla Semana dan las mismas cifras '
        'al centavo', (tester) async {
      await montarFinanzasConTamano(
        tester,
        dispositivo: TipoDispositivo.telefono,
        tamano: _telefono,
      );
      final c = await _cargado(tester);
      final ctx = c.read(contextoFinanzasProvider).value!;
      final miSemana = c.read(cifrasMiSemanaProvider)!;
      final hoy = c
          .read(resumenFinanzasHoyProvider)
          .libros
          .firstWhere((l) => l.libroId == ctx.libroId)
          .cifras;
      final v = vistaSemana(ctx.datos, ctx.libroId, semana, hoy: ctx.hoy);
      final escalones = escalonesDe(v);
      expect(miSemana, hoy);
      expect(miSemana.ingresoPlaneado, escalones[0].planeadoCentavos);
      expect(miSemana.ingresoReal, escalones[0].realCentavos);
      expect(miSemana.presupuesto, escalones[1].planeadoCentavos);
      expect(miSemana.gastado, escalones[1].realCentavos);
      expect(miSemana.deuda, escalones[2].planeadoCentavos);
      expect(miSemana.remanentePlaneado, escalones[3].planeadoCentavos);
      expect(miSemana.remanenteReal, escalones[3].realCentavos);
    });

    for (final (rol, vistos) in [
      (Rol.coadministrador, true),
      (Rol.familiar, false),
      (Rol.cuidador, false),
      (Rol.casa, false),
    ]) {
      testWidgets('${rol.name}: ${vistos ? 've sus libros' : 'no ve la tarjeta'}',
          (tester) async {
        await montarFinanzasConTamano(
          tester,
          dispositivo: TipoDispositivo.telefono,
          tamano: _telefono,
          rol: rol,
        );
        final resumen = (await _cargado(tester)).read(resumenFinanzasHoyProvider);
        expect(resumen.visible, vistos);
        if (!vistos) {
          expect(resumen.libros, isEmpty);
          await _mostrarTarjetaHoy(tester);
          expect(find.byKey(const ValueKey('finanzas-hoy')), findsNothing);
          expect(find.textContaining('Quedan'), findsNothing);
        }
      });
    }

    testWidgets('la pareja jamás ve el libro personal del dueño ni el de '
        'papá', (tester) async {
      await montarFinanzasConTamano(
        tester,
        dispositivo: TipoDispositivo.telefono,
        tamano: _telefono,
        rol: Rol.coadministrador,
      );
      final ids = (await _cargado(tester))
          .read(resumenFinanzasHoyProvider)
          .libros
          .map((l) => l.libroId);
      expect(ids, isNot(contains(_libroDueno)));
      expect(ids, isNot(contains(IdsDemostracion.libroPapa)));
    });

    testWidgets('con los montos ocultos la tarjeta dice "Montos ocultos" y no '
        'hay una cifra en el texto ni en la semántica', (tester) async {
      await montarFinanzasConTamano(
        tester,
        dispositivo: TipoDispositivo.telefono,
        tamano: _telefono,
      );
      await _cargado(tester);
      await _mostrarTarjetaHoy(tester);
      final tarjeta = find.byKey(const ValueKey('finanzas-hoy'));
      expect(tarjeta, findsOneWidget);
      expect(
        find.descendant(of: tarjeta, matching: find.byType(dis.MarcaMontosOcultos)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tarjeta, matching: find.textContaining('Montos ocultos')),
        findsOneWidget,
      );
      final dinero = RegExp(r'\$\s*\d|\d{1,3}(,\d{3})+(\.\d\d)?');
      expect(dinero.hasMatch(_todoElTexto(tester, tarjeta)), isFalse);
      final SemanticsNode semantica = tester.getSemantics(tarjeta);
      final etiquetas = '${semantica.label} ${semantica.value}';
      expect(dinero.hasMatch(etiquetas), isFalse);
      // Y el monto se dibuja como "Monto oculto".
      expect(find.bySemanticsLabel('Monto oculto'), findsWidgets);
    });

    testWidgets('con los montos a la vista muestra lo que queda de cada libro',
        (tester) async {
      await montarFinanzasConTamano(
        tester,
        dispositivo: TipoDispositivo.telefono,
        tamano: _telefono,
      );
      final c = await _cargado(tester);
      c.read(dis.montosVisiblesProvider.notifier).fijar(true);
      await _mostrarTarjetaHoy(tester);
      final resumen = c.read(resumenFinanzasHoyProvider);
      for (final l in resumen.libros) {
        if (l.cifras.sinDatos) continue;
        expect(
          find.descendant(
            of: find.byKey(ValueKey('finanzas-hoy-quedan-${l.libroId}')),
            matching: find.text(dis.formatearCentavos(l.cifras.disponible)),
          ),
          findsOneWidget,
          reason: l.nombre,
        );
        expect(
          find.byKey(ValueKey('finanzas-hoy-alertas-${l.libroId}')),
          findsOneWidget,
        );
      }
    });

    testWidgets('un libro sin plan ni movimientos dice "Sin datos todavía", '
        'nunca ceros inventados', (tester) async {
      final repo = _sinPlan(sesionDe(Rol.dueno));
      await _montarConRepo(tester, repo);
      final resumen = (await _cargado(tester)).read(resumenFinanzasHoyProvider);
      expect(resumen.estado, EstadoResumenHoy.conLibros);
      expect(resumen.sinDatos, isTrue);
      await _mostrarTarjetaHoy(tester);
      expect(find.byKey(const ValueKey('finanzas-hoy-sin-datos')), findsOneWidget);
      expect(find.textContaining('Quedan'), findsNothing);
    });

    testWidgets('el semáforo y las alertas críticas salen del libro y de la '
        'bandeja', (tester) async {
      await montarFinanzasConTamano(
        tester,
        dispositivo: TipoDispositivo.telefono,
        tamano: _telefono,
      );
      final c = await _cargado(tester);
      final resumen = c.read(resumenFinanzasHoyProvider);
      expect(resumen.alertasCriticas, 0);
      for (final l in resumen.libros) {
        expect(l.textoAlertas, 'Sin alertas críticas');
      }
      final uno = ResumenLibroHoy(
        libroId: 'x',
        nombre: 'X',
        tipo: dom.TipoLibro.personal,
        cifras: CifrasSemana(
          semana: semana,
          ingresoPlaneado: 0,
          ingresoReal: 0,
          presupuesto: 0,
          gastado: 0,
          deuda: 0,
          abonado: 0,
          remanentePlaneado: 0,
          remanenteReal: 0,
          semaforo: dom.Semaforo.verde,
          sinDatos: true,
        ),
        alertasCriticas: 2,
      );
      expect(uno.textoAlertas, '2 alertas críticas');
    });
  });

  group('2. Chip "+ Cuenta" al final de la lista de cuentas', () {
    testWidgets('dice "+ Cuenta", va después de las cuentas y mide 48 dp o '
        'más', (tester) async {
      await montarFinanzasConTamano(
        tester,
        dispositivo: TipoDispositivo.telefono,
        tamano: _telefono,
      );
      await abrirRegistroDelTelefono(tester, 'Gasto');
      expect(find.text('+ Cuenta'), findsOneWidget);
      expect(find.text('Cuenta nueva'), findsNothing);
      final chip = find.byKey(const ValueKey('gasto-cuenta-nueva'));
      final cuentas = find.byWidgetPredicate(
        (w) =>
            w is ChoiceChip &&
            w.key is ValueKey &&
            '${(w.key! as ValueKey).value}'.startsWith('gasto-cuenta-'),
      );
      expect(cuentas, findsWidgets);
      final ultima = tester.getRect(cuentas.last);
      final destacado = tester.getRect(chip);
      // Al final de la lista: en la misma fila a la derecha o en la siguiente.
      expect(
        destacado.top > ultima.top - 1 &&
            (destacado.left >= ultima.right - 1 || destacado.top >= ultima.bottom - 1),
        isTrue,
        reason: 'el chip va después de la última cuenta',
      );
      expect(destacado.height, greaterThanOrEqualTo(48));
    });

    testWidgets('al tocarlo abre el formulario y la cuenta nueva sigue el '
        'gasto', (tester) async {
      await montarFinanzasConTamano(
        tester,
        dispositivo: TipoDispositivo.telefono,
        tamano: _telefono,
      );
      await abrirRegistroDelTelefono(tester, 'Gasto');
      await tester.tap(find.text('+ Cuenta'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('cuenta-nueva')), findsOneWidget);
    });
  });

  group('3. Motivo válido: 3 visibles, 2 letras o dígitos, no todos iguales', () {
    test('errorDeMotivo explica lo que falta solo cuando ya escribió algo', () {
      expect(errorDeMotivo(''), isNull);
      expect(errorDeMotivo('   '), isNull);
      expect(errorDeMotivo('Luz'), isNull);
      for (final malo in ['ab', '___', '...', '---', 'aaa', 'a--']) {
        expect(errorDeMotivo(malo), mensajeMotivoCorto, reason: malo);
      }
    });

    testWidgets('el diálogo de anular no deja continuar con "aaa" ni "---" y '
        'muestra el error', (tester) async {
      await montarFinanzasConTamano(
        tester,
        dispositivo: TipoDispositivo.telefono,
        tamano: _telefono,
      );
      final contexto = tester.element(find.byType(Scaffold).first);
      String? resultado;
      unawaited(
        pedirTexto(
          contexto,
          titulo: 'Anular',
          etiqueta: 'Motivo',
          textoAccion: 'Anular',
          esMotivo: true,
        ).then((t) => resultado = t),
      );
      await avanzar(tester);
      final campo = find.byKey(const ValueKey('finanzas-dialogo-texto'));
      final boton = find.widgetWithText(FilledButton, 'Anular');
      for (final malo in ['aaa', '---', 'ab', '___']) {
        await tester.enterText(campo, malo);
        await tester.pump();
        expect(tester.widget<FilledButton>(boton).onPressed, isNull, reason: malo);
        expect(find.textContaining('al menos 2 letras'), findsWidgets, reason: malo);
      }
      await tester.enterText(campo, '  Luz  ');
      await tester.pump();
      expect(tester.widget<FilledButton>(boton).onPressed, isNotNull);
      await tester.tap(boton);
      await avanzar(tester);
      expect(resultado, 'Luz', reason: 'se recorta antes de guardar');
    });

    test('anular, retirar y el libro de papá rechazan un motivo vacío de '
        'sentido', () async {
      final sesion = sesionDe(Rol.dueno);
      final repo = repositorioDe(sesion);
      addTearDown(repo.cerrar);
      final base = servicioDe(repo, sesion);
      final svc = ServicioDeudasAhorro(base);
      final gasto = repo.datos.movimientos.firstWhere(
        (m) => m.tipo == TipoMovimiento.gasto,
      );
      for (final malo in ['___', 'aaa', '...', 'x']) {
        await expectLater(
          base.anular(gasto.id, motivo: malo),
          throwsA(isA<ErrorFinanzas>()),
          reason: malo,
        );
      }
      final bolsa = await svc.crearBolsa(
        libroId: _libroDueno,
        nombre: 'Viaje',
        tipo: TipoBolsaAhorro.metaLibre,
        meta: 100000,
        saldoInicial: 50000,
      );
      await expectLater(
        svc.retirar(
          bolsaId: bolsa.id,
          monto: 1000,
          tipo: TipoRetiro.usoPrevisto,
          motivo: '---',
          cuentaDestinoId: repo.datos
              .cuentasDe(_libroDueno)
              .firstWhere((c) => c.tipo == TipoCuenta.efectivo)
              .id,
        ),
        throwsA(isA<ErrorFinanzas>()),
      );
    });
  });

  group('4. Avisos de la app con fin_emitir_aviso, sin dinero', () {
    late RepositorioFinanzasEnMemoria repo;
    late ServicioFinanzas base;
    const montoGrande = 9999900;

    setUp(() async {
      final sesion = sesionDe(Rol.dueno);
      repo = repositorioDe(sesion);
      base = servicioDe(repo, sesion);
      final banco = repo.datos
          .cuentasDe(_libroDueno)
          .firstWhere((c) => c.tipo == TipoCuenta.banco);
      // Un gasto enorme: el saldo del peor caso baja de cero.
      await base.registrarGasto(
        libroId: _libroDueno,
        cuentaOrigenId: banco.id,
        lineas: const [LineaGasto(monto: montoGrande)],
      );
    });
    tearDown(() => repo.cerrar());

    test('flujo negativo: un aviso con tipo del catálogo, sin dinero y con '
        'clave estable', () async {
      final v = base.vista(_libroDueno, semana);
      expect(avisosPorEmitir(v).map((a) => a.tipo), contains(TipoAlerta.flujoNegativo));
      final emisor = EmisorAvisosFinanzas(reloj: () => ahoraDePrueba);
      final creados = await emisor.emitir(base, _libroDueno);
      expect(creados, greaterThan(0));
      final a = repo.avisosEmitidos.firstWhere((a) => a.tipo == 'flujo_negativo');
      expect(a.objetoTipo, 'libro');
      expect(a.objetoId, _libroDueno);
      expect(a.clave, 'flujo_negativo:$_libroDueno:${semana.inicio}');
      expect(a.clave, matches(RegExp(r'^[a-z0-9_:.\-]+$')));
      // Nada de dinero ni texto libre en lo que viaja.
      final enviado = repo.avisosEmitidos.map((x) => x.toString()).join();
      expect(enviado.contains('$montoGrande'), isFalse);
      expect(enviado.contains(r'$'), isFalse);
      expect(titulosDeAviso[a.tipo], isNotNull);
      expect(textoDeAvisoEsDiscreto(titulosDeAviso[a.tipo]!), isTrue);
    });

    test('cinco cálculos seguidos emiten un solo aviso', () async {
      final emisor = EmisorAvisosFinanzas(reloj: () => ahoraDePrueba);
      for (var i = 0; i < 5; i++) {
        await emisor.emitir(base, _libroDueno);
      }
      expect(
        repo.avisosEmitidos.where((a) => a.tipo == 'flujo_negativo'),
        hasLength(1),
      );
      // Aunque otro emisor (otra sesión) repita la clave, el servidor no duplica.
      final otro = EmisorAvisosFinanzas(reloj: () => ahoraDePrueba);
      expect(await otro.emitir(base, _libroDueno), 0);
      expect(
        repo.avisosEmitidos.where((a) => a.tipo == 'flujo_negativo'),
        hasLength(1),
      );
    });

    test('sin señal no se encola nada; al volver emite con el cálculo vigente',
        () async {
      final emisor = EmisorAvisosFinanzas(reloj: () => ahoraDePrueba);
      repo.simularSinConexion = true;
      expect(await emisor.emitir(base, _libroDueno), 0);
      expect(repo.avisosEmitidos, isEmpty);
      expect(emisor.emitidas, isEmpty, reason: 'no queda marcado como emitido');
      repo.simularSinConexion = false;
      expect(await emisor.emitir(base, _libroDueno), greaterThan(0));
      expect(repo.avisosEmitidos, isNotEmpty);
    });

    test('quien no escribe en el libro no emite (la cuenta maestra solo lee)',
        () async {
      final maestra = sesionDuenoMaestro();
      final soloLee = servicioDe(
        repositorioDe(sesionDe(Rol.coadministrador, maestra: true)),
        sesionDe(Rol.coadministrador, maestra: true),
      );
      final emisor = EmisorAvisosFinanzas(reloj: () => ahoraDePrueba);
      expect(await emisor.emitir(soloLee, _libroDueno), 0);
      expect(maestra.esMaestra, isTrue);
    });

    test('al llegar al tope del día lo registra y no reintenta en bucle',
        () async {
      var ahora = ahoraDePrueba;
      final emisor = EmisorAvisosFinanzas(reloj: () => ahora);
      repo.topeAvisosPorDia = 0;
      expect(await emisor.emitir(base, _libroDueno), 0);
      expect(emisor.enPausaHasta, ahoraDePrueba.add(EmisorAvisosFinanzas.pausaPorTope));
      // Sigue el tope: ni siquiera lo intenta durante la pausa.
      repo.topeAvisosPorDia = 60;
      expect(await emisor.emitir(base, _libroDueno), 0);
      expect(repo.avisosEmitidos, isEmpty);
      // Pasada la pausa, vuelve a intentar.
      ahora = ahoraDePrueba.add(const Duration(hours: 25));
      expect(await emisor.emitir(base, _libroDueno), greaterThan(0));
    });

    test('el servicio avisa tras guardar un movimiento (sin esperar)', () async {
      final llamados = <String>[];
      final sesion = sesionDe(Rol.dueno);
      final conGancho = ServicioFinanzas(
        repositorio: repo,
        personaId: sesion.persona.id,
        hogarId: hogarDeEjemplo,
        esDueno: true,
        reloj: () => ahoraDePrueba,
        alCambiarLibro: llamados.add,
      );
      final cuenta = repo.datos
          .cuentasDe(_libroDueno)
          .firstWhere((c) => c.tipo == TipoCuenta.banco);
      await conGancho.registrarGasto(
        libroId: _libroDueno,
        cuentaOrigenId: cuenta.id,
        lineas: const [LineaGasto(monto: 100)],
      );
      expect(llamados, [_libroDueno]);
    });

    testWidgets('en la app, guardar un gasto emite el aviso por el proveedor',
        (tester) async {
      final r = await montarFinanzasConTamano(
        tester,
        dispositivo: TipoDispositivo.telefono,
        tamano: _telefono,
      );
      final c = await _cargado(tester);
      final banco = r.datos
          .cuentasDe(_libroDueno)
          .firstWhere((x) => x.tipo == TipoCuenta.banco);
      await c
          .read(servicioFinanzasProvider)
          .registrarGasto(
            libroId: _libroDueno,
            cuentaOrigenId: banco.id,
            lineas: const [LineaGasto(monto: montoGrande)],
          );
      await avanzar(tester);
      expect(r.avisosEmitidos.map((a) => a.tipo), contains('flujo_negativo'));
    });
  });
}
