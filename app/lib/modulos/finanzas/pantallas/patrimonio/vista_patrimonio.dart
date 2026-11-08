/// Patrimonio (Fase 8, bloque 3): objetivos con su avance, inversiones con su
/// origen, y bienes y previsión con su fecha de captura. Todo lo captura la
/// persona; la app no inventa cifras ni calcula rendimientos. Nada sale a la
/// IA ni a las bocinas (D3).
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    show AportacionAhorro, Fecha, Semana;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../diseno/diseno.dart';
import '../../casos_uso/servicio_fase2.dart';
import '../../datos/patrimonio.dart';
import '../../estado/proveedores.dart';
import '../../estado/proveedores_fase2.dart';
import '../../estado/proveedores_patrimonio.dart';
import '../comunes.dart';

/// Permiso de patrimonio en el libro activo del contexto.
PermisoPatrimonio permisoPatrimonioDe(ContextoFinanzas c) {
  final p = permisoPatrimonio(
    c.permiso,
    c.rol,
    soloLectura: c.soloLecturaTotal,
  );
  return PermisoPatrimonio(ver: p.ver, editar: p.editar && c.puedeEscribir);
}

/// Apartado semanal de [bolsaId] en la semana guardada (lectura de lo que ya
/// existe en Ahorro): lo aportado si ya se confirmó, si no lo sugerido.
int apartadoSemanalDeBolsa(
  Iterable<AportacionAhorro> aportaciones,
  String? semanaId,
  String bolsaId,
) {
  if (semanaId == null) return 0;
  var total = 0;
  for (final a in aportaciones) {
    if (a.semanaId == semanaId && a.bolsaId == bolsaId) {
      total += a.aportado > 0 ? a.aportado : a.sugerido;
    }
  }
  return total;
}

class VistaPatrimonio extends ConsumerWidget {
  const VistaPatrimonio({super.key, required this.contexto});

  final ContextoFinanzas contexto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = contexto;
    final permiso = permisoPatrimonioDe(c);
    if (!permiso.ver) {
      return const EstadoVacio(
        mensaje: 'Esta sección no está disponible para ti.',
        detalle: 'El patrimonio solo lo ve su titular.',
      );
    }
    final datos = ref.watch(patrimonioDeLibroProvider(c.libroId));
    return datos.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('No se pudo cargar: $e')),
      data: (d) {
        final v = ValoresDiseno.de(context);
        final hueco = SizedBox(height: v.espacio * 2);
        return ListView(
          key: const ValueKey('patrimonio-lista'),
          padding: const EdgeInsets.all(16),
          children: [
            _Objetivos(contexto: c, objetivos: d.objetivos, permiso: permiso),
            hueco,
            _Inversiones(
              contexto: c,
              inversiones: d.inversiones,
              permiso: permiso,
            ),
            hueco,
            _BienesYPrevision(contexto: c, datos: d, permiso: permiso),
          ],
        );
      },
    );
  }
}

void _guardado(WidgetRef ref, String libroId) =>
    ref.invalidate(patrimonioDeLibroProvider(libroId));

// ----------------------------------------------------------------- objetivos

class _Objetivos extends ConsumerWidget {
  const _Objetivos({
    required this.contexto,
    required this.objetivos,
    required this.permiso,
  });

