// CA-G-42 y CA-G-38 (parte de rutas): «Mi gimnasio» cuelga de Hábitos
// (/habitos/entrenamiento/…) y cada persona ve solo lo suyo (D5): dueño,
// coadministrador y familiar sí; cuidadora, Hogar (Casa) y la cuenta maestra no
// ven nada. Encima, por equipo (spec 7.1): las molestias nunca están en la
// laptop ni en la tablet pública; planear y revisar no están en la tablet
// pública. Las molestias llevan FLAG_SECURE y se ocultan en modo privado.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/app/avisos/con_avisos.dart'
    show tipoEquipoAvisosProvider;
import 'package:gravity/app/gimnasio/acceso_gimnasio.dart';
import 'package:gravity/app/gimnasio/proteger_molestias.dart';
import 'package:gravity/app/navegacion.dart';
import 'package:gravity/app/pantalla_segura.dart';
import 'package:gravity/app/router.dart';
import 'package:gravity/diseno/gimnasio/textos_gimnasio.dart';
import 'package:gravity/diseno/proveedores.dart' show modoPrivadoProvider;
import 'package:gravity/nucleo/avisos/repositorio_avisos.dart'
    show TipoEquipoAvisos;
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/pantalla_segura.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart'
    show almacenSeguroProvider;
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart'
    show sesionDeEjemplo;
import 'package:gravity/nucleo/tablet/usuarios_tablet.dart';
import 'package:gravity/app/tablet/pantalla_modo_casa.dart'
    show tarjetasPorContexto;

import '../nucleo/seguridad/pantalla_segura_test.dart'
    show ProtectorRegistrador;
import 'ayuda_plataforma.dart';

const nombreDueno = 'Dueño de ejemplo';

String ubicacion(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AppGravity)))
        .read(routerProvider)
        .routerDelegate
        .currentConfiguration
        .uri
        .path;

