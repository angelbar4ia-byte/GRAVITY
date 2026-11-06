import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

void main() {
  final plan = PlanCigarrillo(inicio: dia(2026, 11, 2), diaD: dia(2026, 11, 30));
  FaseHabito f(int m, int d) => plan.fase(dia(2026, m, d));

  test('fases con inicio 2/nov y Día D 30/nov', () {
    expect(f(11, 1), FaseHabito.noIniciado);
    expect(f(11, 2), FaseHabito.lineaBase);
    expect(f(11, 8), FaseHabito.lineaBase);
    expect(f(11, 9), FaseHabito.reduccion);
    expect(f(11, 22), FaseHabito.reduccion);
    expect(f(11, 23), FaseHabito.preparacion);
    expect(f(11, 29), FaseHabito.preparacion);
    expect(f(11, 30), FaseHabito.diaD);
    expect(f(12, 1), FaseHabito.libre);
    expect(f(12, 27), FaseHabito.libre);
    expect(f(12, 28), FaseHabito.mantenimiento);
    expect(plan.enFoco(dia(2026, 12, 13)), isTrue);
    expect(plan.enFoco(dia(2026, 12, 14)), isFalse);
    expect(plan.enFoco(dia(2026, 11, 29)), isFalse);
  });

  test('Día D por omisión = inicio + 28', () {
    expect(PlanCigarrillo(inicio: dia(2026, 11, 2)).diaD, dia(2026, 11, 30));
  });

  test('promedio de la línea base', () {
    expect(promedioLineaBase([12, 12, 12, 12, 12, 12, 12]), 1200);
    expect(promedioLineaBase([10, 10, 10, 10, 10]), 1000);
    expect(promedioLineaBase([10, 10, 10, 10]), isNull);
  });

  test('límites de reducción', () {
    expect([25, 50, 75].map((p) => limiteReduccion(1200, p)), [9, 6, 3]);
    expect([25, 50, 75].map((p) => limiteReduccion(1000, p)), [8, 5, 3]);
    expect(limiteReduccion(0, 25), 0);
    expect(plan.limiteDelDia(dia(2026, 11, 9), 1200), 9);
    expect(plan.limiteDelDia(dia(2026, 11, 16), 1200), 6);
    expect(plan.limiteDelDia(dia(2026, 11, 23), 1200), 3);
    expect(plan.limiteDelDia(dia(2026, 11, 5), 1200), isNull);
  });

  test('racha libre y recaída', () {
    final d = dia(2026, 11, 30);
    var r = calcularRachaLibre(diaD: d, hoy: dia(2026, 12, 4), consumoPorDia: {});
    expect([r.actual, r.mejor, r.acumulados], [5, 5, 5]);
    final c = {dia(2026, 12, 5): 1};
    r = calcularRachaLibre(diaD: d, hoy: dia(2026, 12, 5), consumoPorDia: c);
    expect([r.actual, r.mejor, r.acumulados], [0, 5, 5]);
    r = calcularRachaLibre(diaD: d, hoy: dia(2026, 12, 6), consumoPorDia: c);
    expect([r.actual, r.mejor, r.acumulados], [1, 5, 6]);
  });

  test('recaídas: antes del Día D no cuenta; 3 en 14 sugiere apoyo', () {
    final d = dia(2026, 11, 30);
    final c = {
      dia(2026, 11, 20): 5,
      dia(2026, 12, 2): 1,
      dia(2026, 12, 5): 1,
    };
    final r = diasDeRecaida(d, c);
    expect(r.length, 2);
    expect(sugerirApoyo(r, dia(2026, 12, 6)), isFalse);
    c[dia(2026, 12, 6)] = 2;
    expect(sugerirApoyo(diasDeRecaida(d, c), dia(2026, 12, 6)), isTrue);
  });

  test('semáforo del refresco', () {
    SemaforoHabito s(int u, int l) => semaforoAzucar(u, l);
    expect([0, 1, 2].map((u) => s(u, 4)), everyElement(SemaforoHabito.verde));
    expect([3, 4].map((u) => s(u, 4)), everyElement(SemaforoHabito.ambar));
    expect(s(5, 4), SemaforoHabito.terracota);
    expect(s(0, 1), SemaforoHabito.verde);
    expect(s(1, 1), SemaforoHabito.ambar);
    expect(s(2, 1), SemaforoHabito.terracota);
    expect(s(0, 0), SemaforoHabito.verde);
    expect(s(1, 0), SemaforoHabito.terracota);
  });

  test('ahorro', () {
    expect(
        ahorroDia(
            promedioCentesimas: 1200,
            consumoDia: 0,
            precioCajetillaCentavos: 15000,
            cigarrillosPorCajetilla: 20),
        9000);
    expect(
        ahorroDia(
            promedioCentesimas: 1200,
            consumoDia: 20,
            precioCajetillaCentavos: 15000,
            cigarrillosPorCajetilla: 20),
        0);
    final t = ahorroTotal(
        finLineaBase: dia(2026, 11, 9),
        consumoDiasConDatos: {dia(2026, 11, 5): 0, dia(2026, 11, 10): 0},
        promedioCentesimas: 1200,
        precioCajetillaCentavos: 15000,
        cigarrillosPorCajetilla: 20);
    expect(t, 9000);
  });

  test('hitos de constancia', () {
    expect(hitosAlcanzados(8, hitosCigarrillo), [1, 3, 7]);
    expect(hitosAlcanzados(0, hitosCigarrillo), isEmpty);
  });

  test('SOS', () {
    final s = SesionSos();
    expect(s.paso, PasoSos.pausa);
    s.avanzar();
    s.avanzar();
    s.avanzar();
    expect(s.paso, PasoSos.temporizador);
    s.terminarTiempo(sigue: true);
    expect(s.rondas, 2);
    expect(s.paso, PasoSos.tecnica);
    s.terminarTiempo(sigue: false);
    expect(s.resultado, ResultadoAntojo.superado);
    expect(SesionSos(minutos: 99).minutos, 15);
    expect(ordenarTecnicas(['agua']).first, 'agua');
    expect(ordenarTecnicas([]).length, 6);
    expect(pasosSos.length, 6);
    expect(versiculoDelDia(dia(2000, 1, 1), versiculosAnimo), versiculosAnimo[0]);
    expect(versiculoDelDia(dia(2000, 1, 8), versiculosAnimo), versiculosAnimo[0]);
  });

  test('referencias de ánimo se analizan', () {
    for (final r in versiculosAnimo) {
      expect(analizarReferencia(r), isNotNull, reason: r);
    }
  });
}
