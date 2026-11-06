import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

void main() {
  test('carga: umbrales con 200 libres', () {
    NivelCarga n(int p) => medirCarga(libres: 200, programados: p);
    expect(n(99), NivelCarga.ligero);
    expect(n(100), NivelCarga.equilibrado);
    expect(n(170), NivelCarga.equilibrado);
    expect(n(171), NivelCarga.saturado);
    expect(medirCarga(libres: 0, programados: 0), NivelCarga.saturado);
    expect(minutosLibres(despertarMin: 360, dormirMin: 1320, fijosMin: 695), 265);
  });

  test('recortes: no mínimos más largos primero', () {
    expect(
        proponerRecortes(const [
          BloqueCarga('a', 30),
          BloqueCarga('b', 60),
          BloqueCarga('c', 90, minimo: true),
        ]),
        ['b', 'a']);
  });

  test('orden de Hoy y Sigue', () {
    final l = [
      const ElementoHoy('z'),
      const ElementoHoy('b', horaMin: 600, prioridad: 1),
      const ElementoHoy('a', horaMin: 600, prioridad: 2),
      const ElementoHoy('c', horaMin: 480, duracionMin: 30),
    ];
    expect(ordenarHoy(l).map((e) => e.id), ['c', 'a', 'b', 'z']);
    final s = calcularSigue(l, 490)!;
    expect(s.elemento.id, 'c');
    expect(s.enCurso, isTrue);
    expect(calcularSigue(l, 520)!.elemento.id, 'a');
    expect(calcularSigue(const [], 0), isNull);
  });

  test('foco', () {
    expect(
        filtrarFoco(const [ElementoHoy('a', esencial: true), ElementoHoy('b')])
            .length,
        1);
  });

  test('objetivos: ritmo y validación', () {
    expect(ritmoPorDia(meta: 300, avance: 0, diasRestantes: 30), 10);
    expect(ritmoPorDia(meta: 301, avance: 0, diasRestantes: 30), 11);
    expect(avanceProyecto(1, 3), 33);
    expect(validarObjetivo(titulo: '', tipo: TipoObjetivo.construir), isNotEmpty);
    expect(validarObjetivo(titulo: 'Leer', tipo: TipoObjetivo.meta), isNotEmpty);
    expect(pasosSmart.length, 5);
  });

  test('agenda: recurrencia, huecos, conflictos', () {
    final b = BloqueRecurrente(
        id: 'x', inicioMin: 0, duracionMin: 30, dias: 1 | 4,
        desde: dia(2026, 11, 2), cadaSemanas: 2);
    expect(b.ocurreEn(dia(2026, 11, 2)), isTrue); // lunes sem 0
    expect(b.ocurreEn(dia(2026, 11, 4)), isTrue); // miércoles
    expect(b.ocurreEn(dia(2026, 11, 9)), isFalse); // sem 1
    expect(b.ocurreEn(dia(2026, 11, 16)), isTrue);
    expect(b.ocurreEn(dia(2026, 11, 3)), isFalse);
    final h = huecosLibres(360, 1320, const [Intervalo(480, 1080)]);
    expect(h.map((e) => [e.inicio, e.fin]), [[360, 480], [1080, 1320]]);
    final p = huecosLibres(360, 1320, const [Intervalo(480, 1080)],
        preferidaMin: 1200);
    expect(p.first.inicio, 1080);
    expect(conflictos(const Intervalo(470, 500), const [Intervalo(480, 1080)]).length, 1);
    expect(conflictos(const Intervalo(400, 480), const [Intervalo(480, 1080)]), isEmpty);
  });

  test('revisión', () {
    expect(cumplimientoSemanal(2, 3), 66);
    expect(cumplimientoSemanal(0, 0), isNull);
    expect(diaDeRevision(dia(2026, 11, 4)), dia(2026, 11, 7));
    expect(minutoDeAviso(870, 15), 855);
    expect(revisionVigente(dia(2026, 11, 2), dia(2026, 11, 11)), isTrue);
    expect(revisionVigente(dia(2026, 11, 2), dia(2026, 11, 12)), isFalse);
  });
}
