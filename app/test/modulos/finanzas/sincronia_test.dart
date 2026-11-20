// F8-6.6: Finanzas al día entre dispositivos (docs/specs/fase-8-finanzas-realtime.md).
// Sin servidor: una fuente falsa de avisos de Realtime y un reloj que avanza con
// la prueba. Cubre: aviso con debounce de 1.5 s y una sola recarga por ráfaga,
// aplazar con una hoja abierta, mínimo de 10 s en entrar/volver/reconectar, sin
// temporizador periódico, la reconexión, el mensaje sin datos y que lo pendiente
// de la cola siga visible tras recargar.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/finanzas/casos_uso/servicio_finanzas.dart'
    show LineaGasto;
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/modulos/finanzas/datos/filas.dart' show TablasFinanzas;
import 'package:gravity/modulos/finanzas/datos/fuente_cambios_finanzas.dart';
import 'package:gravity/modulos/finanzas/datos/fuente_tablas.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_supabase.dart';
import 'package:gravity/modulos/finanzas/estado/proveedores.dart';
import 'package:gravity/modulos/finanzas/estado/sincronia_finanzas.dart';
import 'package:gravity/modulos/finanzas/pantallas/sincronia_finanzas.dart';
import 'package:gravity/nucleo/base_local/base_local.dart';
import 'package:gravity/nucleo/cola/cola_sin_conexion.dart';
import 'package:gravity/nucleo/contratos/roles.dart';

import 'ayuda_finanzas.dart';
import 'contrato_servidor_test.dart' show sembrar;

/// Fuente falsa: la prueba emite los avisos a mano.
class FuenteFalsa implements FuenteCambiosFinanzas {
  final List<Set<String>> pedidos = [];
  StreamController<EventoSincronia>? _control;
  int cancelaciones = 0;

  bool get escuchando => _control?.hasListener ?? false;

  @override
  Stream<EventoSincronia> escuchar(Set<String> libroIds) {
    pedidos.add(libroIds);
    _control = StreamController<EventoSincronia>(
      onCancel: () => cancelaciones++,
    );
    return _control!.stream;
  }

  void cambio(String libro) => _control!.add(CambioDeLibro(libro));
  void reconectado() => _control!.add(const CanalReconectado());
}

/// Banco de pruebas: el servicio, el reloj y las recargas contadas.
class Banco {
  Banco({
    this.fallaAlRecargar = false,
    Duration retraso = Duration.zero,
    this.conFuente = true,
  }) {
    servicio = ServicioSincroniaFinanzas(
      fuente: conFuente ? fuente : null,
      recargar: () async {
        recargas++;
        if (retraso > Duration.zero) await Future<void>.delayed(retraso);
        if (fallaAlRecargar) throw StateError('sin servidor');
      },
      ahora: () => _base.add(transcurrido),
    );
  }

  final bool fallaAlRecargar;
  final bool conFuente;
  final fuente = FuenteFalsa();
  final _base = DateTime(2026, 11, 20, 9);
  Duration transcurrido = Duration.zero;
  int recargas = 0;
  bool hoja = false;
  late final ServicioSincroniaFinanzas servicio;

  void abrir() => servicio.abrir(hojaAbierta: () => hoja);

  /// Avanza el reloj de la prueba y el del servicio juntos, a pasos.
  Future<void> pasar(WidgetTester t, Duration d) async {
    await t.pump(Duration.zero);
    final paso = d > const Duration(seconds: 5)
        ? const Duration(seconds: 1)
        : const Duration(milliseconds: 100);
    var restante = d;
    while (restante > Duration.zero) {
      final p = restante < paso ? restante : paso;
      transcurrido += p;
      await t.pump(p);
      restante -= p;
    }
  }
}

