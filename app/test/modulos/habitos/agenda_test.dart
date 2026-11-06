import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/habitos/casos_uso/servicio_agenda.dart';
import 'package:gravity/modulos/habitos/datos/modelos.dart';
import 'package:gravity/modulos/habitos/datos/repositorio.dart';
import 'package:gravity/modulos/habitos/datos/repositorio_agenda.dart';
import 'package:habitos_dominio/habitos_dominio.dart';

void main() {
  late ServicioAgenda s;
  late RepositorioAgendaEnMemoria agenda;
  final lunes = DateTime.utc(2026, 11, 2);

  setUp(() {
    agenda = RepositorioAgendaEnMemoria();
    s = ServicioAgenda(
      agenda,
      RepositorioHabitosEnMemoria(),
      ahora: () => DateTime.utc(2026, 11, 2, 8),
    );
  });

  test('asistente: trabajo y traslados fijos; carga con 265 libres', () async {
    await s.aplicarAsistente(
      despertarMin: 360,
      dormirMin: 1320,
      trabajoEntradaMin: 480,
      trabajoSalidaMin: 1080,
      trasladoIdaMin: 35,
      trasladoVueltaMin: 60,
      revisionDia: 6,
      pasosHechos: {1, 2, 3},
    );
    final c = await s.carga(lunes);
    expect(c.libres, 265);
    expect(c.programados, 0);
    expect(c.nivel, NivelCarga.ligero);
    expect((await agenda.ajustes()).asistente['completo'], false);
    // sábado: no hay trabajo (lunes a viernes)
    expect((await s.carga(DateTime.utc(2026, 11, 7))).libres, 960);
  });

  test('bloques de actividad suman a la carga; saturan', () async {
    await s.aplicarAsistente(
      trabajoEntradaMin: 480,
      trabajoSalidaMin: 1080,
      trasladoIdaMin: 35,
      trasladoVueltaMin: 60,
    );
    await s.crearBloque(
      titulo: 'Inglés',
      area: 'educacion',
      inicioMin: 1140,
      duracionMin: 120,
    );
    expect((await s.carga(lunes)).nivel, NivelCarga.ligero); // 120/265 = 45 %
    await s.crearBloque(
      titulo: 'Lectura',
      area: 'personal',
      inicioMin: 1300,
      duracionMin: 100,
    );
    expect(
      (await s.carga(lunes)).nivel,
      NivelCarga.equilibrado,
    ); // 220/265 = 83 %
    await s.crearBloque(
      titulo: 'Otro',
      area: 'salud',
      inicioMin: 400,
      duracionMin: 30,
    );
    expect((await s.carga(lunes)).nivel, NivelCarga.saturado); // 250/265 = 94 %
  });

  test('conflicto y huecos', () async {
    await s.aplicarAsistente(trabajoEntradaMin: 480, trabajoSalidaMin: 1080);
    final nuevo = await s.crearBloque(
      titulo: 'Gym',
      area: 'salud',
      inicioMin: 1050,
      duracionMin: 60,
    );
    final c = await s.conflictosDe(nuevo);
    expect(c.map((b) => b.tipo), ['trabajo']);
    final h = await s.huecos(lunes, preferidaMin: 1200);
    expect(
      h.first.inicio,
      1110,
    ); // el hueco tras el gym, más cercano a las 20:00
  });

  test('hecho, posponer y deshacer un bloque; no duplica', () async {
    final b = await s.crearBloque(
      titulo: 'Leer',
      area: 'personal',
      inicioMin: 1260,
      duracionMin: 30,
    );
    await s.marcarHecho(b);
    var o = (await s.bloquesDe(lunes)).single;
    expect(o.estado, EstadoRegistro.hecho);
    await s.posponer(b, 1290);
    o = (await s.bloquesDe(lunes)).single;
    expect(o.estado, EstadoRegistro.pospuesto);
    expect(o.inicioMin, 1290);
    await s.deshacer(b);
    expect((await s.bloquesDe(lunes)).single.estado, EstadoRegistro.pendiente);
  });

  test('semana tipo: 7 días', () async {
    expect((await s.semanaTipo(lunes)).length, 7);
    expect(
      () => s.crearBloque(
        titulo: '',
        area: 'salud',
        inicioMin: 0,
        duracionMin: 1,
      ),
      throwsArgumentError,
    );
  });

  test('fila del servidor sin campos del servidor', () async {
    final b = await s.crearBloque(
      titulo: 'x',
      area: 'salud',
      inicioMin: 485,
      duracionMin: 30,
    );
    final f = b.aFila();
    expect(f['inicio'], '08:05');
    expect(f.containsKey('persona_id'), isFalse);
    expect(f.containsKey('actualizado_en'), isFalse);
  });
}
