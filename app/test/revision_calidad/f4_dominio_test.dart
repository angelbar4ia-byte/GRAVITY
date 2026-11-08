// REVISIÓN DE CALIDAD · FASE 4 (docs/revisiones/fase-4.md) · dominio.
//
// Pruebas de propiedades (entradas al azar con semilla fija) sobre el ahorro
// automático del cierre de semana (E16, D25) y sobre el motivo de 3
// caracteres. Lo que se vigila:
//  - nunca se aparta más que el remanente ni queda negativo;
//  - cada origen respeta su tope (extras: 20 % por omisión; sobre: lo
//    disponible; redondeo: nunca deja la semana en negativo);
//  - con una deuda que recibe abono extra solo cuenta el fondo de emergencia;
//  - el orden de prioridad que arrastra la persona manda al sobrante;
//  - los ids del cierre son estables y distintos por origen y bolsa;
//  - el motivo: la regla de la app es más estricta que la del servidor
//    (hallazgo F4-M1, ver supabase/tests/hallazgos_fase4.sql).
//
// Excluir los hallazgos: flutter test --exclude-tags hallazgo
library;

import 'dart:math';

import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/finanzas/casos_uso/servicio_fase2.dart';

BolsaAhorro _bolsa(
  String id,
  List<MetodoAhorro> metodos, {
  TipoBolsaAhorro tipo = TipoBolsaAhorro.metaLibre,
  int? aportePb,
  int multiplo = 1000,
  int prioridad = 1,
}) => BolsaAhorro(
  id: id,
  libroId: 'l',
  nombre: id,
  tipo: tipo,
  cuentaId: 'c-$id',
  metodos: metodos,
  aportePb: aportePb,
  redondeoMultiplo: multiplo,
  prioridad: prioridad,
);

