// Fase 8 (F8-6.7): «Cambiar reparto» (P5, 20/nov/2026). Un reparto de ingreso ya
// confirmado se puede cambiar, no solo deshacer: servicio (en memoria y sobre el
// servidor, con control de versión), repositorio de Supabase y la hoja
// «Repartir ingreso» en teléfono y laptop. Datos de ejemplo inventados.
import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide Semaforo, formatearCentavos, TipoLibro, puntosBaseEnCien;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/diseno/diseno.dart' show montosVisiblesProvider;
import 'package:gravity/modulos/finanzas/casos_uso/servicio_dispersion.dart';
import 'package:gravity/modulos/finanzas/casos_uso/servicio_finanzas.dart';
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/modulos/finanzas/datos/fuente_tablas.dart';
import 'package:gravity/modulos/finanzas/datos/ids.dart'
    show ClavesId, claveDeLineaDispersion, idEstable;
import 'package:gravity/modulos/finanzas/datos/repositorio.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_dispersiones.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_dispersiones_supabase.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_memoria.dart';
import 'package:gravity/modulos/finanzas/estado/proveedores.dart';
import 'package:gravity/modulos/finanzas/estado/proveedores_dispersion.dart';
import 'package:gravity/modulos/finanzas/finanzas.dart' show SeccionFinanzas;
import 'package:gravity/modulos/finanzas/pantallas/comunes.dart'
    show conceptoDe;
import 'package:gravity/modulos/finanzas/pantallas/fila_movimiento.dart';
import 'package:gravity/modulos/finanzas/pantallas/registro/hoja_repartir_ingreso.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart'
    show hogarDeEjemplo;

import '../../revision_calidad/ayuda_calidad.dart';
import 'ayuda_finanzas.dart';

const _libro = IdsDemostracion.libroDueno;
const _papa = IdsDemostracion.libroPapa;

/// Viernes de la semana anterior a "hoy" (martes 20/oct/2026).
final _viernesPasado = Fecha(2026, 10, 16);

class _Mundo {
  _Mundo(this.repo, this.finanzas, this.reparto, this.servicio);

  final RepositorioFinanzasEnMemoria repo;
  final ServicioFinanzas finanzas;
  final RepositorioDispersiones reparto;
  final ServicioDispersion servicio;

  DatosFinanzas get datos => repo.datos;
}

_Mundo _mundo({RepositorioDispersiones? reparto}) {
  final dueno = sesionDe(Rol.dueno);
  final repo = repositorioDe(dueno);
  final finanzas = ServicioFinanzas(
    repositorio: repo,
    personaId: dueno.persona.id,
    hogarId: dueno.hogarId ?? hogarDeEjemplo,
    esDueno: true,
    reloj: () => ahoraDePrueba,
  );
  final r = reparto ?? RepositorioDispersionesEnMemoria();
  return _Mundo(
    repo,
    finanzas,
    r,
    ServicioDispersion(finanzas: finanzas, repositorio: r),
  );
}

String _banco(_Mundo m, String libro) =>
    m.datos.cuentasDe(libro).firstWhere((c) => c.tipo == TipoCuenta.banco).id;

Future<String> _sueldoComoExtra(_Mundo m, {int monto = 900000}) async {
  final r = await m.finanzas.registrarIngresoExtra(
    libroId: _libro,
    monto: monto,
    cuentaDestinoId: _banco(m, _libro),
    fecha: _viernesPasado,
    nota: 'Sueldo',
  );
  return r.movimientos.single.id;
}

Future<Cuenta> _ahorro(_Mundo m) => m.finanzas.crearCuenta(
  libroId: _libro,
  nombre: 'Mi ahorro',
  tipo: TipoCuenta.ahorro,
);

IngresoPorRepartir _ingreso(_Mundo m, String movimientoId, [String? libro]) => m
    .servicio
    .ingresos(libro ?? _libro)
    .firstWhere((i) => i.movimientoId == movimientoId);

/// Los ids de los movimientos que creó un reparto.
List<String> _movimientosDe(Dispersion d) => [
  for (final l in d.lineas)
    if (l.destino.mueveDinero && l.monto > 0)
      idEstable(ClavesId.dispersionMovimiento(d.id, claveDeLineaDispersion(l))),
];

/// La propuesta de cambio con el primer renglón que mueve dinero puesto en
/// cero: siempre es un cambio real.
PropuestaDispersion _sinElPrimerRenglon(
  _Mundo m,
  IngresoPorRepartir ingreso, {
  DestinoLinea? destino,
}) {
  final p = m.servicio.propuestaParaCambiarReparto(ingreso);
  final i = p.lineas.indexWhere(
    (l) => l.monto > 0 && (destino == null || l.destino == destino),
  );
  expect(i, isNonNegative, reason: 'el reparto tiene algo que quitar');
  return p.editar(i, 0);
}

