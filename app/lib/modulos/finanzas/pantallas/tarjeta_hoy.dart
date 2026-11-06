/// Tarjeta de Finanzas para "Hoy" (laptop y teléfono; Fase 4, E2): el resumen
/// de la semana **por libro** con cifras reales, el semáforo con texto y el
/// número de alertas críticas. Los montos se dibujan con [MontoOcultable]: con
/// los montos ocultos la tarjeta dice "Montos ocultos" y no hay una sola cifra
/// ni en el texto ni en el lector de pantalla (D3: tampoco sale del equipo).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../diseno/diseno.dart';
import '../estado/resumen_hoy.dart';
import 'comunes.dart' show estadoDe;

/// Tarjeta "Finanzas · semana" con una fila por libro. No dibuja nada si el
/// rol no ve Finanzas ([ResumenFinanzasHoy.visible] es falso).
class TarjetaFinanzasHoy extends ConsumerWidget {
  const TarjetaFinanzasHoy({super.key, this.alAbrir});

  /// Qué hacer al tocar la tarjeta (abrir Finanzas).
  final VoidCallback? alAbrir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumen = ref.watch(resumenFinanzasHoyProvider);
    if (!resumen.visible) return const SizedBox.shrink();
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final ocultos = ref.watch(montosOcultosProvider);
    final privado = ref.watch(modoPrivadoProvider);

    final Widget cuerpo;
    if (resumen.estado == EstadoResumenHoy.cargando) {
      cuerpo = Text(
        'Cargando…',
        key: const ValueKey('finanzas-hoy-cargando'),
        style: v.lectura(tamano: 14, color: v.textoTenue),
      );
    } else if (resumen.sinDatos) {
      cuerpo = Text(
        'Sin datos todavía',
        key: const ValueKey('finanzas-hoy-sin-datos'),
        style: v.lectura(tamano: 14, color: v.textoTenue),
      );
    } else {
      cuerpo = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < resumen.libros.length; i++) ...[
            if (i > 0) SizedBox(height: e * 1.5),
            _FilaLibro(
              libro: resumen.libros[i],
              ocultos: ocultos,
              privado: privado,
            ),
          ],
          if (ocultos) ...[
            SizedBox(height: e * 0.5),
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: MarcaMontosOcultos(),
            ),
          ],
        ],
      );
    }
    final peor = resumen.peorSemaforo;
    return TarjetaModulo(
      key: const ValueKey('finanzas-hoy'),
      titulo: 'Finanzas · semana',
      accion: peor == null || resumen.libros.length > 1
          ? null
          : Semaforo(estado: estadoDe(peor)),
      alTocar: alAbrir,
      child: cuerpo,
    );
  }
}

class _FilaLibro extends ConsumerWidget {
  const _FilaLibro({
    required this.libro,
    required this.ocultos,
    required this.privado,
  });

  final ResumenLibroHoy libro;
  final bool ocultos;
  final bool privado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final c = libro.cifras;
    // El lector de pantalla dice el estado y las alertas; nunca la cifra si
    // están ocultas (el monto trae su propia etiqueta "Monto oculto").
    return Column(
      key: ValueKey('finanzas-hoy-libro-${libro.libroId}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: e,
          runSpacing: e * 0.5,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Text(
              libro.nombre,
              style: v.lectura(
                tamano: 14,
                color: v.textoFuerte,
                peso: FontWeight.w600,
              ),
            ),
            if (!c.sinDatos) Semaforo(estado: estadoDe(c.semaforo)),
          ],
        ),
        SizedBox(height: e * 0.5),
        if (c.sinDatos)
          Text(
            'Sin datos todavía',
            style: v.lectura(tamano: 14, color: v.textoTenue),
          )
        else
          Wrap(
            spacing: e,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Quedan', style: v.lectura(tamano: 14, color: v.textoTenue)),
              MontoOcultable(
                key: ValueKey('finanzas-hoy-quedan-${libro.libroId}'),
                centavos: c.disponible,
                oculto: ocultos,
                estilo: v.numero(
                  tamano: 22,
                  peso: FontWeight.w600,
                  color: v.acento,
                ),
                alTocar: privado
                    ? null
                    : ocultos
                    ? () => ref.read(revelarMontosProvider)(context)
                    : () => ref.read(montosVisiblesProvider.notifier).fijar(false),
              ),
            ],
          ),
        if (!c.sinDatos) ...[
          SizedBox(height: e * 0.5),
          Row(
            children: [
              Icon(
                libro.alertasCriticas > 0
                    ? Icons.error_outline
                    : Icons.check_circle_outline,
                size: 16,
                color: libro.alertasCriticas > 0 ? v.peligro : v.textoTenue,
              ),
              SizedBox(width: e * 0.75),
              Expanded(
                child: Text(
                  libro.textoAlertas,
                  key: ValueKey('finanzas-hoy-alertas-${libro.libroId}'),
                  style: v.lectura(tamano: 14, color: v.textoTenue),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
