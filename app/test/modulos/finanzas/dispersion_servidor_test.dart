// Fase 8 (F8-6.5): el repositorio de Supabase de la dispersión de ingresos
// (migración 20261147) y el servicio sobre él. Con una fuente en memoria que
// imita al servidor: el servidor crea y anula los movimientos, así que el
// servicio no los agrega por su cuenta; confirmar, deshacer y corregir el tipo
// necesitan señal. Datos de ejemplo inventados.
import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide Semaforo, formatearCentavos, TipoLibro, puntosBaseEnCien;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/finanzas/casos_uso/servicio_dispersion.dart';
import 'package:gravity/modulos/finanzas/casos_uso/servicio_finanzas.dart';
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/modulos/finanzas/datos/fuente_tablas.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_dispersiones_supabase.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_memoria.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart'
    show hogarDeEjemplo;

import 'ayuda_finanzas.dart';

const _libro = IdsDemostracion.libroDueno;

/// Viernes de la semana anterior a "hoy" de las pruebas.
final _viernesPasado = Fecha(2026, 10, 16);

/// Un reparto tal como lo devuelve el servidor.
Map<String, Object?> _repartoDelServidor({
  String id = 'a1',
  String libro = 'l1',
  String movimiento = 'm1',
  String estado = 'confirmada',
  List<Map<String, Object?>>? lineas,
}) => {
  'id': id,
  'libro_id': libro,
  'movimiento_id': movimiento,
  'estado': estado,
  'modo': 'confirmacion',
  'creada_en': '2026-10-20T15:00:00+00:00',
  'resuelta_por': estado == 'confirmada' ? 'p1' : null,
  'resuelta_en': estado == 'confirmada' ? '2026-10-20T15:00:01+00:00' : null,
  'en_nombre_de': null,
  'motivo': null,
  'lineas':
      lineas ??
      [
        {
          'destino': 'presupuesto',
          'referencia_id': null,
          'etiqueta': 'Renta',
          'monto_centavos': 500000,
          'movimiento_id': null,
        },
        {
          'destino': 'por_repartir',
          'referencia_id': null,
          'etiqueta': 'Por repartir',
          'monto_centavos': 400000,
          'movimiento_id': null,
        },
      ],
};

Dispersion _reparto({
  String id = 'a1',
  EstadoDispersion estado = EstadoDispersion.propuesta,
  List<LineaDispersion>? lineas,
  String? motivo,
}) => Dispersion(
  id: id,
  libroId: 'l1',
  movimientoId: 'm1',
  estado: estado,
  lineas:
      lineas ??
      const [
        LineaDispersion(
          destino: DestinoLinea.presupuesto,
          etiqueta: 'Renta',
          monto: 500000,
        ),
        LineaDispersion(
          destino: DestinoLinea.porRepartir,
          etiqueta: 'Por repartir',
          monto: 400000,
        ),
      ],
  creadaEn: DateTime.utc(2026, 10, 20, 15),
  motivo: motivo,
);

/// El servidor de mentira: devuelve lo que recibe como reparto guardado.
Object? _eco(Map<String, Object?> p, String estado) {
  final d = Map<String, Object?>.from(p['p_dispersion']! as Map);
  return {
    ..._repartoDelServidor(
      id: d['id']! as String,
      libro: d['libro_id']! as String,
      movimiento: d['movimiento_id']! as String,
      estado: estado,
      lineas: [
        for (final l in (d['lineas']! as List))
          Map<String, Object?>.from(l as Map),
      ],
    ),
  };
}

