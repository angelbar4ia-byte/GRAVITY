import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:test/test.dart';

void main() {
  group('Fecha', () {
    test('valida que la fecha exista', () {
      expect(() => Fecha(2026, 2, 30), throwsArgumentError);
      expect(() => Fecha(2026, 13, 1), throwsArgumentError);
      expect(Fecha(2028, 2, 29).toString(), '2028-02-29');
    });

    test('día de la semana ISO (1 = lunes)', () {
      expect(Fecha(2026, 10, 31).diaSemana, DateTime.saturday);
      expect(Fecha(2026, 11, 1).diaSemana, DateTime.sunday);
      expect(Fecha(2026, 11, 2).diaSemana, DateTime.monday);
      expect(Fecha(2026, 10, 31).esFinDeSemana, isTrue);
    });

    test('aritmética sin horario de verano', () {
      expect(Fecha(2026, 10, 31).sumarDias(2), Fecha(2026, 11, 2));
      expect(Fecha(2026, 3, 1).sumarDias(-1), Fecha(2026, 2, 28));
      expect(Fecha(2026, 1, 1).diasHasta(Fecha(2026, 12, 31)), 364);
      expect(Fecha.parse('2026-10-26'), Fecha(2026, 10, 26));
    });

    test('día del mes que no existe se va al último', () {
      expect(Fecha.enMes(2026, 4, 31), Fecha(2026, 4, 30));
      expect(Fecha.enMes(2026, 2, 31), Fecha(2026, 2, 28));
      expect(Fecha.enMes(2026, 13, 15), Fecha(2027, 1, 15));
    });
  });

  group('Semana (lunes a domingo)', () {
    test('a qué semana pertenece una fecha', () {
      final semana = Semana.de(Fecha(2026, 10, 29)); // jueves
      expect(semana.inicio, Fecha(2026, 10, 26)); // lunes
      expect(semana.fin, Fecha(2026, 11, 1)); // domingo
      expect(
        Semana.de(Fecha(2026, 11, 1)),
        semana,
      ); // el domingo es de la misma
      expect(Semana.de(Fecha(2026, 11, 2)), semana.siguiente); // el lunes no
    });

    test('contiene sus siete días', () {
      final semana = Semana.de(Fecha(2026, 10, 26));
      expect(semana.dias.length, 7);
      expect(semana.contiene(Fecha(2026, 10, 26)), isTrue);
      expect(semana.contiene(Fecha(2026, 11, 1)), isTrue);
      expect(semana.contiene(Fecha(2026, 11, 2)), isFalse);
      expect(semana.contiene(Fecha(2026, 10, 25)), isFalse);
    });

    test('número de semana ISO', () {
      expect(Semana.de(Fecha(2026, 10, 26)).numeroIso, 44);
      expect(Semana.de(Fecha(2026, 1, 1)).numeroIso, 1); // jueves
      expect(Semana.de(Fecha(2026, 1, 1)).inicio, Fecha(2025, 12, 29));
    });

    test('semanas que cruzan el año', () {
      // 2026 empieza en jueves: tiene 53 semanas ISO.
      final finDeAnio = Semana.de(Fecha(2027, 1, 1));
      expect(finDeAnio.anioIso, 2026);
      expect(finDeAnio.numeroIso, 53);
      expect(Semana.semanasIsoDelAnio(2026), 53);
      // El lunes 30/dic/2024 ya es la semana 1 de 2025.
      final s = Semana.de(Fecha(2024, 12, 30));
      expect(s.anioIso, 2025);
      expect(s.numeroIso, 1);
      expect(Semana.semanasIsoDelAnio(2025), 52);
    });

    test('semana por número ISO', () {
      expect(Semana.iso(2026, 44).inicio, Fecha(2026, 10, 26));
      expect(Semana.iso(2025, 1).inicio, Fecha(2024, 12, 30));
      expect(() => Semana.iso(2025, 53), throwsArgumentError);
    });

    test('navegar entre semanas', () {
      final s = Semana.de(Fecha(2026, 10, 26));
      expect(s.mas(2).inicio, Fecha(2026, 11, 9));
      expect(s.anterior.inicio, Fecha(2026, 10, 19));
      expect(s.semanasHasta(s.mas(5)), 5);
      expect(s.compareTo(s.siguiente), lessThan(0));
    });
  });

  group('Periodos de visualización', () {
    test('quincena del calendario (1–15 y 16–fin)', () {
      expect(
        Periodo.quincena(Fecha(2026, 11, 10)),
        Periodo(Fecha(2026, 11, 1), Fecha(2026, 11, 15)),
      );
      expect(
        Periodo.quincena(Fecha(2026, 11, 16)),
        Periodo(Fecha(2026, 11, 16), Fecha(2026, 11, 30)),
      );
      expect(Periodo.quincena(Fecha(2026, 2, 20)).fin, Fecha(2026, 2, 28));
    });

    test('catorcena desde la fecha ancla, antes y después', () {
      final ancla = Fecha(2026, 10, 2);
      expect(
        Periodo.catorcena(Fecha(2026, 10, 20), ancla: ancla),
        Periodo(Fecha(2026, 10, 16), Fecha(2026, 10, 29)),
      );
      expect(
        Periodo.catorcena(Fecha(2026, 9, 30), ancla: ancla),
        Periodo(Fecha(2026, 9, 18), Fecha(2026, 10, 1)),
      );
      expect(Periodo.catorcena(ancla, ancla: ancla).inicio, ancla);
    });

    test('mes natural y semana', () {
      expect(Periodo.mes(Fecha(2026, 11, 2)).numeroDeDias, 30);
      expect(
        Periodo.de(TipoPeriodo.semana, Fecha(2026, 10, 29)),
        Periodo(Fecha(2026, 10, 26), Fecha(2026, 11, 1)),
      );
      expect(
        () => Periodo.de(TipoPeriodo.catorcena, Fecha(2026, 10, 29)),
        throwsArgumentError,
      );
    });
  });
}
