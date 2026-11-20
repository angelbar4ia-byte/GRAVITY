/// Finanzas › Fugas (Fase 8, bloque 6; `docs/specs/fase-8-fugas-y-deudas.md`
/// 8.1 y 8.2): «Lo que se va sin que lo notes».
///
/// - **Resumen** de las cuatro fugas (hormiga, fantasma, vampiro, zombi) con su
///   conteo y su total, calculado del MISMO conjunto de gastos (hallazgo H-04:
///   `gastoIds` y `totalCentavos` de `FugaDetectada`).
/// - **Revisa un cobro** y la revisión mensual de hasta 7 preguntas.
/// - **Lista por tipo** con la regla que la puso ahí y la acción sugerida:
///   reconocer, «ya no lo uso», «ya lo cancelé» (fecha y folio) y «No es así»
///   (corregir con motivo cuando contradice la regla).
///
/// Todo se calcula en el dispositivo con reglas locales (D3, D6). **Sin
/// culpa:** sin respuesta no se acusa (un cobro por reconocer no cuenta en los
/// totales). Los montos respetan el modo oculto: no hay una cifra ni en el
/// texto ni en la etiqueta del lector de pantalla. Sin permiso de escribir (la
/// cuenta maestra, un libro archivado) la pantalla solo muestra: no hay
/// botones.
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide Semaforo, formatearCentavos, TipoLibro, puntosBaseEnCien;
import 'package:finanzas_dominio/finanzas_dominio.dart' as dom show TipoLibro;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../diseno/diseno.dart';
import '../../casos_uso/servicio_fugas.dart';
import '../../estado/proveedores.dart';
import '../../estado/proveedores_fugas.dart';
import '../comunes.dart';
import 'dialogos_fugas.dart';
import 'tarjeta_revisa_cobro.dart';
import 'textos_fugas.dart';

IconData _icono(TipoFuga t) => switch (t) {
  TipoFuga.hormiga => Icons.grain,
  TipoFuga.fantasma => Icons.visibility_off_outlined,
  TipoFuga.vampiro => Icons.water_drop_outlined,
  TipoFuga.zombie => Icons.hourglass_bottom_outlined,
  TipoFuga.ninguna => Icons.check_circle_outline,
};

const _tipos = [
  TipoFuga.hormiga,
  TipoFuga.fantasma,
  TipoFuga.vampiro,
  TipoFuga.zombie,
];

class VistaFugas extends ConsumerWidget {
  const VistaFugas({super.key, required this.contexto, this.telefono = false});

