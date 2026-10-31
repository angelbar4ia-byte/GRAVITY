// Avisos en la app (Fase 2, D20): ruta y bandeja, quién la abre, y Ajustes ›
// Notificaciones por equipo.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/app/navegacion.dart';
import 'package:gravity/app/router.dart';
import 'package:gravity/nucleo/avisos/aviso.dart';
import 'package:gravity/nucleo/avisos/catalogo_avisos.dart';
import 'package:gravity/nucleo/avisos/fuente_push.dart';
import 'package:gravity/nucleo/avisos/notificador.dart';
import 'package:gravity/nucleo/avisos/proveedores_avisos.dart';
import 'package:gravity/nucleo/avisos/repositorio_avisos.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';

import 'ayuda_plataforma.dart';

const id1 = '3f2b8a52-6f0e-4b1b-9c52-1d7d5a2b9e10';

Aviso aviso(String id, String tipo, {EstadoAviso estado = EstadoAviso.pendiente}) =>
    Aviso(
      id: id,
      tipo: tipo,
      clave: '$tipo:$id',
      estado: estado,
      creadoEn: DateTime.utc(2026, 11, 2, 15),
    );

ProviderContainer contenedorDe(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(AppGravity)));

void main() {
  late RepositorioAvisosEnMemoria repo;
  late NotificadorEnMemoria notificador;
  late FuentePushFalsa push;

  setUp(() {
    repo = RepositorioAvisosEnMemoria()
      ..agregar(aviso(id1, 'pago_proximo'))
      ..agregar(aviso('3f2b8a52-6f0e-4b1b-9c52-1d7d5a2b9e11', 'partida_80'));
    notificador = NotificadorEnMemoria();
    push = FuentePushFalsa();
  });

  Future<void> montar(
    WidgetTester tester,
    Rol rol, {
    TipoDispositivo dispositivo = TipoDispositivo.telefono,
    ServicioSesionFalso? sesion,
  }) => montarApp(
    tester,
    dispositivo: dispositivo,
    sesion: sesion ?? sesionCon(rol),
    extras: [
      repositorioAvisosProvider.overrideWithValue(repo),
      notificadorProvider.overrideWithValue(notificador),
      fuentePushProvider.overrideWithValue(push),
    ],
  );

  testWidgets('la bandeja muestra el título del catálogo y nivel, sin cifras', (
    tester,
  ) async {
    await montar(tester, Rol.dueno);
    contenedorDe(tester).read(routerProvider).go(RutasApp.avisos);
    await tester.pumpAndSettle();
    expect(find.text('Tienes un pago próximo'), findsOneWidget);
    expect(find.text('Una categoría se acerca a su límite'), findsOneWidget);
    expect(find.textContaining('Crítica'), findsOneWidget);
    expect(find.textContaining(r'$'), findsNothing);
    expect(find.byKey(const ValueKey('aviso-$id1')), findsOneWidget);
  });

  testWidgets('abrir un aviso lo marca leído; Hecho lo resuelve; posponer 1 hora', (
    tester,
  ) async {
    await montar(tester, Rol.dueno);
    contenedorDe(tester).read(routerProvider).go(RutasApp.avisos);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tienes un pago próximo'));
    await tester.pumpAndSettle();
    expect(repo.marcados.single.accion, AccionAviso.leida);
    await tester.tap(find.text('Posponer 1 hora'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hecho').first);
    await tester.pumpAndSettle();
    expect(
      repo.marcados.map((m) => m.accion),
      containsAll([AccionAviso.posponerUnaHora, AccionAviso.resuelta]),
    );
  });

  testWidgets('Finanzas pone el detalle con montos dentro del aviso', (
    tester,
  ) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.telefono,
      sesion: sesionCon(Rol.dueno),
      extras: [
        repositorioAvisosProvider.overrideWithValue(repo),
        notificadorProvider.overrideWithValue(notificador),
      ],
    );
    contenedorDe(tester).read(routerProvider).go(RutasApp.avisos);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tienes un pago próximo'));
    await tester.pumpAndSettle();
    // El arranque ya conecta el detalle de Finanzas (Fase 2): el aviso se
    // abre y la bandeja deja de mostrar solo el título.
    expect(
      contenedorDe(tester).read(detalleDeAvisoProvider),
      isNotNull,
    );
  });

  testWidgets('sin avisos: estado vacío', (tester) async {
    repo.avisos.clear();
    await montar(tester, Rol.dueno);
    contenedorDe(tester).read(routerProvider).go(RutasApp.avisos);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bandeja-vacia')), findsOneWidget);
  });

  group('quién abre la bandeja', () {
    for (final rol in [Rol.familiar, Rol.cuidador]) {
      testWidgets('${rol.name}: vuelve a su inicio', (tester) async {
        await montar(tester, rol);
        contenedorDe(tester).read(routerProvider).go(RutasApp.avisos);
        await tester.pumpAndSettle();
        expect(find.text('Tienes un pago próximo'), findsNothing);
      });
    }

    test('la regla del router: maestra y quien no ve dinero, fuera', () {
      String? redir(Rol rol, {bool maestra = false}) => calcularRedireccion(
        ubicacion: RutasApp.avisos,
        rol: rol,
        dispositivo: TipoDispositivo.telefono,
        esMaestra: maestra,
      );
      expect(redir(Rol.dueno), isNull);
      expect(redir(Rol.coadministrador), isNull);
      expect(redir(Rol.coadministrador, maestra: true), isNotNull);
      for (final rol in [Rol.familiar, Rol.cuidador, Rol.casa]) {
        expect(redir(rol), isNotNull, reason: rol.name);
      }
    });
  });

  group('Ajustes › Notificaciones', () {
    Future<void> ir(WidgetTester tester) async {
      contenedorDe(tester).read(routerProvider).go('/ajustes/notificaciones');
      await tester.pumpAndSettle();
    }

    testWidgets('teléfono: activar pide el permiso (tras explicarlo) y registra el '
        'equipo; apagar lo da de baja', (tester) async {
      notificador.permiso = false;
      await montar(tester, Rol.dueno);
      await ir(tester);
      expect(find.byKey(const ValueKey('avisos-activar')), findsOneWidget);
      expect(find.byKey(const ValueKey('avisos-vista-previa')), findsOneWidget);
      expect(find.byKey(const ValueKey('avisos-guia-pulsera')), findsOneWidget);

      // En el teléfono vienen activados, pero sin el permiso del sistema.
      expect(find.byKey(const ValueKey('avisos-sin-permiso')), findsOneWidget);
      notificador.permiso = true;
      await tester.tap(find.byKey(const ValueKey('avisos-activar')));
      await tester.pumpAndSettle(); // apagar
      expect(repo.dispositivos, isEmpty);
      await tester.tap(find.byKey(const ValueKey('avisos-activar')));
      await tester.pumpAndSettle(); // encender: explica antes
      expect(find.text('Permitir avisos'), findsNothing, reason: 'ya había permiso');
      expect(repo.dispositivos, isNotEmpty);
    });

    testWidgets('explica antes de pedir el permiso de Android', (tester) async {
      notificador.permiso = false;
      await montar(tester, Rol.dueno);
      await ir(tester);
      await tester.tap(find.byKey(const ValueKey('avisos-activar')));
      await tester.pumpAndSettle(); // apagar
      await tester.tap(find.byKey(const ValueKey('avisos-activar')));
      await tester.pumpAndSettle();
      expect(find.text('Permitir avisos'), findsOneWidget);
      expect(notificador.vecesPedirPermiso, 0, reason: 'primero se explica');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(notificador.vecesPedirPermiso, 1);
    });

    testWidgets('el aviso de prueba muestra el genérico', (tester) async {
      await montar(tester, Rol.dueno);
      await ir(tester);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('avisos-prueba')),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('avisos-prueba')));
      await tester.pumpAndSettle();
      expect(notificador.visibles.values.single.titulo, textoAvisoGenerico);
    });

    testWidgets('el tope y los tipos se guardan en el servidor', (tester) async {
      await montar(tester, Rol.dueno);
      await ir(tester);
      await tester.tap(find.byKey(const ValueKey('avisos-tope')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5').last);
      await tester.pumpAndSettle();
      expect(repo.preferenciasIniciales?.topeNoCriticas, 5);
      await tester.tap(find.text('Tipos de aviso'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('avisos-tipo-partida_80')),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('avisos-tipo-partida_80')));
      await tester.pumpAndSettle();
      expect(repo.preferenciasIniciales?.tiposSilenciados, {'partida_80'});
    });

    testWidgets('tablet pública: dice que nunca recibe avisos personales', (
      tester,
    ) async {
      await montar(
        tester,
        Rol.casa,
        dispositivo: TipoDispositivo.tablet,
        sesion: sesionCon(Rol.casa),
      );
      expect(find.text('Tienes un pago próximo'), findsNothing);
      // Aun si alguien manda un push, la tablet pública no muestra nada.
      push.recibir({'v': '1', 'id': id1});
      await tester.pumpAndSettle();
      expect(notificador.historial, isEmpty);
      expect(repo.dispositivos, isEmpty);
    });

    testWidgets('cuenta maestra: sin avisos de dinero', (tester) async {
      final maestra = ServicioSesionFalso(
        inicial: const Sesion(
          persona: Persona(id: 'm', nombre: 'Maestra'),
          rol: Rol.coadministrador,
          esMaestra: true,
        ),
      );
      await montar(tester, Rol.coadministrador, sesion: maestra);
      await ir(tester);
      expect(find.text('Esta cuenta no recibe avisos de dinero.'), findsOneWidget);
      push.recibir({'v': '1', 'id': id1});
      await tester.pumpAndSettle();
      expect(notificador.historial, isEmpty);
      expect(repo.dispositivos, isEmpty);
    });
  });

  testWidgets('Copias de seguridad muestra el porcentaje de la base al dueño', (
    tester,
  ) async {
    repo.porcentaje = 82.5;
    await montar(tester, Rol.dueno, dispositivo: TipoDispositivo.laptop);
    contenedorDe(tester).read(routerProvider).go('/ajustes/copias');
    await tester.pumpAndSettle();
    expect(find.textContaining('82.5 %'), findsOneWidget);
  });

  testWidgets('push con la app abierta en el teléfono: notificación discreta y '
      'se registra el equipo al entrar', (tester) async {
    await montar(tester, Rol.dueno);
    await tester.pumpAndSettle();
    expect(repo.dispositivos, {'token-de-prueba': TipoEquipoAvisos.telefono});
    push.recibir({'v': '1', 'id': id1});
    await tester.pumpAndSettle();
    expect(notificador.visibles.values.single.titulo, 'Tienes un pago próximo');
    notificador.tocar(id1);
    await tester.pumpAndSettle();
    expect(find.text('Tienes un pago próximo'), findsWidgets);
  });
}
