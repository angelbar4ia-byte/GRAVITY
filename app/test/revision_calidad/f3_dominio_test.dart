// Revisión de calidad de la Fase 3: bordes del dominio de Hábitos (criterios 2,
// 3, 9, 12 a 19, 26 y 27): bisiestos, semana en lunes, cambio de horario,
// redondeos, límites 25/50/75 %, carga 50/85 % y planes de lectura.
// Todas son guardias (pasan). Corren en la zona del equipo; la revisión las
// repitió con TZ=America/New_York, Pacific/Auckland y America/Sao_Paulo.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:habitos_dominio/habitos_dominio.dart';

DiaRacha d(DateTime f, bool ok, {bool prog = true}) => DiaRacha(f, programado: prog, cumplido: ok);

void main() {
  group('fechas', () {
    test('la semana empieza en lunes, también en domingo, en año nuevo y en bisiesto', () {
      expect(lunesDe(DateTime(2026, 11, 1)), DateTime.utc(2026, 10, 26)); // domingo
      expect(lunesDe(DateTime(2026, 11, 2)), DateTime.utc(2026, 11, 2)); // lunes
      expect(lunesDe(DateTime(2027, 1, 1)), DateTime.utc(2026, 12, 28));
      expect(lunesDe(DateTime(2028, 2, 29)), DateTime.utc(2028, 2, 28));
      expect(lunesDe(DateTime(2028, 3, 5)), DateTime.utc(2028, 2, 28));
    });

    test('sumar días cruza el 29 de febrero y los cambios de horario sin perder un día', () {
      expect(sumarDias(DateTime.utc(2028, 2, 28), 2), DateTime.utc(2028, 3, 1));
      expect(sumarDias(DateTime.utc(2027, 2, 28), 1), DateTime.utc(2027, 3, 1));
      expect(diasEntre(DateTime(2026, 3, 7), DateTime(2026, 3, 10)), 3); // primavera EE. UU.
      expect(diasEntre(DateTime(2026, 10, 31), DateTime(2026, 11, 2)), 2); // otoño
      expect(diasEntre(DateTime(2026, 3, 28), DateTime(2026, 3, 30)), 2); // Europa
      var f = DateTime.utc(2026, 1, 1);
      for (var i = 0; i < 800; i++) {
        f = sumarDias(f, 1);
      }
      expect(f, DateTime.utc(2026, 1, 1).add(const Duration(days: 800)));
    });
  });

  group('rachas', () {
    test('la gracia se reparte por semana de lunes a domingo, no por 7 días corridos', () {
      // domingo y lunes fallados: cada uno en una semana distinta, los dos con gracia.
      final dias = [
        d(DateTime.utc(2026, 10, 26), true),
        d(DateTime.utc(2026, 11, 1), false), // domingo
        d(DateTime.utc(2026, 11, 2), false), // lunes siguiente
        d(DateTime.utc(2026, 11, 3), true),
      ];
      final r = calcularRachaDiaria(dias, hoy: DateTime.utc(2026, 11, 3));
      expect(r.estados[DateTime.utc(2026, 11, 1)], EstadoDia.gracia);
      expect(r.estados[DateTime.utc(2026, 11, 2)], EstadoDia.gracia);
      expect(r.actual, 2);
    });

    test('mejor racha nunca baja y un día futuro no cuenta', () {
      final dias = [
        for (var i = 0; i < 5; i++) d(DateTime.utc(2026, 10, 12 + i), true),
        d(DateTime.utc(2026, 10, 17), false),
        d(DateTime.utc(2026, 10, 18), false), // segunda falla en la misma semana: rompe
        d(DateTime.utc(2026, 10, 19), true),
        d(DateTime.utc(2026, 10, 25), true), // futuro respecto a hoy
      ];
      final r = calcularRachaDiaria(dias, hoy: DateTime.utc(2026, 10, 19));
      expect(r.mejor, 5);
      expect(r.actual, 1);
    });

    test('sin días y con graciaSemanal 0 no revienta', () {
      expect(calcularRachaDiaria(const [], hoy: DateTime.utc(2026, 11, 2)).actual, 0);
      final r = calcularRachaDiaria([d(DateTime.utc(2026, 11, 1), false)],
          hoy: DateTime.utc(2026, 11, 2), graciaSemanal: 0);
      expect(r.estados[DateTime.utc(2026, 11, 1)], EstadoDia.noCumplido);
    });
  });

  group('cigarrillo', () {
    test('fases del criterio 12 con inicio 2/nov y Día D 30/nov, día por día', () {
      final p = PlanCigarrillo(inicio: DateTime(2026, 11, 2), diaD: DateTime(2026, 11, 30));
      FaseHabito f(int mes, int dia, [int anio = 2026]) => p.fase(DateTime(anio, mes, dia));
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
      expect(p.enFoco(DateTime(2026, 11, 30)), isTrue);
      expect(p.enFoco(DateTime(2026, 12, 13)), isTrue);
      expect(p.enFoco(DateTime(2026, 12, 14)), isFalse);
    });

    test('porcentajes 25/50/75 por semana y después se mantiene el último', () {
      final p = PlanCigarrillo(inicio: DateTime(2026, 11, 2), diaD: DateTime(2026, 11, 30));
      expect(p.porcentajeEtapa(DateTime(2026, 11, 9)), 25);
      expect(p.porcentajeEtapa(DateTime(2026, 11, 15)), 25);
      expect(p.porcentajeEtapa(DateTime(2026, 11, 16)), 50);
      expect(p.porcentajeEtapa(DateTime(2026, 11, 23)), 75);
      expect(p.porcentajeEtapa(DateTime(2026, 11, 8)), isNull); // línea base
      expect(p.porcentajeEtapa(DateTime(2026, 11, 30)), isNull); // Día D
    });

    test('Día D por omisión cruza el 29 de febrero', () {
      final p = PlanCigarrillo(inicio: DateTime(2028, 2, 10));
      expect(p.diaD, DateTime.utc(2028, 3, 9));
    });

    test('límites y promedio: redondeo mitad hacia arriba, nunca negativo', () {
      expect([25, 50, 75].map((x) => limiteReduccion(1200, x)), [9, 6, 3]);
      expect([25, 50, 75].map((x) => limiteReduccion(1000, x)), [8, 5, 3]);
      expect(limiteReduccion(0, 25), 0);
      expect(limiteReduccion(1200, 100), 0);
      expect(limiteReduccion(1200, 150), 0);
      expect(promedioLineaBase([12, 12, 12, 12, 12, 12, 12]), 1200);
      expect(promedioLineaBase([10, 10, 10, 10, 10]), 1000);
      expect(promedioLineaBase([10, 10, 10, 10]), isNull);
      expect(promedioLineaBase(const []), isNull);
      expect(promedioLineaBase([12, 12, 12, 12, 12, 12, 11]), 1186); // 11.857 -> 11.86
    });

    test('ahorro: exacto en centavos, oculto no negativo, sin dividir entre cero', () {
      expect(ahorroDia(promedioCentesimas: 1200, consumoDia: 0, precioCajetillaCentavos: 15000, cigarrillosPorCajetilla: 20), 9000);
      expect(ahorroDia(promedioCentesimas: 1200, consumoDia: 20, precioCajetillaCentavos: 15000, cigarrillosPorCajetilla: 20), 0);
      expect(ahorroDia(promedioCentesimas: 1200, consumoDia: 0, precioCajetillaCentavos: 15000, cigarrillosPorCajetilla: 0), 0);
      expect(ahorroDia(promedioCentesimas: 1200, consumoDia: 0, precioCajetillaCentavos: 0, cigarrillosPorCajetilla: 20), 0);
    });

    test('racha libre, recaída y apoyo en el borde de los 14 días', () {
      final diaD = DateTime.utc(2026, 11, 30);
      final r = calcularRachaLibre(diaD: diaD, hoy: DateTime.utc(2026, 12, 6), consumoPorDia: {DateTime.utc(2026, 12, 5): 1});
      expect((r.actual, r.mejor, r.acumulados), (1, 5, 6));
      final hoy = DateTime.utc(2026, 12, 20);
      expect(sugerirApoyo([DateTime.utc(2026, 12, 7), DateTime.utc(2026, 12, 8), DateTime.utc(2026, 12, 20)], hoy), isTrue); // el día -13 aún cuenta
      expect(sugerirApoyo([DateTime.utc(2026, 12, 6), DateTime.utc(2026, 12, 8), DateTime.utc(2026, 12, 20)], hoy), isFalse); // el día -14 queda fuera
      expect(sugerirApoyo([DateTime.utc(2026, 12, 7), DateTime.utc(2026, 12, 20)], hoy), isFalse);
    });

    test('semáforo del refresco: límites 4, 1 y 0', () {
      SemaforoHabito s(int u, int l) => semaforoAzucar(u, l);
      expect([for (var u = 0; u <= 5; u++) s(u, 4)], [
        SemaforoHabito.verde, SemaforoHabito.verde, SemaforoHabito.verde,
        SemaforoHabito.ambar, SemaforoHabito.ambar, SemaforoHabito.terracota,
      ]);
      expect([s(0, 1), s(1, 1), s(2, 1)], [SemaforoHabito.verde, SemaforoHabito.ambar, SemaforoHabito.terracota]);
      expect([s(0, 0), s(1, 0)], [SemaforoHabito.verde, SemaforoHabito.terracota]);
    });
  });

  group('carga y planes', () {
    test('carga 50/85 % en los bordes exactos y sin horas libres', () {
      NivelCarga c(int libres, int prog) => medirCarga(libres: libres, programados: prog);
      expect([c(200, 99), c(200, 100), c(200, 170), c(200, 171)],
          [NivelCarga.ligero, NivelCarga.equilibrado, NivelCarga.equilibrado, NivelCarga.saturado]);
      expect(c(0, 0), NivelCarga.saturado);
      expect(c(-30, 0), NivelCarga.saturado);
      expect(minutosLibres(despertarMin: 360, dormirMin: 1320, fijosMin: 480), 480);
    });

    test('los planes suman 260 y 1 189 capítulos y cierran la fecha final', () {
      final nt = generarPlan(TipoPlan.nt90, DateTime(2028, 2, 20));
      expect(nt.dias.length, 90);
      expect(nt.totalCapitulos, 260);
      expect(nt.dias.where((x) => x.capitulos.length == 3).length, 80);
      expect(nt.dias.where((x) => x.capitulos.length == 2).length, 10);
      final b = generarPlan(TipoPlan.biblia1Ano, DateTime(2027, 12, 1));
      expect(b.dias.length, 365);
      expect(b.totalCapitulos, 1189);
      expect(b.dias.where((x) => x.capitulos.length == 4).length, 94);
      expect(b.dias.where((x) => x.capitulos.length == 3).length, 271);
      // sin repetir un capítulo ni saltarse uno
      final vistos = {for (final x in b.dias) ...x.capitulos};
      expect(vistos.length, 1189);
      final ruta = generarPlan(TipoPlan.rutaInicio, DateTime(2026, 11, 2));
      expect(ruta.dias.length, 21);
      expect(ruta.totalCapitulos, 21);
    });

    test('solo lunes a viernes: ninguna lectura cae en fin de semana', () {
      final p = generarPlan(TipoPlan.nt90, DateTime(2026, 11, 7), mascaraDias: 31);
      for (final x in p.dias) {
        expect(x.fecha.weekday <= DateTime.friday, isTrue, reason: '${x.fecha}');
      }
      expect(p.dias.first.fecha, DateTime.utc(2026, 11, 9)); // sábado -> lunes
    });
  });
}
