// Fase 8 · Alimentación (ampliaciones): tienda en la compra, historial
// completo por cuatro ejes y platillos desde la despensa con IA.
// Criterios de docs/specs/fase-8-alimentacion-ampliaciones.md, sección 3.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/alimentacion/repositorio_alimentacion_supabase.dart';
import 'package:gravity/app/alimentacion/sugeridor_recetas_supabase.dart';
import 'package:gravity/app/sesion_efectiva.dart';
import 'package:gravity/diseno/proveedores.dart' show RelojFijo, relojProvider;
import 'package:gravity/modulos/alimentacion/casos_uso/servicio_alimentacion.dart';
import 'package:gravity/modulos/alimentacion/casos_uso/sugerir_platillos.dart';
import 'package:gravity/modulos/alimentacion/datos/modelos.dart';
import 'package:gravity/modulos/alimentacion/datos/perfiles.dart';
import 'package:gravity/modulos/alimentacion/datos/repositorio.dart';
import 'package:gravity/modulos/alimentacion/estado/proveedores.dart';
import 'package:gravity/modulos/alimentacion/pantallas/despensa_platillos.dart';
import 'package:gravity/modulos/alimentacion/pantallas/historial_completo.dart';
import 'package:gravity/modulos/finanzas/datos/fuente_tablas.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';

final _lunes = DateTime(2026, 11, 2);

CompraPrecio _c(
  String nombre,
  int total,
  double cantidad,
  DateTime fecha, {
  String? tiendaId,
  String? tienda,
  String unidad = 'kg',
}) => CompraPrecio(
  clave: claveCompra(nombre, unidad),
  nombre: nombre,
  unidad: unidad,
  totalCentavos: total,
  cantidad: cantidad,
  fecha: fecha,
  tiendaId: tiendaId,
  tienda: tienda,
);

/// Un año de compras repartidas en tiempo, productos y tiendas (y una vieja
/// "sin tienda").
List<CompraPrecio> _compras() => [
  _c('Arroz', 3000, 2, DateTime(2026, 1, 5), tiendaId: 't1', tienda: 'Súper'),
  _c('Arroz', 2400, 2, DateTime(2026, 2, 9), tiendaId: 't2', tienda: 'Mercado'),
  _c('Arroz', 4400, 2, DateTime(2026, 8, 3), tiendaId: 't1', tienda: 'Súper'),
  _c('Frijol', 5000, 1, DateTime(2026, 3, 15), tiendaId: 't2', tienda: 'Mercado'),
  _c('Frijol', 6100, 1, DateTime(2026, 11, 2), tiendaId: 't1', tienda: 'Súper'),
  _c('Leche', 2800, 1, DateTime(2025, 12, 30), unidad: 'l'),
  _c('Leche', 3100, 1, DateTime(2026, 6, 30), tiendaId: 't1', tienda: 'Súper', unidad: 'l'),
  _c('Huevo', 4800, 12, DateTime(2026, 7, 1), tiendaId: 't2', tienda: 'Mercado', unidad: 'pza'),
];

Future<CompraPrecio> _una(RepositorioAlimentacionEnMemoria r) async =>
    (await r.historialCompleto(CuentaCompra.dueno)).single;

