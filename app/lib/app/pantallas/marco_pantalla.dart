/// Marco común de las pantallas de la plataforma: barra superior con el
/// título, el botón de micrófono de GRAVITY (teléfono y tablet) y el menú de
/// la cuenta. En la laptop, el botón de la izquierda vuelve a GRAVITY.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../nucleo/contratos/dispositivo.dart';
import '../../nucleo/contratos/roles.dart';
import '../../nucleo/contratos/rutas.dart';
import '../../nucleo/permisos/permisos.dart';
import '../../nucleo/sesion/proveedores_sesion.dart';
import '../../nucleo/tablet/controlador_tablet.dart';
import '../dispositivo.dart';
import '../sesion_efectiva.dart';

class MarcoPantalla extends ConsumerWidget {
  const MarcoPantalla({
    super.key,
    required this.titulo,
    required this.cuerpo,
    this.rutaAnterior,
    this.acciones = const [],
  });

  final String titulo;
  final Widget cuerpo;

  /// Si se da, la flecha de regreso lleva a esta ruta.
  final String? rutaAnterior;
  final List<Widget> acciones;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dispositivo = ref.watch(tipoDispositivoProvider);
    final Widget? inicio = switch ((rutaAnterior, dispositivo)) {
      (final String ruta, _) => IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Regresar',
        onPressed: () => context.go(ruta),
      ),
      (null, TipoDispositivo.laptop) => IconButton(
        icon: const Icon(Icons.blur_circular),
        tooltip: 'Volver a GRAVITY (Esc)',
        onPressed: () => context.go(Rutas.inicio),
      ),
      _ => null,
    };
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: inicio,
        title: Text(titulo),
        actions: [
          ...acciones,
          if (dispositivo != TipoDispositivo.laptop) const BotonMicrofono(),
          const MenuCuenta(),
          const SizedBox(width: 8),
        ],
      ),
      body: cuerpo,
    );
  }
}

/// GRAVITY en el teléfono: un botón de micrófono arriba (D12). La voz llega
/// en la Fase 6. No aparece para quien no conversa con GRAVITY (la
/// cuidadora solo confirma sus solicitudes, D18).
class BotonMicrofono extends ConsumerWidget {
  const BotonMicrofono({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rol = ref.watch(rolEfectivoProvider);
    if (rol == null || !puedeAbrir(rol, Modulo.gravity)) {
      return const SizedBox.shrink();
    }
    return IconButton(
      icon: const Icon(Icons.mic_none),
      tooltip: 'Hablar con GRAVITY',
      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hablar con GRAVITY llega en la Fase 6.')),
      ),
    );
  }
}

/// Menú de la cuenta: quién está, Ajustes y salir (o volver al modo Casa en
/// la tablet). En el modo Casa no se muestra.
class MenuCuenta extends ConsumerWidget {
  const MenuCuenta({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesion = ref.watch(sesionEfectivaProvider);
    if (sesion == null) return const SizedBox.shrink();
    final esTablet = ref.watch(tipoDispositivoProvider) == TipoDispositivo.tablet;
    if (esTablet && sesion.rol == Rol.casa) return const SizedBox.shrink();
    final personal = ref.watch(
      controladorTabletProvider.select((e) => e.configuracion.esPersonal),
    );
    return PopupMenuButton<_OpcionCuenta>(
      tooltip: 'Cuenta',
      icon: const Icon(Icons.account_circle_outlined),
      onSelected: (opcion) async {
        switch (opcion) {
          case _OpcionCuenta.ajustes:
            context.go(Rutas.ajustes);
          case _OpcionCuenta.modoCasa:
            ref.read(controladorTabletProvider.notifier).volverAlReposo();
          case _OpcionCuenta.salir:
            await ref.read(servicioSesionProvider).salir();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Text('${sesion.persona.nombre} · ${nombreRol(sesion.rol)}'),
        ),
        const PopupMenuDivider(),
        if (puedeAbrir(sesion.rol, Modulo.ajustes))
          const PopupMenuItem(
            value: _OpcionCuenta.ajustes,
            child: Text('Ajustes'),
          ),
        if (esTablet)
          PopupMenuItem(
            value: _OpcionCuenta.modoCasa,
            child: Text(personal ? 'Bloquear la tablet' : 'Volver al modo Casa'),
          )
        else
          const PopupMenuItem(value: _OpcionCuenta.salir, child: Text('Salir')),
      ],
    );
  }
}

enum _OpcionCuenta { ajustes, modoCasa, salir }