  final ContextoFinanzas contexto;
  final List<Objetivo> objetivos;
  final PermisoPatrimonio permiso;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = contexto;
    final semana = Semana.de(c.hoy);
    final bolsas = {
      for (final b
          in ref.watch(servicioFase2Provider).bolsas(c.libroId, semana))
        b.bolsa.id: b,
    };
    final guardada = c.datos.semanaGuardada(c.libroId, semana);
    return TarjetaModulo(
      key: const ValueKey('patrimonio-objetivos'),
      titulo: 'Objetivos',
      icono: Icons.flag_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (objetivos.isEmpty)
            const Text('Aún no tienes objetivos.')
          else
            for (final o in objetivos)
              _FilaObjetivo(
                objetivo: o,
                avance: avanceObjetivo(
                  metaCentavos: o.metaCentavos,
                  ahorrado: bolsas[o.bolsaId]?.saldo ?? 0,
                  apartadoSemanal: o.bolsaId == null
                      ? 0
                      : apartadoSemanalDeBolsa(
                          c.datos.aportaciones,
                          guardada?.id,
                          o.bolsaId!,
                        ),
                  fechaMeta: o.fechaMeta,
                  hoy: c.hoy,
                ),
                alEditar: permiso.editar
                    ? () => showDialog<void>(
                        context: context,
                        builder: (_) => _DialogoObjetivo(
                          contexto: c,
                          objetivo: o,
                          bolsas: [for (final b in bolsas.values) b],
                        ),
                      )
                    : null,
              ),
          if (permiso.editar)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                key: const ValueKey('objetivo-nuevo'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _DialogoObjetivo(
                    contexto: c,
                    bolsas: [for (final b in bolsas.values) b],
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Nuevo objetivo'),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilaObjetivo extends StatelessWidget {
  const _FilaObjetivo({
    required this.objetivo,
    required this.avance,
    this.alEditar,
  });

  final Objetivo objetivo;
  final AvanceObjetivo avance;
  final VoidCallback? alEditar;

  String get _texto {
    if (avance.alcanzado) return 'Meta alcanzada.';
    final semanas = avance.semanasParaAlcanzar;
    if (semanas == null) {
      return 'Aún no hay apartado semanal para estimar cuándo se alcanza.';
    }
    return 'Se alcanza en $semanas ${semanas == 1 ? 'semana' : 'semanas'} '
        'con tu apartado.';
  }

  @override
  Widget build(BuildContext context) => Padding(
    key: ValueKey('objetivo-${objetivo.id}'),
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                objetivo.nombre,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            if (alEditar != null)
              IconButton(
                key: ValueKey('objetivo-editar-${objetivo.id}'),
                tooltip: 'Editar',
                onPressed: alEditar,
                icon: const Icon(Icons.edit_outlined),
              ),
          ],
        ),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [const Text('Meta '), Monto(objetivo.metaCentavos)],
            ),
            Text('para ${textoFecha(objetivo.fechaMeta)}'),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Falta '),
                Monto(avance.falta, key: ValueKey('falta-${objetivo.id}')),
              ],
            ),
          ],
        ),
        Text(_texto, key: ValueKey('semanas-${objetivo.id}')),
        if (!avance.alcanzado && avance.llegaATiempo == false)
          Text(
            'Con este apartado no llega a la fecha.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    ),
  );
}

class _DialogoObjetivo extends ConsumerStatefulWidget {
  const _DialogoObjetivo({
    required this.contexto,
    required this.bolsas,
    this.objetivo,
  });

  final ContextoFinanzas contexto;
  final List<ResumenBolsa> bolsas;
  final Objetivo? objetivo;

  @override
  ConsumerState<_DialogoObjetivo> createState() => _DialogoObjetivoState();
}

