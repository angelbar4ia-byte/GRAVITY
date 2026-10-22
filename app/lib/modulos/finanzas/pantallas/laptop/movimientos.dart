/// Movimientos (laptop; especificación 6.1): tabla paginada con filtros por
/// fecha, cuenta, categoría, tipo y estado; detalle en panel lateral con su
/// contraasiento. Anular pide motivo.
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
import 'tablero.dart' show accionRegistrar;

class PantallaMovimientos extends StatelessWidget {
  const PantallaMovimientos({super.key});

  @override
  Widget build(BuildContext context) => MarcoFinanzasLaptop(
    seccion: SeccionFinanzas.movimientos,
    acciones: accionRegistrar,
    builder: (context, c) => _Movimientos(contexto: c),
  );
}

enum _Rango { semana, semanaPasada, mes, todo }

enum _Estado { todos, vigentes, anulados }

class _Movimientos extends ConsumerStatefulWidget {
  const _Movimientos({required this.contexto});

  final ContextoFinanzas contexto;

  @override
  ConsumerState<_Movimientos> createState() => _MovimientosState();
}

class _MovimientosState extends ConsumerState<_Movimientos> {
  static const porPagina = 40;
  _Rango _rango = _Rango.todo;
  String? _cuenta;
  String? _categoria;
  TipoMovimiento? _tipo;
  _Estado _estado = _Estado.todos;
  int _pagina = 0;
  String? _seleccionado;

  ContextoFinanzas get c => widget.contexto;

  List<Movimiento> _filtrados(LibroMovimientos vista) {
    final hoy = c.hoy;
    final periodo = switch (_rango) {
      _Rango.semana => Periodo.semana(hoy),
      _Rango.semanaPasada => Periodo.semana(hoy.sumarDias(-7)),
      _Rango.mes => Periodo.mes(hoy),
      _Rango.todo => null,
    };
    final familia = _categoria == null
        ? null
        : c.datos.arbol.conDescendientes(_categoria!);
    return [
      for (final m in movimientosDelLibro(c))
        if ((periodo == null || periodo.contiene(m.fecha)) &&
            (_cuenta == null ||
                m.cuentaOrigenId == _cuenta ||
                m.cuentaDestinoId == _cuenta) &&
            (familia == null || familia.contains(m.categoriaId)) &&
            (_tipo == null || m.tipo == _tipo) &&
            switch (_estado) {
              _Estado.todos => true,
              _Estado.vigentes =>
                !vista.estaAnulado(m.id) && m.tipo != TipoMovimiento.anulacion,
              _Estado.anulados =>
                vista.estaAnulado(m.id) || m.tipo == TipoMovimiento.anulacion,
            })
          m,
    ];
  }

