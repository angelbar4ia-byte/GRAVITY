// Avisos que emite la app (flujo negativo y abono bajo el mínimo): discretos,
// sin dinero, con clave estable (Fase 4, E16).
import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:test/test.dart';

import 'hogar_ejemplo.dart';

void main() {
  final semana = Semana.de(Fecha(2026, 10, 26));

  test('flujo negativo: un aviso por libro y semana, con clave estable', () {
    final v = vistaSemana(
      hogarEjemplo(),
      casa,
      semana,
      hoy: Fecha(2026, 10, 26),
    );
    final avisos = avisosPorEmitir(v);
    final flujo = avisos
        .where((a) => a.tipo == TipoAlerta.flujoNegativo)
        .toList();
    expect(flujo, hasLength(1));
    expect(flujo.single.objetoTipo, 'libro');
    expect(flujo.single.objetoId, casa);
    expect(flujo.single.clave, 'flujo_negativo:$casa:2026-10-26');
    // Calcular otra vez da la misma clave (idempotencia del servidor).
    expect(
      avisosPorEmitir(
        vistaSemana(hogarEjemplo(), casa, semana, hoy: Fecha(2026, 10, 27)),
      ).where((a) => a.tipo == TipoAlerta.flujoNegativo).single.clave,
      flujo.single.clave,
    );
  });

  test('abono bajo el mínimo: uno por deuda, objeto deuda', () {
    final base = hogarEjemplo(
      movimientos: [
        gasto('mucho', Fecha(2026, 10, 27), 5000000, 'g-alimentacion'),
      ],
    );
    // La tarjeta exige un mínimo semanal alto que el sobregasto no deja pagar.
    final d = base.copiar(
      deudas: [
        for (final x in base.deudas)
          x.id == 'deuda-tarjeta'
              ? Deuda(
                  id: x.id,
                  libroId: x.libroId,
                  nombre: x.nombre,
                  tipo: x.tipo,
                  cuentaPasivoId: x.cuentaPasivoId,
                  abono: x.abono,
                  minimo: 120000,
                  frecuencia: x.frecuencia,
                  calendario: x.calendario,
                  tasaAnualPuntosBase: x.tasaAnualPuntosBase,
                )
              : x,
      ],
    );
    final v = vistaSemana(d, casa, semana, hoy: Fecha(2026, 10, 30));
    final bajos = v.real.abonosBajoMinimo;
    expect(bajos, isNotEmpty, reason: 'el escenario debe dejar un abono bajo');
    final avisos = avisosPorEmitir(v)
        .where((a) => a.tipo == TipoAlerta.abonoBajoMinimo)
        .toList();
    expect(avisos.length, bajos.length);
    for (final a in avisos) {
      expect(a.objetoTipo, 'deuda');
      expect(a.clave, startsWith('abono_bajo_minimo:'));
      expect(a.clave, endsWith(':2026-10-26'));
    }
  });

  test('las claves cumplen lo que exige el servidor y los títulos son del '
      'catálogo sin dinero', () {
    final v = vistaSemana(
      hogarEjemplo(),
      casa,
      semana,
      hoy: Fecha(2026, 10, 26),
    );
    for (final a in avisosPorEmitir(v)) {
      expect(a.clave, matches(RegExp(r'^[a-z0-9_:.\-]+$')));
      expect(a.clave.length, lessThanOrEqualTo(120));
      expect(TextoAviso.esDiscreto(a.tipo.titulo), isTrue);
      expect(a.tipo.origen, OrigenAlerta.app);
    }
    expect(
      claveDeAviso(TipoAlerta.flujoNegativo, 'ABC dé', '2026-10-26'),
      'flujo_negativo:abc-d-:2026-10-26',
    );
    expect(
      claveDeAviso(TipoAlerta.flujoNegativo, 'x' * 300, '2026-10-26').length,
      120,
    );
  });
}
