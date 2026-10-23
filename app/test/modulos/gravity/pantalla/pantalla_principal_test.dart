import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gravity/app/sesion_efectiva.dart';
import 'package:gravity/diseno/diseno.dart';
import 'package:gravity/modulos/gravity/pantalla/pantalla_principal.dart';
import 'package:gravity/modulos/gravity/pantalla/resumen_gravity.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';

import '../../../diseno/ayuda_pruebas.dart';

const _mensajeCompleto =
    'Buenas noches. Te faltan 2 hábitos de hoy y a las 20:00 hay un '
    'medicamento en el turno.';

Offset _esquina(WidgetTester tester, String clave) =>
    tester.getTopLeft(find.byKey(ValueKey(clave)));

void main() {
  group('Se construye sin errores', () {
    for (final tamano in const [
      Size(1440, 900),
      Size(700, 900),
      Size(390, 844),
    ]) {
      testWidgets('en ${tamano.width.toInt()}×${tamano.height.toInt()}', (
        tester,
      ) async {
        fijarVentana(tester, tamano);
        await montar(tester, const PantallaPrincipalGravity());
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        expect(find.text('GRAVITY'), findsOneWidget);
        expect(find.text('MAR 20 OCT · 19:42'), findsOneWidget);
        expect(find.text('En línea'), findsOneWidget);
        expect(find.byType(NucleoGravity), findsOneWidget);
        expect(
          find.byKey(const ValueKey('barra-ordenes-muestra')),
          findsOneWidget,
        );
      });
    }

    testWidgets('también de día', (tester) async {
      fijarVentana(tester, const Size(1440, 900));
      await montar(
        tester,
        const PantallaPrincipalGravity(),
        momento: momentoDia,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      final v = ValoresDiseno.de(
        tester.element(find.byType(PantallaPrincipalGravity)),
      );
      expect(v.brillo, Brightness.light);
      expect(find.textContaining('Buenos días.'), findsOneWidget);
    });
  });

  testWidgets('1440×900: tres columnas con el núcleo al centro', (
    tester,
  ) async {
    fijarVentana(tester, const Size(1440, 900));
    await montar(tester, const PantallaPrincipalGravity());

    expect(find.text('HOY · AGENDA'), findsOneWidget);
    expect(find.text('CUIDADOS · TURNO'), findsOneWidget);
    expect(find.text('FINANZAS · SEMANA 43'), findsOneWidget);
    expect(find.text('AVISOS'), findsOneWidget);
    expect(find.text(_mensajeCompleto), findsOneWidget);
    expect(find.text('EN ESPERA'), findsOneWidget);

    final hoy = _esquina(tester, 'panel-hoy');
    final nucleo = _esquina(tester, 'panel-nucleo');
    final finanzas = _esquina(tester, 'panel-finanzas');
    expect(hoy.dx, lessThan(nucleo.dx));
    expect(nucleo.dx, lessThan(finanzas.dx));
    expect(hoy.dy, finanzas.dy);
    // La barra de órdenes queda abajo, a todo lo ancho.
    expect(
      _esquina(tester, 'barra-ordenes-muestra').dy,
      greaterThan(
        tester.getBottomLeft(find.byKey(const ValueKey('panel-nucleo'))).dy,
      ),
    );
  });

  testWidgets('700 de ancho: los paneles se apilan', (tester) async {
    fijarVentana(tester, const Size(700, 900));
    await montar(tester, const PantallaPrincipalGravity());

    final nucleo = _esquina(tester, 'panel-nucleo');
    final hoy = _esquina(tester, 'panel-hoy');
    final cuidados = _esquina(tester, 'panel-cuidados');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('panel-avisos')),
      300,
    );
    final finanzas = _esquina(tester, 'panel-finanzas');
    final avisos = _esquina(tester, 'panel-avisos');
    expect(hoy.dx, nucleo.dx);
    expect(cuidados.dx, hoy.dx);
    expect(finanzas.dx, hoy.dx);
    expect(avisos.dx, hoy.dx);
    expect(nucleo.dy, lessThan(hoy.dy));
    expect(hoy.dy, lessThan(cuidados.dy));
    expect(finanzas.dy, lessThan(avisos.dy));
    expect(tester.takeException(), isNull);
  });

  group('Barra de órdenes', () {
    testWidgets('usa la que entrega el asistente', (tester) async {
      fijarVentana(tester, const Size(1440, 900));
      await montar(
        tester,
        const PantallaPrincipalGravity(
          barraOrdenes: SizedBox(
            key: ValueKey('barra-real'),
            height: 56,
            child: Text('barra real'),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('barra-real')), findsOneWidget);
      expect(find.byKey(const ValueKey('barra-ordenes-muestra')), findsNothing);
    });
  });

  group('Privacidad', () {
    testWidgets('los montos empiezan ocultos y se muestran con un toque', (
      tester,
    ) async {
      fijarVentana(tester, const Size(1440, 900));
      await montar(tester, const PantallaPrincipalGravity());
      expect(find.text(montoOculto), findsOneWidget);
      expect(find.text(r'$1,330.00'), findsNothing);
      // La marca avisa y es la forma de pedir verlos (por omisión, sin PIN).
      expect(find.text(MarcaMontosOcultos.texto), findsOneWidget);
      expect(find.text('Ocultar'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('marca-montos-ocultos')));
      await tester.pump();
      expect(find.text(r'$1,330.00'), findsOneWidget);
      expect(find.text(MarcaMontosOcultos.texto), findsNothing);
      expect(find.text('Ocultar'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('boton-ocultar-montos')));
      await tester.pump();
      expect(find.text(r'$1,330.00'), findsNothing);
      expect(find.text(montoOculto), findsOneWidget);
      expect(find.text(MarcaMontosOcultos.texto), findsOneWidget);
    });

    testWidgets('pedir ver los montos pasa por el flujo de plataforma '
        '(revelarMontosProvider)', (tester) async {
      fijarVentana(tester, const Size(1440, 900));
      var pedidos = 0;
      await montar(
        tester,
        const PantallaPrincipalGravity(),
        overrides: [
          revelarMontosProvider.overrideWithValue((context) async {
            pedidos++;
            return false; // el PIN falló: siguen ocultos
          }),
        ],
      );
      await tester.tap(find.byKey(const ValueKey('marca-montos-ocultos')));
      await tester.pump();
      expect(pedidos, 1);
      expect(find.text(r'$1,330.00'), findsNothing);
      expect(find.text(montoOculto), findsOneWidget);
    });

    testWidgets('el modo privado oculta montos y cuidados', (tester) async {
      fijarVentana(tester, const Size(1440, 900));
      await montar(tester, const PantallaPrincipalGravity());
      await tester.tap(find.byKey(const ValueKey('marca-montos-ocultos')));
      await tester.pump();
      expect(find.text(r'$1,330.00'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('boton-modo-privado')));
      await tester.pump();
      expect(find.text(r'$1,330.00'), findsNothing);
      expect(find.text(montoOculto), findsOneWidget);
      expect(find.byKey(const ValueKey('boton-ocultar-montos')), findsNothing);
      // En modo privado la marca lo dice y no se toca: se quita el modo.
      expect(find.text(MarcaMontosOcultos.textoPrivado), findsOneWidget);
      expect(find.text(MarcaMontosOcultos.texto), findsNothing);
      expect(find.text('Medicamento 20:00'), findsNothing);
      expect(
        find.text('Datos de cuidados ocultos (modo privado)'),
        findsOneWidget,
      );
      expect(
        find.text('Buenas noches. Te faltan 2 hábitos de hoy.'),
        findsOneWidget,
      );
      expect(find.text('Privado: activo'), findsOneWidget);

      // Al quitarlo, los montos siguen ocultos hasta que se pidan.
      await tester.tap(find.byKey(const ValueKey('boton-modo-privado')));
      await tester.pump();
      expect(find.text(montoOculto), findsOneWidget);
      expect(find.text('Medicamento 20:00'), findsOneWidget);
    });

    testWidgets('atajo Ctrl + Shift + O', (tester) async {
      fijarVentana(tester, const Size(1440, 900));
      await montar(tester, const PantallaPrincipalGravity());
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      final c = contenedorDe(tester, find.byType(PantallaPrincipalGravity));
      expect(c.read(modoPrivadoProvider), isTrue);
      expect(find.text('Privado: activo'), findsOneWidget);
    });
  });

  testWidgets('sin dinero para el rol: no aparece el panel de Finanzas', (
    tester,
  ) async {
    fijarVentana(tester, const Size(1440, 900));
    await montar(
      tester,
      const PantallaPrincipalGravity(),
      overrides: [
        resumenGravityProvider.overrideWithValue(
          ResumenGravity(
            agenda: ResumenGravity.ejemplo.agenda,
            habitos: ResumenGravity.ejemplo.habitos,
            avisos: const [
              AvisoGravity(
                'SÁB 14:30',
                'Revisión semanal',
                modulo: Modulo.finanzas,
              ),
            ],
          ),
        ),
      ],
    );
    expect(find.byKey(const ValueKey('panel-finanzas')), findsNothing);
    expect(find.byKey(const ValueKey('panel-cuidados')), findsNothing);
    expect(find.text(montoOculto), findsNothing);
    expect(
      find.text('Buenas noches. Te faltan 2 hábitos de hoy.'),
      findsOneWidget,
    );
  });

  testWidgets('la barra de módulos abre la ruta del módulo', (tester) async {
    fijarVentana(tester, const Size(1440, 900));
    final router = GoRouter(
      routes: [
        GoRoute(
          path: Rutas.inicio,
          builder: (_, _) => const PantallaPrincipalGravity(),
        ),
        GoRoute(
          path: Rutas.finanzas,
          builder: (_, _) => const Scaffold(body: Text('pantalla finanzas')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          relojProvider.overrideWithValue(RelojFijo(momentoNoche)),
          rolEfectivoProvider.overrideWithValue(Rol.dueno),
          datosResumenGravityProvider.overrideWithValue(ResumenGravity.ejemplo),
        ],
        child: Consumer(
          builder: (context, ref, _) => MaterialApp.router(
            theme: ref.watch(temaClaroProvider),
            darkTheme: ref.watch(temaOscuroProvider),
            themeMode: ref.watch(modoTemaProvider),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pump();
    for (final (clave, texto) in [
      ('finanzas', 'FINANZAS'),
      ('habitos', 'HÁBITOS'),
      ('cuidados', 'CUIDADOS'),
      ('alimentacion', 'ALIMENTACIÓN'),
      ('casa', 'CASA'),
      ('ajustes', 'AJUSTES'),
    ]) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('modulo-$clave')),
          matching: find.text(texto),
        ),
        findsOneWidget,
      );
    }
    await tester.tap(find.byKey(const ValueKey('modulo-finanzas')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('pantalla finanzas'), findsOneWidget);
  });

  for (final (nombre, momento) in [
    ('noche', momentoNoche),
    ('día', momentoDia),
  ]) {
    testWidgets('cumple zonas táctiles y contraste de texto de $nombre', (
      tester,
    ) async {
      fijarVentana(tester, const Size(1440, 900));
      final semantica = tester.ensureSemantics();
      await montar(tester, const PantallaPrincipalGravity(), momento: momento);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantica.dispose();
    });
  }

  group('Por rol (D5)', () {
    Future<void> montarComo(WidgetTester tester, Rol rol) async {
      fijarVentana(tester, const Size(1440, 900));
      await montar(tester, const PantallaPrincipalGravity(), rol: rol);
    }

    String textoVisible(WidgetTester tester) => tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
        .join(' · ')
        .toLowerCase();

    testWidgets('Familiar: sin dinero ni cuidados, ni en el núcleo', (
      tester,
    ) async {
      await montarComo(tester, Rol.familiar);
      expect(find.byKey(const ValueKey('panel-finanzas')), findsNothing);
      expect(find.byKey(const ValueKey('monto-quedan')), findsNothing);
      expect(find.byKey(const ValueKey('panel-cuidados')), findsNothing);
      // Lo suyo sí: agenda y hábitos.
      expect(find.byKey(const ValueKey('panel-hoy')), findsOneWidget);
      final texto = textoVisible(tester);
      for (final prohibido in [
        'quedan',
        'presupuesto',
        'tarjeta de crédito',
        'revisión semanal',
        'medicamento',
        'cuidados',
        'turno',
      ]) {
        expect(texto, isNot(contains(prohibido)), reason: prohibido);
      }
      expect(
        find.text('Buenas noches. Te faltan 2 hábitos de hoy.'),
        findsOneWidget,
      );
    });

    testWidgets('Casa: sin dinero ni hábitos; cuidados solo genéricos', (
      tester,
    ) async {
      await montarComo(tester, Rol.casa);
      expect(find.byKey(const ValueKey('panel-finanzas')), findsNothing);
      expect(find.byKey(const ValueKey('panel-hoy')), findsNothing);
      expect(find.byKey(const ValueKey('panel-cuidados')), findsOneWidget);
      expect(find.text('Turno de cuidados · hasta 20:00'), findsOneWidget);
      expect(find.text('Recordatorio de cuidados 20:00'), findsOneWidget);
      final texto = textoVisible(tester);
      for (final prohibido in [
        'quedan',
        'presupuesto',
        'tarjeta de crédito',
        'medicamento',
        'cuidadora',
        'entrega de turno',
        'hábito',
      ]) {
        expect(texto, isNot(contains(prohibido)), reason: prohibido);
      }
      expect(
        find.text(
          'Buenas noches. A las 20:00 hay un recordatorio de cuidados.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Coadministrador: Finanzas sí; Cuidados no sin '
        'consentimiento', (tester) async {
      await montarComo(tester, Rol.coadministrador);
      expect(find.byKey(const ValueKey('panel-finanzas')), findsOneWidget);
      expect(find.byKey(const ValueKey('panel-cuidados')), findsNothing);
      expect(textoVisible(tester), isNot(contains('medicamento')));
    });

    testWidgets('sin rol no muestra paneles', (tester) async {
      fijarVentana(tester, const Size(1440, 900));
      await montar(tester, const PantallaPrincipalGravity(), rol: null);
      for (final panel in [
        'panel-hoy',
        'panel-cuidados',
        'panel-finanzas',
        'panel-avisos',
      ]) {
        expect(find.byKey(ValueKey(panel)), findsNothing, reason: panel);
      }
      expect(find.byKey(const ValueKey('panel-nucleo')), findsOneWidget);
    });

    for (final (rol, esperados) in [
      (
        Rol.dueno,
        ['finanzas', 'habitos', 'cuidados', 'alimentacion', 'casa', 'ajustes'],
      ),
      (Rol.familiar, ['habitos', 'alimentacion', 'casa', 'ajustes']),
      (Rol.casa, ['cuidados', 'alimentacion', 'casa']),
    ]) {
      testWidgets('barra de módulos de ${rol.name}', (tester) async {
        await montarComo(tester, rol);
        for (final m in Modulo.values) {
          expect(
            find.byKey(ValueKey('modulo-${m.name}')),
            esperados.contains(m.name) ? findsOneWidget : findsNothing,
            reason: '${rol.name}: ${m.name}',
          );
        }
      });
    }

    testWidgets('el ejemplo de la barra de muestra no ofrece "presupuesto" '
        'a quien no ve Finanzas', (tester) async {
      await montarComo(tester, Rol.familiar);
      expect(find.textContaining('abre presupuesto'), findsNothing);
      expect(find.textContaining('ej.: abre hábitos'), findsOneWidget);
    });
  });

  for (final (nombre, momento) in [
    ('noche', momentoNoche),
    ('día', momentoDia),
  ]) {
    testWidgets('el estado del núcleo llega a 4.5:1 de $nombre (M7)', (
      tester,
    ) async {
      fijarVentana(tester, const Size(1440, 900));
      await montar(tester, const PantallaPrincipalGravity(), momento: momento);
      final estado = tester.widget<Text>(
        find.byKey(const ValueKey('estado-nucleo')),
      );
      expect(estado.data, 'EN ESPERA');
      final caja = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('panel-nucleo')),
      );
      final superficie = (caja.decoration as BoxDecoration).color!;
      expect(
        razonContraste(estado.style!.color!, superficie),
        greaterThanOrEqualTo(contrasteMinimoTexto),
      );
    });
  }
}
