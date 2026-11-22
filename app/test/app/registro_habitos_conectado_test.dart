// F8-7.1, grupo 1: las opciones Hábito, Consumo y SOS del botón (+) ya no
// dicen "llega en la Fase 3": abren su registro, con las guardias de D3, D13 y
// D21 (reservado detrás de la puerta, nunca en la tablet pública).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/navegacion.dart';
import 'package:gravity/app/pantallas/registro_rapido.dart';
import 'package:gravity/app/sensibles/puerta_reservada.dart';
import 'package:gravity/app/tablet/registro_tablet_casa.dart';
import 'package:gravity/diseno/proveedores.dart'
    show ModoPrivado, modoPrivadoProvider;
import 'package:gravity/modulos/habitos/casos_uso/servicio_eliminar.dart';
import 'package:gravity/modulos/habitos/casos_uso/servicio_habitos.dart';
import 'package:gravity/modulos/habitos/datos/documentos_sensibles.dart';
import 'package:gravity/modulos/habitos/datos/repositorio.dart';
import 'package:gravity/modulos/habitos/estado/proveedores.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/sensibles/llaves_habitos.dart';
import 'package:gravity/nucleo/sensibles/sobres.dart';
import 'package:gravity/nucleo/sensibles/subida_diferida.dart';
import 'package:habitos_dominio/habitos_dominio.dart' show TextosSos;

import 'ayuda_plataforma.dart';
import 'tablet_tipos_test.dart' show contenedorDe, montarPublica, ubicacion;

class _Abierto extends ReservadoAbierto {
  @override
  bool build() => true;
}

class _Modo extends ModoPrivado {
  _Modo(this._valor);
  final bool _valor;
  @override
  bool build() => _valor;
}

