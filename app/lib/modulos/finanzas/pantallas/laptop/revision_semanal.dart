/// Revisión semanal (F5, "el ritual de 3 minutos", 5.9 bis punto 4):
/// conciliar el efectivo → ingresos de la semana → desvíos → propuesta de la
/// semana siguiente → aplicar el remanente y cerrar. La app propone; la
/// persona confirma (no mueve dinero sola).
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide Semaforo, formatearCentavos, TipoLibro, puntosBaseEnCien;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../diseno/diseno.dart';
import '../../../../nucleo/contratos/roles.dart';
import '../../casos_uso/servicio_fase2.dart' show ServicioDeudasAhorro;
import '../../casos_uso/sugerencias.dart';
import '../../datos/repositorio.dart' show ErrorFinanzas;
import '../../estado/proveedores_fase2.dart' show servicioFase2Provider;
import '../../estado/proveedores.dart';
import '../comunes.dart';

Future<void> mostrarRevisionSemanal(
  BuildContext context,
  ContextoFinanzas c,
  Semana semana,
) => showDialog<void>(
  context: context,
  builder: (_) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760, maxHeight: 820),
      child: RevisionSemanal(libroId: c.libroId, semana: semana),
    ),
  ),
);

class RevisionSemanal extends ConsumerStatefulWidget {
  const RevisionSemanal({
    super.key,
    required this.libroId,
    required this.semana,
  });

  final String libroId;
  final Semana semana;

  @override
  ConsumerState<RevisionSemanal> createState() => _RevisionSemanalState();
}

class _RevisionSemanalState extends ConsumerState<RevisionSemanal> {
  int _paso = 0;
  bool _aplicar = true;
  String? _origen;
  String? _ahorro;
  bool _cerrando = false;

  /// Prioridad de las bolsas de ahorro que la persona arrastró (D25).
  List<String>? _orden;
  final _saldos = <String, TextEditingController>{};
  final _motivos = <String, TextEditingController>{};

  @override
  void dispose() {
    for (final c in [..._saldos.values, ..._motivos.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cerrar(ContextoFinanzas c, VistaSemana v) async {
    setState(() => _cerrando = true);
    final servicio = ref.read(servicioFinanzasProvider);
    final navegador = Navigator.of(context);
    final mensajero = ScaffoldMessenger.of(context);
    final fase2 = ref.read(servicioFase2Provider);
    final destino = v.real.destino;
    // Ahorro automático (Fase 4): extras → sobre → sobrante → redondeo. Sale
    // del ahorro que el motor ya propone, así que no se aparta dos veces.
    final auto = fase2.planAhorroDeCierre(
      widget.libroId,
      widget.semana,
      orden: _orden ?? const [],
    );
    final restoAhorro = destino.ahorro - auto.total;
    final destinoManual = DestinoRemanente(
      destino.abonosExtra,
      restoAhorro < 0 ? 0 : restoAhorro,
    );
    final aplicar =
        _aplicar &&
        _origen != null &&
        (destino.totalAbonoExtra > 0 || destino.ahorro > 0);
    try {
      final cierre = await servicio.cerrarSemana(
        widget.libroId,
        widget.semana,
        accion: aplicar
            ? AccionCierre.aplicarRemanente
            : AccionCierre.sinAplicar,
      );
      final motivo = c.permiso.enNombreDe ? 'Remanente de la semana' : null;
      if (aplicar) {
        await servicio.aplicarRemanente(
          libroId: widget.libroId,
          destino: destinoManual,
          cuentaOrigenId: _origen!,
          cuentaAhorroId: _ahorro,
          motivo: motivo,
          cierreId: cierre.id,
        );
        await fase2.aplicarAhorroAutomatico(
          libroId: widget.libroId,
          plan: auto,
          cuentaOrigenId: _origen!,
          cierreId: cierre.id,
          motivo: motivo,
        );
      }
      navegador.pop();
      final conAuto = aplicar && auto.aportes.isNotEmpty;
      mensajero.showSnackBar(
        SnackBar(
          content: const Text('Semana cerrada. Arranca la siguiente.'),
          action: conAuto
              ? SnackBarAction(
                  label: 'Deshacer ahorro',
                  onPressed: () => _deshacerAhorro(fase2, cierre.id, mensajero),
                )
              : null,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _cerrando = false);
        avisarError(context, e);
      }
    }
  }

  /// Anula con contraasiento el ahorro automático de ese cierre (nunca se
  /// borra). La semana queda cerrada; el dinero vuelve a la cuenta de origen.
  Future<void> _deshacerAhorro(
    ServicioDeudasAhorro fase2,
    String cierreId,
    ScaffoldMessengerState mensajero,
  ) async {
    try {
      final n = await fase2.deshacerAhorroAutomatico(
        libroId: widget.libroId,
        cierreId: cierreId,
      );
      mensajero.showSnackBar(
        SnackBar(
          content: Text(n == 0 ? 'Nada que deshacer.' : 'Ahorro deshecho.'),
        ),
      );
    } catch (e) {
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            e is ErrorFinanzas ? e.mensaje : 'No se pudo deshacer: $e',
          ),
        ),
      );
    }
  }

