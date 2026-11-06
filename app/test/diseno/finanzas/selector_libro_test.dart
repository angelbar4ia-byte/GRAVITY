import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
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

const _publico = OpcionLibro(
  id: 'libro-publico',
  nombre: 'Viaje en familia (ejemplo)',
  tipo: TipoLibro.compartido,
  acceso: AccesoLibro.lector,
  visibilidad: VisibilidadLibro.publica,
);
const _archivado = OpcionLibro(
  id: 'libro-archivado',
  nombre: 'Boda de Eva (ejemplo)',
  tipo: TipoLibro.compartido,
  acceso: AccesoLibro.miembro,
  archivado: true,
);
const _largoArchivadoPublico = OpcionLibro(
  id: 'libro-largo-archivado',
  nombre: 'Gastos compartidos de la casa de campo de la familia (ejemplo)',
  tipo: TipoLibro.compartido,
  acceso: AccesoLibro.miembro,
  visibilidad: VisibilidadLibro.publica,
  archivado: true,
);

// Nombres largos de ejemplo, con marca: la prueba de desborde.
const _largoSoloLectura = OpcionLibro(
  id: 'libro-largo-lectura',
  nombre: 'Libro de la tía Magdalena del Carmen y familia (ejemplo)',
  tipo: TipoLibro.personal,
  acceso: AccesoLibro.soloLectura,
);
const _largoAlbacea = OpcionLibro(
  id: 'libro-largo-albacea',
  nombre: 'Papá Bartolomé de los Ángeles Fernández (ejemplo)',
  tipo: TipoLibro.representado,
  acceso: AccesoLibro.albacea,
);

