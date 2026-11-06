// Ajustes › Privacidad › Mis datos de Hábitos: dónde aparece y el flujo de
// borrado (Fase 3, D13, D21).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/avisos/con_avisos.dart'
    show tipoEquipoAvisosProvider;
import 'package:gravity/app/sensibles/puerta_reservada.dart';
import 'package:gravity/modulos/ajustes/privacidad/mis_datos_habitos.dart' show guardarArchivoProvider;
import 'package:gravity/app/sensibles/sensibles.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/app/sesion_efectiva.dart';
import 'package:gravity/modulos/ajustes/privacidad/mis_datos_habitos.dart';
import 'package:gravity/nucleo/avisos/repositorio_avisos.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart';
import 'package:gravity/nucleo/sensibles/mis_datos.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';

/// La puerta de lo reservado ya abierta (el PIN de la puerta se prueba aparte).
class _Abierto extends ReservadoAbierto {
  @override
  bool build() => true;
}

class _Fuente implements FuenteDeDatosHabitos {
  @override
  Future<Map<String, Object?>> datosEnClaro() async => {};
  @override
  Future<Map<String, Object?>> datosSensibles(tipo) async => {};
}

final archivosGuardados = <String>[];

Future<void> montar(
  WidgetTester tester, {
  required Rol rol,
  bool maestra = false,
  TipoEquipoAvisos equipo = TipoEquipoAvisos.telefono,
  bool conFuente = true,
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
    // Sin diálogo del sistema: el archivo "se guarda" y queda a la vista.
    guardarArchivoProvider.overrideWithValue((nombre, bytes) async {
      archivosGuardados.add(nombre);
      return true;
    }),
    if (conFuente) fuenteDeDatosHabitosProvider.overrideWithValue(_Fuente()),
  ];
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: MisDatosDeHabitos())),
      ),
    ),
  );
}

void main() {
  setUp(archivosGuardados.clear);
  final tarjeta = find.byKey(const ValueKey('privacidad-mis-datos-habitos'));

  testWidgets('aparece para dueño, coadministrador y familiar', (tester) async {
    for (final rol in [Rol.dueno, Rol.coadministrador, Rol.familiar]) {
      await montar(tester, rol: rol);
      expect(tarjeta, findsOneWidget, reason: '$rol');
    }
  });

  testWidgets(
    'no aparece para la maestra, cuidador, Casa ni en la tablet pública',
    (tester) async {
      await montar(tester, rol: Rol.dueno, maestra: true);
      expect(tarjeta, findsNothing);
      await montar(tester, rol: Rol.cuidador);
      expect(tarjeta, findsNothing);
      await montar(tester, rol: Rol.casa);
      expect(tarjeta, findsNothing);
      await montar(
        tester,
        rol: Rol.dueno,
        equipo: TipoEquipoAvisos.tabletPublica,
      );
      expect(tarjeta, findsNothing);
    },
  );

  testWidgets('la tablet personal sí (D21)', (tester) async {
    await montar(
      tester,
      rol: Rol.dueno,
      equipo: TipoEquipoAvisos.tabletPersonal,
    );
    expect(tarjeta, findsOneWidget);
  });

  testWidgets('exportar está apagado mientras Hábitos no entregue sus datos', (
    tester,
  ) async {
    await montar(tester, rol: Rol.dueno, conFuente: false);
    final lista = tester.widget<ListTile>(
      find.byKey(const ValueKey('mis-datos-exportar')),
    );
    expect(lista.enabled, isFalse);
  });

  testWidgets(
    'un solo PIN (E5): con la puerta abierta, borrar no pide otro PIN y exige '
    'escribir BORRAR',
    (tester) async {
      await montar(tester, rol: Rol.dueno);
      await tester.tap(find.byKey(const ValueKey('mis-datos-borrar')));
      await tester.pumpAndSettle();
      expect(find.text('¿Qué quieres borrar?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('borrar-todo')));
      await tester.pumpAndSettle();
      // Ya no hay segundo PIN: va directo a la palabra de confirmación.
      expect(find.text('Tu PIN'), findsNothing);
      expect(find.text('Confirmar borrado'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Confirmar borrado'), findsNothing);
    },
  );

  testWidgets('un solo PIN (E5): exportar tampoco pide el PIN otra vez', (
    tester,
  ) async {
    await montar(tester, rol: Rol.dueno);
    await tester.tap(find.byKey(const ValueKey('mis-datos-exportar')));
    await tester.pumpAndSettle();
    // Pregunta si incluye lo reservado y, al contestar, no aparece "Tu PIN".
    await tester.tap(find.text('Sin lo reservado'));
    await tester.pumpAndSettle();
    expect(find.text('Tu PIN'), findsNothing);
    expect(archivosGuardados, ['mis-datos-habitos.json']);
  });

  testWidgets(
    'si la puerta se cerró (2 min sin uso) a mitad del flujo, sí vuelve a '
    'pedir el PIN',
    (tester) async {
      await montar(tester, rol: Rol.dueno);
      await tester.tap(find.byKey(const ValueKey('mis-datos-borrar')));
      await tester.pumpAndSettle();
      final contenedor = ProviderScope.containerOf(
        tester.element(find.byType(MisDatosDeHabitos)),
      );
      contenedor.read(reservadoAbiertoProvider.notifier).cerrar();
      await tester.tap(find.byKey(const ValueKey('borrar-todo')));
      await tester.pumpAndSettle();
      expect(find.text('Tu PIN'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Confirmar borrado'), findsNothing);
    },
  );
}
