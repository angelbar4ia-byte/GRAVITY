/// Ahorro y fondo de emergencia (Fase 2, 5.2): la escalera del fondo con las
/// semanas cubiertas, las bolsas con su avance y pendiente (sin intereses ni
/// castigo), y el reparto de la semana que la persona confirma, pospone u
/// omite. La app no mueve dinero sola.
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide
        Semaforo,
        formatearCentavos,
        TipoLibro,
        VisibilidadLibro,
        puntosBaseEnCien,
        BolsaAhorro,
        NivelFondo,
        NivelAlerta;
import 'package:finanzas_dominio/finanzas_dominio.dart'
    as dom
    show BolsaAhorro, NivelFondo;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../diseno/diseno.dart';
import '../../casos_uso/servicio_fase2.dart';
import '../../estado/proveedores.dart';
import '../../estado/proveedores_fase2.dart';
import '../comunes.dart';
import 'dialogos_fase2.dart';

TipoBolsa _tipoGadget(TipoBolsaAhorro t) => switch (t) {
  TipoBolsaAhorro.fondoEmergencia => TipoBolsa.fondo,
  TipoBolsaAhorro.reserva => TipoBolsa.reserva,
  TipoBolsaAhorro.metaFecha => TipoBolsa.metaConFecha,
  TipoBolsaAhorro.metaLibre => TipoBolsa.metaSinFecha,
};

class VistaAhorro extends ConsumerWidget {
  const VistaAhorro({super.key, required this.contexto, this.telefono = false});

  final ContextoFinanzas contexto;
  final bool telefono;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = contexto;
    final svc = ref.watch(servicioFase2Provider);
    final semana = Semana.de(c.hoy);
    final fondo = svc.fondo(c.libroId, semana);
    final bolsas = svc.bolsas(c.libroId, semana);
    final guardada = c.datos.semanaGuardada(c.libroId, semana);
    final propuestas = guardada == null
        ? const <AportacionAhorro>[]
        : [
            for (final a in c.datos.aportaciones)
              if (a.semanaId == guardada.id &&
                  a.estado == EstadoAportacion.propuesta &&
                  a.sugerido > 0)
                a,
          ];
    final hueco = SizedBox(height: ValoresDiseno.de(context).espacio * 2);

