// Fase 7 v1.1: lector de código de barras (con lector falso) y alerta de
// subida de precio con historial. Sin cámara ni catálogo externo.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/sesion_efectiva.dart';
import 'package:gravity/diseno/proveedores.dart' show RelojFijo, relojProvider;
import 'package:gravity/modulos/alimentacion/casos_uso/lista_compras.dart';
import 'package:gravity/modulos/alimentacion/casos_uso/servicio_alimentacion.dart';
import 'package:gravity/modulos/alimentacion/datos/lector_codigo.dart';
import 'package:gravity/modulos/alimentacion/datos/modelos.dart';
import 'package:gravity/modulos/alimentacion/datos/repositorio.dart';
import 'package:gravity/modulos/alimentacion/estado/proveedores.dart';
import 'package:gravity/modulos/alimentacion/pantallas/compras.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';

final _miercoles = DateTime(2026, 11, 4);
final _lunes = DateTime(2026, 11, 2);

const _leche = Ingrediente(
  'Leche entera',
  1,
  'l',
  SeccionCompra.lacteosHuevo,
  codigoBarras: '7501000000011',
);

RepositorioAlimentacionEnMemoria _repoConLeche() {
  final r = RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes);
  r.guardarPlatillos(const [
    Platillo('p-leche', 'Licuado', [_leche]),
  ]);
  return r;
}

ServicioAlimentacion _srv(RepositorioAlimentacion repo, [DateTime? ahora]) {
  var t = ahora ?? DateTime(2026, 11, 2);
  return ServicioAlimentacion(
    repo,
    rol: Rol.dueno,
    ahora: () => t = t.add(const Duration(days: 1)),
  );
}

Future<AlertaPrecio?> _compra(
  ServicioAlimentacion s,
  int centavos, {
  double cantidad = 1,
}) async {
  final tienda = await s.agregarTienda('Súper');
  final r = await s.registrarCompra(
    MenuId.pareja,
    _lunes,
    claveCompra('Leche entera', 'l'),
    cantidadComprada: cantidad,
    totalCentavos: centavos,
    nombre: 'Leche entera',
    unidad: 'l',
    tiendaId: tienda.id,
  );
  return r.alerta;
}

class _RepoCodigoUsado extends RepositorioAlimentacionEnMemoria {
  _RepoCodigoUsado() : super(semanaEjemplo: _lunes);
  @override
  Future<bool> guardarIngredienteConCodigo(Ingrediente ingrediente) async =>
      throw const ErrorAlimentacionServidor(
        'Ese código ya es de otro producto',
      );
}

