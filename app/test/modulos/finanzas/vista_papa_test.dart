import 'dart:io';

// D24, criterios 1, 3, 4 y 6 de docs/specs/fase-4-vista-temporal.md: sin
// autorización no hay nada de Papá; con ella, 30 minutos exactos de solo
// lectura (sin copiar, seleccionar, exportar ni compartir y con captura
// bloqueada); el dueño la cancela; sus textos son del catálogo discreto.
// Datos de ejemplo inventados; el reloj es simulado.
import 'package:finanzas_dominio/finanzas_dominio.dart'
    show motivoValido, Fecha;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/sesion_efectiva.dart';
import 'package:gravity/diseno/diseno.dart' show formatearCentavos;
import 'package:gravity/diseno/proveedores.dart'
    show Reloj, montosOcultosProvider, relojProvider;
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/modulos/finanzas/datos/vista_papa.dart';
import 'package:gravity/modulos/finanzas/estado/proveedores_vista_papa.dart';
import 'package:gravity/modulos/finanzas/pantallas/vista_papa/pedir_vista_papa.dart';
import 'package:gravity/modulos/finanzas/pantallas/vista_papa/tarjeta_vista_papa_dueno.dart';
import 'package:gravity/nucleo/avisos/catalogo_avisos.dart'
    show largoMaximoTituloAviso, titulosDeAviso;
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart'
    show AlmacenSeguroEnMemoria;
import 'package:gravity/nucleo/seguridad/pantalla_segura.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart'
    show almacenSeguroProvider;
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';

import '../../nucleo/seguridad/pantalla_segura_test.dart'
    show ProtectorRegistrador;

/// Reloj que la prueba adelanta a mano.
class RelojSimulado implements Reloj {
  RelojSimulado(this._ahora);
  DateTime _ahora;

  @override
  DateTime ahora() => _ahora;

  void avanzar(Duration d) => _ahora = _ahora.add(d);
}

final _inicio = DateTime(2026, 11, 6, 10);
final _duenoId = IdsDemostracion.dueno;
final _familiarId = personasDeEjemplo[Rol.familiar]!.id;

