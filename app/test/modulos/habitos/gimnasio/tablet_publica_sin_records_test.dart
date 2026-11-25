// Tablet pública (decisión del dueño, 25/nov/2026; CA-G-38): NO ve el historial
// ni los récords; solo Hoy, Sesión de hoy y Sesión en curso. Al terminar una
// sesión la tablet pública solo dice que quedó guardada: el aviso de «nuevo
// récord» se ve en el teléfono, la laptop o la tablet personal.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/gimnasio/acceso_gimnasio.dart';
import 'package:gravity/modulos/habitos/gimnasio/pantallas/comun.dart';
import 'package:gravity/nucleo/avisos/repositorio_avisos.dart'
    show TipoEquipoAvisos;

import 'ayuda_gimnasio_app.dart';

void main() {
  late Mundo m;
  setUp(() => m = Mundo());
  tearDown(() => m.cerrar());

  Future<void> terminarUnaSesion(WidgetTester t, TipoEquipoAvisos equipo) async {
    await montarPantalla(t, m, DestinoGimnasio.sesionEnCurso, equipo: equipo);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.byKey(const ValueKey('calentamiento-listo')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('boton-serie-hecha')));
    await t.pump(const Duration(milliseconds: 100));
    await t.tap(find.text('Saltar'));
    await t.pump(const Duration(milliseconds: 100));
    await t.tap(find.byKey(const ValueKey('terminar')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('termine-sesion')));
    await t.pumpAndSettle();
  }

  testWidgets('control: en el teléfono, al terminar sale el récord', (t) async {
    await terminarUnaSesion(t, TipoEquipoAvisos.telefono);
    expect(find.textContaining('récord'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(milliseconds: 50));
  });

  testWidgets('en la tablet pública, al terminar solo dice que quedó guardada', (
    t,
  ) async {
    await terminarUnaSesion(t, TipoEquipoAvisos.tabletPublica);
    expect((await m.repo.sesiones(persona)).single.estado, 'completa');
    expect(find.textContaining(TextosHabitosGimnasio.sesionTerminada), findsOneWidget);
    expect(find.textContaining('récord'), findsNothing);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(milliseconds: 50));
  });

  test('el historial y los récords no existen en la tablet pública', () {
    for (final d in [DestinoGimnasio.historial, DestinoGimnasio.records]) {
      expect(gimnasioDisponibleEn(d, TipoEquipoAvisos.tabletPublica), isFalse);
      expect(gimnasioDisponibleEn(d, TipoEquipoAvisos.telefono), isTrue);
      expect(gimnasioDisponibleEn(d, TipoEquipoAvisos.laptop), isTrue);
    }
  });
}
