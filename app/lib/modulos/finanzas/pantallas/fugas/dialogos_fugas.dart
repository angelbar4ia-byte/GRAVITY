/// Hojas de las fugas silenciosas (Fase 8, bloque 6): «No es así» (corregir la
/// clasificación con motivo cuando contradice la regla), «Ya lo cancelé»
/// (fecha y folio de cancelación) y la revisión mensual de hasta 7 preguntas.
///
/// Todo se guarda con el servicio ([ServicioFugas]), que revisa el permiso y
/// pide señal; los errores se dicen sin culpa. Sin respuesta no se acusa:
/// «Después» y «Saltar» no cambian nada.
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide Semaforo, formatearCentavos, TipoLibro, puntosBaseEnCien;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../casos_uso/servicio_fugas.dart';
import '../../estado/proveedores_fugas.dart';
import '../comunes.dart';
import 'textos_fugas.dart';

/// Qué eligió la persona en «No es así».
enum OpcionNoEsAsi { ninguna, otro, cancelar, vigilar }

/// Ayuda del motivo cuando la decisión contradice a la regla.
const ayudaMotivoFuga =
    'Cuéntame en pocas palabras por qué (por ejemplo, «lo uso para '
    'trabajar»). Me ayuda a no volver a proponerlo.';

/// Abre «No es así» para la fuga [f]. Devuelve `true` si algo se guardó. Si la
/// persona elige «Lo cancelé», abre enseguida la hoja de cancelación.
Future<bool> mostrarNoEsAsi(
  BuildContext context, {
  required String libroId,
  required FugaDetectada f,
  required String titulo,
  required bool representado,
}) async {
  final r = await showDialog<Object>(
    context: context,
    builder: (_) => _DialogoNoEsAsi(
      libroId: libroId,
      f: f,
      titulo: titulo,
      representado: representado,
    ),
  );
  if (r == OpcionNoEsAsi.cancelar && context.mounted) {
    return mostrarCancelacion(
      context,
      libroId: libroId,
      clave: f.clave,
      titulo: titulo,
      representado: representado,
    );
  }
  return r == true;
}

class _DialogoNoEsAsi extends ConsumerStatefulWidget {
  const _DialogoNoEsAsi({
    required this.libroId,
    required this.f,
    required this.titulo,
    required this.representado,
  });

  final String libroId;
  final FugaDetectada f;
  final String titulo;
  final bool representado;

  @override
  ConsumerState<_DialogoNoEsAsi> createState() => _DialogoNoEsAsiState();
}

class _DialogoNoEsAsiState extends ConsumerState<_DialogoNoEsAsi> {
  OpcionNoEsAsi? _opcion;
  TipoFuga? _otro;
  final _motivo = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  List<TipoFuga> get _otrosTipos => [
    for (final t in TipoFuga.values)
      if (t != TipoFuga.ninguna && t != widget.f.fuga) t,
  ];

  bool get _necesitaMotivo =>
      _opcion == OpcionNoEsAsi.ninguna ||
      _opcion == OpcionNoEsAsi.otro ||
      widget.representado;

  bool get _puedeGuardar {
    if (_guardando || _opcion == null) return false;
    if (_opcion == OpcionNoEsAsi.otro && _otro == null) return false;
    return !_necesitaMotivo || motivoValido(_motivo.text);
  }

