/// Hoja «Repartir ingreso» (teléfono y laptop; `docs/specs/fase-8-finanzas-
/// dispersion.md`): muestra cómo se reparte un ingreso **antes** de aplicarlo
/// (presupuesto de la semana, pagos de deuda y remanente) y deja **Aceptar**,
/// **Editar** o **Dejar para después**.
///
/// La propuesta la calcula el dominio (`proponerDispersion`); la hoja no
/// repite reglas. **La app propone y la persona confirma**: Aceptar solo crea
/// movimientos para el abono extra y el ahorro. Sin permiso de escribir (cuenta
/// maestra, lector, libro archivado) la hoja es de solo lectura.
///
/// **Cambiar reparto (P5, 20/nov/2026):** en un ingreso ya repartido la hoja se
/// abre con el reparto vigente **editable** y el botón «Guardar cambios» (con
/// motivo si el libro es de Papá). El servidor anula con contraasiento lo que
/// creó el reparto anterior y crea lo nuevo en una transacción, con control de
/// versión: si otro dispositivo ya lo cambió, la hoja recarga y avisa.
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide
        Semaforo,
        formatearCentavos,
        TipoLibro,
        VisibilidadLibro,
        puntosBaseEnCien;
import 'package:finanzas_dominio/finanzas_dominio.dart' as dom show TipoLibro;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../diseno/diseno.dart';
import '../../datos/ids.dart' show ClavesId, idEstable;
import '../../datos/repositorio.dart' show ErrorFinanzas;
import '../../estado/proveedores.dart';
import '../../estado/proveedores_dispersion.dart';
import '../comunes.dart';
import '../fila_texto_monto.dart';
import 'hoja_gasto.dart' show librosParaRegistrar;
import 'marco_hoja.dart';

/// Abre la hoja del ingreso [movimientoId] del libro [libroId].
Future<void> mostrarHojaRepartir(
  BuildContext context, {
  required String libroId,
  required String movimientoId,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) =>
      HojaRepartirIngreso(libroId: libroId, movimientoId: movimientoId),
);

class HojaRepartirIngreso extends ConsumerStatefulWidget {
  const HojaRepartirIngreso({
    super.key,
    required this.libroId,
    required this.movimientoId,
  });

  final String libroId;
  final String movimientoId;

  @override
  ConsumerState<HojaRepartirIngreso> createState() => _HojaRepartirState();
}

class _HojaRepartirState extends ConsumerState<HojaRepartirIngreso> {
  PropuestaDispersion? _propuesta;

  /// La hoja arrancó en modo «cambiar» (el ingreso tenía un reparto aplicado).
  bool? _arrancoCambiando;

  /// Id y versión del reparto vigente con el que se armó la hoja: si cambian
  /// mientras está abierta (otro dispositivo lo cambió), se vuelve a armar.
  String? _llaveVigente;

  /// Se volvió a armar la hoja porque el reparto cambió en otro dispositivo.
  bool _recargada = false;
  bool _editada = false;
  bool _editando = false;
  bool _guardando = false;
  String? _cuentaAhorroId;
  String? _error;
  final _motivo = TextEditingController();
  final _campos = <int, TextEditingController>{};

