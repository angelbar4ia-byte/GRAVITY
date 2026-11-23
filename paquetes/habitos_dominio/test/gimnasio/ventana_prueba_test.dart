import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

void main() {
  group('CA-G-23 ventana de prueba', () {
    test('el ejemplo de 5.13: noche 5 de 6 con energía media 3.6; mañana 3 de 6 → noche', () {
      const noche = ResumenVentana(
        planeadas: 6,
        cumplidas: 5,
        energias: [4, 3, 4, 4, 3],
      );
      const manana = ResumenVentana(planeadas: 6, cumplidas: 3);
      expect(noche.energiaCentesimas, 360);
      final s = compararVentanas(manana, noche);
      expect(s.resultado, ResultadoVentana.sugiereNoche);
      expect(s.criterio, CriterioVentana.cumplimiento);
      expect(s.diferenciaPuntos, 33);
    });

    test('simétrico: gana la mañana si cumple más', () {
      const noche = ResumenVentana(planeadas: 6, cumplidas: 2);
      const manana = ResumenVentana(planeadas: 6, cumplidas: 5);
      expect(
        compararVentanas(manana, noche).resultado,
        ResultadoVentana.sugiereManana,
      );
    });

    test('con menos de 4 sesiones planeadas en una ventana: faltan datos', () {
      const ok = ResumenVentana(planeadas: 6, cumplidas: 6);
      const poco = ResumenVentana(planeadas: 3, cumplidas: 0);
      expect(
        compararVentanas(ok, poco).resultado,
        ResultadoVentana.faltanDatos,
      );
      expect(
        compararVentanas(poco, ok).resultado,
        ResultadoVentana.faltanDatos,
      );
      expect(
        compararVentanas(poco, poco).resultado,
        ResultadoVentana.faltanDatos,
      );
      // Con 4 y 4 ya se compara.
      const cuatro = ResumenVentana(planeadas: 4, cumplidas: 4);
      expect(
        compararVentanas(
          cuatro,
          const ResumenVentana(planeadas: 4, cumplidas: 1),
        ).resultado,
        ResultadoVentana.sugiereManana,
      );
    });

    test('diferencia de cumplimiento menor de 15 puntos: decide la energía (0.5 o más)', () {
      const manana = ResumenVentana(
        planeadas: 6,
        cumplidas: 5,
        energias: [4, 4, 5, 4, 4],
      ); // 4.2
      const noche = ResumenVentana(
        planeadas: 6,
        cumplidas: 5,
        energias: [3, 3, 4, 3, 3],
      ); // 3.2
      final s = compararVentanas(manana, noche);
      expect(s.resultado, ResultadoVentana.sugiereManana);
      expect(s.criterio, CriterioVentana.energia);
      expect(s.diferenciaEnergiaCentesimas, 100);
    });

    test('diferencias menores de 15 puntos y de 0.5 de energía: sin diferencia clara', () {
      const manana = ResumenVentana(
        planeadas: 8,
        cumplidas: 7,
        energias: [4, 4, 3, 4],
      ); // 3.75
      const noche = ResumenVentana(
        planeadas: 8,
        cumplidas: 6,
        energias: [4, 3, 4, 4],
      ); // 3.75
      final s = compararVentanas(manana, noche);
      expect(s.resultado, ResultadoVentana.sinDiferenciaClara);
      // 7/8 contra 6/8: 12.5 puntos, menos de 15.
      expect(s.diferenciaPuntos, 13);
    });

    test('los límites exactos: 15 puntos sí decide y 0.5 de energía sí decide', () {
      // 20 sesiones: 17/20 = 85 % contra 14/20 = 70 % → 15 puntos exactos.
      const a = ResumenVentana(planeadas: 20, cumplidas: 17);
      const b = ResumenVentana(planeadas: 20, cumplidas: 14);
      expect(compararVentanas(b, a).resultado, ResultadoVentana.sugiereNoche);
      // 20 sesiones: 85 % contra 71 % (14.x puntos) no decide por cumplimiento.
      const c = ResumenVentana(planeadas: 21, cumplidas: 15); // 71.4 %
      expect(
        compararVentanas(c, a).resultado,
        ResultadoVentana.sinDiferenciaClara,
      );
      // Energía: 3.5 contra 4.0 → 0.5 justo.
      const e1 = ResumenVentana(planeadas: 6, cumplidas: 5, energias: [3, 4]);
      const e2 = ResumenVentana(planeadas: 6, cumplidas: 5, energias: [4, 4]);
      final s = compararVentanas(e1, e2);
      expect(s.resultado, ResultadoVentana.sugiereNoche);
      expect(s.criterio, CriterioVentana.energia);
    });

    test(
      'CASO MALO: nunca cambia la ventana sola (el perfil es inmutable)',
      () {
        const perfil = PerfilGimnasio(ventana: VentanaEntrenamiento.manana);
        const noche = ResumenVentana(planeadas: 6, cumplidas: 6);
        const manana = ResumenVentana(planeadas: 6, cumplidas: 1);
        final s = compararVentanas(manana, noche);
        expect(s.resultado, ResultadoVentana.sugiereNoche);
        // Sugerir devuelve una sugerencia; el perfil sigue como estaba.
        expect(perfil.ventana, VentanaEntrenamiento.manana);
      },
    );

    test('la ventana de una sesión sale de su hora real de inicio', () {
      expect(ventanaDeInicio(7 * 60), VentanaEntrenamiento.manana);
      expect(ventanaDeInicio(11 * 60 + 59), VentanaEntrenamiento.manana);
      expect(ventanaDeInicio(19 * 60 + 15), VentanaEntrenamiento.noche);
    });
  });
}
