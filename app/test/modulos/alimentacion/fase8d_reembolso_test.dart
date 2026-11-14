// Fase 8 v1.4: reembolso de compras de Papá. Rechazada = queda en el histórico
// y quien compró puede reenviarla una vez con justificación (3 a 200). Si se
// rechaza otra vez, el gasto es de quien compró.
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/alimentacion/repositorio_alimentacion_supabase.dart';
import 'package:gravity/modulos/alimentacion/casos_uso/servicio_alimentacion.dart';
import 'package:gravity/modulos/alimentacion/datos/repositorio.dart';
import 'package:gravity/modulos/finanzas/datos/fuente_tablas.dart';
import 'package:gravity/nucleo/contratos/roles.dart';

final _lunes = DateTime(2026, 11, 2);
const _hogar = '00000000-0000-4000-8000-000000000001';
const _yo = '00000000-0000-4000-8000-0000000000a1';
const _otra = '00000000-0000-4000-8000-0000000000b2';

void _sembrar(FuenteTablasEnMemoria f) {
  f.tablas['ali_ingredientes'] = [
    {'id': 'i1', 'hogar_id': _hogar, 'nombre': 'Avena', 'unidad': 'g'},
  ];
  f.tablas['ali_compras'] = [
    {'id': 'c1', 'hogar_id': _hogar, 'ingrediente_id': 'i1', 'cantidad': 2, 'cuenta': 'papa'},
    {'id': 'c2', 'hogar_id': _hogar, 'ingrediente_id': 'i1', 'cantidad': 1, 'cuenta': 'papa'},
    {'id': 'c3', 'hogar_id': _hogar, 'ingrediente_id': 'i1', 'cantidad': 1, 'cuenta': 'papa'},
  ];
  f.tablas['ali_solicitudes_pago'] = [
    // Mía, rechazada, sin reenvío: se puede reenviar.
    {'id': 's1', 'hogar_id': _hogar, 'compra_id': 'c1', 'monto_centavos': 3000,
     'estado': 'rechazada', 'intento': 1, 'solicitada_por': _yo},
    // De otra persona: no es mía.
    {'id': 's2', 'hogar_id': _hogar, 'compra_id': 'c3', 'monto_centavos': 900,
     'estado': 'rechazada', 'intento': 1, 'solicitada_por': _otra},
    // Mía, rechazada y ya reenviada: no se ofrece de nuevo.
    {'id': 's3', 'hogar_id': _hogar, 'compra_id': 'c2', 'monto_centavos': 1500,
     'estado': 'rechazada', 'intento': 1, 'solicitada_por': _yo},
    {'id': 's4', 'hogar_id': _hogar, 'compra_id': 'c2', 'monto_centavos': 1500,
     'estado': 'pendiente', 'intento': 2, 'solicitada_por': _yo, 'justificacion': 'Era para la cena'},
  ];
}

void main() {
  group('gasto de quien compró (Fase 8 v1.7)', () {
    test('quien compró ve registrar (rechazada final) y anular (ya reclasificada)', () async {
      final f = FuenteTablasEnMemoria();
      f.tablas['ali_ingredientes'] = [
        {'id': 'i1', 'hogar_id': _hogar, 'nombre': 'Avena', 'unidad': 'g'},
      ];
      f.tablas['ali_compras'] = [
        {'id': 'c1', 'hogar_id': _hogar, 'ingrediente_id': 'i1', 'cantidad': 2, 'cuenta': 'papa',
         'estado_pago': 'rechazada', 'movimiento_id': null},
        {'id': 'c2', 'hogar_id': _hogar, 'ingrediente_id': 'i1', 'cantidad': 1, 'cuenta': 'papa',
         'estado_pago': 'movimiento', 'movimiento_id': 'm2'},
      ];
      f.tablas['ali_solicitudes_pago'] = [
        {'id': 's1', 'hogar_id': _hogar, 'compra_id': 'c1', 'monto_centavos': 3000, 'estado': 'rechazada',
         'intento': 2, 'solicitada_por': _yo, 'reclasificacion_movimiento_id': null, 'transferencia_id': null},
        {'id': 's2', 'hogar_id': _hogar, 'compra_id': 'c2', 'monto_centavos': 1500, 'estado': 'rechazada',
         'intento': 2, 'solicitada_por': _yo, 'reclasificacion_movimiento_id': 'mp2', 'transferencia_id': null},
      ];
      f.funciones['ali_detalle_reembolso'] = (_) => {
        'reclasificacion': {'movimiento_papa_id': 'mp2', 'anulado_por_comprador': false},
      };
      final repo = RepositorioAlimentacionSupabase(fuente: f, hogarId: _hogar, personaId: _yo);
      final g = await repo.gastosRechazados();
      expect(g.map((x) => '${x.compraId}:${x.accion.name}'), ['c1:registrar', 'c2:anular']);
    });

    test('registrar y anular llaman a sus funciones del servidor', () async {
      final f = FuenteTablasEnMemoria();
      f.funciones['ali_registrar_gasto_rechazado'] = (_) => 'm1';
      f.funciones['ali_anular_gasto_propio'] = (_) => 'a1';
      final repo = RepositorioAlimentacionSupabase(fuente: f, hogarId: _hogar, personaId: _yo);
      await repo.registrarGastoRechazado(compraId: 'c1', cuentaId: 'cu1');
      await repo.anularGastoPropio(compraId: 'c2', motivo: 'Se pasó a Papá');
      expect(f.llamadas[0].$1, 'ali_registrar_gasto_rechazado');
      expect(f.llamadas[0].$2, {'p_compra': 'c1', 'p_cuenta': 'cu1'});
      expect(f.llamadas[1].$1, 'ali_anular_gasto_propio');
      expect(f.llamadas[1].$2, {'p_compra': 'c2', 'p_motivo': 'Se pasó a Papá'});
    });

    test('el motivo de anular lleva 3 caracteres o más, sin llamar al servidor', () async {
      final r = RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes);
      await expectLater(
        ServicioAlimentacion(r, rol: Rol.dueno).anularGastoPropio('c2', motivo: '  ab '),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('reembolso de compras de Papá (Fase 8 v1.4)', () {
    test('quien compró ve solo sus rechazadas que aún puede reenviar', () async {
      final f = FuenteTablasEnMemoria();
      _sembrar(f);
      final repo = RepositorioAlimentacionSupabase(fuente: f, hogarId: _hogar, personaId: _yo);
      final lista = await repo.solicitudesRechazadasMias();
      expect(lista.map((s) => s.id), ['s1']);
      expect(lista.single.ingrediente, 'Avena');
      expect(lista.single.montoCentavos, 3000);
    });

    test('servidor: reenviar manda la solicitud y la justificación', () async {
      final f = FuenteTablasEnMemoria();
      f.funciones['ali_reenviar_solicitud'] = (_) => 's5';
      final repo = RepositorioAlimentacionSupabase(fuente: f, hogarId: _hogar, personaId: _yo);
      await repo.reenviarSolicitud(solicitudId: 's1', justificacion: 'Era para la cena');
      expect(f.llamadas.single.$1, 'ali_reenviar_solicitud');
      expect(f.llamadas.single.$2, {'p_solicitud': 's1', 'p_justificacion': 'Era para la cena'});
    });

    test('la justificación va de 3 a 200 caracteres, sin llamar al servidor', () async {
      final r = RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes);
      final s = ServicioAlimentacion(r, rol: Rol.dueno);
      await expectLater(
        s.reenviarSolicitud('s1', justificacion: '  ab  '),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        s.reenviarSolicitud('s1', justificacion: 'x' * 201),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
