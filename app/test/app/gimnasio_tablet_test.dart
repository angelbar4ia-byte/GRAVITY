// PG-17 y CA-G-38: una sesión de gimnasio en curso RETIENE la tablet 10 minutos
// desde el último toque (en vez de 2); pasados, vuelve al reposo (modo Casa en
// la pública, bloqueo en la personal) y la sesión queda guardada como en_curso
// para retomarla con el PIN. Cada toque reinicia la cuenta. La retención es de
// esa persona y de esa sesión: al volver al reposo se acaba.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/app/gimnasio/proveedores_gimnasio.dart'
    show
        sesionGimnasioEnCursoProvider,
        retencionSesionGimnasio,
        tiempoSinUsoDeLaTablet;
import 'package:gravity/nucleo/gimnasio/repositorio_gimnasio.dart';
import 'package:gravity/nucleo/base_local/base_local.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart'
    show sesionDeEjemplo;
import 'package:gravity/nucleo/tablet/controlador_tablet.dart';
import 'package:gravity/nucleo/tablet/usuarios_tablet.dart';

import '../nucleo/gimnasio/ayuda_gimnasio.dart' as ej;
import 'ayuda_plataforma.dart';

const nombreDueno = 'Dueño de ejemplo';

ProviderContainer contenedor(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AppGravity)));

EstadoTablet estado(WidgetTester tester) =>
    contenedor(tester).read(controladorTabletProvider);

String get duenoId => sesionDeEjemplo(Rol.dueno).persona.id;

Future<void> entrar(WidgetTester tester, {required bool personal}) async {
  await montarApp(
    tester,
    dispositivo: TipoDispositivo.tablet,
    sesion: sesionCon(Rol.casa),
    almacen: await almacenConPersonas(
      {Rol.dueno: '246813'},
      configuracion: personal
          ? ConfiguracionTablet(
              tipo: TipoTablet.personal,
              permitidas: {duenoId},
            )
          : null,
    ),
  );
  await tester.tap(find.text(nombreDueno));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('campo-pin')), '246813');
  await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
  await tester.pumpAndSettle();
  expect(estado(tester).usuarioActivo, isNotNull);
}

void iniciarSesion(WidgetTester tester) =>
    contenedor(tester)
        .read(sesionGimnasioEnCursoProvider.notifier)
        .iniciar(duenoId);

/// Un toque en un rincón de la pantalla.
Future<void> tocar(WidgetTester tester) async {
  await tester.tapAt(const Offset(3, 3));
  await tester.pump();
}

