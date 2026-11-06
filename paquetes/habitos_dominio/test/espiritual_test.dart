import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

void main() {
  test('canon', () {
    expect(canon.length, 66);
    expect(capitulosDe(1, 39).length, 929);
    expect(capitulosDe(40, 66).length, 260);
    expect(capitulosDe(1, 66).length, 1189);
    expect(canon[42].nombre, 'Juan');
    expect(canon[42].numero, 43);
  });

  test('referencias', () {
    final a = analizarReferencia('Juan 3:16')!;
    expect([a.libro, a.capIni, a.verIni, a.verFin], [43, 3, 16, null]);
    final b = analizarReferencia('Jn 3:16-18')!;
    expect([b.verIni, b.verFin], [16, 18]);
    expect(analizarReferencia('1 Corintios 13')!.libro, 46);
    final c = analizarReferencia('1 Co 13:4–7')!;
    expect([c.libro, c.capIni, c.verIni, c.verFin], [46, 13, 4, 7]);
    expect(analizarReferencia('Sal 23')!.libro, 19);
    final g = analizarReferencia('Génesis 1:1-2:3')!;
    expect([g.libro, g.capIni, g.verIni, g.capFin, g.verFin], [1, 1, 1, 2, 3]);
    expect(analizarReferencia('Juan 99'), isNull);
    expect(analizarReferencia('Xyz 1'), isNull);
    expect(buscarLibro('Genesis')!.numero, 1);
    expect(a.codigo, '43:3:16-16');
  });

  int cuenta(PlanLectura p, int n) =>
      p.dias.where((d) => d.capitulos.length == n).length;

  test('planes de lectura', () {
    final i = dia(2026, 11, 2);
    final ruta = generarPlan(TipoPlan.rutaInicio, i);
    expect(ruta.dias.length, 21);
    expect(ruta.dias.every((d) => d.capitulos.length == 1), isTrue);
    expect(ruta.dias.first.capitulos.first, const Capitulo(43, 1));
    expect(ruta.dias.last.capitulos.first, const Capitulo(43, 21));
    final nt = generarPlan(TipoPlan.nt90, i);
    expect([cuenta(nt, 3), cuenta(nt, 2), nt.totalCapitulos], [80, 10, 260]);
    final b = generarPlan(TipoPlan.biblia1Ano, i);
    expect([cuenta(b, 4), cuenta(b, 3), b.totalCapitulos], [94, 271, 1189]);
    final sp = generarPlan(TipoPlan.salmosProverbios30, i);
    expect(sp.dias.length, 30);
    expect(sp.dias[0].capitulos.length, 6);
    expect(sp.dias[29].capitulos.length, 7);
    expect(sp.totalCapitulos, 181);
    final l = generarPlan(TipoPlan.libro, i, libro: 19, capitulosPorDia: 5);
    expect(l.dias.length, 30);
    expect(generarPlan(TipoPlan.rutaInicio, i, mascaraDias: 31).dias[5].fecha,
        dia(2026, 11, 9));
  });

  test('generarPlan rechaza máscara 0, libro inválido y ritmo 0', () {
    final i = dia(2026, 11, 2);
    expect(() => generarPlan(TipoPlan.rutaInicio, i, mascaraDias: 0), throwsArgumentError);
    expect(() => generarPlan(TipoPlan.libro, i), throwsArgumentError);
    expect(() => generarPlan(TipoPlan.libro, i, libro: 67), throwsArgumentError);
    expect(() => generarPlan(TipoPlan.libro, i, libro: 1, capitulosPorDia: 0), throwsArgumentError);
  });

  test('ponerse al día: K=4 y K=7', () {
    for (final k in [4, 7]) {
      final p = generarPlan(TipoPlan.rutaInicio, dia(2026, 11, 2));
      for (var d = 0; d < 3; d++) {
        p.dias[d].estado = EstadoDiaPlan.hecho;
      }
      final hoy = dia(2026, 11, 9); // día 8
      ponerAlDia(p, hoy, k);
      final n = p.dias.sublist(7, 14).map((d) => d.capitulos.length).toList();
      expect(n, k == 4 ? [2, 2, 2, 2, 1, 1, 1] : [2, 2, 2, 2, 1, 1, 1]);
      expect(p.dias.last.fecha, dia(2026, 11, 22)); // fecha final intacta
      expect(p.totalCapitulos, 25); // los 4 movidos se cuentan dos veces en bruto
    }
  });

  test('saltar y reiniciar', () {
    final p = generarPlan(TipoPlan.rutaInicio, dia(2026, 11, 2));
    saltarAtrasados(p, dia(2026, 11, 9));
    expect(p.dias.take(7).every((d) => d.estado == EstadoDiaPlan.saltado), isTrue);
    expect(p.avancePct(), 0);
    final q = generarPlan(TipoPlan.rutaInicio, dia(2026, 11, 2));
    reiniciarTramo(q, dia(2026, 11, 9), 127);
    expect(q.dias.first.fecha, dia(2026, 11, 9));
    expect(q.dias.last.fecha, dia(2026, 11, 29));
  });
}
