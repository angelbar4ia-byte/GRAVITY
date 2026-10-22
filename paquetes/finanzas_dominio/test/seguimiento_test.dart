// Seguimiento de la semana de un libro: plan desde la configuración y desde
// la foto, lo real, el flujo, los indicadores y el cierre (5.6 bis, 5.9 bis).
import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:test/test.dart';

import 'hogar_ejemplo.dart';

void main() {
  final semana = Semana.de(Fecha(2026, 10, 26));
  var siguiente = 0;
  String generarId() => 'gen-${siguiente++}';

  group('Plan desde la configuración (5.6 bis-1)', () {
    test('la cascada del ejemplo del diseño', () {
      final plan = armarPlanDelLibro(hogarEjemplo(), casa, semana).plan;
      expect(plan.ingreso, 738462);
      expect(plan.presupuesto, 547231);
      expect(plan.deudaPlaneada, 39231);
      expect(plan.remanente, 152000);
      expect(plan.metaRemanente, 147692);
      expect(plan.techo, 551539);
      expect(plan.tasaRemanentePuntosBase, 2058);
    });

    test('cada libro arma su propio plan', () {
      final d = hogarEjemplo();
      expect(armarPlanDelLibro(d, libroAna, semana).plan.ingreso, 0);
      expect(
        armarPlanDelLibro(d, libroPapa, semana).plan.ingreso,
        greaterThan(0),
      );
    });

    test('una deuda ya pagada libera su abono (no entra al plan)', () {
      final d = hogarEjemplo(
        movimientos: [
          Movimiento(
            id: 'liquida-familiar',
            tipo: TipoMovimiento.pagoDeuda,
            fecha: Fecha(2026, 10, 20),
            registradoEn: DateTime(2026, 10, 20, 9),
            cuentaOrigenId: 'banco-casa',
            cuentaDestinoId: 'prestamo-fam',
            monto: 300000,
            realizadoPor: ana,
          ),
        ],
      );
      final p = armarPlanDelLibro(d, casa, semana);
      expect(p.liberadas.single.deuda.id, 'deuda-familiar');
      expect(p.abonoLiberado, 11538);
      expect(p.plan.deudaPlaneada, 27692);
      expect(
        p.plan.remanente,
        152000 + 11539,
        reason: 'el remanente crece con el abono liberado',
      );
    });
  });

  group('Vista de la semana', () {
    test('T1 y T2: con \$300 de más en Alimentación el remanente queda en '
        '16.52 % (ámbar) y la acción dice dónde y cuánto', () {
      final d = hogarEjemplo(
        movimientos: [
          gasto('super', Fecha(2026, 10, 27), 180000, 'g-alimentacion'),
        ],
      );
      final v = vistaSemana(d, casa, semana, hoy: Fecha(2026, 10, 28));
      expect(v.estado, EstadoSemana.borrador);
      expect(v.real.remanenteReal, 122000);
      final ind = v.indicadores;
      expect(ind.remanentePuntosBase, 1652);
      expect(ind.remanente, Semaforo.ambar);
      expect(ind.cargaDeudaPuntosBase, 531);
      expect(ind.cargaDeuda, Semaforo.verde);
      final desvio = v.desvios().first;
      expect(desvio.partida.nombre, 'Alimentación');
      expect(desvio.diferencia, 30000);
    });

    test('sin gastos de más: remanente 20.58 % en verde', () {
      final v = vistaSemana(
        hogarEjemplo(),
        casa,
        semana,
        hoy: Fecha(2026, 10, 28),
      );
      expect(v.indicadores.remanentePuntosBase, 2058);
      expect(v.indicadores.remanente, Semaforo.verde);
    });

    test(
      '5.6 bis-3: la semana del 26/oct entra \$0 y sale \$8,000, con alerta',
      () {
        final v = vistaSemana(
          hogarEjemplo(),
          casa,
          semana,
          hoy: Fecha(2026, 10, 26),
        );
        final s = v.flujo.semanas.first;
        expect(s.semana, semana);
        expect(s.entradas, 0);
        expect(s.salidas, 800000);
        expect(v.flujo.semanas[1].entradas, 2300000);
        expect(v.flujo.hayAlerta, isTrue);
        expect(v.flujo.primerDiaEnRiesgo!.fecha, Fecha(2026, 11, 1));
        expect(v.siguienteAccion.tipo, TipoAccionSugerida.revisarFlujo);
        expect(v.siguienteAccion.monto, 500000 - 800000);
      },
    );

    test('lo que vence esta semana, con el día hábil ajustado', () {
      final v = vistaSemana(
        hogarEjemplo(),
        casa,
        semana,
        hoy: Fecha(2026, 10, 26),
      );
      expect(v.vencimientos.map((x) => x.concepto), ['Renta']);
      final siguienteSemana = vencimientosEntre(
        hogarEjemplo(),
        casa,
        Fecha(2026, 11, 2),
        Fecha(2026, 11, 8),
      );
      final ana = siguienteSemana.firstWhere((x) => x.origenId == 'ing-ana');
      expect(ana.fecha.programada, Fecha(2026, 10, 31));
      expect(ana.fecha.ajustada, Fecha(2026, 11, 2));
    });

    test('pagar la renta completa no es sobregasto; una luz más cara sí '
        '(regla 33)', () {
      final d = hogarEjemplo(
        movimientos: [
          gasto(
            'renta',
            Fecha(2026, 11, 1),
            800000,
            'g-vivienda',
            categoria: 'c-renta',
          ),
          gasto(
            'luz',
            Fecha(2026, 10, 27),
            110000,
            'g-vivienda',
            categoria: 'c-luz',
          ),
        ],
      );
      final v = vistaSemana(d, casa, semana, hoy: Fecha(2026, 11, 1));
      final renta = v.real.partidas.firstWhere((p) => p.partida.id == 'renta');
      final luz = v.real.partidas.firstWhere((p) => p.partida.id == 'luz');
      expect(renta.sobregasto, 0);
      expect(v.gasto.pagadoPorPartida['renta'], 800000);
      expect(
        luz.gastado - luz.asignado,
        20000,
        reason: 'la luz llegó \$200 más cara',
      );
    });

    test('un extra cuenta en su semana y un ingreso que no llegó resta', () {
      final d =
          hogarEjemplo(
            movimientos: [
              Movimiento(
                id: 'extra',
                tipo: TipoMovimiento.ingreso,
                fecha: Fecha(2026, 10, 28),
                registradoEn: DateTime(2026, 10, 28, 9),
                cuentaOrigenId: 'extras-casa',
                cuentaDestinoId: 'banco-casa',
                monto: 50000,
                realizadoPor: ana,
              ),
            ],
          ).copiar(
            ocurrencias: [
              Ocurrencia(
                id: 'o1',
                libroId: casa,
                origen: OrigenOcurrencia.ingreso,
                origenId: 'ing-alex',
                fechaProgramada: Fecha(2026, 10, 31),
                fechaAjustada: Fecha(2026, 10, 30),
                montoEsperado: 1400000,
                estado: EstadoOcurrencia.noLlegara,
              ),
            ],
          );
      final v = vistaSemana(d, casa, semana, hoy: Fecha(2026, 10, 30));
      expect(v.ingresoReal, 738462 + 50000 - 1400000);
      expect(v.real.deficit, greaterThan(0));
    });
  });

  group('Activar y cerrar', () {
    DatosFinanzas activada(DatosFinanzas d) {
      final plan = armarPlanDelLibro(d, casa, semana);
      final foto = fotoDelPlan(
        plan,
        id: 'sem-1',
        libroId: casa,
        arrastrePorOrigen: arrastresPorOrigen(d, casa, semana),
        activadaPor: ana,
        activadaEn: DateTime(2026, 10, 26, 8),
        generarId: generarId,
      );
      return d.copiar(semanas: [...d.semanas, foto]);
    }

    test('la foto guarda los mismos totales y la vista la usa', () {
      final d = activada(hogarEjemplo());
      final g = d.semanaGuardada(casa, semana)!;
      expect(
        (g.ingreso, g.presupuesto, g.deudaPlan, g.remanentePlan, g.techo),
        (738462, 547231, 39231, 152000, 551539),
      );
      expect(g.partidas, hasLength(13));
      expect(g.partidas.fold(0, (t, p) => t + p.asignado), 547231);
      final v = vistaSemana(d, casa, semana, hoy: Fecha(2026, 10, 28));
      expect(v.plan.desdeFoto, isTrue);
      expect(v.estado, EstadoSemana.activa);
      expect(v.planSemanal.remanente, 152000);
      expect(v.planSemanal.deudaPlaneada, 39231);
    });

    test('un cambio de configuración a mitad de semana no mueve la foto', () {
      final d = activada(hogarEjemplo());
      final cambiado = d.copiar(
        sobres: [
          for (final s in d.sobres)
            s.id == 'alimentacion' ? s.conMonto(200000) : s,
        ],
      );
      final v = vistaSemana(cambiado, casa, semana, hoy: Fecha(2026, 10, 28));
      expect(v.planSemanal.presupuesto, 547231);
      expect(v.planConfiguracion.plan.presupuesto, 597231);
    });

    test(
      'al pasar el domingo queda por cerrar y a los 3 días se cierra sola',
      () {
        final d = activada(hogarEjemplo());
        expect(
          vistaSemana(d, casa, semana, hoy: Fecha(2026, 11, 2)).estado,
          EstadoSemana.porCerrar,
        );
        expect(
          vistaSemana(
            d,
            casa,
            semana,
            hoy: Fecha(2026, 11, 4),
          ).debeCerrarseSola,
          isFalse,
        );
        expect(
          vistaSemana(
            d,
            casa,
            semana,
            hoy: Fecha(2026, 11, 5),
          ).debeCerrarseSola,
          isTrue,
        );
      },
    );

    test('el cierre guarda el abono extra, el arrastre y el balance; la '
        'semana siguiente recibe el arrastre', () {
      var d = activada(
        hogarEjemplo(
          movimientos: [
            gasto('super', Fecha(2026, 10, 27), 180000, 'g-alimentacion'),
          ],
        ),
      );
      final v = vistaSemana(d, casa, semana, hoy: Fecha(2026, 11, 2));
      final cierre = cierreDeLaVista(
        v,
        d,
        id: 'cierre-1',
        accion: AccionCierre.sinAplicar,
        cerradoPor: ana,
        cerradoEn: DateTime(2026, 11, 2, 9),
      );
      expect(cierre.version, 1);
      expect(cierre.remanenteReal, 122000);
      expect(
        cierre.abonoExtraReal,
        122000,
        reason: 'sin grupo: a la tarjeta, la de mayor costo',
      );
      expect(cierre.abonoDiferido, 0);
      expect(cierre.patrimonio, 500000 - 180000 - 600000 - 300000);
      d = d.copiar(
        cierres: [cierre],
        semanas: [
          for (final s in d.semanas)
            s.id == 'sem-1' ? s.conEstado(EstadoSemana.cerrada) : s,
        ],
      );
      final arrastres = arrastresPorOrigen(d, casa, semana.siguiente);
      expect(arrastres['transporte'], 70000);
      expect(arrastres.containsKey('alimentacion'), isFalse);
      final siguienteVista = vistaSemana(
        d,
        casa,
        semana.siguiente,
        hoy: Fecha(2026, 11, 3),
      );
      expect(siguienteVista.arrastreRecibido['transporte'], 70000);
      expect(siguienteVista.patrimonioAnterior, cierre.patrimonio);
    });

    test('reabrir suma una reapertura y el cierre siguiente es la versión '
        'reaperturas + 1 (como exige el servidor)', () {
      var d = activada(hogarEjemplo());
      final g = d.semanaGuardada(casa, semana)!;
      expect(g.reaperturas, 0);
      expect(g.versionDelSiguienteCierre, 1);
      CierreGuardado cerrar(DatosFinanzas d, String id) => cierreDeLaVista(
        vistaSemana(d, casa, semana, hoy: Fecha(2026, 11, 2)),
        d,
        id: id,
        accion: AccionCierre.sinAplicar,
        cerradoPor: ana,
        cerradoEn: DateTime(2026, 11, 2, 9),
      );
      final primero = cerrar(d, 'cierre-1');
      expect(primero.version, 1);
      final cerrada = g.conEstado(EstadoSemana.cerrada);
      expect(cerrada.reaperturas, 0, reason: 'cerrar no es reabrir');
      final reabierta = cerrada.conEstado(EstadoSemana.activa);
      expect(reabierta.reaperturas, 1);
      expect(
        reabierta.conEstado(EstadoSemana.porCerrar).reaperturas,
        1,
        reason: 'cambiar de estado sin estar cerrada no suma',
      );
      d = d.copiar(semanas: [reabierta], cierres: [primero]);
      expect(cerrar(d, 'cierre-2').version, 2);
    });

    test('con idPara, la foto lleva ids estables: guardarla otra vez no '
        'choca con los únicos de partidas y abonos', () {
      final d = hogarEjemplo();
      SemanaGuardada foto() => fotoDelPlan(
        armarPlanDelLibro(d, casa, semana),
        id: 'sem-estable',
        libroId: casa,
        arrastrePorOrigen: const {},
        activadaPor: ana,
        activadaEn: DateTime(2026, 10, 26, 8),
        idPara: (clave) => 'id:$clave',
      );
      final a = foto();
      final b = foto();
      expect(a.partidas.map((p) => p.id), b.partidas.map((p) => p.id));
      expect(a.abonos.map((x) => x.id), b.abonos.map((x) => x.id));
      expect(
        a.partidas.first.id,
        startsWith('id:partida:sem-estable:'),
      );
      expect(a.abonos.map((x) => x.id), contains('id:abono:sem-estable:deuda-tarjeta'));
      expect(a.partidas.map((p) => p.id).toSet(), hasLength(a.partidas.length));
      expect(
        () => fotoDelPlan(
          armarPlanDelLibro(d, casa, semana),
          id: 'x',
          libroId: casa,
          arrastrePorOrigen: const {},
          activadaPor: ana,
          activadaEn: DateTime(2026, 10, 26, 8),
        ),
        throwsArgumentError,
      );
    });
  });

  test('T8: un mes con 5 lunes se muestra por semanas con promedio', () {
    // Noviembre de 2026 tiene 5 lunes: 2, 9, 16, 23 y 30.
    final d = hogarEjemplo(
      movimientos: [
        gasto('a', Fecha(2026, 11, 3), 100000, 'g-alimentacion'),
        gasto('b', Fecha(2026, 11, 30), 50000, 'g-alimentacion'),
      ],
    );
    final mes = gastoDelMesPorSemanas(d, casa, 2026, 11);
    expect(mes.semanas, hasLength(5));
    expect(mes.total, 150000);
    expect(mes.promedioSemanal, 30000);
  });
}