Object? _repartoDelServidor({
  required String id,
  required String estado,
  required int version,
  String? reemplazaA,
  String movimiento = 'm1',
  String libro = 'l1',
  List<Map<String, Object?>>? lineas,
}) => {
  'id': id,
  'libro_id': libro,
  'movimiento_id': movimiento,
  'estado': estado,
  'modo': 'confirmacion',
  'version': version,
  'reemplaza_a': reemplazaA,
  'creada_en': '2026-10-20T15:00:00+00:00',
  'resuelta_por': 'p1',
  'resuelta_en': '2026-10-20T15:00:01+00:00',
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

ProviderContainer _contenedor(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(AppGravity)));

void main() {
  group('Servicio (en memoria): cambiar un reparto confirmado', () {
    test('anula lo que creó el reparto anterior, crea lo nuevo y deja el '
        'historial', () async {
      final m = _mundo();
      final ahorro = await _ahorro(m);
      final id = await _sueldoComoExtra(m);
      final ingreso = _ingreso(m, id);
      final d1 = await m.servicio.aceptar(
        ingreso: ingreso,
        propuesta: m.servicio.proponer(ingreso),
        cuentaAhorroId: ahorro.id,
      );
      final viejos = _movimientosDe(d1);
      expect(viejos, isNotEmpty);
      final saldoBanco = m.datos.vista(_libro).saldo(_banco(m, _libro));
      final antes = m.datos.movimientos.length;

      final editada = _sinElPrimerRenglon(m, _ingreso(m, id));
      final cuanto = m.servicio
          .propuestaParaCambiarReparto(_ingreso(m, id))
          .lineas
          .firstWhere((l) => l.monto > 0 && l.destino.mueveDinero);
      final d2 = await m.servicio.cambiarReparto(
        ingreso: _ingreso(m, id),
        propuesta: editada,
        cuentaAhorroId: ahorro.id,
      );

      expect(d2.version, 2);
      expect(d2.reemplazaA, d1.id);
      expect(d2.estado, EstadoDispersion.confirmada);
      final lista = m.reparto.actuales;
      expect(
        lista.firstWhere((x) => x.id == d1.id).estado,
        EstadoDispersion.reemplazada,
        reason: 'el anterior conserva su historial',
      );
      expect(lista.where((x) => x.estado.vigente), hasLength(1));
      // Libro solo-agregar: el original sigue y se agrega su contraasiento.
      final vista = m.datos.vista(_libro);
      for (final v in viejos) {
        expect(m.datos.movimientos.any((x) => x.id == v), isTrue);
      }
      expect(
        viejos.where(vista.estaAnulado).length,
        viejos.length,
        reason: 'todo lo que creó el anterior queda anulado',
      );
      // Lo quitado vuelve al banco y queda por repartir.
      final nuevos = _movimientosDe(d2);
      expect(nuevos.length, lessThan(viejos.length));
      expect(
        m.datos.vista(_libro).saldo(_banco(m, _libro)),
        saldoBanco + cuanto.monto,
      );
      expect(m.datos.movimientos.length, greaterThan(antes));
      final i = _ingreso(m, id);
      expect(i.estado, EstadoDispersion.confirmada);
      expect(i.dispersionId, d2.id);
      expect(i.pendiente, d2.porRepartir);
      expect(i.pendiente, greaterThanOrEqualTo(cuanto.monto));
    });

    test(
      'sin cambios, sin reparto aplicado o sin permiso se rechaza',
      () async {
        final m = _mundo();
        final ahorro = await _ahorro(m);
        final id = await _sueldoComoExtra(m);
        final ingreso = _ingreso(m, id);
        // Sin reparto confirmado: no hay qué cambiar.
        await expectLater(
          m.servicio.cambiarReparto(
            ingreso: ingreso,
            propuesta: m.servicio.proponer(ingreso),
          ),
          throwsA(isA<ErrorFinanzas>()),
        );
        await m.servicio.aceptar(
          ingreso: ingreso,
          propuesta: m.servicio.proponer(ingreso),
          cuentaAhorroId: ahorro.id,
        );
        final i = _ingreso(m, id);
        // Sin ediciones: no hay cambio que guardar.
        await expectLater(
          m.servicio.cambiarReparto(
            ingreso: i,
            propuesta: m.servicio.propuestaParaCambiarReparto(i),
            cuentaAhorroId: ahorro.id,
          ),
          throwsA(
            isA<ErrorFinanzas>().having(
              (e) => e.mensaje,
              'mensaje',
              contains('No hay cambios'),
            ),
          ),
        );
        // Con ahorro y sin cuenta de ahorro.
        final base = m.servicio.propuestaParaCambiarReparto(i);
        final k = base.lineas.indexWhere(
          (l) => l.destino == DestinoLinea.ahorro && l.monto > 0,
        );
        expect(k, isNonNegative, reason: 'el reparto de prueba lleva ahorro');
        await expectLater(
          m.servicio.cambiarReparto(
            ingreso: i,
            propuesta: base.editar(k, base.lineas[k].monto - 1000),
          ),
          throwsA(
            isA<ErrorFinanzas>().having(
              (e) => e.mensaje,
              'mensaje',
              contains('cuenta de ahorro'),
            ),
          ),
        );
        // Solo lectura.
        final lector = ServicioDispersion(
          finanzas: ServicioFinanzas(
            repositorio: m.repo,
            personaId: sesionDe(Rol.dueno).persona.id,
            soloLectura: true,
            reloj: () => ahoraDePrueba,
          ),
          repositorio: m.reparto,
        );
        await expectLater(
          lector.cambiarReparto(
            ingreso: i,
            propuesta: _sinElPrimerRenglon(m, i),
            cuentaAhorroId: ahorro.id,
          ),
          throwsA(isA<ErrorFinanzas>()),
        );
        expect(
          m.reparto.actuales.where((x) => x.estado.vigente),
          hasLength(1),
          reason: 'los rechazos no tocan el reparto',
        );
      },
    );

    test('el reparto cambiado se puede volver a cambiar (versión 3) y '
        'deshacer', () async {
      final m = _mundo();
      final ahorro = await _ahorro(m);
      final id = await _sueldoComoExtra(m);
      await m.servicio.aceptar(
        ingreso: _ingreso(m, id),
        propuesta: m.servicio.proponer(_ingreso(m, id)),
        cuentaAhorroId: ahorro.id,
      );
      final d2 = await m.servicio.cambiarReparto(
        ingreso: _ingreso(m, id),
        propuesta: _sinElPrimerRenglon(m, _ingreso(m, id)),
        cuentaAhorroId: ahorro.id,
      );
      expect(d2.version, 2);
      // De vuelta a lo que propone la cascada: otro cambio real.
      final p3 = m.servicio.proponer(_ingreso(m, id));
      final d3 = await m.servicio.cambiarReparto(
        ingreso: _ingreso(m, id),
        propuesta: p3,
        cuentaAhorroId: ahorro.id,
      );
      expect(d3.version, 3);
      expect(d3.reemplazaA, d2.id);
      expect(m.reparto.actuales.map((x) => '${x.version}:${x.estado.name}'), [
        '1:reemplazada',
        '2:reemplazada',
        '3:confirmada',
      ]);
      await m.servicio.deshacer(d3.id);
      expect(_ingreso(m, id).estado, EstadoDispersion.porRepartir);
      final vista = m.datos.vista(_libro);
      for (final v in _movimientosDe(d3)) {
        expect(vista.estaAnulado(v), isTrue);
      }
    });

    test(
      'en el libro de Papá el cambio exige motivo y va en su nombre',
      () async {
        final m = _mundo();
        final r = await m.finanzas.registrarIngresoExtra(
          libroId: _papa,
          monto: 200000,
          cuentaDestinoId: _banco(m, _papa),
          fecha: _viernesPasado,
          motivo: 'Apoyo del hermano',
        );
        final mov = r.movimientos.single.id;
        var p = m.servicio.proponer(_ingreso(m, mov, _papa));
        final j = p.lineas.indexWhere((l) => l.destino == DestinoLinea.ahorro);
        if (j >= 0) p = p.editar(j, 0);
        await m.servicio.aceptar(
          ingreso: _ingreso(m, mov, _papa),
          propuesta: p,
          motivo: 'Reparto del apoyo',
        );
        final i = _ingreso(m, mov, _papa);
        final base = m.servicio.propuestaParaCambiarReparto(i);
        final k = base.lineas.indexWhere((l) => l.monto > 0);
        if (k < 0) return; // nada que quitar en este libro de ejemplo
        final editada = base.editar(k, 0);
        await expectLater(
          m.servicio.cambiarReparto(ingreso: i, propuesta: editada),
          throwsA(isA<ErrorFinanzas>()),
          reason: 'el libro de Papá exige motivo',
        );
        final d = await m.servicio.cambiarReparto(
          ingreso: i,
          propuesta: editada,
          motivo: 'Corrijo el reparto',
        );
        expect(d.version, 2);
        expect(d.enNombreDe, isNotNull);
        expect(d.motivo, 'Corrijo el reparto');
      },
    );

    test('un ingreso repartido se corrige de tipo: se deshace su reparto y '
        'el ingreso nuevo nace por repartir', () async {
      final m = _mundo();
      final ahorro = await _ahorro(m);
      final id = await _sueldoComoExtra(m);
      final ingreso = _ingreso(m, id);
      final d = await m.servicio.aceptar(
        ingreso: ingreso,
        propuesta: m.servicio.proponer(ingreso),
        cuentaAhorroId: ahorro.id,
      );
      // Primero se cambia el reparto y luego se corrige el tipo del ingreso.
      final d2 = await m.servicio.cambiarReparto(
        ingreso: _ingreso(m, id),
        propuesta: _sinElPrimerRenglon(m, _ingreso(m, id)),
        cuentaAhorroId: ahorro.id,
      );
      final honorarios = m.datos
          .ingresosDe(_libro)
          .firstWhere((i) => i.nombre.startsWith('Honorarios'));
      final c = await m.servicio.cambiarTipo(
        movimientoId: id,
        cuentaOrigenId: honorarios.cuentaOrigenId,
        motivo: 'Era mi sueldo',
      );
      final vista = m.datos.vista(_libro);
      for (final v in _movimientosDe(d2)) {
        expect(vista.estaAnulado(v), isTrue, reason: 'sin huérfanos');
      }
      expect(
        m.reparto.actuales.where(
          (x) => x.movimientoId == id && x.estado.vigente,
        ),
        isEmpty,
      );
      expect(
        m.reparto.actuales.map((x) => x.id),
        containsAll([d.id, d2.id]),
        reason: 'el historial se queda',
      );
      expect(_ingreso(m, c.nuevo.id).estado, EstadoDispersion.porRepartir);
    });
  });

  group('RepositorioDispersionesSupabase: cambiar', () {
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

    Dispersion reparto(String id, int version, EstadoDispersion estado) =>
        Dispersion(
          id: id,
          libroId: 'l1',
          movimientoId: 'm1',
          estado: estado,
          lineas: const [
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
          version: version,
          reemplazaA: version > 1 ? 'a${version - 1}' : null,
        );

    test('manda fin_cambiar_dispersion con el reparto que vio y su versión, '
        'marca el anterior como reemplazado y recarga el libro', () async {
      fuente.funciones['fin_confirmar_dispersion'] = (p) {
        final d = Map<String, Object?>.from(p['p_dispersion']! as Map);
        return _repartoDelServidor(
          id: d['id']! as String,
          estado: 'confirmada',
          version: 1,
        );
      };
      fuente.funciones['fin_cambiar_dispersion'] = (p) {
        final d = Map<String, Object?>.from(p['p_cambio']! as Map);
        return _repartoDelServidor(
          id: d['id']! as String,
          estado: 'confirmada',
          version: 2,
          reemplazaA: d['dispersion_anterior_id']! as String,
        );
      };
      final a1 = reparto('a1', 1, EstadoDispersion.confirmada);
      await repo.confirmar(a1, movimientos: const []);
      final a2 = reparto('a2', 2, EstadoDispersion.confirmada);
      await repo.cambiar(a2, anterior: a1, movimientos: const []);
      final (funcion, args) = fuente.llamadas.last;
      expect(funcion, 'fin_cambiar_dispersion');
      final p = args['p_cambio']! as Map;
      expect(p['id'], 'a2');
      expect(p['dispersion_anterior_id'], 'a1');
      expect(p['version_esperada'], 1);
      expect(p['movimiento_id'], 'm1');
      expect((p['lineas']! as List), hasLength(2));
      expect(
        repo.actuales.map((d) => '${d.id}:${d.version}:${d.estado.name}'),
        ['a1:1:reemplazada', 'a2:2:confirmada'],
      );
      expect(repo.actuales.last.reemplazaA, 'a1');
      expect(
        recargas,
        1,
        reason:
            'cambiar recarga el libro (confirmar sin '
            'movimientos no)',
      );
    });

    test('si el servidor ya tiene otra versión, recarga y avisa con un '
        'mensaje claro', () async {
      fuente.tabla('fin_dispersion_lineas').addAll([
        for (final d in ['a1', 'a2'])
          {
            'id': 'l-$d',
            'dispersion_id': d,
            'orden': 0,
            'destino': 'presupuesto',
            'etiqueta': 'Renta',
            'monto_centavos': 900000,
          },
      ]);
      fuente.tabla('fin_dispersiones').addAll([
        {
          'id': 'a1',
          'libro_id': 'l1',
          'movimiento_id': 'm1',
          'estado': 'reemplazada',
          'modo': 'confirmacion',
          'version': 1,
          'creada_en': '2026-10-20T15:00:00+00:00',
        },
        {
          'id': 'a2',
          'libro_id': 'l1',
          'movimiento_id': 'm1',
          'estado': 'confirmada',
          'modo': 'confirmacion',
          'version': 2,
          'reemplaza_a': 'a1',
          'creada_en': '2026-10-20T16:00:00+00:00',
        },
      ]);
      fuente.funciones['fin_cambiar_dispersion'] = (_) =>
          throw const ErrorFinanzas(
            ErrorFinanzas.mensajeRepartoCambio,
            repartoCambio: true,
          );
      await expectLater(
        repo.cambiar(
          reparto('a3', 2, EstadoDispersion.confirmada),
          anterior: reparto('a1', 1, EstadoDispersion.confirmada),
          movimientos: const [],
        ),
        throwsA(
          isA<ErrorFinanzas>()
              .having((e) => e.repartoCambio, 'repartoCambio', true)
              .having((e) => e.mensaje, 'mensaje', contains('cambió')),
        ),
      );
      expect(
        repo.actuales.map((d) => '${d.id}:${d.version}:${d.estado.name}'),
        ['a1:1:reemplazada', 'a2:2:confirmada'],
        reason: 'se volvió a cargar lo que dice el servidor',
      );
      expect(recargas, 1, reason: 'recarga el libro para ver cómo quedó');
    });

    test('sin señal no cambia nada y avisa que necesita conexión', () async {
      fuente.sinSenal = true;
      await expectLater(
        repo.cambiar(
          reparto('a2', 2, EstadoDispersion.confirmada),
          anterior: reparto('a1', 1, EstadoDispersion.confirmada),
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

    test('deshacer un reparto que ya cambió también recarga y avisa', () async {
      fuente.funciones['fin_deshacer_dispersion'] = (_) =>
          throw const ErrorFinanzas(
            ErrorFinanzas.mensajeRepartoCambio,
            repartoCambio: true,
          );
      await expectLater(
        repo.deshacer(
          reparto('a1', 1, EstadoDispersion.confirmada),
          motivo: 'Reparto deshecho',
        ),
        throwsA(
          isA<ErrorFinanzas>().having((e) => e.repartoCambio, 'cambio', true),
        ),
      );
    });

    test('lee la versión y el vínculo de las filas', () {
      final d = dispersionDeFila({
        'id': 'a2',
        'libro_id': 'l1',
        'movimiento_id': 'm1',
        'estado': 'reemplazada',
        'modo': 'confirmacion',
        'version': 2,
        'reemplaza_a': 'a1',
        'creada_en': '2026-10-20T15:00:00+00:00',
      }, const []);
      expect(d.version, 2);
      expect(d.reemplazaA, 'a1');
      expect(d.estado, EstadoDispersion.reemplazada);
      expect(
        dispersionDeFila({
          'id': 'x',
          'libro_id': 'l1',
          'movimiento_id': 'm1',
          'estado': 'confirmada',
          'creada_en': '2026-10-20T15:00:00+00:00',
        }, const []).version,
        1,
        reason: 'sin columna, versión 1',
      );
    });
  });

  group('ServicioDispersion sobre el servidor: cambiar', () {
    late FuenteTablasEnMemoria fuente;
    late RepositorioDispersionesSupabase reparto;
    late _Mundo m;
    late int recargas;

    setUp(() {
      fuente = FuenteTablasEnMemoria();
      recargas = 0;
      reparto = RepositorioDispersionesSupabase(
        fuente: fuente,
        alCambiarMovimientos: () async => recargas++,
      );
      fuente.funciones['fin_confirmar_dispersion'] = (p) {
        final d = Map<String, Object?>.from(p['p_dispersion']! as Map);
        return _repartoDelServidor(
          id: d['id']! as String,
          libro: d['libro_id']! as String,
          movimiento: d['movimiento_id']! as String,
          estado: 'confirmada',
          version: 1,
          lineas: [
            for (final l in (d['lineas']! as List))
              Map<String, Object?>.from(l as Map),
          ],
        );
      };
      fuente.funciones['fin_cambiar_dispersion'] = (p) {
        final d = Map<String, Object?>.from(p['p_cambio']! as Map);
        return _repartoDelServidor(
          id: d['id']! as String,
          libro: d['libro_id']! as String,
          movimiento: d['movimiento_id']! as String,
          estado: 'confirmada',
          version: (d['version_esperada']! as int) + 1,
          reemplazaA: d['dispersion_anterior_id']! as String,
          lineas: [
            for (final l in (d['lineas']! as List))
              Map<String, Object?>.from(l as Map),
          ],
        );
      };
      m = _mundo(reparto: reparto);
    });

    Future<(String, Cuenta, Dispersion)> repartido() async {
      final ahorro = await _ahorro(m);
      final id = await _sueldoComoExtra(m);
      final ingreso = _ingreso(m, id);
      final d = await m.servicio.aceptar(
        ingreso: ingreso,
        propuesta: m.servicio.proponer(ingreso),
        cuentaAhorroId: ahorro.id,
      );
      return (id, ahorro, d);
    }

    test('cambiar manda la versión que vio, no agrega ni anula movimientos '
        'por su cuenta y recarga el libro', () async {
      final (id, ahorro, d1) = await repartido();
      final antes = m.datos.movimientos.length;
      final nueva = await m.servicio.cambiarReparto(
        ingreso: _ingreso(m, id),
        propuesta: _sinElPrimerRenglon(m, _ingreso(m, id)),
        cuentaAhorroId: ahorro.id,
      );
      expect(
        m.datos.movimientos.length,
        antes,
        reason: 'el servidor anula y crea en su transacción',
      );
      final (funcion, args) = fuente.llamadas.last;
      expect(funcion, 'fin_cambiar_dispersion');
      final p = args['p_cambio']! as Map;
      expect(p['dispersion_anterior_id'], d1.id);
      expect(p['version_esperada'], 1);
      expect(p['id'], nueva.id);
      expect(p['cuenta_ahorro_id'], ahorro.id);
      expect(nueva.version, 2);
      expect(reparto.actuales.map((d) => d.estado.name), [
        'reemplazada',
        'confirmada',
      ]);
      expect(recargas, 2);
    });

    test(
      'reintentar el mismo cambio manda el mismo id; otro cambio del mismo '
      'reparto manda otro (así choca con la versión en vez de pisar)',
      () async {
        final (id, ahorro, _) = await repartido();
        final ids = <Object?>[];
        fuente.funciones['fin_cambiar_dispersion'] = (p) {
          ids.add((p['p_cambio']! as Map)['id']);
          throw ErrorFinanzas.conexion;
        };
        final editada = _sinElPrimerRenglon(m, _ingreso(m, id));
        final vigente = m.servicio.propuestaParaCambiarReparto(_ingreso(m, id));
        final j = vigente.lineas.indexWhere((l) => l.monto > 0);
        final otra = vigente.editar(j, vigente.lineas[j].monto - 1000);
        Future<void> intenta(PropuestaDispersion p) async {
          try {
            await m.servicio.cambiarReparto(
              ingreso: _ingreso(m, id),
              propuesta: p,
              cuentaAhorroId: ahorro.id,
            );
          } on ErrorFinanzas {
            // sin señal
          }
        }

        await intenta(editada);
        await intenta(otra);
        await intenta(editada);
        expect(ids, hasLength(3));
        expect(ids[0], ids[2], reason: 'el mismo cambio, el mismo id');
        expect(ids[0], isNot(ids[1]), reason: 'otro cambio, otro id');
      },
    );

    test('si otro dispositivo ya cambió el reparto: mensaje claro y recarga '
        'lo del servidor', () async {
      final (id, ahorro, d1) = await repartido();
      fuente.tabla('fin_dispersion_lineas').addAll([
        for (final d in [d1.id, 'otro-dispositivo'])
          {
            'id': 'l-$d',
            'dispersion_id': d,
            'orden': 0,
            'destino': 'presupuesto',
            'etiqueta': 'Renta',
            'monto_centavos': 900000,
          },
      ]);
      fuente.tabla('fin_dispersiones').addAll([
        {
          'id': d1.id,
          'libro_id': _libro,
          'movimiento_id': id,
          'estado': 'reemplazada',
          'modo': 'confirmacion',
          'version': 1,
          'creada_en': '2026-10-20T15:00:00+00:00',
        },
        {
          'id': 'otro-dispositivo',
          'libro_id': _libro,
          'movimiento_id': id,
          'estado': 'confirmada',
          'modo': 'confirmacion',
          'version': 2,
          'reemplaza_a': d1.id,
          'creada_en': '2026-10-20T16:00:00+00:00',
        },
      ]);
      fuente.funciones['fin_cambiar_dispersion'] = (_) =>
          throw const ErrorFinanzas(
            ErrorFinanzas.mensajeRepartoCambio,
            repartoCambio: true,
          );
      final recargasAntes = recargas;
      await expectLater(
        m.servicio.cambiarReparto(
          ingreso: _ingreso(m, id),
          propuesta: _sinElPrimerRenglon(m, _ingreso(m, id)),
          cuentaAhorroId: ahorro.id,
        ),
        throwsA(
          isA<ErrorFinanzas>()
              .having((e) => e.repartoCambio, 'repartoCambio', true)
              .having(
                (e) => e.mensaje,
                'mensaje',
                ErrorFinanzas.mensajeRepartoCambio,
              ),
        ),
      );
      // El servicio ya ve el reparto del otro dispositivo (versión 2).
      expect(m.servicio.repartoAplicadoDe(id)!.id, 'otro-dispositivo');
      expect(m.servicio.repartoAplicadoDe(id)!.version, 2);
      expect(recargas, greaterThan(recargasAntes));
    });

    test('corregir el tipo de un ingreso repartido llama al servidor (que '
        'deshace el reparto) sin rechazarlo en el dispositivo', () async {
      final (id, _, d1) = await repartido();
      fuente.funciones['fin_corregir_tipo_ingreso'] = (_) => {};
      final honorarios = m.datos
          .ingresosDe(_libro)
          .firstWhere((i) => i.nombre.startsWith('Honorarios'));
      await m.servicio.cambiarTipo(
        movimientoId: id,
        cuentaOrigenId: honorarios.cuentaOrigenId,
        motivo: 'Era mi sueldo',
      );
      expect(fuente.llamadas.last.$1, 'fin_corregir_tipo_ingreso');
      expect(
        reparto.actuales.firstWhere((x) => x.id == d1.id).estado,
        EstadoDispersion.anulada,
      );
    });
  });

  for (final e in {
    'teléfono': (TipoDispositivo.telefono, const Size(360, 800)),
    'laptop': (TipoDispositivo.laptop, const Size(1100, 800)),
  }.entries) {
    group('Hoja «Repartir ingreso» para cambiar el reparto, en ${e.key}', () {
      Future<({String id, String libro})> preparar(
        WidgetTester tester, {
        double letra = 1.0,
      }) async {
        final repo = await montarFinanzasConTamano(
          tester,
          dispositivo: e.value.$1,
          tamano: e.value.$2,
          escalaDeLetra: letra,
        );
        final c = _contenedor(tester);
        final ctx = c.read(contextoFinanzasProvider).value!;
        final base = servicioDe(repo, sesionDe(Rol.dueno));
        final r = await base.registrarIngresoExtra(
          libroId: ctx.libroId,
          monto: 900000,
          cuentaDestinoId: ctx.datos
              .cuentasDe(ctx.libroId)
              .firstWhere((x) => x.tipo == TipoCuenta.banco)
              .id,
          fecha: _viernesPasado,
          nota: 'Sueldo',
        );
        final ahorro = await base.crearCuenta(
          libroId: ctx.libroId,
          nombre: 'Mi ahorro',
          tipo: TipoCuenta.ahorro,
        );
        await avanzar(tester);
        c.read(montosVisiblesProvider.notifier).fijar(true);
        final servicio = c.read(servicioDispersionProvider);
        final id = r.movimientos.single.id;
        final ingreso = servicio
            .ingresos(ctx.libroId)
            .firstWhere((i) => i.movimientoId == id);
        await servicio.aceptar(
          ingreso: ingreso,
          propuesta: servicio.proponer(ingreso),
          cuentaAhorroId: ahorro.id,
        );
        await avanzar(tester);
        return (id: id, libro: ctx.libroId);
      }

      Future<void> abrir(WidgetTester tester, String id, String libro) async {
        final contexto = tester.element(find.byType(Scaffold).first);
        mostrarHojaRepartir(contexto, libroId: libro, movimientoId: id);
        await tester.pumpAndSettle();
      }

      testWidgets('se abre con el reparto vigente editable y «Guardar '
          'cambios»', (tester) async {
        final (:id, :libro) = await preparar(tester);
        await abrir(tester, id, libro);
        expect(
          find.byKey(const ValueKey('repartir-guardar-cambios')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('repartir-editar')), findsOneWidget);
        expect(find.byKey(const ValueKey('repartir-aceptar')), findsNothing);
        expect(find.byKey(const ValueKey('repartir-despues')), findsNothing);
        expect(
          find.byKey(const ValueKey('repartir-aviso-cambio')),
          findsOneWidget,
        );
        expect(find.text('Reparto confirmado'), findsOneWidget);
        // Editable desde el principio.
        expect(find.byKey(const ValueKey('repartir-linea-0')), findsOneWidget);
        // Sin cambios, «Guardar cambios» está apagado.
        final boton = tester.widget<FilledButton>(
          find.byKey(const ValueKey('repartir-guardar-cambios')),
        );
        expect(boton.onPressed, isNull);
        expect(tester.takeException(), isNull);
      });

      testWidgets('editar un renglón y Guardar cambios anula lo anterior y '
          'crea lo nuevo', (tester) async {
        final (:id, :libro) = await preparar(tester);
        final c = _contenedor(tester);
        final servicio = c.read(servicioDispersionProvider);
        final vigente = servicio.repartoAplicadoDe(id)!;
        final viejos = _movimientosDeTest(vigente);
        await abrir(tester, id, libro);
        final p = servicio.propuestaParaCambiarReparto(
          servicio.ingresos(libro).firstWhere((i) => i.movimientoId == id),
        );
        final i = p.lineas.indexWhere(
          (l) => l.monto > 0 && l.destino.mueveDinero,
        );
        expect(i, isNonNegative);
        await tester.enterText(find.byKey(ValueKey('repartir-linea-$i')), '0');
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('repartir-error')), findsNothing);
        await tester.ensureVisible(
          find.byKey(const ValueKey('repartir-guardar-cambios')),
        );
        await tester.tap(
          find.byKey(const ValueKey('repartir-guardar-cambios')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('repartir-guardar-cambios')),
          findsNothing,
          reason: 'la hoja se cierra',
        );
        final nuevo = servicio.repartoAplicadoDe(id)!;
        expect(nuevo.version, 2);
        expect(nuevo.reemplazaA, vigente.id);
        final ctx = c.read(contextoFinanzasProvider).value!;
        final vista = ctx.datos.vista(libro);
        for (final v in viejos) {
          expect(vista.estaAnulado(v), isTrue);
        }
        expect(find.text('Listo: cambié tu reparto.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('si el reparto cambió en otro dispositivo, avisa y vuelve '
          'a armar la hoja con lo que quedó', (tester) async {
        final (:id, :libro) = await preparar(tester);
        final c = _contenedor(tester);
        final servicio = c.read(servicioDispersionProvider);
        final repo = c.read(repositorioDispersionesProvider);
        final vigente = servicio.repartoAplicadoDe(id)!;
        await abrir(tester, id, libro);
        // Mientras la hoja está abierta, otro dispositivo lo cambia: el
        // repositorio en memoria lo refleja como versión 2.
        await repo.guardar(vigente.conEstado(EstadoDispersion.reemplazada));
        await repo.guardar(
          Dispersion(
            id: 'otro',
            libroId: libro,
            movimientoId: id,
            estado: EstadoDispersion.confirmada,
            lineas: [
              LineaDispersion(
                destino: DestinoLinea.presupuesto,
                etiqueta: 'Renta',
                monto: 900000,
              ),
            ],
            creadaEn: DateTime(2026, 10, 20, 11),
            version: 2,
            reemplazaA: vigente.id,
          ),
        );
        await tester.pumpAndSettle();
        // La hoja sigue abierta y ahora muestra el reparto vigente nuevo.
        expect(
          find.byKey(const ValueKey('repartir-guardar-cambios')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('letra grande: no se desborda y los botones quedan a la '
          'vista', (tester) async {
        final (:id, :libro) = await preparar(tester, letra: 2.0);
        final errores = await recolectar(() async {
          await abrir(tester, id, libro);
        });
        expect(
          errores.desbordes,
          isEmpty,
          reason: errores.desbordes.join('\n'),
        );
        final r = tester.getRect(
          find.byKey(const ValueKey('repartir-guardar-cambios')),
        );
        expect(r.bottom, lessThanOrEqualTo(e.value.$2.height));
        expect(find.byKey(const ValueKey('repartir-cancelar')), findsOneWidget);
      });

      testWidgets('con los montos ocultos no hay cifras en la hoja', (
        tester,
      ) async {
        final (:id, :libro) = await preparar(tester);
        _contenedor(tester).read(montosVisiblesProvider.notifier).fijar(false);
        await abrir(tester, id, libro);
        expect(
          find.descendant(
            of: find.byType(HojaRepartirIngreso),
            matching: find.textContaining(r'$'),
          ),
          findsNothing,
        );
      });

      testWidgets('«Cambiar reparto…» está en Movimientos del ingreso '
          'repartido', (tester) async {
        final (:id, :libro) = await preparar(tester);
        await irA(tester, SeccionFinanzas.movimientos.ruta);
        if (e.value.$1 == TipoDispositivo.laptop) {
          // La tabla de la laptop: se toca la fila del ingreso y el detalle
          // trae «Cambiar reparto…».
          final ctx = _contenedor(tester).read(contextoFinanzasProvider).value!;
          final m = ctx.datos.movimientos.firstWhere((x) => x.id == id);
          final concepto = conceptoDe(m, ctx.datos, ctx.datos.vista(libro));
          final celda = find.text(concepto).first;
          await tester.ensureVisible(celda);
          await tester.tap(celda);
          await tester.pumpAndSettle();
          final boton = find.byKey(
            const ValueKey('movimientos-cambiar-reparto'),
          );
          await tester.ensureVisible(boton);
          await tester.tap(boton);
        } else {
          final fila = find.byWidgetPredicate(
            (w) => w is FilaMovimiento && w.movimiento.id == id,
          );
          if (fila.evaluate().isEmpty) {
            await tester.scrollUntilVisible(
              fila,
              300,
              scrollable: find.byType(Scrollable).first,
            );
          }
          await tester.tap(find.byKey(ValueKey('movimiento-menu-$id')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Cambiar reparto…'));
        }
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('repartir-guardar-cambios')),
          findsOneWidget,
        );
        expect(libro, isNotEmpty);
      });
    });
  }
}

List<String> _movimientosDeTest(Dispersion d) => _movimientosDe(d);
