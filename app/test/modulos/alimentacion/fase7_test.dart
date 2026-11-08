// Fase 7, primera tanda: recetas por archivo, precios base y reales, lista por
// pasillo, votación del plan familiar y lo que no le toca a Casa ni a la
// cuidadora.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/sesion_efectiva.dart';
import 'package:gravity/diseno/proveedores.dart' show RelojFijo, relojProvider;
import 'package:gravity/modulos/alimentacion/casos_uso/importar_recetas.dart';
import 'package:gravity/modulos/alimentacion/casos_uso/lista_compras.dart';
import 'package:gravity/modulos/alimentacion/casos_uso/plan_familiar.dart';
import 'package:gravity/modulos/alimentacion/casos_uso/servicio_alimentacion.dart';
import 'package:gravity/modulos/alimentacion/datos/modelos.dart';
import 'package:gravity/modulos/alimentacion/datos/repositorio.dart';
import 'package:gravity/modulos/alimentacion/pantallas/importar_recetas.dart';
import 'package:gravity/modulos/alimentacion/pantallas/menu_del_dia_papa.dart';
import 'package:gravity/modulos/alimentacion/pantallas/plan_familiar.dart';
import 'package:gravity/modulos/alimentacion/estado/proveedores.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';

final _miercoles = DateTime(2026, 11, 4);
final _lunes = DateTime(2026, 11, 2);

Map<String, Object?> _receta({
  Object? titulo = 'Caldo de pollo',
  Object? porciones = 2,
  Object? pasos = const ['Hierve el pollo.', 'Agrega las verduras.'],
  Object? ingredientes = const [
    {'nombre': 'Pollo', 'cantidad': 300, 'unidad': 'g', 'pasillo': 'Carnes y pescados'},
    {'nombre': 'Zanahoria', 'cantidad': 2, 'unidad': 'pza'},
  ],
}) => {
  'titulo': titulo,
  'porciones': porciones,
  'pasos': pasos,
  'ingredientes': ingredientes,
};

String _archivo(List<Object?> recetas) =>
    jsonEncode({'version': 1, 'recetas': recetas});

ResultadoImportacion _importar(Object? receta) =>
    importarRecetasDeTexto(_archivo([receta]));