void main() {
  group('tiempoSinUsoDeLaTablet (función pura)', () {
    const dosMinutos = Duration(minutes: 2);

    test('sin sesión en curso, el de la tablet', () {
      expect(
        tiempoSinUsoDeLaTablet(base: dosMinutos, sesionGimnasioEnCurso: false),
        dosMinutos,
      );
    });

    test('con sesión en curso, 10 minutos', () {
      expect(retencionSesionGimnasio, const Duration(minutes: 10));
      expect(
        tiempoSinUsoDeLaTablet(base: dosMinutos, sesionGimnasioEnCurso: true),
        const Duration(minutes: 10),
      );
    });

    test(
      'nunca menos que lo configurado: si la tablet espera más, se respeta',
      () {
        expect(
          tiempoSinUsoDeLaTablet(
            base: const Duration(minutes: 15),
            sesionGimnasioEnCurso: true,
          ),
          const Duration(minutes: 15),
        );
      },
    );
  });

  group('tablet pública', () {
    testWidgets('control: sin sesión, a los 2 minutos vuelve al modo Casa', (
      tester,
    ) async {
      await entrar(tester, personal: false);
      await tester.pump(const Duration(minutes: 2, seconds: 1));
      await tester.pumpAndSettle();
      expect(estado(tester).usuarioActivo, isNull);
      expect(find.text('GRAVITY · Casa'), findsOneWidget);
    });

    testWidgets(
      'con sesión en curso: sigue dentro a los 9 min 59 s y vuelve a Casa a los 10',
      (tester) async {
        await entrar(tester, personal: false);
        iniciarSesion(tester);
        await tester.pump();
        await tester.pump(const Duration(minutes: 3));
        expect(
          estado(tester).usuarioActivo,
          isNotNull,
          reason: 'a los 3 min sigue',
        );
        await tester.pump(const Duration(minutes: 6, seconds: 58));
        expect(
          estado(tester).usuarioActivo,
          isNotNull,
          reason: 'a los 9 min 58 s sigue',
        );
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(
          estado(tester).usuarioActivo,
          isNull,
          reason: 'pasados los 10 min vuelve',
        );
        expect(find.text('GRAVITY · Casa'), findsOneWidget);
        // La retención se acabó con la persona.
        expect(contenedor(tester).read(sesionGimnasioEnCursoProvider), isNull);
      },
    );

    testWidgets('cada toque reinicia la cuenta de los 10 minutos', (
      tester,
    ) async {
      await entrar(tester, personal: false);
      iniciarSesion(tester);
      await tester.pump();
      await tester.pump(const Duration(minutes: 9));
      await tocar(tester);
      await tester.pump(const Duration(minutes: 9));
      expect(
        estado(tester).usuarioActivo,
        isNotNull,
        reason: '9 min después del toque',
      );
      await tocar(tester);
      await tester.pump(const Duration(minutes: 9, seconds: 59));
      expect(estado(tester).usuarioActivo, isNotNull);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(estado(tester).usuarioActivo, isNull);
    });

    testWidgets('terminar la sesión devuelve los 2 minutos de siempre', (
      tester,
    ) async {
      await entrar(tester, personal: false);
      iniciarSesion(tester);
      await tester.pump();
      await tester.pump(const Duration(minutes: 5));
      contenedor(tester)
          .read(sesionGimnasioEnCursoProvider.notifier)
          .terminar();
      await tester.pump(); // el cambio de tiempo cuenta como uso
      await tester.pump(const Duration(minutes: 1, seconds: 50));
      expect(estado(tester).usuarioActivo, isNotNull);
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(estado(tester).usuarioActivo, isNull);
    });

    testWidgets(
      'al volver al reposo a mano la retención se acaba; al volver a entrar valen 2 minutos',
      (tester) async {
        await entrar(tester, personal: false);
        iniciarSesion(tester);
        await tester.pump();
        contenedor(tester)
            .read(controladorTabletProvider.notifier)
            .volverAlReposo();
        await tester.pumpAndSettle();
        expect(contenedor(tester).read(sesionGimnasioEnCursoProvider), isNull);
        await tester.tap(find.text(nombreDueno));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('campo-pin')), '246813');
        await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(minutes: 2, seconds: 1));
        await tester.pumpAndSettle();
        expect(estado(tester).usuarioActivo, isNull);
      },
    );

    testWidgets(
      'la sesión queda guardada como en_curso para retomarla con el PIN',
      (tester) async {
        final base = BaseLocal.enMemoria();
        addTearDown(base.close);
        await montarApp(
          tester,
          dispositivo: TipoDispositivo.tablet,
          sesion: sesionCon(Rol.casa),
          base: base,
          almacen: await almacenConPersonas({Rol.dueno: '246813'}),
        );
        await tester.tap(find.text(nombreDueno));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('campo-pin')), '246813');
        await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
        await tester.pumpAndSettle();

        // Local primero: al empezar la sesión se guarda en curso. (Sin la cola de
        // la app: sus oyentes de la interfaz consultan la misma base desde la
        // zona falsa de la prueba y la dejarían esperando.)
        final repo = RepositorioGimnasio(base);
        final id = IdsDe.sesion(duenoId);
        await tester.runAsync(
          () => repo.guardarSesion(duenoId, ej.sesion(p: duenoId)),
        );
        iniciarSesion(tester);
        await tester.pump();
        await tester.pump(const Duration(minutes: 10, seconds: 1));
        await tester.pumpAndSettle();
        expect(estado(tester).usuarioActivo, isNull, reason: 'volvió a Casa');
        final enCurso = await tester.runAsync(
          () => repo.sesionEnCurso(duenoId),
        );
        expect(enCurso, isNotNull);
        expect(enCurso!.id, id);
        expect(enCurso.estado, 'en_curso');
      },
    );
  });

  group('tablet personal', () {
    testWidgets(
      'la sesión también la retiene: bloqueo a los 10 minutos, no a los 2',
      (tester) async {
        await entrar(tester, personal: true);
        iniciarSesion(tester);
        await tester.pump();
        await tester.pump(const Duration(minutes: 5));
        expect(estado(tester).usuarioActivo, isNotNull);
        await tester.pump(const Duration(minutes: 5, seconds: 2));
        await tester.pumpAndSettle();
        expect(estado(tester).usuarioActivo, isNull);
        expect(
          find.byKey(const ValueKey('bloqueo-tablet-personal')),
          findsOneWidget,
        );
      },
    );
  });
}

/// El id de la sesión de las pruebas para [persona].
abstract final class IdsDe {
  static String sesion(String persona) => ej.idSesion(p: persona);
}
