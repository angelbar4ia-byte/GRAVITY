// Lo que Finanzas aporta a Cuidados (Fase 5): el paso de un gasto de cuidado
// al libro con confirmación del dueño y el widget del resumen mensual
// (criterio 3 de la sección 7). Datos ilustrativos.
import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/finanzas/casos_uso/gasto_cuidado.dart';
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio.dart'
    show ErrorFinanzas;
import 'package:gravity/modulos/finanzas/pantallas/cuidados/resumen_mensual_cuidado.dart';

import '../../diseno/ayuda_pruebas.dart';
import 'ayuda_finanzas.dart';

void main() {
  final dueno = IdsDemostracion.dueno;
  final pareja = IdsDemostracion.pareja;
  const papa = IdsDemostracion.papa;
  const libroPapa = IdsDemostracion.libroPapa;
  const libroCasa = IdsDemostracion.libroCasa;

  /// El hogar de ejemplo con la categoría "Cuidados de largo plazo" bajo Salud.
  DatosFinanzas hogar({bool conCategoria = true}) {
    final d = datosDeDemostracion(hoy: hoyDePrueba);
    if (!conCategoria) return d;
    final salud = d.categorias.firstWhere((c) => c.nombre == 'Salud');
    return d.copiar(
      categorias: [
        ...d.categorias,
        Categoria(
          id: 'cat-cuidados',
          padreId: salud.id,
          nivel: 2,
          nombre: 'Cuidados de largo plazo y paliativos',
        ),
      ],
    );
  }

  GastoCuidado gasto({
    String id = 'cui-1',
    int centavos = 85050,
    bool esDePapa = true,
    EstadoGastoCuidado estado = EstadoGastoCuidado.pendienteConfirmacion,
  }) => GastoCuidado(
    id: id,
    fecha: Fecha(2026, 10, 19),
    centavos: centavos,
    registradoPor: 'cuidadora',
    concepto: 'Pañales',
    esDePapa: esDePapa,
    personaBajoCuidadoId: papa,
    estado: estado,
  );

  Movimiento pasar(
    GastoCuidado g, {
    DatosFinanzas? datos,
    String? libro,
    String? por,
  }) => gastoDeCuidadoAFinanzas(
    g,
    datos: datos ?? hogar(),
    libroId: libro ?? (g.esDePapa ? libroPapa : libroCasa),
    confirmadoPor: por ?? dueno,
    confirmadoEn: ahoraDePrueba,
  );

  group('gastoDeCuidadoAFinanzas', () {
    test('gasto de Papá: libro de Papá, en su nombre, categoría de cuidado, '
        'centavos exactos', () {
      final d = hogar();
      final m = pasar(gasto(), datos: d);
      expect(m.tipo, TipoMovimiento.gasto);
      expect(m.monto, 85050);
      expect(m.fecha, Fecha(2026, 10, 19));
      expect(m.realizadoPor, papa);
      expect(m.enNombreDe, papa);
      expect(m.registradoPor, dueno);
      expect(m.motivo, motivoGastoCuidado);
      expect(m.categoriaId, 'cat-cuidados');
      expect(m.cuentaDestinoId, d.arbol.cuentaGastoDe('cat-cuidados'));
      expect(d.cuenta(m.cuentaOrigenId)!.libroId, libroPapa);
      expect(m.nota, 'Pañales');
    });

    test(
      'el movimiento entra al libro (valida las reglas) y es idempotente',
      () {
        final d = hogar();
        final m = pasar(gasto(), datos: d);
        final libro = d.nuevoLibroHogar()..agregar(m);
        expect(libro.movimientos.where((x) => x.id == m.id), hasLength(1));
        final otra = pasar(gasto(), datos: d);
        expect(
          otra.id,
          m.id,
          reason: 'mismo gasto, mismo id (cola idempotente)',
        );
        expect(pasar(gasto(id: 'cui-2'), datos: d).id, isNot(m.id));
        expect(otra.mismoContenido(m), isTrue);
      },
    );

    test('gasto de la casa: libro compartido, a nombre de quien confirma', () {
      final m = pasar(gasto(esDePapa: false));
      expect(m.enNombreDe, isNull);
      expect(m.motivo, isNull);
      expect(m.realizadoPor, dueno);
      expect(hogar().cuenta(m.cuentaOrigenId)!.libroId, libroCasa);
    });

    test('sin categoría de cuidado queda en Por clasificar', () {
      final d = hogar(conCategoria: false);
      final m = pasar(gasto(), datos: d);
      expect(m.categoriaId, isNull);
      expect(d.cuenta(m.cuentaDestinoId)!.tipo, TipoCuenta.porClasificar);
    });

    test('solo se confirma lo pendiente y con monto positivo', () {
      for (final e in [
        EstadoGastoCuidado.confirmado,
        EstadoGastoCuidado.rechazado,
      ]) {
        expect(
          () => pasar(gasto(estado: e)),
          throwsA(isA<ErrorFinanzas>()),
          reason: '$e',
        );
      }
      expect(() => pasar(gasto(centavos: 0)), throwsA(isA<ErrorFinanzas>()));
    });

    test('solo un albacea vigente confirma el gasto de Papá', () {
      // El suplente puede (D19); la pareja de ejemplo es la suplente.
      expect(pasar(gasto(), por: pareja).registradoPor, pareja);
      expect(
        () => pasar(gasto(), por: 'cuidadora'),
        throwsA(isA<ErrorFinanzas>()),
      );
    });

    test('el gasto de Papá no va a otro libro ni a otra persona', () {
      expect(
        () => pasar(gasto(), libro: libroCasa),
        throwsA(isA<ErrorFinanzas>()),
      );
      final otro = GastoCuidado(
        id: 'x',
        fecha: Fecha(2026, 10, 19),
        centavos: 100,
        registradoPor: 'cuidadora',
        personaBajoCuidadoId: 'otra-persona',
      );
      expect(() => pasar(otro), throwsA(isA<ErrorFinanzas>()));
    });

    test('el gasto de la casa no va al libro de Papá ni a uno personal', () {
      final g = gasto(esDePapa: false);
      expect(() => pasar(g, libro: libroPapa), throwsA(isA<ErrorFinanzas>()));
      expect(
        () => pasar(g, libro: IdsDemostracion.libroDueno),
        throwsA(isA<ErrorFinanzas>()),
      );
    });
  });

  group('ResumenMensualCuidadoVista', () {
    final resumen = ResumenMensualCuidado(
      anio: 2026,
      mes: 10,
      lineas: const [
        LineaResumenCuidado('Salud', 150075),
        LineaResumenCuidado('Alimentación', 80000),
      ],
    );

    testWidgets('lista los rubros y el total', (tester) async {
      await montar(
        tester,
        Scaffold(body: ResumenMensualCuidadoVista(resumen: resumen)),
        montosVisibles: true,
      );
      expect(find.textContaining('octubre 2026'), findsOneWidget);
      expect(find.text('Salud'), findsOneWidget);
      expect(find.text('Alimentación'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('resumen-cuidado-total')),
          matching: find.textContaining('2,300.75'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('con los montos ocultos no muestra cifras', (tester) async {
      await montar(
        tester,
        Scaffold(body: ResumenMensualCuidadoVista(resumen: resumen)),
      );
      expect(find.textContaining('2,300'), findsNothing);
      expect(find.textContaining('1,500'), findsNothing);
    });

    testWidgets('mes sin gastos', (tester) async {
      await montar(
        tester,
        Scaffold(
          body: ResumenMensualCuidadoVista(
            resumen: ResumenMensualCuidado(
              anio: 2026,
              mes: 3,
              lineas: const [],
            ),
          ),
        ),
      );
      expect(find.text('Sin gastos este mes'), findsOneWidget);
    });
  });
}
