/// Resumen del día de Papá (`cui_resumen_papa`): solo conteos, sin nombres,
/// dosis ni notas. Lo ven el dueño y la pareja con consentimiento vigente; el
/// resto, "no disponible". Texto grande y claro.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/pantallas/marco_pantalla.dart';
import '../../../diseno/diseno.dart';
import '../../../nucleo/contratos/roles.dart';
import '../datos/modelos.dart';
import '../estado/proveedores.dart';
import 'comunes.dart';

class PantallaResumenDia extends ConsumerWidget {
  const PantallaResumenDia({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(permisosCuidadosProvider);
    return TemaModulo(
      modulo: Modulo.cuidados,
      child: MarcoPantalla(
        titulo: 'Resumen del día',
        cuerpo: !p.veResumenDelDia
            ? const SinAccesoCuidados(
                detalle:
                    'El resumen del día se ve con el consentimiento vigente.',
              )
            : cuando(
                ref.watch(resumenDiaProvider),
                () => ref.invalidate(resumenDiaProvider),
                (r) => r == null ? const SinAccesoCuidados() : _Conteos(r),
              ),
      ),
    );
  }
}

class _Conteos extends StatelessWidget {
  const _Conteos(this.r);

  final ResumenPapa r;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget fila(String texto, int n) => ListTile(
      minTileHeight: 56,
      title: Text(texto, style: t.titleMedium),
      trailing: Text('$n', style: t.headlineSmall),
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(diaLargo(r.dia), style: t.titleLarge),
        const SizedBox(height: 8),
        Text('Medicamentos', style: t.titleLarge),
        fila('Programados', r.tomasTotal),
        fila('Dados', r.tomasDadas),
        fila('No dados', r.tomasNoDadas),
        fila('Pendientes', r.tomasPendientes),
        const Divider(),
        Text('Comidas', style: t.titleLarge),
        fila('Registradas', r.comidasRegistradas),
        fila('Con rechazo', r.comidasConRechazo),
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text('Solo conteos del día.'),
        ),
      ],
    );
  }
}
