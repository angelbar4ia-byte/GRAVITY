/// Formularios de la Fase 2 (laptop): estado de cuenta, compra a meses (MSI),
/// tasa de una deuda, bolsa de ahorro, confirmar una aportación y retirar.
/// Todo lo captura la persona: la app no inventa montos, tasas ni fechas.
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
import 'package:finanzas_dominio/finanzas_dominio.dart' as dom show BolsaAhorro;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../nucleo/conectividad/conectividad.dart' show hayRedProvider;
import '../../casos_uso/servicio_fase2.dart';
import '../../datos/repositorio.dart' show ErrorFinanzas;
import '../../importacion/lector_ficha.dart';
import '../../importacion/lector_xlsx.dart' show ErrorArchivo;
import '../../estado/proveedores.dart';
import '../../estado/proveedores_fase2.dart';
import '../comunes.dart';
import '../laptop/importar.dart' show ArchivoElegido, selectorArchivoProvider;

/// Marco de los formularios de la Fase 2. Con [necesitaSenal] (estados de
/// cuenta, aportaciones y retiros de ahorro: el servidor liga el movimiento al
/// guardarlo, F4-3.7):
///
/// - al abrir sin señal avisa *"Sin señal: podrás revisar, pero no guardar"* y
///   deshabilita Guardar con la razón visible (no en silencio);
/// - si la señal se cae al guardar, **no guarda nada**, no cierra ni borra lo
///   escrito y dice en el mismo formulario qué pasó, con *Reintentar*.
class _Forma extends ConsumerStatefulWidget {
  const _Forma({
    required this.titulo,
    required this.forma,
    required this.campos,
    required this.alGuardar,
    this.textoGuardar = 'Guardar',
    this.necesitaSenal = false,
  });

  final String titulo;
  final GlobalKey<FormState> forma;
  final List<Widget> campos;
  final Future<void> Function() alGuardar;
  final String textoGuardar;
  final bool necesitaSenal;

  @override
  ConsumerState<_Forma> createState() => _FormaState();
}

class _FormaState extends ConsumerState<_Forma> {
  /// Mensaje de "necesita conexión" tras un intento fallido por falta de señal.
  String? _sinSenal;
  bool _guardando = false;

  Future<void> _guardar() async {
    if (!(widget.forma.currentState?.validate() ?? false)) return;
    final navegador = Navigator.of(context);
    setState(() {
      _guardando = true;
      _sinSenal = null;
    });
    try {
      await widget.alGuardar();
      navegador.pop();
      return;
    } on ErrorFinanzas catch (e) {
      if (!mounted) return;
      if (widget.necesitaSenal && e.sinConexion) {
        setState(() => _sinSenal = ErrorFinanzas.necesitaConexion.mensaje);
      } else {
        avisarError(context, e);
      }
    } catch (e) {
      if (mounted) avisarError(context, e);
    }
    if (mounted) setState(() => _guardando = false);
  }