class _DialogoObjetivoState extends ConsumerState<_DialogoObjetivo> {
  final _forma = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.objetivo?.nombre);
  late final _meta = TextEditingController(
    text: widget.objetivo == null
        ? ''
        : textoDeCentavos(widget.objetivo!.metaCentavos),
  );
  late Fecha _fecha =
      widget.objetivo?.fechaMeta ?? widget.contexto.hoy.sumarDias(365);
  late String? _bolsa = widget.objetivo?.bolsaId;

  @override
  void dispose() {
    _nombre.dispose();
    _meta.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Formulario(
    titulo: widget.objetivo == null ? 'Nuevo objetivo' : 'Editar objetivo',
    forma: _forma,
    campos: [
      TextFormField(
        key: const ValueKey('objetivo-nombre'),
        controller: _nombre,
        decoration: const InputDecoration(labelText: 'Nombre'),
        validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe un nombre' : null,
      ),
      CampoMonto(controlador: _meta, etiqueta: 'Meta'),
      _BotonFecha(
        etiqueta: 'Fecha meta',
        valor: _fecha,
        alCambiar: (f) => setState(() => _fecha = f),
      ),
      DropdownButtonFormField<String?>(
        isExpanded: true,
        key: const ValueKey('objetivo-bolsa'),
        initialValue: _bolsa,
        decoration: const InputDecoration(
          labelText: 'Bolsa de ahorro de la que lee su avance',
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('Ninguna')),
          for (final b in widget.bolsas)
            DropdownMenuItem(value: b.bolsa.id, child: Text(b.bolsa.nombre)),
        ],
        onChanged: (b) => setState(() => _bolsa = b),
      ),
    ],
    alGuardar: () async {
      final c = widget.contexto;
      await ref
          .read(repositorioPatrimonioProvider)
          .guardarObjetivo(
            Objetivo(
              id: widget.objetivo?.id ?? const Uuid().v4(),
              libroId: c.libroId,
              nombre: _nombre.text.trim(),
              metaCentavos: centavosDeTexto(_meta.text)!,
              fechaMeta: _fecha,
              bolsaId: _bolsa,
            ),
          );
      _guardado(ref, c.libroId);
    },
  );
}

// ----------------------------------------------------------------- inversiones

class _Inversiones extends ConsumerWidget {
  const _Inversiones({
    required this.contexto,
    required this.inversiones,
    required this.permiso,
  });

  final ContextoFinanzas contexto;
  final List<Inversion> inversiones;
  final PermisoPatrimonio permiso;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = contexto;
    final lector = ref.watch(lectorEstadoInversionProvider);
    return TarjetaModulo(
      key: const ValueKey('patrimonio-inversiones'),
      titulo: 'Inversiones',
      icono: Icons.trending_up,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (inversiones.isEmpty)
            const Text('Aún no tienes inversiones.')
          else
            for (final i in inversiones)
              Padding(
                key: ValueKey('inversion-${i.id}'),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            i.institucion == null
                                ? i.nombre
                                : '${i.nombre} · ${i.institucion}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        Chip(
                          key: ValueKey('origen-${i.id}'),
                          label: Text(i.etiquetaOrigen),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 16,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Saldo '),
                            Monto(i.saldoCentavos),
                          ],
                        ),
                        Text(
                          i.rendimientoTexto == null
                              ? 'Rendimiento: sin capturar'
                              : 'Rendimiento capturado: ${i.rendimientoTexto}',
                          key: ValueKey('rendimiento-${i.id}'),
                        ),
                        Text('al ${textoFecha(i.fechaCaptura)}'),
                      ],
                    ),
                  ],
                ),
              ),
          if (permiso.editar)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('inversion-nueva'),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => _DialogoInversion(contexto: c),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Capturar inversión'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('inversion-pdf'),
                  onPressed: () async {
                    if (!lector.disponible) {
                      avisar(
                        context,
                        'La lectura de estados en PDF aún no está disponible '
                        'en este equipo. Puedes capturarla a mano.',
                      );
                      return;
                    }
                    final estado = await lector.leer();
                    if (estado == null) return;
                    await ref
                        .read(repositorioPatrimonioProvider)
                        .guardarInversion(
                          inversionLeidaDeEstado(
                            id: const Uuid().v4(),
                            libroId: c.libroId,
                            estado: estado,
                          ),
                        );
                    _guardado(ref, c.libroId);
                  },
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Leer estado en PDF'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DialogoInversion extends ConsumerStatefulWidget {
  const _DialogoInversion({required this.contexto});

  final ContextoFinanzas contexto;

  @override
  ConsumerState<_DialogoInversion> createState() => _DialogoInversionState();
}

class _DialogoInversionState extends ConsumerState<_DialogoInversion> {
  final _forma = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _institucion = TextEditingController();
  final _saldo = TextEditingController();
  final _rendimiento = TextEditingController();
  late Fecha _fecha = widget.contexto.hoy;

