/// Modo Casa de la tablet (D14, `DISENO_UX_UI.md` sección 11): cuenta de rol
/// Casa, sin dinero ni datos clínicos. Arriba se elige el contexto; a un lado,
/// quién usa la tablet (entra con su PIN).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../nucleo/contratos/roles.dart';
import '../../nucleo/permisos/permisos.dart';
import '../../nucleo/sesion/proveedores_sesion.dart';
import '../../nucleo/tablet/controlador_tablet.dart';
import '../../nucleo/tablet/usuarios_tablet.dart';
import '../navegacion.dart';
import 'dialogo_agregar_persona.dart';
import 'dialogo_pin.dart';

/// Tarjetas de cada contexto (se llenan conforme entran los módulos).
const Map<String, List<(String, String)>> tarjetasPorContexto = {
  'general': [
    ('Hoy en la casa', 'Lo del día de la casa; se llena con cada módulo.'),
    ('Avisos', 'Sin avisos por ahora.'),
    (
      'Turno de cuidados',
      'Recordatorios genéricos, sin nombres ni medicamentos (Fase 5).',
    ),
  ],
  'cocina': [
    ('Receta paso a paso', 'Con letra enorme y voz (Fase 7).'),
    ('Lista de compras', 'Llega con Alimentación (Fase 7).'),
  ],
  'gimnasio': [
    ('Serie y descanso', 'Llega con Hábitos (Fase 3).'),
  ],
  'cuidados': [
    ('Recordatorios del turno', 'Genéricos, sin datos clínicos (Fase 5).'),
    ('Mi turno', 'La cuidadora entra con su PIN para ver su turno.'),
  ],
};

IconData iconoDeContexto(String id) => switch (id) {
  'cocina' => Icons.soup_kitchen_outlined,
  'gimnasio' => Icons.fitness_center,
  'cuidados' => Icons.volunteer_activism_outlined,
  _ => Icons.home_outlined,
};

class PantallaModoCasa extends ConsumerWidget {
  const PantallaModoCasa({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(controladorTabletProvider);
    final tema = Theme.of(context);
    final contexto = estado.configuracion.contexto;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.blur_circular, color: tema.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('GRAVITY · Casa', style: tema.textTheme.titleLarge),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      children: [
                        for (final modulo in modulosNavegables(Rol.casa))
                          TextButton.icon(
                            onPressed: () => context.go(rutaDeModulo(modulo)),
                            icon: Icon(iconoDeModulo(modulo)),
                            label: Text(nombreModulo(modulo)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SelectorContexto(actual: contexto),
              const SizedBox(height: 16),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, limites) {
                    final horizontal = limites.maxWidth > limites.maxHeight;
                    final contenido = _ContenidoContexto(contexto: contexto);
                    final personas = _SelectorPersona(estado: estado);
                    return horizontal
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 3, child: contenido),
                              const SizedBox(width: 24),
                              Expanded(flex: 2, child: personas),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: contenido),
                              const SizedBox(height: 16),
                              Expanded(child: personas),
                            ],
                          );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 56,
                child: FilledButton.tonalIcon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Hablar con GRAVITY llega en la Fase 6.'),
                    ),
                  ),
                  icon: const Icon(Icons.mic_none),
                  label: const Text('Mantén para hablar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectorContexto extends ConsumerWidget {
  const _SelectorContexto({required this.actual});

  final String actual;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final contexto in contextosCasa)
        ChoiceChip(
          avatar: Icon(iconoDeContexto(contexto.id)),
          label: Text(contexto.nombre),
          selected: contexto.id == actual,
          onSelected: (_) => ref
              .read(controladorTabletProvider.notifier)
              .elegirContexto(contexto.id),
        ),
    ],
  );
}

class _ContenidoContexto extends StatelessWidget {
  const _ContenidoContexto({required this.contexto});

  final String contexto;

  @override
  Widget build(BuildContext context) {
    final tarjetas =
        tarjetasPorContexto[contexto] ?? tarjetasPorContexto['general']!;
    return ListView(
      children: [
        for (final (titulo, detalle) in tarjetas)
          Card(
            child: ListTile(
              title: Text(titulo),
              subtitle: Text(detalle),
              minTileHeight: 64,
            ),
          ),
      ],
    );
  }
}

class _SelectorPersona extends ConsumerWidget {
  const _SelectorPersona({required this.estado});

  final EstadoTablet estado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final demostracion = ref.watch(servicioSesionProvider).esDemostracion;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('¿Quién usa la tablet?', style: tema.textTheme.titleMedium),
            if (demostracion)
              Text(
                'Demostración: el PIN es ${ControladorTablet.pinDeDemostracion}.',
                style: tema.textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            Expanded(
              child: !estado.cargado
                  ? const Center(child: CircularProgressIndicator())
                  : estado.usuarios.isEmpty
                  ? const Center(
                      child: Text(
                        'Aún no hay personas en esta tablet.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView(
                      children: [
                        for (final usuario in estado.usuarios)
                          ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                usuario.nombre.characters.first.toUpperCase(),
                              ),
                            ),
                            title: Text(usuario.nombre),
                            subtitle: Text(nombreRol(usuario.rol)),
                            minTileHeight: 56,
                            onTap: () => mostrarDialogoPin(context, usuario),
                          ),
                      ],
                    ),
            ),
            TextButton.icon(
              onPressed: () => mostrarDialogoAgregarPersona(context),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Agregar persona'),
            ),
          ],
        ),
      ),
    );
  }
}
