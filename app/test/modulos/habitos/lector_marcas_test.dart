import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/habitos/casos_uso/servicio_diario.dart';
import 'package:gravity/modulos/habitos/casos_uso/servicio_lectura.dart';
import 'package:gravity/modulos/habitos/datos/biblia.dart';
import 'package:gravity/modulos/habitos/datos/documentos_sensibles.dart';
import 'package:gravity/modulos/habitos/datos/repositorio_agenda.dart';
import 'package:gravity/modulos/habitos/estado/proveedores.dart';
import 'package:gravity/modulos/habitos/pantallas/lector.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/nucleo/sensibles/llaves_habitos.dart';
import 'package:gravity/nucleo/sensibles/sobres.dart';
import 'package:gravity/nucleo/sensibles/subida_diferida.dart';
import 'package:habitos_dominio/habitos_dominio.dart';

// Fase 4, E8 / criterio 32. Texto FICTICIO: valida el formato, no es ninguna
// versión de la Biblia.
BibliaJson biblia(String id) => BibliaJson.deMapa({
  'formato': 'gravity-biblia-v1',
  'version': id,
  'nombre': 'Prueba $id',
  'licencia': 'ficticia',
  'origen': 'ficticio',
  'libros': [
    for (var i = 0; i < 66; i++)
      [
        for (var c = 0; c < canon[i].capitulos; c++)
          ['$id uno de ${i + 1}:${c + 1}', '$id dos de ${i + 1}:${c + 1}'],
      ],
  ],
});