  @override
  void dispose() {
    for (final c in [_nombre, _institucion, _saldo, _rendimiento]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Formulario(
    titulo: 'Capturar inversión',
    forma: _forma,
    campos: [
      TextFormField(
        key: const ValueKey('inversion-nombre'),
        controller: _nombre,
        maxLength: 60,
        decoration: const InputDecoration(labelText: 'Nombre'),
        validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe un nombre' : null,
      ),
      TextFormField(
        controller: _institucion,
        decoration: const InputDecoration(labelText: 'Institución (opcional)'),
      ),
      CampoMonto(controlador: _saldo, etiqueta: 'Saldo'),
      TextFormField(
        key: const ValueKey('inversion-rendimiento'),
        controller: _rendimiento,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Rendimiento anual capturado (opcional)',
          suffixText: '%',
          helperText: 'Se muestra tal cual lo escribes; no se calcula.',
        ),
        validator: (v) =>
            (v ?? '').trim().isEmpty || puntosBaseDeTexto(v!) != null
            ? null
            : 'Porcentaje no válido',
      ),
      _BotonFecha(
        etiqueta: 'Fecha de captura',
        valor: _fecha,
        alCambiar: (f) => setState(() => _fecha = f),
      ),
    ],
    alGuardar: () async {
      final c = widget.contexto;
      await ref
          .read(repositorioPatrimonioProvider)
          .guardarInversion(
            inversionCapturada(
              id: const Uuid().v4(),
              libroId: c.libroId,
              nombre: _nombre.text,
              institucion: _institucion.text,
              saldoCentavos: centavosDeTexto(_saldo.text)!,
              rendimientoPuntosBase: _rendimiento.text.trim().isEmpty
                  ? null
                  : puntosBaseDeTexto(_rendimiento.text),
              fechaCaptura: _fecha,
            ),
          );
      _guardado(ref, c.libroId);
    },
  );
}

// ------------------------------------------------------- bienes y previsión

class _BienesYPrevision extends ConsumerWidget {
  const _BienesYPrevision({
    required this.contexto,
    required this.datos,
    required this.permiso,
  });

  final ContextoFinanzas contexto;
  final DatosPatrimonio datos;
  final PermisoPatrimonio permiso;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = contexto;
    Widget fila(
      String id,
      String etiqueta,
      String nombre,
      int valor,
      Fecha? fecha,
    ) => Padding(
      key: ValueKey('valor-$id'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('$etiqueta · $nombre'),
          Monto(valor),
          Text(
            fecha == null
                ? 'Sin fecha de captura: no es vigente'
                : 'Capturado el ${textoFecha(fecha)}',
            key: ValueKey('captura-$id'),
          ),
        ],
      ),
    );

    return TarjetaModulo(
      key: const ValueKey('patrimonio-bienes'),
      titulo: 'Bienes y previsión',
      icono: Icons.home_work_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (datos.bienes.isEmpty && datos.previsiones.isEmpty)
            const Text('Aún no capturas bienes ni previsión.'),
          for (final b in datos.bienes)
            fila(
              b.id,
              b.tipo.etiqueta,
              b.nombre,
              b.valorCentavos,
              b.fechaCaptura,
            ),
          for (final p in datos.previsiones)
            fila(
              p.id,
              p.tipo.etiqueta,
              p.nombre,
              p.valorCentavos,
              p.fechaCaptura,
            ),
          if (permiso.editar)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('bien-nuevo'),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) =>
                        _DialogoValor(contexto: c, esPrevision: false),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Capturar bien'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('prevision-nueva'),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) =>
                        _DialogoValor(contexto: c, esPrevision: true),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Capturar previsión'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DialogoValor extends ConsumerStatefulWidget {
  const _DialogoValor({required this.contexto, required this.esPrevision});

  final ContextoFinanzas contexto;
  final bool esPrevision;

  @override
  ConsumerState<_DialogoValor> createState() => _DialogoValorState();
}

class _DialogoValorState extends ConsumerState<_DialogoValor> {
  final _forma = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _valor = TextEditingController();
  late Fecha _fecha = widget.contexto.hoy;
  TipoBien _tipoBien = TipoBien.auto;
  TipoPrevision _tipoPrevision = TipoPrevision.seguro;

