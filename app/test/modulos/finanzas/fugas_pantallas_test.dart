// Fase 8, bloque 6 (F8-6.10): pantallas de fugas silenciosas y deuda buena o
// mala, en teléfono y laptop. Montos ocultos (también en las etiquetas de
// accesibilidad), letra al 200 %, sin permiso de escribir (sin botones), sin
// señal, «No es así» y cancelar con folio, tarjeta «Revisa un cobro», etiqueta
// de deuda con semáforo y texto, vista previa de un MSI nuevo, registro con
// comercio y avisos. Datos de ejemplo inventados; hoy: martes 20/oct/2026.
import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide Semaforo, formatearCentavos, TipoLibro, puntosBaseEnCien;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/diseno/diseno.dart'
    show TecladoMonto, montosVisiblesProvider;
import 'package:gravity/diseno/proveedores.dart' show RelojFijo;
import 'package:gravity/modulos/finanzas/casos_uso/servicio_fase2.dart';
import 'package:gravity/modulos/finanzas/casos_uso/servicio_finanzas.dart';
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_fugas.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_memoria.dart';
import 'package:gravity/modulos/finanzas/estado/proveedores.dart';
import 'package:gravity/modulos/finanzas/estado/proveedores_fugas.dart';
import 'package:gravity/modulos/finanzas/finanzas.dart' show SeccionFinanzas;
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart'
    show ServicioSesionDemostracion, hogarDeEjemplo;
import 'package:gravity/nucleo/sesion/sesion.dart';

import '../../app/ayuda_plataforma.dart';
import '../../revision_calidad/ayuda_calidad.dart';
import 'ayuda_finanzas.dart';

const _libro = IdsDemostracion.libroDueno;

class _Pantalla {
  _Pantalla(this.repo, this.base, this.contenedor);

  final RepositorioFinanzasEnMemoria repo;
  final ServicioFinanzas base;
  final ProviderContainer contenedor;

  DatosFinanzas get datos => repo.datos;
  RepositorioFugasEnMemoria get fugas =>
      contenedor.read(repositorioFugasProvider) as RepositorioFugasEnMemoria;

  String subcategoria(String nombre) =>
      datos.categorias.firstWhere((c) => c.nombre == nombre).id;

  String get banco =>
      datos.cuentasDe(_libro).firstWhere((c) => c.tipo == TipoCuenta.banco).id;

  /// Diez gastos de $45 en «Salidas»: una hormiga.
  Future<void> hormigas() async {
    for (final d in [
      Fecha(2026, 9, 22),
      Fecha(2026, 9, 24),
      Fecha(2026, 9, 29),
      Fecha(2026, 9, 30),
      Fecha(2026, 10, 1),
      Fecha(2026, 10, 6),
      Fecha(2026, 10, 8),
      Fecha(2026, 10, 13),
      Fecha(2026, 10, 15),
      Fecha(2026, 10, 17),
    ]) {
      await base.registrarGasto(
        libroId: _libro,
        cuentaOrigenId: banco,
        lineas: [LineaGasto(monto: 4500, categoriaId: subcategoria('Salidas'))],
        fecha: d,
      );
    }
  }

  /// Tres cobros mensuales de $89 con cargo automático: un fantasma por
  /// reconocer.
  Future<void> suscripcion([String comercio = 'Streamix']) async {
    for (final f in [
      Fecha(2026, 8, 5),
      Fecha(2026, 9, 5),
      Fecha(2026, 10, 5),
    ]) {
      await base.registrarGasto(
        libroId: _libro,
        cuentaOrigenId: banco,
        lineas: [
          LineaGasto(
            monto: 8900,
            categoriaId: subcategoria('Streaming y suscripciones'),
          ),
        ],
        fecha: f,
        comercio: comercio,
        cobroAutomatico: true,
      );
    }
  }

  String claveDe(TipoFuga t) => contenedor
      .read(servicioFugasProvider)
      .analizar(_libro)
      .resultado
      .todas
      .firstWhere((f) => f.fuga == t)
      .clave;

  String get clavePorReconocer => contenedor
      .read(servicioFugasProvider)
      .analizar(_libro)
      .porReconocer
      .single
      .clave;
}