void main() {
  late RepositorioAgendaEnMemoria repo;
  late ServicioMarcas marcas;

  setUp(() {
    repo = RepositorioAgendaEnMemoria();
    marcas = ServicioMarcas(repo, ahora: () => DateTime.utc(2026, 11, 6, 9));
  });

  group('subrayados y marcadores', () {
    test('seis colores; cambiar de color no duplica', () async {
      expect(coloresSubrayado.length, 6);
      for (final c in coloresSubrayado) {
        await marcas.subrayar(43, 3, 16, c);
      }
      final l = await marcas.delCapitulo(43, 3);
      expect(l.length, 1);
      expect(l.single.color, 'morado');
      expect(l.single.referencia, '43:3:16');
      expect(l.single.aFila().containsKey('texto'), isFalse); // sin texto libre
    });

    test('color inexistente se rechaza; quitar subrayado', () async {
      await expectLater(
        marcas.subrayar(43, 3, 16, 'negro'),
        throwsArgumentError,
      );
      await marcas.subrayar(43, 3, 16, 'verde');
      await marcas.quitarSubrayado(43, 3, 16);
      expect(await marcas.delCapitulo(43, 3), isEmpty);
    });

    test(
      'el marcador se alterna y no lleva color; subrayado y marcador conviven',
      () async {
        expect(await marcas.alternarMarcador(19, 23, 1), isTrue);
        await marcas.subrayar(19, 23, 1, 'azul');
        var l = await marcas.delCapitulo(19, 23);
        expect(l.length, 2);
        expect(l.where((m) => !m.esSubrayado).single.color, isNull);
        expect(await marcas.alternarMarcador(19, 23, 1), isFalse);
        l = await marcas.delCapitulo(19, 23);
        expect(l.single.esSubrayado, isTrue);
      },
    );

    test('las marcas son por capítulo', () async {
      await marcas.subrayar(43, 3, 16, 'rosa');
      await marcas.subrayar(43, 4, 1, 'rosa');
      expect((await marcas.delCapitulo(43, 3)).length, 1);
      expect((await marcas.delCapitulo(43, 30)).length, 0);
    });
  });

  group('notas (cifradas y sensibles)', () {
    late AlmacenSeguroEnMemoria almacen;
    late ServicioDiario d;
    late DateTime ahora;
    setUp(() {
      almacen = AlmacenSeguroEnMemoria();
      ahora = DateTime.utc(2026, 11, 6, 9);
      d = ServicioDiario(
        DocumentosSensibles(
          llaves: LlavesHabitos(almacen),
          sobres: AlmacenDeSobres(almacen),
          modos: ModosLocales(almacen),
          persona: 'ana',
          ahora: () => ahora,
        ),
        ahora: () => ahora,
      );
    });

    test('la nota va por referencia, cifrada, y no depende del día ni de la versión', () async {
      await d.guardarNota('43:3:16', 'NOTA_PRIVADA_UNO', version: 'rvr1909');
      await d.guardarNota('43:3:17', 'otra nota');
      await d.guardarNota('43:4:1', 'de otro capítulo');
      final n = await d.notasDeCapitulo(43, 3);
      expect(n[16], 'NOTA_PRIVADA_UNO');
      expect(n.length, 2);
      // misma referencia con otra versión: reemplaza, no duplica
      ahora = ahora.add(const Duration(minutes: 1)); // el último cambio gana
      await d.guardarNota('43:3:16', 'NOTA_PRIVADA_DOS', version: 'kjv');
      expect((await d.notasDeCapitulo(43, 3))[16], 'NOTA_PRIVADA_DOS');
      expect((await d.notasDeCapitulo(43, 3)).length, 2);
      expect(almacen.datos.values.join(), isNot(contains('NOTA_PRIVADA')));
    });

    test('texto vacío quita la nota; referencia mala se rechaza', () async {
      await d.guardarNota('19:23:1', 'x');
      ahora = ahora.add(const Duration(minutes: 1));
      await d.guardarNota('19:23:1', '   ');
      expect(await d.notasDeCapitulo(19, 23), isEmpty);
      await expectLater(d.guardarNota('mal', 'x'), throwsArgumentError);
      await expectLater(
        d.guardarNota('19:23:1', 'x' * 4001),
        throwsArgumentError,
      );
    });
  });

  Future<void> montar(WidgetTester t, List<ProveedorBiblia> biblias) =>
      t.pumpWidget(
        ProviderScope(
          overrides: [
            servicioSesionProvider.overrideWithValue(ServicioSesionFalso()),
            repositorioAgendaProvider.overrideWithValue(repo),
            bibliasProvider.overrideWith((ref) async => biblias),
          ],
          child: const MaterialApp(home: PantallaLector()),
        ),
      );

  testWidgets(
    'el lector subraya un versículo y lo conserva al cambiar de versión',
    (t) async {
      final sem = t.ensureSemantics();
      await montar(t, [biblia('rvr1909'), biblia('kjv')]);
      await t.pumpAndSettle();
      expect(
        find.textContaining('rvr1909 uno de 43:1', findRichText: true),
        findsOneWidget,
      );
      await t.tap(
        find.textContaining('rvr1909 uno de 43:1', findRichText: true),
      );
      await t.pumpAndSettle();
      expect(find.text('Subrayar'), findsOneWidget);
      for (final c in coloresSubrayado) {
        expect(
          find.text(nombreColor(c)),
          findsOneWidget,
        ); // seis colores, con su nombre
      }
      await t.tap(find.text('Amarillo'));
      await t.pumpAndSettle();
      expect((await marcas.delCapitulo(43, 1)).single.color, 'amarillo');
      expect(
        find.bySemanticsLabel(RegExp('Versículo 1, subrayado')),
        findsOneWidget,
      );
      expect(
        find.text('Versículo 1 · subrayado amarillo'),
        findsOneWidget,
      ); // en palabras
      // otra versión: la marca sigue en el mismo versículo
      await t.tap(find.text('KJV'));
      await t.pumpAndSettle();
      expect(
        find.textContaining('kjv uno de 43:1', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('Versículo 1, subrayado')),
        findsOneWidget,
      );
      sem.dispose();
    },
  );

  testWidgets('quitar subrayado y poner marcador desde la hoja', (t) async {
    await marcas.subrayar(43, 1, 2, 'verde');
    await montar(t, [biblia('rvr1909')]);
    await t.pumpAndSettle();
    await t.tap(find.textContaining('rvr1909 dos de 43:1', findRichText: true));
    await t.pumpAndSettle();
    expect(find.text('Escribir una nota'), findsOneWidget);
    expect(
      find.text('Reservada: se pide tu PIN'),
      findsOneWidget,
    ); // las notas no se escriben aquí
    await t.tap(find.text('Quitar subrayado'));
    await t.pumpAndSettle();
    expect(await marcas.delCapitulo(43, 1), isEmpty);
    await t.tap(find.textContaining('rvr1909 dos de 43:1', findRichText: true));
    await t.pumpAndSettle();
    await t.tap(find.byType(SwitchListTile));
    await t.pumpAndSettle();
    expect((await marcas.delCapitulo(43, 1)).single.esSubrayado, isFalse);
    expect(find.text('Versículo 2 · marcador'), findsOneWidget);
  });

  testWidgets(
    'sin texto instalado, el lector dice qué falta y a quién avisar (E18)',
    (t) async {
      await montar(t, const []);
      await t.pumpAndSettle();
      expect(find.text('Aún no hay texto bíblico'), findsOneWidget);
      expect(find.text(mensajeSinTexto), findsOneWidget);
      expect(mensajeSinTexto, contains('Avísale'));
    },
  );

  test('los colores de muestra salen del tema y son distintos', () {
    // seis tonos distintos, siempre con nombre
    expect({for (final c in coloresSubrayado) c}.length, 6);
    expect(nombreColor('amarillo'), 'Amarillo');
  });
}
