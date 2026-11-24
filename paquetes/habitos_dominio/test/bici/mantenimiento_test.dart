import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

import 'ayudas_bici.dart';

TareaEstado estado(
  Bicicleta bici,
  List<RegistroMantenimiento> m,
  List<Salida> s,
  DateTime hoy,
  TareaMantenimiento t,
) => estadoMantenimiento(
  bici: bici,
  mantenimientos: m,
  salidas: s,
  hoy: hoy,
).firstWhere((e) => e.tarea == t);

void main() {
  const lub = TareaMantenimiento.lubricarCadena;
  // Lubricada a los 350 km el 7/nov/2026.
  final registro = hecho('m1', lub, dia(2026, 11, 7), odometroM: 350000);

  List<Salida> conKm(int km) => [
    salida('s', dia(2026, 11, 14), distanciaM: km * 1000),
  ];

  group('CA-B-06 mantenimiento (lubricar: 150 km o 4 semanas)', () {
    test('a 470 km no toca (120 km desde que se hizo)', () {
      final e = estado(biciA, [registro], conKm(120), dia(2026, 11, 20), lub);
      expect(e.estado, EstadoTarea.alDia);
      expect(e.kmDesdeM, 120000);
      expect(e.kmFaltanM, 30000);
    });

    test('a 505 km toca (155 km)', () {
      final e = estado(biciA, [registro], conKm(155), dia(2026, 11, 20), lub);
      expect(e.estado, EstadoTarea.toca);
      expect(e.kmDesdeM, 155000);
      expect(e.kmFaltanM, 0);
    });

    test('justo a 150 km toca (llegan al intervalo)', () {
      expect(
        estado(biciA, [registro], conKm(150), dia(2026, 11, 20), lub).estado,
        EstadoTarea.toca,
      );
      expect(
        estado(biciA, [registro], conKm(149), dia(2026, 11, 20), lub).estado,
        EstadoTarea.alDia,
      );
    });

    test('a 4 semanas y 1 día toca aunque los km no lleguen', () {
      // 7/nov + 29 días = 6/dic.
      final e = estado(biciA, [registro], const [], dia(2026, 12, 6), lub);
      expect(e.estado, EstadoTarea.toca);
      expect(e.semanasDesde, 4);
      expect(e.kmDesdeM, 0);
      // A 27 días (3 semanas y 6 días) aún no.
      expect(
        estado(biciA, [registro], const [], dia(2026, 12, 4), lub).estado,
        EstadoTarea.alDia,
      );
      // Justo a las 4 semanas toca (lo primero que se cumple).
      expect(
        estado(biciA, [registro], const [], dia(2026, 12, 5), lub).estado,
        EstadoTarea.toca,
      );
    });

    test('sin ningún registro dice «sin registro», no «vencida»', () {
      final todas = estadoMantenimiento(
        bici: biciA,
        mantenimientos: const [],
        hoy: dia(2026, 12, 6),
      );
      expect(todas, hasLength(4));
      expect(todas.map((e) => e.estado), everyElement(EstadoTarea.sinRegistro));
      expect(todas.map((e) => e.bloquea), everyElement(isFalse));
      expect(
        mantenimientoQueToca(
          bici: biciA,
          mantenimientos: const [],
          hoy: dia(2026, 12, 6),
        ),
        isEmpty,
      );
      expect(MensajesBici.sinRegistro, 'Sin registro');
    });

    test('con un solo intervalo vacío solo manda el otro', () {
      const soloKm = Bicicleta(
        id: 'a',
        nombre: 'Mi bici',
        odometroInicialM: 350000,
        intervalos: {lub: IntervaloMantenimiento(km: 150)},
      );
      expect(
        estado(soloKm, [registro], const [], dia(2027, 6, 1), lub).estado,
        EstadoTarea.alDia, // pasaron meses, pero no hay intervalo en semanas
      );
      const soloSemanas = Bicicleta(
        id: 'a',
        nombre: 'Mi bici',
        intervalos: {lub: IntervaloMantenimiento(semanas: 2)},
      );
      expect(
        estado(
          soloSemanas,
          [registro],
          const [],
          dia(2026, 11, 21),
          lub,
        ).estado,
        EstadoTarea.toca,
      );
    });

    test('un intervalo vacío desactiva la tarea (aunque haya registros)', () {
      const apagada = Bicicleta(
        id: 'a',
        nombre: 'Mi bici',
        intervalos: {lub: IntervaloMantenimiento()},
      );
      final e = estado(apagada, [registro], const [], dia(2027, 6, 1), lub);
      expect(e.estado, EstadoTarea.desactivada);
      // Las otras tres siguen con sus valores iniciales.
      final otras = estadoMantenimiento(
        bici: apagada,
        mantenimientos: const [],
        hoy: dia(2026, 12, 6),
      ).where((x) => x.tarea != lub);
      expect(otras.map((x) => x.estado), everyElement(EstadoTarea.sinRegistro));
    });

    test('CASO MALO: un intervalo de 0 km (o de 0 semanas) se rechaza', () {
      expect(const IntervaloMantenimiento(km: 0).validar(), isNotEmpty);
      expect(const IntervaloMantenimiento(semanas: 0).validar(), isNotEmpty);
      expect(const IntervaloMantenimiento(km: -3).validar(), isNotEmpty);
      expect(
        const IntervaloMantenimiento(km: 1, semanas: 1).validar(),
        isEmpty,
      );
      expect(const IntervaloMantenimiento().validar(), isEmpty);
      // También sale al validar la bicicleta entera.
      const mala = Bicicleta(
        id: 'a',
        nombre: 'x',
        intervalos: {lub: IntervaloMantenimiento(km: 0)},
      );
      expect(mala.validar().map((e) => e.codigo), ['intervalo_km_invalido']);
    });

    test('el registro «Hecho» guarda la fecha y el odómetro de ESE día', () {
      final r = registrarHecho(
        id: 'm2',
        bici: biciA,
        tarea: lub,
        fecha: dia(2026, 11, 20),
        salidas: [
          salida('s1', dia(2026, 11, 14), distanciaM: 62000),
          salida('s2', dia(2026, 11, 27), distanciaM: 58000),
        ],
      );
      expect(r.odometroM, 412000); // la del 27 aún no pasó
      expect(r.fecha, dia(2026, 11, 20));
      expect(r.bicicletaId, 'a');
      expect(r.validar(), isEmpty);
    });

    test('si el registro no trae odómetro se calcula el de su fecha', () {
      final sinKm = hecho('m1', lub, dia(2026, 11, 7)); // sin odometroM
      final e = estado(
        biciA,
        [sinKm],
        [
          salida('antes', dia(2026, 11, 1), distanciaM: 10000),
          salida('despues', dia(2026, 11, 14), distanciaM: 160000),
        ],
        dia(2026, 11, 20),
        lub,
      );
      expect(e.kmDesdeM, 160000);
      expect(e.estado, EstadoTarea.toca);
    });

    test('manda el último registro de la tarea y las bicis no se mezclan', () {
      final viejo = hecho('m0', lub, dia(2026, 8, 1), odometroM: 100000);
      final otraBici = hecho(
        'mb',
        lub,
        dia(2026, 11, 19),
        bici: 'b',
        odometroM: 1000000,
      );
      final e = estado(
        biciA,
        [viejo, registro, otraBici],
        conKm(155),
        dia(2026, 11, 20),
        lub,
      );
      expect(e.kmDesdeM, 155000);
    });

    test('una lectura del odómetro no cuenta como mantenimiento hecho', () {
      final lectura = hecho(
        'l',
        TareaMantenimiento.lecturaOdometro,
        dia(2026, 11, 7),
        odometroM: 350000,
      );
      expect(
        estado(biciA, [lectura], const [], dia(2026, 11, 8), lub).estado,
        EstadoTarea.sinRegistro,
      );
    });

    test('mantenimientoQueToca devuelve solo las que tocan, en orden', () {
      final ms = [
        hecho(
          'a',
          TareaMantenimiento.lubricarCadena,
          dia(2026, 8, 1),
          odometroM: 0,
        ),
        hecho(
          'b',
          TareaMantenimiento.limpiarTransmision,
          dia(2026, 8, 1),
          odometroM: 0,
        ),
        hecho(
          'c',
          TareaMantenimiento.revisarFrenosLlantas,
          dia(2026, 11, 20),
          odometroM: 350000,
        ),
      ];
      final toca = mantenimientoQueToca(
        bici: biciA,
        mantenimientos: ms,
        hoy: dia(2026, 11, 27),
      );
      expect(toca.map((e) => e.tarea), [
        TareaMantenimiento.lubricarCadena,
        TareaMantenimiento.limpiarTransmision,
      ]);
    });
  });

  group('catálogo de intervalos iniciales (PB-11)', () {
    test('150/4, 400/12, 300/8 y 2000/26 como en 4.8', () {
      final m = {
        for (final c in catalogoMantenimiento)
          c.tarea: (c.kmInicial, c.semanasInicial),
      };
      expect(m, {
        TareaMantenimiento.lubricarCadena: (150, 4),
        TareaMantenimiento.limpiarTransmision: (400, 12),
        TareaMantenimiento.revisarFrenosLlantas: (300, 8),
        TareaMantenimiento.revisionGeneral: (2000, 26),
      });
    });

    test('el mantenimiento no genera notificaciones propias (PB-13)', () {
      expect(
        TextoAvisoHabitos.porTipo.keys.any((k) => k.contains('mant')),
        isFalse,
      );
      expect(
        TextoAvisoBici.respaldo.keys.any((k) => k.contains('mant')),
        isFalse,
      );
    });
  });
}
