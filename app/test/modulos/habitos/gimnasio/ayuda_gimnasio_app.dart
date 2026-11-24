/// Ayuda para las pruebas de las pantallas y los casos de uso de «Mi gimnasio»
/// (G5): servicio con todo en memoria y un reloj fijo.
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gravity/app/avisos/con_avisos.dart'
    show servicioAvisoDescansoProvider, tipoEquipoAvisosProvider;
import 'package:gravity/app/dispositivo.dart' show tipoDispositivoProvider;
import 'package:gravity/app/gimnasio/acceso_gimnasio.dart';
import 'package:gravity/app/gimnasio/proveedores_gimnasio.dart'
    show
        molestiasLocalesProvider,
        pantallaEncendidaDeLaSesionProvider,
        pantallaEncendidaProvider,
        personaEnPantallaProvider,
        repositorioGimnasioProvider;
import 'package:gravity/diseno/proveedores.dart'
    show RelojFijo, relojProvider;
import 'package:gravity/modulos/habitos/estado/proveedores.dart'
    show repositorioAgendaProvider, repositorioHabitosProvider;
import 'package:gravity/modulos/habitos/gimnasio/estado/proveedores_gimnasio.dart'
    show modoFocoActivoProvider;
import 'package:gravity/modulos/habitos/gimnasio/pantallas_gimnasio.dart';
import 'package:gravity/nucleo/avisos/aviso.dart' show PreferenciasAvisos;
import 'package:gravity/nucleo/avisos/aviso_descanso.dart';
import 'package:gravity/nucleo/avisos/notificador.dart';
import 'package:gravity/nucleo/avisos/servicio_avisos.dart' show ContextoAvisos;
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/gimnasio/pantalla_encendida.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart'
    show almacenSeguroProvider;
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/modulos/habitos/datos/modelos_agenda.dart';
import 'package:gravity/modulos/habitos/datos/repositorio.dart';
import 'package:gravity/modulos/habitos/datos/repositorio_agenda.dart';
import 'package:gravity/modulos/habitos/gimnasio/casos_uso/modo_foco.dart';
import 'package:gravity/modulos/habitos/gimnasio/casos_uso/servicio_gimnasio.dart';
import 'package:gravity/modulos/habitos/gimnasio/datos/lector_gimnasio.dart';
import 'package:gravity/nucleo/avisos/repositorio_avisos.dart'
    show TipoEquipoAvisos;
import 'package:gravity/nucleo/base_local/base_local.dart';
import 'package:gravity/nucleo/gimnasio/molestias_locales.dart';
import 'package:gravity/nucleo/gimnasio/repositorio_gimnasio.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/sensibles/llaves_habitos.dart';
import 'package:gravity/nucleo/sensibles/sobres.dart';
import 'package:gravity/nucleo/sensibles/subida_diferida.dart';

const persona = 'uid-ana';

/// Lunes 30 de noviembre de 2026, 19:00 hora local (el día de una sesión A).
final lunes30 = DateTime(2026, 11, 30, 19);

/// Todo en memoria: la base local, la agenda, los registros de Hábitos y el
/// almacén seguro (molestias y copia del modo foco).
class Mundo {
  Mundo({
    DateTime? ahora,
    this.equipo = TipoEquipoAvisos.telefono,
    this.foco,
    this.lector = const LectorGimnasioNulo(),
  }) : ahoraActual = ahora ?? lunes30 {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    base = BaseLocal.enMemoria();
    repo = RepositorioGimnasio(base, reloj: () => ahoraActual);
    agenda = RepositorioAgendaEnMemoria();
    registros = RepositorioHabitosEnMemoria();
    almacen = AlmacenSeguroEnMemoria();
    molestias = MolestiasLocales(
      llaves: LlavesHabitos(almacen),
      sobres: AlmacenDeSobres(almacen),
      modos: ModosLocales(almacen),
      persona: persona,
      equipoLasAdmite: () => equipoAdmiteMolestias(equipo),
    );
  }

  DateTime ahoraActual;
  final TipoEquipoAvisos equipo;
  final ModoFocoActivo? foco;
  final LectorGimnasio lector;
  late final BaseLocal base;
  late final RepositorioGimnasio repo;
  late final RepositorioAgendaEnMemoria agenda;
  late final RepositorioHabitosEnMemoria registros;
  late final AlmacenSeguroEnMemoria almacen;
  late final MolestiasLocales molestias;

  ServicioGimnasio get servicio => ServicioGimnasio(
    repo: repo,
    persona: persona,
    agenda: agenda,
    registros: registros,
    molestias: molestias,
    lector: lector,
    foco: foco == null ? null : () async => foco!,
    ahora: () => ahoraActual,
  );

  Future<void> cerrar() => base.close();

