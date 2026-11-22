// F4-A5 (decisión del dueño, opción B): la cuidadora ve el menú de Papá DENTRO
// de Cuidados, en solo lectura (D23). La ruta /alimentacion no se abre para
// ella (sigue mandándola a /cuidados): el menú llega por /cuidados/menu-papa.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gravity/app/navegacion.dart';
import 'package:gravity/app/router.dart' show montarRutasDeModulo;
import 'package:gravity/app/sesion_efectiva.dart';
import 'package:gravity/app/sesion_real.dart';
import 'package:gravity/diseno/proveedores.dart' show RelojFijo, relojProvider;
import 'package:gravity/modulos/alimentacion/datos/modelos.dart';
import 'package:gravity/modulos/alimentacion/datos/perfiles.dart';
import 'package:gravity/modulos/alimentacion/datos/repositorio.dart';
import 'package:gravity/modulos/alimentacion/pantallas/menu.dart'
    show PantallaMenuSemana;
import 'package:gravity/modulos/cuidados/cuidados.dart' show rutasCuidados;
import 'package:gravity/modulos/cuidados/casos_uso/permisos_cuidados.dart';
import 'package:gravity/modulos/cuidados/datos/modelos.dart';
import 'package:gravity/modulos/cuidados/datos/repositorio.dart';
import 'package:gravity/modulos/cuidados/estado/proveedores.dart';
import 'package:gravity/modulos/cuidados/pantallas/menu_papa.dart';
import 'package:gravity/modulos/cuidados/pantallas/mi_turno.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';

final _miercoles10 = DateTime(2026, 11, 4, 10);

const _perfilHermana = PerfilCuidados(
  esFamiliar: true,
  resumenAutorizado: true,
);

List<Override> _overrides(
  Rol rol, {
  PerfilCuidados perfil = const PerfilCuidados(),
  bool maestra = false,
  bool sesionReal = false,
}) {
  final datos = datosDeEjemploCuidados(_miercoles10);
  return [
    relojProvider.overrideWithValue(RelojFijo(_miercoles10)),
    almacenSeguroProvider.overrideWithValue(AlmacenSeguroEnMemoria()),
    servicioSesionProvider.overrideWithValue(ServicioSesionFalso()),
    sesionEfectivaProvider.overrideWithValue(
      Sesion(
        persona: Persona(id: 'persona-$rol', nombre: 'Ejemplo'),
        rol: rol,
        esMaestra: maestra,
      ),
    ),
    // Con sesión real (Supabase) Alimentación nunca arma datos de ejemplo.
    if (sesionReal) sesionRealSupabaseProvider.overrideWithValue(true),
    repositorioCuidadosProvider.overrideWithValue(
      RepositorioCuidadosEnMemoria(
        datos: datos,
        personaId: 'persona-$rol',
        rol: rol,
        perfilActual: perfil,
      ),
    ),
  ];
}

Widget _app(
  Widget pantalla,
  Rol rol, {
  PerfilCuidados perfil = const PerfilCuidados(),
  bool maestra = false,
  bool sesionReal = false,
  double escala = 1,
}) => ProviderScope(
  overrides: _overrides(
    rol,
    perfil: perfil,
    maestra: maestra,
    sesionReal: sesionReal,
  ),
  child: MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(escala)),
      child: child!,
    ),
    home: pantalla,
  ),
);

Future<void> _pantalla(WidgetTester t, [Size tam = const Size(400, 4000)]) async {
  await t.binding.setSurfaceSize(tam);
  addTearDown(() => t.binding.setSurfaceSize(null));
}

/// Lo que un menú editable ofrece y la vista de Cuidados nunca.
void _sinControlesDeEdicion() {
  expect(find.byIcon(Icons.edit_outlined), findsNothing);
  expect(find.text('Agregar suplemento'), findsNothing);
  expect(find.byIcon(Icons.delete_outline), findsNothing);
  expect(find.text('Cambiar porciones'), findsNothing);
  expect(find.byType(SegmentedButton<MenuId>), findsNothing);
  expect(find.byIcon(Icons.upload_file_outlined), findsNothing);
}