  @override
  void dispose() {
    _motivo.dispose();
    for (final c in _campos.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _campo(int i, int centavos) => _campos.putIfAbsent(
    i,
    () => TextEditingController(text: textoDeCentavos(centavos)),
  );

  void _cambiar(int i, String texto) {
    final centavos = centavosDeTexto(texto);
    setState(() {
      if (centavos == null) {
        _error = 'Escribe un monto válido.';
        return;
      }
      try {
        _propuesta = _propuesta!.editar(i, centavos);
        _editada = true;
        _error = null;
      } on ErrorDispersion catch (e) {
        _error = e.mensaje;
      }
    });
  }

  Future<void> _aceptar(IngresoPorRepartir ingreso, bool representado) async {
    setState(() => _guardando = true);
    final navegador = Navigator.of(context);
    final servicio = ref.read(servicioDispersionProvider);
    try {
      final d = await servicio.aceptar(
        ingreso: ingreso,
        propuesta: _propuesta!,
        cuentaAhorroId: _propuesta!.ahorro > 0 ? _cuentaAhorroId : null,
        motivo: representado ? _motivo.text : null,
      );
      if (mounted) {
        final mensajero = ScaffoldMessenger.of(context);
        mostrarAvisoDeshacer(
          context,
          mensaje: 'Listo: repartí tu ingreso',
          alDeshacer: () async {
            try {
              await servicio.deshacer(d.id);
              mensajero.showSnackBar(
                const SnackBar(
                  content: Text(
                    'Se deshizo: el ingreso vuelve a por repartir.',
                  ),
                ),
              );
            } catch (e) {
              mensajero.showSnackBar(SnackBar(content: Text('$e')));
            }
          },
        );
      }
      if (navegador.canPop()) navegador.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        avisarError(context, e);
      }
    }
  }

  /// Vuelve a armar la propuesta desde lo que hay ahora (tras un rechazo por
  /// versión o si el ingreso cambió de estado mientras la hoja estaba abierta).
  void _reiniciar() {
    for (final c in _campos.values) {
      c.dispose();
    }
    _campos.clear();
    _propuesta = null;
    _arrancoCambiando = null;
    _llaveVigente = null;
    _editada = false;
    _error = null;
    _cuentaAhorroId = null;
  }

  Future<void> _guardarCambios(
    IngresoPorRepartir ingreso,
    bool representado,
  ) async {
    setState(() => _guardando = true);
    final navegador = Navigator.of(context);
    try {
      await ref
          .read(servicioDispersionProvider)
          .cambiarReparto(
            ingreso: ingreso,
            propuesta: _propuesta!,
            cuentaAhorroId: _propuesta!.ahorro > 0 ? _cuentaAhorroId : null,
            motivo: representado ? _motivo.text : null,
          );
      if (mounted) avisar(context, 'Listo: cambié tu reparto.');
      if (navegador.canPop()) navegador.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        // Otro dispositivo lo cambió: el repositorio ya recargó; se vuelve a
        // armar la hoja con el reparto que quedó.
        if (e is ErrorFinanzas && e.repartoCambio) {
          _reiniciar();
          _recargada = true;
        }
      });
      avisarError(context, e);
    }
  }

  Future<void> _despues(IngresoPorRepartir ingreso) async {
    setState(() => _guardando = true);
    final navegador = Navigator.of(context);
    try {
      await ref
          .read(servicioDispersionProvider)
          .dejarParaDespues(
            ingreso: ingreso,
            propuestaEditada: _editada ? _propuesta : null,
          );
      if (mounted) avisar(context, 'Quedó por repartir.');
      if (navegador.canPop()) navegador.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        avisarError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(contextoFinanzasProvider).value;
    final ingresos = ref.watch(ingresosDeLibroProvider(widget.libroId));
    final ingreso = ingresos
        .where((i) => i.movimientoId == widget.movimientoId)
        .firstOrNull;
    if (c == null) {
      return const MarcoHojaRegistro(
        titulo: 'Repartir ingreso',
        cuerpo: Center(child: CircularProgressIndicator()),
      );
    }
    if (ingreso == null) {
      return const MarcoHojaRegistro(
        titulo: 'Repartir ingreso',
        cuerpo: Text(
          'Este ingreso ya no está en el libro.',
          key: ValueKey('repartir-nada'),
        ),
      );
    }
    // Un ingreso con reparto aplicado se abre para cambiarlo (P5).
    final cambiando = ingreso.estado.aplicada;
    final vigente = cambiando
        ? ref
              .read(servicioDispersionProvider)
              .repartoAplicadoDe(ingreso.movimientoId)
        : null;
    final llave = vigente == null ? null : '${vigente.id}:${vigente.version}';
    if (_propuesta != null &&
        (_arrancoCambiando != cambiando ||
            (_llaveVigente != null && llave != _llaveVigente))) {
      // El ingreso cambió de estado o alguien cambió el reparto mientras la
      // hoja estaba abierta: se arma de nuevo con lo que quedó.
      _recargada = _arrancoCambiando == true;
      _reiniciar();
    }
    final libro = c.datos.libro(widget.libroId)!;
    final puede = librosParaRegistrar(c).any((l) => l.id == libro.id);
    final representado = libro.tipo == dom.TipoLibro.representado;
    final ahorros = [
      for (final x in c.datos.cuentasDe(libro.id))
        if (x.tipo == TipoCuenta.ahorro && x.estado == EstadoCuenta.activa) x,
    ];
    if (_propuesta == null) {
      _propuesta = _inicial(ingreso, ahorros, cambiando);
      _arrancoCambiando = cambiando;
      _llaveVigente = llave;
      // Cambiar: los renglones se editan desde el principio, salvo con los
      // montos ocultos (modo privado): los campos mostrarían las cifras, así
      // que se editan solo cuando la persona toca «Editar».
      _editando = cambiando && !ref.read(montosOcultosProvider);
    }
    final p = _propuesta!;
    if (_cuentaAhorroId == null && ahorros.length == 1) {
      _cuentaAhorroId = ahorros.first.id;
    }
    if (_cuentaAhorroId == null && vigente != null) {
      _cuentaAhorroId = _cuentaDelAhorroVigente(c.datos, vigente);
    }
    final datosCompletos =
        puede &&
        !_guardando &&
        _error == null &&
        (p.ahorro == 0 || _cuentaAhorroId != null) &&
        (!representado || motivoValido(_motivo.text));
    final aceptable = datosCompletos && ingreso.estado.pendiente;
    // «Guardar cambios» solo cuando hay algo distinto que guardar.
    final hayCambios =
        vigente != null &&
        p.quedaPorRepartir >= 0 &&
        armarCambioDeReparto(vigente: vigente, editada: p).hayCambios;
    final guardable = datosCompletos && cambiando && hayCambios;
    final tema = Theme.of(context);

    Widget fila(int i) {
      final l = p.lineas[i];
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: _editando && puede
            ? Row(
                children: [
                  Expanded(child: Text(l.etiqueta)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 128,
                    child: TextField(
                      key: ValueKey('repartir-linea-$i'),
                      controller: _campo(i, l.monto),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textAlign: TextAlign.end,
                      decoration: const InputDecoration(
                        isDense: true,
                        prefixText: r'$ ',
                      ),
                      onChanged: (t) => _cambiar(i, t),
                    ),
                  ),
                ],
              )
            : FilaTextoMonto(
                texto: l.etiqueta,
                monto: Monto(l.monto, key: ValueKey('repartir-monto-$i')),
              ),
      );
    }

    List<int> de(Iterable<DestinoLinea> destinos) => [
      for (var i = 0; i < p.lineas.length; i++)
        if (destinos.contains(p.lineas[i].destino)) i,
    ];

    Widget titulo(String texto, int total, Key llave) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: FilaTextoMonto(
        texto: texto,
        estilo: tema.textTheme.titleSmall,
        monto: Monto(total, key: llave, estilo: tema.textTheme.titleSmall),
      ),
    );

    final iPresupuesto = de([DestinoLinea.presupuesto]);
    final iDeuda = de([DestinoLinea.pagoDeuda]);
    final iRemanente = de([
      DestinoLinea.abonoExtra,
      DestinoLinea.ahorro,
      DestinoLinea.libre,
    ]);

    return MarcoHojaRegistro(
      titulo: 'Repartir ingreso',
      tituloDerecha: Monto(
        ingreso.monto,
        key: const ValueKey('repartir-monto'),
        estilo: tema.textTheme.headlineSmall,
      ),
      barra: _Barra(
        guardando: _guardando,
        puede: puede,
        editando: _editando,
        cambiando: cambiando,
        alAceptar: aceptable ? () => _aceptar(ingreso, representado) : null,
        alGuardar: guardable
            ? () => _guardarCambios(ingreso, representado)
            : null,
        alEditar: () => setState(() => _editando = !_editando),
        alDespues: _guardando ? null : () => _despues(ingreso),
      ),
      cuerpo: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${ingreso.nombre} · ${textoFecha(ingreso.fecha)}',
            key: const ValueKey('repartir-origen'),
          ),
          Text(
            ingreso.estado == EstadoDispersion.propuesta
                ? 'Propuesta guardada, sin confirmar'
                : cambiando
                ? 'Reparto confirmado'
                : 'Por repartir',
            key: const ValueKey('repartir-estado'),
            style: tema.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Text(
            cambiando
                ? (puede
                      ? 'Así quedó tu reparto. Cámbialo y guarda:'
                      : 'Así quedó el reparto (solo lectura):')
                : puede
                ? 'Esto es lo que propongo:'
                : 'Así se repartiría (solo lectura):',
            key: const ValueKey('repartir-intro'),
          ),
          if (_recargada && cambiando)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'El reparto cambió en otro dispositivo: te muestro cómo quedó.',
                key: const ValueKey('repartir-recargado'),
                style: tema.textTheme.bodySmall,
              ),
            ),
          if (cambiando && puede)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Los movimientos del reparto anterior se anulan con '
                'contraasiento y se crean los nuevos. El historial se queda.',
                key: const ValueKey('repartir-aviso-cambio'),
                style: tema.textTheme.bodySmall,
              ),
            ),
          if (!p.cubreTodo) ...[
            const SizedBox(height: 8),
            Wrap(
              key: const ValueKey('repartir-faltante'),
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: tema.colorScheme.error,
                ),
                const SizedBox(width: 6),
                const Text('Este ingreso no alcanza para todo: faltan '),
                Monto(p.faltante),
                const Text('. Lo protegido no se recorta.'),
              ],
            ),
          ],
          if (iPresupuesto.isNotEmpty)
            ExpansionTile(
              key: ValueKey('repartir-presupuesto-$_editando'),
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: _editando,
              title: FilaTextoMonto(
                texto: 'Presupuesto de la semana',
                monto: Monto(
                  p.totalPresupuesto,
                  key: const ValueKey('repartir-total-presupuesto'),
                ),
              ),
              children: [for (final i in iPresupuesto) fila(i)],
            ),
          if (iDeuda.isNotEmpty) ...[
            titulo(
              'Pagos de deuda (apartados)',
              p.totalPagosDeuda,
              const ValueKey('repartir-total-deuda'),
            ),
            for (final i in iDeuda) fila(i),
          ],
          if (iRemanente.isNotEmpty) ...[
            titulo(
              'Remanente',
              p.remanente,
              const ValueKey('repartir-total-remanente'),
            ),
            for (final i in iRemanente) fila(i),
          ],
          if (p.ahorro > 0 && ahorros.length != 1) ...[
            const SizedBox(height: 8),
            const EtiquetaPanel('Ahorro a'),
            Wrap(
              spacing: 8,
              children: [
                for (final x in ahorros)
                  ChoiceChip(
                    key: ValueKey('repartir-ahorro-${x.id}'),
                    label: Text(x.nombre),
                    selected: _cuentaAhorroId == x.id,
                    onSelected: puede
                        ? (_) => setState(() => _cuentaAhorroId = x.id)
                        : null,
                  ),
              ],
            ),
          ],
          if (ahorros.isEmpty && _sinCuentaDeAhorro)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No hay cuenta de ahorro: ese dinero queda por repartir.',
                key: const ValueKey('repartir-sin-ahorro'),
                style: tema.textTheme.bodySmall,
              ),
            ),
          const Divider(),
          FilaTextoMonto(
            texto: 'Queda por repartir',
            monto: Monto(
              p.quedaPorRepartir,
              key: const ValueKey('repartir-queda'),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                key: const ValueKey('repartir-error'),
                style: TextStyle(color: tema.colorScheme.error),
              ),
            ),
          if (representado && puede)
            TextField(
              key: const ValueKey('repartir-motivo'),
              controller: _motivo,
              maxLength: 200,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Motivo (obligatorio)',
                helperText:
                    '$ayudaDelMotivo Se registra en nombre de ${libro.nombre}.',
                helperMaxLines: 3,
                errorText: errorDeMotivo(_motivo.text),
                errorMaxLines: 3,
              ),
            ),
        ],
      ),
    );
  }

  bool _sinCuentaDeAhorro = false;

  /// La propuesta de partida. Si no hay cuenta de ahorro, el ahorro queda
  /// por repartir (la hoja lo dice) en lugar de proponer algo imposible.
  PropuestaDispersion _inicial(
    IngresoPorRepartir ingreso,
    List<Cuenta> ahorros,
    bool cambiando,
  ) {
    final servicio = ref.read(servicioDispersionProvider);
    // Cambiar: los montos del reparto vigente, sin tocar (aunque no haya
    // cuenta de ahorro hoy: es lo que ya se hizo).
    if (cambiando) return servicio.propuestaParaCambiarReparto(ingreso);
    var p = servicio.proponer(ingreso);
    if (ahorros.isEmpty && p.ahorro > 0) {
      final i = p.lineas.indexWhere((l) => l.destino == DestinoLinea.ahorro);
      p = p.editar(i, 0);
      _sinCuentaDeAhorro = true;
    }
    return p;
  }
}

