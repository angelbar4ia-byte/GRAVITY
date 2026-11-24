import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

void main() {
  const dormir = 22 * 60;

  group('CA-B-02 bloques de la salida', () {
    test('valores iniciales: sábado 8:00, 240 min, recordar 45; preparación '
        'el viernes 19:30, 15 min', () {
      final p = planearBloquesBici(dormirMin: dormir);
      expect(p.salida.diaSemana, DateTime.saturday);
      expect(p.salida.inicioMin, 8 * 60);
      expect(p.salida.duracionMin, 240);
      expect(p.salida.recordarMin, 45);
      expect(p.salida.tipo, 'actividad');
      expect(p.salida.area, 'salud');
      // El aviso de ~7:15.
      expect(p.salida.inicioMin - p.salida.recordarMin, 7 * 60 + 15);
      expect(p.preparacion.diaSemana, DateTime.friday);
      expect(p.preparacion.inicioMin, 19 * 60 + 30);
      expect(p.preparacion.duracionMin, 15);
      expect(p.preparacion.recordarMin, 0);
      expect(p.avisos, isEmpty);
      expect(p.preparacionEnSabado, isFalse);
    });

    test('con la sesión C el viernes a las 19:15 la preparación se mueve al '
        'hueco siguiente y avisa SIN impedir guardar', () {
      // C de 19:15 a 20:15.
      final p = planearBloquesBici(
        dormirMin: dormir,
        ocupadosViernes: const [Intervalo(19 * 60 + 15, 20 * 60 + 15)],
      );
      expect(p.preparacion.diaSemana, DateTime.friday);
      expect(p.preparacion.inicioMin, 20 * 60 + 15);
      expect(p.avisos, [AvisoBloqueBici.preparacionChoca]);
      expect(p.conflictosPreparacion, hasLength(1));
      expect(p.preparacionDeseadaMin, 19 * 60 + 30);
      expect(p.impideGuardar, isFalse);
    });

    test('CASO MALO: un hueco menor de 15 min no se ofrece (pasa al sábado '
        '45 min antes de la salida)', () {
      // Ocupado hasta las 20:50; la ventana cierra a las 21:00 (dormir − 60):
      // quedan 10 min.
      final p = planearBloquesBici(
        dormirMin: dormir,
        ocupadosViernes: const [Intervalo(19 * 60, 20 * 60 + 50)],
      );
      expect(p.preparacion.diaSemana, DateTime.saturday);
      expect(p.preparacion.inicioMin, 7 * 60 + 15);
      expect(p.preparacionEnSabado, isTrue);
      expect(p.avisos, contains(AvisoBloqueBici.sinHuecoViernes));
      expect(p.impideGuardar, isFalse);
    });

    test('un hueco justo de 15 min sí se ofrece; uno de 14 no', () {
      final justo = planearBloquesBici(
        dormirMin: dormir,
        ocupadosViernes: const [Intervalo(19 * 60, 20 * 60 + 45)],
      );
      expect(justo.preparacion.diaSemana, DateTime.friday);
      expect(justo.preparacion.inicioMin, 20 * 60 + 45);
      final corto = planearBloquesBici(
        dormirMin: dormir,
        ocupadosViernes: const [Intervalo(19 * 60, 20 * 60 + 46)],
      );
      expect(corto.preparacion.diaSemana, DateTime.saturday);
    });

    test('nunca se ofrece una hora después de dormir − 60 min', () {
      // Dormir a las 20:30: la ventana cierra a las 19:30 y no cabe nada.
      final p = planearBloquesBici(dormirMin: 20 * 60 + 30);
      expect(p.preparacionEnSabado, isTrue);
    });

    test(
      'la salida avisa si choca con otro bloque del sábado, sin impedir',
      () {
        final p = planearBloquesBici(
          dormirMin: dormir,
          ocupadosSabado: const [Intervalo(11 * 60, 12 * 60)],
        );
        expect(p.avisos, [AvisoBloqueBici.salidaChoca]);
        expect(p.impideGuardar, isFalse);
      },
    );

    test('la duración y el aviso son editables', () {
      final p = planearBloquesBici(
        dormirMin: dormir,
        duracionSalidaMin: 300,
        reglas: const ReglasBicicleta(
          salidaInicioMin: 7 * 60,
          salidaRecordarMin: 30,
        ),
      );
      expect(p.salida.duracionMin, 300);
      expect(p.salida.inicioMin, 7 * 60);
      expect(p.salida.recordarMin, 30);
    });
  });

  group('duración prevista y regreso (4.1)', () {
    List<Salida> cuatro(List<int> d) => [
      for (var i = 0; i < d.length; i++) salidaDe(i, d[i]),
    ];

    test('la ruta elegida manda; luego el promedio de las últimas cuatro '
        'redondeado a 15; luego 240', () {
      final s = cuatro([270, 250, 260, 255]);
      expect(duracionPrevistaMin(rutaDuracionMin: 180, salidas: s), 180);
      // (270+250+260+255)/4 = 258.75 → 255 (múltiplos de 15).
      expect(duracionPrevistaMin(salidas: s), 255);
      expect(duracionPrevistaMin(), 240);
    });

    test('con menos de cuatro salidas no hay promedio: sale 240', () {
      expect(duracionPrevistaMin(salidas: cuatro([300, 300, 300])), 240);
    });

    test('solo cuentan las cuatro MÁS RECIENTES y las que salieron', () {
      final s = [
        salidaDe(0, 60), // la más antigua queda fuera
        salidaDe(1, 300),
        salidaDe(2, 300),
        salidaDe(3, 300),
        salidaDe(4, 300),
        Salida(
          id: 'omitida',
          fecha: dia(2026, 12, 20),
          estado: EstadoSalida.omitida,
          duracionMin: 10,
        ),
      ];
      expect(duracionPrevistaMin(salidas: s), 300);
    });

    test('la duración prevista del perfil es la última opción', () {
      expect(
        duracionPrevistaMin(
          reglas: const ReglasBicicleta(duracionPrevistaMin: 180),
        ),
        180,
      );
    });

    test('una ruta de 0 min se ignora; no divide entre cero', () {
      expect(duracionPrevistaMin(rutaDuracionMin: 0), 240);
      expect(duracionPrevistaMin(salidas: cuatro([0, 0, 0, 0])), 240);
    });

    test('regreso = inicio + duración (8:00 + 4 h = 12:00)', () {
      expect(regresoMin(8 * 60, 240), 12 * 60);
      expect(horaTexto(regresoMin(8 * 60, 240)), '12:00');
    });
  });
}

Salida salidaDe(int i, int min) =>
    Salida(id: 's$i', fecha: dia(2026, 10, 3 + 7 * i), duracionMin: min);