/// Letra grande ([escala]) y la fuente de prueba (Ahem: cada letra mide
/// 1 em de ancho, la más ancha posible) en el texto de lectura, para forzar el
/// peor caso de ancho con cualquier nombre.
Widget _conLetraAncha(Widget hijo, {required double escala}) {
  return Builder(
    builder: (context) {
      final tema = Theme.of(context);
      final v = ValoresDiseno.de(context);
      return Theme(
        data: tema.copyWith(
          extensions: [
            ...tema.extensions.values
                .whereType<ThemeExtension<dynamic>>()
                .where((e) => e is! ValoresDiseno),
            v.copyWith(fuenteLectura: 'Ahem'),
          ],
        ),
        child: MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(escala)),
          child: hijo,
        ),
      );
    },
  );
}

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
      expect(
        _casa.descripcion,
        'Libro: Gastos de la casa, compartido, privado',
      );
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

  group('SelectorLibro sin desbordes (nombre largo y letra ancha)', () {
    // Una excepción de desborde (RenderFlex) hace fallar la prueba.
    for (final escala in [1.0, 1.5, 2.0]) {
      for (final ancho in [200.0, 260.0, 320.0, 360.0, 600.0]) {
        testWidgets('chips a $ancho dp con letra x$escala', (tester) async {
          await montarEnFinanzas(
            tester,
            _conLetraAncha(
              SelectorLibro(
                libros: const [_largoSoloLectura, _largoAlbacea],
                libroActualId: _largoSoloLectura.id,
                alCambiar: (_) {},
                comoMenu: false,
              ),
              escala: escala,
            ),
            ancho: ancho,
          );
          expect(tester.takeException(), isNull);
          // Cada chip cabe en el ancho disponible y sigue siendo tocable.
          final chips = find.descendant(
            of: find.byType(SelectorLibro),
            matching: find.byType(InkWell),
          );
          expect(chips, findsNWidgets(2));
          for (final chip in chips.evaluate()) {
            final tamano = tester.getSize(find.byWidget(chip.widget));
            expect(tamano.width, lessThanOrEqualTo(ancho));
            expect(tamano.height, greaterThanOrEqualTo(zonaTactilMinima));
          }
          // Las marcas siguen ahí, con tooltip del texto completo.
          expect(find.byTooltip('Solo lectura'), findsOneWidget);
          expect(find.byTooltip('Albacea'), findsOneWidget);
        });
      }
    }

    testWidgets('la marca se recorta con puntos suspensivos, no desborda', (
      tester,
    ) async {
      await montarEnFinanzas(
        tester,
        _conLetraAncha(
          SelectorLibro(
            libros: const [_largoSoloLectura],
            libroActualId: _largoSoloLectura.id,
            alCambiar: (_) {},
            comoMenu: false,
          ),
          escala: 2,
        ),
        ancho: 260,
      );
      expect(tester.takeException(), isNull);
      final marca = tester.widget<Text>(find.text('Solo lectura'));
      expect(marca.overflow, TextOverflow.ellipsis);
      expect(marca.maxLines, 1);
      final etiqueta = tester.widget<Text>(
        find.text(_largoSoloLectura.etiqueta),
      );
      expect(etiqueta.overflow, TextOverflow.ellipsis);
      // Lo visible se recorta, el texto no pierde nada.
      expect(
        tester
            .renderObject<RenderParagraph>(find.text(marca.data!))
            .didExceedMaxLines,
        isTrue,
      );
      expect(marca.data, 'Solo lectura');
    });

    testWidgets('si nombre y marca caben juntos, ninguno se recorta', (
      tester,
    ) async {
      // En las pruebas el texto de lectura mide 1 em por letra (fuente de
      // prueba): nombre 196 dp + marca 114 dp + separaciones y relleno del
      // chip. Con 380 dp caben apenas; un reparto por mitades recortaría el
      // nombre aunque quepa, el proporcional no recorta nada.
      await montarEnFinanzas(
        tester,
        SelectorLibro(
          libros: const [_papa],
          libroActualId: _papa.id,
          alCambiar: (_) {},
          comoMenu: false,
        ),
        ancho: 380,
      );
      expect(tester.takeException(), isNull);
      for (final texto in ['Papá (ejemplo)', 'Albacea']) {
        expect(
          tester
              .renderObject<RenderParagraph>(find.text(texto))
              .didExceedMaxLines,
          isFalse,
          reason: '"$texto" se recortó aunque cabe',
        );
      }
    });

    testWidgets('semántica completa aunque se recorte lo visible', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await montarEnFinanzas(
        tester,
        _conLetraAncha(
          SelectorLibro(
            libros: const [_largoSoloLectura, _largoAlbacea],
            libroActualId: _largoSoloLectura.id,
            alCambiar: (_) {},
            comoMenu: false,
          ),
          escala: 2,
        ),
        ancho: 260,
      );
      expect(tester.takeException(), isNull);
      expect(
        _largoSoloLectura.descripcion,
        'Libro: ${_largoSoloLectura.nombre}, solo lectura',
      );
      expect(
        find.bySemanticsLabel(_largoSoloLectura.descripcion),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(_largoAlbacea.descripcion), findsOneWidget);
      semantica.dispose();
    });

    for (final escala in [1.0, 2.0]) {
      testWidgets('menú con nombres largos y letra x$escala', (tester) async {
        await montarEnFinanzas(
          tester,
          _conLetraAncha(
            SelectorLibro(
              libros: const [_mio, _largoSoloLectura, _largoAlbacea],
              libroActualId: _largoAlbacea.id,
              alCambiar: (_) {},
              comoMenu: true,
            ),
            escala: escala,
          ),
          ancho: 360,
        );
        expect(tester.takeException(), isNull);
        // El botón del menú cabe en el ancho y conserva la marca.
        final boton = find.descendant(
          of: find.byType(SelectorLibro),
          matching: find.byType(InkWell),
        );
        expect(tester.getSize(boton).width, lessThanOrEqualTo(360));
        expect(find.byTooltip('Albacea'), findsOneWidget);

        await tester.tap(boton);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // Las tres opciones del menú, con la marca de cada una.
        expect(find.byTooltip('Solo lectura'), findsOneWidget);
        expect(find.byTooltip('Albacea'), findsNWidgets(2));
      });
    }
  });

  group('Pública, Privada y Archivado (D19, 23/oct)', () {
    test('los compartidos son privados por omisión y llevan su marca', () {
      expect(_casa.visibilidad, VisibilidadLibro.privada);
      expect(_casa.marcaVisibilidad, 'Privada');
      expect(_publico.marcaVisibilidad, 'Pública');
      // Solo los compartidos tienen visibilidad.
      expect(_mio.marcaVisibilidad, isNull);
      expect(_papa.marcaVisibilidad, isNull);
      expect(_deAna.marcaVisibilidad, isNull);
      expect([for (final m in _casa.marcas) m.texto], ['Privada']);
      expect(
        [for (final m in _publico.marcas) m.texto],
        ['Pública', 'Solo lectura'],
      );
      // Siempre texto además del icono, y distintos entre sí.
      expect(
        VisibilidadLibro.privada.icono,
        isNot(VisibilidadLibro.publica.icono),
      );
    });

    test('archivado: solo lectura para todos, con su marca', () {
      expect(_archivado.archivado, isTrue);
      expect(_archivado.sinEscritura, isTrue);
      // No es el "solo lectura" de la cuenta maestra.
      expect(_archivado.soloLectura, isFalse);
      expect(_archivado.marca, 'Archivado');
      expect(
        [for (final m in _archivado.marcas) m.texto],
        ['Privada', 'Archivado'],
      );
      expect(
        _archivado.descripcion,
        'Libro: Boda de Eva (ejemplo), compartido, privado, archivado, '
        'solo lectura',
      );
      // Un archivado que además se lee por acceso no repite la marca.
      const maestraEnArchivado = OpcionLibro(
        id: 'x',
        nombre: 'Viejo (ejemplo)',
        tipo: TipoLibro.compartido,
        acceso: AccesoLibro.soloLectura,
        archivado: true,
      );
      expect(
        [for (final m in maestraEnArchivado.marcas) m.texto],
        ['Privada', 'Archivado'],
      );
    });

    test('lector de un público: solo lee, no es la cuenta maestra', () {
      expect(_publico.soloLectura, isTrue);
      expect(_publico.sinEscritura, isTrue);
      expect(_publico.marca, 'Solo lectura');
      expect(
        _publico.descripcion,
        'Libro: Viaje en familia (ejemplo), compartido, público, solo lectura',
      );
      expect(_casa.sinEscritura, isFalse);
      expect(_mio.sinEscritura, isFalse);
      expect(_papa.sinEscritura, isFalse);
    });

    test('igualdad incluye visibilidad y archivado', () {
      expect(
        _casa,
        const OpcionLibro(
          id: 'libro-casa',
          nombre: 'Gastos de la casa',
          tipo: TipoLibro.compartido,
          acceso: AccesoLibro.miembro,
        ),
      );
      expect(
        _casa,
        isNot(
          const OpcionLibro(
            id: 'libro-casa',
            nombre: 'Gastos de la casa',
            tipo: TipoLibro.compartido,
            acceso: AccesoLibro.miembro,
            visibilidad: VisibilidadLibro.publica,
          ),
        ),
      );
      expect(
        _casa,
        isNot(
          const OpcionLibro(
            id: 'libro-casa',
            nombre: 'Gastos de la casa',
            tipo: TipoLibro.compartido,
            acceso: AccesoLibro.miembro,
            archivado: true,
          ),
        ),
      );
    });

    testWidgets('chips: marca con texto, icono y tooltip; archivado', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await montarEnFinanzas(
        tester,
        SelectorLibro(
          libros: const [_mio, _casa, _publico, _archivado],
          libroActualId: _mio.id,
          alCambiar: (_) {},
          comoMenu: false,
        ),
        ancho: 900,
      );
      expect(find.text('Privada'), findsNWidgets(2)); // _casa y _archivado
      expect(find.text('Pública'), findsOneWidget);
      expect(find.text('Archivado'), findsOneWidget);
      expect(
        find.text('Solo lectura'),
        findsOneWidget,
      ); // el lector del público
      expect(find.byIcon(Icons.lock_person_outlined), findsNWidgets(2));
      expect(find.byIcon(Icons.public), findsOneWidget);
      expect(find.byIcon(Icons.archive_outlined), findsOneWidget);
      expect(
        find.byTooltip(VisibilidadLibro.publica.explicacion),
        findsOneWidget,
      );
      expect(
        find.byTooltip(VisibilidadLibro.privada.explicacion),
        findsNWidgets(2),
      );
      // El lector de pantalla dice todo en una frase.
      expect(
        find.bySemanticsLabel(
          'Libro: Boda de Eva (ejemplo), compartido, privado, archivado, '
          'solo lectura',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Libro: Viaje en familia (ejemplo), compartido, público, '
          'solo lectura',
        ),
        findsOneWidget,
      );
      revisarZonasTactiles(tester, find.byType(SelectorLibro));
      expect(tester.takeException(), isNull);
      semantica.dispose();
    });

    testWidgets('menú: las marcas también salen en las opciones', (
      tester,
    ) async {
      await montarEnFinanzas(
        tester,
        SelectorLibro(
          libros: const [_mio, _casa, _publico, _archivado],
          libroActualId: _casa.id,
          alCambiar: (_) {},
          comoMenu: true,
        ),
      );
      // El botón lleva la marca del libro abierto.
      expect(find.text('Privada'), findsOneWidget);
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      expect(find.text('Privada'), findsNWidgets(3));
      expect(find.text('Pública'), findsOneWidget);
      expect(find.text('Archivado'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final escala in [1.0, 2.0]) {
      for (final ancho in [260.0, 360.0, 600.0]) {
        testWidgets(
          'dos marcas con nombre largo a $ancho dp y letra x$escala no '
          'desbordan',
          (tester) async {
            await montarEnFinanzas(
              tester,
              _conLetraAncha(
                SelectorLibro(
                  libros: const [_largoArchivadoPublico, _largoSoloLectura],
                  libroActualId: _largoArchivadoPublico.id,
                  alCambiar: (_) {},
                  comoMenu: false,
                ),
                escala: escala,
              ),
              ancho: ancho,
            );
            expect(tester.takeException(), isNull);
            for (final chip
                in find
                    .descendant(
                      of: find.byType(SelectorLibro),
                      matching: find.byType(InkWell),
                    )
                    .evaluate()) {
              expect(
                tester.getSize(find.byWidget(chip.widget)).width,
                lessThanOrEqualTo(ancho),
              );
            }
            // Las dos marcas del compartido siguen ahí, con su tooltip.
            expect(
              find.byTooltip(VisibilidadLibro.publica.explicacion),
              findsOneWidget,
            );
          },
        );
      }
    }

    testWidgets('MarcaLibro: archivado y lector de un público', (tester) async {
      final semantica = tester.ensureSemantics();
      await montarEnFinanzas(tester, const MarcaLibro(libro: _archivado));
      expect(
        find.textContaining('Archivado', findRichText: true),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.archive_outlined), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Archivado, solo lectura: ya no se puede registrar en este libro',
        ),
        findsOneWidget,
      );
      await montarEnFinanzas(tester, const MarcaLibro(libro: _publico));
      expect(
        find.textContaining('Solo lectura', findRichText: true),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Solo lectura, libro público: puedes ver, no registrar',
        ),
        findsOneWidget,
      );
      // La cuenta maestra conserva su texto.
      await montarEnFinanzas(tester, const MarcaLibro(libro: _deAna));
      expect(
        find.bySemanticsLabel(
          'Solo lectura, cuenta maestra: puedes ver, no registrar',
        ),
        findsOneWidget,
      );
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