  /// El día tipo del diseño: trabajo de 9:00 a 18:00, traslado de 18:00 a
  /// 19:00, de lunes a viernes; despertar 6:00 y dormir 22:00.
  Future<void> diaTipoDelDiseno() async {
    await agenda.guardarBloque(
      BloqueHab(
        id: 'trabajo',
        titulo: 'Trabajo',
        area: 'laboral',
        tipo: 'trabajo',
        inicioMin: 9 * 60,
        duracionMin: 9 * 60,
        dias: 31,
        desde: DateTime.utc(2026, 11, 1),
        modificadoEn: DateTime.utc(2026, 11, 1),
      ),
    );
    await agenda.guardarBloque(
      BloqueHab(
        id: 'traslado',
        titulo: 'Traslado de regreso',
        area: 'laboral',
        tipo: 'traslado',
        inicioMin: 18 * 60,
        duracionMin: 60,
        dias: 31,
        desde: DateTime.utc(2026, 11, 1),
        modificadoEn: DateTime.utc(2026, 11, 1),
      ),
    );
  }
}

// ------------------------------------------------------------- pantallas

/// Monta una pantalla de «Mi gimnasio» dentro de un router mínimo, con todo en
/// memoria. Devuelve lo que las pruebas necesitan para mirar el resultado.
class Montaje {
  Montaje({
    required this.notificador,
    required this.rutas,
    required this.pantallaEncendida,
  });

  final NotificadorEnMemoria notificador;

  /// Las ubicaciones a las que navegó la pantalla, en orden.
  final List<String> rutas;
  final EspiaPantalla pantallaEncendida;
}

/// Cuenta los pedidos de pantalla encendida.
class EspiaPantalla implements PantallaEncendida {
  int vigentes = 0;
  int pedidos = 0;

  @override
  bool get disponible => true;

  @override
  Future<bool> mantener(bool encendida) async => true;

  @override
  void Function() pedir() {
    pedidos++;
    vigentes++;
    var soltado = false;
    return () {
      if (soltado) return;
      soltado = true;
      vigentes--;
    };
  }
}

Future<Montaje> montarPantalla(
  WidgetTester t,
  Mundo m,
  DestinoGimnasio destino, {
  Size tamano = const Size(400, 900),
  String ruta = '',
  TipoEquipoAvisos equipo = TipoEquipoAvisos.telefono,
  List<Override> extras = const [],
}) async {
  t.view.physicalSize = tamano;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final notificador = NotificadorEnMemoria();
  final rutas = <String>[];
  final espia = EspiaPantalla();
  final router = GoRouter(
    initialLocation: ruta.isEmpty ? destino.ruta : '${destino.ruta}?$ruta',
    routes: [
      GoRoute(
        path: '/habitos/entrenamiento',
        builder: (_, _) => Consumer(
          builder: (_, ref, _) => pantallaDeGimnasio(DestinoGimnasio.hoy),
        ),
      ),
      for (final d in DestinoGimnasio.values)
        if (d != DestinoGimnasio.hoy)
          GoRoute(
            path: d.ruta,
            builder: (_, estado) {
              rutas.add(estado.uri.toString());
              return pantallaDeGimnasio(d);
            },
          ),
      GoRoute(
        path: '/ajustes',
        builder: (_, _) => const Scaffold(body: Text('Ajustes')),
      ),
      GoRoute(
        path: '/habitos',
        builder: (_, _) => const Scaffold(body: Text('Hábitos')),
      ),
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('Inicio')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        servicioSesionProvider.overrideWithValue(ServicioSesionFalso()),
        tipoDispositivoProvider.overrideWithValue(TipoDispositivo.telefono),
        tipoEquipoAvisosProvider.overrideWithValue(equipo),
        personaEnPantallaProvider.overrideWithValue(persona),
        repositorioGimnasioProvider.overrideWithValue(m.repo),
        repositorioAgendaProvider.overrideWithValue(m.agenda),
        repositorioHabitosProvider.overrideWithValue(m.registros),
        molestiasLocalesProvider.overrideWithValue(m.molestias),
        almacenSeguroProvider.overrideWithValue(m.almacen),
        relojProvider.overrideWithValue(RelojFijo(m.ahoraActual)),
        modoFocoActivoProvider.overrideWith(
          (ref) async => m.foco ?? const SinModoFoco(),
        ),
        pantallaEncendidaProvider.overrideWithValue(espia),
        servicioAvisoDescansoProvider.overrideWithValue(
          ServicioAvisoDescanso(
            notificador: notificador,
            contexto: () => const ContextoAvisos(
              tipo: TipoEquipoAvisos.telefono,
              personaId: persona,
              usaHabitos: true,
            ),
            preferencias: () async => const PreferenciasAvisos(),
            ahora: () => m.ahoraActual,
          ),
        ),
        ...extras,
      ],
      child: MaterialApp.router(
        routerConfig: router,
        // Como AppGravity: alguien mantiene viva la pantalla encendida.
        builder: (context, child) => Consumer(
          builder: (_, ref, _) {
            ref.watch(pantallaEncendidaDeLaSesionProvider);
            return child!;
          },
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return Montaje(notificador: notificador, rutas: rutas, pantallaEncendida: espia);
}