void main() {
  group('Tienda obligatoria en la compra', () {
    test('una compra sin tienda no se guarda', () async {
      final repo = RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes);
      final s = ServicioAlimentacion(repo, rol: Rol.dueno);
      final clave = claveCompra('Huevo', 'pza');
      for (final id in <String?>[null, '', 'tienda-que-no-existe']) {
        await expectLater(
          s.registrarCompra(
            MenuId.pareja,
            _lunes,
            clave,
            cantidadComprada: 12,
            totalCentavos: 4800,
            tiendaId: id,
          ),
          throwsArgumentError,
          reason: 'tienda: $id',
        );
      }
      expect(await repo.historialCompleto(CuentaCompra.dueno), isEmpty);
      expect(await repo.historialCompras(), isEmpty);
      expect((await repo.precios())[clave]!.esBase, isTrue);
      expect(await repo.comprados(MenuId.pareja, _lunes), isEmpty);
    });

    test('con tienda de la lista sí se guarda, con su tienda', () async {
      final repo = RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes);
      final s = ServicioAlimentacion(repo, rol: Rol.dueno);
      final t = await s.agregarTienda('  Mercado del barrio ');
      await s.registrarCompra(
        MenuId.pareja,
        _lunes,
        claveCompra('Huevo', 'pza'),
        cantidadComprada: 12,
        totalCentavos: 4800,
        tiendaId: t.id,
      );
      final h = await _una(repo);
      expect(h.tiendaId, t.id);
      expect(h.tienda, 'Mercado del barrio');
    });

    test('el nombre de la tienda lleva de 1 a 60 caracteres', () async {
      final s = ServicioAlimentacion(
        RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes),
        rol: Rol.dueno,
      );
      await expectLater(s.agregarTienda('   '), throwsArgumentError);
      await expectLater(s.agregarTienda('x' * 61), throwsArgumentError);
      expect((await s.agregarTienda('x' * 60)).nombre.length, 60);
      expect((await s.agregarTienda('A')).nombre, 'A');
      // Mismo nombre (sin importar mayúsculas): la misma tienda.
      final a = await s.agregarTienda('Súper');
      final b = await s.agregarTienda('súper');
      expect(b.id, a.id);
    });

    test('quien no edita no agrega tiendas', () async {
      final repo = RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes);
      for (final rol in [Rol.familiar, Rol.cuidador, Rol.casa]) {
        await expectLater(
          ServicioAlimentacion(repo, rol: rol).agregarTienda('X'),
          throwsA(isA<PermisoDenegado>()),
          reason: rol.name,
        );
      }
    });

    test('el repositorio del servidor tampoco guarda sin tienda', () async {
      final f = FuenteTablasEnMemoria();
      final repo = RepositorioAlimentacionSupabase(
        fuente: f,
        hogarId: '00000000-0000-4000-8000-000000000001',
        personaId: '00000000-0000-4000-8000-0000000000a1',
      );
      final compra = CompraPrecio(
        clave: 'leche|ml',
        nombre: 'Leche',
        unidad: 'ml',
        totalCentavos: 2800,
        cantidad: 1000,
        fecha: DateTime(2026, 11, 8),
      );
      await expectLater(
        repo.registrarCompraReal(
          menu: MenuId.pareja,
          lunes: _lunes,
          compra: compra,
          precio: PrecioIngrediente.deCompra(
            clave: 'leche|ml',
            totalCentavos: 2800,
            cantidadComprada: 1000,
          ),
          cuenta: CuentaCompra.dueno,
        ),
        throwsA(isA<ErrorAlimentacionServidor>()),
      );
      expect(f.llamadas, isEmpty);
    });

    test('agregar tienda en el servidor escribe ali_tiendas y no repite', () async {
      final f = FuenteTablasEnMemoria();
      final repo = RepositorioAlimentacionSupabase(
        fuente: f,
        hogarId: '00000000-0000-4000-8000-000000000001',
        personaId: '00000000-0000-4000-8000-0000000000a1',
      );
      final a = await repo.agregarTienda('Súper');
      final b = await repo.agregarTienda('súper');
      expect(b.id, a.id);
      expect(f.tabla('ali_tiendas').single['nombre'], 'Súper');
      expect((await repo.tiendas()).single.nombre, 'Súper');
    });
  });

  group('Historial completo', () {
    test('cada eje suma el mismo total que las compras', () {
      final todas = _compras();
      final esperado = todas.fold<int>(0, (a, c) => a + c.totalCentavos);
      for (final e in EscalaTiempo.values) {
        final r = resumirHistorial(todas, FiltroHistorial(escala: e));
        expect(r.totalCentavos, esperado, reason: e.name);
        expect(r.compras, todas.length);
        expect(
          r.porPeriodo.fold<int>(0, (a, f) => a + f.totalCentavos),
          esperado,
          reason: 'tiempo ${e.name}',
        );
        expect(
          r.porProducto.fold<int>(0, (a, f) => a + f.totalCentavos),
          esperado,
          reason: 'producto ${e.name}',
        );
        expect(
          r.porTienda.fold<int>(0, (a, f) => a + f.totalCentavos),
          esperado,
          reason: 'tienda ${e.name}',
        );
        expect(
          r.porPeriodo.fold<int>(0, (a, f) => a + f.compras),
          todas.length,
        );
      }
    });

    test('con filtros combinados los ejes siguen cuadrando', () {
      final todas = _compras();
      final filtros = [
        const FiltroHistorial(tienda: 't1'),
        const FiltroHistorial(tienda: filtroSinTienda),
        FiltroHistorial(claveProducto: claveCompra('Arroz', 'kg'), tienda: 't1'),
        const FiltroHistorial(unitarioMinCentavos: 2000, unitarioMaxCentavos: 5000),
        FiltroHistorial(
          escala: EscalaTiempo.bimestre,
          desde: DateTime(2026, 2, 1),
          hasta: DateTime(2026, 8, 31),
          tienda: 't2',
        ),
        FiltroHistorial(
          escala: EscalaTiempo.semana,
          claveProducto: claveCompra('Frijol', 'kg'),
          unitarioMinCentavos: 5500,
        ),
      ];
      for (final f in filtros) {
        final sumaDirecta = todas
            .where(f.admite)
            .fold<int>(0, (a, c) => a + c.totalCentavos);
        final r = resumirHistorial(todas, f);
        expect(r.totalCentavos, sumaDirecta);
        expect(r.porPeriodo.fold<int>(0, (a, x) => a + x.totalCentavos), sumaDirecta);
        expect(r.porProducto.fold<int>(0, (a, x) => a + x.totalCentavos), sumaDirecta);
        expect(r.porTienda.fold<int>(0, (a, x) => a + x.totalCentavos), sumaDirecta);
      }
      // Valores concretos.
      expect(
        resumirHistorial(todas, const FiltroHistorial(tienda: 't1')).totalCentavos,
        3000 + 4400 + 6100 + 3100,
      );
      expect(
        resumirHistorial(todas, const FiltroHistorial(tienda: filtroSinTienda))
            .totalCentavos,
        2800,
      );
    });

    test('periodos: semana en lunes, bimestre, semestre y año', () {
      final f = DateTime(2026, 11, 8); // domingo
      expect(inicioDePeriodo(f, EscalaTiempo.semana), DateTime(2026, 11, 2));
      expect(inicioDePeriodo(f, EscalaTiempo.mes), DateTime(2026, 11));
      expect(inicioDePeriodo(f, EscalaTiempo.bimestre), DateTime(2026, 11));
      expect(
        inicioDePeriodo(DateTime(2026, 10, 31), EscalaTiempo.bimestre),
        DateTime(2026, 9),
      );
      expect(inicioDePeriodo(DateTime(2026, 6, 30), EscalaTiempo.semestre), DateTime(2026));
      expect(inicioDePeriodo(DateTime(2026, 7, 1), EscalaTiempo.semestre), DateTime(2026, 7));
      expect(inicioDePeriodo(f, EscalaTiempo.ano), DateTime(2026));
      final porSemestre = resumirHistorial(
        _compras(),
        const FiltroHistorial(escala: EscalaTiempo.semestre),
      ).porPeriodo;
      expect(porSemestre.map((p) => p.inicio), [
        DateTime(2026, 7),
        DateTime(2026),
        DateTime(2025, 7),
      ]);
    });

    test('precio y producto: variación, rango y tienda más barata', () {
      final r = resumirHistorial(_compras(), const FiltroHistorial());
      final arroz = r.porProducto.firstWhere((p) => p.nombre == 'Arroz');
      expect(arroz.compras, 3);
      expect(arroz.primerUnitario, 1500);
      expect(arroz.ultimoUnitario, 2200);
      expect(arroz.variacionPorcentaje, 47);
      expect(arroz.minUnitario, 1200);
      expect(arroz.maxUnitario, 2200);
      // Mercado: 1200 por kg; Súper: (3000+4400)/4 = 1850.
      expect(arroz.tiendaMasBarata, 'Mercado');
      final huevo = r.porProducto.firstWhere((p) => p.nombre == 'Huevo');
      expect(huevo.variacionPorcentaje, isNull);
      expect(huevo.tiendaMasBarata, isNull, reason: 'una sola tienda');
      expect(r.porTienda.last.nombre, etiquetaSinTienda);
    });

    test('el precio base de supuesto no entra en el historial', () async {
      final repo = RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes);
      // Hay precios base de ejemplo (supuesto), pero ninguna compra real.
      expect((await repo.precios()).values.any((p) => p.esBase), isTrue);
      await repo.guardarPrecio(
        const PrecioIngrediente(clave: 'huevo|pza', centavos: 400, esBase: true),
      );
      expect(await repo.historialCompleto(CuentaCompra.dueno), isEmpty);
      final s = ServicioAlimentacion(repo, rol: Rol.dueno);
      expect(await s.historialCompleto(MenuId.pareja), isEmpty);
      // Una compra real sí entra, y solo ella.
      final t = await s.agregarTienda('Súper');
      await s.registrarCompra(
        MenuId.pareja,
        _lunes,
        claveCompra('Huevo', 'pza'),
        cantidadComprada: 12,
        totalCentavos: 4800,
        tiendaId: t.id,
      );
      final h = await s.historialCompleto(MenuId.pareja);
      expect(h.single.totalCentavos, 4800);
      expect(resumirHistorial(h, const FiltroHistorial()).totalCentavos, 4800);
    });

    test('del servidor: solo lo que devuelve ali_historial_compras, no ali_ingredientes', () async {
      final f = FuenteTablasEnMemoria();
      f.tabla('ali_ingredientes').add({
        'id': 'i1',
        'nombre': 'Huevo',
        'unidad': 'pza',
        'precio_base_centavos': 400,
      });
      f.tabla('ali_tiendas').add({'id': 't1', 'nombre': 'Súper'});
      f.funciones['ali_historial_compras'] = (p) => [
        {
          'ingrediente': 'Huevo',
          'unidad': 'pza',
          'cantidad': 12,
          'monto_centavos': 4800,
          'tienda_id': 't1',
          'fecha': '2026-11-03T10:00:00Z',
        },
        {
          'ingrediente': 'Arroz',
          'unidad': 'kg',
          'cantidad': 1,
          'monto_centavos': 2000,
          'tienda_id': null,
          'fecha': '2026-10-03T10:00:00Z',
        },
        {'ingrediente': 'Basura', 'unidad': 'kg', 'cantidad': 0, 'monto_centavos': 1, 'fecha': '2026-10-03T10:00:00Z'},
      ];
      final repo = RepositorioAlimentacionSupabase(
        fuente: f,
        hogarId: '00000000-0000-4000-8000-000000000001',
        personaId: '00000000-0000-4000-8000-0000000000a1',
      );
      final h = await repo.historialCompleto(CuentaCompra.dueno);
      expect(f.llamadas.single.$1, 'ali_historial_compras');
      expect(f.llamadas.single.$2['p_cuenta'], 'dueno');
      expect(h.length, 2);
      expect(h.first.tienda, 'Súper');
      expect(h.last.tiendaId, isNull);
      expect(resumirHistorial(h, const FiltroHistorial()).totalCentavos, 6800);
    });

    testWidgets('pantalla: los filtros cambian el total y "sin tienda" aparece', (t) async {
      await t.binding.setSurfaceSize(const Size(500, 3000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final repo = RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes);
      for (final c in _compras()) {
        await repo.guardarCompraPrecio(c);
      }
      await t.pumpWidget(_app(
        repo,
        const PantallaHistorialCompleto(menu: MenuId.pareja),
      ));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('total_historial')), findsOneWidget);
      expect(find.textContaining('Total: \$316.00 en 8 compras'), findsOneWidget);
      await t.tap(find.byKey(const Key('filtro_tienda')));
      await t.pumpAndSettle();
      await t.tap(find.text(etiquetaSinTienda).last);
      await t.pumpAndSettle();
      expect(find.textContaining('Total: \$28.00 en 1 compra'), findsOneWidget);
    });
  });

  group('Platillos desde la despensa', () {
    RepositorioAlimentacionEnMemoria repoConDespensa() {
      final r = RepositorioAlimentacionEnMemoria(
        semanaEjemplo: _lunes,
        conEjemplo: false,
      );
      r.despensaMemoria[CuentaCompra.dueno] = const [
        ItemDespensa(nombre: 'Huevo', unidad: 'pza', cantidad: 6),
        ItemDespensa(nombre: 'Frijoles de la olla', unidad: 'taza', cantidad: 2),
        ItemDespensa(nombre: 'Tortilla', unidad: 'pza', cantidad: 10),
      ];
      r.despensaMemoria[CuentaCompra.pareja] = const [
        ItemDespensa(nombre: 'Salmón secreto de la pareja', unidad: 'g', cantidad: 400),
      ];
      r.despensaMemoria[CuentaCompra.papa] = const [
        ItemDespensa(nombre: 'Avena de Papá', unidad: 'g', cantidad: 300),
      ];
      r.guardarPlatillos(const [
        Platillo('p-huevo', 'Huevos con frijoles', [
          Ingrediente('Huevo', 3, 'pza', SeccionCompra.lacteosHuevo),
          Ingrediente('Frijoles de la olla', 1, 'taza', SeccionCompra.abarrotes),
        ]),
        Platillo('p-queso', 'Quesadillas', [
          Ingrediente('Tortilla', 6, 'pza', SeccionCompra.panaderia),
          Ingrediente('Queso Oaxaca', 120, 'g', SeccionCompra.lacteosHuevo),
        ]),
        Platillo('p-mucho', 'Huevos para un batallón', [
          Ingrediente('Huevo', 30, 'pza', SeccionCompra.lacteosHuevo),
        ]),
      ]);
      return r;
    }

    test('qué se puede cocinar con la despensa de la cuenta que pide', () async {
      final s = ServicioAlimentacion(repoConDespensa(), rol: Rol.dueno);
      final r = await s.platillosConLaDespensa();
      expect(r.where((x) => x.cocinable).map((x) => x.platillo.id), ['p-huevo']);
      final queso = r.firstWhere((x) => x.platillo.id == 'p-queso');
      expect(queso.faltantes, ['Queso Oaxaca']);
      // No alcanza la cantidad: falta.
      expect(r.firstWhere((x) => x.platillo.id == 'p-mucho').cocinable, isFalse);
      // La pareja tiene otra despensa: no se mezclan.
      final p = ServicioAlimentacion(repoConDespensa(), rol: Rol.coadministrador);
      expect((await p.platillosConLaDespensa()).any((x) => x.cocinable), isFalse);
      // Casa no ve platillos.
      await expectLater(
        ServicioAlimentacion(repoConDespensa(), rol: Rol.casa).platillosConLaDespensa(),
        throwsA(isA<PermisoDenegado>()),
      );
    });

    test('el contexto de la IA lleva solo la despensa de quien pide', () async {
      final s = ServicioAlimentacion(repoConDespensa(), rol: Rol.dueno);
      final c = await s.contextoDeSugerencia('algo rápido');
      final texto = jsonEncode(c.aJson());
      expect(texto, contains('Huevo'));
      expect(texto, isNot(contains('Salmón secreto')));
      expect(texto, isNot(contains('Avena de Papá')));
    });

    test('la sugerencia no incluye el perfil clínico de Papá', () async {
      // Aun pidiéndola con la despensa de Papá (familiar) o de dueño.
      for (final rol in [Rol.dueno, Rol.familiar, Rol.coadministrador]) {
        final s = ServicioAlimentacion(repoConDespensa(), rol: rol);
        final c = await s.contextoDeSugerencia('sin picante');
        expect(c.aJson().keys.toSet(), ContextoSugerencia.llaves, reason: rol.name);
        for (final i in c.ingredientes) {
          expect(i.keys.toSet(), ContextoSugerencia.llavesIngrediente);
        }
        final texto = jsonEncode(c.aJson()).toLowerCase();
        final p = perfilDe(MenuId.papa);
        for (final linea in [p.titulo, ...p.lineas]) {
          expect(texto, isNot(contains(linea.toLowerCase())), reason: linea);
        }
        for (final palabra in [
          'alzheimer', 'protein', 'aminoácido', 'duro', 'blando', 'textura',
          'alerg', 'dieta', 'clínic', 'perfil', 'precio', 'centavo', 'saldo',
        ]) {
          expect(texto, isNot(contains(palabra)), reason: '$rol: $palabra');
        }
      }
    });

    test('lo que sale por la red es exactamente el contexto', () async {
      Map<String, Object?>? enviado;
      final sug = SugeridorRecetasSupabase((cuerpo) async {
        enviado = cuerpo;
        return {
          'recetas': [
            {
              'titulo': 'Huevos rancheros',
              'porciones': 2,
              'pasos': ['Fríe los huevos.'],
              'ingredientes': [
                {'nombre': 'Huevo', 'cantidad': 4, 'unidad': 'pza'},
              ],
            },
          ],
        };
      });
      final s = ServicioAlimentacion(
        repoConDespensa(),
        rol: Rol.dueno,
        sugeridor: sug,
      );
      final r = await s.sugerirConIA('sin picante');
      expect(r.single.nombre, 'Huevos rancheros');
      expect(enviado!.keys.toSet(), {'accion', 'contexto'});
      final ctx = enviado!['contexto']! as Map;
      expect(ctx.keys.toSet(), ContextoSugerencia.llaves);
      expect(ctx['preferencias'], 'sin picante');
      expect((ctx['ingredientes'] as List).length, 3);
    });

    test('cantidades aproximadas y preferencias limpias y cortas', () {
      expect(cantidadAproximada(6), 6);
      expect(cantidadAproximada(6.2), 6);
      expect(cantidadAproximada(237), 250);
      expect(cantidadAproximada(1234), 1200);
      final c = ContextoSugerencia.de(
        const [
          ItemDespensa(nombre: ' Leche ', unidad: 'ml', cantidad: 1234),
          ItemDespensa(nombre: 'Vacío', unidad: 'g', cantidad: 0),
        ],
        '  <b>rápido</b>\n\n y   fácil ${'x' * 400}',
      );
      expect(c.ingredientes.single['nombre'], 'Leche');
      expect(c.ingredientes.single['cantidad_aprox'], 1200);
      expect(c.preferencias.length, maxCaracteresPreferencias);
      expect(c.preferencias, isNot(contains('<')));
      expect(c.preferencias, startsWith('b rápido /b y fácil'));
    });

    test('una receta sugerida no se guarda sin confirmación', () async {
      final repo = repoConDespensa();
      final antes = (await repo.platillos()).length;
      final s = ServicioAlimentacion(
        repo,
        rol: Rol.dueno,
        sugeridor: _SugeridorFalso(),
      );
      final r = await s.sugerirConIA('');
      expect(r, hasLength(1));
      expect((await repo.platillos()).length, antes);
      expect((await repo.platillos()).any((p) => p.nombre == 'Huevos a la mexicana'), isFalse);
      await s.guardarSugerida(r.single);
      expect((await repo.platillos()).length, antes + 1);
      // Quien no edita no confirma.
      await expectLater(
        ServicioAlimentacion(repo, rol: Rol.familiar).guardarSugerida(r.single),
        throwsA(isA<PermisoDenegado>()),
      );
    });

    test('una respuesta inválida de la IA no sale como receta', () {
      expect(() => recetasSugeridas({'recetas': []}), throwsA(isA<ErrorSugerencia>()));
      expect(() => recetasSugeridas('hola'), throwsA(isA<ErrorSugerencia>()));
      expect(
        () => recetasSugeridas({
          'recetas': [
            {'titulo': '<script>', 'porciones': 1, 'ingredientes': [], 'pasos': []},
          ],
        }),
        throwsA(isA<ErrorSugerencia>()),
      );
    });

    testWidgets('pantalla: Sugerir con IA muestra la receta y solo Guardar la guarda', (t) async {
      await t.binding.setSurfaceSize(const Size(500, 3000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final repo = repoConDespensa();
      final antes = (await repo.platillos()).length;
      await t.pumpWidget(_app(
        repo,
        const PantallaDespensaPlatillos(),
        sugeridor: _SugeridorFalso(),
      ));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('cocinable_p-huevo')), findsOneWidget);
      expect(find.byKey(const Key('aviso_ia')), findsOneWidget);
      await t.tap(find.byKey(const Key('sugerir_ia')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('sugerida_0')), findsOneWidget);
      expect(find.text('Huevos a la mexicana'), findsOneWidget);
      expect((await repo.platillos()).length, antes);
      await t.tap(find.byKey(const Key('guardar_sugerida_0')));
      await t.pumpAndSettle();
      expect((await repo.platillos()).length, antes + 1);
      expect(find.text('Receta guardada'), findsOneWidget);
    });
  });
}

