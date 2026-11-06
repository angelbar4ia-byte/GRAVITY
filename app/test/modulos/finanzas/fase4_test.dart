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
}
