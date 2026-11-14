// Ajustes › Hábitos › Nube cifrada (P5, E7 de la Fase 4): la pantalla.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/avisos/con_avisos.dart'
    show tipoEquipoAvisosProvider;
import 'package:gravity/app/sensibles/puerta_reservada.dart';
import 'package:gravity/app/sensibles/sensibles.dart';
import 'package:gravity/app/sesion_efectiva.dart';
import 'package:gravity/modulos/ajustes/habitos/pantalla_habitos_ajustes.dart';
import 'package:gravity/nucleo/avisos/repositorio_avisos.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart';
import 'package:gravity/nucleo/sensibles/llaves_habitos.dart';
import 'package:gravity/nucleo/sensibles/nube_habitos.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';

class _Abierto extends ReservadoAbierto {
  @override
  bool build() => true;
}

Future<ProviderContainer> montar(
  WidgetTester tester, {
  required Rol rol,
  TipoEquipoAvisos equipo = TipoEquipoAvisos.telefono,
  AdministracionNubeHabitosEnMemoria? servidor,
  bool maestra = false,
}) async {
  final List<Override> overrides = [
    sesionEfectivaProvider.overrideWithValue(
      Sesion(
        persona: const Persona(id: 'ana', nombre: 'Ana'),
        rol: rol,
        esMaestra: maestra,
      ),
    ),
    tipoEquipoAvisosProvider.overrideWithValue(equipo),
    almacenSeguroProvider.overrideWithValue(AlmacenSeguroEnMemoria()),
    servicioSesionProvider.overrideWithValue(ServicioSesionFalso.con(rol)),
    reservadoAbiertoProvider.overrideWith(_Abierto.new),
    if (servidor != null)
      administracionNubeHabitosProvider.overrideWithValue(servidor),
  ];
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const MaterialApp(home: Scaffold(body: PantallaHabitosAjustes())),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(PantallaHabitosAjustes)),
  );
}

void main() {
  final tarjeta = find.byKey(const ValueKey('ajustes-nube-cifrada'));

  testWidgets('no aparece para la maestra, el cuidador ni la tablet pública', (
    tester,
  ) async {
    await montar(tester, rol: Rol.dueno, maestra: true);
    expect(tarjeta, findsNothing);
    await montar(tester, rol: Rol.cuidador);
    expect(tarjeta, findsNothing);
    await montar(
      tester,
      rol: Rol.dueno,
      equipo: TipoEquipoAvisos.tabletPublica,
    );
    expect(tarjeta, findsNothing);
  });

  testWidgets('sin servidor lo dice y no ofrece nada', (tester) async {
    await montar(tester, rol: Rol.dueno);
    expect(tarjeta, findsOneWidget);
    expect(find.byKey(const ValueKey('nube-sin-servidor')), findsOneWidget);
    expect(find.byKey(const ValueKey('nube-activar')), findsNothing);
  });

  testWidgets('por omisión todo está solo en el equipo y nada se activa solo', (
    tester,
  ) async {
    final servidor = AdministracionNubeHabitosEnMemoria();
    await montar(tester, rol: Rol.familiar, servidor: servidor);
    expect(find.text('Solo en este equipo'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('nube-activar')), findsOneWidget);
    expect(find.byKey(const ValueKey('nube-anadir-equipo')), findsNothing);
    expect(find.byKey(const ValueKey('nube-reiniciar')), findsNothing);
    expect(servidor.llave, isNull);
  });

  testWidgets(
    'activar: frase, confirmación con 3 palabras y queda en la nube',
    (tester) async {
      final servidor = AdministracionNubeHabitosEnMemoria();
      final contenedor = await montar(
        tester,
        rol: Rol.dueno,
        servidor: servidor,
      );
      await tester.tap(find.byKey(const ValueKey('nube-activar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nube-elegir-continuar')));
      await tester.pumpAndSettle();
      // La frase se ve una vez, con las 12 palabras numeradas.
      expect(find.byKey(const ValueKey('nube-frase')), findsOneWidget);
      expect(find.byType(Chip), findsNWidgets(12));
      final chips = tester.widgetList<Chip>(find.byType(Chip)).toList();
      final frase = [
        for (final c in chips) ((c.label as Text).data!).split('. ').last,
      ];
      expect(FraseDeRecuperacion.esValida(frase), isTrue);

      await tester.tap(find.byKey(const ValueKey('nube-ya-anote')));
      await tester.pumpAndSettle();
      // Una palabra mal: no avanza.
      await tester.enterText(
        find.byKey(const ValueKey('nube-confirma-0')),
        'xx',
      );
      await tester.tap(find.byKey(const ValueKey('nube-confirmar')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nube-confirma-error')), findsOneWidget);
      expect(servidor.llave, isNull);

      // Las tres palabras que pide (por su número).
      for (var i = 0; i < 3; i++) {
        final etiqueta = tester
            .widget<TextField>(find.byKey(ValueKey('nube-confirma-$i')))
            .decoration!
            .labelText!;
        final posicion = int.parse(etiqueta.split(' ').last) - 1;
        await tester.enterText(
          find.byKey(ValueKey('nube-confirma-$i')),
          frase[posicion],
        );
      }
      // PBKDF2 de 600 000 vueltas corre en un hilo real.
      await tester.tap(find.byKey(const ValueKey('nube-confirmar')));
      await tester.pump();
      for (var i = 0; i < 100; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 100));
        if (find.text('En la nube cifrada').evaluate().length == 2) break;
      }
      await tester.pumpAndSettle();
      expect(servidor.llave, isNotNull);
      expect(
        servidor.modos.values.every((m) => m.valor == 'nube_cifrada'),
        isTrue,
      );
      expect(find.text('En la nube cifrada'), findsNWidgets(2));
      expect(find.byKey(const ValueKey('nube-reiniciar')), findsOneWidget);
      expect(contenedor, isNotNull);
    },
  );

  testWidgets('sin señal se puede ver el estado pero no cambiar', (
    tester,
  ) async {
    final servidor = AdministracionNubeHabitosEnMemoria()..sinConexion = true;
    await montar(tester, rol: Rol.dueno, servidor: servidor);
    expect(find.byKey(const ValueKey('nube-sin-senal')), findsOneWidget);
    final boton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('nube-activar')),
    );
    expect(boton.onPressed, isNull);
  });

  testWidgets('con la nube activada en otro equipo ofrece añadir este', (
    tester,
  ) async {
    final servidor = AdministracionNubeHabitosEnMemoria();
    final frase = FraseDeRecuperacion.generar();
    servidor.llave = await tester.runAsync(
      () => LlaveEnvuelta.envolver(List<int>.filled(32, 7), frase),
    );
    servidor.modos[TipoSensible.diarioOracion] = ModoSensible.nubeCifrada;
    await montar(tester, rol: Rol.dueno, servidor: servidor);
    expect(find.byKey(const ValueKey('nube-anadir-equipo')), findsOneWidget);
    expect(find.byKey(const ValueKey('nube-activar')), findsNothing);
    expect(find.byKey(const ValueKey('nube-cambiar-frase')), findsNothing);
    expect(find.byKey(const ValueKey('nube-reiniciar')), findsOneWidget);
  });
}
