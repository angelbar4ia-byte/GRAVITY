import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

List<DiaRacha> semana(List<bool?> v, {DateTime? lunes}) {
  final l = lunes ?? dia(2026, 11, 2);
  return [
    for (var i = 0; i < v.length; i++)
      DiaRacha(sumarDias(l, i), programado: v[i] != null, cumplido: v[i] ?? false)
  ];
}

void main() {
  test('racha simple y mejor racha', () {
    final r = calcularRachaDiaria(semana([true, true, true]),
        hoy: dia(2026, 11, 4));
    expect(r.actual, 3);
    expect(r.mejor, 3);
  });

  test('gracia: jueves cubierto, viernes sigue en 4; sábado rompe', () {
    final base = [true, true, true, false, true];
    var r = calcularRachaDiaria(semana(base), hoy: dia(2026, 11, 6));
    expect(r.estados[dia(2026, 11, 5)], EstadoDia.gracia);
    expect(r.actual, 4);
    r = calcularRachaDiaria(semana([...base, false, true]),
        hoy: dia(2026, 11, 8));
    expect(r.estados[dia(2026, 11, 7)], EstadoDia.noCumplido);
    expect(r.actual, 1);
    expect(r.mejor, 4);
  });

  test('la gracia se reinicia cada lunes y con 0 el jueves rompe', () {
    final dias = [
      ...semana([true, true, true, true, true, true, false]),
      ...semana([false, true], lunes: dia(2026, 11, 9)),
    ];
    final r = calcularRachaDiaria(dias, hoy: dia(2026, 11, 10));
    expect(r.estados[dia(2026, 11, 8)], EstadoDia.gracia);
    expect(r.estados[dia(2026, 11, 9)], EstadoDia.gracia);
    expect(r.actual, 7);
    final s = calcularRachaDiaria(semana([true, true, true, false, true]),
        hoy: dia(2026, 11, 6), graciaSemanal: 0);
    expect(s.actual, 1);
  });

  test('hoy sin cumplir no rompe; no aplica no rompe', () {
    final r = calcularRachaDiaria(semana([true, null, true, false]),
        hoy: dia(2026, 11, 5));
    expect(r.actual, 2);
  });

  test('semanal', () {
    expect(calcularRachaSemanal([true, true, false, true]).actual, 1);
    expect(calcularRachaSemanal([true, true, false], ultimaEnCurso: true).actual, 2);
    expect(calcularRachaSemanal([true, true, false], ultimaEnCurso: false).actual, 0);
    expect(calcularRachaSemanal([true, true, false], ultimaEnCurso: false).mejor, 2);
  });

  test('pausa', () {
    final p = Pausa(dia(2026, 11, 2), dia(2026, 11, 4));
    expect(p.cubre(dia(2026, 11, 3), 'x'), isTrue);
    expect(p.cubre(dia(2026, 11, 5), 'x'), isFalse);
  });

  test('racha global por área y marcados; sensibles no cuentan', () {
    final f = dia(2026, 11, 2);
    var d = evaluarDiaGlobal(f, [
      const ElementoDia('espiritual', minimo: false, cumplido: true),
      const ElementoDia('salud', minimo: false, cumplido: false),
    ], ModoMinimos.porArea);
    expect(d.cumplido, isFalse);
    d = evaluarDiaGlobal(f, [
      const ElementoDia('espiritual', minimo: false, cumplido: true),
      const ElementoDia('salud', minimo: false, cumplido: false, sensible: true),
    ], ModoMinimos.porArea);
    expect(d.cumplido, isTrue);
    d = evaluarDiaGlobal(f, [
      const ElementoDia('a', minimo: true, cumplido: true),
      const ElementoDia('b', minimo: false, cumplido: false),
    ], ModoMinimos.marcados);
    expect(d.cumplido, isTrue);
    d = evaluarDiaGlobal(f, [], ModoMinimos.porArea);
    expect(d.programado, isFalse);
  });
}
