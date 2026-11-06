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
import 'package:finanzas_dominio/finanzas_dominio.dart'
    as dom
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
    show SeccionAvisosFinanzas, TarjetaFinanzasHoy, refrescarFinanzas;
import 'package:gravity/modulos/finanzas/pantallas/comunes.dart'
    show errorDeMotivo, escalonesDe, pedirTexto;
import 'package:gravity/modulos/finanzas/pantallas/ajustes_avisos.dart'
    show mensajeSilencioIgual;
import 'package:gravity/nucleo/avisos/aviso.dart';
import 'package:gravity/nucleo/avisos/catalogo_avisos.dart';
import 'package:gravity/nucleo/avisos/recordatorios.dart'
    as av
    show Vencimiento, calcularRecordatorios;
import 'package:gravity/modulos/finanzas/pantallas/fase2/dialogos_fase2.dart'
    show DialogoBolsa;
import 'package:gravity/nucleo/avisos/proveedores_avisos.dart';
import 'package:gravity/nucleo/avisos/repositorio_avisos.dart'
    show RepositorioAvisosEnMemoria;
import 'package:gravity/modulos/finanzas/pantallas/fase2/dialogos_fase2.dart'
    show DialogoEstadoDeCuenta;
import 'package:gravity/nucleo/conectividad/conectividad.dart'
    show FuenteConectividadFalsa, fuenteConectividadProvider;
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
        expect(
          l.cifras.disponible,
          v.planSemanal.presupuesto - v.real.gastoReal,
        );
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
      testWidgets(
        '${rol.name}: ${vistos ? 've sus libros' : 'no ve la tarjeta'}',
        (tester) async {
          await montarFinanzasConTamano(
            tester,
            dispositivo: TipoDispositivo.telefono,
            tamano: _telefono,
            rol: rol,
          );
          final resumen = (await _cargado(tester))
              .read(resumenFinanzasHoyProvider);
          expect(resumen.visible, vistos);
          if (!vistos) {
            expect(resumen.libros, isEmpty);
            await _mostrarTarjetaHoy(tester);
            expect(find.byKey(const ValueKey('finanzas-hoy')), findsNothing);
            expect(find.textContaining('Quedan'), findsNothing);
          }
        },
      );
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
      // El de papá solo si la pareja lo lleva (albacea o suplente vigente).
      final ctx = _contenedor(tester).read(contextoFinanzasProvider).value!;
      for (final l in ctx.libros) {
        final lleva = ctx.permisoEn(l).leer && !ctx.permisoEn(l).comoMaestra;
        expect(ids.contains(l.id), lleva && !ctx.permisoEn(l).comoLector);
      }
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
        find.descendant(
          of: tarjeta,
          matching: find.byType(dis.MarcaMontosOcultos),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tarjeta,
          matching: find.textContaining('Montos ocultos'),
        ),
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

    testWidgets(
      'con los montos a la vista muestra lo que queda de cada libro',
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
      },
    );

    testWidgets('un libro sin plan ni movimientos dice "Sin datos todavía", '
        'nunca ceros inventados', (tester) async {
      final repo = _sinPlan(sesionDe(Rol.dueno));
      await _montarConRepo(tester, repo);
      final resumen = (await _cargado(tester)).read(resumenFinanzasHoyProvider);
      expect(resumen.estado, EstadoResumenHoy.conLibros);
      expect(resumen.sinDatos, isTrue);
      await _mostrarTarjetaHoy(tester);
      expect(
        find.byKey(const ValueKey('finanzas-hoy-sin-datos')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('finanzas-hoy')),
          matching: find.textContaining('Quedan'),
        ),
        findsNothing,
      );
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
            (destacado.left >= ultima.right - 1 ||
                destacado.top >= ultima.bottom - 1),
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
      await tester.ensureVisible(find.text('+ Cuenta'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('+ Cuenta'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('cuenta-nueva')), findsOneWidget);
    });
  });

  group(
    '3. Motivo válido: 3 visibles, 2 letras o dígitos, no todos iguales',
    () {
      test(
        'errorDeMotivo explica lo que falta solo cuando ya escribió algo',
        () {
          expect(errorDeMotivo(''), isNull);
          expect(errorDeMotivo('   '), isNull);
          expect(errorDeMotivo('Luz'), isNull);
          for (final malo in ['ab', '___', '...', '---', 'aaa', 'a--']) {
            expect(errorDeMotivo(malo), mensajeMotivoCorto, reason: malo);
          }
        },
      );

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
          expect(
            tester.widget<FilledButton>(boton).onPressed,
            isNull,
            reason: malo,
          );
          expect(
            find.textContaining('al menos 2 letras'),
            findsWidgets,
            reason: malo,
          );
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
    },
  );

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
      expect(
        avisosPorEmitir(v).map((a) => a.tipo),
        contains(TipoAlerta.flujoNegativo),
      );
      final emisor = EmisorAvisosFinanzas(reloj: () => ahoraDePrueba);
      final creados = await emisor.emitir(base, _libroDueno);
      expect(creados, greaterThan(0));
      final a = repo.avisosEmitidos.firstWhere(
        (a) => a.tipo == 'flujo_negativo',
      );
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

    test(
      'sin señal no se encola nada; al volver emite con el cálculo vigente',
      () async {
        final emisor = EmisorAvisosFinanzas(reloj: () => ahoraDePrueba);
        repo.simularSinConexion = true;
        expect(await emisor.emitir(base, _libroDueno), 0);
        expect(repo.avisosEmitidos, isEmpty);
        expect(
          emisor.emitidas,
          isEmpty,
          reason: 'no queda marcado como emitido',
        );
        repo.simularSinConexion = false;
        expect(await emisor.emitir(base, _libroDueno), greaterThan(0));
        expect(repo.avisosEmitidos, isNotEmpty);
      },
    );

    test(
      'quien no escribe en el libro no emite (la cuenta maestra solo lee)',
      () async {
        final maestra = sesionDuenoMaestro();
        final soloLee = servicioDe(
          repositorioDe(sesionDe(Rol.coadministrador, maestra: true)),
          sesionDe(Rol.coadministrador, maestra: true),
        );
        final emisor = EmisorAvisosFinanzas(reloj: () => ahoraDePrueba);
        expect(await emisor.emitir(soloLee, _libroDueno), 0);
        expect(maestra.esMaestra, isTrue);
      },
    );

    test(
      'al llegar al tope del día lo registra y no reintenta en bucle',
      () async {
        var ahora = ahoraDePrueba;
        final emisor = EmisorAvisosFinanzas(reloj: () => ahora);
        repo.topeAvisosPorDia = 0;
        expect(await emisor.emitir(base, _libroDueno), 0);
        expect(
          emisor.enPausaHasta,
          ahoraDePrueba.add(EmisorAvisosFinanzas.pausaPorTope),
        );
        // Sigue el tope: ni siquiera lo intenta durante la pausa.
        repo.topeAvisosPorDia = 60;
        expect(await emisor.emitir(base, _libroDueno), 0);
        expect(repo.avisosEmitidos, isEmpty);
        // Pasada la pausa, vuelve a intentar.
        ahora = ahoraDePrueba.add(const Duration(hours: 25));
        expect(await emisor.emitir(base, _libroDueno), greaterThan(0));
      },
    );

    test(
      'el servicio avisa tras guardar un movimiento (sin esperar)',
      () async {
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
      },
    );

    testWidgets('en la app, guardar un gasto emite el aviso por el proveedor', (
      tester,
    ) async {
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
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await avanzar(tester);
      expect(r.avisosEmitidos.map((a) => a.tipo), contains('flujo_negativo'));
    });
  });

  group('5. Cierre con ahorro automático, deshacible', () {
    const casa = IdsDemostracion.libroCasa;
    late RepositorioFinanzasEnMemoria repo;
    late ServicioFinanzas base;
    late ServicioDeudasAhorro svc;
    late BolsaAhorro fondo;
    // La semana siguiente aún no está activada: toma los parámetros nuevos.
    final sem = semana.siguiente;

    setUp(() async {
      final sesion = sesionDe(Rol.dueno);
      repo = repositorioDe(sesion);
      base = servicioDe(repo, sesion);
      svc = ServicioDeudasAhorro(base);
      // Con deudas, una parte del remanente va a ahorro desde el inicio.
      await base.guardarParametros(
        repo.datos
            .parametrosDe(casa)
            .copiar(ahorroMinimoConDeudaPuntosBase: 5000),
      );
      fondo = await svc.crearBolsa(
        libroId: casa,
        nombre: 'Fondo de ejemplo',
        tipo: TipoBolsaAhorro.fondoEmergencia,
        metodos: const [MetodoAhorro.sobranteSemanal, MetodoAhorro.redondeo],
      );
      await base.activarSemana(casa, sem);
    });
    tearDown(() => repo.cerrar());

    test('el plan aparta del ahorro que el motor ya propone, en orden', () {
      final destino = base.vista(casa, sem).real.destino;
      final plan = svc.planAhorroDeCierre(casa, sem);
      expect(plan.aportes, isNotEmpty);
      expect(plan.total, lessThanOrEqualTo(destino.ahorro));
      final orden = plan.aportes.map((a) => a.origen.index).toList();
      expect(
        [...orden]..sort(),
        orden,
        reason: 'extras, sobre, sobrante, redondeo',
      );
    });

    test('aplicar crea transferencias con su origen a la vista, es idempotente '
        'y se deshace con contraasiento', () async {
      final plan = svc.planAhorroDeCierre(casa, sem);
      final origen = repo.datos
          .cuentasDe(casa)
          .firstWhere((c) => c.tipo == TipoCuenta.banco);
      final saldoAntes = svc.saldoDeBolsa(fondo);
      final cierre = await base.cerrarSemana(
        casa,
        sem,
        accion: AccionCierre.aplicarRemanente,
      );
      final nuevos = await svc.aplicarAhorroAutomatico(
        libroId: casa,
        plan: plan,
        cuentaOrigenId: origen.id,
        cierreId: cierre.id,
      );
      expect(nuevos, hasLength(plan.aportes.length));
      for (final m in nuevos) {
        expect(m.tipo, TipoMovimiento.transferencia);
        expect(m.nota, startsWith('Ahorro automático · '));
      }
      expect(svc.saldoDeBolsa(fondo), saldoAntes + plan.total);
      // Cerrar/aplicar dos veces el mismo cierre no duplica.
      final otraVez = await svc.aplicarAhorroAutomatico(
        libroId: casa,
        plan: plan,
        cuentaOrigenId: origen.id,
        cierreId: cierre.id,
      );
      expect(otraVez, isEmpty);
      expect(svc.saldoDeBolsa(fondo), saldoAntes + plan.total);
      // Deshacer: anulación + contraasiento; nada se borra.
      final movsAntes = repo.datos.movimientos.length;
      expect(
        await svc.deshacerAhorroAutomatico(libroId: casa, cierreId: cierre.id),
        nuevos.length,
      );
      expect(repo.datos.movimientos.length, movsAntes + nuevos.length);
      for (final m in nuevos) {
        expect(repo.datos.movimientos.any((x) => x.id == m.id), isTrue);
      }
      expect(svc.saldoDeBolsa(fondo), saldoAntes);
      expect(
        await svc.deshacerAhorroAutomatico(libroId: casa, cierreId: cierre.id),
        0,
      );
    });

    test('con semanas cerradas el gasto esencial es real y deja de decir '
        '"según tu plan"', () async {
      expect(svc.gastoEsencial(casa, sem).rotulo, 'según tu plan');
      await base.cerrarSemana(casa, sem);
      final g = svc.gastoEsencial(casa, sem.siguiente);
      expect(g.origen, OrigenEsencial.historial);
      expect(g.rotulo, isNull);
      expect(g.semanasUsadas, 1);
      expect(esencialesPorSemanaCerrada(repo.datos, casa), hasLength(1));
    });
  });

  group('6. Sin señal: estados de cuenta, aportaciones y retiros', () {
    late RepositorioFinanzasEnMemoria repo;
    late ServicioFinanzas base;

    Future<Deuda> tarjeta() async {
      final cuenta = await base.crearCuenta(
        libroId: _libroDueno,
        nombre: 'Tarjeta de ejemplo',
        tipo: TipoCuenta.tarjeta,
        saldoInicial: 500000,
        limiteCentavos: 1000000,
      );
      final d = Deuda(
        id: base.nuevoId(),
        libroId: _libroDueno,
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
      await base.guardarDeuda(d);
      return d;
    }

    setUp(() {
      final sesion = sesionDe(Rol.dueno);
      repo = repositorioDe(sesion);
      base = servicioDe(repo, sesion);
    });
    tearDown(() => repo.cerrar());

    test(
      'el servicio avisa antes de tocar nada: sin cola y sin cambios',
      () async {
        final d = await tarjeta();
        final svc = ServicioDeudasAhorro(base, hayRed: () => false);
        final bolsa = await ServicioDeudasAhorro(base).crearBolsa(
          libroId: _libroDueno,
          nombre: 'Viaje',
          tipo: TipoBolsaAhorro.metaLibre,
          meta: 100000,
          saldoInicial: 50000,
        );
        final antes = repo.datos.movimientos.length;
        final efectivo = repo.datos
            .cuentasDe(_libroDueno)
            .firstWhere((c) => c.tipo == TipoCuenta.efectivo);
        await expectLater(
          svc.registrarEstadoDeCuenta(
            deudaId: d.id,
            corte: hoyDePrueba,
            limitePago: hoyDePrueba.sumarDias(20),
            saldoAlCorte: 1000,
            pagoMinimo: 100,
            pagoSinIntereses: 500,
          ),
          throwsA(same(ErrorFinanzas.necesitaConexion)),
        );
        await expectLater(
          svc.retirar(
            bolsaId: bolsa.id,
            monto: 1000,
            tipo: TipoRetiro.usoPrevisto,
            motivo: 'Para el viaje',
            cuentaDestinoId: efectivo.id,
          ),
          throwsA(same(ErrorFinanzas.necesitaConexion)),
        );
        expect(repo.datos.movimientos.length, antes);
        expect(repo.datos.estadosDeCuenta, isEmpty);
        expect(repo.datos.retiros, isEmpty);
        expect(
          ErrorFinanzas.necesitaConexion.mensaje,
          startsWith('Esto necesita conexión'),
        );
        expect(
          ErrorFinanzas.necesitaConexion.mensaje,
          contains('Tus datos siguen aquí'),
        );
      },
    );

    testWidgets(
      'el formulario avisa al abrir, deshabilita Guardar con la razón '
      'y, si se cae la señal, conserva lo escrito con Reintentar',
      (tester) async {
        final r = await montarFinanzasConTamano(
          tester,
          dispositivo: TipoDispositivo.telefono,
          tamano: _telefono,
        );
        base = servicioDe(r, sesionDe(Rol.dueno));
        final d = await tarjeta();
        final contexto = tester.element(find.byType(Scaffold).first);
        final c = _contenedor(tester);
        unawaited(
          showDialog<void>(
            context: contexto,
            builder: (_) => DialogoEstadoDeCuenta(deuda: d),
          ),
        );
        await avanzar(tester);
        expect(find.byKey(const ValueKey('dialogo-sin-senal')), findsNothing);
        // Señal en el sistema, pero el servidor no responde al guardar.
        r.simularSinConexion = true;
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('ec-saldo')),
            matching: find.byType(TextField),
          ),
          '1000',
        );
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('ec-minimo')),
            matching: find.byType(TextField),
          ),
          '100',
        );
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('ec-sin-intereses')),
            matching: find.byType(TextField),
          ),
          '500',
        );
        await tester.enterText(find.byType(TextFormField).last, '45');
        await tester.pump();
        await tester.ensureVisible(
          find.byKey(const ValueKey('dialogo-guardar')),
        );
        await tester.tap(find.byKey(const ValueKey('dialogo-guardar')));
        await avanzar(tester);
        expect(
          find.byKey(const ValueKey('dialogo-necesita-conexion')),
          findsOneWidget,
        );
        expect(find.textContaining('Tus datos siguen aquí'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('dialogo-reintentar')),
          findsOneWidget,
        );
        expect(
          find.byType(AlertDialog),
          findsOneWidget,
          reason: 'no se cierra',
        );
        expect(
          find.text('1000'),
          findsOneWidget,
          reason: 'no pierde lo escrito',
        );
        expect(r.datos.estadosDeCuenta, isEmpty);
        // Vuelve la señal: Reintentar guarda una sola vez.
        r.simularSinConexion = false;
        await tester.tap(find.byKey(const ValueKey('dialogo-reintentar')));
        await avanzar(tester);
        expect(r.datos.estadosDeCuenta, hasLength(1));
        expect(find.byType(AlertDialog), findsNothing);
        expect(c, isNotNull);
      },
    );
  });

  testWidgets('6. sin señal al abrir: avisa y Guardar queda deshabilitado '
      'con la razón visible', (tester) async {
    final repo = repositorioDe(sesionDe(Rol.dueno));
    addTearDown(repo.cerrar);
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.telefono,
      sesion: ServicioSesionDemostracion(inicial: sesionDe(Rol.dueno)),
      reloj: RelojFijo(DateTime(2026, 10, 20, 10)),
      extras: [
        repositorioFinanzasProvider.overrideWithValue(repo),
        fuenteConectividadProvider.overrideWithValue(
          FuenteConectividadFalsa(hayRed: false),
        ),
      ],
    );
    tester.view.physicalSize = _telefono;
    await _cargado(tester);
    final base = servicioDe(repo, sesionDe(Rol.dueno));
    final cuenta = await base.crearCuenta(
      libroId: _libroDueno,
      nombre: 'Tarjeta de ejemplo',
      tipo: TipoCuenta.tarjeta,
      saldoInicial: 1000,
      limiteCentavos: 100000,
    );
    final d = Deuda(
      id: 'deuda-x',
      libroId: _libroDueno,
      nombre: 'Tarjeta de ejemplo',
      tipo: TipoDeuda.conCosto,
      clase: ClaseDeuda.tarjeta,
      cuentaPasivoId: cuenta.id,
      abono: 1000,
      frecuencia: Frecuencia.mensual,
      tasaAnualPuntosBase: 4500,
    );
    unawaited(
      showDialog<void>(
        context: tester.element(find.byType(Scaffold).first),
        builder: (_) => DialogoEstadoDeCuenta(deuda: d),
      ),
    );
    await avanzar(tester);
    expect(find.byKey(const ValueKey('dialogo-sin-senal')), findsOneWidget);
    expect(
      find.textContaining('podrás revisar, pero no guardar'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('dialogo-guardar')))
          .onPressed,
      isNull,
    );
  });

  group('8. Sección de Finanzas en Ajustes › Notificaciones', () {
    testWidgets('edita días antes, horas y recordatorio de cierre; valida y '
        'guarda', (tester) async {
      final avisos = RepositorioAvisosEnMemoria();
      final repo = repositorioDe(sesionDe(Rol.dueno));
      addTearDown(repo.cerrar);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: ServicioSesionDemostracion(inicial: sesionDe(Rol.dueno)),
        reloj: RelojFijo(DateTime(2026, 10, 20, 10)),
        extras: [
          repositorioFinanzasProvider.overrideWithValue(repo),
          repositorioAvisosProvider.overrideWithValue(avisos),
        ],
      );
      tester.view.physicalSize = const Size(360, 1600);
      final c = await _cargado(tester);
      final contexto = tester.element(find.byType(Scaffold).first);
      unawaited(
        showDialog<void>(
          context: contexto,
          builder: (_) => const Dialog(
            child: SingleChildScrollView(child: SeccionAvisosFinanzas()),
          ),
        ),
      );
      await avanzar(tester);
      expect(find.byKey(const ValueKey('avisos-finanzas')), findsOneWidget);
      // Agrega 7 días antes (quedan 7, 3 y 1).
      await tester.tap(find.byKey(const ValueKey('avisos-fin-dias-7')));
      await avanzar(tester);
      expect(avisos.preferenciasIniciales!.diasAvisoDeuda, [7, 3, 1]);
      expect(
        c
            .read(contextoFinanzasProvider)
            .value!
            .datos
            .parametrosDe(_libroDueno)
            .diasAvisoDeuda,
        [7, 3, 1],
      );
      // Un cuarto aviso no se guarda.
      await tester.tap(find.byKey(const ValueKey('avisos-fin-dias-5')));
      await avanzar(tester);
      expect(find.byKey(const ValueKey('avisos-fin-error')), findsOneWidget);
      expect(avisos.preferenciasIniciales!.diasAvisoDeuda, [7, 3, 1]);
    });

    testWidgets('un rol sin Finanzas no ve la sección', (tester) async {
      await montarFinanzasConTamano(
        tester,
        dispositivo: TipoDispositivo.telefono,
        tamano: _telefono,
        rol: Rol.cuidador,
      );
      final contexto = tester.element(find.byType(Scaffold).first);
      unawaited(
        showDialog<void>(
          context: contexto,
          builder: (_) => const Dialog(child: SeccionAvisosFinanzas()),
        ),
      );
      await avanzar(tester);
      expect(find.byKey(const ValueKey('avisos-finanzas')), findsNothing);
    });

    test('el silencio no puede empezar y terminar a la misma hora', () {
      expect(mensajeSilencioIgual, contains('misma hora'));
      expect(
        const PreferenciasAvisos().silencioDesde ==
            const PreferenciasAvisos().silencioHasta,
        isFalse,
      );
    });
  });

  group('9. Gancho de la baja: refrescarFinanzas', () {
    testWidgets('al salirse del compartido, refrescar quita el libro de "Hoy" '
        'sin reiniciar', (tester) async {
      await montarFinanzasConTamano(
        tester,
        dispositivo: TipoDispositivo.telefono,
        tamano: _telefono,
        rol: Rol.coadministrador,
      );
      final c = await _cargado(tester);
      final antes = c
          .read(resumenFinanzasHoyProvider)
          .libros
          .map((l) => l.libroId)
          .toList();
      final ctx = c.read(contextoFinanzasProvider).value!;
      final compartido = ctx.libros.firstWhere(
        (l) => l.tipo == dom.TipoLibro.compartido && ctx.puedeSalirDe(l),
      );
      expect(antes, contains(compartido.id));
      await c.read(servicioFinanzasProvider).salirDelLibro(compartido.id);
      await refrescarFinanzas(c);
      await avanzar(tester);
      final despues = c
          .read(resumenFinanzasHoyProvider)
          .libros
          .map((l) => l.libroId);
      expect(despues, isNot(contains(compartido.id)));
    });
  });

  group('D25: extras 20 %, prioridad de bolsas y varios días antes', () {
    test(
      'una bolsa con extras sin porcentaje aparta el 20 % y es editable',
      () async {
        final sesion = sesionDe(Rol.dueno);
        final repo = repositorioDe(sesion);
        addTearDown(repo.cerrar);
        final svc = ServicioDeudasAhorro(servicioDe(repo, sesion));
        final a = await svc.crearBolsa(
          libroId: _libroDueno,
          nombre: 'Por omisión',
          tipo: TipoBolsaAhorro.metaLibre,
          metodos: const [MetodoAhorro.porcentajeDeExtras],
        );
        final b = await svc.crearBolsa(
          libroId: _libroDueno,
          nombre: 'Editada',
          tipo: TipoBolsaAhorro.metaLibre,
          metodos: const [MetodoAhorro.porcentajeDeExtras],
          aportePb: 500,
        );
        final plan = planearAhorroDeCierre(
          remanente: 100000,
          extras: 50000,
          bolsas: [
            a,
            repo.datos.bolsasDe(_libroDueno).firstWhere((x) => x.id == b.id),
          ],
        );
        expect(plan.aportadoA(a.id), 10000);
        expect(plan.aportadoA(b.id), 2500);
      },
    );

    testWidgets('el formulario de bolsa ofrece los métodos y el % de extras '
        '(20 por omisión)', (tester) async {
      final repo = await montarFinanzasConTamano(
        tester,
        dispositivo: TipoDispositivo.telefono,
        tamano: _telefono,
      );
      final c = await _cargado(tester);
      unawaited(
        showDialog<void>(
          context: tester.element(find.byType(Scaffold).first),
          builder: (_) =>
              DialogoBolsa(contexto: c.read(contextoFinanzasProvider).value!),
        ),
      );
      await avanzar(tester);
      await tester.enterText(
        find.byKey(const ValueKey('bolsa-nombre')),
        'Viaje',
      );
      await tester.tap(
        find.byKey(const ValueKey('bolsa-metodo-porcentaje_extras')),
      );
      await tester.tap(find.byKey(const ValueKey('bolsa-metodo-redondeo')));
      await tester.pump();
      expect(find.byKey(const ValueKey('bolsa-extras-pct')), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('dialogo-guardar')));
      await tester.tap(find.byKey(const ValueKey('dialogo-guardar')));
      await avanzar(tester);
      final bolsa = repo.datos
          .bolsasDe(_libroDueno)
          .firstWhere((x) => x.nombre == 'Viaje');
      expect(
        bolsa.metodos,
        containsAll([MetodoAhorro.porcentajeDeExtras, MetodoAhorro.redondeo]),
      );
      expect(bolsa.aportePb, 2000);
    });

    test('la prioridad arrastrada llega al plan del servicio', () async {
      final sesion = sesionDe(Rol.dueno);
      final repo = repositorioDe(sesion);
      addTearDown(repo.cerrar);
      final base = servicioDe(repo, sesion);
      final svc = ServicioDeudasAhorro(base);
      const casa = IdsDemostracion.libroCasa;
      final sem = semana.siguiente;
      await base.guardarParametros(
        repo.datos
            .parametrosDe(casa)
            .copiar(ahorroMinimoConDeudaPuntosBase: 5000),
      );
      await svc.crearBolsa(
        libroId: casa,
        nombre: 'Fondo',
        tipo: TipoBolsaAhorro.fondoEmergencia,
        metodos: const [MetodoAhorro.sobranteSemanal],
      );
      await base.activarSemana(casa, sem);
      final plan = svc.planAhorroDeCierre(casa, sem, orden: const ['x']);
      expect(plan.aportes, isNotEmpty);
    });

    test(
      'varios "días antes" por vencimiento: uno por cada día configurado',
      () {
        final ahora = DateTime(2026, 10, 20, 8);
        final vence = DateTime(2026, 10, 30);
        final r = av.calcularRecordatorios(
          preferencias: const PreferenciasAvisos(diasAvisoDeuda: [7, 3, 1]),
          ahora: ahora,
          vencimientos: [av.Vencimiento(objetoId: 'o1', fecha: vence)],
        ).where((x) => x.tipo == 'pago_proximo').toList();
        expect(r, hasLength(3));
        expect(r.map((x) => x.clave.split(':').last), ['7', '3', '1']);
        for (final x in r) {
          expect(x.clave.contains(r'$'), isFalse);
        }
      },
    );
  });
}