void main() {
  final ahora = relojDePrueba.ahora();
  late RepositorioHabitosEnMemoria repo;
  late ServicioHabitos servicio;
  late ServicioHabitoEliminar eliminar;

  setUp(() async {
    repo = RepositorioHabitosEnMemoria();
    servicio = ServicioHabitos(repo, ahora: () => ahora);
    final almacen = AlmacenSeguroEnMemoria();
    eliminar = ServicioHabitoEliminar(
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

  List<Override> extras({
    bool reservadoAbierto = true,
    bool privado = false,
  }) => [
    repositorioHabitosProvider.overrideWithValue(repo),
    servicioHabitosProvider.overrideWithValue(servicio),
    servicioEliminarProvider.overrideWithValue(eliminar),
    if (reservadoAbierto) reservadoAbiertoProvider.overrideWith(_Abierto.new),
    if (privado) modoPrivadoProvider.overrideWith(() => _Modo(true)),
  ];

  Future<void> abrirOpcion(WidgetTester tester, String etiqueta) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Registrar'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(etiqueta));
    await tester.pumpAndSettle();
  }

  group('teléfono del dueño', () {
    testWidgets('ninguna opción dice "llega en la Fase"', (tester) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: sesionCon(Rol.dueno),
        extras: extras(),
      );
      for (final opcion in opcionesDeRegistro) {
        await abrirOpcion(tester, opcion.etiqueta);
        expect(
          find.byKey(llaveRegistro(opcion.tipo)),
          findsOneWidget,
          reason: opcion.etiqueta,
        );
        expect(textoVisible(tester), isNot(contains('llega en la fase')));
        // Cierra la hoja para la siguiente opción.
        await tester.tapAt(const Offset(200, 20));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('SOS abre la pausa en una hoja, detrás de la puerta', (
      tester,
    ) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: sesionCon(Rol.dueno),
        extras: extras(),
      );
      await abrirOpcion(tester, 'SOS: tengo un antojo');
      expect(find.byKey(llaveRegistro(TipoRegistro.sos)), findsOneWidget);
      expect(find.text(TextosSos.pausa), findsOneWidget);
    });

    testWidgets('SOS completo: al terminar cierra la hoja (no navega)', (
      tester,
    ) async {
      await eliminar.configurar(
        ConfigHabito(
          tipo: TipoHabito.cigarrillo,
          inicio: DateTime.utc(2026, 10, 1),
        ),
      );
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: sesionCon(Rol.dueno),
        extras: extras(),
      );
      await abrirOpcion(tester, 'SOS: tengo un antojo');
      Future<void> tocar(Finder f) async {
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      await tocar(find.text('Seguir')); // pausa
      await tocar(find.text('Seguir')); // con qué es el antojo
      expect(find.text(TextosSos.tecnica), findsOneWidget);
      await tocar(find.byType(ListTile).first);
      await tocar(find.text('Empezar'));
      await tocar(find.text('Terminé consumiendo'));
      expect(find.text(TextosSos.cierreConsumo), findsOneWidget);
      await tocar(find.text('Listo'));
      // La hoja se cerró (no navegó): seguimos en la pantalla de debajo.
      expect(find.byKey(llaveRegistro(TipoRegistro.sos)), findsNothing);
      expect(find.text(TextosSos.cierreConsumo), findsNothing);
      expect(ubicacion(tester), Rutas.inicio);

    });

    testWidgets('SOS sin desbloquear lo reservado pide el PIN, no la pausa', (
      tester,
    ) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: sesionCon(Rol.dueno),
        extras: extras(reservadoAbierto: false),
      );
      await abrirOpcion(tester, 'SOS: tengo un antojo');
      expect(find.text(TextosSos.pausa), findsNothing);
      expect(find.byKey(const ValueKey('reservado-pide-pin')), findsOneWidget);
    });

    testWidgets('Hábito: lista lo de hoy y Hecho marca, con Deshacer', (
      tester,
    ) async {
      final objetivo = await servicio.crearObjetivo(
        titulo: 'Beber agua',
        area: 'salud',
        inicio: DateTime(2026, 10, 1),
      );
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: sesionCon(Rol.dueno),
        extras: extras(),
      );
      await abrirOpcion(tester, 'Hábito');
      expect(find.text('Beber agua'), findsOneWidget);
      await tester.tap(find.byTooltip('Hecho'));
      await tester.pumpAndSettle();
      // La hoja se cierra y avisa con Deshacer.
      expect(find.byKey(llaveRegistro(TipoRegistro.habito)), findsNothing);
      expect(find.text('Hecho'), findsOneWidget);
      var hoy = await servicio.hoyDe();
      expect(hoy.single.hecho, isTrue);
      await tester.tap(find.text('Deshacer'));
      await tester.pumpAndSettle();
      hoy = await servicio.hoyDe();
      expect(hoy.single.objetivo.id, objetivo.id);
      expect(hoy.single.hecho, isFalse);
    });

    testWidgets('Hábito sin objetivos: lo dice y lleva a crear uno', (
      tester,
    ) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: sesionCon(Rol.dueno),
        extras: extras(),
      );
      await abrirOpcion(tester, 'Hábito');
      expect(find.text('Aún no tienes hábitos para hoy.'), findsOneWidget);
      await tester.tap(find.text('Crear un objetivo'));
      await tester.pumpAndSettle();
      expect(ubicacion(tester), '${Rutas.habitos}/objetivos');
    });

    testWidgets('Consumo: un toque anota y Deshacer lo quita', (tester) async {
      await eliminar.configurar(
        ConfigHabito(
          tipo: TipoHabito.cigarrillo,
          inicio: DateTime.utc(2026, 10, 1),
        ),
      );
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: sesionCon(Rol.dueno),
        extras: extras(),
      );
      await abrirOpcion(tester, 'Consumo (cigarrillo o azúcar)');
      await tester.tap(find.byKey(const ValueKey('hoja-consumo-cigarrillo')));
      await tester.pumpAndSettle();
      expect(find.byKey(llaveRegistro(TipoRegistro.consumo)), findsNothing);
      expect(find.text('Anotado'), findsOneWidget);
      expect((await eliminar.estado(TipoHabito.cigarrillo))!.hoy, 1);
      await tester.tap(find.text('Deshacer'));
      await tester.pumpAndSettle();
      expect((await eliminar.estado(TipoHabito.cigarrillo))!.hoy, 0);
    });

    testWidgets('Consumo de un hábito sin configurar avisa y no escribe', (
      tester,
    ) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: sesionCon(Rol.dueno),
        extras: extras(),
      );
      await abrirOpcion(tester, 'Consumo (cigarrillo o azúcar)');
      await tester.tap(find.byKey(const ValueKey('hoja-consumo-azucar')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Primero configura azúcar'), findsOneWidget);
    });

    testWidgets('Consumo con el modo privado: contenido oculto (D13)', (
      tester,
    ) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: sesionCon(Rol.dueno),
        extras: extras(privado: true),
      );
      await abrirOpcion(tester, 'Consumo (cigarrillo o azúcar)');
      expect(find.byKey(const ValueKey('reservado-privado')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('hoja-consumo-cigarrillo')),
        findsNothing,
      );
    });

    testWidgets('Consumo sin desbloquear lo reservado pide el PIN', (
      tester,
    ) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.telefono,
        sesion: sesionCon(Rol.dueno),
        extras: extras(reservadoAbierto: false),
      );
      await abrirOpcion(tester, 'Consumo (cigarrillo o azúcar)');
      expect(find.byKey(const ValueKey('reservado-pide-pin')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('hoja-consumo-cigarrillo')),
        findsNothing,
      );
    });
  });

  group('laptop (Ctrl + N / barra de órdenes)', () {
    testWidgets('el diálogo abre Hábito, Consumo y SOS', (tester) async {
      await montarApp(
        tester,
        dispositivo: TipoDispositivo.laptop,
        sesion: sesionCon(Rol.dueno),
        extras: extras(),
      );
      final contexto = tester.element(find.byType(Scaffold).first);
      for (final tipo in [
        TipoRegistro.habito,
        TipoRegistro.consumo,
        TipoRegistro.sos,
      ]) {
        unawaited(abrirRegistroEnDialogo(contexto, tipo: tipo));
        await tester.pumpAndSettle();
        expect(
          find.byKey(llaveRegistro(tipo)),
          findsOneWidget,
          reason: '$tipo',
        );
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
      }
    });
  });

  group('tablet pública de la casa (D21)', () {
    testWidgets('no ofrece Consumo ni SOS; el Hábito sí, con PIN', (
      tester,
    ) async {
      await montarPublica(tester);
      await tester.tap(find.byKey(const ValueKey('registrar-tablet-casa')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('casa-personal-habito')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('casa-personal-consumo')), findsNothing);
      expect(find.byKey(const ValueKey('casa-personal-sos')), findsNothing);
      expect(textoVisible(tester), isNot(contains('llega en la fase')));
      // Sin dinero: lo de la casa sigue sin cifras.
      expect(find.textContaining(r'$'), findsNothing);
      expect(contenedorDe(tester), isNotNull);
    });

    testWidgets(
      'aunque se pida, lo reservado no se abre en la tablet de la casa',
      (tester) async {
        await montarPublica(tester);
        final contexto = tester.element(find.byType(Scaffold).first);
        for (final opcion in opcionesDeRegistro.where(
          (o) => registroReservado(o.tipo),
        )) {
          unawaited(registrarAlgoPersonal(contexto, opcion));
          await tester.pumpAndSettle();
          expect(
            find.text('Esto no está disponible en la tablet de la casa.'),
            findsOneWidget,
            reason: opcion.etiqueta,
          );
          expect(find.byKey(const ValueKey('elegir-nombre')), findsNothing);
          ScaffoldMessenger.of(contexto).clearSnackBars();
          await tester.pumpAndSettle();
        }
      },
    );
  });
}