  @override
  void dispose() {
    _nombre.dispose();
    _valor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Formulario(
    titulo: widget.esPrevision ? 'Capturar previsión' : 'Capturar bien',
    forma: _forma,
    campos: [
      if (widget.esPrevision)
        DropdownButtonFormField<TipoPrevision>(
          isExpanded: true,
          initialValue: _tipoPrevision,
          decoration: const InputDecoration(labelText: 'Tipo'),
          items: [
            for (final t in TipoPrevision.values)
              DropdownMenuItem(value: t, child: Text(t.etiqueta)),
          ],
          onChanged: (t) => setState(() => _tipoPrevision = t!),
        )
      else
        DropdownButtonFormField<TipoBien>(
          isExpanded: true,
          initialValue: _tipoBien,
          decoration: const InputDecoration(labelText: 'Tipo'),
          items: [
            for (final t in TipoBien.values)
              DropdownMenuItem(value: t, child: Text(t.etiqueta)),
          ],
          onChanged: (t) => setState(() => _tipoBien = t!),
        ),
      TextFormField(
        key: const ValueKey('valor-nombre'),
        controller: _nombre,
        maxLength: 60,
        decoration: const InputDecoration(labelText: 'Nombre'),
        validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe un nombre' : null,
      ),
      CampoMonto(controlador: _valor, etiqueta: 'Valor'),
      _BotonFecha(
        etiqueta: 'Fecha de captura',
        valor: _fecha,
        alCambiar: (f) => setState(() => _fecha = f),
      ),
    ],
    alGuardar: () async {
      final c = widget.contexto;
      final repo = ref.read(repositorioPatrimonioProvider);
      final id = const Uuid().v4();
      final valor = centavosDeTexto(_valor.text)!;
      if (widget.esPrevision) {
        await repo.guardarPrevision(
          Prevision(
            id: id,
            libroId: c.libroId,
            tipo: _tipoPrevision,
            nombre: _nombre.text.trim(),
            valorCentavos: valor,
            fechaCaptura: _fecha,
          ),
        );
      } else {
        await repo.guardarBien(
          Bien(
            id: id,
            libroId: c.libroId,
            tipo: _tipoBien,
            nombre: _nombre.text.trim(),
            valorCentavos: valor,
            fechaCaptura: _fecha,
          ),
        );
      }
      _guardado(ref, c.libroId);
    },
  );
}

// ------------------------------------------------------------------- comunes

class _BotonFecha extends StatelessWidget {
  const _BotonFecha({
    required this.etiqueta,
    required this.valor,
    required this.alCambiar,
  });

  final String etiqueta;
  final Fecha valor;
  final ValueChanged<Fecha> alCambiar;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: () async {
      final f = await elegirFecha(context, valor);
      if (f != null) alCambiar(f);
    },
    child: Text('$etiqueta: ${textoFecha(valor)}'),
  );
}

/// Formulario en diálogo: valida, guarda y avisa del error sin cerrarse.
class _Formulario extends StatefulWidget {
  const _Formulario({
    required this.titulo,
    required this.forma,
    required this.campos,
    required this.alGuardar,
  });

  final String titulo;
  final GlobalKey<FormState> forma;
  final List<Widget> campos;
  final Future<void> Function() alGuardar;

  @override
  State<_Formulario> createState() => _FormularioState();
}

class _FormularioState extends State<_Formulario> {
  bool _guardando = false;

  Future<void> _guardar() async {
    if (!(widget.forma.currentState?.validate() ?? false)) return;
    final navegador = Navigator.of(context);
    setState(() => _guardando = true);
    try {
      await widget.alGuardar();
      navegador.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      avisarError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.titulo),
    content: SizedBox(
      width: 420,
      child: Form(
        key: widget.forma,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final c in widget.campos)
                Padding(padding: const EdgeInsets.only(bottom: 8), child: c),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _guardando ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const ValueKey('patrimonio-guardar'),
        onPressed: _guardando ? null : _guardar,
        child: const Text('Guardar'),
      ),
    ],
  );
}
