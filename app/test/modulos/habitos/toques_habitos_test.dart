import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gravity/app/avisos/con_avisos.dart' show tipoEquipoAvisosProvider;
import 'package:gravity/app/sensibles/puerta_reservada.dart';
import 'package:gravity/diseno/proveedores.dart' show RelojFijo, relojProvider;
import 'package:gravity/modulos/habitos/casos_uso/servicio_eliminar.dart';
import 'package:gravity/modulos/habitos/casos_uso/servicio_habitos.dart';
import 'package:gravity/modulos/habitos/datos/documentos_sensibles.dart';
import 'package:gravity/modulos/habitos/datos/modelos.dart';
import 'package:gravity/modulos/habitos/datos/repositorio.dart';
import 'package:gravity/modulos/habitos/datos/repositorio_agenda.dart';
import 'package:gravity/modulos/habitos/estado/proveedores.dart';
import 'package:gravity/modulos/habitos/pantallas/eliminar.dart';
import 'package:gravity/modulos/habitos/pantallas/hoy.dart';
import 'package:gravity/nucleo/avisos/repositorio_avisos.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart';
import 'package:gravity/nucleo/sensibles/llaves_habitos.dart';
import 'package:gravity/nucleo/sensibles/sobres.dart';
import 'package:gravity/nucleo/sensibles/subida_diferida.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:habitos_dominio/habitos_dominio.dart';

// Fase 4, criterio 39 y sección 7.3 del spec: la acción diaria de Hábitos
// toma 3 toques o menos. Se cuenta cada pulsación en pantalla desde Hoy, con
// la app abierta y desbloqueada (el PIN o la huella no cuentan como toques).
class _Abierto extends ReservadoAbierto {
  @override
  bool build() => true;
}

void main() {
  final ahora = DateTime.utc(2026, 11, 6, 9);
  late RepositorioHabitosEnMemoria repo;
  late ServicioHabitos servicio;
  late ServicioHabitoEliminar eliminar;
  late AlmacenSeguroEnMemoria almacen;
  late ObjetivoHab objetivo;
  var toques = 0;
  String? ruta;

  setUp(() async {
    toques = 0;
    ruta = null;
    repo = RepositorioHabitosEnMemoria();
    servicio = ServicioHabitos(repo, ahora: () => ahora);
    objetivo = await servicio.crearObjetivo(
      titulo: 'Beber agua',
      area: 'salud',
      unidad: 'vasos',
      metaValor: 8,
      inicio: DateTime.utc(2026, 11, 1),
    );
    almacen = AlmacenSeguroEnMemoria();
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
    await eliminar.configurar(ConfigHabito(tipo: TipoHabito.cigarrillo, inicio: DateTime.utc(2026, 11, 1)));
  });

  Future<void> abrirHoy(WidgetTester t) async {
    t.view.physicalSize = const Size(400, 1800); // todo a la vista: sin desplazar
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const PantallaHoyHabitos()),
        GoRoute(
          path: '/habitos/sos',
          builder: (_, _) {
            ruta = '/habitos/sos';
            return const Scaffold(body: Text('SOS abierto'));
          },
        ),
        GoRoute(
          path: '/habitos/reservado',
          builder: (_, _) {
            ruta = '/habitos/reservado';
            return const PantallaReservado();
          },
        ),
      ],
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          servicioSesionProvider.overrideWithValue(ServicioSesionFalso()),
          almacenSeguroProvider.overrideWithValue(AlmacenSeguroEnMemoria()),
          tipoEquipoAvisosProvider.overrideWithValue(TipoEquipoAvisos.telefono),
          reservadoAbiertoProvider.overrideWith(_Abierto.new),
          relojProvider.overrideWithValue(RelojFijo(ahora)),
          repositorioHabitosProvider.overrideWithValue(repo),
          servicioHabitosProvider.overrideWithValue(servicio),
          repositorioAgendaProvider.overrideWithValue(RepositorioAgendaEnMemoria()),
          servicioEliminarProvider.overrideWithValue(eliminar),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => toques++,
            child: child,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    toques = 0; // se cuenta desde que Hoy ya está a la vista
  }

  Future<RegistroHab?> registroDeHoy() async =>
      (await repo.registros(DateTime.utc(2026, 11, 6), DateTime.utc(2026, 11, 6)))
          .where((r) => r.objetivoId == objetivo.id)
          .firstOrNull;

  testWidgets('marcar un hábito: Hecho = 1 toque (con la meta precargada)', (t) async {
    await abrirHoy(t);
    await t.tap(find.byTooltip('Hecho'));
    await t.pumpAndSettle();
    expect(toques, 1);
    final r = (await registroDeHoy())!;
    expect(r.estado, EstadoRegistro.hecho);
    expect(r.valor, 8); // un hábito con cantidad queda con su meta: 1 toque, ≤ 3
  });

  testWidgets('posponer u omitir: 2 toques; Deshacer: 1 más', (t) async {
    await abrirHoy(t);
    await t.tap(find.byTooltip('Más acciones'));
    await t.pumpAndSettle();
    await t.tap(find.text('Omitir'));
    await t.pumpAndSettle();
    expect(toques, 2);
    expect((await registroDeHoy())!.estado, EstadoRegistro.omitido);
    await t.tap(find.text('Deshacer'));
    await t.pumpAndSettle();
    expect(toques, 3);
    expect((await registroDeHoy())!.estado, EstadoRegistro.pendiente);
  });

  testWidgets('SOS: 1 toque desde Hoy', (t) async {
    await abrirHoy(t);
    await t.tap(find.text('Pausa').last);
    await t.pumpAndSettle();
    expect(toques, 1);
    expect(ruta, '/habitos/sos');
    expect(find.text('SOS abierto'), findsOneWidget);
  });

  testWidgets('consumo: Reservado → (+) = 2 toques (el PIN no cuenta)', (t) async {
    await abrirHoy(t);
    await t.tap(find.text('Reservado'));
    await t.pumpAndSettle();
    expect(ruta, '/habitos/reservado');
    await t.tap(find.byTooltip('Anotar cigarrillo'));
    await t.pumpAndSettle();
    expect(toques, 2);
    expect(find.text('Anotado'), findsOneWidget);
    expect((await eliminar.estado(TipoHabito.cigarrillo))!.hoy, 1);
    // y se deshace con un toque más
    await t.tap(find.text('Deshacer'));
    await t.pumpAndSettle();
    expect((await eliminar.estado(TipoHabito.cigarrillo))!.hoy, 0);
  });

  testWidgets('consumo de un hábito sin configurar avisa en vez de fallar', (t) async {
    await abrirHoy(t);
    await t.tap(find.text('Reservado'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Anotar azúcar'));
    await t.pumpAndSettle();
    expect(find.textContaining('Primero configura azúcar'), findsOneWidget);
    expect(await eliminar.estado(TipoHabito.azucar), isNull);
  });
}
