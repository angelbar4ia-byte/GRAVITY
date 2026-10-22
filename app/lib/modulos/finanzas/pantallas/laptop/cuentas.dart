/// Cuentas (laptop; especificación 6.1): activos y pasivos con saldo,
/// balance y estado de resultados con selector de periodo, conciliar,
/// congelar, cerrar, archivar o eliminar (5.0 bis 2).
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide Semaforo, formatearCentavos, TipoLibro, puntosBaseEnCien;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../diseno/diseno.dart';
import '../../estado/proveedores.dart';
import '../comunes.dart';
import '../fila_movimiento.dart';
import 'marco_laptop.dart';

class PantallaCuentas extends StatelessWidget {
  const PantallaCuentas({super.key});

  @override
  Widget build(BuildContext context) => MarcoFinanzasLaptop(
    seccion: SeccionFinanzas.cuentas,
    acciones: (context, c) => [
      if (c.puedeAdministrar)
        FilledButton.icon(
          key: const ValueKey('cuentas-nueva'),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => DialogoCuenta(contexto: c),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Nueva cuenta'),
        ),
    ],
    builder: (context, c) => _Cuentas(contexto: c),
  );
}

class _Cuentas extends ConsumerStatefulWidget {
  const _Cuentas({required this.contexto});

  final ContextoFinanzas contexto;

  @override
  ConsumerState<_Cuentas> createState() => _CuentasState();
}

class _CuentasState extends ConsumerState<_Cuentas> {
  TipoPeriodo _periodo = TipoPeriodo.mes;
  String? _seleccionada;

