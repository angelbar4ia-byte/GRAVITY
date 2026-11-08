/// Aportación de referencia a la casa (Fase 8, bloque 1): 50% Papá y 50% entre
/// el dueño y la pareja, para el periodo configurado, junto a lo aportado.
/// Es una guía: la aportación es libre y nadie aparece como deudor.
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide
        Semaforo,
        formatearCentavos,
        TipoLibro,
        VisibilidadLibro,
        puntosBaseEnCien;
import 'package:finanzas_dominio/finanzas_dominio.dart' as dom show TipoLibro;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../diseno/diseno.dart';
import '../../datos/demostracion.dart' show IdsDemostracion;
import '../../datos/transferencias.dart';
import '../../estado/proveedores.dart';
import '../../estado/proveedores_transferencias.dart';
import '../comunes.dart';
import '../laptop/marco_laptop.dart';

class PantallaAportacionCasa extends StatelessWidget {
  const PantallaAportacionCasa({super.key});

  @override
  Widget build(BuildContext context) => MarcoFinanzasLaptop(
    seccion: SeccionFinanzas.aportacion,
    builder: (context, c) =>
        ContenidoLaptop(children: [CuerpoAportacionCasa(contexto: c)]),
  );
}

/// Una persona con su referencia y lo aportado.
class FilaAportacion {
  const FilaAportacion(this.clave, this.nombre, this.referencia, this.aportado);
  final String clave;
  final String nombre;
  final int referencia;
  final int aportado;
}

class CuerpoAportacionCasa extends ConsumerWidget {
  const CuerpoAportacionCasa({super.key, required this.contexto});