  Widget _filtro<T>(
    String etiqueta,
    T valor,
    List<(T, String)> opciones,
    ValueChanged<T> alCambiar,
  ) => SizedBox(
    width: 200,
    child: DropdownButtonFormField<T>(
      initialValue: valor,
      isExpanded: true,
      decoration: InputDecoration(labelText: etiqueta, isDense: true),
      items: [
        for (final (v, t) in opciones)
          DropdownMenuItem<T>(value: v, child: Text(t, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: (v) => setState(() {
        alCambiar(v as T);
        _pagina = 0;
      }),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final vista = c.datos.vista(c.libroId);
    final ocultos = ref.watch(montosOcultosProvider);
    final lista = _filtrados(vista);
    final paginas = (lista.length / porPagina).ceil().clamp(1, 1 << 20);
    final pagina = _pagina.clamp(0, paginas - 1);
    final visibles = lista.skip(pagina * porPagina).take(porPagina).toList();
    final seleccionado = lista.where((m) => m.id == _seleccionado).firstOrNull;
    final cuentas = [
      for (final x in vista.cuentas)
        if (x.clase == ClaseCuenta.activo || x.clase == ClaseCuenta.pasivo) x,
    ];
    final tabla = ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _filtro<_Rango>('Fecha', _rango, const [
              (_Rango.todo, 'Todas'),
              (_Rango.semana, 'Esta semana'),
              (_Rango.semanaPasada, 'Semana pasada'),
              (_Rango.mes, 'Este mes'),
            ], (v) => _rango = v),
            _filtro<String?>('Cuenta', _cuenta, [
              (null, 'Todas'),
              for (final x in cuentas) (x.id, x.nombre),
            ], (v) => _cuenta = v),
            _filtro<String?>('Categoría', _categoria, [
              (null, 'Todas'),
              for (final x in c.datos.arbol.hijas(null)) (x.id, x.nombre),
            ], (v) => _categoria = v),
            _filtro<TipoMovimiento?>('Tipo', _tipo, [
              (null, 'Todos'),
              for (final t in TipoMovimiento.values) (t, nombreTipoMovimiento(t)),
            ], (v) => _tipo = v),
            _filtro<_Estado>('Estado', _estado, const [
              (_Estado.todos, 'Todos'),
              (_Estado.vigentes, 'Vigentes'),
              (_Estado.anulados, 'Anulados'),
            ], (v) => _estado = v),
          ],
        ),
        const SizedBox(height: 16),
        TablaDensa(
          key: const ValueKey('movimientos-tabla'),
          anchoMinimo: 720,
          etiquetaSemantica: 'Movimientos',
          vacio: const Text('No hay movimientos con estos filtros.'),
          columnas: const [
            ColumnaTabla('Fecha'),
            ColumnaTabla('Concepto', flex: 4),
            ColumnaTabla('Tipo', flex: 2),
            ColumnaTabla('Monto', numerica: true, flex: 2),
            ColumnaTabla('Estado', flex: 2),
          ],
          filas: [
            for (final m in visibles)
              FilaTabla(
                seleccionada: m.id == _seleccionado,
                etiquetaSemantica: conceptoDe(m, c.datos, vista),
                alTocar: () => setState(() => _seleccionado = m.id),
                celdas: [
                  CeldaTexto(textoDiaMes(m.fecha)),
                  CeldaTexto(conceptoDe(m, c.datos, vista)),
                  CeldaTexto(nombreTipoMovimiento(m.tipo)),
                  CeldaMonto(efectoEnLibro(m, vista), oculto: ocultos, mostrarSigno: true),
                  CeldaTexto(
                    vista.estaAnulado(m.id)
                        ? 'Anulado'
                        : c.carga.movimientosEnCola.contains(m.id)
                        ? 'Por subir'
                        : 'Vigente',
                    tenue: vista.estaAnulado(m.id),
                  ),
                ],
              ),
          ],
        ),
        if (paginas > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Página ${pagina + 1} de $paginas (${lista.length})'),
              IconButton(
                tooltip: 'Anterior',
                onPressed: pagina == 0 ? null : () => setState(() => _pagina = pagina - 1),
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: 'Siguiente',
                onPressed: pagina >= paginas - 1
                    ? null
                    : () => setState(() => _pagina = pagina + 1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
      ],
    );
    if (seleccionado == null) return tabla;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: tabla),
        const VerticalDivider(width: 1),
        SizedBox(
          width: 360,
          child: _Detalle(
            movimiento: seleccionado,
            contexto: c,
            alCerrar: () => setState(() => _seleccionado = null),
          ),
        ),
      ],
    );
  }
}

class _Detalle extends ConsumerWidget {
  const _Detalle({
    required this.movimiento,
    required this.contexto,
    required this.alCerrar,
  });

  final Movimiento movimiento;
  final ContextoFinanzas contexto;
  final VoidCallback alCerrar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = movimiento;
    final c = contexto;
    final vista = c.datos.vista(c.libroId);
    final contra = vista.contraasientoDe(m.id);
    final original = m.anulaA == null
        ? null
        : c.datos.movimientos.where((x) => x.id == m.anulaA).firstOrNull;
    Widget dato(String etiqueta, String valor) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [EtiquetaPanel(etiqueta), Text(valor)],
      ),
    );
    return ListView(
      key: const ValueKey('movimientos-detalle'),
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                nombreTipoMovimiento(m.tipo),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Cerrar detalle',
              onPressed: alCerrar,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        Monto(efectoEnLibro(m, vista), signo: true),
        dato('Fecha económica', textoFecha(m.fecha)),
        dato('Registrado', '${fechaYHora(m.registradoEn)} por ${c.carga.nombreDe(m.registradoPor)}'),
        if (m.enNombreDe != null) dato('En nombre de', c.carga.nombreDe(m.enNombreDe)),
        dato('De', vista.cuenta(m.cuentaOrigenId).nombre),
        dato('A', vista.cuenta(m.cuentaDestinoId).nombre),
        if (m.categoriaId != null) dato('Categoría', c.datos.arbol.ruta(m.categoriaId!)),
        if (m.nota != null) dato('Nota', m.nota!),
        if (m.motivo != null) dato('Motivo', m.motivo!),
        if (m.grupoId != null) dato('Ticket dividido', 'Es una línea de un ticket con varios rubros'),
        if (original != null) dato('Anula a', conceptoDe(original, c.datos, vista)),
        if (contra != null)
          dato('Contraasiento', '${textoFecha(contra.fecha)} · ${contra.motivo ?? ''}'),
        const SizedBox(height: 12),
        if (sePuedeAnular(m, vista, c))
          OutlinedButton.icon(
            key: const ValueKey('movimientos-anular'),
            onPressed: () => anularConMotivo(context, ref, m),
            icon: const Icon(Icons.block),
            label: const Text('Anular…'),
          ),
        const SizedBox(height: 8),
        const Text(
          'Los movimientos no se editan ni se borran: se corrigen con una '
          'anulación (contraasiento) y quedan en la bitácora.',
        ),
      ],
    );
  }
}
