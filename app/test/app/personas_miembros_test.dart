// Ajustes › Personas › Personas del hogar (E3 de la Fase 4): invitar con un
// rol, cambiar el rol y dar de baja; tras una baja o un cambio de rol se vuelve
// a pedir lo de Finanzas.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/app/router.dart';
import 'package:gravity/modulos/finanzas/estado/proveedores.dart'
    show CargaFinanzasNotifier, cargaFinanzasProvider;
import 'package:gravity/modulos/finanzas/datos/repositorio.dart'
    show CargaFinanzas;
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/invitaciones/invitaciones.dart';
import 'package:gravity/nucleo/personas/personas_hogar.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';

import 'ayuda_plataforma.dart';

/// Cuenta cuántas veces se pidió recargar Finanzas.
class _CargaFalsa extends CargaFinanzasNotifier {
  static int recargas = 0;

  @override
  Future<CargaFinanzas> build() => Completer<CargaFinanzas>().future;

  @override
  Future<void> recargar() async => recargas++;
}

MiembroDelHogar _m(String id, String nombre, Rol rol, {bool maestra = false}) =>
    MiembroDelHogar(
      membresiaId: 'm-$id',
      personaId: id,
      nombre: nombre,
      rol: rol,
      esMaestra: maestra,
    );

Future<ProviderContainer> abrir(
  WidgetTester tester, {
  required RepositorioPersonasHogarEnMemoria personas,
  RepositorioInvitacionesEnMemoria? invitaciones,
}) async {
  _CargaFalsa.recargas = 0;
  await montarApp(
    tester,
    dispositivo: TipoDispositivo.laptop,
    sesion: sesionCon(Rol.dueno),
    extras: [
      repositorioPersonasHogarProvider.overrideWithValue(personas),
      repositorioInvitacionesProvider.overrideWithValue(
        invitaciones ??
            RepositorioInvitacionesEnMemoria(reloj: () => DateTime(2026, 11, 6)),
      ),
      cargaFinanzasProvider.overrideWith(_CargaFalsa.new),
    ],
  );
  final contenedor = ProviderScope.containerOf(
    tester.element(find.byType(AppGravity)),
  );
  // Finanzas ya estaba abierta: sin esto, "refrescar" no hace nada.
  contenedor.listen(cargaFinanzasProvider, (_, _) {});
  contenedor.read(routerProvider).go('/ajustes/personas');
  await tester.pumpAndSettle();
  return contenedor;
}

void main() {
  final dueno = personasDeEjemplo[Rol.dueno]!.id;

  RepositorioPersonasHogarEnMemoria repo() => RepositorioPersonasHogarEnMemoria(
    inicial: [
      _m(dueno, 'Ana', Rol.dueno),
      _m('luis', 'Luis', Rol.familiar),
      _m('mar', 'Mar', Rol.coadministrador, maestra: true),
    ],
    personaQueAdministra: dueno,
  );

  testWidgets('lista a las personas; el dueño no tiene opciones sobre sí', (
    tester,
  ) async {
    await abrir(tester, personas: repo());
    expect(find.byKey(const ValueKey('personas-del-hogar')), findsOneWidget);
    expect(find.text('Ana (tú)'), findsOneWidget);
    expect(find.text('Luis'), findsOneWidget);
    expect(find.text('Familiar'), findsWidgets);
    expect(find.text('Coadministrador · cuenta maestra'), findsOneWidget);
    expect(find.byKey(ValueKey('opciones-$dueno')), findsNothing);
    expect(find.byKey(const ValueKey('opciones-luis')), findsOneWidget);
  });

  testWidgets('dar de baja: pide confirmación, quita el acceso y recarga Finanzas', (
    tester,
  ) async {
    final personas = repo();
    await abrir(tester, personas: personas);
    await tester.tap(find.byKey(const ValueKey('opciones-luis')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dar de baja'));
    await tester.pumpAndSettle();
    // Cancelar no hace nada.
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(personas.bajas, isEmpty);
    expect(_CargaFalsa.recargas, 0);

    await tester.tap(find.byKey(const ValueKey('opciones-luis')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dar de baja'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirmar-baja')));
    await tester.pumpAndSettle();
    expect(personas.bajas, ['m-luis']);
    expect(find.text('Luis'), findsNothing);
    expect(_CargaFalsa.recargas, 1);
  });

  testWidgets('cambiar el rol: lo guarda y recarga Finanzas', (tester) async {
    final personas = repo();
    await abrir(tester, personas: personas);
    await tester.tap(find.byKey(const ValueKey('opciones-luis')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cambiar rol'));
    await tester.pumpAndSettle();
    // "Dueño" no se ofrece.
    expect(find.byKey(const ValueKey('rol-dueno')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('rol-cuidador')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('guardar-rol')));
    await tester.pumpAndSettle();
    expect(personas.cambios, [('m-luis', Rol.cuidador)]);
    expect(_CargaFalsa.recargas, 1);
    expect(find.text('Cuidador'), findsWidgets);
  });

  testWidgets('la cuenta maestra no ofrece cambiar de rol, solo la baja', (
    tester,
  ) async {
    await abrir(tester, personas: repo());
    await tester.tap(find.byKey(const ValueKey('opciones-mar')));
    await tester.pumpAndSettle();
    expect(find.text('Cambiar rol'), findsNothing);
    expect(find.text('Dar de baja'), findsOneWidget);
  });

  testWidgets('si el servidor no deja, lo dice y no pierde nada', (tester) async {
    final personas = repo()..sinConexion = false;
    await abrir(tester, personas: personas);
    personas.sinConexion = true;
    await tester.tap(find.byKey(const ValueKey('opciones-luis')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dar de baja'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirmar-baja')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sin conexión'), findsWidgets);
    expect(personas.bajas, isEmpty);
  });

  testWidgets('invitar a una persona con un rol: muestra el código una vez', (
    tester,
  ) async {
    final invitaciones = RepositorioInvitacionesEnMemoria(
      reloj: () => DateTime(2026, 11, 6),
    );
    await abrir(tester, personas: repo(), invitaciones: invitaciones);
    await tester.ensureVisible(find.byKey(const ValueKey('invitar-persona')));
    await tester.tap(find.byKey(const ValueKey('invitar-persona')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('correo-invitado')),
      'no-es-correo',
    );
    await tester.tap(find.byKey(const ValueKey('enviar-invitacion')));
    await tester.pumpAndSettle();
    expect(find.text('Escribe un correo válido.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('correo-invitado')),
      'cuidadora@ejemplo.test',
    );
    await tester.tap(find.byKey(const ValueKey('rol-invitado')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cuidador').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('enviar-invitacion')));
    await tester.pumpAndSettle();
    expect(find.text('Invitación creada'), findsOneWidget);
    expect(find.byKey(const ValueKey('codigo-invitacion')), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Listo'));
    await tester.pumpAndSettle();
    final pendientes = await invitaciones.pendientes('x');
    expect(pendientes.single.rol, 'cuidador');
    expect(pendientes.single.esMaestra, isFalse);
    expect(find.text('cuidadora@ejemplo.test'), findsOneWidget);
    expect(find.textContaining('Invitada como Cuidador'), findsOneWidget);
    expect(find.byKey(const ValueKey('codigo-invitacion')), findsNothing);
  });
}
