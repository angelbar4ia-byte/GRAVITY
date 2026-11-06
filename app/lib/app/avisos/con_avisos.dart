/// Conecta los avisos con la app (Fase 2, D20): crea el [ServicioAvisos] con
/// el contexto del equipo (teléfono, tablet personal o pública, laptop; quién
/// está dentro), lo arranca, registra el equipo al entrar una persona y lo da de
/// baja al salir, y abre la bandeja al tocar una notificación.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../nucleo/avisos/proveedores_avisos.dart';
import '../../nucleo/avisos/aviso.dart';
import '../../nucleo/avisos/recordatorios.dart';
import '../../nucleo/avisos/servicio_recordatorios_habitos.dart';
import '../../nucleo/avisos/repositorio_avisos.dart';
import '../../nucleo/avisos/servicio_avisos.dart';
import '../../nucleo/contratos/dispositivo.dart';
import '../../nucleo/contratos/roles.dart';
import '../../nucleo/contratos/rutas.dart';
import '../../nucleo/permisos/permisos.dart' show puedeUsarHabitos;
import '../../nucleo/seguridad/pin.dart' show rolVeDinero;
import '../../nucleo/seguridad/proveedores_seguridad.dart';
import '../../nucleo/sesion/proveedores_sesion.dart';
import '../../nucleo/tablet/controlador_tablet.dart';
import '../dispositivo.dart';
import '../navegacion.dart';
import '../router.dart';
import '../sesion_efectiva.dart';

/// Qué clase de equipo es este para los avisos.
final tipoEquipoAvisosProvider = Provider<TipoEquipoAvisos>((ref) {
  return switch (ref.watch(tipoDispositivoProvider)) {
    TipoDispositivo.telefono => TipoEquipoAvisos.telefono,
    TipoDispositivo.laptop => TipoEquipoAvisos.laptop,
    TipoDispositivo.tablet =>
      ref.watch(
            controladorTabletProvider.select((e) => e.configuracion.esPersonal),
          )
          ? TipoEquipoAvisos.tabletPersonal
          : TipoEquipoAvisos.tabletPublica,
  };
});

/// Quién está dentro: la persona de la sesión efectiva (en la tablet, la que
/// entró con su PIN). La cuenta Hogar no es una persona con avisos.
final contextoAvisosProvider = Provider<ContextoAvisos>((ref) {
  final sesion = ref.watch(sesionEfectivaProvider);
  final rol = sesion?.rol;
  return ContextoAvisos(
    tipo: ref.watch(tipoEquipoAvisosProvider),
    personaId: rol == null || rol == Rol.casa ? null : sesion!.persona.id,
    esMaestra: sesion?.esMaestra ?? false,
    puedeRecibir: rol != null && rolVeDinero(rol),
    usaHabitos:
        rol != null &&
        puedeUsarHabitos(rol, esMaestra: sesion?.esMaestra ?? false),
  );
});

/// Recordatorios locales de Hábitos (Fase 3): teléfono y tablet personal.
final recordatoriosHabitosProvider = Provider<ServicioRecordatoriosHabitos>((
  ref,
) {
  return ServicioRecordatoriosHabitos(
    notificador: ref.watch(notificadorProvider),
    fuente: ref.watch(fuenteDeRecordatoriosHabitosProvider),
    almacen: ref.watch(almacenSeguroProvider),
    contexto: () => ref.read(contextoAvisosProvider),
    preferencias: () async {
      try {
        return await ref.read(repositorioAvisosProvider)?.preferencias() ??
            const PreferenciasAvisos();
      } catch (_) {
        return const PreferenciasAvisos();
      }
    },
  );
});

final servicioAvisosProvider = Provider<ServicioAvisos>((ref) {
  final notificador = ref.watch(notificadorProvider);
  final servicio = ServicioAvisos(
    notificador: notificador,
    fuentePush: ref.watch(fuentePushProvider),
    repositorio: () => ref.read(repositorioAvisosProvider),
    almacen: ref.watch(almacenSeguroProvider),
    contexto: () => ref.read(contextoAvisosProvider),
    recordatorios: RecordatoriosLocales(
      notificador: notificador,
      almacen: ref.watch(almacenSeguroProvider),
      vencimientos: ref.watch(fuenteDeVencimientosProvider),
    ),
    alAbrirAviso: (carga) {
      // Los recordatorios de Hábitos llevan su clave (`hab:…`); abrir uno lleva
      // a Hábitos (lo sensible pide el PIN allí), no a la bandeja de Finanzas.
      ref
          .read(routerProvider)
          .go(carga != null && carga.startsWith('hab:') ? Rutas.habitos : RutasApp.avisos);
    },
    alAccion: (carga, accion) => unawaited(
      ref.read(recordatoriosHabitosProvider).alAccion(carga, accion),
    ),
  );
  ref.onDispose(() => unawaited(servicio.detener()));
  return servicio;
});

/// Envuelve la app: arranca el servicio y sigue los cambios de persona.
class ConAvisos extends ConsumerStatefulWidget {
  const ConAvisos({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ConAvisos> createState() => _ConAvisosState();
}

class _ConAvisosState extends ConsumerState<ConAvisos> {
  String? _persona;

  @override
  void initState() {
    super.initState();
    final servicio = ref.read(servicioAvisosProvider);
    unawaited(
      servicio.iniciar().then((_) {
        if (!mounted) return Future<void>.value();
        _persona = ref.read(contextoAvisosProvider).personaId;
        return servicio.alEntrarPersona();
      }).then((_) => ref.read(recordatoriosHabitosProvider).reprogramar()),
    );
    // La tarea diaria de los recordatorios de Hábitos (cada 12 h con la app
    // abierta; al reiniciar el teléfono los reprograma la biblioteca).
    _diaria = Timer.periodic(
      const Duration(hours: 12),
      (_) => unawaited(ref.read(recordatoriosHabitosProvider).reprogramar()),
    );
  }

  Timer? _diaria;

  @override
  void dispose() {
    _diaria?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Cada cambio de persona (entrar, salir, PIN en la tablet): el equipo se
    // da de baja de la anterior y se registra a nombre de la nueva.
    ref.listen(contextoAvisosProvider.select((c) => (c.personaId, c.tipo)), (
      anterior,
      actual,
    ) {
      if (anterior == actual) return;
      final servicio = ref.read(servicioAvisosProvider);
      final haySesion = ref.read(sesionActualProvider) != null;
      unawaited(() async {
        if (_persona != null) {
          await servicio.alSalirPersona(conservarToken: haySesion);
        }
        _persona = actual.$1;
        if (_persona != null) await servicio.alEntrarPersona();
        await ref.read(recordatoriosHabitosProvider).reprogramar();
      }());
    });
    return widget.child;
  }
}