  Future<void> _guardar() async {
    if (!_puedeGuardar) return;
    final servicio = ref.read(servicioFugasProvider);
    final navegador = Navigator.of(context);
    setState(() => _guardando = true);
    try {
      await servicio.clasificar(
        libroId: widget.libroId,
        clave: widget.f.clave,
        fuga: switch (_opcion!) {
          OpcionNoEsAsi.otro => _otro!,
          _ => TipoFuga.ninguna,
        },
        vigilar: _opcion == OpcionNoEsAsi.vigilar,
        motivo: _motivo.text,
      );
      if (navegador.canPop()) navegador.pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        avisarError(context, e);
      }
    }
  }

  /// «Lo necesito, pero quiero revisarlo» guarda al tocar (dos toques en
  /// total) cuando no hace falta un motivo.
  void _elegir(OpcionNoEsAsi o) {
    setState(() => _opcion = o);
    if (o == OpcionNoEsAsi.cancelar) {
      Navigator.of(context).pop(OpcionNoEsAsi.cancelar);
      return;
    }
    if (o == OpcionNoEsAsi.vigilar && !widget.representado) {
      _guardar();
    }
  }

  Widget _opcionTile(
    OpcionNoEsAsi o,
    String titulo,
    String detalle,
    IconData icono,
  ) => ListTile(
    key: ValueKey('noesasi-${o.name}'),
    contentPadding: EdgeInsets.zero,
    minVerticalPadding: 12,
    leading: Icon(icono),
    title: Text(titulo),
    subtitle: Text(detalle),
    selected: _opcion == o,
    onTap: _guardando ? null : () => _elegir(o),
  );

  @override
  Widget build(BuildContext context) {
    final recurrente = esCobroRecurrente(widget.f);
    return AlertDialog(
      key: const ValueKey('noesasi-hoja'),
      title: Text('No es así: ${widget.titulo}'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tú decides. Corregir no borra nada: queda una decisión nueva '
                'que reemplaza a la anterior.',
              ),
              const SizedBox(height: 8),
              _opcionTile(
                OpcionNoEsAsi.ninguna,
                'No es una fuga',
                'Dejo de proponerlo.',
                Icons.check_circle_outline,
              ),
              _opcionTile(
                OpcionNoEsAsi.otro,
                'Es de otro tipo',
                'Elijo cuál es.',
                Icons.swap_horiz,
              ),
              if (recurrente)
                _opcionTile(
                  OpcionNoEsAsi.cancelar,
                  'Lo cancelé',
                  'Guardo la fecha y el folio de cancelación.',
                  Icons.event_busy_outlined,
                ),
              _opcionTile(
                OpcionNoEsAsi.vigilar,
                'Lo necesito, pero quiero revisarlo',
                'Te lo vuelvo a preguntar en unos meses.',
                Icons.visibility_outlined,
              ),
              if (_opcion == OpcionNoEsAsi.otro) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final t in _otrosTipos)
                      ChoiceChip(
                        key: ValueKey('noesasi-tipo-${t.name}'),
                        label: Text(nombreTipoFuga(t)),
                        selected: _otro == t,
                        onSelected: (_) => setState(() => _otro = t),
                      ),
                  ],
                ),
              ],
              if (_opcion != null && _necesitaMotivo)
                TextField(
                  key: const ValueKey('noesasi-motivo'),
                  controller: _motivo,
                  maxLength: 200,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Motivo (obligatorio)',
                    helperText: widget.representado
                        ? '$ayudaMotivoFuga Se registra en nombre de Papá.'
                        : ayudaMotivoFuga,
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
          key: const ValueKey('noesasi-salir'),
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('noesasi-guardar'),
          onPressed: _puedeGuardar ? _guardar : null,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------- cancelación

/// Abre «Ya lo cancelé»: fecha y folio. Devuelve `true` si se guardó.
Future<bool> mostrarCancelacion(
  BuildContext context, {
  required String libroId,
  required String clave,
  required String titulo,
  required bool representado,
  Fecha? fechaInicial,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoCancelacion(
        libroId: libroId,
        clave: clave,
        titulo: titulo,
        representado: representado,
        fechaInicial: fechaInicial,
      ),
    ) ??
    false;

/// Texto de la acción sugerida al cancelar.
const ayudaFolio =
    'Pide la baja formal al proveedor y guarda el folio de cancelación.';

class _DialogoCancelacion extends ConsumerStatefulWidget {
  const _DialogoCancelacion({
    required this.libroId,
    required this.clave,
    required this.titulo,
    required this.representado,
    this.fechaInicial,
  });

  final String libroId;
  final String clave;
  final String titulo;
  final bool representado;
  final Fecha? fechaInicial;

  @override
  ConsumerState<_DialogoCancelacion> createState() =>
      _DialogoCancelacionState();
}

class _DialogoCancelacionState extends ConsumerState<_DialogoCancelacion> {
  final _folio = TextEditingController();
  final _motivo = TextEditingController();
  Fecha? _fecha;
  bool _guardando = false;

  @override
  void dispose() {
    _folio.dispose();
    _motivo.dispose();
    super.dispose();
  }

  String? get _errorFolio {
    final t = _folio.text.trim();
    if (t.isEmpty) return null;
    try {
      validarFolio(t);
      return null;
    } on ArgumentError catch (e) {
      return '${e.message}';
    }
  }

  bool get _puedeGuardar =>
      !_guardando &&
      _errorFolio == null &&
      (!widget.representado || motivoValido(_motivo.text));

  Future<void> _guardar(Fecha hoy) async {
    if (!_puedeGuardar) return;
    final servicio = ref.read(servicioFugasProvider);
    final navegador = Navigator.of(context);
    setState(() => _guardando = true);
    try {
      await servicio.cancelar(
        libroId: widget.libroId,
        clave: widget.clave,
        fecha: _fecha ?? widget.fechaInicial ?? hoy,
        folio: _folio.text,
        motivo: _motivo.text,
      );
      if (navegador.canPop()) navegador.pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        avisarError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hoy = ref.watch(servicioFugasProvider).hoy;
    final fecha = _fecha ?? widget.fechaInicial ?? hoy;
    return AlertDialog(
      key: const ValueKey('cancelacion-hoja'),
      title: Text('Ya lo cancelé: ${widget.titulo}'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(ayudaFolio),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: ActionChip(
                  key: const ValueKey('cancelacion-fecha'),
                  avatar: const Icon(Icons.event_outlined, size: 18),
                  label: Text(fecha == hoy ? 'Hoy' : textoFecha(fecha)),
                  onPressed: () async {
                    final f = await elegirFecha(context, fecha);
                    if (f != null && !f.despuesDe(hoy)) {
                      setState(() => _fecha = f);
                    }
                  },
                ),
              ),
              TextField(
                key: const ValueKey('cancelacion-folio'),
                controller: _folio,
                maxLength: 40,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
                ],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Folio de cancelación',
                  helperText:
                      'Letras, números y guiones. Sin folio se guarda como '
                      '«cancelado sin folio» y te lo recordaré.',
                  helperMaxLines: 3,
                  errorText: _errorFolio,
                ),
              ),
              if (widget.representado)
                TextField(
                  key: const ValueKey('cancelacion-motivo'),
                  controller: _motivo,
                  maxLength: 200,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Motivo (obligatorio)',
                    helperText:
                        '$ayudaMotivoFuga Se registra en nombre de Papá.',
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
          key: const ValueKey('cancelacion-guardar'),
          onPressed: _puedeGuardar ? () => _guardar(hoy) : null,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

// ------------------------------------------------------ revisión mensual

/// Abre la revisión mensual: de una en una, con dos respuestas grandes,
/// «Después» y «Saltar». Como máximo [ParametrosFugas.revisionMaxPreguntas].
Future<void> mostrarRevisionMensual(
  BuildContext context, {
  required String libroId,
}) => showDialog<void>(
  context: context,
  builder: (_) => _DialogoRevision(libroId: libroId),
);

class _DialogoRevision extends ConsumerStatefulWidget {
  const _DialogoRevision({required this.libroId});

  final String libroId;

  @override
  ConsumerState<_DialogoRevision> createState() => _DialogoRevisionState();
}

class _DialogoRevisionState extends ConsumerState<_DialogoRevision> {
  late final List<PreguntaRevision> _preguntas = [
    ...ref.read(analisisFugasProvider(widget.libroId)).preguntas,
  ];
  int _i = 0;
  bool _guardando = false;

  Future<void> _responder(RespuestaPersona r) async {
    final p = _preguntas[_i];
    final servicio = ref.read(servicioFugasProvider);
    setState(() => _guardando = true);
    try {
      await servicio.responder(
        libroId: widget.libroId,
        clave: p.clave,
        pregunta: p.tipo == TipoPregunta.reconoce
            ? PreguntaFuga.reconoce
            : PreguntaFuga.uso,
        respuesta: r,
      );
      if (mounted) {
        setState(() {
          _guardando = false;
          _i++;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        avisarError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(servicioFugasProvider).finanzas.datos;
    final analisis = ref.watch(analisisFugasProvider(widget.libroId));
    final terminada = _i >= _preguntas.length;
    return AlertDialog(
      key: const ValueKey('revision-hoja'),
      title: const Text('Revisión de cobros'),
      content: SizedBox(
        width: 460,
        child: terminada
            ? Text(
                _preguntas.isEmpty
                    ? 'No hay nada por revisar ahora.'
                    : 'Listo, gracias por revisar. Lo que dejaste para '
                          'después te lo vuelvo a preguntar más adelante.',
                key: const ValueKey('revision-listo'),
              )
            : _Pregunta(
                numero: _i + 1,
                total: _preguntas.length,
                pregunta: _preguntas[_i],
                titulo: analisis.resultado.de(_preguntas[_i].clave) == null
                    ? 'Un cobro'
                    : tituloDeFuga(
                        analisis.resultado.de(_preguntas[_i].clave)!,
                        d,
                      ),
                ocupado: _guardando,
                alResponder: _responder,
                alSaltar: () => setState(() => _i++),
              ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('revision-cerrar'),
          onPressed: () => Navigator.pop(context),
          child: Text(terminada ? 'Cerrar' : 'Salir'),
        ),
      ],
    );
  }
}

class _Pregunta extends StatelessWidget {
  const _Pregunta({
    required this.numero,
    required this.total,
    required this.pregunta,
    required this.titulo,
    required this.ocupado,
    required this.alResponder,
    required this.alSaltar,
  });

  final int numero;
  final int total;
  final PreguntaRevision pregunta;
  final String titulo;
  final bool ocupado;
  final ValueChanged<RespuestaPersona> alResponder;
  final VoidCallback alSaltar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final t = pregunta.tipo;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Pregunta $numero de $total',
            key: const ValueKey('revision-avance'),
            style: tema.bodySmall,
          ),
          const SizedBox(height: 8),
          Text(titulo, style: tema.titleMedium),
          const SizedBox(height: 4),
          Text(textoDePregunta(t), key: const ValueKey('revision-pregunta')),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('revision-si'),
            style: FilledButton.styleFrom(minimumSize: const Size(48, 52)),
            onPressed: ocupado ? null : () => alResponder(RespuestaPersona.si),
            child: Text(textoDeRespuesta(t, RespuestaPersona.si)),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            key: const ValueKey('revision-no'),
            style: FilledButton.styleFrom(minimumSize: const Size(48, 52)),
            onPressed: ocupado ? null : () => alResponder(RespuestaPersona.no),
            child: Text(textoDeRespuesta(t, RespuestaPersona.no)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                key: const ValueKey('revision-despues'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: ocupado
                    ? null
                    : () => alResponder(RespuestaPersona.despues),
                child: const Text('Después'),
              ),
              TextButton(
                key: const ValueKey('revision-saltar'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: ocupado ? null : alSaltar,
                child: const Text('Saltar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