Future<_Pantalla> _montar(
  WidgetTester tester, {
  required TipoDispositivo dispositivo,
  required Size tamano,
  double letra = 1.0,
  Sesion? sesion,
  Future<void> Function(_Pantalla)? preparar,
  bool montosVisibles = true,
}) async {
  final s = sesion ?? sesionDe(Rol.dueno);
  final repo = repositorioDe(s);
  addTearDown(repo.cerrar);
  tester.platformDispatcher.textScaleFactorTestValue = letra;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await montarApp(
    tester,
    dispositivo: dispositivo,
    sesion: ServicioSesionDemostracion(inicial: s),
    reloj: RelojFijo(DateTime(2026, 10, 20, 10)),
    extras: [repositorioFinanzasProvider.overrideWithValue(repo)],
  );
  tester.view.physicalSize = tamano;
  await tester.pump();
  await avanzar(tester);
  final contenedor = ProviderScope.containerOf(
    tester.element(find.byType(AppGravity)),
  );
  // Quien prepara los datos escribe como la persona de la sesión (aunque sea
  // la cuenta maestra, que en la app solo lee).
  final base = ServicioFinanzas(
    repositorio: repo,
    personaId: s.persona.id,
    hogarId: s.hogarId ?? hogarDeEjemplo,
    esDueno: s.rol == Rol.dueno,
    reloj: () => ahoraDePrueba,
  );
  final p = _Pantalla(repo, base, contenedor);
  if (preparar != null) {
    await preparar(p);
    await avanzar(tester);
  }
  contenedor.read(montosVisiblesProvider.notifier).fijar(montosVisibles);
  await tester.pump();
  return p;
}

Future<void> _tocar(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(f);
  await avanzar(tester);
}

/// Todos los textos y etiquetas de accesibilidad de lo que se ve.
Iterable<String> _textosVisibles(WidgetTester tester) => [
  for (final t in tester.widgetList<Text>(find.byType(Text)))
    t.data ?? t.textSpan?.toPlainText() ?? '',
];

Future<void> _teclear(WidgetTester tester, String digitos) async {
  for (final d in digitos.split('')) {
    await tester.tap(
      find.descendant(of: find.byType(TecladoMonto), matching: find.text(d)),
    );
  }
  await tester.pump();
}

/// Elige la primera cuenta para pagar si la hoja no preseleccionó una.
Future<void> _elegirCuenta(WidgetTester tester) async {
  final chips = tester
      .widgetList<ChoiceChip>(
        find.byWidgetPredicate(
          (w) =>
              w is ChoiceChip &&
              '${w.key}'.contains('gasto-cuenta-') &&
              !'${w.key}'.contains('nueva'),
        ),
      )
      .toList();
  if (chips.any((c) => c.selected) || chips.isEmpty) return;
  await tester.tap(find.byKey(chips.first.key!));
  await tester.pump();
}

final _cifra = RegExp(r'\d[\d,]*\.\d{2}');

