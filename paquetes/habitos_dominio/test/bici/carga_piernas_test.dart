import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

import 'ayudas_bici.dart';

final cat = catalogoGimnasio;

SesionProgramada ruta() => SesionProgramada('bici', t(5, 8, 0));

ResultadoPiernas revisar(
  List<SesionProgramada> s, {
  CargaPiernas? carga,
  List<Salida> salidas = const [],
}) => revisarSemanaConBici(
  sesiones: s,
  catalogo: cat,
  carga: carga,
  salidas: salidas,
);

void main() {
  group('CA-B-04 48 horas con la bicicleta', () {
    test('C el jueves 19:15: 36 h 45 min, faltan 615 min, avisa', () {
      final r = revisar([SesionProgramada('C', t(3, 19, 15)), ruta()]);
      expect(r.avisos, hasLength(1));
      expect(r.avisos.single.intervaloMin, 36 * 60 + 45);
      expect(r.avisos.single.intervaloMin, 2205);
      expect(r.avisos.single.faltanMin, 615);
      expect(r.avisosBici, hasLength(1));
      expect(r.avisosBici.single.intervaloMin, 2205);
      expect(r.avisosBici.single.faltanMin, 615);
    });

    test('C el viernes 20:00: 12 h, faltan 35 h, avisa', () {
      final r = revisar([SesionProgramada('C', t(4, 20, 0)), ruta()]);
      expect(r.avisos.single.intervaloMin, 12 * 60);
      expect(r.avisos.single.faltanMin, 35 * 60);
    });

    test('C el miércoles 19:15: 60 h 45 min, cumple', () {
      final r = revisar([SesionProgramada('C', t(2, 19, 15)), ruta()]);
      expect(r.avisos, isEmpty);
      expect(60 * 60 + 45, 3645);
    });

    test('C el martes 19:15: 84 h 45 min, cumple', () {
      final r = revisar([SesionProgramada('C', t(1, 19, 15)), ruta()]);
      expect(r.avisos, isEmpty);
      expect(ruta().inicio.difference(t(1, 19, 15)).inMinutes, 84 * 60 + 45);
    });

    test('C el jueves a las 9:00: 47 h 0 min, cumple (justo en el mínimo)', () {
      final r = revisar([SesionProgramada('C', t(3, 9, 0)), ruta()]);
      expect(r.avisos, isEmpty);
      final casi = revisar([SesionProgramada('C', t(3, 9, 1)), ruta()]);
      expect(casi.avisos, hasLength(1));
      expect(casi.avisos.single.faltanMin, 1);
    });

    group('con carga_piernas = ligera ninguna avisa', () {
      for (final c in [
        SesionProgramada('C', t(3, 19, 15)),
        SesionProgramada('C', t(4, 20, 0)),
        SesionProgramada('C', t(2, 19, 15)),
        SesionProgramada('C', t(1, 19, 15)),
        SesionProgramada('C', t(3, 9, 0)),
      ]) {
        test('C ${c.inicio}', () {
          final r = revisar([c, ruta()], carga: CargaPiernas.ligera);
          expect(r.biciCuenta, isFalse);
          expect(r.avisos, isEmpty);
          expect(r.avisosBici, isEmpty);
        });
      }
    });

    test(
      'por_esfuerzo: tres salidas de esfuerzo 2 NO avisa; con una de 4 SÍ',
      () {
        final bajas = [
          for (var i = 0; i < 3; i++)
            salida('s$i', dia(2026, 11, 7 + 7 * i), esfuerzo: 2),
        ];
        final c = SesionProgramada('C', t(3, 19, 15));
        final sin = revisar(
          [c, ruta()],
          carga: CargaPiernas.porEsfuerzo,
          salidas: bajas,
        );
        expect(sin.biciCuenta, isFalse);
        expect(sin.avisos, isEmpty);
        final conUna = revisar(
          [c, ruta()],
          carga: CargaPiernas.porEsfuerzo,
          salidas: [
            salida('s0', dia(2026, 11, 7), esfuerzo: 2),
            salida('s1', dia(2026, 11, 14), esfuerzo: 4),
            salida('s2', dia(2026, 11, 21), esfuerzo: 2),
          ],
        );
        expect(conUna.biciCuenta, isTrue);
        expect(conUna.avisos, hasLength(1));
        // Con una sola salida registrada de esfuerzo 4 también cuenta.
        expect(
          revisar(
            [c, ruta()],
            carga: CargaPiernas.porEsfuerzo,
            salidas: [salida('x', dia(2026, 11, 28), esfuerzo: 4)],
          ).avisos,
          hasLength(1),
        );
      },
    );

    test(
      'por_esfuerzo: solo cuentan las ÚLTIMAS tres (una de 4 antigua no)',
      () {
        final salidas = [
          salida('vieja', dia(2026, 10, 3), esfuerzo: 5),
          salida('a', dia(2026, 11, 7), esfuerzo: 2),
          salida('b', dia(2026, 11, 14), esfuerzo: 1),
          salida('c', dia(2026, 11, 21), esfuerzo: 2),
        ];
        expect(
          biciCuentaComoPiernas(
            carga: CargaPiernas.porEsfuerzo,
            salidas: salidas,
          ),
          isFalse,
        );
      },
    );

    test('por_esfuerzo sin salidas (o sin esfuerzo registrado): cuenta', () {
      expect(biciCuentaComoPiernas(carga: CargaPiernas.porEsfuerzo), isTrue);
      expect(
        biciCuentaComoPiernas(
          carga: CargaPiernas.porEsfuerzo,
          salidas: [salida('x', dia(2026, 11, 28))],
        ),
        isTrue,
      );
      // Una omitida no es una salida.
      expect(
        biciCuentaComoPiernas(
          carga: CargaPiernas.porEsfuerzo,
          salidas: [
            salida('x', dia(2026, 11, 28), esfuerzo: 1),
            salida(
              'o',
              dia(2026, 11, 29),
              esfuerzo: 5,
              estado: EstadoSalida.omitida,
            ),
          ],
        ),
        isFalse,
      );
    });

    test('el valor sale de ReglasBicicleta cuando no se pasa carga', () {
      final r = revisarSemanaConBici(
        sesiones: [SesionProgramada('C', t(3, 19, 15)), ruta()],
        catalogo: cat,
        reglas: const ReglasBicicleta(cargaPiernas: CargaPiernas.ligera),
      );
      expect(r.avisos, isEmpty);
    });

    test('CASO MALO: la versión corta de C NO quita el aviso (la regla mide '
        'el inicio) y no es una opción de la bicicleta', () {
      // Mismo inicio: la duración de la sesión no entra a la regla.
      final r = revisar([SesionProgramada('C', t(3, 19, 15)), ruta()]);
      expect(r.avisos, hasLength(1));
      expect(r.avisos.single.intervaloMin, 2205);
      expect(
        r.avisosBici.single.opciones,
        isNot(contains(AccionSemana.versionCorta)),
      );
      for (final o in r.avisosBici.single.opciones) {
        expect(
          MensajesBici.deOpcionPiernas(o).toLowerCase(),
          isNot(contains('corta')),
        );
      }
    });

    test('las cuatro salidas de 4.6, en orden; sin «mover C al martes» si C '
        'ya es el martes', () {
      final r = revisar([SesionProgramada('C', t(3, 19, 15)), ruta()]);
      expect(r.avisosBici.single.opciones, [
        OpcionPiernas.moverCAlMartes,
        OpcionPiernas.declararRutaLigera,
        OpcionPiernas.dejarloAsi,
        OpcionPiernas.moverLaRuta,
      ]);
      expect(r.avisosBici.single.sesionC.tipo, 'C');
      // C el martes a las 8:00 de la ruta del sábado con 9:00… avisaría solo
      // si fuera tarde: C martes 19:15 no avisa; fabricamos el caso con la
      // ruta el miércoles a las 8:00 (intervalo corto).
      final raro = revisar([
        SesionProgramada('C', t(1, 19, 15)),
        SesionProgramada('bici', t(2, 8, 0)),
      ]);
      expect(raro.avisosBici.single.opciones, [
        OpcionPiernas.declararRutaLigera,
        OpcionPiernas.dejarloAsi,
        OpcionPiernas.moverLaRuta,
      ]);
    });
  });

  group('compatibilidad con el gimnasio (la regla no cambió)', () {
    test('con carga normal el resultado es idéntico a revisarSemana', () {
      final casos = [
        [SesionProgramada('C', t(3, 19, 15)), ruta()],
        [SesionProgramada('C', t(4, 20, 0)), ruta()],
        [SesionProgramada('C', t(1, 19, 15)), ruta()],
        [
          SesionProgramada('A', t(30, 20, 0, mes: 11)),
          SesionProgramada('B', t(2, 18, 30)),
          ruta(),
        ],
      ];
      for (final s in casos) {
        final directo = revisarSemana(s, cat);
        final conBici = revisar(s).avisos;
        expect(conBici.length, directo.length);
        for (var i = 0; i < directo.length; i++) {
          expect(conBici[i].intervaloMin, directo[i].intervaloMin);
          expect(conBici[i].faltanMin, directo[i].faltanMin);
          expect(conBici[i].propuestas, directo[i].propuestas);
          expect(conBici[i].grupos, directo[i].grupos);
        }
      }
    });

    test('la semana por omisión (3, 4 y 5 días) no avisa de nada', () {
      for (final d in [3, 4, 5]) {
        final r = revisar(calendario(planSemanal(d)));
        expect(r.avisos, isEmpty, reason: 'plan de $d');
        expect(r.avisosBici, isEmpty);
      }
    });

    test('C el jueves (variante) sigue como hoy: aviso de 36 h 45 min con '
        'sus propuestas del gimnasio intactas', () {
      for (final d in [3, 4, 5]) {
        final r = revisar(calendario(planSemanal(d, cEnJueves: true)));
        expect(r.avisos, hasLength(1), reason: 'plan de $d');
        expect(r.avisos.single.intervaloMin, 2205);
        expect(r.avisos.single.propuestas, [
          AccionSemana.versionCorta,
          AccionSemana.dejarComoEsta,
        ]);
      }
    });

    test('C el viernes (variante) sigue como hoy: 12 h 45 min y propone mover '
        'al jueves', () {
      final r = revisar(calendario(planSemanal(3, cEnViernes: true)));
      expect(r.avisos, hasLength(1));
      expect(r.avisos.single.intervaloMin, 12 * 60 + 45);
      expect(r.avisos.single.propuestas.first, AccionSemana.moverAlJueves);
    });

    test('«ligera» solo quita lo de la ruta: un aviso A-B sigue saliendo', () {
      final r = revisar([
        SesionProgramada('A', t(30, 20, 0, mes: 11)),
        SesionProgramada('B', t(2, 18, 30)),
        ruta(),
      ], carga: CargaPiernas.ligera);
      expect(r.avisos, hasLength(1));
      expect(r.avisos.single.grupos, ['hombro']);
      expect(r.avisosBici, isEmpty);
    });

    test('nunca bloquea: el resultado siempre se devuelve', () {
      final r = revisar([SesionProgramada('C', t(4, 20, 0)), ruta()]);
      expect(r.avisos, isNotEmpty);
    });

    test('plan_semana.dart del gimnasio no se tocó para esto', () {
      // La carga de piernas vive en bici/: `gruposDeTipo` sigue dando
      // cuádriceps y glúteo a la bicicleta.
      expect(gruposDeTipo(cat, 'bici'), {'cuadriceps', 'gluteo'});
    });
  });

  group('última sesión de piernas (CB-3)', () {
    test('es la última de C o la ruta, sea el día que sea', () {
      final sesiones = [
        SesionProgramada('A', t(30, 19, 15, mes: 11)),
        SesionProgramada('C', t(1, 19, 15)),
        SesionProgramada('B', t(2, 19, 15)),
        ruta(),
      ];
      // El viernes por la noche: la última de piernas es C el martes (la
      // ruta aún no pasó).
      final v = ultimaSesionDePiernas(
        sesiones: sesiones,
        catalogo: cat,
        hasta: t(4, 21, 0),
      );
      expect(v!.tipo, 'C');
      // El domingo: la ruta.
      final d = ultimaSesionDePiernas(
        sesiones: sesiones,
        catalogo: cat,
        hasta: t(6, 12, 0),
      );
      expect(d!.tipo, 'bici');
      // Con la ruta declarada ligera, vuelve a ser C.
      final l = ultimaSesionDePiernas(
        sesiones: sesiones,
        catalogo: cat,
        hasta: t(6, 12, 0),
        biciCuenta: false,
      );
      expect(l!.tipo, 'C');
      // Con C el jueves, es el jueves y no «la del viernes».
      final j = ultimaSesionDePiernas(
        sesiones: [SesionProgramada('C', t(3, 19, 15)), ruta()],
        catalogo: cat,
        hasta: t(4, 21, 0),
      );
      expect(j!.inicio, t(3, 19, 15));
      expect(
        ultimaSesionDePiernas(
          sesiones: const [],
          catalogo: cat,
          hasta: t(6, 0, 0),
        ),
        isNull,
      );
    });
  });
}