void main() {
  group('Cierre de semana: propiedades', () {
    final azar = Random(20261107);
    final todos = MetodoAhorro.values;

    test('2 000 cierres al azar: nunca se aparta de más ni queda negativo', () {
      for (var i = 0; i < 2000; i++) {
        final bolsas = [
          for (var b = 0; b < 1 + azar.nextInt(4); b++)
            _bolsa(
              'b$b',
              [
                for (final m in todos)
                  if (azar.nextBool()) m,
              ],
              tipo: azar.nextInt(4) == 0
                  ? TipoBolsaAhorro.fondoEmergencia
                  : TipoBolsaAhorro.metaLibre,
              aportePb: azar.nextBool() ? 500 * azar.nextInt(20) : null,
              multiplo: [100, 500, 1000, 5000][azar.nextInt(4)],
              prioridad: 1 + azar.nextInt(3),
            ),
        ];
        final remanente = azar.nextInt(400000) - 50000;
        final extras = azar.nextInt(300000);
        final sobre = azar.nextInt(60000);
        final gastos = [
          for (var g = 0; g < azar.nextInt(30); g++) 1 + azar.nextInt(90000),
        ];
        final deuda = azar.nextInt(4) == 0;
        final minimo = azar.nextInt(3000);
        final plan = planearAhorroDeCierre(
          remanente: remanente,
          bolsas: bolsas,
          extras: extras,
          sobre: sobre,
          gastos: gastos,
          hayDeudaConExtra: deuda,
          ahorroMinimoConDeudaPuntosBase: minimo,
        );
        final contexto = 'caso $i remanente=$remanente deuda=$deuda';
        if (remanente <= 0) {
          expect(plan.aportes, isEmpty, reason: contexto);
          continue;
        }
        expect(plan.total, lessThanOrEqualTo(remanente), reason: contexto);
        expect(plan.disponibleFinal, greaterThanOrEqualTo(0), reason: contexto);
        for (final a in plan.aportes) {
          expect(a.monto, greaterThan(0), reason: contexto);
        }
        expect(
          plan.deOrigen(OrigenAporte.sobre),
          lessThanOrEqualTo(sobre),
          reason: contexto,
        );
        if (deuda) {
          // Regla 16: solo el fondo de emergencia, y solo el mínimo.
          final tope = aplicarPorcentaje(remanente, minimo);
          expect(plan.total, lessThanOrEqualTo(tope), reason: contexto);
          for (final a in plan.aportes) {
            final b = bolsas.firstWhere((x) => x.id == a.bolsaId);
            expect(b.tipo, TipoBolsaAhorro.fondoEmergencia, reason: contexto);
          }
        }
        // El orden de aplicación es el del enum: extras, sobre, sobrante,
        // redondeo.
        final indices = [for (final a in plan.aportes) a.origen.index];
        expect(indices, [...indices]..sort(), reason: contexto);
        // Solo un aporte de sobrante (va a una sola bolsa, D25).
        expect(
          plan.aportes.where((a) => a.origen == OrigenAporte.sobrante).length,
          lessThanOrEqualTo(1),
          reason: contexto,
        );
      }
    });

    test('los extras apartan el 20 % por omisión y 0 si no hubo extras', () {
      final b = _bolsa('a', [MetodoAhorro.porcentajeDeExtras]);
      expect(
        planearAhorroDeCierre(
          remanente: 100000,
          bolsas: [b],
          extras: 50000,
        ).deOrigen(OrigenAporte.extras),
        10000,
      );
      expect(
        planearAhorroDeCierre(remanente: 100000, bolsas: [b]).aportes,
        isEmpty,
      );
      // Redondeo al centavo más cercano; nunca más que lo disponible.
      expect(
        planearAhorroDeCierre(remanente: 5, bolsas: [b], extras: 1000).total,
        lessThanOrEqualTo(5),
      );
    });

    test(
      'el orden que arrastra la persona manda: el sobrante va a la primera',
      () {
        final a = _bolsa('a', [MetodoAhorro.sobranteSemanal], prioridad: 1);
        final c = _bolsa('c', [MetodoAhorro.sobranteSemanal], prioridad: 2);
        expect(
          planearAhorroDeCierre(remanente: 9000, bolsas: [a, c]).aportadoA('a'),
          9000,
        );
        final arrastrado = planearAhorroDeCierre(
          remanente: 9000,
          bolsas: [a, c],
          orden: ['c', 'a'],
        );
        expect(arrastrado.aportadoA('c'), 9000);
        expect(arrastrado.aportadoA('a'), 0);
      },
    );

    test('es determinista: el mismo cierre da el mismo plan', () {
      final bolsas = [
        _bolsa('a', [MetodoAhorro.porcentajeDeExtras, MetodoAhorro.redondeo]),
        _bolsa('b', [MetodoAhorro.sobranteSemanal], prioridad: 2),
      ];
      String huella() => planearAhorroDeCierre(
        remanente: 77777,
        bolsas: bolsas,
        extras: 33333,
        gastos: [1234, 5678, 9999],
      ).aportes.join('|');
      expect(huella(), huella());
    });

    test('ids estables y distintos por cierre, origen y bolsa', () {
      final ids = <String>{};
      for (final cierre in ['c1', 'c2']) {
        for (final o in OrigenAporte.values) {
          for (final b in ['a', 'b', 'a-b', 'a_b']) {
            final id = ServicioDeudasAhorro.idAporteAutomatico(cierre, o, b);
            expect(
              id,
              ServicioDeudasAhorro.idAporteAutomatico(cierre, o, b),
              reason: 'estable',
            );
            expect(ids.add(id), isTrue, reason: 'único: $cierre ${o.clave} $b');
          }
        }
      }
    });
  });

  group('Motivo de 3 caracteres', () {
    test('la regla de la app (guardia)', () {
      for (final bueno in ['abc', 'a b c', ' ok! ', '1.2', 'é-é', 'a b!']) {
        expect(motivoValido(bueno), isTrue, reason: '"$bueno"');
      }
      for (final malo in [
        '',
        '  ',
        'ab',
        'a b',
        '___',
        '...',
        '---',
        'aaa',
        '!!a',
        'a​b',
        'ㅤㅤㅤ',
        '\t\n  \r',
      ]) {
        expect(motivoValido(malo), isFalse, reason: '"$malo"');
      }
    });
  });
}
