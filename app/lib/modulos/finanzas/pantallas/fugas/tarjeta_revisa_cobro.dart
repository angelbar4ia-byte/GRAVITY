/// Tarjeta «Revisa un cobro» (Fase 8, bloque 6; spec 8.2): una pregunta de la
/// revisión mensual con dos botones grandes, solo cuando hay preguntas. Sin
/// cifras: no dice montos (ni en el lector de pantalla), estén ocultos o no.
///
/// Quien solo lee (la cuenta maestra, un libro archivado) ve que hay preguntas
/// pero no tiene botones para contestarlas.
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide Semaforo, formatearCentavos, TipoLibro, puntosBaseEnCien;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../diseno/diseno.dart';
import '../../estado/proveedores.dart';
import '../../estado/proveedores_fugas.dart';
import '../comunes.dart';
import 'dialogos_fugas.dart';
import 'textos_fugas.dart';

class TarjetaRevisaUnCobro extends ConsumerWidget {
  const TarjetaRevisaUnCobro({super.key, required this.contexto});

  final ContextoFinanzas contexto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = contexto;
    if (c.libro == null || !ref.watch(puedeVerFugasProvider)) {
      return const SizedBox.shrink();
    }
    final analisis = ref.watch(analisisFugasProvider(c.libroId));
    if (analisis.preguntas.isEmpty) return const SizedBox.shrink();
    final servicio = ref.watch(servicioFugasProvider);
    final puede = servicio.puedeResponder(c.libroId);
    final primera = analisis.preguntas.first;
    final f = analisis.resultado.de(primera.clave);
    final titulo = f == null ? 'Un cobro' : tituloDeFuga(f, c.datos);
    final n = analisis.preguntas.length;
    final tema = Theme.of(context).textTheme;
    return TarjetaModulo(
      key: const ValueKey('fugas-revisa-cobro'),
      titulo: 'Revisa un cobro',
      icono: Icons.fact_check_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titulo, style: tema.titleSmall),
          const SizedBox(height: 2),
          Text(
            textoDePregunta(primera.tipo),
            key: const ValueKey('revisa-pregunta'),
          ),
          if (!puede) ...[
            const SizedBox(height: 4),
            Text(
              n == 1
                  ? 'Hay 1 pregunta por revisar. Quien lleva este libro la '
                        'contesta.'
                  : 'Hay $n preguntas por revisar. Quien lleva este libro las '
                        'contesta.',
              key: const ValueKey('revisa-solo-lectura'),
              style: tema.bodySmall,
            ),
          ] else ...[
            const SizedBox(height: 8),
            Row(
              children: [
                for (final r in [RespuestaPersona.si, RespuestaPersona.no])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: FilledButton(
                        key: ValueKey('revisa-${r.name}'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(48, 52),
                        ),
                        onPressed: () => _responder(context, ref, primera, r),
                        child: Text(
                          textoDeRespuesta(primera.tipo, r),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  key: const ValueKey('revisa-despues'),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () => _responder(
                    context,
                    ref,
                    primera,
                    RespuestaPersona.despues,
                  ),
                  child: const Text('Después'),
                ),
                if (n > 1)
                  TextButton(
                    key: const ValueKey('revisa-ver-todas'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () =>
                        mostrarRevisionMensual(context, libroId: c.libroId),
                    child: Text('Ver las $n preguntas'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _responder(
    BuildContext context,
    WidgetRef ref,
    PreguntaRevision p,
    RespuestaPersona r,
  ) async {
    final ok = await intentar(
      context,
      () => ref
          .read(servicioFugasProvider)
          .responder(
            libroId: contexto.libroId,
            clave: p.clave,
            pregunta: p.tipo == TipoPregunta.reconoce
                ? PreguntaFuga.reconoce
                : PreguntaFuga.uso,
            respuesta: r,
          ),
    );
    if (ok && context.mounted) {
      avisar(context, 'Listo, lo guardé.');
    }
  }
}
