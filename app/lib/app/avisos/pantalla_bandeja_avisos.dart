/// Bandeja de avisos (Fase 2, D20): la lista de lo que GRAVITY avisó, con su
/// nivel (texto e icono), el título del catálogo y la fecha. Los montos y el
/// detalle los pone Finanzas con `detalleDeAvisoProvider`; aquí nunca se
/// muestra una cifra. Acciones: *Hecho*, *Posponer* (1 hora o hasta mañana).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../nucleo/avisos/aviso.dart';
import '../../nucleo/avisos/catalogo_avisos.dart';
import '../../nucleo/avisos/proveedores_avisos.dart';
import '../../nucleo/avisos/repositorio_avisos.dart';
import '../pantallas/marco_pantalla.dart';

final bandejaDeAvisosProvider = StreamProvider.autoDispose<List<Aviso>>((
  ref,
) async* {
  final repo = ref.watch(repositorioAvisosProvider);
  if (repo == null) {
    yield const [];
    return;
  }
  yield await repo.bandeja();
  yield* repo.enVivo();
});

String textoSeveridad(SeveridadAviso s) => switch (s) {
  SeveridadAviso.critica => 'Crítica',
  SeveridadAviso.importante => 'Importante',
  SeveridadAviso.informativa => 'Informativa',
};

IconData iconoSeveridad(SeveridadAviso s) => switch (s) {
  SeveridadAviso.critica => Icons.error_outline,
  SeveridadAviso.importante => Icons.priority_high,
  SeveridadAviso.informativa => Icons.info_outline,
};

String _fecha(DateTime f) {
  final l = f.toLocal();
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(l.day)}/${dos(l.month)}/${l.year} ${dos(l.hour)}:${dos(l.minute)}';
}

class PantallaBandejaAvisos extends ConsumerWidget {
  const PantallaBandejaAvisos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avisos = ref.watch(bandejaDeAvisosProvider);
    return MarcoPantalla(
      titulo: 'Avisos',
      cuerpo: avisos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(
          child: Text('No se pudieron leer los avisos. Revisa tu conexión.'),
        ),
        data: (lista) => lista.isEmpty
            ? const Center(
                key: ValueKey('bandeja-vacia'),
                child: Text('No tienes avisos.'),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [for (final a in lista) _FilaAviso(aviso: a)],
              ),
      ),
    );
  }
}

class _FilaAviso extends ConsumerWidget {
  const _FilaAviso({required this.aviso});

  final Aviso aviso;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalle = ref.watch(detalleDeAvisoProvider);
    final repo = ref.read(repositorioAvisosProvider);
    final abierto = aviso.estado.abierto;
    return Card(
      key: ValueKey('aviso-${aviso.id}'),
      child: ExpansionTile(
        leading: Icon(iconoSeveridad(aviso.severidad)),
        title: Text(
          aviso.titulo,
          style: TextStyle(
            fontWeight: abierto ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          '${textoSeveridad(aviso.severidad)} · ${_fecha(aviso.creadoEn)}',
        ),
        onExpansionChanged: (abre) {
          if (abre && abierto && aviso.estado != EstadoAviso.pospuesta) {
            repo?.marcar(aviso.id, AccionAviso.leida);
          }
        },
        childrenPadding: const EdgeInsets.all(12),
        children: [
          if (detalle != null) detalle(context, aviso),
          if (abierto)
            OverflowBar(
              alignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () =>
                      repo?.marcar(aviso.id, AccionAviso.posponerUnaHora),
                  child: const Text('Posponer 1 hora'),
                ),
                TextButton(
                  onPressed: () =>
                      repo?.marcar(aviso.id, AccionAviso.posponerManana),
                  child: const Text('Hasta mañana'),
                ),
                FilledButton(
                  onPressed: () => repo?.marcar(aviso.id, AccionAviso.resuelta),
                  child: const Text('Hecho'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
