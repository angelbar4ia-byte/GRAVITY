/// Ajustes › Dispositivos (solo el Dueño, en la tablet): el tipo de esta
/// tablet (D14, 21/oct/2026) y quiénes entran a la tablet personal.
///
/// - **Pública de la casa:** en reposo, modo Casa; leer no pide identidad;
///   registrar algo de la casa pide elegir el nombre y registrar algo
///   personal, nombre y PIN.
/// - **Personal** (dueño y pareja): en reposo, pantalla de bloqueo con las
///   personas permitidas; sin modo Casa.
///
/// En las dos se entra solo con PIN (la huella queda para el teléfono).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../nucleo/permisos/permisos.dart';
import '../../../nucleo/tablet/controlador_tablet.dart';
import '../../../nucleo/tablet/usuarios_tablet.dart';
import '../marco_seccion.dart';
import '../secciones_ajustes.dart';

/// Nombre de cada tipo de tablet para la interfaz.
String nombreTipoTablet(TipoTablet tipo) => switch (tipo) {
  TipoTablet.publica => 'Pública de la casa',
  TipoTablet.personal => 'Personal',
};

/// Qué hace cada tipo, en una línea.
String descripcionTipoTablet(TipoTablet tipo) => switch (tipo) {
  TipoTablet.publica =>
    'Modo Casa en reposo. Leer no pide identidad; para registrar eliges tu '
        'nombre (algo de la casa) o tu nombre y PIN (algo personal).',
  TipoTablet.personal =>
    'Del dueño y la pareja. En reposo, pantalla de bloqueo con las personas '
        'permitidas; sin modo Casa.',
};

class PantallaDispositivos extends ConsumerWidget {
  const PantallaDispositivos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(controladorTabletProvider);
    final controlador = ref.read(controladorTabletProvider.notifier);
    final configuracion = estado.configuracion;
    final tema = Theme.of(context);
    return MarcoSeccion(
      seccion: SeccionAjustes.dispositivos,
      hijos: [
        Text('Esta tablet', style: tema.textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<TipoTablet>(
          key: const ValueKey('tipo-tablet'),
          segments: [
            for (final tipo in const [TipoTablet.publica, TipoTablet.personal])
              ButtonSegment(
                value: tipo,
                label: Text(nombreTipoTablet(tipo)),
                icon: Icon(
                  tipo == TipoTablet.publica
                      ? Icons.home_outlined
                      : Icons.lock_person_outlined,
                ),
              ),
          ],
          selected: {configuracion.tipo},
          onSelectionChanged: (seleccion) =>
              controlador.elegirTipo(seleccion.first),
        ),
        const SizedBox(height: 8),
        Text(descripcionTipoTablet(configuracion.tipo)),
        if (configuracion.esPersonal) ...[
          const SizedBox(height: 24),
          Text('Personas permitidas', style: tema.textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Solo el dueño y la pareja; cada quien entra con su PIN. Para '
            'agregar a alguien, usa Personas y roles.',
          ),
          for (final usuario in estado.usuarios)
            _Permitida(usuario: usuario, configuracion: configuracion),
          if (estado.usuarios.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Aún no hay personas en esta tablet.'),
            ),
        ],
        const SizedBox(height: 24),
        const NotaAjustes(
          'En las dos tablets se entra solo con PIN: la huella no dice quién '
          'es (queda para el teléfono personal).',
          icono: Icons.pin_outlined,
        ),
      ],
    );
  }
}

class _Permitida extends ConsumerWidget {
  const _Permitida({required this.usuario, required this.configuracion});

  final UsuarioTablet usuario;
  final ConfiguracionTablet configuracion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final puedeSer = rolesDeTabletPersonal.contains(usuario.rol);
    return SwitchListTile(
      key: ValueKey('permitida-${usuario.personaId}'),
      contentPadding: EdgeInsets.zero,
      title: Text(usuario.nombre),
      subtitle: Text(
        puedeSer
            ? nombreRol(usuario.rol)
            : '${nombreRol(usuario.rol)} · solo en la tablet de la casa',
      ),
      value: puedeSer && configuracion.permitidas.contains(usuario.personaId),
      onChanged: puedeSer
          ? (valor) => ref
                .read(controladorTabletProvider.notifier)
                .permitir(usuario.personaId, permitida: valor)
          : null,
    );
  }
}
