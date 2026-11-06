import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/habitos/casos_uso/servicio_habitos.dart';
import 'package:gravity/modulos/habitos/datos/modelos.dart';
import 'package:gravity/modulos/habitos/datos/repositorio.dart';
import 'package:habitos_dominio/habitos_dominio.dart';

void main() {
  late DateTime ahora;
  late RepositorioHabitosEnMemoria repo;
  late ServicioHabitos s;

  setUp(() {
    ahora = DateTime.utc(2026, 11, 2, 9); // lunes
    repo = RepositorioHabitosEnMemoria();
    s = ServicioHabitos(repo, ahora: () => ahora);
  });

  test('crear valida y guarda; archivar lo saca de Hoy', () async {
    expect(
      () => s.crearObjetivo(titulo: '', area: 'personal'),
      throwsArgumentError,
    );
    final o = await s.crearObjetivo(
      titulo: 'Leer',
      area: 'personal',
      unidad: 'páginas',
      metaValor: 10,
    );
    expect((await s.hoyDe()).length, 1);
    await s.archivar(o);
    expect(await s.hoyDe(), isEmpty);
  });

  test('hecho, deshacer y racha con gracia', () async {
    final o = await s.crearObjetivo(
      titulo: 'Orar',
      area: 'espiritual',
      inicio: DateTime.utc(2026, 11, 2),
    );
    await s.marcarHecho(o, fecha: DateTime.utc(2026, 11, 2));
    await s.marcarHecho(o, fecha: DateTime.utc(2026, 11, 3));
    // miércoles sin cumplir (gracia); jueves hecho
    await s.marcarHecho(o, fecha: DateTime.utc(2026, 11, 5));
    ahora = DateTime.utc(2026, 11, 5, 20);
    var h = (await s.hoyDe()).single;
    expect(h.hecho, isTrue);
    expect(h.racha.actual, 3);
    await s.deshacer(o);
    h = (await s.hoyDe()).single;
    expect(h.estado, EstadoRegistro.pendiente);
    expect(h.racha.actual, 2); // hoy abierto: no rompe
    expect(h.racha.mejor, 2);
  });

  test('el mismo registro no se duplica y el último gana', () async {
    final o = await s.crearObjetivo(titulo: 'x', area: 'salud');
    await s.marcarHecho(o);
    await s.omitir(o, motivo: 'cansancio');
    final regs = await repo.registros(
      DateTime.utc(2026, 11, 1),
      DateTime.utc(2026, 11, 3),
    );
    expect(regs.length, 1);
    expect(regs.single.estado, EstadoRegistro.omitido);
    expect(
      idRegistro(o.id, DateTime.utc(2026, 11, 2)),
      idRegistro(o.id, DateTime.utc(2026, 11, 2)),
    );
  });

  test('objetivo por días de la semana y fila del servidor', () async {
    final o = await s.crearObjetivo(
      titulo: 'Gym',
      area: 'salud',
      frecuencia: Frecuencia.diasSemana,
      diasSemana: 1 | 4,
    );
    expect(o.programadoEn(DateTime.utc(2026, 11, 2)), isTrue);
    expect(o.programadoEn(DateTime.utc(2026, 11, 3)), isFalse);
    final f = o.aFila();
    expect(f.containsKey('persona_id'), isFalse);
    expect(f.containsKey('actualizado_en'), isFalse);
    expect(f['frecuencia'], 'dias_semana');
    expect(ObjetivoHab.deFila(f).frecuencia, Frecuencia.diasSemana);
  });

  test('resumen discreto', () async {
    expect(await s.resumenHoy(), MensajesHabitos.diaLibre);
    final o = await s.crearObjetivo(titulo: 'x', area: 'salud');
    await s.marcarHecho(o);
    expect(await s.resumenHoy(), 'Hoy llevas 1 de 1.');
  });
}