  @override
  Widget build(BuildContext context) {
    final c = widget.contexto;
    final vista = c.datos.vista(c.libroId);
    final ocultos = ref.watch(montosOcultosProvider);
    final balance = vista.balance();
    final periodo = Periodo.de(
      _periodo == TipoPeriodo.catorcena ? TipoPeriodo.semana : _periodo,
      c.hoy,
    );
    final resultados = vista.estadoResultados(periodo);
    List<Cuenta> de(ClaseCuenta clase) => [
      for (final x in c.datos.cuentasDe(c.libroId))
        if (x.clase == clase) x,
    ]..sort((a, b) => a.nombre.compareTo(b.nombre));
    FilaTabla fila(Cuenta x) => FilaTabla(
      seleccionada: x.id == _seleccionada,
      etiquetaSemantica: x.nombre,
      alTocar: () => setState(() => _seleccionada = x.id),
      celdas: [
        CeldaTexto(x.nombre, detalle: x.estado == EstadoCuenta.activa ? null : x.estado.name),
        CeldaTexto(nombreTipoCuenta(x.tipo)),
        CeldaMonto(vista.saldo(x.id), oculto: ocultos),
      ],
    );
    TablaDensa tabla(String titulo, List<Cuenta> cuentas) => TablaDensa(
      key: ValueKey('cuentas-$titulo'),
      anchoMinimo: 420,
      etiquetaSemantica: titulo,
      vacio: Text('Sin $titulo en este libro.'),
      columnas: const [
        ColumnaTabla('Cuenta', flex: 3),
        ColumnaTabla('Tipo', flex: 2),
        ColumnaTabla('Saldo', numerica: true, flex: 2),
      ],
      filas: [for (final x in cuentas) fila(x)],
    );
    final seleccionada = c.datos.cuenta(_seleccionada ?? '');
    final lista = ContenidoLaptop(
      children: [
        Rejilla(
          anchoMinimo: 380,
          children: [
            TarjetaModulo(
              titulo: 'Activos (lo que tengo)',
              icono: Icons.account_balance_wallet_outlined,
              child: tabla('activos', de(ClaseCuenta.activo)),
            ),
            TarjetaModulo(
              titulo: 'Pasivos (lo que debo)',
              icono: Icons.credit_card_outlined,
              child: tabla('pasivos', de(ClaseCuenta.pasivo)),
            ),
          ],
        ),
        Rejilla(
          anchoMinimo: 380,
          children: [
            TarjetaModulo(
              key: const ValueKey('cuentas-balance'),
              titulo: 'Balance',
              icono: Icons.balance_outlined,
              child: Column(
                children: [
                  _Renglon('Activos', balance.activos),
                  _Renglon('Pasivos', balance.pasivos),
                  _Renglon('Patrimonio', balance.patrimonio),
                  _Renglon('Disponible (efectivo y bancos)', vista.disponible()),
                  const Divider(),
                  // Cuadre del libro (D19): las aportaciones entre libros
                  // cambian el patrimonio sin pasar por el resultado.
                  _Renglon('Patrimonio inicial', balance.patrimonioInicial),
                  _Renglon('+ Resultado (ingresos − gastos)', balance.resultadoAcumulado),
                  if (balance.ajustes != 0)
                    _Renglon('+ Ajustes de conciliación', balance.ajustes),
                  if (balance.aportacionesRecibidas != 0)
                    _Renglon(
                      '+ Aportaciones recibidas de otros libros',
                      balance.aportacionesRecibidas,
                    ),
                  if (balance.aportacionesEntregadas != 0)
                    _Renglon(
                      '− Aportaciones entregadas a otros libros',
                      balance.aportacionesEntregadas,
                    ),
                  _Renglon('= Patrimonio', balance.patrimonioEsperado),
                  const SizedBox(height: 8),
                  Semaforo(
                    key: const ValueKey('cuentas-cuadre'),
                    estado: balance.cuadra ? EstadoSemaforo.verde : EstadoSemaforo.rojo,
                    etiqueta: balance.cuadra ? 'Cuadra' : 'Descuadre',
                  ),
                ],
              ),
            ),
            TarjetaModulo(
              key: const ValueKey('cuentas-resultados'),
              titulo: 'Estado de resultados',
              icono: Icons.summarize_outlined,
              accion: DropdownButton<TipoPeriodo>(
                value: _periodo,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: TipoPeriodo.semana, child: Text('Semana')),
                  DropdownMenuItem(value: TipoPeriodo.quincena, child: Text('Quincena')),
                  DropdownMenuItem(value: TipoPeriodo.mes, child: Text('Mes')),
                ],
                onChanged: (v) => setState(() => _periodo = v!),
              ),
              child: Column(
                children: [
                  Text('${textoFecha(periodo.inicio)} a ${textoFecha(periodo.fin)}'),
                  _Renglon('Ingresos', resultados.ingresos),
                  _Renglon('Gastos', resultados.gastos),
                  _Renglon('Gasto financiero', resultados.gastoFinanciero),
                  _Renglon('Resultado', resultados.resultado),
                ],
              ),
            ),
          ],
        ),
      ],
    );
    if (seleccionada == null) return lista;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: lista),
        const VerticalDivider(width: 1),
        SizedBox(
          width: 380,
          child: _DetalleCuenta(
            cuenta: seleccionada,
            contexto: c,
            alCerrar: () => setState(() => _seleccionada = null),
          ),
        ),
      ],
    );
  }
}

class _Renglon extends StatelessWidget {
  const _Renglon(this.etiqueta, this.centavos);

  final String etiqueta;
  final int centavos;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [Expanded(child: Text(etiqueta)), Monto(centavos)]),
  );
}

class _DetalleCuenta extends ConsumerWidget {
  const _DetalleCuenta({
    required this.cuenta,
    required this.contexto,
    required this.alCerrar,
  });

