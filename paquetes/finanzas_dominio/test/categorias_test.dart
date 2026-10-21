// Árbol de categorías e importador de la hoja Categorías (5.2; 10, MVP 1).
import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:test/test.dart';

/// Primeras filas de la hoja Categorías de
/// `data/DATOS_SEMILLA_PRESUPUESTO.xlsx` (mismas columnas), en CSV.
const csvSemilla =
    '﻿'
    'Categoría (nivel 1),Subcategoría (nivel 2),Detalle (nivel 3),'
    'Naturaleza típica,Notas o ejemplos,Cuenta de gasto\r\n'
    'Vivienda y servicios,,,Fija,,Sí (por defecto)\r\n'
    'Vivienda y servicios,Renta o hipoteca,,Fija,,\r\n'
    'Vivienda y servicios,Luz,,Fija,,\r\n'
    'Alimentación,,,Variable (ver 5.8),,Sí (por defecto)\r\n'
    'Alimentación,Despensa y abarrotes,,Variable (ver 5.8),,\r\n'
    'Salud,,,Recurrente y eventual,,Sí (por defecto)\r\n'
    'Salud,Cuidados de largo plazo y paliativos,,Recurrente y eventual,,'
    'Puede promoverse a cuenta propia\r\n'
    'Salud,Cuidados de largo plazo y paliativos,Insumos de cuidado diario,'
    'Recurrente y eventual,"Pañales para adulto, protectores, cremas",\r\n'
    'Entretenimiento,,,Discrecional,,Sí (por defecto)\r\n'
    'Entretenimiento,Streaming y suscripciones,,Discrecional,,\r\n'
    'Limpieza y mantenimiento del hogar,Reparaciones,,Mixta,'
    '"plomería, electricidad, pintura",\r\n'
    ',,,,,\r\n';