    if (bolsas.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          EstadoVacio(
            mensaje: 'Aún no tienes bolsas de ahorro.',
            detalle:
                'Crea tu fondo de emergencia, una reserva o una meta. '
                'Tú decides cuándo y cuánto apartar.',
            textoAccion: c.puedeAdministrar ? 'Nueva bolsa' : null,
            alAccionar: c.puedeAdministrar
                ? () => showDialog<void>(
                    context: context,
                    builder: (_) => DialogoBolsa(contexto: c),
                  )
                : null,
          ),
        ],
      );
    }

    return ListView(
      key: const ValueKey('ahorro-lista'),
      padding: const EdgeInsets.all(16),
      children: [
        if (!telefono && c.puedeAdministrar)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: OutlinedButton.icon(
              key: const ValueKey('ahorro-nueva-bolsa'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => DialogoBolsa(contexto: c),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Nueva bolsa'),
            ),
          ),
        if (fondo != null) ...[
          TarjetaModulo(
            key: const ValueKey('ahorro-fondo'),
            titulo: 'Fondo de emergencia',
            icono: Icons.shield_outlined,
            child: EscaleraFondo(
              nivelActual: _nivelAlcanzado(fondo),
              nivelMeta: fondo.nivel.numero,
              nivelSugerido: fondo.sugerido.numero,
              semanasCubiertas: fondo.semanasDecimas == null
                  ? null
                  : fondo.semanasDecimas! / 10,
              estado: fondo.semaforo == null ? null : estadoDe(fondo.semaforo!),
              metasCentavos: fondo.esencial.semanal == null
                  ? null
                  : [
                      for (final n in dom.NivelFondo.values)
                        metaDelFondo(n, fondo.esencial.semanal!),
                    ],
              alElegirNivel: c.puedeAdministrar
                  ? (n) => intentar(
                      context,
                      () => ref
                          .read(servicioFase2Provider)
                          .cambiarNivelFondo(
                            bolsas
                                .firstWhere(
                                  (b) =>
                                      b.bolsa.tipo ==
                                      TipoBolsaAhorro.fondoEmergencia,
                                )
                                .bolsa
                                .id,
                            dom.NivelFondo.values[n - 1],
                          ),
                    )
                  : null,
            ),
          ),
          if (fondo.esencial.rotulo != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Gasto esencial ${fondo.esencial.rotulo}.',
                key: const ValueKey('ahorro-segun-plan'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          hueco,
        ],
        if (propuestas.isNotEmpty) ...[
          TarjetaModulo(
            key: const ValueKey('ahorro-reparto'),
            titulo: 'Para apartar esta semana',
            icono: Icons.savings_outlined,
            child: Column(
              children: [
                for (final a in propuestas)
                  _FilaPropuesta(
                    contexto: c,
                    aportacion: a,
                    bolsa: bolsas
                        .firstWhere((b) => b.bolsa.id == a.bolsaId)
                        .bolsa,
                  ),
              ],
            ),
          ),
          hueco,
        ] else if (guardada != null && c.puedeEscribir)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton(
              key: const ValueKey('ahorro-proponer'),
              onPressed: () => intentar(context, () async {
                final v = vistaSemana(c.datos, c.libroId, semana, hoy: c.hoy);
                await ref
                    .read(servicioFase2Provider)
                    .proponerReparto(
                      libroId: c.libroId,
                      semana: semana,
                      remanente: v.planSemanal.remanente,
                    );
              }),
              child: const Text('Proponer el reparto de la semana'),
            ),
          ),
        for (final b in bolsas) ...[
          BolsaAhorro(
            key: ValueKey('bolsa-${b.bolsa.id}'),
            nombre: b.bolsa.nombre,
            tipo: _tipoGadget(b.bolsa.tipo),
            saldoCentavos: b.saldo,
            metaCentavos: b.meta,
            pendienteCentavos: b.pendiente,
            estado: b.semaforo == null ? null : estadoDe(b.semaforo!),
          ),
          if (c.puedeEscribir && b.saldo > 0)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                key: ValueKey('retirar-${b.bolsa.id}'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => DialogoRetiro(contexto: c, bolsa: b.bolsa),
                ),
                child: const Text('Retirar'),
              ),
            ),
          hueco,
        ],
      ],
    );
  }

  static int _nivelAlcanzado(ResumenFondo f) {
    final s = f.esencial.semanal;
    if (s == null) return 0;
    var n = 0;
    for (final nivel in dom.NivelFondo.values) {
      if (f.saldo >= metaDelFondo(nivel, s)) n = nivel.numero;
    }
    return n;
  }
}

class _FilaPropuesta extends ConsumerWidget {
  const _FilaPropuesta({
    required this.contexto,
    required this.aportacion,
    required this.bolsa,
  });

  final ContextoFinanzas contexto;
  final AportacionAhorro aportacion;
  final dom.BolsaAhorro bolsa;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(bolsa.nombre)),
        Monto(aportacion.sugerido),
        if (contexto.puedeEscribir) ...[
          const SizedBox(width: 8),
          FilledButton(
            key: ValueKey('apartar-${aportacion.id}'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => DialogoConfirmarAportacion(
                contexto: contexto,
                aportacion: aportacion,
                nombreBolsa: bolsa.nombre,
              ),
            ),
            child: const Text('Apartar'),
          ),
          TextButton(
            key: ValueKey('posponer-${aportacion.id}'),
            onPressed: () => intentar(
              context,
              () => ref
                  .read(servicioFase2Provider)
                  .posponerAportacion(aportacion.id),
            ),
            child: const Text('Después'),
          ),
        ],
      ],
    ),
  );
}