void main() {
  group('Menú de Papá dentro de Cuidados (solo lectura)', () {
    testWidgets('la cuidadora ve el menú de Papá, sin controles de edición', (
      t,
    ) async {
      await _pantalla(t);
      await t.pumpWidget(_app(const PantallaMenuDePapa(), Rol.cuidador));
      await t.pumpAndSettle();

      expect(find.text('Menú de Papá'), findsOneWidget);
      expect(find.textContaining('Semana del'), findsOneWidget);
      expect(find.text('Lunes'), findsOneWidget);
      expect(find.text('Desayuno'), findsWidgets);
      expect(find.text('Solo lectura'), findsOneWidget);
      // D23: la cuidadora ve el perfil de Papá (lo pinta Alimentación).
      expect(find.text(perfilDe(MenuId.papa).titulo), findsOneWidget);
      _sinControlesDeEdicion();
    });

    testWidgets('control: la pantalla de Alimentación sí ofrece editar al dueño', (
      t,
    ) async {
      await _pantalla(t);
      await t.pumpWidget(_app(const PantallaMenuSemana(), Rol.dueno));
      await t.pumpAndSettle();
      expect(find.byIcon(Icons.edit_outlined), findsWidgets);
      expect(find.text('Agregar suplemento'), findsOneWidget);
    });

    testWidgets('tocar una comida no abre nada para elegir platillo', (t) async {
      await _pantalla(t);
      await t.pumpWidget(_app(const PantallaMenuDePapa(), Rol.cuidador));
      await t.pumpAndSettle();
      await t.tap(find.text('Desayuno').first);
      await t.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('el dueño la ve igual de solo lectura, aunque en Alimentación edite', (
      t,
    ) async {
      await _pantalla(t);
      await t.pumpWidget(_app(const PantallaMenuDePapa(), Rol.dueno));
      await t.pumpAndSettle();
      expect(find.text('Solo lectura'), findsOneWidget);
      _sinControlesDeEdicion();
    });

    testWidgets('la hermana (familiar) la ve en solo lectura', (t) async {
      await _pantalla(t);
      await t.pumpWidget(
        _app(const PantallaMenuDePapa(), Rol.familiar, perfil: _perfilHermana),
      );
      await t.pumpAndSettle();
      expect(find.text('Solo lectura'), findsOneWidget);
      _sinControlesDeEdicion();
    });

    testWidgets('Casa no ve nada: ni menú ni perfil (D3)', (t) async {
      await _pantalla(t);
      await t.pumpWidget(_app(const PantallaMenuDePapa(), Rol.casa));
      await t.pumpAndSettle();
      expect(find.text('Esta sección no está disponible'), findsOneWidget);
      expect(find.textContaining('Semana del'), findsNothing);
      expect(find.text(perfilDe(MenuId.papa).titulo), findsNothing);
      expect(find.text('Suplementos'), findsNothing);
    });

    testWidgets('la pareja sin consentimiento y la cuenta maestra tampoco entran', (
      t,
    ) async {
      await _pantalla(t);
      await t.pumpWidget(_app(const PantallaMenuDePapa(), Rol.coadministrador));
      await t.pumpAndSettle();
      expect(find.text('Esta sección no está disponible'), findsOneWidget);
      expect(find.textContaining('Semana del'), findsNothing);

      await t.pumpWidget(
        _app(const PantallaMenuDePapa(), Rol.coadministrador, maestra: true),
      );
      await t.pumpAndSettle();
      expect(find.text('Esta sección no está disponible'), findsOneWidget);
    });

    testWidgets(
      'con sesión real y sin menú en el servidor: vacío honesto, sin cifras ni platillos de ejemplo',
      (t) async {
        final ejemplo = RepositorioAlimentacionEnMemoria(
          semanaEjemplo: _miercoles10,
        );
        final platillos = (await ejemplo.platillos()).map((p) => p.nombre);
        final suplementos = (await ejemplo.suplementos(
          MenuId.papa,
        )).map((s) => s.nombre);
        expect(platillos, isNotEmpty, reason: 'la prueba necesita un ejemplo');

        await _pantalla(t);
        await t.pumpWidget(
          _app(const PantallaMenuDePapa(), Rol.cuidador, sesionReal: true),
        );
        await t.pumpAndSettle();

        expect(find.text('Sin menú todavía'), findsOneWidget);
        expect(find.textContaining('Semana del'), findsNothing);
        for (final nombre in [...platillos, ...suplementos]) {
          expect(find.textContaining(nombre), findsNothing, reason: nombre);
        }
        expect(find.text('Sin platillo'), findsNothing);
        _sinControlesDeEdicion();
      },
    );

    testWidgets('letra grande: 2.0 en 360 dp sin desbordes y al menos 1.2 siempre', (
      t,
    ) async {
      await _pantalla(t, const Size(360, 4000));
      // Letra normal del sistema: la vista la agranda a 1.2 como mínimo.
      await t.pumpWidget(_app(const PantallaMenuDePapa(), Rol.cuidador));
      await t.pumpAndSettle();
      final minimo = MediaQuery.textScalerOf(
        t.element(find.text('Desayuno').first),
      );
      expect(minimo.scale(10), greaterThanOrEqualTo(12));
      expect(t.takeException(), isNull);

      // La letra del sistema al máximo: se respeta la de la persona.
      await t.pumpWidget(
        _app(const PantallaMenuDePapa(), Rol.cuidador, escala: 2),
      );
      await t.pumpAndSettle();
      expect(
        MediaQuery.textScalerOf(
          t.element(find.text('Desayuno').first),
        ).scale(10),
        greaterThanOrEqualTo(20),
      );
      expect(t.takeException(), isNull);
    });

    testWidgets('accesible: cada comida se lee completa con su día y tiempo', (
      t,
    ) async {
      final semantica = t.ensureSemantics();
      await _pantalla(t);
      await t.pumpWidget(_app(const PantallaMenuDePapa(), Rol.cuidador));
      await t.pumpAndSettle();
      final lunes = find.bySemanticsLabel(RegExp(r'Lunes, Desayuno: '));
      expect(lunes, findsOneWidget);
      final nodo = t.getSemantics(lunes);
      expect(
        nodo.flagsCollection.isButton,
        isFalse,
        reason: 'solo lectura: no es un botón que cambie la comida',
      );
      expect(
        find.bySemanticsLabel(RegExp('Toca para cambiar')),
        findsNothing,
        reason: 'no ofrece cambiar nada',
      );
      semantica.dispose();
    });
  });

  group('Cómo llega la cuidadora al menú de Papá', () {
    testWidgets('Mi turno ofrece "Menú de Papá" a la cuidadora y a la hermana', (
      t,
    ) async {
      await _pantalla(t);
      await t.pumpWidget(_app(const PantallaMiTurno(), Rol.cuidador));
      await t.pumpAndSettle();
      expect(find.text('Menú de Papá'), findsOneWidget);

      await t.pumpWidget(
        _app(const PantallaMiTurno(), Rol.familiar, perfil: _perfilHermana),
      );
      await t.pumpAndSettle();
      expect(find.text('Menú de Papá'), findsOneWidget);
    });

    testWidgets('Mi turno no lo ofrece a Casa ni a la pareja sin consentimiento', (
      t,
    ) async {
      await _pantalla(t);
      for (final rol in [Rol.casa, Rol.coadministrador]) {
        await t.pumpWidget(_app(const PantallaMiTurno(), rol));
        await t.pumpAndSettle();
        expect(find.text('Menú de Papá'), findsNothing, reason: '$rol');
      }
    });

    testWidgets('con el router: toca "Menú de Papá" y llega a /cuidados/menu-papa', (
      t,
    ) async {
      await _pantalla(t);
      final router = GoRouter(
        initialLocation: Rutas.cuidados,
        redirect: (context, estado) => calcularRedireccion(
          ubicacion: estado.uri.path,
          rol: Rol.cuidador,
          dispositivo: TipoDispositivo.telefono,
        ),
        routes: montarRutasDeModulo(
          Rutas.cuidados,
          rutasCuidados(),
          modulo: Modulo.cuidados,
        ),
      );
      addTearDown(router.dispose);
      await t.pumpWidget(
        ProviderScope(
          overrides: _overrides(Rol.cuidador),
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Mi turno'), findsOneWidget);

      await t.tap(find.text('Menú de Papá'));
      await t.pumpAndSettle();
      expect(router.state.uri.path, '${Rutas.cuidados}/menu-papa');
      expect(find.textContaining('Semana del'), findsOneWidget);
      _sinControlesDeEdicion();

      // /alimentacion sigue sin abrirse para ella: vuelve a Cuidados.
      router.go(Rutas.alimentacion);
      await t.pumpAndSettle();
      expect(router.state.uri.path, Rutas.cuidados);
      expect(find.text('Mi turno'), findsOneWidget);
    });

    test('el permiso de la vista es el de entrar a la parte clínica de Cuidados', () {
      PermisosCuidados de(Rol rol, {PerfilCuidados? perfil, bool maestra = false}) =>
          PermisosCuidados(
            rol: rol,
            perfil: perfil ?? const PerfilCuidados(),
            esMaestra: maestra,
          );
      expect(de(Rol.cuidador).veMenuDePapa, isTrue);
      expect(de(Rol.dueno).veMenuDePapa, isTrue);
      expect(de(Rol.familiar, perfil: _perfilHermana).veMenuDePapa, isTrue);
      expect(de(Rol.casa).veMenuDePapa, isFalse);
      expect(de(Rol.coadministrador).veMenuDePapa, isFalse);
      expect(de(Rol.coadministrador, maestra: true).veMenuDePapa, isFalse);
    });
  });

  group('D3 y guardias del módulo', () {
    test('Cuidados no escribe el perfil clínico ni importa red, voz o asistente', () {
      final archivos = Directory('lib/modulos/cuidados')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      for (final f in archivos) {
        final texto = f.readAsStringSync().toLowerCase();
        expect(texto.contains('alzheimer'), isFalse, reason: f.path);
        expect(texto.contains('aminoácidos'), isFalse, reason: f.path);
      }
      final menu = File(
        'lib/modulos/cuidados/pantallas/menu_papa.dart',
      ).readAsStringSync();
      expect(menu.contains('Clipboard'), isFalse);
      expect(menu.contains('Share'), isFalse);
      expect(menu.contains('print('), isFalse);
    });

    test('lo único que Cuidados toma de Alimentación es el widget de solo lectura', () {
      final importa = RegExp(
        r"^import '[^']*modulos/alimentacion/[^']*'|^import '\.\./\.\./alimentacion/[^']*'",
        multiLine: true,
      );
      final infractores = <String>[];
      for (final f
          in Directory('lib/modulos/cuidados')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        for (final m in importa.allMatches(f.readAsStringSync())) {
          final linea = m.group(0)!;
          if (!linea.endsWith("alimentacion/alimentacion.dart'")) {
            infractores.add('${f.path}: $linea');
          }
        }
      }
      expect(infractores, isEmpty);
    });
  });
}
