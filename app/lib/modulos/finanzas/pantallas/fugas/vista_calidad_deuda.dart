/// Deuda buena o mala en las pantallas de Deudas (Fase 8, bloque 6; spec 5 y
/// 8): la etiqueta con semáforo **y texto** (nunca solo color), las señales que
/// la explican, el gadget «Tus MSI y tu ingreso», la vista previa de un MSI
/// nuevo y el formulario corto «Declarar para qué fue».
///
/// **Una deuda mala solo avisa y sugiere** (decisión del dueño): nada de esto
/// bloquea un registro ni pide una confirmación extra. Las explicaciones de las
/// señales no llevan cifras; los porcentajes del gadget y de la vista previa
/// se ocultan con los montos ocultos.
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
import 'textos_fugas.dart';

/// Semáforo de un estado de calidad; `null` si no lleva color (por declarar,
/// sin costo, liquidada).
EstadoSemaforo? semaforoDeCalidad(EstadoCalidad e) => switch (e) {
  EstadoCalidad.buena => EstadoSemaforo.verde,
  EstadoCalidad.enVigilancia => EstadoSemaforo.ambar,
  EstadoCalidad.seVolvioMala => EstadoSemaforo.rojo,
  _ => null,
};

/// La etiqueta de una deuda: semáforo con texto, o un chip neutro con icono
/// para «Por declarar», «Sin costo» y «Liquidada».
class EtiquetaCalidadDeuda extends StatelessWidget {
  const EtiquetaCalidadDeuda({super.key, required this.estado});

  final EstadoCalidad estado;