  final ContextoFinanzas contexto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodo = ref.watch(periodoAportacionProvider);
    final transferencias = ref.watch(transferenciasProvider).value ?? [];
    final casa = contexto.libros
        .where((l) => l.tipo == dom.TipoLibro.compartido)
        .firstOrNull;
    return periodo.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Text('No se pudo consultar el periodo.'),
      data: (p) {
        if (casa == null) {
          return const Text(
            'Aún no hay un libro de la casa.',
            key: ValueKey('aporte-sin-casa'),
          );
        }
        final (desde, hasta) = p.rango(contexto.hoy);
        final total = totalGastoCasa(contexto.datos, casa.id, desde, hasta);
        final filas = filasDeAportacion(
          total: total,
          transferencias: transferencias,
          duenoId: _duenoId(contexto),
          parejaId: _parejaId(contexto),
          desde: desde,
          hasta: hasta,
          nombreDe: contexto.carga.nombreDe,
        );
        return TarjetaModulo(
          key: const ValueKey('aporte-tarjeta'),
          titulo: 'Aportación de referencia · ${p.titulo.toLowerCase()}',
          icono: Icons.home_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Del ${textoFecha(desde)} al ${textoFecha(hasta)}',
                key: const ValueKey('aporte-rango'),
              ),
              const SizedBox(height: 8),
              DatoConMonto('Gastos de la casa en el periodo', total),
              const Divider(),
              for (final f in filas)
                ListTile(
                  key: ValueKey('aporte-${f.clave}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(f.nombre),
                  subtitle: Wrap(
                    spacing: 12,
                    children: [
                      const Text('Referencia'),
                      Monto(f.referencia),
                      const Text('· Aportado'),
                      Monto(f.aportado),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              const ReferenciaPorSubcuenta(),
              const SizedBox(height: 8),
              const Text(
                'Es una guía: cada quien aporta lo que quiera. Nadie debe '
                'nada por no aportar.',
                key: ValueKey('aporte-aviso-libre'),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _duenoId(ContextoFinanzas c) =>
    c.rol.name == 'dueno' ? c.personaId : IdsDemostracion.dueno;
String _parejaId(ContextoFinanzas c) =>
    c.rol.name == 'coadministrador' ? c.personaId : IdsDemostracion.pareja;

/// Las tres filas (dueño, pareja y Papá) con referencia y aportado. Las
/// referencias suman el total (100%).
List<FilaAportacion> filasDeAportacion({
  required int total,
  required List<Transferencia> transferencias,
  required String duenoId,
  required String parejaId,
  required Fecha desde,
  required Fecha hasta,
  required String Function(String?) nombreDe,
}) {
  final r = ReferenciaAportacion.de(total);
  int aportado(String id) =>
      aportadoPorPersona(transferencias, id, desde, hasta);
  return [
    FilaAportacion('dueno', 'Dueño', r.duenoCentavos, aportado(duenoId)),
    FilaAportacion('pareja', 'Pareja', r.parejaCentavos, aportado(parejaId)),
    // Las aportaciones de Papá pasan por el albacea (D19); su registro llega
    // con el registro de aportantes.
    FilaAportacion('papa', 'Papá', r.papaCentavos, 0),
  ];
}

/// Selector del periodo (solo el dueño). Va en Ajustes de Finanzas.
class SelectorPeriodoAportacion extends ConsumerWidget {
  const SelectorPeriodoAportacion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actual = ref.watch(periodoAportacionProvider).value;
    return TarjetaModulo(
      key: const ValueKey('ajustes-periodo-aportacion'),
      titulo: 'Periodo de la aportación a la casa',
      icono: Icons.event_repeat_outlined,
      child: Wrap(
        spacing: 8,
        children: [
          for (final p in PeriodoAportacion.values)
            ChoiceChip(
              key: ValueKey('periodo-${p.codigo}'),
              label: Text(p.titulo),
              selected: actual == p,
              onSelected: (_) => intentar(
                context,
                () => ref.read(periodoAportacionProvider.notifier).fijar(p),
              ),
            ),
        ],
      ),
    );
  }
}

/// Referencia por subcuenta y por persona (por omisión 50/25/25). Solo el
/// dueño la edita.
class ReferenciaPorSubcuenta extends ConsumerWidget {
  const ReferenciaPorSubcuenta({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subs = ref.watch(subcuentasCasaProvider).value ?? const [];
    final esDueno =
        ref.watch(parteTransferenciaProvider) == ParteTransferencia.dueno;
    final repo = ref.watch(repositorioTransferenciasProvider);
    return Column(
      key: const ValueKey('aporte-por-subcuenta'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in subs)
          FutureBuilder<ReparteReferencia>(
            future: repo.referencia(s.id),
            builder: (context, snap) {
              final r = snap.data ?? ReparteReferencia.porOmision;
              String pct(int pb) => '${pb / 100}%';
              return ListTile(
                key: ValueKey('aporte-sub-${s.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(s.nombre),
                subtitle: Text(
                  'Papá ${pct(r.papaPb)} · Dueño ${pct(r.duenoPb)} · '
                  'Pareja ${pct(r.parejaPb)}',
                ),
                trailing: esDueno
                    ? TextButton(
                        key: ValueKey('aporte-editar-${s.id}'),
                        onPressed: () => _editar(context, repo, s, r),
                        child: const Text('Cambiar reparto'),
                      )
                    : null,
              );
            },
          ),
      ],
    );
  }

  Future<void> _editar(
    BuildContext context,
    RepositorioTransferencias repo,
    SubcuentaCasa s,
    ReparteReferencia actual,
  ) async {
    final c = {
      for (final p in ParteReferencia.values)
        p: TextEditingController(text: '${actual.de(p) ~/ 100}'),
    };
    final nuevo = await showDialog<ReparteReferencia>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reparto de ${s.nombre}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in ParteReferencia.values)
              TextField(
                controller: c[p],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: '${p.name} (%)'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              ReparteReferencia(
                papaPb: (int.tryParse(c[ParteReferencia.papa]!.text) ?? 0) * 100,
                duenoPb:
                    (int.tryParse(c[ParteReferencia.dueno]!.text) ?? 0) * 100,
                parejaPb:
                    (int.tryParse(c[ParteReferencia.pareja]!.text) ?? 0) * 100,
              ),
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    for (final x in c.values) {
      x.dispose();
    }
    if (nuevo == null || !context.mounted) return;
    await intentar(context, () => repo.fijarReferencia(s.id, nuevo));
  }
}