void main() {
  group('lector de código', () {
    test(
      'lector falso devuelve un código y encuentra el ingrediente',
      () async {
        final s = _srv(_repoConLeche());
        final lector = LectorCodigoFalso('7501000000011');
        final codigo = await lector.leer();
        expect(codigo, '7501000000011');
        final ing = await s.buscarPorCodigoBarras(codigo!);
        expect(ing?.nombre, 'Leche entera');
        expect(lector.lecturas, 1);
      },
    );

    test(
      'código no encontrado: se captura a mano y queda guardado con el código',
      () async {
        final repo = _repoConLeche();
        final s = _srv(repo);
        expect(await s.buscarPorCodigoBarras('999'), isNull);
        await s.guardarIngredienteConCodigo(
          codigo: '999',
          nombre: 'Atún',
          unidad: 'lata',
          seccion: SeccionCompra.abarrotes,
        );
        final ing = await s.buscarPorCodigoBarras('999');
        expect(ing?.nombre, 'Atún');
        expect(ing?.codigoBarras, '999');
        expect(
          () => s.guardarIngredienteConCodigo(
            codigo: '1',
            nombre: '',
            unidad: 'g',
          ),
          throwsArgumentError,
        );
      },
    );

    test('el lector por omisión no lee ni pide cámara', () async {
      expect(await const LectorCodigoSinCamara().leer(), isNull);
    });
  });

  group('alerta de precio e historial', () {
    test(
      'la primera compra real no alerta (el precio base no cuenta)',
      () async {
        expect(await _compra(_srv(_repoConLeche()), 2800), isNull);
      },
    );

    test(
      'sube más de 20%: alerta con porcentaje y precios unitarios',
      () async {
        final s = _srv(_repoConLeche());
        await _compra(s, 2000);
        final a = await _compra(s, 2600); // +30%
        expect(a, isNotNull);
        expect(a!.porcentaje, 30);
        expect(a.texto, contains('El precio subió 30% desde la última compra'));
        expect(a.texto, contains('\$20.00'));
        expect(a.texto, contains('\$26.00'));
      },
    );

    test('compara precio unitario, no total', () async {
      final s = _srv(_repoConLeche());
      await _compra(s, 2000); // $20 por l
      expect(await _compra(s, 6000, cantidad: 3), isNull); // $20 por l
    });

    test('sube 20% exacto o menos: sin alerta; baja: sin alerta', () async {
      final s = _srv(_repoConLeche());
      await _compra(s, 2000);
      expect(await _compra(s, 2400), isNull); // +20%, no "más de"
      expect(await _compra(s, 2500), isNull); // +4%
      expect(await _compra(s, 1000), isNull); // baja
    });

    test('historial ordenado: la más reciente primero', () async {
      final s = _srv(_repoConLeche());
      await _compra(s, 2000);
      await _compra(s, 2200);
      await _compra(s, 2500);
      final h = await s.historialPrecios(claveCompra('Leche entera', 'l'));
      expect(h.map((c) => c.totalCentavos), [2500, 2200, 2000]);
      final porIng = await s.historialPorIngrediente();
      expect(porIng.keys.single, claveCompra('Leche entera', 'l'));
    });
  });

  group('pantalla de compras', () {
    Widget app(RepositorioAlimentacion repo, LectorCodigo lector) =>
        ProviderScope(
          overrides: [
            relojProvider.overrideWithValue(RelojFijo(_miercoles)),
            almacenSeguroProvider.overrideWithValue(AlmacenSeguroEnMemoria()),
            servicioSesionProvider.overrideWithValue(ServicioSesionFalso()),
            sesionEfectivaProvider.overrideWithValue(
              const Sesion(
                persona: Persona(id: 'p1', nombre: 'Ejemplo'),
                rol: Rol.dueno,
              ),
            ),
            repositorioAlimentacionProvider.overrideWithValue(repo),
            lectorCodigoProvider.overrideWithValue(lector),
          ],
          child: const MaterialApp(home: PantallaListaCompras()),
        );

    testWidgets('código desconocido pide captura a mano y la guarda', (
      t,
    ) async {
      await t.binding.setSurfaceSize(const Size(400, 9000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final repo = RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes);
      await t.pumpWidget(app(repo, LectorCodigoFalso('555')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('escanear_codigo')));
      await t.pumpAndSettle();
      expect(find.text('Código nuevo'), findsOneWidget);
      await t.enterText(find.byKey(const Key('captura_nombre')), 'Galletas');
      await t.enterText(find.byKey(const Key('captura_unidad')), 'paq');
      await t.tap(find.text('Guardar con el código'));
      await t.pumpAndSettle();
      final guardados = await repo.ingredientesConCodigo();
      expect(guardados.single.codigoBarras, '555');
      expect(guardados.single.nombre, 'Galletas');
    });

    testWidgets('código ya usado por otro producto muestra el aviso', (
      t,
    ) async {
      await t.binding.setSurfaceSize(const Size(400, 9000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(app(_RepoCodigoUsado(), LectorCodigoFalso('555')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('escanear_codigo')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('captura_nombre')), 'Galletas');
      await t.enterText(find.byKey(const Key('captura_unidad')), 'paq');
      await t.tap(find.text('Guardar con el código'));
      await t.pumpAndSettle();
      expect(find.text('Ese código ya es de otro producto'), findsOneWidget);
      expect(find.text('Código nuevo'), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('compra que sube más de 20% muestra la alerta local', (
      t,
    ) async {
      await t.binding.setSurfaceSize(const Size(400, 9000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final repo = RepositorioAlimentacionEnMemoria(semanaEjemplo: _lunes);
      final lista = generarListaCompras(
        menu: await repo.menu(MenuId.papa, _lunes),
        platillos: await repo.platillos(),
      );
      final i = lista.first;
      await repo.agregarTienda('Súper');
      await repo.guardarCompraPrecio(
        CompraPrecio(
          clave: i.clave,
          nombre: i.nombre,
          unidad: i.unidad,
          totalCentavos: 1000,
          cantidad: i.cantidad,
          fecha: DateTime(2026, 10, 1),
        ),
      );
      await t.pumpWidget(app(repo, LectorCodigoFalso(null)));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Registrar compra con precio').first);
      await t.pumpAndSettle();
      final campos = find.byType(TextField);
      await t.enterText(campos.at(0), cantidadTexto(i.cantidad));
      await t.enterText(campos.at(1), '15');
      await t.tap(find.byKey(const Key('tienda')));
      await t.pumpAndSettle();
      await t.tap(find.text('Súper').last);
      await t.pumpAndSettle();
      await t.tap(find.text('Guardar compra'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('alerta_precio')), findsOneWidget);
      expect(find.textContaining('El precio subió 50%'), findsOneWidget);
    });
  });
}