void main() {
  group('RepositorioDispersionesSupabase', () {
    late FuenteTablasEnMemoria fuente;
    late int recargas;
    late RepositorioDispersionesSupabase repo;

    setUp(() {
      fuente = FuenteTablasEnMemoria();
      recargas = 0;
      repo = RepositorioDispersionesSupabase(
        fuente: fuente,
        alCambiarMovimientos: () async => recargas++,
      );
    });

    test('cargar arma los repartos con sus renglones en orden y los '
        'parámetros solo si el libro ya activó la función', () async {
      fuente.tabla('fin_dispersiones').addAll([
        {
          'id': 'a2',
          'libro_id': 'l1',
          'movimiento_id': 'm2',
          'estado': 'automatica',
          'modo': 'automatico',
          'creada_en': '2026-10-21T10:00:00+00:00',
        },
        {
          'id': 'a1',
          'libro_id': 'l1',
          'movimiento_id': 'm1',
          'estado': 'confirmada',
          'modo': 'confirmacion',
          'creada_en': '2026-10-20T10:00:00+00:00',
          'resuelta_por': 'p1',
          'resuelta_en': '2026-10-20T10:00:05+00:00',
          'en_nombre_de': 'papa',
          'motivo': 'Pensión del mes',
        },
      ]);
      fuente.tabla('fin_dispersion_lineas').addAll([
        {
          'dispersion_id': 'a1',
          'orden': 1,
          'destino': 'abono_extra',
          'referencia_id': 'd1',
          'etiqueta': 'Tarjeta',
          'monto_centavos': 300000,
          'movimiento_id': 'x1',
        },
        {
          'dispersion_id': 'a1',
          'orden': 0,
          'destino': 'presupuesto',
          'referencia_id': null,
          'etiqueta': 'Renta',
          'monto_centavos': 600000,
          'movimiento_id': null,
        },
        {
          'dispersion_id': 'a2',
          'orden': 0,
          'destino': 'por_repartir',
          'referencia_id': null,
          'etiqueta': 'Por repartir',
          'monto_centavos': 50000,
          'movimiento_id': null,
        },
      ]);
      fuente.tabla('fin_parametros').addAll([
        {
          'libro_id': 'l1',
          'dispersion_modo': 'automatico',
          'dispersion_desde': '2026-10-12',
          'dispersion_parte_libre_pb': 1000,
          'dispersion_tope_ahorro': 500000,
        },
        {
          'libro_id': 'l2',
          'dispersion_modo': 'confirmacion',
          'dispersion_desde': null,
          'dispersion_parte_libre_pb': 0,
          'dispersion_tope_ahorro': null,
        },
      ]);
      await repo.cargar();

      expect(repo.actuales.map((d) => d.id), ['a1', 'a2'], reason: 'por fecha');
      final a1 = repo.actuales.first;
      expect(a1.estado, EstadoDispersion.confirmada);
      expect(a1.resueltaPor, 'p1');
      expect(a1.enNombreDe, 'papa');
      expect(a1.motivo, 'Pensión del mes');
      expect(a1.lineas.map((l) => l.destino), [
        DestinoLinea.presupuesto,
        DestinoLinea.abonoExtra,
      ]);
      expect(a1.lineas.last.referenciaId, 'd1');
      expect(a1.lineas.last.monto, 300000);
      expect(repo.actuales.last.modo, ModoDispersion.automatico);
      expect(repo.actuales.last.porRepartir, 50000);

      final p = repo.parametrosDe('l1')!;
      expect(p.modo, ModoDispersion.automatico);
      expect(p.desde, Fecha(2026, 10, 12));
      expect(p.parteLibrePuntosBase, 1000);
      expect(p.topeAhorro, 500000);
      expect(
        repo.parametrosDe('l2'),
        isNull,
        reason: 'sin «desde» la función no está activada: valen los de omisión',
      );
    });

    test('cargar sin señal lanza y deja lo que había', () async {
      fuente.sinSenal = true;
      await expectLater(repo.cargar(), throwsA(isA<ErrorFinanzas>()));
      expect(repo.actuales, isEmpty);
    });

    test('confirmar manda el reparto con los ids estables de los movimientos '
        'que mueven dinero y recarga el libro', () async {
      fuente.funciones['fin_confirmar_dispersion'] = (p) =>
          _eco(p, 'confirmada');
      final d = _reparto(
        id: 'a1',
        estado: EstadoDispersion.confirmada,
        motivo: 'Lo repartí',
        lineas: const [
          LineaDispersion(
            destino: DestinoLinea.presupuesto,
            etiqueta: 'Renta',
            monto: 500000,
          ),
          LineaDispersion(
            destino: DestinoLinea.pagoDeuda,
            referenciaId: 'd1',
            etiqueta: 'Tarjeta',
            monto: 100000,
          ),
          LineaDispersion(
            destino: DestinoLinea.abonoExtra,
            referenciaId: 'd1',
            etiqueta: 'Tarjeta',
            monto: 150000,
          ),
          LineaDispersion(
            destino: DestinoLinea.ahorro,
            etiqueta: 'Ahorro',
            monto: 100000,
          ),
          LineaDispersion(
            destino: DestinoLinea.porRepartir,
            etiqueta: 'Por repartir',
            monto: 50000,
          ),
        ],
      );
      final m = Movimiento(
        id: 'x',
        tipo: TipoMovimiento.transferencia,
        fecha: Fecha(2026, 10, 20),
        registradoEn: DateTime.utc(2026, 10, 20),
        cuentaOrigenId: 'c1',
        cuentaDestinoId: 'c2',
        monto: 1,
        realizadoPor: 'p1',
      );
      await repo.confirmar(d, movimientos: [m], cuentaAhorroId: 'ca');

      expect(fuente.llamadas, hasLength(1));
      final (funcion, args) = fuente.llamadas.single;
      expect(funcion, 'fin_confirmar_dispersion');
      final p = args['p_dispersion']! as Map;
      expect(p['id'], 'a1');
      expect(p['movimiento_id'], 'm1');
      expect(p['modo'], 'confirmacion');
      expect(p['motivo'], 'Lo repartí');
      expect(p['cuenta_ahorro_id'], 'ca');
      expect(p['fecha'], '2026-10-20');
      final lineas = (p['lineas']! as List).cast<Map>();
      expect(lineas.map((l) => l['destino']), [
        'presupuesto',
        'pago_deuda',
        'abono_extra',
        'ahorro',
        'por_repartir',
      ]);
      expect(lineas.map((l) => l['monto_centavos']), [
        500000,
        100000,
        150000,
        100000,
        50000,
      ]);
      // Solo el abono extra y el ahorro llevan el id del movimiento que crean.
      expect(lineas.map((l) => l.containsKey('movimiento_id')), [
        false,
        false,
        true,
        true,
        false,
      ]);
      expect(
        lineas[2]['movimiento_id'],
        idEstable(ClavesId.dispersionMovimiento('a1', 'extra:d1')),
      );
      expect(
        lineas[3]['movimiento_id'],
        idEstable(ClavesId.dispersionMovimiento('a1', 'ahorro')),
      );
      expect(repo.actuales.single.estado, EstadoDispersion.confirmada);
      expect(recargas, 1, reason: 'el servidor creó movimientos');
    });

    test('confirmar sin señal exige conexión y no guarda nada', () async {
      fuente.sinSenal = true;
      await expectLater(
        repo.confirmar(
          _reparto(estado: EstadoDispersion.confirmada),
          movimientos: const [],
        ),
        throwsA(
          isA<ErrorFinanzas>().having(
            (e) => e.sinConexion,
            'sinConexion',
            true,
          ),
        ),
      );
      expect(repo.actuales, isEmpty);
      expect(recargas, 0);
    });

    test(
      'un rechazo del servidor llega a la pantalla con su mensaje',
      () async {
        fuente.funciones['fin_confirmar_dispersion'] = (_) =>
            throw const ErrorFinanzas('Ese ingreso ya está repartido.');
        await expectLater(
          repo.confirmar(
            _reparto(estado: EstadoDispersion.confirmada),
            movimientos: const [],
          ),
          throwsA(
            isA<ErrorFinanzas>().having(
              (e) => e.mensaje,
              'mensaje',
              'Ese ingreso ya está repartido.',
            ),
          ),
        );
        expect(repo.actuales, isEmpty);
      },
    );

    test('guardar una propuesta usa fin_guardar_propuesta y reemplaza a la '
        'propuesta vieja del mismo ingreso', () async {
      fuente.funciones['fin_guardar_propuesta'] = (p) => _eco(p, 'propuesta');
      await repo.guardar(_reparto(id: 'a1'));
      await repo.guardar(_reparto(id: 'a2'));
      expect(fuente.llamadas.map((c) => c.$1), [
        'fin_guardar_propuesta',
        'fin_guardar_propuesta',
      ]);
      expect(
        repo.actuales.map((d) => '${d.id}:${d.estado.name}'),
        ['a1:anulada', 'a2:propuesta'],
        reason: 'un solo reparto vigente por movimiento (lo hace el servidor)',
      );
      expect(recargas, 0, reason: 'una propuesta no mueve dinero');
    });

    test(
      'guardar una propuesta sin señal la deja en este dispositivo',
      () async {
        fuente.sinSenal = true;
        await repo.guardar(_reparto(id: 'a1'));
        expect(repo.actuales.single.id, 'a1');
        expect(repo.actuales.single.estado, EstadoDispersion.propuesta);
      },
    );

    test('un reparto automático va por fin_confirmar_dispersion con modo '
        'automatico y sin movimientos', () async {
      fuente.funciones['fin_confirmar_dispersion'] = (p) =>
          _eco(p, 'automatica');
      final d = Dispersion(
        id: 'a9',
        libroId: 'l1',
        movimientoId: 'm1',
        estado: EstadoDispersion.automatica,
        modo: ModoDispersion.automatico,
        lineas: const [
          LineaDispersion(
            destino: DestinoLinea.presupuesto,
            etiqueta: 'Renta',
            monto: 300000,
          ),
          LineaDispersion(
            destino: DestinoLinea.porRepartir,
            etiqueta: 'Por repartir',
            monto: 600000,
          ),
        ],
        creadaEn: DateTime.utc(2026, 10, 20),
      );
      await repo.guardar(d);
      final p = fuente.llamadas.single.$2['p_dispersion']! as Map;
      expect(p['modo'], 'automatico');
      expect(
        (p['lineas']! as List).any(
          (l) => (l as Map).containsKey('movimiento_id'),
        ),
        isFalse,
      );
      expect(recargas, 0);
    });

    test('guardar() no acepta un reparto confirmado ni anulado', () async {
      expect(
        () => repo.guardar(_reparto(estado: EstadoDispersion.confirmada)),
        throwsStateError,
      );
      expect(
        () => repo.guardar(_reparto(estado: EstadoDispersion.anulada)),
        throwsStateError,
      );
    });

    test(
      'deshacer llama a fin_deshacer_dispersion y recarga el libro',
      () async {
        fuente.funciones['fin_confirmar_dispersion'] = (p) =>
            _eco(p, 'confirmada');
        fuente.funciones['fin_deshacer_dispersion'] = (p) =>
            _repartoDelServidor(
              id: p['p_dispersion']! as String,
              estado: 'anulada',
            );
        final d = _reparto(estado: EstadoDispersion.confirmada);
        await repo.confirmar(d, movimientos: const []);
        await repo.deshacer(d, motivo: 'Reparto deshecho');
        final (funcion, args) = fuente.llamadas.last;
        expect(funcion, 'fin_deshacer_dispersion');
        expect(args, {'p_dispersion': 'a1', 'p_motivo': 'Reparto deshecho'});
        expect(repo.actuales.single.estado, EstadoDispersion.anulada);
        expect(recargas, 1);
      },
    );

    test('corregir el tipo manda los ids y el grupo, y anula el borrador '
        'del ingreso viejo', () async {
      fuente.funciones['fin_guardar_propuesta'] = (p) => _eco(p, 'propuesta');
      await repo.guardar(_reparto(id: 'a1'));
      await repo.corregirTipo(
        movimientoId: 'm1',
        cuentaOrigenId: 'sueldo',
        motivo: 'Era mi sueldo',
        idAnulacion: 'ia',
        idNuevo: 'in',
        grupoId: 'g',
      );
      final (funcion, args) = fuente.llamadas.last;
      expect(funcion, 'fin_corregir_tipo_ingreso');
      expect(args, {
        'p_movimiento': 'm1',
        'p_cuenta_origen': 'sueldo',
        'p_motivo': 'Era mi sueldo',
        'p_grupo': 'g',
        'p_id_anulacion': 'ia',
        'p_id_nuevo': 'in',
      });
      expect(repo.actuales.single.estado, EstadoDispersion.anulada);
      expect(recargas, 1);
    });

    test(
      'guardar parámetros llama a fin_dispersion_parametros_cambiar',
      () async {
        fuente.funciones['fin_dispersion_parametros_cambiar'] = (_) => {
          'modo': 'automatico',
          'desde': '2026-10-12',
          'parte_libre_pb': 500,
          'tope_ahorro': 250000,
        };
        await repo.guardarParametros(
          'l1',
          ParametrosDispersion(
            modo: ModoDispersion.automatico,
            desde: Fecha(2026, 10, 12),
            parteLibrePuntosBase: 500,
            topeAhorro: 250000,
          ),
          motivo: 'Activo el reparto',
        );
        final (funcion, args) = fuente.llamadas.single;
        expect(funcion, 'fin_dispersion_parametros_cambiar');
        expect(args, {
          'p_libro': 'l1',
          'p_modo': 'automatico',
          'p_desde': '2026-10-12',
          'p_parte_libre_pb': 500,
          'p_tope_ahorro': 250000,
          'p_quitar_tope': false,
          'p_motivo': 'Activo el reparto',
        });
        expect(repo.parametrosDe('l1')!.topeAhorro, 250000);
      },
    );
  });

  group('ServicioDispersion sobre el servidor', () {
    late RepositorioFinanzasEnMemoria finanzasRepo;
    late ServicioFinanzas finanzas;
    late FuenteTablasEnMemoria fuente;
    late RepositorioDispersionesSupabase reparto;
    late ServicioDispersion servicio;
    late int recargas;

    setUp(() {
      final dueno = sesionDe(Rol.dueno);
      finanzasRepo = repositorioDe(dueno);
      finanzas = ServicioFinanzas(
        repositorio: finanzasRepo,
        personaId: dueno.persona.id,
        hogarId: dueno.hogarId ?? hogarDeEjemplo,
        esDueno: true,
        reloj: () => ahoraDePrueba,
      );
      fuente = FuenteTablasEnMemoria();
      fuente.funciones['fin_confirmar_dispersion'] = (p) =>
          _eco(p, 'confirmada');
      fuente.funciones['fin_guardar_propuesta'] = (p) => _eco(p, 'propuesta');
      fuente.funciones['fin_deshacer_dispersion'] = (p) => _repartoDelServidor(
        id: p['p_dispersion']! as String,
        libro: _libro,
        estado: 'anulada',
      );
      recargas = 0;
      reparto = RepositorioDispersionesSupabase(
        fuente: fuente,
        alCambiarMovimientos: () async => recargas++,
      );
      servicio = ServicioDispersion(finanzas: finanzas, repositorio: reparto);
    });

    String banco() => finanzasRepo.datos
        .cuentasDe(_libro)
        .firstWhere((c) => c.tipo == TipoCuenta.banco)
        .id;

    Future<String> sueldoComoExtra() async {
      final r = await finanzas.registrarIngresoExtra(
        libroId: _libro,
        monto: 900000,
        cuentaDestinoId: banco(),
        fecha: _viernesPasado,
        nota: 'Sueldo',
      );
      return r.movimientos.single.id;
    }

    test('aceptar no agrega movimientos por su cuenta: los crea el servidor '
        'en la misma transacción que el reparto', () async {
      final ahorro = await finanzas.crearCuenta(
        libroId: _libro,
        nombre: 'Mi ahorro',
        tipo: TipoCuenta.ahorro,
      );
      final id = await sueldoComoExtra();
      final ingreso = servicio
          .ingresos(_libro)
          .firstWhere((i) => i.movimientoId == id);
      final propuesta = servicio.proponer(ingreso);
      final antes = finanzasRepo.datos.movimientos.length;

      final d = await servicio.aceptar(
        ingreso: ingreso,
        propuesta: propuesta,
        cuentaAhorroId: ahorro.id,
      );

      expect(d.estado, EstadoDispersion.confirmada);
      expect(
        finanzasRepo.datos.movimientos.length,
        antes,
        reason: 'el servidor los crea; la app recarga el libro',
      );
      final p = fuente.llamadas.single.$2['p_dispersion']! as Map;
      expect(fuente.llamadas.single.$1, 'fin_confirmar_dispersion');
      expect(p['movimiento_id'], id);
      expect(p['cuenta_ahorro_id'], ahorro.id);
      final conMovimiento = (p['lineas']! as List)
          .cast<Map>()
          .where((l) => l.containsKey('movimiento_id'))
          .toList();
      expect(conMovimiento, hasLength(greaterThanOrEqualTo(1)));
      expect(
        conMovimiento.any(
          (l) =>
              l['movimiento_id'] ==
              idEstable(ClavesId.dispersionMovimiento(d.id, 'ahorro')),
        ),
        isTrue,
        reason: 'el ahorro lleva el mismo id estable que validó el servicio',
      );
      expect(recargas, 1);
      expect(servicio.repositorio.actuales.single.id, d.id);
    });

    test('sin señal, aceptar falla con el aviso de conexión y no deja nada '
        'a medias', () async {
      final ahorro = await finanzas.crearCuenta(
        libroId: _libro,
        nombre: 'Mi ahorro',
        tipo: TipoCuenta.ahorro,
      );
      final id = await sueldoComoExtra();
      final ingreso = servicio
          .ingresos(_libro)
          .firstWhere((i) => i.movimientoId == id);
      final propuesta = servicio.proponer(ingreso);
      final antes = finanzasRepo.datos.movimientos.length;
      fuente.sinSenal = true;
      await expectLater(
        servicio.aceptar(
          ingreso: ingreso,
          propuesta: propuesta,
          cuentaAhorroId: ahorro.id,
        ),
        throwsA(
          isA<ErrorFinanzas>().having(
            (e) => e.sinConexion,
            'sinConexion',
            true,
          ),
        ),
      );
      expect(finanzasRepo.datos.movimientos.length, antes);
      expect(reparto.actuales, isEmpty);
    });

    test(
      'deshacer llama al servidor y no anula movimientos por su cuenta',
      () async {
        final ahorro = await finanzas.crearCuenta(
          libroId: _libro,
          nombre: 'Mi ahorro',
          tipo: TipoCuenta.ahorro,
        );
        final id = await sueldoComoExtra();
        final ingreso = servicio
            .ingresos(_libro)
            .firstWhere((i) => i.movimientoId == id);
        final d = await servicio.aceptar(
          ingreso: ingreso,
          propuesta: servicio.proponer(ingreso),
          cuentaAhorroId: ahorro.id,
        );
        final movimientos = finanzasRepo.datos.movimientos.length;
        await servicio.deshacer(d.id);
        expect(fuente.llamadas.last.$1, 'fin_deshacer_dispersion');
        expect(fuente.llamadas.last.$2['p_motivo'], motivoDeshacerReparto);
        expect(
          finanzasRepo.datos.movimientos.length,
          movimientos,
          reason: 'las anulaciones las hace el servidor',
        );
        expect(reparto.actuales.single.estado, EstadoDispersion.anulada);
      },
    );

    test('cambiar el tipo manda al servidor los ids estables de los dos '
        'asientos y no los agrega por su cuenta', () async {
      final id = await sueldoComoExtra();
      final honorarios = finanzasRepo.datos
          .ingresosDe(_libro)
          .firstWhere((i) => i.nombre.startsWith('Honorarios'));
      final antes = finanzasRepo.datos.movimientos.length;
      final c = await servicio.cambiarTipo(
        movimientoId: id,
        cuentaOrigenId: honorarios.cuentaOrigenId,
        motivo: 'Era mi sueldo, no un extra',
      );
      expect(fuente.llamadas.single.$1, 'fin_corregir_tipo_ingreso');
      expect(fuente.llamadas.single.$2, {
        'p_movimiento': id,
        'p_cuenta_origen': honorarios.cuentaOrigenId,
        'p_motivo': 'Era mi sueldo, no un extra',
        'p_grupo': c.anulacion.grupoId,
        'p_id_anulacion': c.anulacion.id,
        'p_id_nuevo': c.nuevo.id,
      });
      expect(
        c.anulacion.id,
        idEstable(ClavesId.correccionIngreso(id, 'a')),
        reason: 'ids estables: repetir la corrección no duplica',
      );
      expect(finanzasRepo.datos.movimientos.length, antes);
      expect(recargas, 1);
    });

    test('la validación local sigue primero: un motivo vacío no llama al '
        'servidor', () async {
      final id = await sueldoComoExtra();
      final honorarios = finanzasRepo.datos
          .ingresosDe(_libro)
          .firstWhere((i) => i.nombre.startsWith('Honorarios'));
      await expectLater(
        servicio.cambiarTipo(
          movimientoId: id,
          cuentaOrigenId: honorarios.cuentaOrigenId,
          motivo: '  ',
        ),
        throwsA(isA<ErrorFinanzas>()),
      );
      expect(fuente.llamadas, isEmpty);
    });
  });
}