/// Navega y deja pasar un momento (la sesión en curso tiene un temporizador, así
/// que no se espera a que "no haya nada pendiente").
Future<void> irA(WidgetTester tester, String ruta) async {
  ProviderScope.containerOf(tester.element(find.byType(AppGravity)))
      .read(routerProvider)
      .go(ruta);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Finder get provisional => find.byKey(const ValueKey('gimnasio-provisional'));

void main() {
  group('matriz por equipo (7.1)', () {
    // equipo → destinos que SÍ tiene.
    final matriz = <TipoEquipoAvisos, Set<DestinoGimnasio>>{
      TipoEquipoAvisos.telefono: {...DestinoGimnasio.values},
      TipoEquipoAvisos.tabletPersonal: {...DestinoGimnasio.values},
      TipoEquipoAvisos.laptop: {
        for (final d in DestinoGimnasio.values)
          if (d != DestinoGimnasio.molestias) d,
      },
      TipoEquipoAvisos.tabletPublica: {
        DestinoGimnasio.hoy,
        DestinoGimnasio.sesion,
        DestinoGimnasio.sesionEnCurso,
      },
    };

    for (final e in matriz.entries) {
      test('${e.key.name}: tiene ${e.value.length} de 10 pantallas', () {
        for (final d in DestinoGimnasio.values) {
          expect(
            gimnasioDisponibleEn(d, e.key),
            e.value.contains(d),
            reason: '${d.name} en ${e.key.name}',
          );
        }
      });
    }

    test('las molestias NUNCA en la tablet pública ni en la laptop', () {
      expect(
        gimnasioDisponibleEn(
          DestinoGimnasio.molestias,
          TipoEquipoAvisos.tabletPublica,
        ),
        isFalse,
      );
      expect(
        gimnasioDisponibleEn(
          DestinoGimnasio.molestias,
          TipoEquipoAvisos.laptop,
        ),
        isFalse,
      );
    });

    test('la sesión en curso en la laptop es solo para ver', () {
      expect(
        gimnasioSoloVerEn(
          DestinoGimnasio.sesionEnCurso,
          TipoEquipoAvisos.laptop,
        ),
        isTrue,
      );
      expect(
        gimnasioSoloVerEn(
          DestinoGimnasio.sesionEnCurso,
          TipoEquipoAvisos.telefono,
        ),
        isFalse,
      );
      expect(
        gimnasioSoloVerEn(DestinoGimnasio.hoy, TipoEquipoAvisos.laptop),
        isFalse,
      );
    });

    test('las diez pantallas existen, con rutas únicas bajo /habitos/entrenamiento', () {
      expect(DestinoGimnasio.values, hasLength(10));
      final rutas = [for (final d in DestinoGimnasio.values) d.ruta];
      expect(rutas.toSet(), hasLength(10));
      for (final r in rutas) {
        expect(r, startsWith('${Rutas.habitos}/entrenamiento'));
        expect(destinoGimnasioDeRuta(r), isNotNull);
        expect(
          destinoGimnasioDeRuta('$r/'),
          isNotNull,
          reason: 'con barra final',
        );
      }
      expect(destinoGimnasioDeRuta('/habitos/objetivos'), isNull);
      expect(destinoGimnasioDeRuta('/habitos/entrenamiento/otra'), isNull);
      expect(RutasGimnasio.hoy, '/habitos/entrenamiento');
      expect(RutasGimnasio.molestias, '/habitos/entrenamiento/molestias');
    });
  });

  group('redirecciones por rol y por equipo (función pura)', () {
    String? ir(
      Rol rol,
      String ruta, {
      TipoDispositivo dispositivo = TipoDispositivo.telefono,
      bool esMaestra = false,
      TipoEquipoAvisos? equipo,
      bool enAccion = false,
    }) => calcularRedireccion(
      ubicacion: ruta,
      rol: rol,
      dispositivo: dispositivo,
      esMaestra: esMaestra,
      equipo: equipo,
      enAccionDeTabletCasa: enAccion,
    );

    test('dueño, coadministrador y familiar abren las diez', () {
      for (final rol in [Rol.dueno, Rol.coadministrador, Rol.familiar]) {
        for (final d in DestinoGimnasio.values) {
          expect(
            ir(rol, d.ruta, equipo: TipoEquipoAvisos.telefono),
            isNull,
            reason: '${rol.name} ${d.name}',
          );
        }
      }
    });

    test('cuidadora y Hogar (Casa) no ven nada: vuelven a su inicio', () {
      for (final rol in [Rol.cuidador, Rol.casa]) {
        for (final d in DestinoGimnasio.values) {
          final destino = ir(rol, d.ruta, equipo: TipoEquipoAvisos.telefono);
          expect(destino, isNotNull, reason: '${rol.name} ${d.name}');
          expect(destino, isNot(startsWith('${Rutas.habitos}/')));
        }
      }
    });

    test('la cuenta maestra no tiene Hábitos: nada de Mi gimnasio', () {
      for (final d in DestinoGimnasio.values) {
        expect(
          ir(
            Rol.dueno,
            d.ruta,
            esMaestra: true,
            equipo: TipoEquipoAvisos.telefono,
          ),
          isNotNull,
          reason: d.name,
        );
      }
    });

    test('laptop: sin molestias; vuelve a la entrada del entrenamiento', () {
      expect(
        ir(
          Rol.dueno,
          RutasGimnasio.molestias,
          dispositivo: TipoDispositivo.laptop,
          equipo: TipoEquipoAvisos.laptop,
        ),
        RutasGimnasio.hoy,
      );
      expect(
        ir(
          Rol.dueno,
          DestinoGimnasio.historial.ruta,
          dispositivo: TipoDispositivo.laptop,
          equipo: TipoEquipoAvisos.laptop,
        ),
        isNull,
      );
    });

    test(
      'tablet pública: con PIN ve Hoy, Sesión de hoy y en curso; lo demás no',
      () {
        for (final d in DestinoGimnasio.values) {
          final r = ir(
            Rol.dueno,
            d.ruta,
            dispositivo: TipoDispositivo.tablet,
            equipo: TipoEquipoAvisos.tabletPublica,
          );
          final tiene = const {
            DestinoGimnasio.hoy,
            DestinoGimnasio.sesion,
            DestinoGimnasio.sesionEnCurso,
          }.contains(d);
          expect(r, tiene ? isNull : RutasGimnasio.hoy, reason: d.name);
        }
      },
    );

    test('tablet personal: como el teléfono, también las molestias (de este equipo)', () {
      for (final d in DestinoGimnasio.values) {
        expect(
          ir(
            Rol.dueno,
            d.ruta,
            dispositivo: TipoDispositivo.tablet,
            equipo: TipoEquipoAvisos.tabletPersonal,
          ),
          isNull,
          reason: d.name,
        );
      }
    });

    test('caso malo: entrar solo para una acción en la tablet pública tampoco abre molestias', () {
      expect(
        ir(
          Rol.dueno,
          RutasGimnasio.molestias,
          dispositivo: TipoDispositivo.tablet,
          enAccion: true,
        ),
        RutasGimnasio.hoy,
      );
    });
  });

  group('esPantallaSensible: las molestias, sin capturas', () {
    test('las molestias sí; el resto del entrenamiento se puede capturar', () {
      for (final rol in [Rol.dueno, Rol.coadministrador, Rol.familiar]) {
        expect(
          esPantallaSensible(RutasGimnasio.molestias, rol),
          isTrue,
          reason: rol.name,
        );
        for (final d in DestinoGimnasio.values.where(
          (d) => d != DestinoGimnasio.molestias,
        )) {
          expect(
            esPantallaSensible(d.ruta, rol),
            isFalse,
            reason: '${rol.name} ${d.name}',
          );
        }
      }
    });

    test('quien no abre Hábitos no tiene nada que proteger ahí', () {
      expect(
        esPantallaSensible(RutasGimnasio.molestias, Rol.cuidador),
        isFalse,
      );
      expect(esPantallaSensible(RutasGimnasio.molestias, Rol.casa), isFalse);
      expect(esPantallaSensible(RutasGimnasio.molestias, null), isFalse);
    });
  });

  group('rutas montadas en la app', () {
    for (final rol in [Rol.dueno, Rol.coadministrador, Rol.familiar]) {
      testWidgets(
        '${rol.name} en el teléfono: las diez pantallas reales (G5), ya no provisionales',
        (tester) async {
          await montarApp(
            tester,
            dispositivo: TipoDispositivo.telefono,
            sesion: sesionCon(rol),
          );
          for (final d in DestinoGimnasio.values) {
            await irA(tester, d.ruta);
            expect(ubicacion(tester), d.ruta, reason: d.name);
            // G5: ya son las pantallas reales, no las maquetas de G4.
            expect(provisional, findsNothing, reason: d.name);
            expect(
              find.textContaining('Pantalla provisional'),
              findsNothing,
              reason: d.name,
            );
            expect(find.text(d.titulo), findsWidgets, reason: d.name);
          }
          // Se sale de la sesión en curso (tiene un temporizador): sin pendientes.
          await irA(tester, Rutas.ajustes);
        },
      );
    }

    for (final rol in [Rol.cuidador, Rol.casa]) {
      testWidgets(
        '${rol.name}: ninguna pantalla de Mi gimnasio; vuelve a su inicio',
        (tester) async {
          await montarApp(
            tester,
            dispositivo: rol == Rol.casa
                ? TipoDispositivo.tablet
                : TipoDispositivo.telefono,
            sesion: sesionCon(rol),
          );
          for (final d in DestinoGimnasio.values) {
            await irA(tester, d.ruta);
            expect(
              ubicacion(tester),
              isNot(startsWith('${Rutas.habitos}/')),
              reason: d.name,
            );
            expect(provisional, findsNothing, reason: d.name);
          }
        },
      );
    }

    testWidgets(
      'laptop: el dueño ve planear y revisar; las molestias no están aquí',
      (tester) async {
        await montarApp(
          tester,
          dispositivo: TipoDispositivo.laptop,
          sesion: sesionCon(Rol.dueno),
        );
        for (final d in [
          DestinoGimnasio.inventario,
          DestinoGimnasio.plan,
          DestinoGimnasio.historial,
          DestinoGimnasio.records,
          DestinoGimnasio.ajustes,
        ]) {
          await irA(tester, d.ruta);
          expect(ubicacion(tester), d.ruta, reason: d.name);
        }
        await irA(tester, RutasGimnasio.molestias);
        expect(ubicacion(tester), RutasGimnasio.hoy);
        expect(
          find.byKey(const ValueKey('molestias-otro-equipo')),
          findsNothing,
        );
      },
    );
  });

  group('tablet de la casa (pública) con nombre y PIN', () {
    Future<void> entrar(WidgetTester tester) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.tablet,
        sesion: sesionCon(Rol.casa),
        almacen: await almacenConPersonas({Rol.dueno: '246813'}),
      );
      await tester.tap(find.text(nombreDueno));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('campo-pin')), '246813');
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      've Entrenamiento de hoy y la sesión; nunca molestias ni planear',
      (tester) async {
        await entrar(tester);
        for (final d in [
          DestinoGimnasio.hoy,
          DestinoGimnasio.sesion,
          DestinoGimnasio.sesionEnCurso,
        ]) {
          await irA(tester, d.ruta);
          expect(ubicacion(tester), d.ruta, reason: d.name);
        }
        for (final d in [
          DestinoGimnasio.molestias,
          DestinoGimnasio.inventario,
          DestinoGimnasio.plan,
          DestinoGimnasio.registro,
          DestinoGimnasio.historial,
          DestinoGimnasio.records,
          DestinoGimnasio.ajustes,
        ]) {
          await irA(tester, d.ruta);
          expect(ubicacion(tester), RutasGimnasio.hoy, reason: d.name);
        }
        // Ni siquiera construye la pantalla de molestias.
        expect(
          find.byKey(const ValueKey('molestias-otro-equipo')),
          findsNothing,
        );
        await irA(tester, Rutas.ajustes);
      },
    );
  });

  group('tablet personal', () {
    testWidgets(
      'con su PIN el dueño abre también las molestias (de este equipo)',
      (tester) async {
        await montarApp(
          tester,
          dispositivo: TipoDispositivo.tablet,
          sesion: sesionCon(Rol.casa),
          almacen: await almacenConPersonas(
            {Rol.dueno: '246813'},
            configuracion: ConfiguracionTablet(
              tipo: TipoTablet.personal,
              permitidas: {sesionDeEjemplo(Rol.dueno).persona.id},
            ),
          ),
        );
        await tester.tap(find.text(nombreDueno));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('campo-pin')), '246813');
        await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
        await tester.pumpAndSettle();
        await irA(tester, RutasGimnasio.molestias);
        expect(ubicacion(tester), RutasGimnasio.molestias);
        // G5: la pantalla real de molestias (no la maqueta provisional).
        expect(provisional, findsNothing);
        expect(find.text(DestinoGimnasio.molestias.titulo), findsWidgets);
        expect(
          find.byKey(const ValueKey('molestias-otro-equipo')),
          findsNothing,
        );
      },
    );
  });

  group('ProtegerMolestias: FLAG_SECURE, modo privado y otros equipos', () {
    late ProtectorRegistrador protector;

    Future<ProviderContainer> montar(
      WidgetTester tester,
      TipoEquipoAvisos equipo,
    ) async {
      protector = ProtectorRegistrador();
      late ProviderContainer contenedor;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tipoEquipoAvisosProvider.overrideWithValue(equipo),
            protectorDePantallaProvider.overrideWithValue(protector),
            almacenSeguroProvider.overrideWithValue(AlmacenSeguroEnMemoria()),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              contenedor = ProviderScope.containerOf(context);
              return const MaterialApp(
                home: ProtegerMolestias(
                  child: Scaffold(body: Text('PANTALLA DE MOLESTIAS')),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();
      return contenedor;
    }

    testWidgets(
      'en el teléfono: pide FLAG_SECURE mientras está a la vista y lo suelta al salir',
      (tester) async {
        final c = await montar(tester, TipoEquipoAvisos.telefono);
        final controlador = c.read(controladorPantallaSeguraProvider);
        await controlador.aplicado;
        expect(find.text('PANTALLA DE MOLESTIAS'), findsOneWidget);
        expect(protector.segura, isTrue);
        await tester.pumpWidget(const SizedBox());
        await controlador.aplicado;
        expect(protector.segura, isFalse);
      },
    );

    testWidgets(
      'modo privado: oculta el contenido y se vuelve a ver al quitarlo',
      (tester) async {
        final c = await montar(tester, TipoEquipoAvisos.tabletPersonal);
        expect(find.text('PANTALLA DE MOLESTIAS'), findsOneWidget);
        c.read(modoPrivadoProvider.notifier).fijar(true);
        await tester.pump();
        expect(find.text('PANTALLA DE MOLESTIAS'), findsNothing);
        expect(find.text(textoMolestiasOcultas), findsOneWidget);
        c.read(modoPrivadoProvider.notifier).fijar(false);
        await tester.pump();
        expect(find.text('PANTALLA DE MOLESTIAS'), findsOneWidget);
      },
    );

    for (final equipo in [
      TipoEquipoAvisos.tabletPublica,
      TipoEquipoAvisos.laptop,
    ]) {
      testWidgets(
        '${equipo.name}: no construye la pantalla y dice dónde están',
        (tester) async {
          await montar(tester, equipo);
          expect(find.text('PANTALLA DE MOLESTIAS'), findsNothing);
          expect(find.text(TextosGimnasio.molestiaOtroEquipo), findsOneWidget);
          expect(
            TextosGimnasio.molestiaOtroEquipo,
            'Las molestias están solo en tu teléfono; aquí no se tienen en cuenta.',
          );
        },
      );
    }
  });

  group('la ruta de molestias pide FLAG_SECURE en la app', () {
    testWidgets('dueño en el teléfono: se protege solo en molestias', (
      tester,
    ) async {
      final protector = ProtectorRegistrador();
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: sesionCon(Rol.familiar), // Hoy del familiar no se protege
        extras: [protectorDePantallaProvider.overrideWithValue(protector)],
      );
      final c = ProviderScope.containerOf(
        tester.element(find.byType(AppGravity)),
      );
      await irA(tester, DestinoGimnasio.historial.ruta);
      await c.read(controladorPantallaSeguraProvider).aplicado;
      expect(
        protector.segura,
        isFalse,
        reason: 'el historial se puede capturar',
      );
      await irA(tester, RutasGimnasio.molestias);
      await c.read(controladorPantallaSeguraProvider).aplicado;
      expect(protector.segura, isTrue, reason: 'las molestias, no');
      await irA(tester, DestinoGimnasio.plan.ruta);
      await c.read(controladorPantallaSeguraProvider).aplicado;
      expect(protector.segura, isFalse);
    });
  });

  group('el modo Casa ya no dice que Hábitos no está en la tablet (H-15)', () {
    test('ninguna tarjeta dice «Todavía no está en la tablet de la casa» ni «Hábitos es personal»', () {
      for (final e in tarjetasPorContexto.entries) {
        for (final (titulo, detalle) in e.value) {
          for (final texto in [titulo, detalle]) {
            expect(
              texto,
              isNot(contains('Todavía no está en la tablet de la casa')),
              reason: e.key,
            );
            expect(
              texto,
              isNot(contains('Hábitos es personal')),
              reason: e.key,
            );
          }
        }
      }
    });

    test('la tarjeta del gimnasio manda a nombre y PIN y dice dónde están las molestias', () {
      final tarjetas = tarjetasPorContexto['gimnasio']!;
      expect(tarjetas.map((t) => t.$1), contains('Serie y descanso'));
      final detalle = tarjetas.map((t) => t.$2).join(' ');
      expect(detalle, contains('PIN'));
      expect(detalle, contains('molestias están solo en tu teléfono'));
    });

    testWidgets(
      'en la tablet de la casa, contexto Gimnasio: se ve la tarjeta nueva',
      (tester) async {
        await montarApp(
          tester,
          dispositivo: TipoDispositivo.tablet,
          sesion: sesionCon(Rol.casa),
          almacen: await almacenConPersonas({Rol.dueno: '246813'}),
        );
        await tester.tap(find.widgetWithText(ChoiceChip, 'Gimnasio'));
        await tester.pumpAndSettle();
        expect(find.text('Serie y descanso'), findsOneWidget);
        expect(
          find.textContaining('Todavía no está en la tablet de la casa'),
          findsNothing,
        );
        expect(find.textContaining('Hábitos es personal'), findsNothing);
        expect(find.textContaining('escribe tu PIN'), findsOneWidget);
      },
    );
  });
}
