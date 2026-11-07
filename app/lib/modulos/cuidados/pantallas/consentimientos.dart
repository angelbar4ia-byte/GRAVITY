/// Consentimientos de Cuidados (spec §4).
///
/// - Pareja: concede o retira su consentimiento de lectura de la bitácora
///   (`cui_cambiar_consentimiento`; solo su titular).
/// - Albacea: autoriza o retira el resumen mensual de la hermana
///   (`cui_autorizar_resumen`; solo el albacea).
/// - Dueño: solo ve el estado; no cambia nada por la pareja.
///
/// La app solo oculta; el servidor decide. Textos sobrios, sin cifras ni
/// nombres clínicos.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/pantallas/marco_pantalla.dart';
import '../../../diseno/diseno.dart';
import '../../../nucleo/contratos/roles.dart';
import '../datos/modelos.dart';
import '../estado/proveedores.dart';
import 'comunes.dart';

class PantallaConsentimientos extends ConsumerWidget {
  const PantallaConsentimientos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(permisosCuidadosProvider);
    return TemaModulo(
      modulo: Modulo.cuidados,
      child: MarcoPantalla(
        titulo: 'Consentimientos',
        cuerpo: !p.veConsentimientos
            ? const SinAccesoCuidados()
            : cuando(
                ref.watch(consentimientosProvider),
                () => ref.invalidate(consentimientosProvider),
                (e) => e == null
                    ? const SinAccesoCuidados()
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          if (p.daConsentimiento)
                            _TarjetaPareja(estado: e, propia: true)
                          else if (p.administra)
                            _TarjetaPareja(estado: e, propia: false),
                          if (p.autorizaResumen)
                            _TarjetaHermana(estado: e, puedeCambiar: true)
                          else if (p.administra)
                            _TarjetaHermana(estado: e, puedeCambiar: false),
                        ],
                      ),
              ),
      ),
    );
  }
}

class _Estado extends StatelessWidget {
  const _Estado(this.activo, this.si, this.no);
  final bool activo;
  final String si, no;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(activo ? Icons.check_circle_outline : Icons.remove_circle_outline),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          activo ? si : no,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    ],
  );
}

class _TarjetaPareja extends ConsumerWidget {
  const _TarjetaPareja({required this.estado, required this.propia});
  final EstadoConsentimientos estado;
  final bool propia;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final concedido = estado.parejaConcedido;
    return TarjetaCuidados(
      titulo: propia ? 'Mi consentimiento' : estado.parejaNombre,
      icono: Icons.fact_check_outlined,
      hijos: [
        const Text('Lectura de la bitácora de cuidados.'),
        const SizedBox(height: 8),
        _Estado(concedido, 'Concedido', 'No concedido'),
        if (propia) ...[
          const SizedBox(height: 12),
          BotonGrande(
            texto: concedido ? 'Retirar consentimiento' : 'Conceder',
            tonal: concedido,
            onPressed: () => ejecutarCuidados(
              context,
              ref,
              () => ref
                  .read(servicioCuidadosProvider)
                  .cambiarMiConsentimiento(!concedido),
              ok: concedido
                  ? 'Consentimiento retirado'
                  : 'Consentimiento concedido',
            ),
          ),
        ] else
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Solo su titular lo puede cambiar.'),
          ),
      ],
    );
  }
}

class _TarjetaHermana extends ConsumerWidget {
  const _TarjetaHermana({required this.estado, required this.puedeCambiar});
  final EstadoConsentimientos estado;
  final bool puedeCambiar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aut = estado.hermanaAutorizada;
    final id = estado.hermanaId;
    return TarjetaCuidados(
      titulo: estado.hermanaNombre,
      icono: Icons.verified_user_outlined,
      hijos: [
        const Text('Resumen mensual del costo del cuidado.'),
        const SizedBox(height: 8),
        _Estado(aut, 'Autorizado', 'No autorizado'),
        if (puedeCambiar && id != null) ...[
          const SizedBox(height: 12),
          BotonGrande(
            texto: aut ? 'Retirar autorización' : 'Autorizar',
            tonal: aut,
            onPressed: () => ejecutarCuidados(
              context,
              ref,
              () =>
                  ref.read(servicioCuidadosProvider).autorizarResumen(id, !aut),
              ok: aut ? 'Autorización retirada' : 'Resumen autorizado',
            ),
          ),
        ] else
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Solo el albacea lo puede cambiar.'),
          ),
      ],
    );
  }
}
