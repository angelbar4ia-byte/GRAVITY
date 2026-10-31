/// (+) Ingreso extra en el teléfono: monto → cuenta → fecha (hoy) → Guardar
/// (5.1 bis, punto 4: los extras cuentan en la semana en que llegan).
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
import '../../casos_uso/sugerencias.dart';
import '../../estado/proveedores.dart';
import '../comunes.dart';
import 'hoja_gasto.dart';
import 'marco_hoja.dart';
import 'nueva_cuenta_en_hoja.dart';

class HojaIngresoExtra extends ConsumerStatefulWidget {
  const HojaIngresoExtra({super.key});

  @override
  ConsumerState<HojaIngresoExtra> createState() => _HojaIngresoExtraState();
}

class _HojaIngresoExtraState extends ConsumerState<HojaIngresoExtra> {
  int _monto = 0;
  String? _libroId;
  String? _cuentaId;
  Fecha? _fecha;
  bool _creandoCuenta = false;
  final _nota = TextEditingController();
  final _motivo = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _nota.dispose();
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _guardar(Libro libro) async {
    setState(() => _guardando = true);
    final navegador = Navigator.of(context);
    final servicio = ref.read(servicioFinanzasProvider);
    try {
      final r = await servicio.registrarIngresoExtra(
        libroId: libro.id,
        monto: _monto,
        cuentaDestinoId: _cuentaId!,
        fecha: _fecha,
        nota: _nota.text,
        motivo: libro.tipo == dom.TipoLibro.representado ? _motivo.text : null,
      );
      if (mounted) avisarGuardado(context, r, servicio);
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
    final v = ValoresDiseno.de(context);
    if (c == null) {
      return const MarcoHojaRegistro(
        titulo: 'Ingreso extra',
        cuerpo: Center(child: CircularProgressIndicator()),
      );
    }
    final libros = librosParaRegistrar(c);
    if (libros.isEmpty) {
      return const MarcoHojaRegistro(
        titulo: 'Ingreso extra',
        cuerpo: Text('Solo lectura: no tienes un libro donde registrar.'),
      );
    }
    final libro = libros.firstWhere(
      (l) => l.id == _libroId,
      orElse: () => libros.first,
    );
    final cuentas = cuentasParaRecibir(c.datos, libro.id);
    if (!cuentas.any((x) => x.id == _cuentaId)) {
      _cuentaId = cuentas.firstOrNull?.id;
    }
    final representado = libro.tipo == dom.TipoLibro.representado;
    final fecha = _fecha ?? c.hoy;
    final puedeGuardar =
        _monto > 0 &&
        _cuentaId != null &&
        !_guardando &&
        (!representado || motivoValido(_motivo.text));
    return MarcoHojaRegistro(
      titulo: 'Ingreso extra',
      // El monto comparte línea con el título; se encoge en vez de partirse.
      tituloDerecha: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          formatearCentavos(_monto),
          key: const ValueKey('extra-monto'),
          textAlign: TextAlign.center,
          style: v.numero(
            tamano: 32,
            peso: FontWeight.w600,
            color: v.textoFuerte,
          ),
        ),
      ),
      barra: BarraAccionesRegistro(
        llaveGuardar: const ValueKey('extra-guardar'),
        alGuardar: puedeGuardar ? () => _guardar(libro) : null,
      ),
      cuerpo: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (libros.length > 1)
            // Una sola línea que se desliza (ver hoja_gasto.dart, I8).
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final l in libros) ...[
                    ChoiceChip(
                      key: ValueKey('extra-libro-${l.id}'),
                      label: Text(
                        opcionDe(l, c.permisoEn(l), c.personaId).etiqueta,
                      ),
                      selected: l.id == libro.id,
                      onSelected: (_) => setState(() {
                        _libroId = l.id;
                        _creandoCuenta = false;
                      }),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          TecladoMonto(
            alCambiar: (centavos) => setState(() => _monto = centavos),
            autofocus: true,
            // Teclas de 48 dp: categoría y cuenta quedan a la vista (I8).
            compacto: true,
          ),
          const SizedBox(height: 12),
          const EtiquetaPanel('Entró a'),
          if (cuentas.isEmpty || _creandoCuenta) ...[
            if (cuentas.isEmpty)
              Text(
                'Este libro aún no tiene una cuenta donde reciba dinero. Crea '
                'la primera y sigue con el ingreso.',
                key: const ValueKey('extra-sin-cuentas'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (c.permisoEn(libro).administrar)
              NuevaCuentaEnHoja(
                key: ValueKey('extra-cuenta-nueva-${libro.id}'),
                libroId: libro.id,
                tipos: const [TipoCuenta.efectivo, TipoCuenta.banco],
                alCrear: (id) => setState(() {
                  _cuentaId = id;
                  _creandoCuenta = false;
                }),
              )
            else
              const Text('Pide a quien administra este libro que cree una cuenta.'),
          ] else
            Wrap(
              spacing: 8,
              children: [
                for (final cuenta in cuentas)
                  ChoiceChip(
                    key: ValueKey('extra-cuenta-${cuenta.id}'),
                    label: Text(cuenta.nombre),
                    selected: _cuentaId == cuenta.id,
                    onSelected: (_) => setState(() => _cuentaId = cuenta.id),
                  ),
                if (c.permisoEn(libro).administrar)
                  ActionChip(
                    key: const ValueKey('extra-cuenta-nueva'),
                    avatar: const Icon(Icons.add, size: 18),
                    label: const Text('Cuenta nueva'),
                    onPressed: () => setState(() => _creandoCuenta = true),
                  ),
              ],
            ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ActionChip(
              key: const ValueKey('extra-fecha'),
              avatar: const Icon(Icons.event_outlined, size: 18),
              label: Text(fecha == c.hoy ? 'Hoy' : textoFecha(fecha)),
              onPressed: () async {
                final f = await elegirFecha(context, fecha);
                if (f != null) setState(() => _fecha = f);
              },
            ),
          ),
          TextField(
            controller: _nota,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'De qué es (opcional)'),
          ),
          if (representado)
            TextField(
              key: const ValueKey('extra-motivo'),
              controller: _motivo,
              maxLength: 200,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Motivo (obligatorio)',
                helperText: '$ayudaDelMotivo Se registra en nombre de ${libro.nombre}.',
                helperMaxLines: 3,
              ),
            ),
        ],
      ),
    );
  }
}