class _SugeridorFalso implements SugeridorRecetas {
  @override
  Future<List<Platillo>> sugerir(ContextoSugerencia contexto) async => const [
    Platillo(
      'imp-huevos-a-la-mexicana',
      'Huevos a la mexicana',
      [Ingrediente('Huevo', 3, 'pza', SeccionCompra.lacteosHuevo)],
      pasos: ['Fríe los huevos.'],
      porciones: 1,
    ),
  ];
}

Widget _app(
  RepositorioAlimentacion repo,
  Widget pantalla, {
  SugeridorRecetas? sugeridor,
}) => ProviderScope(
  overrides: [
    relojProvider.overrideWithValue(RelojFijo(DateTime(2026, 11, 4))),
    almacenSeguroProvider.overrideWithValue(AlmacenSeguroEnMemoria()),
    servicioSesionProvider.overrideWithValue(ServicioSesionFalso()),
    sesionEfectivaProvider.overrideWithValue(
      const Sesion(
        persona: Persona(id: 'p1', nombre: 'Ejemplo'),
        rol: Rol.dueno,
      ),
    ),
    repositorioAlimentacionProvider.overrideWithValue(repo),
    if (sugeridor != null) sugeridorRecetasProvider.overrideWithValue(sugeridor),
  ],
  child: MaterialApp(home: pantalla),
);