  final ContextoFinanzas contexto;
  final bool telefono;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = contexto;
    final hueco = SizedBox(height: ValoresDiseno.de(context).espacio * 2);
    if (!ref.watch(puedeVerFugasProvider)) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          EstadoVacio(
            key: ValueKey('fugas-sin-acceso'),
            icono: Icons.lock_outline,
            mensaje: 'Esta sección no está disponible aquí.',
            detalle:
                'Las fugas de un libro las ven quienes lo llevan: el dueño y '
                'la pareja.',
          ),
        ],
      );
    }
    final analisis = ref.watch(analisisFugasProvider(c.libroId));
    final servicio = ref.watch(servicioFugasProvider);
    final puedeResponder = servicio.puedeResponder(c.libroId);
    final representado = c.libro!.tipo == dom.TipoLibro.representado;
    final r = analisis.resultado;
    final cancelados = [
      for (final f in r.todas)
        if (f.estado == EstadoFuga.cancelada &&
            f.marcas.contains(MarcaFuga.canceladoSinFolio))
          f,
    ];
    final enVigilancia = [
      for (final f in r.todas)
        if (f.estado == EstadoFuga.enVigilancia) f,
    ];

    return ListView(
      key: const ValueKey('fugas-lista'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Lo que se va sin que lo notes',
          key: const ValueKey('fugas-titulo'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Calculado en tu equipo, con reglas; nada sale de aquí. Tú decides '
          'qué es una fuga: sin tu respuesta no acuso a nadie.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (!puedeResponder) ...[
          const SizedBox(height: 4),
          const Text(
            'Solo lectura: aquí no se responde ni se cambia nada.',
            key: ValueKey('fugas-solo-lectura'),
          ),
        ],
        hueco,
        if (analisis.preguntas.isNotEmpty) ...[
          TarjetaRevisaUnCobro(contexto: c),
          hueco,
        ],
        if (!analisis.hayAlgo && enVigilancia.isEmpty && cancelados.isEmpty)
          const EstadoVacio(
            key: ValueKey('fugas-vacio'),
            icono: Icons.check_circle_outline,
            mensaje: 'Por ahora no veo nada que se esté yendo en silencio.',
            detalle:
                'Cuando registres gastos con su comercio (y marques «Es un '
                'cargo automático» si se cobra solo), te ayudo a encontrar '
                'los cobros que se repiten.',
          )
        else ...[
          _Resumen(analisis: analisis, telefono: telefono),
          if (r.alertaConjuntoHormiga) ...[
            const SizedBox(height: 8),
            const _AvisoConjunto(),
          ],
          hueco,
          if (analisis.porReconocer.isNotEmpty) ...[
            _SeccionPorReconocer(
              contexto: c,
              fugas: analisis.porReconocer,
              puedeResponder: puedeResponder,
              representado: representado,
            ),
            hueco,
          ],
          for (final t in _tipos)
            if (analisis.deTipo(t).isNotEmpty) ...[
              _SeccionTipo(
                contexto: c,
                tipo: t,
                fugas: analisis.deTipo(t),
                puedeResponder: puedeResponder,
                representado: representado,
              ),
              hueco,
            ],
          if (cancelados.isNotEmpty) ...[
            _SeccionCancelados(
              contexto: c,
              fugas: cancelados,
              puedeResponder: puedeResponder,
              representado: representado,
            ),
            hueco,
          ],
          if (enVigilancia.isNotEmpty)
            Text(
              enVigilancia.length == 1
                  ? 'Tienes 1 cobro en vigilancia: te lo vuelvo a preguntar '
                        'en unos meses.'
                  : 'Tienes ${enVigilancia.length} cobros en vigilancia: te '
                        'los vuelvo a preguntar en unos meses.',
              key: const ValueKey('fugas-en-vigilancia'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- resumen

class _Resumen extends StatelessWidget {
  const _Resumen({required this.analisis, required this.telefono});

  final AnalisisFugas analisis;
  final bool telefono;

  @override
  Widget build(BuildContext context) {
    final tarjetas = [
      for (final t in _tipos) _TarjetaResumen(tipo: t, analisis: analisis),
    ];
    if (telefono) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final t in tarjetas) ...[t, const SizedBox(height: 8)],
        ],
      );
    }
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [for (final t in tarjetas) SizedBox(width: 260, child: t)],
    );
  }
}

class _TarjetaResumen extends StatelessWidget {
  const _TarjetaResumen({required this.tipo, required this.analisis});

  final TipoFuga tipo;
  final AnalisisFugas analisis;

  @override
  Widget build(BuildContext context) {
    final fugas = analisis.deTipo(tipo);
    final total = analisis.total(tipo);
    // H-04: el conteo sale de la MISMA lista de gastos que el total.
    final compras = [for (final f in fugas) ...f.gastoIds].length;
    final String conteo;
    if (fugas.isEmpty) {
      conteo = 'Nada por ahora';
    } else if (tipo == TipoFuga.hormiga) {
      conteo = compras == 1 ? '1 compra' : '$compras compras';
    } else {
      conteo = fugas.length == 1 ? '1 cobro' : '${fugas.length} cobros';
    }
    return TarjetaModulo(
      key: ValueKey('fugas-resumen-${tipo.name}'),
      titulo: nombreTipoFuga(tipo),
      icono: _icono(tipo),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            conteo,
            key: ValueKey('fugas-conteo-${tipo.name}'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (fugas.isNotEmpty) ...[
            DatoConMonto(
              tipo == TipoFuga.hormiga ? 'En 4 semanas' : 'Últimos 12 meses',
              total.totalCentavos,
            ),
            DatoConMonto('Al año (estimado)', total.anualCentavos),
          ],
        ],
      ),
    );
  }
}

class _AvisoConjunto extends StatelessWidget {
  const _AvisoConjunto();

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey('fugas-aviso-conjunto'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(Icons.info_outline, size: 18),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          'Juntas, tus compras chicas ya pesan bastante en tu ingreso. '
          'Solo te lo cuento: tú decides qué hacer.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ],
  );
}

// ------------------------------------------------------------ secciones

Future<void> _guardar(
  BuildContext context,
  Future<void> Function() accion,
  String mensaje,
) async {
  final ok = await intentar(context, accion);
  if (ok && context.mounted) avisar(context, mensaje);
}

class _SeccionPorReconocer extends ConsumerWidget {
  const _SeccionPorReconocer({
    required this.contexto,
    required this.fugas,
    required this.puedeResponder,
    required this.representado,
  });

