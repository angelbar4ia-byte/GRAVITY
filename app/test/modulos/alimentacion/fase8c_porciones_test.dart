// Fase 8 v1.3: porciones recomendadas editables por dueño y pareja. Cada
// persona cambia la suya; la otra conserva la suya; de 0.25 a 20; la familiar,
// Casa y la cuidadora no las cambian. El servidor recibe los parámetros de
// ali_fijar_porcion y la lectura pasa por ali_porciones_recomendadas.
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/alimentacion/repositorio_alimentacion_supabase.dart';
import 'package:gravity/modulos/alimentacion/casos_uso/servicio_alimentacion.dart';
import 'package:gravity/modulos/alimentacion/datos/modelos.dart';
import 'package:gravity/modulos/alimentacion/datos/repositorio.dart';
import 'package:gravity/modulos/finanzas/datos/fuente_tablas.dart';
import 'package:gravity/nucleo/contratos/roles.dart';

final _lunes = DateTime(2026, 11, 2);
const _hogar = '00000000-0000-4000-8000-000000000001';
const _yo = '00000000-0000-4000-8000-0000000000a1';

RepositorioAlimentacionEnMemoria _repoConPorciones() {
  final r = RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes);
  r.porcionesMemoria.addAll(const [
    PorcionPersona(platilloId: 'p1', cuenta: CuentaCompra.dueno, porciones: 1.5),
    PorcionPersona(platilloId: 'p1', cuenta: CuentaCompra.pareja, porciones: 1),
  ]);
  return r;
}

void main() {
  group('porciones editables (Fase 8 v1.3)', () {
    test('dueño cambia su porción y la de la pareja se conserva', () async {
      final r = _repoConPorciones();
      final s = ServicioAlimentacion(r, rol: Rol.dueno);
      await s.fijarPorcion(
        platilloId: 'p1',
        semana: _lunes,
        cuenta: CuentaCompra.dueno,
        porciones: 2,
      );
      final m = await s.porcionesPorPlatillo(_lunes);
      expect({
        for (final p in m['p1']!) p.cuenta: p.porciones,
      }, {CuentaCompra.dueno: 2.0, CuentaCompra.pareja: 1.0});
    });

    test('la pareja (coadministrador) también cambia la suya', () async {
      final r = _repoConPorciones();
      final s = ServicioAlimentacion(r, rol: Rol.coadministrador);
      await s.fijarPorcion(
        platilloId: 'p1',
        semana: _lunes,
        cuenta: CuentaCompra.pareja,
        porciones: 0.25,
      );
      final m = await s.porcionesPorPlatillo(_lunes);
      expect({
        for (final p in m['p1']!) p.cuenta: p.porciones,
      }, {CuentaCompra.dueno: 1.5, CuentaCompra.pareja: 0.25});
    });

    test('fuera de 0.25 a 20 o no numérica no se guarda', () async {
      final r = _repoConPorciones();
      final s = ServicioAlimentacion(r, rol: Rol.dueno);
      for (final malo in [0.1, 0.0, 21.0, double.nan]) {
        await expectLater(
          s.fijarPorcion(
            platilloId: 'p1',
            semana: _lunes,
            cuenta: CuentaCompra.dueno,
            porciones: malo,
          ),
          throwsA(isA<ArgumentError>()),
        );
      }
      final m = await s.porcionesPorPlatillo(_lunes);
      expect(m['p1']!.firstWhere((p) => p.cuenta == CuentaCompra.dueno).porciones, 1.5);
    });

    test('la familiar, Casa y la cuidadora no cambian porciones', () async {
      for (final rol in [Rol.familiar, Rol.casa, Rol.cuidador]) {
        final r = _repoConPorciones();
        await expectLater(
          ServicioAlimentacion(r, rol: rol).fijarPorcion(
            platilloId: 'p1',
            semana: _lunes,
            cuenta: CuentaCompra.dueno,
            porciones: 3,
          ),
          throwsA(isA<PermisoDenegado>()),
          reason: rol.name,
        );
      }
    });

    test('servidor: ali_fijar_porcion recibe la cuenta y la porción', () async {
      final f = FuenteTablasEnMemoria();
      f.funciones['ali_fijar_porcion'] = (_) => 2;
      final repo = RepositorioAlimentacionSupabase(
        fuente: f,
        hogarId: _hogar,
        personaId: _yo,
      );
      await repo.fijarPorcion(
        platilloId: 'p1',
        lunes: _lunes,
        cuenta: CuentaCompra.pareja,
        porciones: 1.5,
      );
      expect(f.llamadas.single.$2, {
        'p_hogar_id': _hogar,
        'p_platillo': 'p1',
        'p_semana': '2026-11-02',
        'p_cuenta': 'pareja',
        'p_porciones': 1.5,
      });
    });
  });
}
