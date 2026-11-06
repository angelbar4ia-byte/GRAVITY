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
import 'package:gravity/modulos/alimentacion/datos/perfiles.dart';
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

Widget _app(
  Rol rol,
  Widget pantalla, {
  RepositorioAlimentacion? repo,
  bool maestra = false,
}) => ProviderScope(
  overrides: [
    relojProvider.overrideWithValue(RelojFijo(_miercoles)),
    almacenSeguroProvider.overrideWithValue(AlmacenSeguroEnMemoria()),
    servicioSesionProvider.overrideWithValue(ServicioSesionFalso()),
    sesionEfectivaProvider.overrideWithValue(_sesion(rol, maestra: maestra)),
    if (repo != null) repositorioAlimentacionProvider.overrideWithValue(repo),
  ],
  child: MaterialApp(home: pantalla),
);

Future<void> _alto(WidgetTester t, [double h = 9000]) async {
  await t.binding.setSurfaceSize(Size(400, h));
  addTearDown(() => t.binding.setSurfaceSize(null));
}

ServicioAlimentacion _srv(
  Rol rol, {
  bool maestra = false,
  RepositorioAlimentacion? repo,
}) => ServicioAlimentacion(
  repo ?? RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes),
  rol: rol,
  esMaestra: maestra,
);