  final Cuenta cuenta;
  final ContextoFinanzas contexto;
  final VoidCallback alCerrar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = contexto;
    final x = cuenta;
    final vista = c.datos.vista(c.libroId);
    final servicio = ref.read(servicioFinanzasProvider);
    final movimientos = [
      for (final m in movimientosDelLibro(c))
        if (m.cuentaOrigenId == x.id || m.cuentaDestinoId == x.id) m,
    ];
    final tieneApertura = movimientos.any((m) => m.tipo == TipoMovimiento.apertura);
    final conciliable = x.clase == ClaseCuenta.activo || x.clase == ClaseCuenta.pasivo;
    return ListView(
      key: const ValueKey('cuentas-detalle'),
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: Text(x.nombre, style: Theme.of(context).textTheme.titleMedium)),
            IconButton(tooltip: 'Cerrar detalle', onPressed: alCerrar, icon: const Icon(Icons.close)),
          ],
        ),
        Text('${nombreTipoCuenta(x.tipo)} · ${x.estado.name}'),
        Monto(vista.saldo(x.id)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (c.puedeEscribir && conciliable && x.estado == EstadoCuenta.activa)
              OutlinedButton(
                key: const ValueKey('cuentas-conciliar'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _DialogoConciliar(cuenta: x, contexto: c),
                ),
                child: const Text('Conciliar'),
              ),
            if (c.puedeEscribir && conciliable && !tieneApertura)
              OutlinedButton(
                onPressed: () async {
                  final texto = await pedirTexto(
                    context,
                    titulo: 'Saldo inicial',
                    etiqueta: 'Saldo al día de hoy (pesos)',
                  );
                  final saldo = texto == null ? null : centavosDeTexto(texto);
                  if (saldo != null && context.mounted) {
                    await intentar(
                      context,
                      () => servicio.registrarApertura(
                        cuentaId: x.id,
                        saldo: saldo,
                        fecha: c.hoy,
                      ),
                    );
                  }
                },
                child: const Text('Saldo inicial'),
              ),
            if (c.puedeAdministrar && x.estado == EstadoCuenta.activa && conciliable)
              OutlinedButton(
                onPressed: () => intentar(
                  context,
                  () => servicio.cambiarEstadoCuenta(x.id, EstadoCuenta.congelada),
                ),
                child: const Text('Congelar'),
              ),
            if (c.puedeAdministrar && x.estado == EstadoCuenta.congelada)
              OutlinedButton(
                onPressed: () => intentar(
                  context,
                  () => servicio.cambiarEstadoCuenta(x.id, EstadoCuenta.activa),
                ),
                child: const Text('Reactivar'),
              ),
            if (c.puedeAdministrar &&
                x.estado != EstadoCuenta.cerrada &&
                x.estado != EstadoCuenta.archivada &&
                x.tipo != TipoCuenta.ajustes &&
                x.tipo != TipoCuenta.apertura &&
                x.tipo != TipoCuenta.porClasificar) ...[
              OutlinedButton(
                key: const ValueKey('cuentas-cerrar'),
                onPressed: () => intentar(
                  context,
                  () => servicio.cambiarEstadoCuenta(x.id, EstadoCuenta.cerrada),
                ),
                child: const Text('Cerrar'),
              ),
              OutlinedButton(
                onPressed: () => intentar(
                  context,
                  () => servicio.cambiarEstadoCuenta(x.id, EstadoCuenta.archivada),
                ),
                child: const Text('Archivar'),
              ),
            ],
            if (c.puedeAdministrar && movimientos.isEmpty &&
                x.tipo != TipoCuenta.ajustes &&
                x.tipo != TipoCuenta.apertura &&
                x.tipo != TipoCuenta.porClasificar)
              OutlinedButton(
                key: const ValueKey('cuentas-eliminar'),
                onPressed: () async {
                  if (await confirmar(
                        context,
                        titulo: 'Eliminar cuenta',
                        mensaje: 'No tiene movimientos: se puede eliminar.',
                        textoAccion: 'Eliminar',
                      ) &&
                      context.mounted) {
                    await intentar(context, () => servicio.eliminarCuenta(x.id));
                  }
                },
                child: const Text('Eliminar'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const EtiquetaPanel('Movimientos'),
        for (final m in movimientos.take(30)) FilaMovimiento(movimiento: m, contexto: c),
        if (movimientos.isEmpty) const Text('Sin movimientos.'),
      ],
    );
  }
}

class _DialogoConciliar extends ConsumerStatefulWidget {
  const _DialogoConciliar({required this.cuenta, required this.contexto});

  final Cuenta cuenta;
  final ContextoFinanzas contexto;

  @override
  ConsumerState<_DialogoConciliar> createState() => _DialogoConciliarState();
}

class _DialogoConciliarState extends ConsumerState<_DialogoConciliar> {
  final _forma = GlobalKey<FormState>();
  final _saldo = TextEditingController();
  final _motivo = TextEditingController();

