/// Resumen mensual del costo del cuidado y de los gastos de la casa (Fase 5,
/// criterio 3), como **widget reutilizable**: Cuidados lo monta donde le
/// toque; Finanzas no lo monta en ninguna ruta.
///
/// Solo dibuja lo que recibe: una lista de rubros y el total del mes. Los
/// montos respetan "Mostrar/Ocultar" ([Monto]). Quién puede verlo (el dueño y
/// la hermana, con autorización del albacea) lo decide quien lo monta y el
/// servidor; el [ResumenMensualCuidado] ya llega sin montos de la pareja ni
/// del dueño.
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    show LineaResumenCuidado, ResumenMensualCuidado;
import 'package:flutter/material.dart';

import '../../../../diseno/diseno.dart';
import '../comunes.dart' show Monto;

const _meses = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// "octubre 2026".
String textoMesResumen(int anio, int mes) => '${_meses[mes - 1]} $anio';

class ResumenMensualCuidadoVista extends StatelessWidget {
  const ResumenMensualCuidadoVista({super.key, required this.resumen});

  final ResumenMensualCuidado resumen;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final titulo =
        'Costo del cuidado y de la casa · '
        '${textoMesResumen(resumen.anio, resumen.mes)}';
    return Semantics(
      container: true,
      label: titulo,
      child: Column(
        key: const ValueKey('resumen-cuidado'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titulo, style: v.lectura(tamano: 16)),
          SizedBox(height: e),
          if (resumen.vacio)
            Text(
              'Sin gastos este mes',
              key: const ValueKey('resumen-cuidado-vacio'),
              style: v.lectura(tamano: 14, color: v.textoTenue),
            )
          else ...[
            for (final l in resumen.lineas) _Fila(l),
            const Divider(),
            _Fila(
              LineaResumenCuidado('Total', resumen.totalCentavos),
              clave: const ValueKey('resumen-cuidado-total'),
              fuerte: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila(this.linea, {this.clave, this.fuerte = false});

  final LineaResumenCuidado linea;
  final Key? clave;
  final bool fuerte;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final estilo = v.lectura(tamano: 14);
    return Padding(
      key: clave,
      padding: EdgeInsets.symmetric(vertical: v.espacio * 0.5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              linea.categoria,
              style: fuerte
                  ? estilo.copyWith(fontWeight: FontWeight.w600)
                  : estilo,
            ),
          ),
          Monto(
            linea.centavos,
            estilo: fuerte
                ? estilo.copyWith(fontWeight: FontWeight.w600)
                : estilo,
          ),
        ],
      ),
    );
  }
}