  @override
  Widget build(BuildContext context) {
    final semaforo = semaforoDeCalidad(estado);
    if (semaforo != null) {
      return Semaforo(
        estado: semaforo,
        etiqueta: etiquetaDeCalidad(estado),
        conIcono: true,
        tamanoTexto: 14,
      );
    }
    final v = ValoresDiseno.de(context);
    return Semantics(
      label: 'Estado de la deuda: ${etiquetaDeCalidad(estado)}',
      excludeSemantics: true,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          Icon(
            estado == EstadoCalidad.porDeclarar
                ? Icons.help_outline
                : Icons.remove_circle_outline,
            size: 18,
            color: v.textoTenue,
          ),
          Text(
            etiquetaDeCalidad(estado),
            style: TextStyle(color: v.textoTenue, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// Etiqueta, texto corto y señales de una deuda. En la laptop, además,
/// «Declarar para qué fue» (a quien administra el libro).
class TarjetaCalidadDeuda extends ConsumerWidget {
  const TarjetaCalidadDeuda({
    super.key,
    required this.item,
    required this.contexto,
    this.telefono = false,
  });

  final DeudaConCalidad item;
  final ContextoFinanzas contexto;
  final bool telefono;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = item.mostrado;
    if (estado == EstadoCalidad.liquidada) return const SizedBox.shrink();
    final d = item.deuda;
    final tema = Theme.of(context).textTheme;
    final servicio = ref.watch(servicioFugasProvider);
    final puedeDeclarar =
        !telefono &&
        servicio.puedeDeclarar(contexto.libroId) &&
        item.calidad.estado != EstadoCalidad.sinCosto;
    final senales = [
      for (final s in item.calidad.senales)
        if (s.nivel != NivelSenal.verde) s,
    ];
    return Container(
      key: ValueKey('calidad-${d.id}'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: ValoresDiseno.de(context).borde),
        borderRadius: BorderRadius.circular(
          ValoresDiseno.de(context).radioChico,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              KeyedSubtree(
                key: ValueKey('calidad-etiqueta-${d.id}'),
                child: EtiquetaCalidadDeuda(estado: estado),
              ),
              Text('Buena o mala', style: tema.bodySmall),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            textoCortoDeCalidad(estado, esMsi: item.esMsi),
            key: ValueKey('calidad-texto-${d.id}'),
          ),
          if (item.mejoraEnEspera)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Esta semana mejoró; lo confirmo la próxima para no ir y '
                'venir.',
                key: ValueKey('calidad-espera-${d.id}'),
                style: tema.bodySmall,
              ),
            ),
          if (senales.isNotEmpty)
            Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: ValueKey('calidad-senales-${d.id}'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text('Por qué (${senales.length})'),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final s in senales)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${s.codigo} · ${nombreNivelSenal(s.nivel)}: '
                            '${s.explicacion}',
                          ),
                          if (s.sugerencia != null &&
                              s.nivel != NivelSenal.sinDato)
                            Text(
                              'Sugerencia: ${s.sugerencia}',
                              style: tema.bodySmall,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          if (estado == EstadoCalidad.porDeclarar && telefono)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Esto se declara en la laptop.',
                key: ValueKey('calidad-declara-laptop-${d.id}'),
                style: tema.bodySmall,
              ),
            ),
          if (puedeDeclarar)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                key: ValueKey('declarar-${d.id}'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => mostrarDeclararProposito(
                  context,
                  libroId: contexto.libroId,
                  item: item,
                  representado:
                      contexto.libro?.tipo == dom.TipoLibro.representado,
                ),
                child: Text(
                  item.declaracion == null
                      ? 'Declarar para qué fue'
                      : 'Cambiar para qué fue',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------- «Tus MSI y tu ingreso»

/// Gadget «Tus MSI y tu ingreso»: una barra con las marcas de 10 % y 20 % del
/// ingreso mensual y cuántos MSI hay activos a la vez. Con los montos ocultos
/// no dice el porcentaje (ni en el lector de pantalla); sí dice el nivel.
class GadgetMsiIngreso extends ConsumerWidget {
  const GadgetMsiIngreso({super.key, required this.resumen});

  final ResumenMsi resumen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (resumen.activos == 0) return const SizedBox.shrink();
    final ocultos = ref.watch(montosOcultosProvider);
    final v = ValoresDiseno.de(context);
    final nivel = resumen.nivel;
    final estado = switch (nivel) {
      NivelSenal.rojo => EstadoSemaforo.rojo,
      NivelSenal.ambar => EstadoSemaforo.ambar,
      _ => EstadoSemaforo.verde,
    };
    // Escala de 0 a 30 % del ingreso; las marcas van en 10 % y 20 %.
    const tope = 3000;
    final lleno = (resumen.puntosBase / tope).clamp(0.0, 1.0);
    final texto = resumen.sobreIngreso == NivelSenal.sinDato
        ? 'Aún no hay un ingreso con el que compararlos.'
        : ocultos
        ? 'Tus MSI pesan ${nombreNivelSenal(resumen.sobreIngreso).toLowerCase()} '
              'frente a tu ingreso. Muestra los montos para ver el porcentaje.'
        : 'Tus MSI suman ${formatearPuntosBase(resumen.puntosBase, decimales: 1)} '
              '% de tu ingreso mensual.';
    final activos = resumen.activos == 1
        ? '1 MSI activo'
        : '${resumen.activos} MSI activos a la vez';
    return TarjetaModulo(
      key: const ValueKey('deudas-gadget-msi'),
      titulo: 'Tus MSI y tu ingreso',
      icono: Icons.stacked_bar_chart,
      accion: Semaforo(
        estado: estado,
        etiqueta: estado.etiqueta,
        tamanoTexto: 12,
      ),
      child: Semantics(
        container: true,
        label:
            'Tus MSI y tu ingreso: $activos. ${ocultos ? 'Montos ocultos.' : texto}',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(activos, key: const ValueKey('msi-activos')),
            const SizedBox(height: 8),
            SizedBox(
              height: 20,
              child: LayoutBuilder(
                builder: (context, caja) {
                  final ancho = caja.maxWidth;
                  return Stack(
                    key: const ValueKey('msi-barra'),
                    children: [
                      Positioned.fill(
                        top: 6,
                        bottom: 6,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: v.borde,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 6,
                        bottom: 6,
                        width: ancho * lleno,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: estado.color(v),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      for (final marca in [1000, 2000])
                        Positioned(
                          left: ancho * marca / tope - 1,
                          top: 0,
                          bottom: 0,
                          width: 2,
                          child: ColoredBox(color: v.textoFuerte),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Las rayas marcan 10 % y 20 % de tu ingreso mensual.',
              key: const ValueKey('msi-marcas'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(texto, key: const ValueKey('msi-texto')),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------ vista previa de un MSI

/// «Con esta compra, tus MSI serían X % de tu ingreso y tendrías N a la vez»,
/// con el semáforo que quedaría. **Solo informa**: guardar no pide nada más.
class VistaPreviaMsiNuevo extends ConsumerWidget {
  const VistaPreviaMsiNuevo({
    super.key,
    required this.libroId,
    required this.mensualidadCentavos,
  });

  final String libroId;

  /// Mensualidad de la compra que se está capturando (0 = aún no hay monto).
  final int mensualidadCentavos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (mensualidadCentavos <= 0 || !ref.watch(puedeVerFugasProvider)) {
      return const SizedBox.shrink();
    }
    final VistaPreviaMsi vp;
    try {
      vp = ref
          .watch(servicioFugasProvider)
          .vistaPreviaMsi(libroId, mensualidadCentavos);
    } on Object {
      return const SizedBox.shrink();
    }
    final ocultos = ref.watch(montosOcultosProvider);
    final estado = switch (vp.nivel) {
      NivelSenal.rojo => EstadoSemaforo.rojo,
      NivelSenal.ambar => EstadoSemaforo.ambar,
      _ => EstadoSemaforo.verde,
    };
    final cuantos = vp.activos == 1 ? '1 a la vez' : '${vp.activos} a la vez';
    final texto = ocultos
        ? 'Con esta compra tendrías $cuantos. Muestra los montos para ver '
              'cuánto pesarían en tu ingreso.'
        : 'Con esta compra, tus MSI serían '
              '${formatearPuntosBase(vp.puntosBase, decimales: 1)} % de tu '
              'ingreso y tendrías $cuantos.';
    return Container(
      key: const ValueKey('msi-vista-previa'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: estado.color(ValoresDiseno.de(context))),
        borderRadius: BorderRadius.circular(
          ValoresDiseno.de(context).radioChico,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semaforo(
            estado: estado,
            etiqueta: 'Quedaría ${estado.etiqueta.toLowerCase()}',
            conIcono: true,
            tamanoTexto: 14,
          ),
          const SizedBox(height: 4),
          Text(texto, key: const ValueKey('msi-vista-previa-texto')),
          const SizedBox(height: 4),
          Text(
            'Solo es información: puedes guardarla igual.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------- declarar el propósito

/// Abre «Declarar para qué fue» (laptop). Devuelve `true` si se guardó.
Future<bool> mostrarDeclararProposito(
  BuildContext context, {
  required String libroId,
  required DeudaConCalidad item,
  required bool representado,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoProposito(
        libroId: libroId,
        item: item,
        representado: representado,
      ),
    ) ??
    false;

class _DialogoProposito extends ConsumerStatefulWidget {
  const _DialogoProposito({
    required this.libroId,
    required this.item,
    required this.representado,
  });

  final String libroId;
  final DeudaConCalidad item;
  final bool representado;

  @override
  ConsumerState<_DialogoProposito> createState() => _DialogoPropositoState();
}

class _DialogoPropositoState extends ConsumerState<_DialogoProposito> {
  late PropositoDeuda _proposito =
      widget.item.declaracion?.proposito ?? PropositoDeuda.bienDuradero;
  late EstadoObjetivo _estado =
      widget.item.declaracion?.estado ?? EstadoObjetivo.vigente;
  late bool _usoPoco = widget.item.declaracion?.usoPoco ?? false;
  late final _objetivo = TextEditingController(
    text: widget.item.declaracion?.objetivoTexto ?? '',
  );
  late final _vida = TextEditingController(
    text: widget.item.declaracion?.vidaUtilMeses?.toString() ?? '',
  );
  late final _precio = TextEditingController(
    text: widget.item.precioContadoCentavos == null
        ? ''
        : textoDeCentavos(widget.item.precioContadoCentavos!),
  );
  final _motivo = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _objetivo.dispose();
    _vida.dispose();
    _precio.dispose();
    _motivo.dispose();
    super.dispose();
  }

  String? get _errorObjetivo {
    final t = _objetivo.text.trim();
    if (t.isEmpty) return null;
    try {
      validarObjetivoTexto(t);
      return null;
    } on ArgumentError catch (e) {
      return '${e.message}';
    }
  }

  String? get _errorVida {
    final t = _vida.text.trim();
    if (t.isEmpty) return null;
    final n = int.tryParse(t);
    return n == null || n < 1 || n > 600 ? 'De 1 a 600 meses' : null;
  }

  String? get _errorPrecio {
    final t = _precio.text.trim();
    if (t.isEmpty) return null;
    final c = centavosDeTexto(t);
    return c == null || c <= 0 ? 'Monto no válido' : null;
  }

  bool get _puedeGuardar =>
      !_guardando &&
      _errorObjetivo == null &&
      _errorVida == null &&
      _errorPrecio == null &&
      (!widget.representado || motivoValido(_motivo.text));

  Future<void> _guardar() async {
    if (!_puedeGuardar) return;
    final servicio = ref.read(servicioFugasProvider);
    final navegador = Navigator.of(context);
    setState(() => _guardando = true);
    try {
      await servicio.declararProposito(
        libroId: widget.libroId,
        deudaId: widget.item.deuda.id,
        declaracion: DeclaracionDeuda(
          proposito: _proposito,
          objetivoTexto: _objetivo.text,
          vidaUtilMeses: int.tryParse(_vida.text.trim()),
          estado: _estado,
          usoPoco: _usoPoco,
          bienId: widget.item.declaracion?.bienId,
          objetivoId: widget.item.declaracion?.objetivoId,
        ),
        precioContadoCentavos: _precio.text.trim().isEmpty
            ? null
            : centavosDeTexto(_precio.text.trim()),
        motivo: _motivo.text,
      );
      if (mounted) avisar(context, 'Listo: guardé para qué fue.');
      if (navegador.canPop()) navegador.pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        avisarError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const ValueKey('proposito-hoja'),
    title: Text('Para qué fue: ${widget.item.deuda.titulo}'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Una vez por deuda; puedes cambiarlo después y se guarda el '
              'historial. Sin esto no la juzgo.',
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<PropositoDeuda>(
              key: const ValueKey('proposito-tipo'),
              initialValue: _proposito,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Fue para'),
              items: [
                for (final p in PropositoDeuda.values)
                  DropdownMenuItem(
                    value: p,
                    child: Text(
                      nombreProposito(p),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (p) => setState(() => _proposito = p ?? _proposito),
            ),
            TextField(
              key: const ValueKey('proposito-objetivo'),
              controller: _objetivo,
              maxLength: 80,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'En una frase (opcional)',
                helperText: 'Sin cifras ni precios.',
                errorText: _errorObjetivo,
              ),
            ),
            DropdownButtonFormField<EstadoObjetivo>(
              key: const ValueKey('proposito-estado'),
              initialValue: _estado,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Cómo va'),
              items: [
                for (final e in EstadoObjetivo.values)
                  DropdownMenuItem(
                    value: e,
                    child: Text(
                      nombreEstadoObjetivo(e),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (e) => setState(() => _estado = e ?? _estado),
            ),
            CheckboxListTile(
              key: const ValueKey('proposito-uso-poco'),
              value: _usoPoco,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (v) => setState(() => _usoPoco = v ?? false),
              title: const Text('Lo uso poco'),
            ),
            TextField(
              key: const ValueKey('proposito-vida'),
              controller: _vida,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Cuántos meses espero que dure (opcional)',
                errorText: _errorVida,
              ),
            ),
            if (widget.item.esMsi)
              TextField(
                key: const ValueKey('proposito-precio'),
                controller: _precio,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Lo que costaba de contado (opcional)',
                  prefixText: r'$ ',
                  helperText: 'Para ver si hubo sobreprecio. No lo invento.',
                  errorText: _errorPrecio,
                ),
              ),
            if (widget.representado)
              TextField(
                key: const ValueKey('proposito-motivo'),
                controller: _motivo,
                maxLength: 200,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Motivo (obligatorio)',
                  helperText:
                      '$ayudaMotivoDeclaracion Se registra en nombre de Papá.',
                  helperMaxLines: 3,
                  errorText: errorDeMotivo(_motivo.text),
                  errorMaxLines: 3,
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const ValueKey('proposito-guardar'),
        onPressed: _puedeGuardar ? _guardar : null,
        child: const Text('Guardar'),
      ),
    ],
  );
}

/// Ayuda del motivo de una declaración en el libro de Papá.
const ayudaMotivoDeclaracion =
    'Cuéntame en pocas palabras por qué lo declaras así.';
