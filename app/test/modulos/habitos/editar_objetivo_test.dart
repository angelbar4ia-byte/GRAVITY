import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/habitos/casos_uso/servicio_habitos.dart';
import 'package:gravity/modulos/habitos/datos/modelos.dart';
import 'package:gravity/modulos/habitos/datos/repositorio.dart';
import 'package:habitos_dominio/habitos_dominio.dart';

// Fase 4, E4 / criterio 28: editar un objetivo no rompe racha ni historial.
void main() {
  late DateTime ahora;
  late RepositorioHabitosEnMemoria repo;
  late ServicioHabitos s;
  late ObjetivoHab o;

  setUp(() async {
    ahora = DateTime.utc(2026, 11, 2, 9); // lunes
    repo = RepositorioHabitosEnMemoria();
    s = ServicioHabitos(repo, ahora: () => ahora);
    o = await s.crearObjetivo(
      titulo: 'Leer',
      area: 'personal',
      unidad: 'páginas',
      metaValor: 10,
      inicio: DateTime.utc(2026, 11, 2),
    );
    for (final d in [2, 3, 4]) {
      await s.marcarHecho(o, fecha: DateTime.utc(2026, 11, d));
    }
    ahora = DateTime.utc(2026, 11, 4, 20);
  });

  Future<List<Map<String, Object?>>> registros() async => [
    for (final r in await repo.registros(
      DateTime.utc(2026, 1, 1),
      DateTime.utc(2026, 12, 31),
    ))
      r.aFila(),
  ];

  test(
    'edita nombre, área, unidad, meta y motivo sin tocar registros ni racha',
    () async {
      final antes = await registros();
      final rachaAntes = (await s.hoyDe()).single.racha.actual;
      final n = await s.editarObjetivo(
        o,
        titulo: '  Leer un libro ',
        area: 'educacion',
        unidad: 'capítulos',
        metaValor: 2,
        motivo: 'Aprender',
      );
      expect(n.id, o.id);
      expect(n.titulo, 'Leer un libro');
      expect(n.area, 'educacion');
      expect(n.unidad, 'capítulos');
      expect(n.metaValor, 2);
      expect(n.fechaInicio, o.fechaInicio);
      expect(await registros(), antes); // el libro de cumplimiento no cambia
      final h = (await s.hoyDe()).single;
      expect(h.objetivo.titulo, 'Leer un libro');
      expect(h.racha.actual, rachaAntes);
      expect(h.racha.actual, 3);
    },
  );

  test('cambiar a días elegidos conserva el historial; vaciar unidad y motivo los limpia', () async {
    final antes = await registros();
    final n = await s.editarObjetivo(
      o,
      titulo: 'Leer',
      area: 'personal',
      unidad: '  ',
      metaValor: null,
      frecuencia: Frecuencia.diasSemana,
      diasSemana: 1 | 4 | 16, // lunes, miércoles, viernes
      motivo: '',
    );
    expect(n.frecuencia, Frecuencia.diasSemana);
    expect(n.diasSemana, 21);
    expect(n.unidad, isNull);
    expect(n.metaValor, isNull);
    expect(n.motivo, isNull);
    expect(n.programadoEn(DateTime.utc(2026, 11, 3)), isFalse);
    expect(n.programadoEn(DateTime.utc(2026, 11, 2)), isTrue);
    expect(await registros(), antes);
    // volver a "todos los días" restablece la máscara
    final t = await s.editarObjetivo(
      n,
      titulo: 'Leer',
      area: 'personal',
      frecuencia: Frecuencia.diaria,
    );
    expect(t.diasSemana, 127);
  });

  test('valida: nombre, área, días y meta', () async {
    Future<void> intentar({
      String titulo = 'Leer',
      String area = 'personal',
      int? meta,
      Frecuencia? f,
      int? dias,
    }) => s.editarObjetivo(
      o,
      titulo: titulo,
      area: area,
      metaValor: meta,
      frecuencia: f,
      diasSemana: dias,
    );
    await expectLater(intentar(titulo: ' '), throwsArgumentError);
    await expectLater(intentar(titulo: 'x' * 121), throwsArgumentError);
    await expectLater(intentar(area: 'otra'), throwsArgumentError);
    await expectLater(
      intentar(f: Frecuencia.diasSemana, dias: 0),
      throwsArgumentError,
    );
    await expectLater(intentar(meta: 0), throwsArgumentError);
    // lo inválido no se guardó
    expect((await s.hoyDe()).single.objetivo.titulo, 'Leer');
  });

  test('deshacer devuelve el objetivo original', () async {
    final n = await s.editarObjetivo(
      o,
      titulo: 'Otra cosa',
      area: 'salud',
      metaValor: 3,
    );
    ahora = ahora.add(const Duration(minutes: 1));
    await s.restaurarObjetivo(o);
    final h = (await s.hoyDe()).single;
    expect(h.objetivo.titulo, 'Leer');
    expect(h.objetivo.area, 'personal');
    expect(h.objetivo.metaValor, 10);
    expect(h.objetivo.modificadoEn.isAfter(n.modificadoEn), isTrue);
    expect(h.racha.actual, 3);
  });

  test('archivar y deshacer el archivado', () async {
    await s.archivar(o);
    expect(await s.hoyDe(), isEmpty);
    ahora = ahora.add(const Duration(minutes: 1));
    await s.restaurarObjetivo(o);
    expect((await s.hoyDe()).length, 1);
    expect((await registros()).length, 3);
  });
}
