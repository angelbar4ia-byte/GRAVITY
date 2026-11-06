import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/habitos/casos_uso/servicio_agenda.dart';
import 'package:gravity/modulos/habitos/datos/modelos.dart';
import 'package:gravity/modulos/habitos/datos/repositorio.dart';
import 'package:gravity/modulos/habitos/datos/repositorio_agenda.dart';
import 'package:gravity/modulos/habitos/estado/proveedores.dart';
import 'package:gravity/modulos/habitos/pantallas/edicion.dart';
import 'package:habitos_dominio/habitos_dominio.dart';

// Fase 4, E4 / criterio 28: editar un bloque no pierde sus registros.
void main() {
  late DateTime ahora;
  late RepositorioAgendaEnMemoria agenda;
  late RepositorioHabitosEnMemoria repo;
  late ServicioAgenda s;
  final lunes = DateTime.utc(2026, 11, 2);

  setUp(() {
    ahora = DateTime.utc(2026, 11, 2, 8);
    agenda = RepositorioAgendaEnMemoria();
    repo = RepositorioHabitosEnMemoria();
    s = ServicioAgenda(agenda, repo, ahora: () => ahora);
  });

  test('edita nombre, horario, días y área; los registros se conservan', () async {
    final b = await s.crearBloque(titulo: 'Inglés', area: 'educacion', inicioMin: 1140, duracionMin: 30);
    await s.marcarHecho(b, fecha: lunes);
    final n = await s.editarBloque(
      b,
      titulo: ' Inglés con audio ',
      area: 'personal',
      inicioMin: 1200,
      duracionMin: 45,
      dias: 1 | 8, // lunes y jueves
      recordarMin: 10,
    );
    expect(n.id, b.id);
    expect(n.titulo, 'Inglés con audio');
    expect(n.inicioMin, 1200);
    expect(n.duracionMin, 45);
    expect(n.dias, 9);
    expect(n.recordarMin, 10);
    expect(n.desde, b.desde);
    final hoy = (await s.bloquesDe(lunes)).single;
    expect(hoy.bloque.titulo, 'Inglés con audio');
    expect(hoy.estado, EstadoRegistro.hecho); // el registro del día sigue ahí
    expect(await s.bloquesDe(DateTime.utc(2026, 11, 3)), isEmpty); // martes ya no
    expect((await s.bloquesDe(DateTime.utc(2026, 11, 5))).length, 1); // jueves sí
  });

  test('valida y no guarda lo inválido', () async {
    final b = await s.crearBloque(titulo: 'Caminar', area: 'salud', inicioMin: 360, duracionMin: 30);
    Future<void> intentar({String t = 'x', String a = 'salud', int ini = 360, int dur = 30, int dias = 127}) =>
        s.editarBloque(b, titulo: t, area: a, inicioMin: ini, duracionMin: dur, dias: dias);
    await expectLater(intentar(t: ''), throwsArgumentError);
    await expectLater(intentar(a: 'nada'), throwsArgumentError);
    await expectLater(intentar(ini: 1500), throwsArgumentError);
    await expectLater(intentar(dur: 1), throwsArgumentError);
    await expectLater(intentar(dias: 0), throwsArgumentError);
    expect((await agenda.bloques()).single.titulo, 'Caminar');
  });

  test('deshacer restaura el bloque original; el cruce avisa, no impide', () async {
    final a = await s.crearBloque(titulo: 'A', area: 'salud', inicioMin: 600, duracionMin: 60);
    final b = await s.crearBloque(titulo: 'B', area: 'salud', inicioMin: 800, duracionMin: 30);
    final n = await s.editarBloque(b, titulo: 'B', area: 'salud', inicioMin: 630, duracionMin: 30, dias: 127);
    expect((await s.conflictosDe(n)).map((x) => x.id), [a.id]);
    expect((await agenda.bloques()).firstWhere((x) => x.id == b.id).inicioMin, 630); // guardó igual
    ahora = ahora.add(const Duration(minutes: 1));
    await s.restaurarBloque(b);
    expect((await agenda.bloques()).firstWhere((x) => x.id == b.id).inicioMin, 800);
  });

  test('quitar un bloque y deshacerlo', () async {
    final b = await s.crearBloque(titulo: 'Leer', area: 'personal', inicioMin: 1200, duracionMin: 20);
    await s.desactivar(b);
    expect(await s.bloquesDe(lunes), isEmpty);
    ahora = ahora.add(const Duration(minutes: 1));
    await s.restaurarBloque(b);
    expect((await s.bloquesDe(lunes)).length, 1);
  });

  testWidgets('la hoja de edición guarda, ofrece Deshacer y avisa si hay error', (t) async {
    final b = await s.crearBloque(titulo: 'Inglés', area: 'educacion', inicioMin: 1140, duracionMin: 30);
    await t.pumpWidget(ProviderScope(
      overrides: [
        servicioAgendaProvider.overrideWithValue(s),
        repositorioAgendaProvider.overrideWithValue(agenda),
      ],
      child: MaterialApp(
        home: Scaffold(body: Builder(builder: (c) => TextButton(onPressed: () => editarBloqueEnHoja(c, b), child: const Text('abrir')))),
      ),
    ));
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    // nombre vacío: error visible y la hoja se queda abierta
    await t.enterText(find.widgetWithText(TextField, 'Nombre'), '');
    await t.tap(find.text('Guardar cambios'));
    await t.pumpAndSettle();
    expect(find.text('El nombre va de 1 a 120 caracteres.'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextField, 'Nombre'), 'Inglés 2');
    await t.tap(find.text('Guardar cambios'));
    await t.pumpAndSettle();
    expect((await agenda.bloques()).single.titulo, 'Inglés 2');
    expect(find.text('Deshacer'), findsOneWidget);
    ahora = ahora.add(const Duration(minutes: 1));
    await t.tap(find.text('Deshacer'));
    await t.pumpAndSettle();
    expect((await agenda.bloques()).single.titulo, 'Inglés');
  });
}
