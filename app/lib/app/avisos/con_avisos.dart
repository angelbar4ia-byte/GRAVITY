/// Conecta los avisos con la app (Fase 2, D20): crea el [ServicioAvisos] con
/// el contexto del equipo (teléfono, tablet personal o pública, laptop; quién
/// está dentro), lo arranca, registra el equipo al entrar una persona y lo da de
/// baja al salir, y abre la bandeja al tocar una notificación.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../nucleo/avisos/proveedores_avisos.dart';
import '../../nucleo/avisos/recordatorios.dart';
import '../../nucleo/avisos/repositorio_avisos.dart';
import '../../nucleo/avisos/servicio_avisos.dart';
import '../../nucleo/contratos/dispositivo.dart';
import '../../nucleo/contratos/roles.dart';
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
      vencimientos: ref.watch(fuenteDeVencimientosProvider),
    ),
    alAbrirAviso: (_) => ref.read(routerProvider).go(RutasApp.avisos),
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
      }),
    );
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
      }());
    });
    return widget.child;
  }
}