/// La cuenta que recibió el ahorro del reparto vigente (si lo hubo), para que
/// el cambio no pida elegirla otra vez.
String? _cuentaDelAhorroVigente(DatosFinanzas datos, Dispersion vigente) {
  final tieneAhorro = vigente.lineas.any(
    (l) => l.destino == DestinoLinea.ahorro && l.monto > 0,
  );
  if (!tieneAhorro) return null;
  final id = idEstable(ClavesId.dispersionMovimiento(vigente.id, 'ahorro'));
  return datos.movimientos
      .where((m) => m.id == id)
      .map((m) => m.cuentaDestinoId)
      .firstOrNull;
}

class _Barra extends StatelessWidget {
  const _Barra({
    required this.guardando,
    required this.puede,
    required this.editando,
    required this.cambiando,
    required this.alAceptar,
    required this.alGuardar,
    required this.alEditar,
    required this.alDespues,
  });

  final bool guardando;
  final bool puede;
  final bool editando;

  /// La hoja cambia un reparto ya confirmado (P5).
  final bool cambiando;
  final VoidCallback? alAceptar;
  final VoidCallback? alGuardar;
  final VoidCallback alEditar;
  final VoidCallback? alDespues;

  @override
  Widget build(BuildContext context) {
    if (!puede) {
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: TextButton(
          key: const ValueKey('repartir-cerrar'),
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Cerrar'),
        ),
      );
    }
    // Un Wrap que crece hacia arriba: con letra grande los botones se apilan
    // y nunca se cortan (mismo criterio que BarraAccionesRegistro).
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.end,
        runAlignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        verticalDirection: VerticalDirection.up,
        spacing: 8,
        runSpacing: 4,
        children: [
          if (cambiando) ...[
            TextButton(
              key: const ValueKey('repartir-cancelar'),
              onPressed: guardando
                  ? null
                  : () => Navigator.of(context).maybePop(),
              child: const Text('Cancelar'),
            ),
            OutlinedButton(
              key: const ValueKey('repartir-editar'),
              onPressed: guardando ? null : alEditar,
              child: Text(editando ? 'Listo' : 'Editar'),
            ),
            FilledButton.icon(
              key: const ValueKey('repartir-guardar-cambios'),
              onPressed: alGuardar,
              icon: const Icon(Icons.check),
              label: const Text('Guardar cambios'),
            ),
          ] else ...[
            TextButton(
              key: const ValueKey('repartir-despues'),
              onPressed: alDespues,
              child: const Text('Dejar para después'),
            ),
            OutlinedButton(
              key: const ValueKey('repartir-editar'),
              onPressed: guardando ? null : alEditar,
              child: Text(editando ? 'Listo' : 'Editar'),
            ),
            FilledButton.icon(
              key: const ValueKey('repartir-aceptar'),
              onPressed: alAceptar,
              icon: const Icon(Icons.check),
              label: const Text('Aceptar'),
            ),
          ],
        ],
      ),
    );
  }
}