void main() {
  var siguiente = 0;
  String generarId() => 'id-${siguiente++}';
  setUp(() => siguiente = 0);

  group('CSV', () {
    test('comillas, comas dentro de comillas, BOM y fin de línea \\r\\n', () {
      final t = leerCsv(csvSemilla);
      expect(t.first.first, 'Categoría (nivel 1)');
      expect(t[8][4], 'Pañales para adulto, protectores, cremas');
      expect(t.length, 13);
    });

    test('separador punto y coma y comillas escapadas', () {
      final t = leerCsv('a;b\n"x ""y""";z\n');
      expect(t, [
        ['a', 'b'],
        ['x "y"', 'z'],
      ]);
    });
  });

  group('Lectura de la hoja', () {
    test('lee las filas, salta las vacías y valida niveles', () {
      final l = leerPlantillaCategorias([
        ...leerCsv(csvSemilla),
        ['', 'Sin padre', '', '', '', ''],
        ['Salud', '', 'Detalle sin sub', '', '', ''],
      ]);
      expect(l.filas, hasLength(11));
      expect(l.omitidas.map((o) => o.motivo), [
        'Falta la categoría de nivel 1',
        'Un detalle necesita su subcategoría',
      ]);
      expect(l.filasLeidas, 13);
    });

    test('sin la columna de nivel 1 avisa que no es la hoja Categorías', () {
      expect(
        () => leerPlantillaCategorias([
          ['Producto', 'Precio'],
        ]),
        throwsA(isA<ErrorPlantilla>()),
      );
    });
  });

  group('Importar (criterio 29)', () {
    test('crea el árbol de 3 niveles con naturaleza y cuenta de gasto', () {
      final plan = planearImportacionCategorias(
        leerPlantillaCategorias(leerCsv(csvSemilla)),
        generarId: generarId,
      );
      final arbol = ArbolCategorias(plan.nuevas);
      final niveles1 = arbol.hijas(null).map((c) => c.nombre).toList();
      expect(niveles1, [
        'Alimentación',
        'Entretenimiento',
        'Limpieza y mantenimiento del hogar',
        'Salud',
        'Vivienda y servicios',
      ]);
      // Una cuenta de gasto del hogar por cada categoría principal.
      expect(plan.cuentasNuevas, hasLength(5));
      expect(
        plan.cuentasNuevas.every((c) => c.tipo == TipoCuenta.deGasto),
        isTrue,
      );
      expect(plan.cuentasNuevas.every((c) => c.libroId == null), isTrue);
      final salud = arbol.buscar('salud')!;
      expect(salud.cuentaGastoId, isNotNull);
      final cuidados = arbol.buscar(
        'Cuidados de largo plazo y paliativos',
        padreId: salud.id,
      )!;
      final insumos = arbol.hijas(cuidados.id).single;
      expect(insumos.nivel, 3);
      expect(
        arbol.ruta(insumos.id),
        'Salud › Cuidados de largo plazo y paliativos › Insumos de cuidado '
        'diario',
      );
      expect(arbol.cuentaGastoDe(insumos.id), salud.cuentaGastoId);
      expect(insumos.naturaleza, 'Recurrente y eventual');
      expect(plan.omitidas, isEmpty);
      expect(plan.filasCreadas, 11);
    });

    test('protegidas y prioridades sugeridas (interpretación, P12)', () {
      final plan = planearImportacionCategorias(
        leerPlantillaCategorias(leerCsv(csvSemilla)),
        generarId: generarId,
      );
      final arbol = ArbolCategorias(plan.nuevas);
      Categoria por(String nombre) =>
          plan.nuevas.firstWhere((c) => c.nombre == nombre);
      expect(por('Renta o hipoteca').protegida, isTrue);
      expect(por('Insumos de cuidado diario').protegida, isTrue);
      expect(por('Despensa y abarrotes').protegida, isFalse);
      expect(
        por('Streaming y suscripciones').prioridad,
        Prioridad.discrecional,
      );
      expect(por('Luz').prioridad, Prioridad.necesario);
      expect(por('Reparaciones').prioridad, Prioridad.deseable);
      // "Limpieza…" no venía como fila propia: se creó al ver su subcategoría.
      expect(arbol.buscar('Limpieza y mantenimiento del hogar'), isNotNull);
    });

    test('reimportar no duplica', () {
      final lectura = leerPlantillaCategorias(leerCsv(csvSemilla));
      final primera = planearImportacionCategorias(
        lectura,
        generarId: generarId,
      );
      final segunda = planearImportacionCategorias(
        lectura,
        existentes: primera.nuevas,
        cuentasExistentes: primera.cuentasNuevas,
        generarId: generarId,
      );
      expect(segunda.sinCambios, isTrue);
      expect(segunda.omitidas.every((o) => o.motivo == 'Ya existe'), isTrue);
      expect(segunda.omitidas, hasLength(lectura.filas.length));
    });

    test('ignora acentos y mayúsculas al comparar y avisa repetidas', () {
      final lectura = leerPlantillaCategorias([
        ['Categoría (nivel 1)', 'Subcategoría (nivel 2)'],
        ['Salud', ''],
        ['SALUD', 'Médico'],
        ['salud', 'medico'],
      ]);
      final plan = planearImportacionCategorias(lectura, generarId: generarId);
      expect(plan.nuevas.map((c) => c.nombre), ['Salud', 'Médico']);
      expect(plan.omitidas.single.motivo, 'Repetida en el archivo');
    });

    test('liga una cuenta de gasto que ya existe con ese nombre', () {
      const existente = Cuenta(
        id: 'g-salud',
        nombre: 'Salud',
        tipo: TipoCuenta.deGasto,
      );
      final plan = planearImportacionCategorias(
        leerPlantillaCategorias([
          ['Categoría (nivel 1)'],
          ['Salud'],
        ]),
        cuentasExistentes: [existente],
        generarId: generarId,
      );
      expect(plan.cuentasNuevas, isEmpty);
      expect(plan.nuevas.single.cuentaGastoId, 'g-salud');
    });
  });
}
