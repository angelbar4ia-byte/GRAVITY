import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:test/test.dart';

void main() {
  group('Fondo de emergencia', () {
    test('5 niveles de 2, 4, 13, 26 y 52 semanas; por defecto 3 meses', () {
      expect(NivelFondo.values.map((n) => n.semanas), [2, 4, 13, 26, 52]);
      expect(NivelFondo.porDefecto, NivelFondo.tresMeses);
    });

    test('meta, semanas cubiertas hacia abajo y semaforo', () {
      expect(metaDelFondo(NivelFondo.tresMeses, 150000), 1950000);
      expect(textoSemanasCubiertas(semanasCubiertasDecimas(459999, 150000)!), '3.0');
      expect(semanasCubiertasDecimas(1, 0), isNull);
      expect(semaforoDelFondo(1950000, 1950000), Semaforo.verde);
      expect(semaforoDelFondo(975000, 1950000), Semaforo.ambar);
      expect(semaforoDelFondo(974999, 1950000), Semaforo.rojo);
      expect(semaforoDelFondo(1, 0), isNull);
    });

    test('gasto esencial: ultimas 8, segun tu plan, sin datos', () {
      final h = gastoEsencialSemanal(
        esencialesPorSemanaCerrada: [999999, ...List.filled(8, 100000)],
      );
      expect(h.semanal, 100000);
      expect(h.semanasUsadas, 8);
      final p = gastoEsencialSemanal(
        esencialesPorSemanaCerrada: [],
        presupuestoEsencial: 90000,
      );
      expect(p.rotulo, 'según tu plan');
      expect(gastoEsencialSemanal(esencialesPorSemanaCerrada: []).semanal, isNull);
    });

    test('nivel 4 sugerido con un ingreso o dependientes', () {
      expect(
        nivelSugeridoDelFondo(
          ingresosActivos: 1,
          soloIngresosInseguros: false,
          dependientesCuidados: false,
        ),
        NivelFondo.seisMeses,
      );
      expect(
        nivelSugeridoDelFondo(
          ingresosActivos: 2,
          soloIngresosInseguros: false,
          dependientesCuidados: false,
        ),
        NivelFondo.tresMeses,
      );
    });
  });

  group('Aportaciones y metodos', () {
    test('reserva anual entre 52', () {
      expect(aportacionDeReserva(520000), 10000);
    });

    test('meta con fecha: la ultima cuota absorbe la diferencia', () {
      final c = cuotasDeMetaConFecha(meta: 1000, saldo: 0, semanas: 3);
      expect(c, [333, 333, 334]);
      expect(c.fold(0, (a, b) => a + b), 1000);
      expect(aportacionDeMetaConFecha(meta: 1000, saldo: 1000, semanasRestantes: 3), 0);
    });

    test('reto de 52 semanas con base 10 pesos suma 13,780', () {
      expect(totalDelReto(1000), 1378000);
      expect(retoDeSemana(52, 1000), 52000);
      expect(() => retoDeSemana(53, 1000), throwsRangeError);
    });

    test('redondeo, sobrante, sobre, extras y pagate primero', () {
      expect(redondeoDeGasto(4350), 650);
      expect(redondeoDeGasto(5000), 0);
      expect(redondeoDeGastos([4350, 5000, 123]), 650 + 877);
      expect(sobranteSemanal(-5), 0);
      expect(sobreDeCategoria(asignado: 100, gastado: 130), 0);
      expect(porcentajeDeExtras(100000, 1000), 10000);
      expect(pagatePrimero(ingresoQueLlego: 100000, puntosBase: 1000, hayDeuda: true), 0);
      expect(pagatePrimero(ingresoQueLlego: 100000, puntosBase: 1000, hayDeuda: false), 10000);
      expect(sugeridoSinLoYaApartado(5000, 8000), 0);
    });

    test('acelerar una meta sube la aportacion', () {
      final a = acelerarMeta(meta: 52000, saldo: 0, semanasActuales: 52, semanasNuevas: 26);
      expect(a.nueva, 2000);
      expect(a.aumento, 1000);
    });
  });

  group('Reparto', () {
    final pasos = [
      const PasoDeAhorro('fondo', EtapaAhorro.fondoHastaLaMeta, 5000),
      const PasoDeAhorro('colchon', EtapaAhorro.colchon, 2000),
      const PasoDeAhorro('reserva', EtapaAhorro.reservas, 3000),
    ];

    test('alcanza para todo: respeta el orden de etapas', () {
      final r = repartirAhorro(remanente: 12000, pasos: pasos);
      expect(r.renglones.map((x) => x.paso.bolsaId), ['colchon', 'reserva', 'fondo']);
      expect(r.totalAportado, 10000);
      expect(r.sobrante, 2000);
    });

    test('recorta de abajo hacia arriba y deja pendiente sin castigo', () {
      final r = repartirAhorro(remanente: 6000, pasos: pasos);
      expect(r.aportadoA('colchon'), 2000);
      expect(r.aportadoA('reserva'), 3000);
      expect(r.aportadoA('fondo'), 1000);
      expect(r.pendienteDe('fondo'), 4000);
      final corto = repartirAhorro(remanente: 1500, pasos: pasos);
      expect(corto.aportadoA('colchon'), 1500);
      expect(corto.aportadoA('reserva'), 0);
    });

    test('con deuda que recibe extra solo se aparta el minimo al colchon', () {
      final r = repartirAhorro(
        remanente: 10000,
        pasos: pasos,
        hayDeudaConExtra: true,
        ahorroMinimoConDeuda: 1000,
      );
      expect(r.aportadoA('colchon'), 1000);
      expect(r.aportadoA('reserva'), 0);
      expect(r.aportadoA('fondo'), 0);
      expect(r.sobrante, 9000);
    });

    test('remanente negativo no reparte', () {
      expect(repartirAhorro(remanente: -5, pasos: pasos).totalAportado, 0);
    });

    test('reposicion del fondo tras retiro de emergencia', () {
      expect(reposicionTrasRetiro(saldoAntes: 100000, saldoAhora: 60000), 40000);
      expect(reposicionTrasRetiro(saldoAntes: 100, saldoAhora: 200), 0);
    });
  });
}