  @override
  Widget build(BuildContext context) {
    final hayRed = ref.watch(hayRedProvider);
    final sinSenal = widget.necesitaSenal && !hayRed;
    final tema = Theme.of(context);
    return AlertDialog(
      title: Text(widget.titulo),
      content: SizedBox(
        width: 480,
        child: Form(
          key: widget.forma,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (sinSenal)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      key: const ValueKey('dialogo-sin-senal'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Sin señal: podrás revisar, pero no guardar.',
                            style: tema.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final c in widget.campos)
                  Padding(padding: const EdgeInsets.only(bottom: 8), child: c),
                if (_sinSenal != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      key: const ValueKey('dialogo-necesita-conexion'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.wifi_off_outlined,
                          size: 20,
                          color: tema.colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _sinSenal!,
                            style: tema.textTheme.bodyMedium?.copyWith(
                              color: tema.colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        if (_sinSenal != null)
          OutlinedButton(
            key: const ValueKey('dialogo-reintentar'),
            onPressed: _guardando ? null : _guardar,
            child: const Text('Reintentar'),
          ),
        FilledButton(
          key: const ValueKey('dialogo-guardar'),
          // Sin señal queda deshabilitado, y el aviso de arriba dice por qué.
          onPressed: _guardando || sinSenal ? null : _guardar,
          child: Text(widget.textoGuardar),
        ),
      ],
    );
  }
}

class _CampoFecha extends StatelessWidget {
  const _CampoFecha({
    super.key,
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

// ---------------------------------------------------------- estado de cuenta

class DialogoEstadoDeCuenta extends ConsumerStatefulWidget {
  const DialogoEstadoDeCuenta({super.key, required this.deuda});

  final Deuda deuda;

  @override
  ConsumerState<DialogoEstadoDeCuenta> createState() => _EstadoCuentaState();
}

class _EstadoCuentaState extends ConsumerState<DialogoEstadoDeCuenta> {
  final _forma = GlobalKey<FormState>();
  final _saldo = TextEditingController();
  final _minimo = TextEditingController();
  final _sinIntereses = TextEditingController();
  final _intereses = TextEditingController();
  final _tasa = TextEditingController();
  late Fecha _corte;
  late Fecha _limite;

  @override
  void initState() {
    super.initState();
    _corte = ref.read(hoyFinanzasProvider);
    _limite = _corte.sumarDias(20);
  }

  @override
  void dispose() {
    for (final c in [_saldo, _minimo, _sinIntereses, _intereses, _tasa]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Forma(
    titulo: 'Estado de cuenta · ${widget.deuda.titulo}',
    necesitaSenal: true,
    forma: _forma,
    campos: [
      _CampoFecha(
        key: const ValueKey('ec-corte'),
        etiqueta: 'Fecha de corte',
        valor: _corte,
        alCambiar: (f) => setState(() => _corte = f),
      ),
      _CampoFecha(
        key: const ValueKey('ec-limite'),
        etiqueta: 'Fecha límite de pago',
        valor: _limite,
        alCambiar: (f) => setState(() => _limite = f),
      ),
      KeyedSubtree(
        key: const ValueKey('ec-saldo'),
        child: CampoMonto(controlador: _saldo, etiqueta: 'Saldo al corte'),
      ),
      KeyedSubtree(
        key: const ValueKey('ec-minimo'),
        child: CampoMonto(controlador: _minimo, etiqueta: 'Pago mínimo'),
      ),
      KeyedSubtree(
        key: const ValueKey('ec-sin-intereses'),
        child: CampoMonto(
          controlador: _sinIntereses,
          etiqueta: 'Pago para no generar intereses',
        ),
      ),
      CampoMonto(
        controlador: _intereses,
        etiqueta: 'Intereses del periodo',
        obligatorio: false,
      ),
      CampoPorcentaje(
        controlador: _tasa,
        etiqueta: 'Tasa anual (si la dice el estado)',
      ),
    ],
    alGuardar: () async {
      await ref
          .read(servicioFase2Provider)
          .registrarEstadoDeCuenta(
            deudaId: widget.deuda.id,
            corte: _corte,
            limitePago: _limite,
            saldoAlCorte: centavosDeTexto(_saldo.text)!,
            pagoMinimo: centavosDeTexto(_minimo.text)!,
            pagoSinIntereses: centavosDeTexto(_sinIntereses.text)!,
            intereses: centavosDeTexto(_intereses.text) ?? 0,
            tasaDeclaradaPb: _tasa.text.trim().isEmpty
                ? null
                : CampoPorcentaje.puntosBase(_tasa.text),
          );
    },
  );
}

// --------------------------------------------------------------------- tasa

class DialogoTasa extends ConsumerStatefulWidget {
  const DialogoTasa({super.key, required this.deuda});

  final Deuda deuda;

  @override
  ConsumerState<DialogoTasa> createState() => _TasaState();
}

class _TasaState extends ConsumerState<DialogoTasa> {
  final _forma = GlobalKey<FormState>();
  final _tasa = TextEditingController();

  @override
  void dispose() {
    _tasa.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Forma(
    titulo: 'Tasa de ${widget.deuda.titulo}',
    forma: _forma,
    campos: [
      KeyedSubtree(
        key: const ValueKey('tasa-campo'),
        child: CampoPorcentaje(controlador: _tasa, etiqueta: 'Tasa anual'),
      ),
    ],
    alGuardar: () => ref
        .read(servicioFase2Provider)
        .capturarTasa(widget.deuda.id, CampoPorcentaje.puntosBase(_tasa.text)!),
  );
}

// ---------------------------------------------------------------------- MSI

class DialogoMsi extends ConsumerStatefulWidget {
  const DialogoMsi({super.key, required this.contexto});

  final ContextoFinanzas contexto;

  @override
  ConsumerState<DialogoMsi> createState() => _MsiState();
}

class _MsiState extends ConsumerState<DialogoMsi> {
  final _forma = GlobalKey<FormState>();
  final _comercio = TextEditingController();
  final _total = TextEditingController();
  final _meses = TextEditingController(text: '12');
  final _dia = TextEditingController(text: '1');
  final _pagadas = TextEditingController(text: '0');
  late Fecha _compra;
  String? _tarjeta;

  @override
  void initState() {
    super.initState();
    _compra = ref.read(hoyFinanzasProvider);
  }

  @override
  void dispose() {
    for (final c in [_comercio, _total, _meses, _dia, _pagadas]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.contexto;
    final tarjetas = [
      for (final d in c.datos.deudasDe(c.libroId))
        if (d.clase == ClaseDeuda.tarjeta && d.activa) d,
    ];
    return _Forma(
      titulo: 'Compra a meses sin intereses',
      forma: _forma,
      campos: [
        TextFormField(
          key: const ValueKey('msi-comercio'),
          controller: _comercio,
          decoration: const InputDecoration(labelText: 'Comercio'),
          validator: (v) =>
              (v ?? '').trim().isEmpty ? 'Escribe el comercio' : null,
        ),
        KeyedSubtree(
          key: const ValueKey('msi-total'),
          child: CampoMonto(
            controlador: _total,
            etiqueta: 'Total de la compra',
          ),
        ),
        TextFormField(
          key: const ValueKey('msi-meses'),
          controller: _meses,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Meses (2 a 48)'),
          validator: (v) {
            final n = int.tryParse(v ?? '');
            return n == null || n < 2 || n > 48 ? 'De 2 a 48' : null;
          },
        ),
        TextFormField(
          key: const ValueKey('msi-dia'),
          controller: _dia,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Día del mes en que pagas',
          ),
          validator: (v) {
            final n = int.tryParse(v ?? '');
            return n == null || n < 1 || n > 31 ? 'De 1 a 31' : null;
          },
        ),
        TextFormField(
          controller: _pagadas,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Mensualidades que ya pagaste',
          ),
          validator: (v) => int.tryParse(v ?? '') == null ? 'Un número' : null,
        ),
        _CampoFecha(
          etiqueta: 'Fecha de la compra',
          valor: _compra,
          alCambiar: (f) => setState(() => _compra = f),
        ),
        if (tarjetas.isNotEmpty)
          DropdownButtonFormField<String>(
            initialValue: _tarjeta,
            decoration: const InputDecoration(labelText: 'Tarjeta (opcional)'),
            items: [
              for (final t in tarjetas)
                DropdownMenuItem(value: t.id, child: Text(t.titulo)),
            ],
            onChanged: (v) => _tarjeta = v,
          ),
      ],
      alGuardar: () async {
        await ref
            .read(servicioFase2Provider)
            .crearMsi(
              libroId: c.libroId,
              comercio: _comercio.text,
              total: centavosDeTexto(_total.text)!,
              meses: int.parse(_meses.text),
              fechaCompra: _compra,
              diaPago: int.parse(_dia.text),
              tarjetaDeudaId: _tarjeta,
              pagadas: int.tryParse(_pagadas.text) ?? 0,
            );
      },
    );
  }
}

// -------------------------------------------------------------------- bolsa

class DialogoBolsa extends ConsumerStatefulWidget {
  const DialogoBolsa({super.key, required this.contexto});

  final ContextoFinanzas contexto;

  @override
  ConsumerState<DialogoBolsa> createState() => _BolsaState();
}

class _BolsaState extends ConsumerState<DialogoBolsa> {
  final _forma = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _monto = TextEditingController();
  final _saldo = TextEditingController();
  TipoBolsaAhorro _tipo = TipoBolsaAhorro.metaLibre;
  Fecha? _fecha;

  @override
  void dispose() {
    for (final c in [_nombre, _monto, _saldo]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _nombreTipo(TipoBolsaAhorro t) => switch (t) {
    TipoBolsaAhorro.fondoEmergencia => 'Fondo de emergencia',
    TipoBolsaAhorro.reserva => 'Reserva anual',
    TipoBolsaAhorro.metaFecha => 'Meta con fecha',
    TipoBolsaAhorro.metaLibre => 'Meta sin fecha',
  };

  @override
  Widget build(BuildContext context) {
    final c = widget.contexto;
    final yaHayFondo = c.datos
        .bolsasDe(c.libroId)
        .any((b) => b.tipo == TipoBolsaAhorro.fondoEmergencia);
    final tipos = [
      for (final t in TipoBolsaAhorro.values)
        if (!(t == TipoBolsaAhorro.fondoEmergencia && yaHayFondo)) t,
    ];
    if (!tipos.contains(_tipo)) _tipo = tipos.first;
    return _Forma(
      titulo: 'Nueva bolsa de ahorro',
      forma: _forma,
      campos: [
        TextFormField(
          key: const ValueKey('bolsa-nombre'),
          controller: _nombre,
          decoration: const InputDecoration(labelText: 'Nombre'),
          validator: (v) =>
              (v ?? '').trim().isEmpty ? 'Escribe un nombre' : null,
        ),
        DropdownButtonFormField<TipoBolsaAhorro>(
          key: const ValueKey('bolsa-tipo'),
          initialValue: _tipo,
          decoration: const InputDecoration(labelText: 'Tipo'),
          items: [
            for (final t in tipos)
              DropdownMenuItem(value: t, child: Text(_nombreTipo(t))),
          ],
          onChanged: (t) => setState(() => _tipo = t!),
        ),
        if (_tipo != TipoBolsaAhorro.fondoEmergencia)
          KeyedSubtree(
            key: const ValueKey('bolsa-monto'),
            child: CampoMonto(
              controlador: _monto,
              etiqueta: _tipo == TipoBolsaAhorro.reserva
                  ? 'Monto al año'
                  : 'Meta',
              obligatorio: _tipo != TipoBolsaAhorro.metaLibre,
            ),
          ),
        if (_tipo == TipoBolsaAhorro.metaFecha)
          _CampoFecha(
            key: const ValueKey('bolsa-fecha'),
            etiqueta: 'Fecha meta',
            valor: _fecha ?? ref.read(hoyFinanzasProvider).sumarDias(365),
            alCambiar: (f) => setState(() => _fecha = f),
          ),
        CampoMonto(
          controlador: _saldo,
          etiqueta: 'Lo que ya tienes ahorrado',
          obligatorio: false,
        ),
      ],
      alGuardar: () async {
        final monto = centavosDeTexto(_monto.text);
        await ref
            .read(servicioFase2Provider)
            .crearBolsa(
              libroId: c.libroId,
              nombre: _nombre.text,
              tipo: _tipo,
              meta: _tipo == TipoBolsaAhorro.reserva ? null : monto,
              montoAnual: _tipo == TipoBolsaAhorro.reserva ? monto : null,
              fechaMeta: _tipo == TipoBolsaAhorro.metaFecha
                  ? (_fecha ?? ref.read(hoyFinanzasProvider).sumarDias(365))
                  : null,
              saldoInicial: centavosDeTexto(_saldo.text) ?? 0,
            );
      },
    );
  }
}

// ------------------------------------------------------------------- retiro

class DialogoRetiro extends ConsumerStatefulWidget {
  const DialogoRetiro({super.key, required this.contexto, required this.bolsa});

  final ContextoFinanzas contexto;
  final dom.BolsaAhorro bolsa;

  @override
  ConsumerState<DialogoRetiro> createState() => _RetiroState();
}

class _RetiroState extends ConsumerState<DialogoRetiro> {
  final _forma = GlobalKey<FormState>();
  final _monto = TextEditingController();
  final _motivo = TextEditingController();
  TipoRetiro _tipo = TipoRetiro.usoPrevisto;
  String? _cuenta;
  String? _bolsaDestino;

  // Una vez por formulario: reintentar no duplica el retiro.
  final String _movimientoId = const Uuid().v4();
  final String _retiroId = const Uuid().v4();

  @override
  void dispose() {
    _monto.dispose();
    _motivo.dispose();
    super.dispose();
  }

  static String _nombreTipo(TipoRetiro t) => switch (t) {
    TipoRetiro.usoPrevisto => 'Uso previsto',
    TipoRetiro.emergencia => 'Emergencia',
    TipoRetiro.cambioDeDestino => 'Cambio de destino',
  };

  @override
  Widget build(BuildContext context) {
    final c = widget.contexto;
    final cuentas = [
      for (final x in c.datos.cuentasDe(c.libroId))
        if ((x.tipo == TipoCuenta.efectivo || x.tipo == TipoCuenta.banco) &&
            x.estado == EstadoCuenta.activa)
          x,
    ];
    final otras = [
      for (final b in c.datos.bolsasDe(c.libroId))
        if (b.id != widget.bolsa.id) b,
    ];
    return _Forma(
      titulo: 'Retirar de ${widget.bolsa.nombre}',
      textoGuardar: 'Retirar',
      necesitaSenal: true,
      forma: _forma,
      campos: [
        DropdownButtonFormField<TipoRetiro>(
          key: const ValueKey('retiro-tipo'),
          initialValue: _tipo,
          decoration: const InputDecoration(labelText: 'Motivo del retiro'),
          items: [
            for (final t in TipoRetiro.values)
              DropdownMenuItem(value: t, child: Text(_nombreTipo(t))),
          ],
          onChanged: (t) => setState(() => _tipo = t!),
        ),
        KeyedSubtree(
          key: const ValueKey('retiro-monto'),
          child: CampoMonto(controlador: _monto, etiqueta: 'Monto'),
        ),
        if (_tipo == TipoRetiro.cambioDeDestino)
          DropdownButtonFormField<String>(
            key: const ValueKey('retiro-bolsa'),
            initialValue: _bolsaDestino,
            decoration: const InputDecoration(labelText: 'A qué bolsa'),
            items: [
              for (final b in otras)
                DropdownMenuItem(value: b.id, child: Text(b.nombre)),
            ],
            onChanged: (v) => _bolsaDestino = v,
            validator: (v) => v == null ? 'Elige la bolsa' : null,
          )
        else
          DropdownButtonFormField<String>(
            key: const ValueKey('retiro-cuenta'),
            initialValue: _cuenta,
            decoration: const InputDecoration(labelText: 'A qué cuenta'),
            items: [
              for (final x in cuentas)
                DropdownMenuItem(value: x.id, child: Text(x.nombre)),
            ],
            onChanged: (v) => _cuenta = v,
            validator: (v) => v == null ? 'Elige la cuenta' : null,
          ),
        TextFormField(
          key: const ValueKey('retiro-motivo'),
          controller: _motivo,
          decoration: const InputDecoration(
            labelText: 'Motivo',
            helperText: ayudaDelMotivo,
            helperMaxLines: 3,
            errorMaxLines: 3,
          ),
          validator: (v) => motivoValido(v) ? null : mensajeMotivoCorto,
        ),
      ],
      alGuardar: () => ref
          .read(servicioFase2Provider)
          .retirar(
            bolsaId: widget.bolsa.id,
            monto: centavosDeTexto(_monto.text)!,
            tipo: _tipo,
            motivo: _motivo.text,
            cuentaDestinoId: _cuenta,
            bolsaDestinoId: _bolsaDestino,
            movimientoId: _movimientoId,
            retiroId: _retiroId,
          ),
    );
  }
}

// ------------------------------------------------------------ confirmar ahorro

class DialogoConfirmarAportacion extends ConsumerStatefulWidget {
  const DialogoConfirmarAportacion({
    super.key,
    required this.contexto,
    required this.aportacion,
    required this.nombreBolsa,
  });

  final ContextoFinanzas contexto;
  final AportacionAhorro aportacion;
  final String nombreBolsa;

  @override
  ConsumerState<DialogoConfirmarAportacion> createState() =>
      _ConfirmarAportacionState();
}

class _ConfirmarAportacionState
    extends ConsumerState<DialogoConfirmarAportacion> {
  final _forma = GlobalKey<FormState>();
  late final TextEditingController _monto = TextEditingController(
    text: textoDeCentavos(widget.aportacion.sugerido),
  );
  String? _cuenta;

  @override
  void dispose() {
    _monto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.contexto;
    final cuentas = [
      for (final x in c.datos.cuentasDe(c.libroId))
        if ((x.tipo == TipoCuenta.efectivo || x.tipo == TipoCuenta.banco) &&
            x.estado == EstadoCuenta.activa)
          x,
    ];
    return _Forma(
      titulo: 'Apartar para ${widget.nombreBolsa}',
      textoGuardar: 'Confirmar',
      necesitaSenal: true,
      forma: _forma,
      campos: [
        KeyedSubtree(
          key: const ValueKey('apartar-monto'),
          child: CampoMonto(controlador: _monto, etiqueta: 'Monto a apartar'),
        ),
        DropdownButtonFormField<String>(
          key: const ValueKey('apartar-cuenta'),
          initialValue: _cuenta,
          decoration: const InputDecoration(labelText: 'De qué cuenta sale'),
          items: [
            for (final x in cuentas)
              DropdownMenuItem(value: x.id, child: Text(x.nombre)),
          ],
          onChanged: (v) => _cuenta = v,
          validator: (v) => v == null ? 'Elige la cuenta' : null,
        ),
      ],
      alGuardar: () => ref
          .read(servicioFase2Provider)
          .confirmarAportacion(
            aportacionId: widget.aportacion.id,
            cuentaOrigenId: _cuenta!,
            monto: centavosDeTexto(_monto.text),
          ),
    );
  }
}

// ------------------------------------------------------------ importar ficha

/// Importa `FICHA_DEUDAS_Y_TARJETAS.xlsx`: elige el archivo, muestra una vista
/// previa (lo que se crea y lo que se omite, con su motivo) y pide confirmar.
class DialogoImportarFicha extends ConsumerStatefulWidget {
  const DialogoImportarFicha({super.key, required this.contexto});

  final ContextoFinanzas contexto;

  @override
  ConsumerState<DialogoImportarFicha> createState() => _FichaState();
}

class _FichaState extends ConsumerState<DialogoImportarFicha> {
  LecturaFicha? _lectura;
  String? _error;
  bool _trabajando = false;
  ResultadoFicha? _resultado;

  Future<void> _elegir() async {
    setState(() {
      _trabajando = true;
      _error = null;
      _resultado = null;
    });
    try {
      final ArchivoElegido? a = await ref.read(selectorArchivoProvider)();
      if (a == null) {
        setState(() => _trabajando = false);
        return;
      }
      final lectura = leerFichaDeBytes(a.bytes, nombre: a.nombre);
      setState(() {
        _lectura = lectura;
        _trabajando = false;
      });
    } on ErrorArchivo catch (e) {
      setState(() {
        _error = e.mensaje;
        _lectura = null;
        _trabajando = false;
      });
    } catch (_) {
      setState(() {
        _error = 'No pude abrir el archivo.';
        _trabajando = false;
      });
    }
  }

  Future<void> _confirmar() async {
    setState(() => _trabajando = true);
    try {
      final r = await ref
          .read(servicioFase2Provider)
          .aplicarFicha(widget.contexto.libroId, _lectura!);
      setState(() {
        _resultado = r;
        _trabajando = false;
      });
    } catch (e) {
      setState(() {
        _trabajando = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _lectura;
    return AlertDialog(
      title: const Text('Importar la ficha de deudas'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Elige tu FICHA_DEUDAS_Y_TARJETAS.xlsx. Se importan las hojas '
                'Tarjetas, Credito_Auto y MSI; lo que no tenga saldo o monto '
                'se omite y se explica.',
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    key: const ValueKey('ficha-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (l != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Se crearán: ${l.tarjetas.length} tarjetas, '
                  '${l.credito == null ? 0 : 1} crédito, ${l.msi.length} compras a meses.',
                  key: const ValueKey('ficha-resumen'),
                ),
                for (final o in l.omitidas)
                  Text('Omitido · ${o.hoja}: ${o.motivo}'),
              ],
              if (_resultado != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Listo: ${_resultado!.creadas} creadas, '
                    '${_resultado!.yaExistian} ya estaban.',
                    key: const ValueKey('ficha-listo'),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_resultado == null ? 'Cancelar' : 'Cerrar'),
        ),
        OutlinedButton(
          key: const ValueKey('ficha-elegir'),
          onPressed: _trabajando ? null : _elegir,
          child: const Text('Elegir archivo'),
        ),
        if (l != null && !l.vacia && _resultado == null)
          FilledButton(
            key: const ValueKey('ficha-confirmar'),
            onPressed: _trabajando ? null : _confirmar,
            child: const Text('Importar'),
          ),
      ],
    );
  }
}