  final ContextoFinanzas contexto;
  final List<FugaDetectada> fugas;
  final bool puedeResponder;
  final bool representado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = contexto.datos;
    return TarjetaModulo(
      key: const ValueKey('fugas-por-reconocer'),
      titulo: 'Por reconocer (${fugas.length})',
      icono: Icons.help_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            queEsLaFuga(TipoFuga.fantasma),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          for (final f in fugas)
            _FilaFuga(
              key: ValueKey('fuga-fila-${f.clave}'),
              contexto: contexto,
              f: f,
              titulo: tituloDeFuga(f, d),
              puedeResponder: puedeResponder,
              representado: representado,
              acciones: [
                for (final r in [RespuestaPersona.si, RespuestaPersona.no])
                  _Accion(
                    ValueKey('fuga-reconoce-${r.name}-${f.clave}'),
                    textoDeRespuesta(TipoPregunta.reconoce, r),
                    (ref, context) => _guardar(
                      context,
                      () => ref
                          .read(servicioFugasProvider)
                          .responder(
                            libroId: contexto.libroId,
                            clave: f.clave,
                            pregunta: PreguntaFuga.reconoce,
                            respuesta: r,
                          ),
                      'Listo, lo guardé.',
                    ),
                  ),
                _Accion(
                  ValueKey('fuga-reconoce-despues-${f.clave}'),
                  'Después',
                  (ref, context) => _guardar(
                    context,
                    () => ref
                        .read(servicioFugasProvider)
                        .responder(
                          libroId: contexto.libroId,
                          clave: f.clave,
                          pregunta: PreguntaFuga.reconoce,
                          respuesta: RespuestaPersona.despues,
                        ),
                    'Está bien: te lo vuelvo a preguntar más adelante.',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SeccionTipo extends ConsumerWidget {
  const _SeccionTipo({
    required this.contexto,
    required this.tipo,
    required this.fugas,
    required this.puedeResponder,
    required this.representado,
  });

  final ContextoFinanzas contexto;
  final TipoFuga tipo;
  final List<FugaDetectada> fugas;
  final bool puedeResponder;
  final bool representado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = contexto.datos;
    return TarjetaModulo(
      key: ValueKey('fugas-seccion-${tipo.name}'),
      titulo: '${nombreTipoFuga(tipo)} (${fugas.length})',
      icono: _icono(tipo),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final f in fugas)
            _FilaFuga(
              key: ValueKey('fuga-fila-${f.clave}'),
              contexto: contexto,
              f: f,
              titulo: tituloDeFuga(f, d),
              puedeResponder: puedeResponder,
              representado: representado,
              acciones: _accionesDe(f, contexto, representado),
            ),
        ],
      ),
    );
  }
}

class _SeccionCancelados extends ConsumerWidget {
  const _SeccionCancelados({
    required this.contexto,
    required this.fugas,
    required this.puedeResponder,
    required this.representado,
  });

  final ContextoFinanzas contexto;
  final List<FugaDetectada> fugas;
  final bool puedeResponder;
  final bool representado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = contexto.datos;
    return TarjetaModulo(
      key: const ValueKey('fugas-cancelados'),
      titulo: 'Cancelados sin folio (${fugas.length})',
      icono: Icons.event_busy_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Pide el folio de cancelación al proveedor y guárdalo: te sirve '
            'si el cobro sigue.',
          ),
          for (final f in fugas)
            _FilaFuga(
              key: ValueKey('fuga-fila-${f.clave}'),
              contexto: contexto,
              f: f,
              titulo: tituloDeFuga(f, d),
              puedeResponder: puedeResponder,
              representado: representado,
              acciones: [
                _Accion(
                  ValueKey('fuga-agregar-folio-${f.clave}'),
                  'Agregar el folio',
                  (ref, context) => mostrarCancelacion(
                    context,
                    libroId: contexto.libroId,
                    clave: f.clave,
                    titulo: tituloDeFuga(f, d),
                    representado: representado,
                    fechaInicial: ref
                        .read(fugasGuardadasProvider)
                        .patronDeClave(contexto.libroId, f.clave)
                        ?.canceladoEn,
                  ),
                ),
              ],
              mostrarRegla: false,
            ),
        ],
      ),
    );
  }
}

