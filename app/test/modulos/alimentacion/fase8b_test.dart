// Fase 8 v1.1 (2b): tiendas editables y borrables, regresar compra, compra
// rechazada en el historial, Casa solo ve platillos de la comida familiar y
// del menú de Papá, y porciones recomendadas por persona.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/alimentacion/repositorio_alimentacion_supabase.dart';
import 'package:gravity/app/sesion_efectiva.dart';
import 'package:gravity/diseno/proveedores.dart' show RelojFijo, relojProvider;
import 'package:gravity/modulos/alimentacion/casos_uso/plan_familiar.dart';
import 'package:gravity/modulos/alimentacion/casos_uso/servicio_alimentacion.dart';
import 'package:gravity/modulos/alimentacion/datos/ejemplo.dart';
import 'package:gravity/modulos/alimentacion/datos/modelos.dart';
import 'package:gravity/modulos/alimentacion/datos/repositorio.dart';
import 'package:gravity/modulos/alimentacion/estado/proveedores.dart';
import 'package:gravity/modulos/alimentacion/pantallas/compras.dart';
import 'package:gravity/modulos/alimentacion/pantallas/historial_completo.dart';
import 'package:gravity/modulos/alimentacion/pantallas/tiendas.dart';
import 'package:gravity/modulos/finanzas/datos/fuente_tablas.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';

final _lunes = DateTime(2026, 11, 2);
const _hogar = '00000000-0000-4000-8000-000000000001';
const _yo = '00000000-0000-4000-8000-0000000000a1';
const _t1 = '00000000-0000-4000-8000-0000000000e1';
const _comp = '00000000-0000-4000-8000-0000000000f1';

Future<(RepositorioAlimentacionEnMemoria, ServicioAlimentacion, Tienda)>
_conCompra({Rol rol = Rol.dueno}) async {
  final repo = RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes);
  final s = ServicioAlimentacion(repo, rol: rol);
  final t = await ServicioAlimentacion(repo, rol: Rol.dueno).agregarTienda('Súper');
  await ServicioAlimentacion(repo, rol: Rol.dueno).registrarCompra(
    MenuId.pareja,
    _lunes,
    claveCompra('Huevo', 'pza'),
    cantidadComprada: 12,
    totalCentavos: 4800,
    tiendaId: t.id,
  );
  return (repo, s, t);
}