void main() {
  for (final e in {
    // Altos para que la lista perezosa construya todo (no cambia el ancho).
    'teléfono': (TipoDispositivo.telefono, const Size(360, 3200)),
    'laptop': (TipoDispositivo.laptop, const Size(1200, 2600)),
  }.entries) {
    final dispositivo = e.value.$1;
    final tamano = e.value.$2;

    group('Pantalla «Fugas» en ${e.key}', () {
      Future<_Pantalla> montar(
        WidgetTester tester, {
        double letra = 1.0,
        Sesion? sesion,
        bool visibles = true,
        bool datos = true,
        Future<void> Function(_Pantalla)? preparar,
      }) async {
        final p = await _montar(
          tester,
          dispositivo: dispositivo,
          tamano: tamano,
          letra: letra,
          sesion: sesion,
          montosVisibles: visibles,
          preparar: (p) async {
            if (datos) {
              await p.hormigas();
              await p.suscripcion();
            }
            await preparar?.call(p);
          },
        );
        await irA(tester, SeccionFinanzas.fugas.ruta);
        return p;
      }

      testWidgets('el resumen muestra las cuatro fugas; la hormiga cuenta '
          'las compras del MISMO conjunto de su total (H-04)', (tester) async {
        await montar(tester);
        for (final t in ['hormiga', 'fantasma', 'vampiro', 'zombie']) {
          expect(find.byKey(ValueKey('fugas-resumen-$t')), findsOneWidget);
        }
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('fugas-conteo-hormiga')))
              .data,
          '10 compras',
        );
        // El fantasma candidato espera respuesta: no cuenta ni acusa.
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('fugas-conteo-fantasma')))
              .data,
          'Nada por ahora',
        );
        expect(
          find.byKey(const ValueKey('fugas-por-reconocer')),
          findsOneWidget,
        );
        expect(
          find.textContaining('Todavía no cuenta como fuga'),
          findsOneWidget,
        );
        // La fila de la hormiga dice lo mismo: 10 compras y la regla.
        final f = find.byKey(const ValueKey('fugas-seccion-hormiga'));
        await tester.ensureVisible(f);
        expect(
          find.descendant(of: f, matching: find.textContaining('10 compras')),
          findsOneWidget,
        );
        expect(find.textContaining('Regla H'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('estado vacío claro y sin acusar cuando no hay nada', (
        tester,
      ) async {
        await montar(tester, datos: false);
        expect(find.byKey(const ValueKey('fugas-vacio')), findsOneWidget);
        expect(
          find.text('Por ahora no veo nada que se esté yendo en silencio.'),
          findsOneWidget,
        );
        expect(find.textContaining('Comercio'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('«No lo conocía» confirma el fantasma y su fila ofrece '
          'cancelar y «No es así»; reconocerlo lo saca de la lista', (
        tester,
      ) async {
        final p = await montar(tester);
        final clave = p.clavePorReconocer;
        await _tocar(tester, find.byKey(ValueKey('fuga-reconoce-no-$clave')));
        expect(find.byKey(const ValueKey('fugas-por-reconocer')), findsNothing);
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('fugas-conteo-fantasma')))
              .data,
          '1 cobro',
        );
        expect(find.byKey(ValueKey('fuga-cancele-$clave')), findsOneWidget);
        expect(find.byKey(ValueKey('fuga-no-es-asi-$clave')), findsOneWidget);
        expect(find.byKey(ValueKey('fuga-reconocer-$clave')), findsOneWidget);
        await _tocar(tester, find.byKey(ValueKey('fuga-reconocer-$clave')));
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('fugas-conteo-fantasma')))
              .data,
          'Nada por ahora',
        );
      });

      testWidgets('«No es así»: cuatro opciones; «Lo necesito» guarda en dos '
          'toques; «No es una fuga» exige motivo', (tester) async {
        final p = await montar(tester);
        final clave = p.clavePorReconocer;
        await _tocar(tester, find.byKey(ValueKey('fuga-reconoce-no-$clave')));
        await _tocar(tester, find.byKey(ValueKey('fuga-no-es-asi-$clave')));
        for (final o in ['ninguna', 'otro', 'cancelar', 'vigilar']) {
          expect(find.byKey(ValueKey('noesasi-$o')), findsOneWidget, reason: o);
        }
        // «No es una fuga» sin motivo: Guardar apagado.
        await tester.tap(find.byKey(const ValueKey('noesasi-ninguna')));
        await tester.pump();
        FilledButton guardar() => tester.widget<FilledButton>(
          find.byKey(const ValueKey('noesasi-guardar')),
        );
        expect(guardar().onPressed, isNull);
        await tester.enterText(
          find.byKey(const ValueKey('noesasi-motivo')),
          'Lo uso para trabajar',
        );
        await tester.pump();
        expect(guardar().onPressed, isNotNull);
        await tester.tap(find.byKey(const ValueKey('noesasi-guardar')));
        await avanzar(tester);
        expect(p.fugas.actuales.clasificaciones, hasLength(1));
        expect(p.fugas.actuales.clasificaciones.single.fuga, TipoFuga.ninguna);
        // El patrón dejó de ser fuga.
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('fugas-conteo-fantasma')))
              .data,
          'Nada por ahora',
        );
      });

      testWidgets('«Lo necesito pero quiero revisarlo» guarda con dos toques '
          'en total, sin motivo', (tester) async {
        final p = await montar(tester);
        final clave = p.claveDe(TipoFuga.hormiga);
        await _tocar(tester, find.byKey(ValueKey('fuga-no-es-asi-$clave')));
        // La hormiga no es un cobro recurrente: no hay «Lo cancelé».
        expect(find.byKey(const ValueKey('noesasi-cancelar')), findsNothing);
        expect(find.byKey(const ValueKey('noesasi-vigilar')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('noesasi-vigilar')));
        await avanzar(tester);
        expect(p.fugas.actuales.clasificaciones.single.vigilar, isTrue);
        expect(
          find.byKey(const ValueKey('fugas-en-vigilancia')),
          findsOneWidget,
        );
      });

      testWidgets('«Ya lo cancelé»: un folio inválido no deja guardar; sin '
          'folio queda «cancelado sin folio»; luego se completa', (
        tester,
      ) async {
        final p = await montar(tester);
        final clave = p.clavePorReconocer;
        await _tocar(tester, find.byKey(ValueKey('fuga-reconoce-no-$clave')));
        await _tocar(tester, find.byKey(ValueKey('fuga-cancele-$clave')));
        expect(find.byKey(const ValueKey('cancelacion-hoja')), findsOneWidget);
        expect(
          find.textContaining('guarda el folio de cancelación'),
          findsOneWidget,
        );
        // Los caracteres que no valen ni se escriben (el filtro los quita).
        await tester.enterText(
          find.byKey(const ValueKey('cancelacion-folio')),
          'ABC 123',
        );
        await tester.pump();
        expect(
          tester
              .widget<TextField>(
                find.byKey(const ValueKey('cancelacion-folio')),
              )
              .controller!
              .text,
          'ABC123',
        );
        await tester.enterText(
          find.byKey(const ValueKey('cancelacion-folio')),
          '',
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('cancelacion-guardar')));
        await avanzar(tester);
        expect(
          p.fugas.actuales.patrones.single.canceladoSinFolio,
          isTrue,
          reason: 'sin folio se guarda como cancelado sin folio',
        );
        expect(find.byKey(const ValueKey('fugas-cancelados')), findsOneWidget);
        // Completar el folio.
        await _tocar(tester, find.byKey(ValueKey('fuga-agregar-folio-$clave')));
        await tester.enterText(
          find.byKey(const ValueKey('cancelacion-folio')),
          'ABC-123',
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('cancelacion-guardar')));
        await avanzar(tester);
        final patron = p.fugas.actuales.patrones.single;
        expect(patron.folio, 'ABC-123');
        expect(patron.canceladoSinFolio, isFalse);
        expect(find.byKey(const ValueKey('fugas-cancelados')), findsNothing);
      });

      testWidgets('sin señal lo dice, no cambia nada y la tarjeta sigue '
          'ahí', (tester) async {
        final p = await montar(tester);
        final clave = p.clavePorReconocer;
        p.fugas.falla = ErrorFinanzas.conexion;
        await _tocar(tester, find.byKey(ValueKey('fuga-reconoce-no-$clave')));
        expect(find.textContaining('Sin conexión'), findsOneWidget);
        expect(p.fugas.actuales.respuestas, isEmpty);
        expect(
          find.byKey(const ValueKey('fugas-por-reconocer')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('revisión mensual: una pregunta a la vez, con «Después» y '
          '«Saltar»', (tester) async {
        final p = await montar(
          tester,
          preparar: (p) => p.suscripcion('Musicafé'),
        );
        expect(p.contenedor.read(preguntasPendientesProvider), 2);
        await _tocar(tester, find.byKey(const ValueKey('revisa-ver-todas')));
        expect(find.byKey(const ValueKey('revision-hoja')), findsOneWidget);
        expect(find.text('Pregunta 1 de 2'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('revision-despues')));
        await avanzar(tester);
        expect(find.text('Pregunta 2 de 2'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('revision-saltar')));
        await avanzar(tester);
        expect(find.byKey(const ValueKey('revision-listo')), findsOneWidget);
        // «Después» quedó registrado; «Saltar» no cambió nada.
        expect(p.fugas.actuales.respuestas, hasLength(1));
        expect(
          p.fugas.actuales.respuestas.single.respuesta,
          RespuestaPersona.despues,
        );
        await tester.tap(find.byKey(const ValueKey('revision-cerrar')));
        await avanzar(tester);
      });

      testWidgets('montos ocultos: ni una cifra, ni en el texto ni en la '
          'etiqueta de accesibilidad; visibles, sí hay cifras', (tester) async {
        final semantica = tester.ensureSemantics();
        await montar(tester, visibles: false);
        final raiz = find.byKey(const ValueKey('fugas-lista'));
        for (final t in _textosVisibles(tester)) {
          expect(t, isNot(contains(r'$')), reason: t);
          expect(t, isNot(matches(_cifra)), reason: t);
        }
        final s = tester.getSemantics(raiz);
        final etiquetas = <String>[];
        void recorre(SemanticsNode n) {
          etiquetas.add(n.label);
          n.visitChildren((h) {
            recorre(h);
            return true;
          });
        }

        recorre(s);
        for (final et in etiquetas) {
          expect(et, isNot(contains(r'$')), reason: et);
          expect(et, isNot(matches(_cifra)), reason: et);
        }
        tester.view.physicalSize = tamano;
        final c = ProviderScope.containerOf(
          tester.element(find.byType(AppGravity)),
        );
        c.read(montosVisiblesProvider.notifier).fijar(true);
        await tester.pump();
        expect(
          _textosVisibles(tester).any((t) => t.contains(r'$')),
          isTrue,
          reason: 'visibles, los montos aparecen',
        );
        semantica.dispose();
      });

      testWidgets('letra al 200 %: sin desbordes y las acciones siguen a la '
          'vista', (tester) async {
        final p = await montar(tester, letra: 2.0);
        final clave = p.clavePorReconocer;
        final errores = await recolectar(() async {
          for (final k in [
            'fugas-resumen-hormiga',
            'fugas-por-reconocer',
            'fugas-seccion-hormiga',
          ]) {
            await tester.ensureVisible(find.byKey(ValueKey(k)));
            await tester.pump();
          }
        });
        expect(
          errores.desbordes,
          isEmpty,
          reason: errores.desbordes.join('\n'),
        );
        expect(find.byKey(ValueKey('fuga-reconoce-si-$clave')), findsOneWidget);
      });

      testWidgets('la cuenta maestra (solo lectura) ve las fugas pero no hay '
          'un solo botón para escribir', (tester) async {
        final p = await montar(
          tester,
          sesion: sesionParejaMaestra(),
          // La pareja lleva su libro: los datos van en el suyo.
          datos: false,
          preparar: (_) async {},
        );
        // Datos en el libro de la pareja.
        final libro = IdsDemostracion.libroPareja;
        final banco = p.datos
            .cuentasDe(libro)
            .firstWhere((c) => c.tipo == TipoCuenta.banco)
            .id;
        final sub = p.subcategoria('Streaming y suscripciones');
        for (final f in [
          Fecha(2026, 8, 5),
          Fecha(2026, 9, 5),
          Fecha(2026, 10, 5),
        ]) {
          await p.base.registrarGasto(
            libroId: libro,
            cuentaOrigenId: banco,
            lineas: [LineaGasto(monto: 8900, categoriaId: sub)],
            fecha: f,
            comercio: 'Streamix',
            cobroAutomatico: true,
          );
        }
        await avanzar(tester);
        await irA(tester, SeccionFinanzas.fugas.ruta);
        expect(
          find.byKey(const ValueKey('fugas-solo-lectura')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('fugas-por-reconocer')),
          findsOneWidget,
        );
        expect(find.byType(OutlinedButton), findsNothing);
        expect(find.byType(FilledButton), findsNothing);
        expect(find.textContaining('Quien lleva este libro'), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    });
  }

  group('«Revisa un cobro» en el teléfono', () {
    testWidgets('una pregunta con dos botones grandes; contestar la quita; '
        'sin cifras', (tester) async {
      final semantica = tester.ensureSemantics();
      final p = await _montar(
        tester,
        dispositivo: TipoDispositivo.telefono,
        tamano: const Size(360, 800),
        preparar: (p) => p.suscripcion(),
        montosVisibles: true,
      );
      await irA(tester, SeccionFinanzas.semana.ruta);
      final tarjeta = find.byKey(const ValueKey('fugas-revisa-cobro'));
      expect(tarjeta, findsOneWidget);
      expect(find.byKey(const ValueKey('revisa-si')), findsOneWidget);
      expect(find.byKey(const ValueKey('revisa-no')), findsOneWidget);
      expect(find.text('Sí, lo conozco'), findsOneWidget);
      expect(
        find.descendant(of: tarjeta, matching: find.textContaining(r'$')),
        findsNothing,
      );
      final s = tester.getSemantics(tarjeta);
      expect(s.label, isNot(contains(r'$')));
      expect(s.label, isNot(matches(_cifra)));
      await tester.tap(find.byKey(const ValueKey('revisa-si')));
      await avanzar(tester);
      expect(p.fugas.actuales.respuestas.single.respuesta, RespuestaPersona.si);
      // Reconocido: lo siguiente es preguntar el uso.
      expect(find.text('¿Lo usaste este mes?'), findsOneWidget);
      expect(find.text('Lo usé'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('revisa-si')));
      await avanzar(tester);
      expect(find.byKey(const ValueKey('fugas-revisa-cobro')), findsNothing);
      semantica.dispose();
    });

    testWidgets('sin preguntas no hay tarjeta', (tester) async {
      await _montar(
        tester,
        dispositivo: TipoDispositivo.telefono,
        tamano: const Size(360, 800),
      );
      await irA(tester, SeccionFinanzas.semana.ruta);
      expect(find.byKey(const ValueKey('fugas-revisa-cobro')), findsNothing);
    });

    testWidgets('el teléfono tiene los accesos a Deudas y a Fugas', (
      tester,
    ) async {
      await _montar(
        tester,
        dispositivo: TipoDispositivo.telefono,
        tamano: const Size(360, 2600),
      );
      await irA(tester, SeccionFinanzas.semana.ruta);
      await tester.ensureVisible(
        find.byKey(const ValueKey('finanzas-ver-fugas')),
      );
      expect(find.byKey(const ValueKey('finanzas-ver-deudas')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('finanzas-ver-fugas')));
      await avanzar(tester);
      expect(find.byKey(const ValueKey('fugas-titulo')), findsOneWidget);
    });
  });

  group('Avisos al abrir el libro (D20)', () {
    testWidgets('al abrir Finanzas salen los avisos de fugas, sin cifras ni '
        'comercios', (tester) async {
      final p = await _montar(
        tester,
        dispositivo: TipoDispositivo.laptop,
        tamano: const Size(1200, 2600),
        preparar: (p) => p.suscripcion('Streamix'),
      );
      await irA(tester, SeccionFinanzas.tablero.ruta);
      await avanzar(tester);
      final tipos = p.repo.avisosEmitidos.map((a) => a.tipo).toSet();
      expect(tipos, contains('fuga_por_reconocer'));
      expect(tipos, contains('fuga_revision_mensual'));
      for (final a in p.repo.avisosEmitidos) {
        expect(a.clave, isNot(contains('streamix')));
        expect(a.clave, isNot(matches(RegExp(r'\d{3,}\.\d'))));
      }
    });
  });

  group('Deudas: buena o mala', () {
    Future<(_Pantalla, Msi)> conMsi(
      WidgetTester tester, {
      required TipoDispositivo dispositivo,
      required Size tamano,
      bool visibles = true,
      double letra = 1.0,
      Sesion? sesion,
    }) async {
      late Msi compra;
      final p = await _montar(
        tester,
        dispositivo: dispositivo,
        tamano: tamano,
        montosVisibles: visibles,
        letra: letra,
        sesion: sesion,
        preparar: (p) async {
          compra = await ServicioDeudasAhorro(p.base).crearMsi(
            libroId: _libro,
            comercio: 'Laptop',
            total: 120000,
            meses: 12,
            fechaCompra: Fecha(2026, 10, 19),
            diaPago: 28,
          );
        },
      );
      await irA(tester, SeccionFinanzas.deudas.ruta);
      return (p, compra);
    }

    testWidgets('laptop: la etiqueta dice «Por declarar» con texto; declarar '
        'el propósito la vuelve «Deuda buena»; el gadget de MSI está', (
      tester,
    ) async {
      final (p, compra) = await conMsi(
        tester,
        dispositivo: TipoDispositivo.laptop,
        tamano: const Size(1200, 2600),
      );
      final etiqueta = find.byKey(
        ValueKey('calidad-etiqueta-${compra.deudaId}'),
      );
      await tester.ensureVisible(etiqueta);
      expect(
        find.descendant(of: etiqueta, matching: find.text('Por declarar')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('deudas-gadget-msi')), findsOneWidget);
      expect(find.byKey(const ValueKey('msi-barra')), findsOneWidget);
      // Declarar.
      await _tocar(tester, find.byKey(ValueKey('declarar-${compra.deudaId}')));
      expect(find.byKey(const ValueKey('proposito-hoja')), findsOneWidget);
      // El objetivo no lleva cifras.
      await tester.enterText(
        find.byKey(const ValueKey('proposito-objetivo')),
        'Laptop 2026',
      );
      await tester.pump();
      expect(find.text('El objetivo no lleva cifras'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('proposito-guardar')),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const ValueKey('proposito-objetivo')),
        'Herramienta de trabajo',
      );
      await tester.pump();
      // Propósito: herramienta de trabajo.
      await tester.tap(find.byKey(const ValueKey('proposito-tipo')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Herramienta de trabajo o negocio').last);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(
        find.byKey(const ValueKey('proposito-vida')),
        '48',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('proposito-guardar')));
      await avanzar(tester);
      expect(p.fugas.actuales.propositos, hasLength(1));
      expect(
        p.fugas.actuales.propositos.single.declaracion.proposito,
        PropositoDeuda.generaIngreso,
      );
      await tester.ensureVisible(etiqueta);
      expect(
        find.descendant(of: etiqueta, matching: find.text('Por declarar')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: etiqueta,
          matching: find.textContaining('Deuda buena'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('teléfono: etiqueta y texto, pero sin formulario de '
        'propósito (se declara en la laptop)', (tester) async {
      final (_, compra) = await conMsi(
        tester,
        dispositivo: TipoDispositivo.telefono,
        tamano: const Size(360, 3200),
      );
      final etiqueta = find.byKey(
        ValueKey('calidad-etiqueta-${compra.deudaId}'),
      );
      await tester.ensureVisible(etiqueta);
      expect(find.text('Por declarar'), findsOneWidget);
      expect(
        find.byKey(ValueKey('calidad-declara-laptop-${compra.deudaId}')),
        findsOneWidget,
      );
      expect(find.byKey(ValueKey('declarar-${compra.deudaId}')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final e in {
      'teléfono': (TipoDispositivo.telefono, const Size(360, 3200)),
      'laptop': (TipoDispositivo.laptop, const Size(1200, 2600)),
    }.entries) {
      testWidgets('${e.key}: con los montos ocultos el gadget y la etiqueta '
          'no dicen porcentajes ni cifras (ni en accesibilidad)', (
        tester,
      ) async {
        final semantica = tester.ensureSemantics();
        final (_, compra) = await conMsi(
          tester,
          dispositivo: e.value.$1,
          tamano: e.value.$2,
          visibles: false,
        );
        final gadget = find.byKey(const ValueKey('deudas-gadget-msi'));
        await tester.ensureVisible(gadget);
        final texto = tester.widget<Text>(
          find.byKey(const ValueKey('msi-texto')),
        );
        expect(texto.data, isNot(contains('%')));
        expect(texto.data, contains('Muestra los montos'));
        final s = tester.getSemantics(gadget);
        expect(s.label, isNot(contains('%')));
        expect(s.label, isNot(contains(r'$')));
        final et = find.byKey(ValueKey('calidad-texto-${compra.deudaId}'));
        await tester.ensureVisible(et);
        expect(tester.widget<Text>(et).data, isNot(matches(_cifra)));
        semantica.dispose();
      });

      testWidgets('${e.key}: letra al 200 % sin desbordes en la tarjeta de '
          'calidad y el gadget', (tester) async {
        final (_, compra) = await conMsi(
          tester,
          dispositivo: e.value.$1,
          tamano: e.value.$2,
          letra: 2.0,
        );
        final errores = await recolectar(() async {
          await tester.ensureVisible(
            find.byKey(const ValueKey('deudas-gadget-msi')),
          );
          await tester.pump();
          await tester.ensureVisible(
            find.byKey(ValueKey('calidad-${compra.deudaId}')),
          );
          await tester.pump();
        });
        expect(
          errores.desbordes,
          isEmpty,
          reason: errores.desbordes.join('\n'),
        );
      });
    }

    testWidgets('sin permiso de escribir (la cuenta maestra) ve la etiqueta '
        'pero no el botón de declarar', (tester) async {
      final sesion = sesionParejaMaestra();
      final repoPareja = repositorioDe(sesion);
      addTearDown(repoPareja.cerrar);
      // La pareja lleva su propio libro: se monta con su sesión de solo
      // lectura y una compra a meses de su libro.
      final libro = IdsDemostracion.libroPareja;
      late Msi compra;
      await _montar(
        tester,
        dispositivo: TipoDispositivo.laptop,
        tamano: const Size(1200, 2600),
        sesion: sesion,
        preparar: (p) async {
          compra = await ServicioDeudasAhorro(p.base).crearMsi(
            libroId: libro,
            comercio: 'Laptop',
            total: 120000,
            meses: 12,
            fechaCompra: Fecha(2026, 10, 19),
            diaPago: 28,
          );
        },
      );
      await irA(tester, SeccionFinanzas.deudas.ruta);
      expect(
        find.byKey(ValueKey('calidad-etiqueta-${compra.deudaId}')),
        findsOneWidget,
      );
      expect(find.byKey(ValueKey('declarar-${compra.deudaId}')), findsNothing);
    });

    testWidgets('«Compra a meses»: la vista previa muestra el efecto y se '
        'puede guardar igual, sin confirmación extra (DD-19)', (tester) async {
      final (p, _) = await conMsi(
        tester,
        dispositivo: TipoDispositivo.laptop,
        tamano: const Size(1200, 2600),
      );
      await _tocar(tester, find.byKey(const ValueKey('deudas-nuevo-msi')));
      expect(find.byKey(const ValueKey('msi-vista-previa')), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('msi-comercio')), 'Cel');
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('msi-total')),
          matching: find.byType(TextFormField),
        ),
        '600',
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('msi-vista-previa')), findsOneWidget);
      final texto = tester
          .widget<Text>(find.byKey(const ValueKey('msi-vista-previa-texto')))
          .data!;
      expect(texto, contains('2 a la vez'));
      expect(texto, contains('% de tu ingreso'));
      expect(find.textContaining('Quedaría'), findsOneWidget);
      expect(find.textContaining('Solo es información'), findsOneWidget);
      // Guarda sin pedir nada más.
      final antes = p.datos.msi.length;
      final guardar = find.widgetWithText(FilledButton, 'Guardar');
      await tester.ensureVisible(guardar);
      await tester.tap(guardar);
      await avanzar(tester);
      expect(p.repo.datos.msi.length, antes + 1);
    });

    testWidgets('la vista previa con montos ocultos no dice el porcentaje', (
      tester,
    ) async {
      await conMsi(
        tester,
        dispositivo: TipoDispositivo.laptop,
        tamano: const Size(1200, 2600),
        visibles: false,
      );
      await _tocar(tester, find.byKey(const ValueKey('deudas-nuevo-msi')));
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('msi-total')),
          matching: find.byType(TextFormField),
        ),
        '600',
      );
      await tester.pump();
      final texto = tester
          .widget<Text>(find.byKey(const ValueKey('msi-vista-previa-texto')))
          .data!;
      expect(texto, isNot(contains('%')));
      expect(texto, contains('2 a la vez'));
    });
  });

  group('Registro de un gasto con comercio y cargo automático', () {
    testWidgets('teléfono: sin tocar «Comercio» el gasto se guarda igual '
        '(sin pasos nuevos); con comercio y casilla lleva ambos', (
      tester,
    ) async {
      final p = await _montar(
        tester,
        dispositivo: TipoDispositivo.telefono,
        tamano: const Size(360, 800),
      );
      await irA(tester, SeccionFinanzas.semana.ruta);
      await abrirRegistroDelTelefono(tester, 'Gasto');
      // Opcionales: el comercio y la casilla no están a la vista hasta pedirlos.
      expect(find.byKey(const ValueKey('gasto-comercio')), findsNothing);
      expect(find.byKey(const ValueKey('gasto-con-comercio')), findsOneWidget);
      await _teclear(tester, '50');
      await _elegirCuenta(tester);
      final guardar = find.byKey(const ValueKey('gasto-guardar'));
      await tester.ensureVisible(guardar);
      await tester.tap(guardar);
      await avanzar(tester);
      // El último gasto no lleva comercio ni marca.
      final ultimo = p.datos.movimientos.last;
      expect(ultimo.tipo, TipoMovimiento.gasto);
      expect(ultimo.monto, 5000);
      expect(ultimo.comercio, isNull);
      expect(ultimo.cobroAutomatico, isFalse);
    });

    testWidgets('teléfono: con comercio y «Es un cargo automático»', (
      tester,
    ) async {
      final p = await _montar(
        tester,
        dispositivo: TipoDispositivo.telefono,
        tamano: const Size(360, 800),
      );
      await irA(tester, SeccionFinanzas.semana.ruta);
      await abrirRegistroDelTelefono(tester, 'Gasto');
      await _teclear(tester, '89');
      await _elegirCuenta(tester);
      await _tocar(tester, find.byKey(const ValueKey('gasto-con-comercio')));
      await tester.enterText(
        find.byKey(const ValueKey('gasto-comercio')),
        'Streamix',
      );
      await tester.pump();
      await _tocar(
        tester,
        find.byKey(const ValueKey('gasto-cargo-automatico')),
      );
      final guardar = find.byKey(const ValueKey('gasto-guardar'));
      await tester.ensureVisible(guardar);
      await tester.tap(guardar);
      await avanzar(tester);
      final ultimo = p.datos.movimientos.last;
      expect(ultimo.tipo, TipoMovimiento.gasto);
      expect(ultimo.comercio, 'Streamix');
      expect(ultimo.cobroAutomatico, isTrue);
    });
  });
}