void main() {
  const l1 = 'libro-1';

  group('Servicio: avisos de Realtime', () {
    testWidgets('un aviso recarga una sola vez, tras 1.5 s', (t) async {
      final b = Banco()..servicio.marcarRefresco();
      b.servicio.actualizarLibros({l1});
      b.abrir();
      await b.pasar(t, Duration.zero);
      expect(b.fuente.pedidos, [
        {l1},
      ]);
      b.fuente.cambio(l1);
      await b.pasar(t, const Duration(milliseconds: 1400));
      expect(b.recargas, 0, reason: 'todavía en la espera');
      await b.pasar(t, const Duration(milliseconds: 200));
      expect(b.recargas, 1);
      b.servicio.liberar();
    });

    testWidgets('una ráfaga de avisos (varias tablas, varios libros) = una recarga', (
      t,
    ) async {
      final b = Banco()..servicio.marcarRefresco();
      b.servicio.actualizarLibros({l1, 'libro-2'});
      b.abrir();
      await b.pasar(t, Duration.zero);
      for (var i = 0; i < 6; i++) {
        b.fuente.cambio(i.isEven ? l1 : 'libro-2');
        await b.pasar(t, const Duration(milliseconds: 100));
      }
      await b.pasar(t, const Duration(seconds: 3));
      expect(b.recargas, 1);
      b.servicio.liberar();
    });

    testWidgets('un aviso durante una recarga pide una más al terminar', (t) async {
      final b = Banco(retraso: const Duration(seconds: 2))
        ..servicio.marcarRefresco();
      b.servicio.actualizarLibros({l1});
      b.abrir();
      await b.pasar(t, Duration.zero);
      b.fuente.cambio(l1);
      await b.pasar(t, const Duration(milliseconds: 1600));
      expect(b.recargas, 1);
      b.fuente.cambio(l1); // llega mientras recarga
      await b.pasar(t, const Duration(seconds: 8));
      expect(b.recargas, 2, reason: 'el cambio pudo ser posterior a la lectura');
      b.servicio.liberar();
    });

    testWidgets('una recarga que falla no rompe nada y se sigue escuchando', (
      t,
    ) async {
      final b = Banco(fallaAlRecargar: true)..servicio.marcarRefresco();
      b.servicio.actualizarLibros({l1});
      b.abrir();
      b.fuente.cambio(l1);
      await b.pasar(t, const Duration(seconds: 2));
      b.fuente.cambio(l1);
      await b.pasar(t, const Duration(seconds: 2));
      expect(b.recargas, 2);
      b.servicio.liberar();
    });

    test('el aviso no lleva datos: la fuente solo dice qué libro cambió', () {
      // Contrato del evento: un id de libro y nada más (D3, D20).
      const e = CambioDeLibro('libro-1');
      expect(e.libroId, 'libro-1');
      expect(temaDeLibroFinanzas('libro-1'), 'finanzas:libro:libro-1');
    });
  });

  group('Servicio: aplazar con una hoja abierta', () {
    testWidgets('con una hoja abierta no recarga; al cerrarla, sí', (t) async {
      final b = Banco()..servicio.marcarRefresco();
      b.servicio.actualizarLibros({l1});
      b.abrir();
      b.hoja = true;
      b.fuente.cambio(l1);
      await b.pasar(t, const Duration(seconds: 2));
      expect(b.recargas, 0);
      expect(b.servicio.pendientePorHoja, isTrue);
      await b.pasar(t, const Duration(seconds: 10));
      expect(b.recargas, 0, reason: 'sigue abierta: sigue aplazada');
      b.hoja = false;
      await b.pasar(t, const Duration(seconds: 1));
      expect(b.recargas, 1);
      expect(b.servicio.pendientePorHoja, isFalse);
      b.servicio.liberar();
    });

    testWidgets('varios avisos con la hoja abierta = una recarga al cerrarla', (
      t,
    ) async {
      final b = Banco()..servicio.marcarRefresco();
      b.servicio.actualizarLibros({l1});
      b.abrir();
      b.hoja = true;
      for (var i = 0; i < 4; i++) {
        b.fuente.cambio(l1);
        await b.pasar(t, const Duration(seconds: 2));
      }
      b.hoja = false;
      await b.pasar(t, const Duration(seconds: 2));
      expect(b.recargas, 1);
      b.servicio.liberar();
    });

    testWidgets('volver de segundo plano con una hoja abierta también espera', (
      t,
    ) async {
      final b = Banco();
      b.servicio.actualizarLibros({l1});
      b.abrir(); // sin refresco previo: recarga al entrar
      await b.pasar(t, const Duration(seconds: 30));
      final antes = b.recargas;
      b.hoja = true;
      b.servicio.alVolver();
      await b.pasar(t, const Duration(seconds: 3));
      expect(b.recargas, antes);
      b.hoja = false;
      await b.pasar(t, const Duration(seconds: 1));
      expect(b.recargas, antes + 1);
      b.servicio.liberar();
    });
  });

  group('Servicio: entrar, volver y reconectar (mínimo de 10 s)', () {
    testWidgets('al entrar recarga; si acaba de cargar, no', (t) async {
      final b = Banco();
      b.servicio.actualizarLibros({l1});
      b.abrir();
      await b.pasar(t, Duration.zero);
      expect(b.recargas, 1, reason: 'entrar sin carga reciente');
      b.servicio.liberar();
      await b.pasar(t, Duration.zero);

      final c = Banco()..servicio.marcarRefresco();
      c.servicio.actualizarLibros({l1});
      c.abrir();
      await c.pasar(t, const Duration(seconds: 3));
      expect(c.recargas, 0, reason: 'la carga inicial cuenta como refresco');
      c.servicio.liberar();
    });

    testWidgets('volver a entrar al módulo tras más de 10 s recarga', (t) async {
      final b = Banco()..servicio.marcarRefresco();
      b.servicio.actualizarLibros({l1});
      b.abrir();
      await b.pasar(t, const Duration(seconds: 1));
      b.servicio.cerrar();
      await b.pasar(t, const Duration(seconds: 15));
      expect(b.fuente.escuchando, isFalse, reason: 'cerrado: sin suscripción');
      b.abrir();
      await b.pasar(t, Duration.zero);
      expect(b.recargas, 1);
      expect(b.fuente.pedidos, hasLength(2), reason: 'se suscribió de nuevo');
      b.servicio.liberar();
    });

    testWidgets('al volver de segundo plano: no antes de 10 s, sí después', (
      t,
    ) async {
      final b = Banco()..servicio.marcarRefresco();
      b.servicio.actualizarLibros({l1});
      b.abrir();
      await b.pasar(t, const Duration(seconds: 5));
      b.servicio.alVolver();
      await b.pasar(t, Duration.zero);
      expect(b.recargas, 0, reason: 'hace 5 s que se cargó');
      await b.pasar(t, const Duration(seconds: 6));
      b.servicio.alVolver();
      await b.pasar(t, Duration.zero);
      expect(b.recargas, 1);
      b.servicio.alVolver();
      await b.pasar(t, Duration.zero);
      expect(b.recargas, 1, reason: 'el refresco recién hecho cuenta');
      b.servicio.liberar();
    });

    testWidgets('al reconectar el canal recarga (con el mismo mínimo)', (t) async {
      final b = Banco()..servicio.marcarRefresco();
      b.servicio.actualizarLibros({l1});
      b.abrir();
      await b.pasar(t, const Duration(seconds: 30));
      b.fuente.reconectado();
      await b.pasar(t, Duration.zero);
      expect(b.recargas, 1);
      // Varios canales reconectan casi a la vez: una sola recarga.
      b.fuente.reconectado();
      b.fuente.reconectado();
      await b.pasar(t, const Duration(seconds: 1));
      expect(b.recargas, 1);
      b.servicio.liberar();
    });

    testWidgets('Actualizar a mano siempre recarga, sin esperar los 10 s', (
      t,
    ) async {
      final b = Banco()..servicio.marcarRefresco();
      b.servicio.actualizarLibros({l1});
      b.abrir();
      await b.servicio.actualizarAhora();
      await b.servicio.actualizarAhora();
      expect(b.recargas, 2);
      b.servicio.liberar();
    });

    testWidgets('sin temporizador periódico: quieto, no recarga nunca', (t) async {
      final b = Banco()..servicio.marcarRefresco();
      b.servicio.actualizarLibros({l1});
      b.abrir();
      await b.pasar(t, const Duration(minutes: 30));
      expect(b.recargas, 0);
      b.servicio.liberar();
    });
  });

  group('Servicio: suscripciones', () {
    testWidgets('solo se vuelve a suscribir si cambian los libros', (t) async {
      final b = Banco()..servicio.marcarRefresco();
      b.servicio.actualizarLibros({l1});
      b.abrir();
      b.servicio.actualizarLibros({l1});
      expect(b.fuente.pedidos, hasLength(1));
      b.servicio.actualizarLibros({l1, 'libro-2'});
      expect(b.fuente.pedidos, hasLength(2));
      expect(b.fuente.cancelaciones, 1);
      b.servicio.actualizarLibros({});
      expect(b.fuente.cancelaciones, 2, reason: 'sin libros no se escucha');
      b.servicio.liberar();
    });

    testWidgets('cerrado el módulo, los avisos ya no recargan', (t) async {
      final b = Banco()..servicio.marcarRefresco();
      b.servicio.actualizarLibros({l1});
      b.abrir();
      final control = b.fuente;
      b.servicio.cerrar();
      await b.pasar(t, Duration.zero);
      expect(b.servicio.activo, isFalse);
      expect(control.escuchando, isFalse);
      await b.pasar(t, const Duration(seconds: 5));
      expect(b.recargas, 0);
    });

    testWidgets('cambiar de sección (sale una pantalla, entra otra) no suelta el canal', (
      t,
    ) async {
      final b = Banco()..servicio.marcarRefresco();
      b.servicio.actualizarLibros({l1});
      b.abrir();
      b.servicio.cerrar();
      b.abrir();
      await b.pasar(t, Duration.zero);
      expect(b.servicio.activo, isTrue);
      expect(b.fuente.pedidos, hasLength(1));
      expect(b.fuente.cancelaciones, 0);
      b.servicio.liberar();
    });

    testWidgets('sin servidor (demostración) solo funcionan entrar, volver y manual', (
      t,
    ) async {
      final b = Banco(conFuente: false);
      b.servicio.actualizarLibros({l1});
      b.abrir();
      await b.pasar(t, Duration.zero);
      expect(b.recargas, 1);
      b.servicio.liberar();
    });
  });

  group('Anfitrión (pantallas)', () {
    Future<Banco> montar(WidgetTester t, {Widget? hijo}) async {
      final b = Banco()..servicio.marcarRefresco();
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            sincroniaFinanzasProvider.overrideWithValue(b.servicio),
            librosParaSincroniaProvider.overrideWithValue({l1}),
          ],
          child: MaterialApp(
            home: AnfitrionSincroniaFinanzas(
              child: Builder(
                builder: (context) => Scaffold(
                  body: hijo ?? const Text('Finanzas'),
                  floatingActionButton: FloatingActionButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const AlertDialog(content: Text('Hoja')),
                    ),
                    child: const Icon(Icons.add),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      return b;
    }

    testWidgets('al montarse abre el servicio con los libros de la persona; al salir lo cierra', (
      t,
    ) async {
      final b = await montar(t);
      expect(b.servicio.activo, isTrue);
      expect(b.servicio.libros, {l1});
      expect(b.fuente.pedidos.single, {l1});
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(milliseconds: 1));
      expect(b.servicio.activo, isFalse);
    });

    testWidgets('al volver de segundo plano pide de nuevo (pasados 10 s)', (
      t,
    ) async {
      final b = await montar(t);
      await b.pasar(t, const Duration(seconds: 20));
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      expect(b.recargas, 1);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(milliseconds: 1));
    });

    testWidgets('con un diálogo abierto el aviso espera; al cerrarlo recarga', (
      t,
    ) async {
      final b = await montar(t);
      await t.tap(find.byType(FloatingActionButton));
      await t.pumpAndSettle();
      expect(find.text('Hoja'), findsOneWidget);
      b.fuente.cambio(l1);
      await b.pasar(t, const Duration(seconds: 3));
      expect(b.recargas, 0, reason: 'no pisa la hoja abierta');
      Navigator.of(t.element(find.text('Hoja'))).pop();
      await t.pumpAndSettle();
      await b.pasar(t, const Duration(seconds: 2));
      expect(b.recargas, 1);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(milliseconds: 1));
    });

    testWidgets('el botón Actualizar y F5 recargan; con un diálogo abierto, F5 no', (
      t,
    ) async {
      final b = await montar(t, hijo: const BotonActualizarFinanzas());
      await t.tap(find.byKey(const ValueKey('finanzas-actualizar')));
      await t.pump();
      expect(b.recargas, 1);
      await t.sendKeyEvent(LogicalKeyboardKey.f5);
      await t.pump();
      expect(b.recargas, 2);
      await t.tap(find.byType(FloatingActionButton));
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.f5);
      await t.pump();
      expect(b.recargas, 2, reason: 'hoja abierta: no pisa lo que se edita');
      Navigator.of(t.element(find.text('Hoja'))).pop();
      await t.pumpAndSettle();
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(milliseconds: 1));
    });
  });

  group('Estado: recargar en segundo plano', () {
    const hogar = '00000000-0000-4000-8000-0000000000aa';
    final dueno = sesionDe(Rol.dueno);
    late FuenteTablasEnMemoria memoria;
    late BaseLocal base;
    late ColaSinConexion cola;
    late RepositorioFinanzasSupabase repo;
    late ProviderContainer contenedor;
    final llamadasSincronia = <String>[];

    setUp(() {
      llamadasSincronia.clear();
      memoria = FuenteTablasEnMemoria();
      sembrar(memoria, datosDeDemostracion(hoy: hoyDePrueba), hogar: hogar);
      base = BaseLocal.enMemoria();
      // Sin señal para subir: lo que se registra se queda en la cola.
      cola = ColaSinConexion(base: base, enviador: _EnviadorSinSenal());
      repo = RepositorioFinanzasSupabase(
        fuente: memoria,
        cola: cola,
        hogarId: hogar,
        personaId: dueno.persona.id,
        esperaSubida: const Duration(milliseconds: 50),
      );
      final servicio = ServicioSincroniaFinanzas(
        fuente: null,
        recargar: () async {},
      );
      contenedor = ProviderContainer(
        overrides: [
          repositorioFinanzasProvider.overrideWithValue(repo),
          sincroniaFinanzasProvider.overrideWithValue(servicio),
        ],
      );
      addTearDown(() async {
        contenedor.dispose();
        await repo.cerrar();
        await base.close();
      });
    });

    test('lo que está en la cola sigue visible tras recargar', () async {
      final carga = contenedor.read(cargaFinanzasProvider.notifier);
      await contenedor.read(cargaFinanzasProvider.future);
      final servicio = servicioDe(repo, dueno);
      final r = await servicio.registrarGasto(
        libroId: IdsDemostracion.libroDueno,
        cuentaOrigenId:
            memoria
                    .tabla(TablasFinanzas.cuentas)
                    .firstWhere((c) => c['nombre'] == 'Mi efectivo')['id']!
                as String,
        lineas: const [LineaGasto(monto: 4321)],
      );
      expect(r.enCola, isTrue, reason: 'sin señal queda en la cola');
      final id = r.movimientos.single.id;
      await carga.recargarEnSegundoPlano();
      final datos = contenedor.read(cargaFinanzasProvider).requireValue;
      expect(datos.movimientosEnCola, contains(id));
      expect(datos.datos.movimientos.any((m) => m.id == id), isTrue);
    });

    test('si el servidor falla, se queda con lo último cargado', () async {
      final carga = contenedor.read(cargaFinanzasProvider.notifier);
      final antes = await contenedor.read(cargaFinanzasProvider.future);
      memoria.sinSenal = true;
      await carga.recargarEnSegundoPlano();
      final estado = contenedor.read(cargaFinanzasProvider);
      expect(estado.hasError, isFalse, reason: 'sin pantalla de error');
      expect(estado.requireValue.datos.movimientos, hasLength(antes.datos.movimientos.length));
    });

    test('la carga inicial cuenta como refresco (no se recarga al abrir)', () async {
      final servicio = ServicioSincroniaFinanzas(
        fuente: null,
        recargar: () async => llamadasSincronia.add('recarga'),
      );
      final c = ProviderContainer(
        overrides: [
          repositorioFinanzasProvider.overrideWithValue(repo),
          sincroniaFinanzasProvider.overrideWithValue(servicio),
        ],
      );
      addTearDown(c.dispose);
      await c.read(cargaFinanzasProvider.future);
      servicio.abrir(hojaAbierta: () => false);
      await Future<void>.delayed(Duration.zero);
      expect(llamadasSincronia, isEmpty);
      servicio.liberar();
    });
  });
}

class _EnviadorSinSenal implements Enviador {
  @override
  Future<ResultadoEnvio> enviar(PeticionEnvio peticion) async =>
      ResultadoEnvio.reintentar;
}