void main() {
  group('importar recetas', () {
    test('archivo válido: receta con pasos en orden e ingredientes', () {
      final r = _importar(_receta());
      expect(r.valido, isTrue);
      final p = r.recetas.single.platillo;
      expect(p.nombre, 'Caldo de pollo');
      expect(p.porciones, 2);
      expect(p.pasos, ['Hierve el pollo.', 'Agrega las verduras.']);
      expect(p.ingredientes.map((i) => i.nombre), ['Pollo', 'Zanahoria']);
      expect(p.ingredientes[0].seccion, SeccionCompra.carnesPescados);
      expect(p.ingredientes[1].seccion, SeccionCompra.otros);
      expect(p.id, 'imp-caldo-de-pollo');
    });

    test('también acepta un arreglo de recetas sin envoltura', () {
      expect(importarRecetasDeTexto(jsonEncode([_receta()])).valido, isTrue);
    });

    test('rechaza JSON roto, bytes que no son UTF-8 y archivos enormes', () {
      expect(importarRecetasDeTexto('{no es json').valido, isFalse);
      expect(
        importarRecetasDeBytes(Uint8List.fromList([0xff, 0xfe, 0x00])).valido,
        isFalse,
      );
      expect(
        importarRecetasDeBytes(Uint8List(maxBytesArchivoRecetas + 1)).errores.single.mensaje,
        contains('1 MB'),
      );
    });

    test('rechaza texto no válido: etiquetas y caracteres de control', () {
      expect(_importar(_receta(titulo: '<b>Caldo</b>')).valido, isFalse);
      expect(
        _importar(_receta(pasos: ['Hierve\u0000 el pollo.'])).valido,
        isFalse,
      );
      expect(
        _importar(_receta(ingredientes: [
          {'nombre': '<script>', 'cantidad': 1, 'unidad': 'pza'},
        ])).valido,
        isFalse,
      );
    });

    test('rechaza pasos de más de 200 caracteres y más de 50 pasos', () {
      final largo = _importar(_receta(pasos: ['a' * 201]));
      expect(largo.valido, isFalse);
      expect(largo.errores.single.mensaje, contains('200'));
      expect(_importar(_receta(pasos: ['a' * 200])).valido, isTrue);
      expect(
        _importar(_receta(pasos: List.filled(50, 'Mezcla.'))).valido,
        isTrue,
      );
      final muchos = _importar(_receta(pasos: List.filled(51, 'Mezcla.')));
      expect(muchos.valido, isFalse);
      expect(muchos.errores.single.mensaje, contains('50 pasos'));
    });

    test('rechaza campos vacíos o faltantes', () {
      expect(_importar(_receta(titulo: '  ')).valido, isFalse);
      expect(_importar(_receta(titulo: null)).valido, isFalse);
      expect(_importar(_receta(pasos: const [])).valido, isFalse);
      expect(_importar(_receta(pasos: ['Hierve.', ''])).valido, isFalse);
      expect(_importar(_receta(ingredientes: const [])).valido, isFalse);
      expect(_importar(_receta(porciones: 0)).valido, isFalse);
      expect(
        _importar(_receta(ingredientes: [
          {'nombre': 'Sal', 'cantidad': 1, 'unidad': ''},
        ])).valido,
        isFalse,
      );
      expect(
        _importar(_receta(ingredientes: [
          {'nombre': 'Sal', 'cantidad': 0, 'unidad': 'g'},
        ])).valido,
        isFalse,
      );
      expect(
        _importar(_receta(ingredientes: [
          {'nombre': 'Sal', 'cantidad': 1, 'unidad': 'g', 'pasillo': 'Luna'},
        ])).valido,
        isFalse,
      );
    });

    test('todo o nada: una receta mala invalida el archivo', () {
      final r = importarRecetasDeTexto(
        _archivo([_receta(), _receta(titulo: 'Sopa', pasos: const [])]),
      );
      expect(r.valido, isFalse);
      expect(r.recetas, isEmpty);
      expect(r.errores.first.donde, contains('Receta 2'));
    });

    test('título repetido en el archivo es error; las cifras en pasos avisan', () {
      expect(
        importarRecetasDeTexto(_archivo([_receta(), _receta()])).valido,
        isFalse,
      );
      final r = _importar(_receta(pasos: ['Hierve 20 minutos.']));
      expect(r.valido, isTrue);
      expect(r.recetas.single.advertencias, isNotEmpty);
    });

    test('guardar reemplaza por título y la rechazada no se guarda', () async {
      final repo = RepositorioAlimentacionEnMemoria(conEjemplo: false);
      final s = ServicioAlimentacion(repo, rol: Rol.dueno);
      final n0 = (await repo.platillos()).length;
      await s.importarRecetas(_importar(_receta()));
      await s.importarRecetas(_importar(_receta(porciones: 4)));
      final todos = await repo.platillos();
      expect(todos.length, n0 + 1);
      expect(todos.firstWhere((p) => p.id == 'imp-caldo-de-pollo').porciones, 4);
      expect(
        () => s.importarRecetas(_importar(_receta(titulo: ''))),
        throwsA(isA<ArgumentError>()),
      );
      for (final rol in [Rol.familiar, Rol.cuidador, Rol.casa]) {
        await expectLater(
          ServicioAlimentacion(repo, rol: rol).importarRecetas(_importar(_receta())),
          throwsA(isA<PermisoDenegado>()),
          reason: rol.name,
        );
      }
    });
  });

  group('precios', () {
    test('el precio base es base y se muestra estimado; sin precio no hay costo', () async {
      final repo = RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes);
      final precios = await repo.precios();
      final huevo = precios[claveCompra('Huevo', 'pza')]!;
      expect(huevo.esBase, isTrue);
      expect(precios.values.every((p) => p.esBase), isTrue);
      final items = await ServicioAlimentacion(repo, rol: Rol.dueno)
          .listaCompras(MenuId.pareja, _miercoles);
      final h = items.firstWhere((i) => i.nombre == 'Huevo');
      expect(h.costoEstimado, isTrue);
      expect(h.costoCentavos, isNotNull);
      expect(costoTexto(h.costoCentavos!, estimado: h.costoEstimado), contains('estimado'));
      // Ingrediente sin precio base: sin costo.
      final sinPrecio = items.firstWhere((i) => i.precio == null);
      expect(sinPrecio.costoCentavos, isNull);
      final total = costoDeLista(items)!;
      expect(total.estimado, isTrue);
      expect(total.sinPrecio, greaterThan(0));
    });

    test('lista sin ningún precio: no hay costo total', () {
      const it = ItemCompra(
        nombre: 'Sal',
        cantidad: 1,
        unidad: 'kg',
        seccion: SeccionCompra.abarrotes,
        comprado: false,
      );
      expect(it.costoCentavos, isNull);
      expect(costoDeLista([it]), isNull);
    });

    test('la primera compra real reemplaza al base y las siguientes lo actualizan', () async {
      final repo = RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes);
      final s = ServicioAlimentacion(repo, rol: Rol.dueno);
      final clave = claveCompra('Huevo', 'pza');
      expect((await repo.precios())[clave]!.esBase, isTrue);

      // 12 piezas por $48.00 -> $4.00 la pieza, real.
      await s.registrarCompra(MenuId.pareja, _miercoles, clave,
          cantidadComprada: 12, totalCentavos: 4800);
      var p = (await repo.precios())[clave]!;
      expect(p.esBase, isFalse);
      expect(p.costoDe(3), 1200);
      var items = await s.listaCompras(MenuId.pareja, _miercoles);
      var h = items.firstWhere((i) => i.clave == clave);
      expect(h.comprado, isTrue);
      expect(h.costoEstimado, isFalse);
      expect(costoTexto(h.costoCentavos!, estimado: h.costoEstimado), isNot(contains('estimado')));

      // Segunda compra: el precio se actualiza.
      await s.registrarCompra(MenuId.pareja, _miercoles, clave,
          cantidadComprada: 6, totalCentavos: 3000);
      p = (await repo.precios())[clave]!;
      expect(p.esBase, isFalse);
      expect(p.costoDe(1), 500);

      // Las demás siguen siendo base.
      expect((await repo.precios())[claveCompra('Tortilla', 'pza')]!.esBase, isTrue);
    });

    test('una compra necesita precio y cantidad mayores que cero y permiso', () async {
      final repo = RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes);
      final clave = claveCompra('Huevo', 'pza');
      final s = ServicioAlimentacion(repo, rol: Rol.dueno);
      expect(
        () => s.registrarCompra(MenuId.pareja, _miercoles, clave,
            cantidadComprada: 1, totalCentavos: 0),
        throwsArgumentError,
      );
      expect((await repo.precios())[clave]!.esBase, isTrue);
      for (final rol in [Rol.familiar, Rol.cuidador, Rol.casa]) {
        await expectLater(
          ServicioAlimentacion(repo, rol: rol).registrarCompra(
            MenuId.papa, _miercoles, clave,
            cantidadComprada: 1, totalCentavos: 100),
          throwsA(isA<PermisoDenegado>()),
          reason: rol.name,
        );
      }
      expect((await repo.precios())[clave]!.esBase, isTrue);
    });

    test('pesosTexto en centavos', () {
      expect(pesosTexto(12345), '\$123.45');
      expect(pesosTexto(5), '\$0.05');
    });
  });

  group('lista por pasillo', () {
    test('agrupa por pasillo en orden, suma cantidades y respeta lo comprado', () async {
      final repo = RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes);
      final s = ServicioAlimentacion(repo, rol: Rol.dueno);
      await s.marcar(MenuId.pareja, _miercoles, claveCompra('Huevo', 'pza'), true);
      final items = await s.listaCompras(MenuId.pareja, _miercoles);
      final grupos = agruparPorSeccion(items);
      final orden = grupos.keys.map((k) => k.index).toList();
      expect(orden, [...orden]..sort());
      for (final g in grupos.entries) {
        expect(g.value.every((i) => i.seccion == g.key), isTrue);
      }
      expect(items.firstWhere((i) => i.nombre == 'Huevo').comprado, isTrue);
      expect(items.where((i) => i.comprado).length, 1);
    });

    test('una receta importada aporta sus ingredientes a su pasillo', () {
      final r = _importar(_receta()).recetas.single.platillo;
      final lista = generarListaCompras(
        menu: const [
          EntradaMenu(dia: 0, tiempo: TiempoComida.comida, platilloId: 'imp-caldo-de-pollo'),
          EntradaMenu(dia: 2, tiempo: TiempoComida.cena, platilloId: 'imp-caldo-de-pollo'),
        ],
        platillos: [r],
      );
      final pollo = lista.firstWhere((i) => i.nombre == 'Pollo');
      expect(pollo.cantidad, 600);
      expect(pollo.seccion, SeccionCompra.carnesPescados);
      expect(lista.first.seccion, SeccionCompra.carnesPescados);
    });
  });

  group('votación del plan familiar', () {
    final t0 = DateTime(2026, 11, 10, 9);
    final dia = DateTime(2026, 11, 10);

    ServicioPlanFamiliar srv(RepositorioAlimentacion repo, Rol rol, String id,
            {DateTime? ahora, bool maestra = false}) =>
        ServicioPlanFamiliar(repo,
            rol: rol,
            personaId: id,
            personaNombre: id,
            esMaestra: maestra,
            ahora: () => ahora ?? t0);

    test('dos propuestas de personas distintas; votos; empate y cambio de voto', () async {
      final repo = RepositorioAlimentacionEnMemoria(conEjemplo: false);
      final ana = srv(repo, Rol.dueno, 'ana');
      final beto = srv(repo, Rol.coadministrador, 'beto');
      var v = await ana.proponer(dia, titulo: 'Pozole');
      expect(v.estado(t0), EstadoVotacion.faltaPropuesta);
      await expectLater(ana.proponer(dia, titulo: 'Otro'), throwsA(isA<ErrorVotacion>()));
      await expectLater(ana.votar(dia, v.propuestas[0].id), throwsA(isA<ErrorVotacion>()));
      v = await beto.proponer(dia, titulo: 'Tacos');
      expect(v.estado(t0), EstadoVotacion.enCurso);
      final a = v.propuestas[0].id, b = v.propuestas[1].id;

      v = await ana.votar(dia, a);
      v = await beto.votar(dia, b);
      expect(v.hayEmpate, isTrue);
      expect(v.estado(t0), EstadoVotacion.empate);
      expect(v.delante, isNull);

      // Empate: Beto cambia su voto y gana la primera.
      v = await beto.votar(dia, a);
      expect(v.votos['beto'], a);
      expect(v.conteo(a), 2);
      expect(v.conteo(b), 0);
      expect(v.hayEmpate, isFalse);
      expect(v.delante!.id, a);
      // Mismo día aún: sin ganador definitivo.
      expect(v.ganador(t0), isNull);
      final despues = t0.add(const Duration(days: 1, minutes: 1));
      expect(v.ganador(despues)!.titulo, 'Pozole');
      expect(v.estado(despues), EstadoVotacion.ganador);
      expect(v.puedeVotar(despues), isFalse);
      await expectLater(
        srv(repo, Rol.dueno, 'ana', ahora: despues).votar(dia, b),
        throwsA(isA<ErrorVotacion>()),
      );
    });

    test('pasado el día, un empate sigue abierto para cambiar el voto', () async {
      final repo = RepositorioAlimentacionEnMemoria(conEjemplo: false);
      var v = await srv(repo, Rol.dueno, 'ana').proponer(dia, titulo: 'Pozole');
      v = await srv(repo, Rol.familiar, 'cris').proponer(dia, titulo: 'Tacos');
      final a = v.propuestas[0].id, b = v.propuestas[1].id;
      await srv(repo, Rol.dueno, 'ana').votar(dia, a);
      await srv(repo, Rol.familiar, 'cris').votar(dia, b);
      final tarde = t0.add(const Duration(days: 2));
      v = (await repo.votacion(dia))!;
      expect(v.estado(tarde), EstadoVotacion.empate);
      expect(v.ganador(tarde), isNull);
      v = await srv(repo, Rol.familiar, 'cris', ahora: tarde).votar(dia, a);
      expect(v.estado(tarde), EstadoVotacion.ganador);
      expect(v.ganador(tarde)!.id, a);
    });

    test('quién propone y vota: dueño, pareja y familiar; Casa y la maestra ven; la cuidadora no', () async {
      final repo = RepositorioAlimentacionEnMemoria(conEjemplo: false);
      await srv(repo, Rol.dueno, 'ana').proponer(dia, titulo: 'Pozole');
      for (final r in [Rol.casa]) {
        final s = srv(repo, r, 'x');
        expect((await s.votacion(dia))!.propuestas, hasLength(1));
        await expectLater(s.proponer(dia, titulo: 'Z'), throwsA(isA<ErrorVotacion>()));
        await expectLater(s.votar(dia, 'v-2026-11-10-p1'), throwsA(isA<ErrorVotacion>()));
      }
      final maestra = srv(repo, Rol.coadministrador, 'm', maestra: true);
      expect(await maestra.votacion(dia), isNotNull);
      await expectLater(maestra.proponer(dia, titulo: 'Z'), throwsA(isA<ErrorVotacion>()));
      await expectLater(
        srv(repo, Rol.cuidador, 'c').votacion(dia),
        throwsA(isA<ErrorVotacion>()),
      );
      expect(puedeParticiparPlan(Rol.familiar), isTrue);
    });
  });

  group('lo que no le toca a Casa ni a la cuidadora', () {
    test('Casa ve solo los nombres del menú del día de Papá', () async {
      final repo = RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes);
      final casa = ServicioAlimentacion(repo, rol: Rol.casa);
      final hoy = await casa.menuDelDiaPapa(_miercoles);
      expect(hoy, isNotEmpty);
      expect(hoy.every((c) => c.platillo.isNotEmpty), isTrue);
      // Todo lo demás sigue negado.
      expect(casa.menusVisibles, isEmpty);
      await expectLater(casa.menu(MenuId.papa, _miercoles), throwsA(isA<PermisoDenegado>()));
      await expectLater(casa.suplementos(MenuId.papa), throwsA(isA<PermisoDenegado>()));
      await expectLater(casa.listaCompras(MenuId.papa, _miercoles), throwsA(isA<PermisoDenegado>()));
      await expectLater(casa.platillos(), throwsA(isA<PermisoDenegado>()));
      expect(() => casa.perfil(MenuId.papa), throwsA(isA<PermisoDenegado>()));
      // El menú del día sale en el mismo orden de los tiempos.
      expect(hoy.map((c) => c.tiempo.index), [...hoy.map((c) => c.tiempo.index)]..sort());
    });

    test('la cuidadora ve el menú de Papá sin editar ni tocar precios; el familiar edita solo el de Papá', () async {
      final repo = RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes);
      final c = ServicioAlimentacion(repo, rol: Rol.cuidador);
      expect(await c.menu(MenuId.papa, _miercoles), isNotEmpty);
      expect(c.puedeEditarMenuDe(MenuId.papa), isFalse);
      await expectLater(c.menu(MenuId.pareja, _miercoles), throwsA(isA<PermisoDenegado>()));
      await expectLater(c.asignar(MenuId.papa, _miercoles, 0, TiempoComida.cena, null),
          throwsA(isA<PermisoDenegado>()));
      final f = ServicioAlimentacion(repo, rol: Rol.familiar);
      expect(f.puedeEditarMenuDe(MenuId.papa), isTrue);
      expect(f.puedeEditarMenuDe(MenuId.pareja), isFalse);
      expect(puedeVerPlan(Rol.cuidador), isFalse);
    });

    test('el menú del día no lleva perfil clínico ni suplementos', () async {
      final repo = RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes);
      final hoy = await ServicioAlimentacion(repo, rol: Rol.casa).menuDelDiaPapa(_miercoles);
      final texto = hoy.map((c) => '${c.tiempo.etiqueta} ${c.platillo}').join(' ').toLowerCase();
      expect(texto, isNot(contains('alzheimer')));
      expect(texto, isNot(contains('tableta')));
    });
  });

  group('pantallas', () {
    Widget app(Rol rol, Widget pantalla,
            {RepositorioAlimentacion? repo,
            SelectorArchivoRecetas? selector,
            String id = 'p1',
            bool maestra = false}) =>
        ProviderScope(
          overrides: [
            relojProvider.overrideWithValue(RelojFijo(_miercoles)),
            almacenSeguroProvider.overrideWithValue(AlmacenSeguroEnMemoria()),
            servicioSesionProvider.overrideWithValue(ServicioSesionFalso()),
            sesionEfectivaProvider.overrideWithValue(Sesion(
              persona: Persona(id: id, nombre: 'Persona $id'),
              rol: rol,
              esMaestra: maestra,
            )),
            if (repo != null) repositorioAlimentacionProvider.overrideWithValue(repo),
            if (selector != null) selectorRecetasProvider.overrideWithValue(selector),
          ],
          child: MaterialApp(home: pantalla),
        );

    Future<void> alto(WidgetTester t) async {
      await t.binding.setSurfaceSize(const Size(400, 9000));
      addTearDown(() => t.binding.setSurfaceSize(null));
    }

    ArchivoRecetas arch(String texto) =>
        ArchivoRecetas('recetas.json', Uint8List.fromList(utf8.encode(texto)));

    testWidgets('importar: vista previa y luego guarda', (t) async {
      await alto(t);
      final repo = RepositorioAlimentacionEnMemoria(conEjemplo: false);
      await t.pumpWidget(app(Rol.dueno, const PantallaImportarRecetas(),
          repo: repo, selector: () async => arch(_archivo([_receta()]))));
      await t.tap(find.text('Elegir archivo'));
      await t.pumpAndSettle();
      expect(find.text('Vista previa: 1 receta'), findsOneWidget);
      expect(find.text('Caldo de pollo'), findsOneWidget);
      expect(find.text('1. Hierve el pollo.'), findsOneWidget);
      expect((await repo.platillos()).any((p) => p.id == 'imp-caldo-de-pollo'), isFalse);
      await t.tap(find.text('Guardar receta'));
      await t.pumpAndSettle();
      expect(find.text('Se guardó 1 receta'), findsOneWidget);
      expect((await repo.platillos()).any((p) => p.id == 'imp-caldo-de-pollo'), isTrue);
    });

    testWidgets('importar: archivo con errores no se puede guardar', (t) async {
      await alto(t);
      final repo = RepositorioAlimentacionEnMemoria(conEjemplo: false);
      await t.pumpWidget(app(Rol.dueno, const PantallaImportarRecetas(),
          repo: repo,
          selector: () async => arch(_archivo([_receta(pasos: ['a' * 201])]))));
      await t.tap(find.text('Elegir archivo'));
      await t.pumpAndSettle();
      expect(find.text('El archivo no se puede importar'), findsOneWidget);
      expect(find.textContaining('200 caracteres'), findsOneWidget);
      expect(find.text('Guardar receta'), findsNothing);
    });

    testWidgets('importar: quien no edita no ve el selector', (t) async {
      await t.pumpWidget(app(Rol.cuidador, const PantallaImportarRecetas(),
          repo: RepositorioAlimentacionEnMemoria(conEjemplo: false)));
      await t.pumpAndSettle();
      expect(find.text('Elegir archivo'), findsNothing);
    });

    testWidgets('plan: proponer, votar y cambiar el voto en empate', (t) async {
      await alto(t);
      final repo = RepositorioAlimentacionEnMemoria(conEjemplo: false);
      final dia = DateTime(2026, 11, 4);
      final a = ServicioPlanFamiliar(repo,
          rol: Rol.dueno, personaId: 'ana', personaNombre: 'Ana',
          ahora: () => _miercoles);
      final b = ServicioPlanFamiliar(repo,
          rol: Rol.familiar, personaId: 'beto', personaNombre: 'Beto',
          ahora: () => _miercoles);
      var v = await a.proponer(dia, titulo: 'Pozole');
      v = await b.proponer(dia, titulo: 'Tacos');
      await a.votar(dia, v.propuestas[0].id);
      await b.votar(dia, v.propuestas[1].id);

      await t.pumpWidget(app(Rol.dueno, const PantallaPlanFamiliar(),
          repo: repo, id: 'ana'));
      await t.pumpAndSettle();
      expect(find.text('Empate: cualquiera puede cambiar su voto.'), findsOneWidget);
      expect(find.text('Tu voto'), findsOneWidget);
      await t.tap(find.text('Cambiar mi voto a esta'));
      await t.pumpAndSettle();
      expect(find.text('2 votos'), findsOneWidget);
      expect(find.text('Tu voto'), findsOneWidget);
    });

    testWidgets('plan: Casa lo ve en solo lectura, la cuidadora no', (t) async {
      final repo = RepositorioAlimentacionEnMemoria(conEjemplo: false);
      await ServicioPlanFamiliar(repo,
              rol: Rol.dueno, personaId: 'ana', personaNombre: 'Ana',
              ahora: () => _miercoles)
          .proponer(DateTime(2026, 11, 4), titulo: 'Pozole');
      await t.pumpWidget(app(Rol.casa, const PantallaPlanFamiliar(), repo: repo));
      await t.pumpAndSettle();
      expect(find.text('Pozole'), findsOneWidget);
      expect(find.text('Solo lectura'), findsOneWidget);
      expect(find.text('Dar mi propuesta'), findsNothing);
      await t.pumpWidget(app(Rol.cuidador, const PantallaPlanFamiliar(), repo: repo));
      await t.pumpAndSettle();
      expect(find.text('Pozole'), findsNothing);
      expect(find.text('No tienes acceso al plan familiar'), findsOneWidget);
    });

    testWidgets('Casa: tarjeta del menú de hoy sin perfil ni suplementos', (t) async {
      await t.pumpWidget(app(Rol.casa, const Scaffold(body: TarjetaMenuDelDiaPapa()),
          repo: RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes)));
      await t.pumpAndSettle();
      expect(find.text('Menú de hoy'), findsOneWidget);
      expect(find.textContaining('Alzheimer'), findsNothing);
      expect(find.textContaining('Multivit'), findsNothing);
    });
  });
}
