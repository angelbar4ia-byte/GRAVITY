/// Registro rápido de Hábitos desde el botón (+) (teléfono y tablet) y desde
/// Ctrl + N (laptop): marcar un hábito del día y anotar un consumo. El SOS usa
/// la pantalla de pausa (`pausa.dart`).
///
/// No duplican reglas: marcar usa [ServicioHabitos] (igual que Hoy) y anotar un
/// consumo usa [anotarConsumo] (igual que Reservado).
///
/// Guardias (D3, D13, D21):
/// - el **consumo** es sección reservada: va detrás de [PuertaReservada] (PIN o
///   huella, sin capturas, oculto con el modo privado y nunca en la tablet
///   pública de la casa);
/// - el **hábito** del día solo lista objetivos normales (no sensibles);
/// - nada de esto sale del equipo hacia la IA.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/sensibles/puerta_reservada.dart';
import '../../../nucleo/contratos/rutas.dart';
import '../casos_uso/servicio_eliminar.dart';
import '../casos_uso/servicio_habitos.dart';
import '../datos/modelos.dart' show EstadoRegistro;
import '../estado/proveedores.dart';
import 'eliminar.dart' show anotarConsumo, nombreHabito;

/// Hoja "Hábito": los hábitos de hoy con un botón *Hecho* y *Deshacer*.
class HojaHabito extends ConsumerWidget {
  const HojaHabito({super.key});

  Future<void> _hecho(BuildContext context, WidgetRef ref, ItemHoy item) async {
    final contenedor = ProviderScope.containerOf(context, listen: false);
    final servicio = ref.read(servicioHabitosProvider);
    final mensajero = ScaffoldMessenger.maybeOf(context);
    await servicio.marcarHecho(item.objetivo);
    contenedor.read(versionHabitosProvider.notifier).state++;
    mensajero
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('Hecho'),
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () async {
              await servicio.deshacer(item.objetivo);
              contenedor.read(versionHabitosProvider.notifier).state++;
            },
          ),
        ),
      );
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final hoy = ref.watch(hoyHabitosProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: hoy.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No pudimos cargar tus hábitos.'),
                TextButton(
                  onPressed: () => ref.invalidate(hoyHabitosProvider),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
          data: (items) {
            final pendientes = [
              for (final i in items)
                if (i.estado != EstadoRegistro.hecho &&
                    i.estado != EstadoRegistro.omitido)
                  i,
            ];
            return ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Hábito de hoy',
                    style: tema.textTheme.titleLarge,
                  ),
                ),
                if (items.isEmpty)
                  _Vacio(
                    texto: 'Aún no tienes hábitos para hoy.',
                    accion: 'Crear un objetivo',
                    alAccionar: () {
                      Navigator.of(context).pop();
                      context.go('${Rutas.habitos}/objetivos');
                    },
                  )
                else if (pendientes.isEmpty)
                  const _Vacio(texto: 'Todo lo de hoy ya está hecho.'),
                for (final i in pendientes)
                  ListTile(
                    key: ValueKey('hoja-habito-${i.objetivo.id}'),
                    title: Text(i.objetivo.titulo),
                    subtitle: i.estado == EstadoRegistro.pendiente
                        ? null
                        : Text(i.estado.name),
                    minTileHeight: 56,
                    trailing: IconButton(
                      tooltip: 'Hecho',
                      icon: const Icon(Icons.check_circle_outline),
                      onPressed: () => _hecho(context, ref, i),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.texto, this.accion, this.alAccionar});

  final String texto;
  final String? accion;
  final VoidCallback? alAccionar;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(texto, textAlign: TextAlign.center),
        if (accion != null && alAccionar != null)
          TextButton(onPressed: alAccionar, child: Text(accion!)),
      ],
    ),
  );
}

/// Hoja "Consumo": un toque para anotar un cigarrillo o un refresco, detrás de
/// la puerta reservada.
class HojaConsumo extends ConsumerWidget {
  const HojaConsumo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => PuertaReservada(
    child: SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Anotar un consumo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          for (final t in TipoHabito.values)
            ListTile(
              key: ValueKey('hoja-consumo-${t.name}'),
              title: Text(nombreHabito(t)),
              subtitle: Text(
                t == TipoHabito.azucar ? 'Un refresco' : 'Un cigarrillo',
              ),
              minTileHeight: 56,
              trailing: const Icon(Icons.add_circle_outline),
              onTap: () async {
                final navegador = Navigator.of(context);
                await anotarConsumo(context, ref, t);
                if (context.mounted) navegador.pop();
              },
            ),
        ],
      ),
    ),
  );
}