  Widget _conciliar(ContextoFinanzas c) {
    final efectivo = [
      for (final x in c.datos.cuentasDe(widget.libroId))
        if (x.tipo == TipoCuenta.efectivo && x.estado == EstadoCuenta.activa) x,
    ];
    if (efectivo.isEmpty) {
      return const Text('Este libro no tiene efectivo que conciliar.');
    }
    final libro = c.datos.vista(widget.libroId);
    return Column(
      children: [
        for (final cuenta in efectivo)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cuenta.nombre),
                      Row(
                        children: [
                          const Text('Según la app: '),
                          Monto(libro.saldo(cuenta.id, hasta: c.hoy)),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CampoMonto(
                    key: ValueKey('revision-saldo-${cuenta.id}'),
                    controlador: _saldos.putIfAbsent(
                      cuenta.id,
                      TextEditingController.new,
                    ),
                    etiqueta: 'Cuánto hay',
                    obligatorio: false,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _motivos.putIfAbsent(
                      cuenta.id,
                      TextEditingController.new,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Motivo si no cuadra',
                      helperText:
                          'Suele ser gasto sin capturar. $ayudaDelMotivo',
                      helperMaxLines: 3,
                      errorText: errorDeMotivo(_motivos[cuenta.id]?.text),
                      errorMaxLines: 3,
                    ),
                  ),
                ),
                IconButton(
                  key: ValueKey('revision-conciliar-${cuenta.id}'),
                  tooltip: 'Conciliar',
                  onPressed: () async {
                    final declarado = centavosDeTexto(_saldos[cuenta.id]!.text);
                    if (declarado == null) {
                      avisar(context, 'Escribe cuánto hay.');
                      return;
                    }
                    final ok = await intentar(
                      context,
                      () => ref
                          .read(servicioFinanzasProvider)
                          .conciliar(
                            cuentaId: cuenta.id,
                            saldoDeclarado: declarado,
                            fecha: c.hoy,
                            motivo: _motivos[cuenta.id]!.text,
                          ),
                    );
                    if (ok && mounted) avisar(context, 'Conciliado.');
                  },
                  icon: const Icon(Icons.check_circle_outline),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _ingresos(ContextoFinanzas c, VistaSemana v) {
    final entradas = [
      for (final x in v.vencimientos)
        if (x.esEntrada) x,
    ];
    if (entradas.isEmpty) {
      return const Text('No se esperaban ingresos esta semana.');
    }
    EstadoOcurrencia? estadoDe(Vencimiento x) => c.datos.ocurrencias
        .where(
          (o) =>
              o.libroId == widget.libroId &&
              o.origenId == x.origenId &&
              o.fechaProgramada == x.fecha.programada,
        )
        .firstOrNull
        ?.estado;
    return Column(
      children: [
        for (final x in entradas)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(x.concepto),
            subtitle: Text(textoFecha(x.fecha.ajustada)),
            trailing: SegmentedButton<EstadoOcurrencia>(
              showSelectedIcon: false,
              emptySelectionAllowed: true,
              segments: const [
                ButtonSegment(
                  value: EstadoOcurrencia.cumplida,
                  label: Text('Llegó'),
                ),
                ButtonSegment(
                  value: EstadoOcurrencia.retrasada,
                  label: Text('Se retrasó'),
                ),
                ButtonSegment(
                  value: EstadoOcurrencia.noLlegara,
                  label: Text('No llegará'),
                ),
              ],
              selected: {?estadoDe(x)},
              onSelectionChanged: c.puedeEscribir
                  ? (s) {
                      if (s.isEmpty) return;
                      intentar(
                        context,
                        () => ref
                            .read(servicioFinanzasProvider)
                            .marcarIngreso(widget.libroId, x, s.first),
                      );
                    }
                  : null,
            ),
          ),
        const Text(
          'Un ingreso que no llegó resta completo en la semana en que debía '
          'llegar.',
        ),
      ],
    );
  }

  Widget _desvios(VistaSemana v) {
    final lista = v.desvios();
    if (lista.isEmpty) {
      return const Text('Todas las partidas van según el plan.');
    }
    return Column(
      children: [
        for (final d in lista)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              d.diferencia > 0 ? Icons.trending_up : Icons.trending_down,
            ),
            title: Text(d.partida.nombre),
            subtitle: Text(d.diferencia > 0 ? 'Se pasó' : 'Sobró'),
            trailing: Monto(d.diferencia.abs()),
          ),
      ],
    );
  }

  Widget _siguiente(ContextoFinanzas c, VistaSemana v, bool ocultos) {
    final siguiente = armarPlanDelLibro(
      c.datos,
      widget.libroId,
      widget.semana.siguiente,
    );
    final p = siguiente.plan;
    final recortes = v.recortesSiguiente(siguiente);
    final orden = ordenDeAbonoExtra(p.abonos.map((r) => r.origen));
    final grupo = hayGrupoPrioritario(p.abonos.map((r) => r.origen));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GadgetCascada(
          montosOcultos: ocultos,
          escalones: [
            EscalonCascada(etiqueta: 'Ingreso', planeadoCentavos: p.ingreso),
            EscalonCascada(
              etiqueta: '− Presupuesto',
              planeadoCentavos: p.presupuesto,
            ),
            EscalonCascada(
              etiqueta: '− Deuda',
              planeadoCentavos: p.deudaPlaneada,
            ),
            EscalonCascada(
              etiqueta: '= Remanente',
              planeadoCentavos: p.remanente,
              tono: tonoDe(p.semaforoDelRemanente),
            ),
          ],
        ),
        if (v.real.arrastreSiguiente > 0)
          Row(
            children: [
              const Text('Arrastre que pasa a la semana siguiente: '),
              Monto(v.real.arrastreSiguiente),
            ],
          ),
        for (final l in siguiente.liberadas)
          Row(
            children: [
              Expanded(
                child: Text(
                  '${l.deuda.nombre} quedó pagada: su abono pasa '
                  '${grupo ? 'a la siguiente deuda del grupo prioritario' : 'al remanente'}:',
                ),
              ),
              Monto(l.abonoSemanal),
            ],
          ),
        if (orden.isNotEmpty)
          Text(
            grupo
                ? 'El remanente va al grupo prioritario, en este orden: '
                      '${orden.map((d) => d.nombre).join(' → ')}; cuando quede '
                      'pagado, a ahorro.'
                : 'El remanente va primero a la deuda de mayor costo: '
                      '${orden.map((d) => d.nombre).join(' → ')}.',
          ),
        if (recortes != null) ...[
          const SizedBox(height: 8),
          const Text(
            'El presupuesto pasa del techo. Recortes propuestos (lo protegido '
            'nunca se toca):',
          ),
          for (final r in recortes.recortes)
            Row(
              children: [
                Expanded(child: Text(r.partida.nombre)),
                Monto(r.monto),
              ],
            ),
          if (recortes.faltante > 0)
            Row(
              children: [
                const Expanded(
                  child: Text('Falta cubrir sin tocar lo protegido'),
                ),
                Monto(recortes.faltante),
              ],
            ),
        ],
      ],
    );
  }

  Widget _aplicarYCerrar(ContextoFinanzas c, VistaSemana v) {
    final destino = v.real.destino;
    final origenes = cuentasParaRecibir(
      c.datos,
      widget.libroId,
    ).where((x) => x.tipo.liquida).toList();
    final ahorros = [
      for (final x in c.datos.cuentasDe(widget.libroId))
        if (x.tipo == TipoCuenta.ahorro && x.estado == EstadoCuenta.activa) x,
    ];
    _origen ??= origenes.firstOrNull?.id;
    _ahorro ??= ahorros.firstOrNull?.id;
    final hayQueAplicar = destino.totalAbonoExtra > 0 || destino.ahorro > 0;
    final auto = ref
        .read(servicioFase2Provider)
        .planAhorroDeCierre(
          widget.libroId,
          widget.semana,
          orden: _orden ?? const [],
        );
    final conMetodos = [
      for (final b in c.datos.bolsasDe(widget.libroId))
        if (b.activa &&
            b.metodos.any(
              (m) => OrigenAporte.values.any((o) => o.metodo == m),
            ))
          b,
    ];
    if (_orden != null) {
      conMetodos.sort(
        (a, b) => _orden!.indexOf(a.id).compareTo(_orden!.indexOf(b.id)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: Text('Remanente real')),
            Monto(v.real.remanenteReal),
          ],
        ),
        for (final a in destino.abonosExtra)
          Row(
            children: [
              Expanded(child: Text('Abono extra a ${a.deuda.nombre}')),
              Monto(a.monto),
            ],
          ),
        if (destino.ahorro > 0)
          Row(
            children: [
              const Expanded(child: Text('A ahorro')),
              Monto(destino.ahorro),
            ],
          ),
        // Prioridad de las bolsas: se arrastran; el sobrante va a la primera.
        if (conMetodos.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Prioridad de tus bolsas: arrastra para ordenarlas. El '
                  'sobrante va a la primera.',
                ),
                ReorderableListView(
                  key: const ValueKey('revision-orden-bolsas'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  onReorderItem: (de, a) => setState(() {
                    final ids = [for (final b in conMetodos) b.id];
                    ids.insert(a, ids.removeAt(de));
                    _orden = ids;
                  }),
                  children: [
                    for (final b in conMetodos)
                      ListTile(
                        key: ValueKey('revision-orden-${b.id}'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.drag_handle),
                        title: Text(b.nombre),
                      ),
                  ],
                ),
              ],
            ),
          ),
        // Ahorro automático (extras → sobre → sobrante → redondeo): sale de
        // ese mismo ahorro, con su origen a la vista.
        for (final a in auto.aportes)
          Padding(
            key: ValueKey('revision-auto-${a.origen.clave}-${a.bolsaId}'),
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${a.origen.etiqueta} → '
                    '${c.datos.bolsas.where((b) => b.id == a.bolsaId).firstOrNull?.nombre ?? 'ahorro'}',
                  ),
                ),
                Monto(a.monto),
              ],
            ),
          ),
        if (v.real.abonoDiferido > 0)
          Row(
            children: [
              const Expanded(child: Text('Abono diferido (no baja el saldo)')),
              Monto(v.real.abonoDiferido),
            ],
          ),
        if (v.real.deficit > 0)
          Row(
            children: [
              const Expanded(child: Text('Déficit')),
              Monto(v.real.deficit),
            ],
          ),
        if (hayQueAplicar && c.puedeEscribir) ...[
          SwitchListTile(
            key: const ValueKey('revision-aplicar'),
            contentPadding: EdgeInsets.zero,
            value: _aplicar,
            onChanged: (x) => setState(() => _aplicar = x),
            title: const Text('Aplicar ahora (crea los movimientos)'),
          ),
          if (_aplicar)
            DropdownButtonFormField<String>(
              initialValue: _origen,
              decoration: const InputDecoration(labelText: 'Sale de'),
              items: [
                for (final x in origenes)
                  DropdownMenuItem(value: x.id, child: Text(x.nombre)),
              ],
              onChanged: (x) => setState(() => _origen = x),
            ),
          if (_aplicar && destino.ahorro - auto.total > 0)
            ahorros.isEmpty
                ? const Text(
                    'No hay cuenta de ahorro en este libro: créala en Cuentas '
                    'para aplicar el ahorro.',
                  )
                : DropdownButtonFormField<String>(
                    initialValue: _ahorro,
                    decoration: const InputDecoration(labelText: 'Ahorro en'),
                    items: [
                      for (final x in ahorros)
                        DropdownMenuItem(value: x.id, child: Text(x.nombre)),
                    ],
                    onChanged: (x) => setState(() => _ahorro = x),
                  ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(contextoFinanzasProvider).value;
    if (c == null) return const Center(child: CircularProgressIndicator());
    final v = vistaSemana(c.datos, widget.libroId, widget.semana, hoy: c.hoy);
    final ocultos = ref.watch(montosOcultosProvider);
    final pasos = [
      ('Conciliar el efectivo', _conciliar(c)),
      ('Ingresos de la semana', _ingresos(c, v)),
      ('Desvíos', _desvios(v)),
      ('Propuesta de la semana siguiente', _siguiente(c, v, ocultos)),
      ('Aplicar el remanente y cerrar', _aplicarYCerrar(c, v)),
    ];
    final ultimo = _paso == pasos.length - 1;
    return TemaModulo(
      modulo: Modulo.finanzas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Text(
              'Revisión semanal · ${textoSemana(widget.semana)}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: Stepper(
              key: const ValueKey('revision-pasos'),
              currentStep: _paso,
              onStepTapped: (i) => setState(() => _paso = i),
              controlsBuilder: (context, detalles) => Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    if (!ultimo)
                      FilledButton(
                        key: const ValueKey('revision-siguiente'),
                        onPressed: () => setState(() => _paso++),
                        child: const Text('Siguiente'),
                      )
                    else if (c.puedeEscribir)
                      FilledButton(
                        key: const ValueKey('revision-cerrar'),
                        onPressed: _cerrando ? null : () => _cerrar(c, v),
                        child: const Text('Cerrar semana'),
                      ),
                    const SizedBox(width: 8),
                    if (_paso > 0)
                      TextButton(
                        onPressed: () => setState(() => _paso--),
                        child: const Text('Atrás'),
                      ),
                  ],
                ),
              ),
              steps: [
                for (var i = 0; i < pasos.length; i++)
                  Step(
                    title: Text(pasos[i].$1),
                    content: pasos[i].$2,
                    isActive: i == _paso,
                    state: i < _paso ? StepState.complete : StepState.indexed,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Salir sin cerrar'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