void main() {
  test('la semana arranca en lunes', () {
    expect(lunesDe(_miercoles), _lunes);
    expect(lunesDe(DateTime(2026, 11, 8)), _lunes); // domingo
    expect(lunesDe(_lunes), _lunes);
  });

  test('hay cuatro tiempos de comida y dos menús', () {
    expect(TiempoComida.values.map((t) => t.etiqueta), [
      'Desayuno',
      'Comida',
      'Cena',
      'Colación',
    ]);
    expect(MenuId.values.length, 2);
    expect(menuEjemplo(MenuId.papa).length, 28);
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
      final l = generarListaCompras(
        menu: const [
          EntradaMenu(dia: 0, tiempo: TiempoComida.comida, platilloId: 'a'),
          EntradaMenu(dia: 1, tiempo: TiempoComida.comida, platilloId: 'b'),
        ],
        platillos: ps,
      );
      expect(l.firstWhere((i) => i.nombre == 'Jitomate').cantidad, 4);
      expect(l.where((i) => i.nombre == 'Leche').length, 2);
    });

    test('agrupa por sección en orden y menú vacío da lista vacía', () {
      final l = generarListaCompras(
        menu: menuEjemplo(MenuId.pareja),
        platillos: platillosEjemplo,
      );
      final g = agruparPorSeccion(l);
      expect(
        g.keys.toList(),
        [...g.keys]..sort((a, b) => a.index.compareTo(b.index)),
      );
      expect(g.containsKey(SeccionCompra.frutasVerduras), isTrue);
      expect(
        generarListaCompras(menu: const [], platillos: platillosEjemplo),
        isEmpty,
      );
    });

    test('las marcas son por menú y sobreviven a un cambio de menú', () async {
      final s = _srv(Rol.dueno);
      await s.marcar(
        MenuId.papa,
        _miercoles,
        claveCompra('Huevo', 'pza'),
        true,
      );
      await s.asignar(MenuId.papa, _miercoles, 6, TiempoComida.cena, 'p-pasta');
      final papa = await s.listaCompras(MenuId.papa, _miercoles);
      expect(papa.firstWhere((i) => i.nombre == 'Huevo').comprado, isTrue);
      final pareja = await s.listaCompras(MenuId.pareja, _miercoles);
      expect(pareja.firstWhere((i) => i.nombre == 'Huevo').comprado, isFalse);
      await s.marcar(
        MenuId.papa,
        _miercoles,
        claveCompra('Huevo', 'pza'),
        false,
      );
      expect(
        (await s.listaCompras(MenuId.papa, _miercoles)).any((i) => i.comprado),
        isFalse,
      );
    });
  });

  group('permisos (D23)', () {
    test('solo dueño y pareja editan; la maestra no', () {
      expect(puedeEditarAlimentacion(Rol.dueno), isTrue);
      expect(puedeEditarAlimentacion(Rol.coadministrador), isTrue);
      for (final r in [Rol.familiar, Rol.cuidador, Rol.casa]) {
        expect(puedeEditarAlimentacion(r), isFalse, reason: r.name);
      }
      expect(puedeEditarAlimentacion(Rol.dueno, esMaestra: true), isFalse);
    });

    test('el familiar edita el menú de Papá y no el de la pareja; la cuidadora solo lee', () {
      expect(puedeEditarMenu(Rol.familiar, MenuId.papa), isTrue);
      expect(puedeEditarMenu(Rol.familiar, MenuId.pareja), isFalse);
      expect(
        puedeEditarMenu(Rol.familiar, MenuId.papa, esMaestra: true),
        isFalse,
      );
      expect(puedeEditarMenu(Rol.cuidador, MenuId.papa), isFalse);
      expect(puedeEditarMenu(Rol.casa, MenuId.papa), isFalse);
      for (final m in MenuId.values) {
        expect(puedeEditarMenu(Rol.dueno, m), isTrue);
        expect(puedeEditarMenu(Rol.coadministrador, m), isTrue);
      }
      // Marcar comprado y suplementos siguen siendo solo de dueño y pareja.
      expect(puedeEditarAlimentacion(Rol.familiar), isFalse);
    });

    test('quién ve qué menú', () {
      for (final r in [Rol.dueno, Rol.coadministrador]) {
        expect(_srv(r).menusVisibles, MenuId.values);
      }
      for (final r in [Rol.familiar, Rol.cuidador]) {
        expect(_srv(r).menusVisibles, [MenuId.papa], reason: r.name);
      }
      expect(_srv(Rol.casa).menusVisibles, isEmpty);
      expect(_srv(Rol.familiar, maestra: true).menusVisibles, MenuId.values);
    });

    test(
      'lista de compras: la cuidadora ve la de Papá, el familiar ninguna',
      () {
        expect(_srv(Rol.cuidador).menusConCompras, [MenuId.papa]);
        expect(_srv(Rol.familiar).menusConCompras, isEmpty);
        expect(_srv(Rol.dueno).menusConCompras, MenuId.values);
      },
    );

    test('el servicio rechaza lo que el rol no puede', () async {
      final lector = _srv(Rol.familiar);
      await lector.asignar(
        MenuId.papa,
        _lunes,
        0,
        TiempoComida.cena,
        'p-pure',
      ); // sí puede
      expect(
        () => lector.asignar(
          MenuId.pareja,
          _lunes,
          0,
          TiempoComida.cena,
          'p-pasta',
        ),
        throwsA(isA<PermisoDenegado>()),
      );
      expect(
        () =>
            _srv(Rol.cuidador)
                .asignar(MenuId.papa, _lunes, 0, TiempoComida.cena, 'p-pure'),
        throwsA(isA<PermisoDenegado>()),
      );
      expect(
        () => lector.marcar(MenuId.papa, _lunes, 'x|y', true),
        throwsA(isA<PermisoDenegado>()),
      );
      expect(
        () => lector.menu(MenuId.pareja, _lunes),
        throwsA(isA<PermisoDenegado>()),
      );
      expect(
        () => lector.listaCompras(MenuId.papa, _lunes),
        throwsA(isA<PermisoDenegado>()),
      );
      expect(
        () => lector.suplementos(MenuId.pareja),
        throwsA(isA<PermisoDenegado>()),
      );
      expect(
        () => lector.guardarSuplemento(
          MenuId.papa,
          suplementosEjemplo(MenuId.papa).first,
        ),
        throwsA(isA<PermisoDenegado>()),
      );
      expect(
        () => _srv(Rol.cuidador).perfil(MenuId.pareja),
        throwsA(isA<PermisoDenegado>()),
      );
      expect(
        () => _srv(Rol.casa).perfil(MenuId.papa),
        throwsA(isA<PermisoDenegado>()),
      );
      // La cuidadora lee la lista de Papá pero no la marca.
      expect(
        (await _srv(Rol.cuidador).listaCompras(MenuId.papa, _lunes)),
        isNotEmpty,
      );
      expect(
        () => _srv(Rol.cuidador).marcar(MenuId.papa, _lunes, 'x|y', true),
        throwsA(isA<PermisoDenegado>()),
      );
    });

    test('los dos menús y las semanas son independientes', () async {
      final s = _srv(Rol.dueno);
      expect((await s.menu(MenuId.papa, _lunes)).length, 28);
      await s.asignar(MenuId.pareja, _lunes, 0, TiempoComida.colacion, null);
      expect((await s.menu(MenuId.pareja, _lunes)).length, 27);
      expect((await s.menu(MenuId.papa, _lunes)).length, 28);
      expect(
        await s.menu(MenuId.papa, _lunes.add(const Duration(days: 7))),
        isEmpty,
      );
    });
  });

  group('suplementos y perfil', () {
    test('dueño y pareja agregan, editan y quitan en ambos menús', () async {
      final s = _srv(Rol.coadministrador);
      for (final m in MenuId.values) {
        final antes = (await s.suplementos(m)).length;
        const nuevo = Suplemento(
          id: 'x',
          nombre: 'Vitamina D',
          dosis: '1 gota',
          horario: 'Cena',
        );
        await s.guardarSuplemento(m, nuevo);
        expect((await s.suplementos(m)).length, antes + 1);
        await s.guardarSuplemento(
          m,
          const Suplemento(
            id: 'x',
            nombre: 'Vitamina D',
            dosis: '2 gotas',
            horario: 'Cena',
          ),
        );
        expect(
          (await s.suplementos(m)).firstWhere((e) => e.id == 'x').dosis,
          '2 gotas',
        );
        await s.quitarSuplemento(m, 'x');
        expect((await s.suplementos(m)).length, antes);
      }
    });

    test('el perfil de Papá pide textura blanda; el de la pareja no', () {
      expect(perfilDe(MenuId.papa).texturaBlanda, isTrue);
      expect(perfilDe(MenuId.pareja).texturaBlanda, isFalse);
      expect(
        _srv(Rol.cuidador).perfil(MenuId.papa).lineas.join(' '),
        contains('80 años'),
      );
    });
  });

  group('pantallas', () {
    testWidgets('menú: 7 días, 4 tiempos y celdas vacías', (t) async {
      await _alto(t);
      await t.pumpWidget(
        _app(
          Rol.dueno,
          const PantallaMenuSemana(),
          repo: RepositorioAlimentacionEnMemoria(conEjemplo: false),
        ),
      );
      await t.pumpAndSettle();
      for (final d in diasSemana) {
        expect(find.text(d), findsOneWidget);
      }
      expect(find.text('Colación'), findsNWidgets(7));
      expect(find.text('Sin platillo'), findsNWidgets(28));
      expect(find.text('Semana del 2/11 al 8/11'), findsOneWidget);
    });

    testWidgets('editor asigna un platillo y puede deshacer', (t) async {
      await _alto(t);
      await t.pumpWidget(
        _app(
          Rol.dueno,
          const PantallaMenuSemana(),
          repo: RepositorioAlimentacionEnMemoria(conEjemplo: false),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Sin platillo').first);
      await t.pumpAndSettle();
      await t.tap(find.text('Sopa de lentejas'));
      await t.pumpAndSettle();
      expect(find.text('Sopa de lentejas'), findsOneWidget);
      expect(find.text('Sin platillo'), findsNWidgets(27));
      await t.tap(find.text('Deshacer'));
      await t.pumpAndSettle();
      expect(find.text('Sin platillo'), findsNWidgets(28));
    });

    testWidgets('el dueño cambia entre los dos menús', (t) async {
      await _alto(t);
      await t.pumpWidget(
        _app(
          Rol.dueno,
          const PantallaMenuSemana(),
          repo: RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Adulto mayor con Alzheimer'), findsOneWidget);
      await t.tap(find.text('Pareja y dueño'));
      await t.pumpAndSettle();
      expect(find.text('Adulto mayor con Alzheimer'), findsNothing);
    });

    testWidgets(
      'advierte al elegir un platillo con alimento duro en el menú de Papá',
      (t) async {
        await _alto(t);
        await t.pumpWidget(
          _app(
            Rol.dueno,
            const PantallaMenuSemana(),
            repo: RepositorioAlimentacionEnMemoria(conEjemplo: false),
          ),
        );
        await t.pumpAndSettle();
        await t.tap(find.text('Sin platillo').first);
        await t.pumpAndSettle();
        await t.tap(find.text('Yogurt con granola'));
        await t.pumpAndSettle();
        expect(find.text('Alimento duro'), findsOneWidget);
        await t.tap(find.text('Elegir otro'));
        await t.pumpAndSettle();
        await t.tap(
          find.text('Quitar platillo'),
        ); // sigue en la hoja, sin asignar nada
        await t.pumpAndSettle();
        expect(find.text('Yogurt con granola'), findsNothing);

        // En el menú de la pareja no hay advertencia.
        await t.tap(find.text('Pareja y dueño'));
        await t.pumpAndSettle();
        await t.tap(find.text('Sin platillo').first);
        await t.pumpAndSettle();
        await t.tap(find.text('Yogurt con granola'));
        await t.pumpAndSettle();
        expect(find.text('Alimento duro'), findsNothing);
        expect(find.text('Yogurt con granola'), findsOneWidget);
      },
    );

    testWidgets('cuidadora: solo el menú de Papá, en solo lectura', (t) async {
      await _alto(t);
      await t.pumpWidget(
        _app(
          Rol.cuidador,
          const PantallaMenuSemana(),
          repo: RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Solo lectura'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byType(SegmentedButton<MenuId>), findsNothing);
      expect(find.text('Agregar suplemento'), findsNothing);
      expect(find.text('Adulto mayor con Alzheimer'), findsOneWidget);
      expect(find.text('Proteína en polvo'), findsWidgets);
    });

    testWidgets(
      'familiar: edita el menú de Papá, no ve el otro ni edita suplementos',
      (t) async {
        await _alto(t);
        await t.pumpWidget(
          _app(
            Rol.familiar,
            const PantallaMenuSemana(),
            repo: RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('Solo lectura'), findsNothing);
        expect(find.byIcon(Icons.edit_outlined), findsNWidgets(28));
        expect(find.byType(SegmentedButton<MenuId>), findsNothing);
        expect(find.text('Agregar suplemento'), findsNothing);
        await t.tap(find.byIcon(Icons.edit_outlined).first);
        await t.pumpAndSettle();
        await t.tap(find.text('Flan de huevo').last);
        await t.pumpAndSettle();
        expect(find.text('Menú actualizado'), findsOneWidget);
      },
    );

    testWidgets('la cuenta Casa no ve ningún menú ni el perfil clínico', (
      t,
    ) async {
      await t.pumpWidget(
        _app(
          Rol.casa,
          const PantallaMenuSemana(),
          repo: RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('No tienes menús para ver'), findsOneWidget);
      expect(find.textContaining('Alzheimer'), findsNothing);
    });

    testWidgets('suplementos: el dueño agrega uno', (t) async {
      await _alto(t);
      await t.pumpWidget(
        _app(
          Rol.dueno,
          const PantallaMenuSemana(),
          repo: RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Agregar suplemento'));
      await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextField, 'Nombre'), 'Calcio');
      await t.enterText(find.widgetWithText(TextField, 'Dosis'), '1 tableta');
      await t.enterText(find.widgetWithText(TextField, 'Horario'), 'Cena');
      await t.tap(find.text('Guardar'));
      await t.pumpAndSettle();
      expect(find.text('Calcio'), findsOneWidget);
      expect(find.text('1 tableta · Cena'), findsOneWidget);
    });

    testWidgets('lista: agrupa, marca comprado con texto y cuenta avance', (
      t,
    ) async {
      await _alto(t);
      await t.pumpWidget(
        _app(
          Rol.coadministrador,
          const PantallaListaCompras(),
          repo: RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Frutas y verduras'), findsOneWidget);
      expect(find.textContaining('0 de'), findsOneWidget);
      await t.tap(find.byType(Checkbox).first);
      await t.pumpAndSettle();
      expect(find.text('Comprado'), findsOneWidget);
      expect(find.textContaining('1 de'), findsOneWidget);
    });

    testWidgets('lista vacía explica cómo llenarla', (t) async {
      await t.pumpWidget(
        _app(
          Rol.dueno,
          const PantallaListaCompras(),
          repo: RepositorioAlimentacionEnMemoria(conEjemplo: false),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('La lista está vacía'), findsOneWidget);
    });

    testWidgets(
      'la cuidadora ve la lista de Papá sin poder marcar; el familiar no la ve',
      (t) async {
        await _alto(t);
        await t.pumpWidget(
          _app(
            Rol.cuidador,
            const PantallaListaCompras(),
            repo: RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes),
          ),
        );
        await t.pumpAndSettle();
        expect(
          t.widget<Checkbox>(find.byType(Checkbox).first).onChanged,
          isNull,
        );
        expect(find.byType(SegmentedButton<MenuId>), findsNothing);

        await t.pumpWidget(
          _app(
            Rol.familiar,
            const PantallaListaCompras(),
            repo: RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes),
          ),
        );
        await t.pumpAndSettle();
        expect(find.byType(Checkbox), findsNothing);
        expect(find.text('No tienes listas para ver'), findsOneWidget);
      },
    );

    testWidgets('letra 2.0 en 360 dp sin desbordes', (t) async {
      await t.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final repo = RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes);
      for (final p in const [PantallaMenuSemana(), PantallaListaCompras()]) {
        await t.pumpWidget(
          ProviderScope(
            overrides: [
              relojProvider.overrideWithValue(RelojFijo(_miercoles)),
              almacenSeguroProvider.overrideWithValue(AlmacenSeguroEnMemoria()),
              servicioSesionProvider.overrideWithValue(ServicioSesionFalso()),
              sesionEfectivaProvider.overrideWithValue(_sesion(Rol.dueno)),
              repositorioAlimentacionProvider.overrideWithValue(repo),
            ],
            child: MaterialApp(
              builder: (c, h) => MediaQuery(
                data: MediaQuery.of(c)
                    .copyWith(textScaler: const TextScaler.linear(2.0)),
                child: h!,
              ),
              home: p,
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      }
    });
  });

  group('guardia', () {
    Iterable<File> fuentes() =>
        Directory('lib/modulos/alimentacion')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'));
    String sinComentarios(File f) => f
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');

    test('sin precios, IA, red ni servidor en el código', () {
      final prohibidas = RegExp(
        r"""precio|importe|[\s'"]\$\s?\d|gemini|openai|anthropic|package:http|dart:io|supabase""",
        caseSensitive: false,
      );
      expect(fuentes(), isNotEmpty);
      for (final f in fuentes()) {
        expect(prohibidas.hasMatch(sinComentarios(f)), isFalse, reason: f.path);
      }
    });

    test('el perfil clínico solo vive en perfiles.dart, sin enlaces a voz ni asistente', () {
      final clinico = RegExp(
        r'alzheimer|demencia|diagn[oó]stic|medicament|alergi',
        caseSensitive: false,
      );
      final enlaces = RegExp(
        r"import .*(asistente|voz|herramientas|bocina|ia/)",
        caseSensitive: false,
      );
      for (final f in fuentes()) {
        final esPerfil = f.path.endsWith('datos/perfiles.dart');
        expect(
          clinico.hasMatch(f.readAsStringSync()),
          esPerfil,
          reason: f.path,
        );
        expect(enlaces.hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
      }
    });
  });
}