/// Lo que se puede hacer con una fuga confirmada.
List<_Accion> _accionesDe(
  FugaDetectada f,
  ContextoFinanzas c,
  bool representado,
) {
  final recurrente = esCobroRecurrente(f);
  Future<void> responder(
    WidgetRef ref,
    BuildContext context,
    PreguntaFuga p,
    RespuestaPersona r,
    String mensaje,
  ) => _guardar(
    context,
    () => ref
        .read(servicioFugasProvider)
        .responder(
          libroId: c.libroId,
          clave: f.clave,
          pregunta: p,
          respuesta: r,
        ),
    mensaje,
  );
  final d = c.datos;
  return [
    if (f.fuga == TipoFuga.fantasma && recurrente)
      _Accion(
        ValueKey('fuga-reconocer-${f.clave}'),
        'Lo reconozco',
        (ref, context) => responder(
          ref,
          context,
          PreguntaFuga.reconoce,
          RespuestaPersona.si,
          'Listo: lo reconocí y dejó de ser un fantasma.',
        ),
      ),
    if (f.fuga == TipoFuga.vampiro && recurrente && f.regla == 'VB')
      _Accion(
        ValueKey('fuga-ya-no-lo-uso-${f.clave}'),
        'Ya no lo uso',
        (ref, context) => responder(
          ref,
          context,
          PreguntaFuga.yaNoSirve,
          RespuestaPersona.si,
          'Listo: lo marqué como zombi. Pide la baja formal y guarda el '
          'folio de cancelación.',
        ),
      ),
    if (recurrente &&
        (f.fuga == TipoFuga.fantasma ||
            f.fuga == TipoFuga.zombie ||
            f.fuga == TipoFuga.vampiro))
      _Accion(
        ValueKey('fuga-cancele-${f.clave}'),
        'Ya lo cancelé',
        (ref, context) => mostrarCancelacion(
          context,
          libroId: c.libroId,
          clave: f.clave,
          titulo: tituloDeFuga(f, d),
          representado: representado,
        ),
      ),
    _Accion(
      ValueKey('fuga-no-es-asi-${f.clave}'),
      'No es así',
      (ref, context) => mostrarNoEsAsi(
        context,
        libroId: c.libroId,
        f: f,
        titulo: tituloDeFuga(f, d),
        representado: representado,
      ),
    ),
  ];
}

// -------------------------------------------------------------------- fila

class _Accion {
  const _Accion(this.llave, this.texto, this.alTocar);

  final Key llave;
  final String texto;
  final Future<void> Function(WidgetRef ref, BuildContext context) alTocar;
}

class _FilaFuga extends ConsumerWidget {
  const _FilaFuga({
    super.key,
    required this.contexto,
    required this.f,
    required this.titulo,
    required this.puedeResponder,
    required this.representado,
    required this.acciones,
    this.mostrarRegla = true,
  });

  final ContextoFinanzas contexto;
  final FugaDetectada f;
  final String titulo;
  final bool puedeResponder;
  final bool representado;
  final List<_Accion> acciones;
  final bool mostrarRegla;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context).textTheme;
    final hormiga = f.fuga == TipoFuga.hormiga;
    final porReconocer = f.estado == EstadoFuga.porReconocer;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titulo, style: tema.titleSmall),
          const SizedBox(height: 2),
          Text(
            [
              if (!hormiga) nombreCadencia(f.cadencia),
              if (mostrarRegla && f.regla != 'PERSONA')
                'Regla ${f.regla}: ${fraseDeLaRegla(f)}'
              else if (mostrarRegla)
                fraseDeLaRegla(f),
            ].where((t) => t.isNotEmpty).join(' · '),
            key: ValueKey('fuga-regla-${f.clave}'),
            style: tema.bodySmall,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 16,
            runSpacing: 2,
            children: [
              if (hormiga) ...[
                // H-04: las compras y el total salen del mismo conjunto.
                Text(
                  f.gastoIds.length == 1
                      ? '1 compra'
                      : '${f.gastoIds.length} compras',
                  key: ValueKey('fuga-compras-${f.clave}'),
                ),
                DatoConMonto('En 4 semanas', f.totalCentavos),
              ] else
                DatoConMonto('Por cobro', f.ultimoMontoCentavos),
              DatoConMonto('Al año (estimado)', f.anualCentavos),
            ],
          ),
          if (f.marcas.contains(MarcaFuga.canceladoSinFolio))
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Cancelado sin folio: falta completar el folio.'),
            ),
          if (porReconocer)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Todavía no cuenta como fuga: sin tu respuesta no acuso a '
                'nadie.',
                style: tema.bodySmall,
              ),
            )
          else if (mostrarRegla && accionSugerida(f).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                accionSugerida(f),
                key: ValueKey('fuga-accion-${f.clave}'),
              ),
            ),
          if (puedeResponder && acciones.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final a in acciones)
                    OutlinedButton(
                      key: a.llave,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: () => a.alTocar(ref, context),
                      child: Text(a.texto),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