  @override
  void dispose() {
    _saldo.dispose();
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.contexto;
    final calculado = c.datos.vista(c.libroId).saldo(widget.cuenta.id, hasta: c.hoy);
    final declarado = centavosDeTexto(_saldo.text);
    final diferencia = declarado == null ? null : declarado - calculado;
    return AlertDialog(
      title: Text('Conciliar ${widget.cuenta.nombre}'),
      content: Form(
        key: _forma,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [const Text('Según la app: '), Monto(calculado)]),
            CampoMonto(
              key: const ValueKey('conciliar-saldo'),
              controlador: _saldo,
              etiqueta: 'Saldo real',
            ),
            if (diferencia != null && diferencia != 0) ...[
              Row(children: [const Text('Diferencia: '), Monto(diferencia, signo: true)]),
              TextFormField(
                key: const ValueKey('conciliar-motivo'),
                controller: _motivo,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Motivo del ajuste (obligatorio)',
                ),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe el motivo' : null,
              ),
            ],
            const Text(
              'Si hay diferencia se registra un ajuste con su motivo en la '
              'cuenta Ajustes, visible siempre.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          key: const ValueKey('conciliar-guardar'),
          onPressed: () async {
            setState(() {});
            if (!(_forma.currentState?.validate() ?? false)) return;
            final saldo = centavosDeTexto(_saldo.text)!;
            final navegador = Navigator.of(context);
            if (await intentar(
              context,
              () => ref.read(servicioFinanzasProvider).conciliar(
                cuentaId: widget.cuenta.id,
                saldoDeclarado: saldo,
                fecha: c.hoy,
                motivo: _motivo.text,
              ),
            )) {
              navegador.pop();
            }
          },
          child: const Text('Conciliar'),
        ),
      ],
    );
  }
}

/// Nueva cuenta del libro con su saldo inicial (también en el asistente).
class DialogoCuenta extends ConsumerStatefulWidget {
  const DialogoCuenta({super.key, required this.contexto});

  final ContextoFinanzas contexto;

  @override
  ConsumerState<DialogoCuenta> createState() => _DialogoCuentaState();
}

class _DialogoCuentaState extends ConsumerState<DialogoCuenta> {
  final _forma = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _saldo = TextEditingController();
  final _limite = TextEditingController();
  TipoCuenta _tipo = TipoCuenta.banco;

  @override
  void dispose() {
    _nombre.dispose();
    _saldo.dispose();
    _limite.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nueva cuenta'),
    content: Form(
      key: _forma,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            key: const ValueKey('cuenta-nombre'),
            controller: _nombre,
            decoration: const InputDecoration(labelText: 'Nombre'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe un nombre' : null,
          ),
          DropdownButtonFormField<TipoCuenta>(
            key: const ValueKey('cuenta-tipo'),
            initialValue: _tipo,
            decoration: const InputDecoration(labelText: 'Tipo'),
            items: [
              for (final t in const [
                TipoCuenta.efectivo,
                TipoCuenta.banco,
                TipoCuenta.ahorro,
                TipoCuenta.inversion,
                TipoCuenta.tarjeta,
                TipoCuenta.prestamo,
                TipoCuenta.origenIngreso,
              ])
                DropdownMenuItem(value: t, child: Text(nombreTipoCuenta(t))),
            ],
            onChanged: (t) => setState(() => _tipo = t!),
          ),
          if (_tipo != TipoCuenta.origenIngreso)
            CampoMonto(
              key: const ValueKey('cuenta-saldo'),
              controlador: _saldo,
              etiqueta: _tipo == TipoCuenta.tarjeta || _tipo == TipoCuenta.prestamo
                  ? 'Lo que debes hoy (opcional)'
                  : 'Saldo de hoy (opcional)',
              obligatorio: false,
            ),
          if (_tipo == TipoCuenta.tarjeta)
            CampoMonto(controlador: _limite, etiqueta: 'Límite (opcional)', obligatorio: false),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(
        key: const ValueKey('cuenta-guardar'),
        onPressed: () async {
          if (!(_forma.currentState?.validate() ?? false)) return;
          final navegador = Navigator.of(context);
          final c = widget.contexto;
          if (await intentar(
            context,
            () => ref.read(servicioFinanzasProvider).crearCuenta(
              libroId: c.libroId,
              nombre: _nombre.text,
              tipo: _tipo,
              saldoInicial: centavosDeTexto(_saldo.text) ?? 0,
              fechaSaldo: c.hoy,
              limiteCentavos: centavosDeTexto(_limite.text),
            ),
          )) {
            navegador.pop();
          }
        },
        child: const Text('Crear'),
      ),
    ],
  );
}
