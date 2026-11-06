/// Fila de un movimiento (teléfono y laptop) y la acción de anular con
/// motivo (5.0 bis: nada se borra; se corrige con un contraasiento).
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide Semaforo, formatearCentavos, TipoLibro, puntosBaseEnCien;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../diseno/diseno.dart';
import '../estado/proveedores.dart';
import 'comunes.dart';

IconData iconoDe(TipoMovimiento t) => switch (t) {
  TipoMovimiento.gasto => Icons.shopping_bag_outlined,
  TipoMovimiento.ingreso => Icons.savings_outlined,
  TipoMovimiento.reembolso => Icons.undo,
  TipoMovimiento.transferencia => Icons.swap_horiz,
  TipoMovimiento.pagoDeuda => Icons.credit_score_outlined,
  TipoMovimiento.reclasificacion => Icons.label_outline,
  TipoMovimiento.ajuste => Icons.tune,
  TipoMovimiento.anulacion => Icons.block,
  TipoMovimiento.apertura => Icons.flag_outlined,
};

/// `true` si [m] se puede anular desde la vista del libro.
bool sePuedeAnular(Movimiento m, LibroMovimientos vista, ContextoFinanzas c) =>
    c.puedeEscribir &&
    m.tipo != TipoMovimiento.anulacion &&
    vista.contraasientoDe(m.id) == null &&
    vista.estadoDe(m.id) == EstadoMovimiento.confirmado;

/// Pide el motivo y anula. Devuelve `true` si se anuló.
Future<bool> anularConMotivo(
  BuildContext context,
  WidgetRef ref,
  Movimiento m,
) async {
  final motivo = await pedirTexto(
    context,
    titulo: 'Anular movimiento',
    etiqueta: 'Motivo (obligatorio)',
    ayuda:
        '$ayudaDelMotivo No se borra: se registra un contraasiento con el '
        'mismo monto y la misma fecha, y queda en la bitácora.',
    textoAccion: 'Anular',
    minimoVisibles: minimoCaracteresDeMotivo,
  );
  if (motivo == null || !context.mounted) return false;
  final ok = await intentar(
    context,
    () => ref.read(servicioFinanzasProvider).anular(m.id, motivo: motivo),
  );
  if (ok && context.mounted) avisar(context, 'Movimiento anulado.');
  return ok;
}

class FilaMovimiento extends ConsumerWidget {
  const FilaMovimiento({
    super.key,
    required this.movimiento,
    required this.contexto,
    this.alTocar,
    this.seleccionada = false,
  });

  final Movimiento movimiento;
  final ContextoFinanzas contexto;
  final VoidCallback? alTocar;
  final bool seleccionada;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = movimiento;
    final c = contexto;
    final vista = c.datos.vista(c.libroId);
    final anulado = vista.estaAnulado(m.id);
    final enCola = c.carga.movimientosEnCola.contains(m.id);
    final v = ValoresDiseno.de(context);
    final detalles = [
      textoFecha(m.fecha),
      if (m.tipo == TipoMovimiento.gasto) vista.cuenta(m.cuentaOrigenId).nombre,
      if (m.registradoPor != c.personaId) 'por ${c.carga.nombreDe(m.registradoPor)}',
      if (m.enNombreDe != null) 'en nombre de ${c.carga.nombreDe(m.enNombreDe)}',
      if (anulado) 'Anulado',
      if (enCola) 'Por subir',
    ];
    final tema = Theme.of(context);
    final estiloTitulo = tema.textTheme.bodyLarge?.copyWith(
      decoration: anulado ? TextDecoration.lineThrough : null,
    );
    // Sin ListTile: con letra grande su `trailing` se comía todo el ancho y el
    // monto no tenía lugar (I6 de la revisión de la Fase 1). El texto toma el
    // espacio que sobra (hasta 2 líneas) y el monto se encoge a su tope.
    return Semantics(
      container: true,
      selected: seleccionada,
      child: Material(
        color: seleccionada
            ? tema.colorScheme.secondaryContainer.withValues(alpha: 0.5)
            : Colors.transparent,
        child: InkWell(
          key: ValueKey('movimiento-${m.id}'),
          onTap: alTocar,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(iconoDe(m.tipo)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          conceptoDe(m, c.datos, vista),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: estiloTitulo,
                        ),
                        Text(
                          detalles.join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: tema.textTheme.bodyMedium?.copyWith(
                            color: tema.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // El monto no pasa de un tercio del ancho: si no cabe, se
                  // encoge en vez de empujar al resto.
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.38,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerEnd,
                      child: Monto(
                        efectoEnLibro(m, vista),
                        signo: true,
                        estilo: v.numero(
                          tamano: 15,
                          peso: FontWeight.w600,
                          color: v.textoFuerte,
                        ),
                      ),
                    ),
                  ),
                  if (sePuedeAnular(m, vista, c))
                    PopupMenuButton<String>(
                      key: ValueKey('movimiento-menu-${m.id}'),
                      tooltip: 'Opciones',
                      onSelected: (_) => anularConMotivo(context, ref, m),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'anular', child: Text('Anular…')),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Movimientos del libro activo, del más reciente al más antiguo.
List<Movimiento> movimientosDelLibro(ContextoFinanzas c) {
  final lista = [...c.datos.vista(c.libroId).movimientos]
    ..sort((a, b) {
      final f = b.fecha.compareTo(a.fecha);
      return f != 0 ? f : b.registradoEn.compareTo(a.registradoEn);
    });
  return lista;
}