void main() {
  guardiaCopiaLocalVistaPapa();
  late RelojSimulado reloj;
  late RepositorioVistaPapaEnMemoria servidor;
  late ProtectorRegistrador protector;

  setUp(() {
    reloj = RelojSimulado(_inicio);
    protector = ProtectorRegistrador();
    servidor = RepositorioVistaPapaEnMemoria(
      personaId: _duenoId,
      duenoId: _duenoId,
      reloj: reloj.ahora,
      datosPapa: datosDeLibros(
        datosDeDemostracion(hoy: Fecha.deDateTime(_inicio)),
        {IdsDemostracion.libroPapa},
        conservarLibros: false,
      ),
    );
  });

  Future<ProviderContainer> monta(
    WidgetTester t,
    Rol rol,
    Widget pantalla,
  ) async {
    final repo = servidor.comoPersona(
      rol == Rol.dueno ? _duenoId : _familiarId,
    );
    final c = ProviderContainer(
      overrides: [
        sesionEfectivaProvider.overrideWithValue(sesionDeEjemplo(rol)),
        repositorioVistaPapaProvider.overrideWithValue(repo),
        relojProvider.overrideWithValue(reloj),
        montosOcultosProvider.overrideWithValue(false),
        protectorDePantallaProvider.overrideWithValue(protector),
        almacenSeguroProvider.overrideWithValue(AlmacenSeguroEnMemoria()),
      ],
    );
    addTearDown(c.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(home: Scaffold(body: pantalla)),
      ),
    );
    await t.pumpAndSettle();
    return c;
  }

  /// Adelanta el reloj simulado y deja correr los temporizadores de la pantalla.
  Future<void> pasa(WidgetTester t, Duration d) async {
    reloj.avanzar(d);
    await t.pump(d);
    await t.pump();
    await t.pump();
  }

  Finder campoMotivo() => find.byKey(const ValueKey('vista-papa-motivo'));
  Finder botonPedir() => find.byKey(const ValueKey('vista-papa-pedir'));

  Future<void> pideComoFamiliar(WidgetTester t) async {
    await t.enterText(campoMotivo(), 'Revisar los pagos de la luz');
    await t.pump();
    await t.tap(botonPedir());
    await t.pumpAndSettle();
  }

  String montoDePapa() {
    // Un saldo real de la cuenta de Papá: no debe verse sin autorización.
    final datos = datosDeDemostracion(hoy: Fecha.deDateTime(_inicio));
    final c = datos.cuentas.firstWhere(
      (c) =>
          c.libroId == IdsDemostracion.libroPapa &&
          c.nombre.contains('pensión'),
    );
    return formatearCentavos(
      datos
          .vista(IdsDemostracion.libroPapa)
          .saldo(c.id, incluirPendientes: true),
    );
  }

  group('pedir la vista (familiar)', () {
    testWidgets('el motivo usa el mismo criterio que motivoValido', (t) async {
      await monta(t, Rol.familiar, const PantallaPedirVistaPapa());
      for (final texto in ['ab', '  a ', '...', 'aaa', '']) {
        await t.enterText(campoMotivo(), texto);
        await t.pump();
        expect(
          t.widget<FilledButton>(botonPedir()).onPressed,
          isNull,
          reason: '"$texto" no es un motivo válido',
        );
        expect(motivoValido(texto), isFalse);
      }
      await t.enterText(campoMotivo(), 'Pagos de luz');
      await t.pump();
      expect(t.widget<FilledButton>(botonPedir()).onPressed, isNotNull);
    });

    testWidgets('al pedir queda pendiente y no se ve nada de Papá (crit. 1)', (
      t,
    ) async {
      await monta(t, Rol.familiar, const PantallaPedirVistaPapa());
      await pideComoFamiliar(t);
      expect(
        find.byKey(const ValueKey('vista-papa-pendiente')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('vista-papa-contador')), findsNothing);
      expect(find.textContaining(montoDePapa()), findsNothing);
      expect(find.textContaining('Papá (ejemplo)'), findsNothing);
      expect(protector.cambios, isEmpty, reason: 'sin vista no se bloquea');
    });

    testWidgets('rechazada: se puede pedir otra vez y sigue sin ver nada', (
      t,
    ) async {
      await monta(t, Rol.familiar, const PantallaPedirVistaPapa());
      await pideComoFamiliar(t);
      final id = (await servidor.listar()).single.id;
      await servidor.responder(id, AccionVista.rechazar);
      await pasa(t, const Duration(seconds: 3));
      expect(find.byKey(const ValueKey('vista-papa-aviso')), findsOneWidget);
      expect(botonPedir(), findsOneWidget);
      expect(find.textContaining(montoDePapa()), findsNothing);
    });

    testWidgets('el familiar puede cancelar su solicitud pendiente', (t) async {
      await monta(t, Rol.familiar, const PantallaPedirVistaPapa());
      await pideComoFamiliar(t);
      await t.tap(find.byKey(const ValueKey('vista-papa-cancelar-pedido')));
      await t.pumpAndSettle();
      expect((await servidor.listar()).single.estado, EstadoVista.cancelada);
      expect(botonPedir(), findsOneWidget);
    });
  });

  group('vista temporal (crit. 2, 3 y 4)', () {
    Future<String> autorizada(WidgetTester t) async {
      await monta(t, Rol.familiar, const PantallaPedirVistaPapa());
      await pideComoFamiliar(t);
      final id = (await servidor.listar()).single.id;
      await servidor.responder(id, AccionVista.autorizar);
      await pasa(t, const Duration(seconds: 3));
      return id;
    }

    testWidgets('autorizada: contador de 30 min y cifras de solo lectura', (
      t,
    ) async {
      await autorizada(t);
      expect(find.byKey(const ValueKey('vista-papa-contador')), findsOneWidget);
      // Pasaron 3 s desde que se autorizó.
      expect(
        t.widget<Text>(find.byKey(const ValueKey('vista-papa-contador'))).data,
        '29:57',
      );
      expect(find.byKey(const ValueKey('vista-papa-titulo')), findsOneWidget);
      expect(find.textContaining(montoDePapa()), findsWidgets);
      // Captura bloqueada mientras dura.
      await t.pump();
      expect(protector.segura, isTrue);
    });

    testWidgets('no se puede copiar, seleccionar, exportar ni compartir', (
      t,
    ) async {
      await autorizada(t);
      expect(find.byType(SelectableText), findsNothing);
      expect(find.byType(SelectionArea), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byType(PopupMenuButton), findsNothing);
      for (final palabra in [
        'Copiar',
        'Exportar',
        'Compartir',
        'Descargar',
        'Imprimir',
      ]) {
        expect(find.textContaining(palabra), findsNothing, reason: palabra);
      }
      for (final w in t.widgetList<Tooltip>(find.byType(Tooltip))) {
        expect(
          w.message,
          isNot(matches(RegExp('copiar|export|compart', caseSensitive: false))),
        );
      }
      // La selección está apagada para todo lo que hay dentro.
      expect(find.byType(SelectionContainer), findsWidgets);
    });

    testWidgets('dura 30 min exactos y luego se cierra sola (crit. 2)', (
      t,
    ) async {
      await autorizada(t);
      await pasa(t, const Duration(minutes: 10));
      expect(
        t.widget<Text>(find.byKey(const ValueKey('vista-papa-contador'))).data,
        '19:57',
      );
      // Un segundo antes del final sigue abierta.
      await pasa(t, const Duration(minutes: 19, seconds: 56));
      expect(find.byKey(const ValueKey('vista-papa-contador')), findsOneWidget);
      expect(find.textContaining(montoDePapa()), findsWidgets);
      // Al segundo siguiente, cerrada: sin cifras, sin contador, sin bloqueo.
      await pasa(t, const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('vista-papa-contador')), findsNothing);
      expect(find.textContaining(montoDePapa()), findsNothing);
      expect(find.byKey(const ValueKey('vista-papa-aviso')), findsOneWidget);
      expect(protector.segura, isFalse);
    });

    testWidgets(
      'si el dueño la cancela, se cierra en pocos segundos (crit. 4)',
      (t) async {
        final id = await autorizada(t);
        await pasa(t, const Duration(minutes: 5));
        expect(find.textContaining(montoDePapa()), findsWidgets);
        await servidor
            .comoPersona(_duenoId)
            .responder(id, AccionVista.cancelar);
        await pasa(t, const Duration(seconds: 4));
        expect(find.byKey(const ValueKey('vista-papa-contador')), findsNothing);
        expect(find.textContaining(montoDePapa()), findsNothing);
        expect(protector.segura, isFalse);
        expect(await servidor.comoPersona(_familiarId).vigente(), isFalse);
        expect(await servidor.comoPersona(_familiarId).leerVista(), isNull);
      },
    );
  });

  group('lado del dueño (crit. 4 y 6)', () {
    Future<void> pideElFamiliar() async {
      await servidor
          .comoPersona(_familiarId)
          .pedir('Revisar los pagos de la luz');
    }

    testWidgets('autorizar 30 min y luego cancelar una vigente', (t) async {
      await pideElFamiliar();
      await monta(t, Rol.dueno, const TarjetaVistaPapaDueno());
      final id = (await servidor.listar()).single.id;
      expect(find.text('Solicitud de vista: Familiar'), findsOneWidget);

      await t.tap(find.byKey(ValueKey('vista-papa-autorizar-$id')));
      await t.pumpAndSettle();
      final s = (await servidor.listar()).single;
      expect(s.estado, EstadoVista.autorizada);
      expect(s.vigenteHasta, _inicio.add(const Duration(minutes: 30)));
      expect(find.text('Quedan 30:00'), findsOneWidget);

      await t.tap(find.byKey(ValueKey('vista-papa-cancelar-$id')));
      await t.pumpAndSettle();
      expect((await servidor.listar()).single.estado, EstadoVista.cancelada);
      expect(
        find.byKey(const ValueKey('vista-papa-tarjeta-dueno')),
        findsNothing,
      );
    });

    testWidgets('rechazar cierra la solicitud', (t) async {
      await pideElFamiliar();
      await monta(t, Rol.dueno, const TarjetaVistaPapaDueno());
      final id = (await servidor.listar()).single.id;
      await t.tap(find.byKey(ValueKey('vista-papa-rechazar-$id')));
      await t.pumpAndSettle();
      expect((await servidor.listar()).single.estado, EstadoVista.rechazada);
    });

    testWidgets('el aviso no lleva montos, cuentas ni nombres (crit. 6)', (
      t,
    ) async {
      await pideElFamiliar();
      await monta(t, Rol.dueno, const TarjetaVistaPapaDueno());
      final textos = t
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('vista-papa-tarjeta-dueno')),
              matching: find.byType(Text),
            ),
          )
          .map((w) => w.data ?? '')
          .join(' | ');
      expect(textos, isNot(contains(r'$')));
      expect(textos, isNot(contains(montoDePapa())));
      expect(textos, isNot(contains('Papá (ejemplo)')));
      expect(textos, isNot(contains('Cuenta de la pensión')));
      // Todos los textos del catálogo: cortos, sin dígitos, sin "$".
      expect(find.text(titulosDeAviso['solicitud_vista']!), findsOneWidget);
      for (final titulo in [
        ...textosVistaPapa.values,
        titulosDeAviso['solicitud_vista']!,
      ]) {
        expect(titulo.length, lessThanOrEqualTo(largoMaximoTituloAviso));
        expect(titulo, isNot(matches(RegExp(r'[0-9$]'))));
      }
    });

    testWidgets('la tarjeta no existe para quien no es el dueño', (t) async {
      await pideElFamiliar();
      await monta(t, Rol.coadministrador, const TarjetaVistaPapaDueno());
      expect(
        find.byKey(const ValueKey('vista-papa-tarjeta-dueno')),
        findsNothing,
      );
    });
  });

  group('repositorio en memoria (espejo del servidor)', () {
    test(
      'solo el dueño autoriza; el familiar no lee sin autorización',
      () async {
        final f = servidor.comoPersona(_familiarId);
        final id = await f.pedir('Revisar pagos');
        expect(() => f.responder(id, AccionVista.autorizar), throwsA(anything));
        expect(await f.leerVista(), isNull);
        expect(await f.vigente(), isFalse);
        await servidor.responder(id, AccionVista.autorizar);
        expect(await f.vigente(), isTrue);
        expect(await f.leerVista(), isNotNull);
        reloj.avanzar(const Duration(minutes: 30));
        expect(await f.vigente(), isFalse);
        expect(await f.leerVista(), isNull);
      },
    );

    test('un motivo corto no se envía', () async {
      expect(
        () => servidor.comoPersona(_familiarId).pedir('ab'),
        throwsA(anything),
      );
    });
  });
}

// Guardia (D24): la vista temporal de Papá no deja copia local. Si alguien
// vuelve a usar cargar() en esa ruta, las cifras de Papá quedarían guardadas
// después de los 30 minutos.
void guardiaCopiaLocalVistaPapa() {
  test('la vista de Papá carga sin persistir (D24)', () {
    final fuente = File(
      'lib/modulos/finanzas/estado/proveedores_vista_papa.dart',
    ).readAsStringSync();
    expect(fuente, contains('cargarSinPersistir()'));
    expect(fuente, isNot(contains('.cargar()')));
  });
}
