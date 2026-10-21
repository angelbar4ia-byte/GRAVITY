import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';

import 'ayuda_finanzas.dart';

// Datos de ejemplo (nunca nombres reales).
const _mio = OpcionLibro(
  id: 'libro-alex',
  nombre: 'Libro de Alex',
  tipo: TipoLibro.personal,
);
const _casa = OpcionLibro(
  id: 'libro-casa',
  nombre: 'Gastos de la casa',
  tipo: TipoLibro.compartido,
  acceso: AccesoLibro.miembro,
);
const _papa = OpcionLibro(
  id: 'libro-papa',
  nombre: 'Papá (ejemplo)',
  tipo: TipoLibro.representado,
  acceso: AccesoLibro.albacea,
);
const _deAna = OpcionLibro(
  id: 'libro-ana',
  nombre: 'Libro de Ana',
  tipo: TipoLibro.personal,
  acceso: AccesoLibro.soloLectura,
);

void main() {
  group('OpcionLibro', () {
    test('"Mi libro" solo en el personal propio', () {
      expect(_mio.etiqueta, 'Mi libro');
      expect(_deAna.etiqueta, 'Libro de Ana');
      expect(_casa.etiqueta, 'Gastos de la casa');
      expect(_papa.etiqueta, 'Papá (ejemplo)');
    });

    test('marcas: solo lectura (maestra) y en nombre de (albacea)', () {
      expect(_deAna.soloLectura, isTrue);
      expect(_deAna.marca, 'Solo lectura');
      expect(_papa.enNombreDe, isTrue);
      expect(_papa.marca, 'Albacea');
      expect(_mio.marca, isNull);
      expect(_casa.marca, isNull);
      // La maestra en un representado solo lee: no actúa en su nombre.
      const maestraEnPapa = OpcionLibro(
        id: 'libro-papa',
        nombre: 'Papá (ejemplo)',
        tipo: TipoLibro.representado,
        acceso: AccesoLibro.soloLectura,
      );
      expect(maestraEnPapa.enNombreDe, isFalse);
      expect(maestraEnPapa.soloLectura, isTrue);
    });

    test('lo que dice el lector de pantalla', () {
      expect(_mio.descripcion, 'Libro: Mi libro');
      expect(_casa.descripcion, 'Libro: Gastos de la casa, compartido');
      expect(
        _papa.descripcion,
        'Libro: Papá (ejemplo), en nombre de Papá (ejemplo)',
      );
      expect(_deAna.descripcion, 'Libro: Libro de Ana, solo lectura');
    });
  });

  group('SelectorLibro como chips', () {
    testWidgets('icono por tipo, marca con texto y palomita en el elegido', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      final cambios = <String>[];
      await montarEnFinanzas(
        tester,
        SelectorLibro(
          libros: const [_mio, _casa, _papa],
          libroActualId: _mio.id,
          alCambiar: cambios.add,
        ),
        ancho: 600,
      );
      expect(find.text('Mi libro'), findsOneWidget);
      expect(find.text('Gastos de la casa'), findsOneWidget);
      expect(find.text('Papá (ejemplo)'), findsOneWidget);
      expect(find.text('Albacea'), findsOneWidget);
      // El elegido lleva palomita; los demás, el icono de su tipo.
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byIcon(Icons.group_outlined), findsOneWidget);
      expect(find.byIcon(Icons.volunteer_activism_outlined), findsOneWidget);
      expect(find.byType(MenuAnchor), findsNothing);

      expect(
        tester.getSemantics(find.bySemanticsLabel('Libro: Mi libro')),
        isSemantics(
          isSelected: true,
          isButton: true,
          isInMutuallyExclusiveGroup: true,
        ),
      );
      final papa = find.bySemanticsLabel(
        'Libro: Papá (ejemplo), en nombre de Papá (ejemplo)',
      );
      expect(
        tester.getSemantics(papa),
        isSemantics(isSelected: false, hasTapAction: true),
      );

      revisarZonasTactiles(tester, find.byType(SelectorLibro));

      await tester.tap(find.text('Papá (ejemplo)'));
      await tester.tap(find.text('Mi libro')); // ya es el actual: no avisa
      expect(cambios, ['libro-papa']);
      semantica.dispose();
    });

    testWidgets('la cuenta maestra ve "Solo lectura" en los ajenos', (
      tester,
    ) async {
      await montarEnFinanzas(
        tester,
        SelectorLibro(
          libros: const [_mio, _deAna],
          libroActualId: _deAna.id,
          alCambiar: (_) {},
        ),
        ancho: 600,
      );
      expect(find.text('Solo lectura'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });
  });

  group('SelectorLibro como menú', () {
    testWidgets('automático con más de 4 libros o poco ancho', (tester) async {
      await montarEnFinanzas(
        tester,
        SelectorLibro(
          libros: const [_mio, _casa, _papa],
          libroActualId: _casa.id,
          alCambiar: (_) {},
        ),
        ancho: 300,
      );
      expect(find.byType(MenuAnchor), findsOneWidget);

      await montarEnFinanzas(
        tester,
        SelectorLibro(
          libros: [
            _mio,
            _casa,
            _papa,
            _deAna,
            const OpcionLibro(
              id: 'libro-otro',
              nombre: 'Viaje (ejemplo)',
              tipo: TipoLibro.compartido,
              acceso: AccesoLibro.miembro,
            ),
          ],
          libroActualId: _casa.id,
          alCambiar: (_) {},
        ),
        ancho: 800,
      );
      expect(find.byType(MenuAnchor), findsOneWidget);
    });

    testWidgets('abre, muestra las marcas y elige', (tester) async {
      final semantica = tester.ensureSemantics();
      final cambios = <String>[];
      await montarEnFinanzas(
        tester,
        SelectorLibro(
          libros: const [_mio, _casa, _papa, _deAna],
          libroActualId: _mio.id,
          alCambiar: cambios.add,
          comoMenu: true,
        ),
      );
      // El botón dice qué libro está abierto.
      expect(find.text('Mi libro'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Libro: Mi libro')),
        isSemantics(isButton: true, hasTapAction: true),
      );
      revisarZonasTactiles(tester, find.byType(SelectorLibro));

      await tester.tap(find.text('Mi libro'));
      await tester.pumpAndSettle();
      expect(find.text('Gastos de la casa'), findsOneWidget);
      expect(find.text('Albacea'), findsOneWidget);
      expect(find.text('Solo lectura'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.tap(find.text('Libro de Ana'));
      await tester.pumpAndSettle();
      expect(cambios, ['libro-ana']);
      semantica.dispose();
    });
  });

  group('MarcaLibro', () {
    testWidgets('albacea: "En nombre de" con icono y texto', (tester) async {
      final semantica = tester.ensureSemantics();
      await montarEnFinanzas(tester, const MarcaLibro(libro: _papa));
      expect(
        find.text(
          'En nombre de Papá (ejemplo) · cada movimiento pide motivo y queda '
          'en la bitácora',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.draw_outlined), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'En nombre de Papá (ejemplo), cada movimiento pide motivo y queda '
          'en la bitácora',
        ),
        findsOneWidget,
      );
      semantica.dispose();
    });

    testWidgets('cuenta maestra: "Solo lectura"', (tester) async {
      await montarEnFinanzas(tester, const MarcaLibro(libro: _deAna));
      expect(
        find.text(
          'Solo lectura · cuenta maestra: puedes ver, no registrar',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      final v = valoresDe(tester, find.byType(MarcaLibro));
      expect(
        razonContraste(v.textoFuerte, v.chipSeleccionado),
        greaterThanOrEqualTo(contrasteMinimoTexto),
      );
    });

    testWidgets('en el libro propio o compartido no dibuja nada', (
      tester,
    ) async {
      for (final libro in [_mio, _casa]) {
        await montarEnFinanzas(tester, MarcaLibro(libro: libro));
        expect(find.byType(Icon), findsNothing);
        expect(find.byType(Text), findsNothing);
      }
    });
  });
}
