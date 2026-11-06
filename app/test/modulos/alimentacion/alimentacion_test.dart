import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/sesion_efectiva.dart';
import 'package:gravity/diseno/proveedores.dart' show RelojFijo, relojProvider;
import 'package:gravity/modulos/alimentacion/casos_uso/lista_compras.dart';
import 'package:gravity/modulos/alimentacion/casos_uso/servicio_alimentacion.dart';
import 'package:gravity/modulos/alimentacion/datos/ejemplo.dart';
import 'package:gravity/modulos/alimentacion/datos/modelos.dart';
import 'package:gravity/modulos/alimentacion/datos/repositorio.dart';
import 'package:gravity/modulos/alimentacion/estado/proveedores.dart';
import 'package:gravity/modulos/alimentacion/pantallas/compras.dart';
import 'package:gravity/modulos/alimentacion/pantallas/menu.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';

final _miercoles = DateTime(2026, 11, 4);
final _lunes = DateTime(2026, 11, 2);

Sesion _sesion(Rol rol, {bool maestra = false}) => Sesion(
      persona: const Persona(id: 'p1', nombre: 'Ejemplo'),
      rol: rol,
      esMaestra: maestra,
    );

Widget _app(Rol rol, Widget pantalla, {RepositorioAlimentacion? repo, bool maestra = false}) =>
    ProviderScope(
      overrides: [
        relojProvider.overrideWithValue(RelojFijo(_miercoles)),
        almacenSeguroProvider.overrideWithValue(AlmacenSeguroEnMemoria()),
        servicioSesionProvider.overrideWithValue(ServicioSesionFalso()),
        sesionEfectivaProvider.overrideWithValue(_sesion(rol, maestra: maestra)),
        if (repo != null) repositorioAlimentacionProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(home: pantalla),
    );

void main() {
  test('la semana arranca en lunes', () {
    expect(lunesDe(_miercoles), _lunes);
    expect(lunesDe(DateTime(2026, 11, 8)), _lunes); // domingo
    expect(lunesDe(_lunes), _lunes);
  });

  group('lista de compras', () {
    test('suma el mismo ingrediente y unidad, y no mezcla unidades', () {
      const ps = [
        Platillo('a', 'A', [
          Ingrediente('Jitomate', 2, 'pza', SeccionCompra.frutasVerduras),
          Ingrediente('Leche', 250, 'ml', SeccionCompra.lacteosHuevo),
        ]),
        Platillo('b', 'B', [
          Ingrediente('Jitomate', 2, 'pza', SeccionCompra.frutasVerduras),
          Ingrediente('Leche', 1, 'l', SeccionCompra.lacteosHuevo),
        ]),
      ];
      final l = generarListaCompras(menu: const [
        EntradaMenu(dia: 0, tiempo: TiempoComida.comida, platilloId: 'a'),
        EntradaMenu(dia: 1, tiempo: TiempoComida.comida, platilloId: 'b'),
      ], platillos: ps);
      expect(l.firstWhere((i) => i.nombre == 'Jitomate').cantidad, 4);
      expect(l.where((i) => i.nombre == 'Leche').length, 2);
    });

    test('agrupa por sección en orden y menú vacío da lista vacía', () {
      final l = generarListaCompras(menu: menuEjemplo(), platillos: platillosEjemplo);
      final g = agruparPorSeccion(l);
      expect(g.keys.toList(), [...g.keys]..sort((a, b) => a.index.compareTo(b.index)));
      expect(g.containsKey(SeccionCompra.frutasVerduras), isTrue);
      expect(generarListaCompras(menu: const [], platillos: platillosEjemplo), isEmpty);
    });

    test('las marcas sobreviven a un cambio de menú si el ingrediente sigue', () async {
      final repo = RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes);
      final s = ServicioAlimentacion(repo, puedeEditar: true);
      await s.marcar(_miercoles, claveCompra('Huevo', 'pza'), true);
      await s.asignar(_miercoles, 6, TiempoComida.cena, 'p-pasta');
      final l = await s.listaCompras(_miercoles);
      expect(l.firstWhere((i) => i.nombre == 'Huevo').comprado, isTrue);
      await s.marcar(_miercoles, claveCompra('Huevo', 'pza'), false);
      expect((await s.listaCompras(_miercoles)).firstWhere((i) => i.nombre == 'Huevo').comprado,
          isFalse);
    });
  });

  group('permisos', () {
    test('dueño y coadministrador editan; los demás no', () {
      expect(puedeEditarAlimentacion(Rol.dueno), isTrue);
      expect(puedeEditarAlimentacion(Rol.coadministrador), isTrue);
      for (final r in [Rol.familiar, Rol.cuidador, Rol.casa]) {
        expect(puedeEditarAlimentacion(r), isFalse, reason: r.name);
      }
      expect(puedeEditarAlimentacion(Rol.dueno, esMaestra: true), isFalse);
    });

    test('el servicio de un lector rechaza escribir', () async {
      final s = ServicioAlimentacion(RepositorioAlimentacionEnMemoria(), puedeEditar: false);
      expect(() => s.asignar(_lunes, 0, TiempoComida.cena, 'p-pasta'),
          throwsA(isA<PermisoDenegado>()));
      expect(() => s.marcar(_lunes, 'x|y', true), throwsA(isA<PermisoDenegado>()));
    });

    test('semanas distintas guardan menús distintos', () async {
      final repo = RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes);
      final s = ServicioAlimentacion(repo, puedeEditar: true);
      expect((await s.menu(_lunes)).length, 21);
      expect(await s.menu(_lunes.add(const Duration(days: 7))), isEmpty);
    });
  });

  group('pantallas', () {
    testWidgets('menú: 7 días, 3 tiempos y celdas vacías', (t) async {
      await t.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(_app(Rol.dueno, const PantallaMenuSemana(),
          repo: RepositorioAlimentacionEnMemoria(conEjemplo: false)));
      await t.pumpAndSettle();
      for (final d in diasSemana) {
        expect(find.text(d), findsOneWidget);
      }
      expect(find.text('Sin platillo'), findsNWidgets(21));
      expect(find.text('Semana del 2/11 al 8/11'), findsOneWidget);
    });

    testWidgets('editor asigna un platillo y puede deshacer', (t) async {
      await t.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(_app(Rol.dueno, const PantallaMenuSemana(),
          repo: RepositorioAlimentacionEnMemoria(conEjemplo: false)));
      await t.pumpAndSettle();
      await t.tap(find.text('Sin platillo').first);
      await t.pumpAndSettle();
      await t.tap(find.text('Sopa de lentejas'));
      await t.pumpAndSettle();
      expect(find.text('Sopa de lentejas'), findsOneWidget);
      expect(find.text('Sin platillo'), findsNWidgets(20));
      await t.tap(find.text('Deshacer'));
      await t.pumpAndSettle();
      expect(find.text('Sin platillo'), findsNWidgets(21));
    });

    for (final rol in [Rol.familiar, Rol.casa, Rol.cuidador]) {
      testWidgets('lector (${rol.name}) ve el menú sin controles de edición', (t) async {
        await t.binding.setSurfaceSize(const Size(400, 4000));
        addTearDown(() => t.binding.setSurfaceSize(null));
        await t.pumpWidget(_app(rol, const PantallaMenuSemana(),
            repo: RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes)));
        await t.pumpAndSettle();
        expect(find.text('Solo lectura'), findsOneWidget);
        expect(find.byIcon(Icons.edit_outlined), findsNothing);
        expect(find.text('Huevos revueltos con frijoles'), findsWidgets);
      });
    }

    testWidgets('lista: agrupa, marca comprado con texto y cuenta avance', (t) async {
      await t.binding.setSurfaceSize(const Size(400, 4000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(_app(Rol.coadministrador, const PantallaListaCompras(),
          repo: RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes)));
      await t.pumpAndSettle();
      expect(find.text('Frutas y verduras'), findsOneWidget);
      expect(find.textContaining('0 de'), findsOneWidget);
      await t.tap(find.byType(Checkbox).first);
      await t.pumpAndSettle();
      expect(find.text('Comprado'), findsOneWidget);
      expect(find.textContaining('1 de'), findsOneWidget);
    });

    testWidgets('lista vacía explica cómo llenarla; lector no marca', (t) async {
      await t.pumpWidget(_app(Rol.familiar, const PantallaListaCompras(),
          repo: RepositorioAlimentacionEnMemoria(conEjemplo: false)));
      await t.pumpAndSettle();
      expect(find.text('La lista está vacía'), findsOneWidget);

      await t.pumpWidget(_app(Rol.familiar, const PantallaListaCompras(),
          repo: RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes)));
      await t.pumpAndSettle();
      final cb = t.widget<Checkbox>(find.byType(Checkbox).first);
      expect(cb.onChanged, isNull);
    });

    testWidgets('letra 2.0 en 360 dp sin desbordes', (t) async {
      await t.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final repo = RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes);
      for (final p in const [PantallaMenuSemana(), PantallaListaCompras()]) {
        await t.pumpWidget(ProviderScope(
          overrides: [
            relojProvider.overrideWithValue(RelojFijo(_miercoles)),
            almacenSeguroProvider.overrideWithValue(AlmacenSeguroEnMemoria()),
            servicioSesionProvider.overrideWithValue(ServicioSesionFalso()),
            sesionEfectivaProvider.overrideWithValue(_sesion(Rol.dueno)),
            repositorioAlimentacionProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            builder: (c, h) => MediaQuery(
                data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(2.0)),
                child: h!),
            home: p,
          ),
        ));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      }
    });
  });

  test('guardia: sin precios, IA, red ni datos de salud en el código', () {
    final prohibidas = RegExp(
        r'''precio|importe|[\s'"]\$\s?\d|gemini|openai|anthropic|package:http|dart:io|supabase|diagn|medicament|alergi''',
        caseSensitive: false);
    final archivos = Directory('lib/modulos/alimentacion')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    expect(archivos, isNotEmpty);
    for (final f in archivos) {
      final codigo = f
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('///') && !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(prohibidas.hasMatch(codigo), isFalse, reason: f.path);
    }
  });
}