void main() {
  group('Tiendas: editar y borrar', () {
    test('dueño y pareja editan el nombre; el historial lo conserva', () async {
      for (final rol in [Rol.dueno, Rol.coadministrador]) {
        final (repo, s, t) = await _conCompra(rol: rol);
        final n = await s.editarTienda(t.id, '  Súper Centro ');
        expect(n.nombre, 'Súper Centro');
        expect((await s.tiendas()).single.nombre, 'Súper Centro');
        final h = await repo.historialCompleto(CuentaCompra.dueno);
        expect(h.single.tienda, 'Súper Centro');
        await expectLater(s.editarTienda(t.id, '  '), throwsArgumentError);
        await expectLater(s.editarTienda(t.id, 'x' * 61), throwsArgumentError);
      }
    });

    test('quien no edita no edita ni borra tiendas', () async {
      final (repo, _, t) = await _conCompra();
      for (final rol in [Rol.familiar, Rol.cuidador, Rol.casa]) {
        final s = ServicioAlimentacion(repo, rol: rol);
        await expectLater(s.editarTienda(t.id, 'X'), throwsA(isA<PermisoDenegado>()));
        await expectLater(s.borrarTienda(t.id), throwsA(isA<PermisoDenegado>()));
      }
    });

    test('borrar una tienda sin compras la quita', () async {
      final repo = RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes);
      final s = ServicioAlimentacion(repo, rol: Rol.coadministrador);
      final t = await s.agregarTienda('Tianguis');
      expect(await s.borrarTienda(t.id), ResultadoBorradoTienda.borrada);
      expect(await s.tiendas(), isEmpty);
    });

    test('borrar una tienda con compras la desactiva y ya no se ofrece', () async {
      final (_, s, t) = await _conCompra();
      final r = await s.borrarTienda(t.id);
      expect(r, ResultadoBorradoTienda.desactivada);
      expect(r.mensaje, 'La tienda tiene compras: se desactivó.');
      final ts = await s.tiendas();
      expect(ts.single.activa, isFalse);
      await expectLater(
        s.registrarCompra(
          MenuId.pareja,
          _lunes,
          claveCompra('Avena', 'g'),
          cantidadComprada: 500,
          totalCentavos: 3000,
          tiendaId: t.id,
        ),
        throwsArgumentError,
      );
    });

    test('servidor: editar y borrar van por ali_editar_tienda y ali_borrar_tienda', () async {
      final f = FuenteTablasEnMemoria();
      f.funciones['ali_editar_tienda'] = (_) => null;
      f.funciones['ali_borrar_tienda'] = (_) => 'desactivada';
      final repo = RepositorioAlimentacionSupabase(
        fuente: f,
        hogarId: _hogar,
        personaId: _yo,
      );
      await repo.editarTienda(_t1, 'Nueva');
      expect(f.llamadas.first.$1, 'ali_editar_tienda');
      expect(f.llamadas.first.$2, {'p_tienda': _t1, 'p_nombre': 'Nueva'});
      expect(await repo.borrarTienda(_t1), ResultadoBorradoTienda.desactivada);
      f.funciones['ali_borrar_tienda'] = (_) => {'resultado': 'borrada'};
      expect(await repo.borrarTienda(_t1), ResultadoBorradoTienda.borrada);
    });

    testWidgets('pantalla: borrar con compras dice que se desactivó', (t) async {
      await t.binding.setSurfaceSize(const Size(500, 1200));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final (repo, _, tienda) = await _conCompra();
      await t.pumpWidget(_app(repo, const PantallaTiendas()));
      await t.pumpAndSettle();
      await t.tap(find.byKey(Key('borrar_tienda_${tienda.id}')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('confirmar_borrar_tienda')));
      await t.pumpAndSettle();
      expect(find.text('La tienda tiene compras: se desactivó.'), findsOneWidget);
      expect(find.text('Desactivada'), findsOneWidget);
    });
  });

  group('Regresar compra', () {
    test('pide motivo de 3 caracteres y la compra vuelve a pendiente', () async {
      final (repo, s, _) = await _conCompra();
      final clave = claveCompra('Huevo', 'pza');
      expect(await repo.comprados(MenuId.pareja, _lunes), contains(clave));
      for (final m in ['', 'ab', '  a ']) {
        await expectLater(
          s.regresarCompra(MenuId.pareja, _lunes, clave, motivo: m),
          throwsArgumentError,
          reason: 'motivo "$m"',
        );
      }
      expect(await repo.comprados(MenuId.pareja, _lunes), contains(clave));
      await s.regresarCompra(MenuId.pareja, _lunes, clave, motivo: 'Mal precio');
      expect(await repo.comprados(MenuId.pareja, _lunes), isNot(contains(clave)));
      // La original se conserva, como revertida, y no suma en el análisis.
      final h = await repo.historialCompleto(CuentaCompra.dueno);
      expect(h.single.revertida, isTrue);
      expect(
        resumirHistorial(h, const FiltroHistorial()).totalCentavos,
        0,
      );
    });

    test('quien no edita no regresa compras', () async {
      final (repo, _, _) = await _conCompra();
      for (final rol in [Rol.familiar, Rol.cuidador, Rol.casa]) {
        await expectLater(
          ServicioAlimentacion(repo, rol: rol).regresarCompra(
            MenuId.pareja,
            _lunes,
            claveCompra('Huevo', 'pza'),
            motivo: 'Error',
          ),
          throwsA(isA<PermisoDenegado>()),
        );
      }
    });

    test('servidor: llama ali_regresar_compra con la compra y el motivo', () async {
      final f = FuenteTablasEnMemoria();
      f.tabla('ali_ingredientes').add({
        'id': 'i1', 'nombre': 'Huevo', 'unidad': 'pza',
      });
      f.tabla('ali_compras').addAll([
        {'id': 'viejo', 'cuenta': 'dueno', 'ingrediente_id': 'i1', 'comprado': true, 'comprado_en': '2026-10-01T10:00:00Z'},
        {'id': _comp, 'cuenta': 'dueno', 'ingrediente_id': 'i1', 'comprado': true, 'comprado_en': '2026-11-03T10:00:00Z'},
      ]);
      f.funciones['ali_regresar_compra'] = (_) => null;
      final repo = RepositorioAlimentacionSupabase(
        fuente: f,
        hogarId: _hogar,
        personaId: _yo,
      );
      await expectLater(
        repo.regresarCompra(menu: MenuId.pareja, lunes: _lunes, clave: claveCompra('Huevo', 'pza'), motivo: 'no'),
        throwsA(isA<ErrorAlimentacionServidor>()),
      );
      await repo.regresarCompra(
        menu: MenuId.pareja,
        lunes: _lunes,
        clave: claveCompra('Huevo', 'pza'),
        motivo: ' Mal precio ',
      );
      expect(f.llamadas.single.$1, 'ali_regresar_compra');
      expect(f.llamadas.single.$2, {'p_compra': _comp, 'p_motivo': 'Mal precio'});
    });

    testWidgets('pantalla: el botón pide el motivo y regresa la compra', (t) async {
      await t.binding.setSurfaceSize(const Size(600, 3000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final (repo, _, _) = await _conCompra();
      final clave = claveCompra('Huevo', 'pza');
      await t.pumpWidget(_app(repo, const PantallaListaCompras(), menu: MenuId.pareja));
      await t.pumpAndSettle();
      await t.tap(find.byKey(Key('regresar_$clave')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('motivo_regreso')), 'ab');
      await t.tap(find.byKey(const Key('confirmar_regreso')));
      await t.pumpAndSettle();
      expect(find.textContaining('al menos 3 caracteres'), findsOneWidget);
      expect(await repo.comprados(MenuId.pareja, _lunes), contains(clave));
      await t.tap(find.byKey(Key('regresar_$clave')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('motivo_regreso')), 'Se echó a perder');
      await t.tap(find.byKey(const Key('confirmar_regreso')));
      await t.pumpAndSettle();
      expect(await repo.comprados(MenuId.pareja, _lunes), isNot(contains(clave)));
      expect(repo.regresadas.single.$2, 'Se echó a perder');
    });
  });

  group('Historial: compra rechazada y revertida', () {
    test('servidor: la rechazada sigue en el historial con su nueva cuenta', () async {
      final f = FuenteTablasEnMemoria();
      f.funciones['ali_historial_compras'] = (_) => [
        {
          'compra_id': _comp,
          'ingrediente': 'Avena',
          'unidad': 'g',
          'cantidad': 500,
          'monto_centavos': 3000,
          'fecha': '2026-11-03T10:00:00Z',
          'cuenta_pago': 'Cuenta del dueño',
        },
        {
          'ingrediente': 'Leche',
          'unidad': 'ml',
          'cantidad': 1000,
          'monto_centavos': 2800,
          'fecha': '2026-11-02T10:00:00Z',
          'estado': 'revertida',
        },
      ];
      final repo = RepositorioAlimentacionSupabase(
        fuente: f,
        hogarId: _hogar,
        personaId: _yo,
      );
      final h = await repo.historialCompleto(CuentaCompra.papa);
      expect(h.length, 2);
      expect(h.first.cuentaPago, 'Cuenta del dueño');
      expect(h.first.revertida, isFalse);
      expect(h.last.revertida, isTrue);
      // La revertida se muestra, pero no suma.
      expect(resumirHistorial(h, const FiltroHistorial()).totalCentavos, 3000);
    });

    testWidgets('pantalla: se ve la revertida y la cuenta de pago', (t) async {
      await t.binding.setSurfaceSize(const Size(500, 4000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final (repo, s, _) = await _conCompra();
      await s.regresarCompra(MenuId.pareja, _lunes, claveCompra('Huevo', 'pza'), motivo: 'Error');
      await t.pumpWidget(_app(repo, const PantallaHistorialCompleto(menu: MenuId.pareja)));
      await t.pumpAndSettle();
      expect(find.textContaining('Revertida'), findsOneWidget);
    });
  });

  group('Casa y platillos', () {
    final dia = DateTime(2026, 11, 4);
    final abierta = DateTime(2026, 11, 3, 9);
    final cerrada = DateTime(2026, 11, 4, 12);
    VotacionPlan votacion({Map<String, String> votos = const {}}) => VotacionPlan(
      id: 'v1',
      dia: dia,
      abiertaEn: abierta,
      propuestas: const [
        PropuestaMenu(id: 'a', autorId: 'x', autorNombre: 'X', titulo: 'Caldo', platilloIds: ['p-caldo']),
        PropuestaMenu(id: 'b', autorId: 'y', autorNombre: 'Y', titulo: 'Tacos', platilloIds: ['p-tacos']),
      ],
      votos: votos,
    );
    RepositorioAlimentacionEnMemoria repo() {
      final r = RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes);
      r.guardarPlatillos(const [
        Platillo('p-caldo', 'Caldo de pollo', []),
        Platillo('p-tacos', 'Tacos de frijol', []),
      ]);
      return r;
    }

    ServicioPlanFamiliar plan(Rol rol, DateTime ahora) => ServicioPlanFamiliar(
      repo(),
      rol: rol,
      personaId: 'p',
      personaNombre: 'P',
      ahora: () => ahora,
    );

    test('Casa solo ve los platillos de la comida familiar ganadora', () async {
      final v = votacion(votos: {'u1': 'a', 'u2': 'a', 'u3': 'b'});
      final casa = plan(Rol.casa, cerrada);
      expect(await casa.nombresDePlatillos(v), {'p-caldo': 'Caldo de pollo'});
      expect(casa.muestraPlatillosDe(v, v.propuestas[0]), isTrue);
      expect(casa.muestraPlatillosDe(v, v.propuestas[1]), isFalse);
    });

    test('Casa no ve platillos mientras la votación sigue abierta', () async {
      final v = votacion(votos: {'u1': 'a'});
      final casa = plan(Rol.casa, abierta.add(const Duration(hours: 2)));
      expect(await casa.nombresDePlatillos(v), isEmpty);
      expect(casa.muestraPlatillosDe(v, v.propuestas[0]), isFalse);
    });

    test('dueño y familiar sí ven los platillos de todas las propuestas', () async {
      final v = votacion(votos: {'u1': 'a'});
      for (final rol in [Rol.dueno, Rol.coadministrador, Rol.familiar]) {
        final s = plan(rol, cerrada);
        expect((await s.nombresDePlatillos(v)).length, 2, reason: rol.name);
        expect(s.muestraPlatillosDe(v, v.propuestas[1]), isTrue);
      }
    });

    test('Casa solo ve platillos en el menú del día de Papá; el catálogo, el menú y el perfil no', () async {
      final r = repo();
      final casa = ServicioAlimentacion(r, rol: Rol.casa);
      expect(casa.menusVisibles, isEmpty);
      await expectLater(casa.platillos(), throwsA(isA<PermisoDenegado>()));
      await expectLater(casa.menu(MenuId.papa, _lunes), throwsA(isA<PermisoDenegado>()));
      expect(() => casa.perfil(MenuId.papa), throwsA(isA<PermisoDenegado>()));
      await expectLater(casa.porcionesPorPlatillo(_lunes), throwsA(isA<PermisoDenegado>()));
      final dia = await casa.menuDelDiaPapa(DateTime(2026, 11, 4));
      expect(dia, isA<List<ComidaDelDia>>());
    });

    test('la IA no recibe el perfil de Papá ni porciones', () async {
      final r = repo();
      r.despensaMemoria[CuentaCompra.dueno] = const [
        ItemDespensa(nombre: 'Huevo', unidad: 'pza', cantidad: 6),
      ];
      r.porcionesMemoria.add(const PorcionPersona(
        platilloId: 'p-caldo', cuenta: CuentaCompra.dueno, porciones: 1.5,
      ));
      final c = await ServicioAlimentacion(r, rol: Rol.dueno).contextoDeSugerencia('rápido');
      final t = jsonEncode(c.aJson()).toLowerCase();
      for (final x in ['alzheimer', 'papá', 'porcion', 'blando', 'dieta']) {
        expect(t, isNot(contains(x)));
      }
      await expectLater(
        ServicioAlimentacion(r, rol: Rol.casa).contextoDeSugerencia('x'),
        throwsA(isA<PermisoDenegado>()),
      );
    });
  });

  group('Porciones por persona', () {
    RepositorioAlimentacionEnMemoria repoConPorciones() {
      final r = RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes);
      final id = menuEjemploPrimerPlatillo(r);
      r.porcionesMemoria.addAll([
        PorcionPersona(platilloId: id, cuenta: CuentaCompra.dueno, porciones: 1.5),
        PorcionPersona(platilloId: id, cuenta: CuentaCompra.pareja, porciones: 1),
      ]);
      return r;
    }

    test('un solo platillo con una porción por cada persona', () async {
      final r = repoConPorciones();
      final p = r.porcionesMemoria.first.platilloId;
      for (final rol in [Rol.dueno, Rol.coadministrador]) {
        final m = await ServicioAlimentacion(r, rol: rol).porcionesPorPlatillo(_lunes);
        expect(m.keys, [p], reason: rol.name);
        expect(m[p]!.map((x) => x.cuenta), [CuentaCompra.dueno, CuentaCompra.pareja]);
        expect(m[p]!.map((x) => x.porciones), [1.5, 1]);
      }
      // El menú de Papá no lleva porciones: nadie más las pide.
      for (final rol in [Rol.familiar, Rol.cuidador, Rol.casa]) {
        await expectLater(
          ServicioAlimentacion(r, rol: rol).porcionesPorPlatillo(_lunes),
          throwsA(isA<PermisoDenegado>()),
          reason: rol.name,
        );
      }
    });

    test('servidor: lee ali_porciones_recomendadas y descarta filas raras', () async {
      final f = FuenteTablasEnMemoria();
      f.funciones['ali_porciones_recomendadas'] = (_) => [
        {'platillo_id': 'p1', 'cuenta': 'dueno', 'porciones': 1.5},
        {'platillo_id': 'p1', 'cuenta': 'pareja', 'porciones': 1},
        {'platillo_id': 'p1', 'cuenta': 'papa', 'porciones': 1},
        {'platillo_id': 'p2', 'cuenta': 'dueno'},
      ];
      final repo = RepositorioAlimentacionSupabase(fuente: f, hogarId: _hogar, personaId: _yo);
      final r = await repo.porcionesRecomendadas(_lunes);
      expect(r.length, 2);
      expect(f.llamadas.single.$2, {'p_hogar_id': _hogar, 'p_semana': '2026-11-02'});
    });
  });
}

String menuEjemploPrimerPlatillo(RepositorioAlimentacionEnMemoria r) =>
    menuEjemplo(MenuId.pareja).first.platilloId;

Widget _app(RepositorioAlimentacion repo, Widget pantalla, {MenuId menu = MenuId.pareja}) =>
    ProviderScope(
      overrides: [
        relojProvider.overrideWithValue(RelojFijo(DateTime(2026, 11, 4))),
        almacenSeguroProvider.overrideWithValue(AlmacenSeguroEnMemoria()),
        servicioSesionProvider.overrideWithValue(ServicioSesionFalso()),
        sesionEfectivaProvider.overrideWithValue(
          const Sesion(persona: Persona(id: 'p1', nombre: 'Ejemplo'), rol: Rol.dueno),
        ),
        repositorioAlimentacionProvider.overrideWithValue(repo),
        menuElegidoProvider.overrideWith((_) => menu),
      ],
      child: MaterialApp(home: pantalla),
    );
