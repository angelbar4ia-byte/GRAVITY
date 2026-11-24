import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

import 'ayudas_bici.dart';

void main() {
  group('CA-B-05 odómetro derivado', () {
    test('350 + 62 + 58 = 470 km', () {
      final km = odometroM(
        bici: biciA,
        salidas: [
          salida('1', dia(2026, 11, 7), distanciaM: 62000),
          salida('2', dia(2026, 11, 14), distanciaM: 58000),
        ],
      );
      expect(km, 470000);
    });

    test('con una lectura de 480 km el 12/dic y una salida posterior de 60 km: '
        '540 km (las salidas anteriores a la lectura ya están dentro)', () {
      final km = odometroM(
        bici: biciA,
        mantenimientos: [
          hecho(
            'l1',
            TareaMantenimiento.lecturaOdometro,
            dia(2026, 12, 12),
            odometroM: 480000,
          ),
        ],
        salidas: [
          salida('1', dia(2026, 11, 7), distanciaM: 62000),
          salida('2', dia(2026, 11, 14), distanciaM: 58000),
          salida('3', dia(2026, 12, 19), distanciaM: 60000),
        ],
      );
      expect(km, 540000);
    });

    test('la salida del mismo día de la lectura no se suma otra vez', () {
      final km = odometroM(
        bici: biciA,
        mantenimientos: [
          hecho(
            'l1',
            TareaMantenimiento.lecturaOdometro,
            dia(2026, 12, 12),
            odometroM: 480000,
          ),
        ],
        salidas: [salida('1', dia(2026, 12, 12), distanciaM: 60000)],
      );
      expect(km, 480000);
    });

    test('con varias lecturas manda la más reciente', () {
      final km = odometroM(
        bici: biciA,
        mantenimientos: [
          hecho(
            'l2',
            TareaMantenimiento.lecturaOdometro,
            dia(2026, 12, 12),
            odometroM: 480000,
          ),
          hecho(
            'l1',
            TareaMantenimiento.lecturaOdometro,
            dia(2026, 11, 1),
            odometroM: 400000,
          ),
        ],
        salidas: [salida('3', dia(2026, 12, 19), distanciaM: 1000)],
      );
      expect(km, 481000);
    });

    test('dos bicis llevan cada una el suyo', () {
      final salidas = [
        salida('1', dia(2026, 11, 7), distanciaM: 62000), // bici a
        salida('2', dia(2026, 11, 14), distanciaM: 40000, bici: 'b'),
      ];
      expect(odometroM(bici: biciA, salidas: salidas), 412000);
      expect(odometroM(bici: biciB, salidas: salidas), 1040000);
    });

    test('una lectura de otra bici no mueve esta', () {
      final km = odometroM(
        bici: biciA,
        mantenimientos: [
          hecho(
            'l',
            TareaMantenimiento.lecturaOdometro,
            dia(2026, 12, 12),
            bici: 'b',
            odometroM: 9000000,
          ),
        ],
      );
      expect(km, 350000);
    });

    test('borrar una salida lo recalcula', () {
      final todas = [
        salida('1', dia(2026, 11, 7), distanciaM: 62000),
        salida('2', dia(2026, 11, 14), distanciaM: 58000),
      ];
      expect(odometroM(bici: biciA, salidas: todas), 470000);
      expect(odometroM(bici: biciA, salidas: [todas.first]), 412000);
      expect(odometroM(bici: biciA), 350000);
    });

    test('CASO MALO: una salida sin bicicleta no suma a ninguna', () {
      final salidas = [
        salida('x', dia(2026, 11, 7), distanciaM: 62000, bici: null),
      ];
      expect(odometroM(bici: biciA, salidas: salidas), 350000);
      expect(odometroM(bici: biciB, salidas: salidas), 1000000);
    });

    test('una omitida, o una salida sin distancia, no suma', () {
      final salidas = [
        salida(
          'o',
          dia(2026, 11, 7),
          distanciaM: 62000,
          estado: EstadoSalida.omitida,
        ),
        salida('s', dia(2026, 11, 14)),
      ];
      expect(odometroM(bici: biciA, salidas: salidas), 350000);
    });

    test('«hasta» da el odómetro de ese día', () {
      final salidas = [
        salida('1', dia(2026, 11, 7), distanciaM: 62000),
        salida('2', dia(2026, 11, 14), distanciaM: 58000),
      ];
      expect(
        odometroM(bici: biciA, salidas: salidas, hasta: dia(2026, 11, 10)),
        412000,
      );
    });

    test('la distancia se maneja en metros enteros (sin decimales)', () {
      final km = odometroM(
        bici: biciA,
        salidas: [salida('1', dia(2026, 11, 7), distanciaM: 62437)],
      );
      expect(km, 412437);
      expect(km, isA<int>());
    });
  });

  group('validación y JSON de la bicicleta y los registros', () {
    test('rangos', () {
      expect(biciA.validar(), isEmpty);
      expect(const Bicicleta(id: 'x', nombre: '').validar(), isNotEmpty);
      expect(Bicicleta(id: 'x', nombre: 'n' * 41).validar(), isNotEmpty);
      expect(
        const Bicicleta(id: 'x', nombre: 'n', odometroInicialM: -1).validar(),
        isNotEmpty,
      );
      expect(
        const Bicicleta(
          id: 'x',
          nombre: 'n',
          odometroInicialM: 200000001,
        ).validar(),
        isNotEmpty,
      );
    });

    test(
      '«lectura_odometro» sin km se rechaza; un odómetro negativo también',
      () {
        expect(
          hecho(
            'l',
            TareaMantenimiento.lecturaOdometro,
            dia(2026, 12, 1),
          ).validar().map((e) => e.codigo),
          ['lectura_sin_odometro'],
        );
        expect(
          hecho(
            'l',
            TareaMantenimiento.lecturaOdometro,
            dia(2026, 12, 1),
            odometroM: -5,
          ).validar(),
          isNotEmpty,
        );
        expect(
          hecho(
            'm',
            TareaMantenimiento.lubricarCadena,
            dia(2026, 12, 1),
          ).validar(),
          isEmpty,
        );
        expect(
          RegistroMantenimiento(
            id: 'n',
            bicicletaId: 'a',
            tarea: TareaMantenimiento.otra,
            fecha: dia(2026, 12, 1),
            nota: 'n' * 121,
          ).validar(),
          isNotEmpty,
        );
      },
    );

    test('las filas de nube son las columnas de 5.2', () {
      expect(biciA.aJson().keys, [
        'id',
        'nombre',
        'tipo',
        'odometro_inicial_m',
        'intervalos',
        'activa',
      ]);
      expect(
        hecho(
          'm',
          TareaMantenimiento.lubricarCadena,
          dia(2026, 12, 1),
          odometroM: 350000,
        ).aJson(),
        {
          'id': 'm',
          'bicicleta_id': 'a',
          'tarea': 'lubricar_cadena',
          'fecha': '2026-12-01',
          'odometro_m': 350000,
          'nota': null,
        },
      );
    });
  });
}
