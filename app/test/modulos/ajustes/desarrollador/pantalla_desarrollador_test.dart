import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/ajustes/desarrollador/abrir_swagger.dart';
import 'package:gravity/modulos/ajustes/desarrollador/operaciones.g.dart';
import 'package:gravity/modulos/ajustes/desarrollador/pantalla_desarrollador.dart';

Widget _app(Widget pantalla) => MaterialApp(home: Scaffold(body: pantalla));

void main() {
  test('las instrucciones sirven api/ solo en este equipo (M11)', () {
    expect(instruccionesSwagger, contains('-a 127.0.0.1'));
    expect(instruccionesSwagger, contains('http://127.0.0.1:8080/'));
  });

  group('ubicarSwagger', () {
    test('una dirección http se usa tal cual', () {
      final u = ubicarSwagger(
        rutaConfigurada: 'http://127.0.0.1:8080/swagger/index.html',
        directorioActual: '/x',
        existe: (_) => false,
      );
      expect(
        (u as SwaggerEncontrado).uri.toString(),
        'http://127.0.0.1:8080/swagger/index.html',
      );
    });

    test('una ruta de Windows configurada que existe', () {
      const ruta = r'C:\repos\gravity\api\swagger\index.html';
      final u = ubicarSwagger(
        rutaConfigurada: ruta,
        directorioActual: r'C:\repos\gravity\app',
        existe: (r) => r == ruta,
      );
      expect(
        (u as SwaggerEncontrado).uri.toString(),
        'file:///C:/repos/gravity/api/swagger/index.html',
      );
    });

    test('una dirección file:// de Windows', () {
      final u = ubicarSwagger(
        rutaConfigurada: 'file:///C:/repos/gravity/api/swagger/index.html',
        directorioActual: '/x',
        existe: (r) => r == r'C:\repos\gravity\api\swagger\index.html',
      );
      expect(
        (u as SwaggerEncontrado).uri.toString(),
        'file:///C:/repos/gravity/api/swagger/index.html',
      );
    });

    test('una ruta configurada que no existe', () {
      final u = ubicarSwagger(
        rutaConfigurada: '/no/existe/index.html',
        directorioActual: '/x',
        existe: (_) => false,
      );
      expect(
        (u as SwaggerNoEncontrado).rutaConfigurada,
        '/no/existe/index.html',
      );
    });

    test('sin configurar, la busca junto a app/ o en la raíz', () {
      final desdeApp = ubicarSwagger(
        rutaConfigurada: '',
        directorioActual: '/repos/gravity/app',
        existe: (r) => r == '/repos/gravity/app/../api/swagger/index.html',
      );
      expect(
        (desdeApp as SwaggerEncontrado).uri.toString(),
        'file:///repos/gravity/api/swagger/index.html',
      );
      final desdeRaiz = ubicarSwagger(
        rutaConfigurada: '',
        directorioActual: r'C:\repos\gravity',
        existe: (r) => r == r'C:\repos\gravity\api\swagger\index.html',
      );
      expect(
        (desdeRaiz as SwaggerEncontrado).uri.toString(),
        'file:///C:/repos/gravity/api/swagger/index.html',
      );
      final nada = ubicarSwagger(
        rutaConfigurada: '',
        directorioActual: '/x',
        existe: (_) => false,
      );
      expect((nada as SwaggerNoEncontrado).rutaConfigurada, isNull);
    });
  });

  group('PantallaDesarrollador', () {
    test('constructor del contrato', () {
      const pantalla = PantallaDesarrollador();
      expect(pantalla.key, isNull);
    });

    testWidgets('muestra los grupos y las operaciones con sus marcas', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(const PantallaDesarrollador()));

      expect(find.text('Desarrollador · APIs'), findsOneWidget);
      expect(find.text('Abrir en Swagger UI'), findsOneWidget);
      expect(
        find.textContaining('OpenAPI $versionEspecificacion'),
        findsOneWidget,
      );
      // Una operación que escribe y nunca pasa por la IA.
      final crearHogar = find.byKey(const ValueKey('operacion-crearHogar'));
      await tester.scrollUntilVisible(
        crearHogar,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      Finder dentro(Finder f) => find.descendant(of: crearHogar, matching: f);
      expect(dentro(find.text('POST')), findsOneWidget);
      expect(dentro(find.text('/rest/v1/rpc/crear_hogar')), findsOneWidget);
      expect(dentro(find.text('Pide confirmación')), findsOneWidget);
      expect(dentro(find.text('Nunca pasa por la IA')), findsOneWidget);
      // Cualquier cuenta con sesión crea un hogar y queda como su dueño (M5).
      expect(
        dentro(
          find.text('Roles: Dueño, Coadministrador, Familiar, Cuidador, Casa'),
        ),
        findsOneWidget,
      );

      // Una herramienta de navegación de Finanzas: no escribe y, como todo
      // Finanzas, nunca pasa por la IA (D3).
      final finanzas = find.byKey(
        const ValueKey('operacion-herramientaFinanzasAbrir'),
      );
      await tester.scrollUntilVisible(
        finanzas,
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      Finder enFinanzas(Finder f) => find.descendant(of: finanzas, matching: f);
      expect(
        enFinanzas(find.text('Roles: Dueño, Coadministrador')),
        findsOneWidget,
      );
      expect(enFinanzas(find.text('Pide confirmación')), findsNothing);
      expect(enFinanzas(find.text('Nunca pasa por la IA')), findsOneWidget);

      // Una de otro módulo: no escribe y sí puede verla la IA.
      final alimentacion = find.byKey(
        const ValueKey('operacion-herramientaAlimentacionAbrir'),
      );
      await tester.scrollUntilVisible(
        alimentacion,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      Finder enAlimentacion(Finder f) =>
          find.descendant(of: alimentacion, matching: f);
      expect(enAlimentacion(find.text('Pide confirmación')), findsNothing);
      expect(enAlimentacion(find.text('Nunca pasa por la IA')), findsNothing);

      // La bandeja de la cuidadora (D18), de la Fase 1.
      final bandeja = find.byKey(
        const ValueKey('operacion-herramientaGravityAbrirSolicitudes'),
      );
      await tester.scrollUntilVisible(
        bandeja,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      Finder enBandeja(Finder f) => find.descendant(of: bandeja, matching: f);
      expect(enBandeja(find.text('Roles: Cuidador')), findsOneWidget);
      expect(enBandeja(find.text('Fase 1')), findsOneWidget);

      // Cada grupo con su número de operaciones (Finanzas tiene su grupo).
      expect(
        gruposOperaciones.map((g) => g.nombre),
        contains('Base de datos · Finanzas'),
      );
      for (final g in gruposOperaciones) {
        final titulo = find.text('${g.nombre} (${g.operaciones.length})');
        await tester.scrollUntilVisible(
          titulo,
          600,
          scrollable: find.byType(Scrollable).first,
        );
        expect(titulo, findsOneWidget);
      }
    });
  });

  group('Abrir en Swagger UI', () {
    Future<List<Uri>> tocarBoton(
      WidgetTester tester, {
      String ruta = '',
      bool existe = false,
      bool abre = true,
    }) async {
      final abiertas = <Uri>[];
      await tester.pumpWidget(
        _app(
          VistaDesarrollador(
            grupos: gruposOperaciones,
            version: versionEspecificacion,
            rutaSwagger: ruta,
            directorioActual: '/repos/gravity/app',
            existeArchivo: (_) => existe,
            abrirUrl: (uri) async {
              abiertas.add(uri);
              return abre;
            },
          ),
        ),
      );
      await tester.tap(find.text('Abrir en Swagger UI'));
      await tester.pump();
      return abiertas;
    }

    testWidgets('sin ruta configurada explica cómo abrirla', (tester) async {
      final abiertas = await tocarBoton(tester);
      expect(abiertas, isEmpty);
      expect(
        find.textContaining('No encontré la página de Swagger UI'),
        findsOneWidget,
      );
      expect(find.textContaining('RUTA_SWAGGER'), findsOneWidget);
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pump();
      expect(find.textContaining('No encontré'), findsNothing);
    });

    testWidgets('con una ruta que no existe lo dice', (tester) async {
      final abiertas = await tocarBoton(tester, ruta: '/no/existe/index.html');
      expect(abiertas, isEmpty);
      expect(find.textContaining('/no/existe/index.html'), findsOneWidget);
    });

    testWidgets('con la ruta configurada la abre en el navegador', (
      tester,
    ) async {
      final abiertas = await tocarBoton(
        tester,
        ruta: '/repos/gravity/api/swagger/index.html',
        existe: true,
      );
      expect(abiertas, [
        Uri.parse('file:///repos/gravity/api/swagger/index.html'),
      ]);
      expect(find.textContaining('No encontré'), findsNothing);
    });

    testWidgets('si el navegador no abre, da la dirección', (tester) async {
      await tocarBoton(
        tester,
        ruta: 'http://127.0.0.1:8080/swagger/index.html',
        abre: false,
      );
      expect(
        find.textContaining('No se pudo abrir el navegador'),
        findsOneWidget,
      );
      expect(
        find.textContaining('http://127.0.0.1:8080/swagger/index.html'),
        findsOneWidget,
      );
    });
  });
}
