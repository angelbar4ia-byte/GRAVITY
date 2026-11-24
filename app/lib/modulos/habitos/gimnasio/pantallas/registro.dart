/// E6 · Registro rápido («Registrar lo que hice»): para anotar después una
/// sesión que no se llevó en la app (7.1, F-E3).
///
/// Con *Todo como estaba planeado* son tres toques: abrir esta pantalla, esa
/// opción y *Guardar* (CA-G-33). Lo que fue distinto se ajusta con − y +.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habitos_dominio/habitos_dominio.dart' hide EstadoDiaPlan;

import '../../../../app/gimnasio/acceso_gimnasio.dart';
import '../../../../diseno/componentes/tarjeta_modulo.dart';
import '../../../../diseno/gimnasio/gimnasio.dart';
import '../../../../diseno/valores_diseno.dart';
import '../../estado/proveedores.dart' show versionHabitosProvider;
import '../casos_uso/servicio_gimnasio.dart';
import '../datos/conversion_gimnasio.dart';
import '../datos/modelos_gimnasio.dart';
import '../estado/proveedores_gimnasio.dart';
import 'comun.dart';

class _FilaRegistro {
  _FilaRegistro(this.ejercicio, this.series, this.reps, this.carga);

  final EjercicioPlanificado ejercicio;
  int series;
  int reps;
  int? carga;
}

class PantallaRegistro extends ConsumerStatefulWidget {
  const PantallaRegistro({super.key});

  @override
  ConsumerState<PantallaRegistro> createState() => _EstadoRegistro();
}

class _EstadoRegistro extends ConsumerState<PantallaRegistro> {
  DateTime? _fecha;
  String? _plantilla;
  bool _arrancado = false;
  bool _planeado = false;
  bool _parte = false;
  int? _esfuerzo;
  int? _energia;
  List<_FilaRegistro> _filas = [];
  EntrenamientoHoy? _h;
  bool _guardando = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_arrancado) return;
    _arrancado = true;
    try {
      final q = GoRouterState.of(context).uri.queryParameters;
      _fecha = q['fecha'] == null ? null : fechaDeIso(q['fecha']!);
      _plantilla = q['tipo'];
    } catch (_) {
      // Sin router: hoy y la plantilla del plan.
    }
  }

  Future<void> _cargar(ServicioGimnasio s, DateTime fecha) async {
    final h = await s.entrenamientoDe(fecha, tipo: _plantilla);
    if (!mounted) return;
    setState(() {
      _h = h;
      _filas = [
        if (h.sesion != null)
          for (final e in h.sesion!.ejercicios)
            _FilaRegistro(e, e.series, e.objetivo, e.cargaPasos),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final servicio = ref.watch(servicioGimnasioProvider);
    return MarcoGimnasio(
      destino: DestinoGimnasio.registro,
      sport: true,
      cuerpo: servicio == null
          ? const SinPersonaGimnasio()
          : _cuerpo(context, servicio),
    );
  }

  Widget _cuerpo(BuildContext context, ServicioGimnasio s) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final hoy = ref.watch(fechaDeHoyGimnasioProvider);
    final fecha = _fecha ?? hoy;
    final h = _h;
    final dato = ref.watch(datosGimnasioProvider).value;
    final inv = dato?.inventario ?? Inventario.inicial();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Fuerza o regenerativa de ${nombreDeDia(fecha.weekday)} '
          '${fecha.day}/${fecha.month}',
          style: v.lectura(tamano: 15, color: v.textoTenue),
        ),
        SizedBox(height: e),
        Wrap(
          spacing: e,
          children: [
            for (final t in const ['A', 'B', 'C'])
              ChoiceChip(
                key: ValueKey('registro-$t'),
                label: Text('Fuerza $t'),
                selected: (_plantilla ?? dato?.dia(fecha.weekday).tipo) == t,
                onSelected: (_) => setState(() {
                  _plantilla = t;
                  _h = null;
                  _planeado = false;
                }),
              ),
            ActionChip(
              avatar: const Icon(Icons.calendar_today, size: 18),
              label: const Text('Cambiar el día'),
              onPressed: () async {
                final r = await showDatePicker(
                  context: context,
                  initialDate: fecha.isAfter(hoy) ? hoy : fecha,
                  firstDate: hoy.subtract(const Duration(days: 60)),
                  lastDate: hoy,
                );
                if (r == null) return;
                setState(() {
                  _fecha = soloDia(r);
                  _h = null;
                  _planeado = false;
                });
              },
            ),
          ],
        ),
        SizedBox(height: e * 2),
        if (!_planeado)
          FilledButton.icon(
            key: const ValueKey('todo-planeado'),
            onPressed: () async {
              await _cargar(s, fecha);
              if (mounted) setState(() => _planeado = true);
            },
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(64),
            ),
            icon: const Icon(Icons.done_all, size: 26),
            label: const Text(TextosHabitosGimnasio.todoComoPlaneado),
          )
        else if (h == null || h.sesion == null)
          const Text(TextosHabitosGimnasio.hoyNoHayPlan)
        else ...[
          for (var i = 0; i < _filas.length; i++) ...[
            _TarjetaFila(
              fila: _filas[i],
              numero: i + 1,
              total: _filas.length,
              catalogo: s.catalogo,
              inventario: inv,
              alCambiar: () => setState(() {}),
            ),
            SizedBox(height: e),
          ],
          TarjetaModulo(
            titulo: 'Cómo te sentiste',
            icono: Icons.speed,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Esfuerzo de la sesión (opcional)'),
                _Cinco(
                  valor: _esfuerzo,
                  alCambiar: (x) => setState(() => _esfuerzo = x),
                ),
                const SizedBox(height: 8),
                const Text('Energía (opcional)'),
                _Cinco(
                  valor: _energia,
                  alCambiar: (x) => setState(() => _energia = x),
                ),
              ],
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Fue solo una parte'),
            value: _parte,
            onChanged: (x) => setState(() => _parte = x),
          ),
          SizedBox(height: e),
          FilledButton(
            key: const ValueKey('registro-guardar'),
            onPressed: _guardando ? null : () => _guardar(s),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: const Text(TextosHabitosGimnasio.guardar),
          ),
        ],
      ],
    );
  }

  Future<void> _guardar(ServicioGimnasio s) async {
    final h = _h;
    if (h == null) return;
    setState(() => _guardando = true);
    bool esBanda(EjercicioPlanificado e) =>
        s.catalogo.variante(e.varianteId)?.carga == TipoCarga.banda;
    final r = await s.registrarDespues(
      h: h,
      hecho: [
        for (final f in _filas)
          (
            ejercicio: f.ejercicio,
            series: f.series,
            reps: f.reps,
            cargaPasos: esBanda(f.ejercicio) ? null : f.carga,
            bandaId: esBanda(f.ejercicio) ? f.ejercicio.bandaId : null,
          ),
      ],
      completa: !_parte,
      esfuerzo: _esfuerzo,
      energia: _energia,
    );
    ref.read(versionGimnasioProvider.notifier).state++;
    ref.read(versionHabitosProvider.notifier).state++;
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            [
              TextosHabitosGimnasio.sesionTerminada,
              for (final x in r.records.take(2))
                MensajesGimnasio.recordPersonal(
                  nombreDeEjercicio(
                    s.catalogo,
                    s.catalogo.ejercicioDeVariante(x.varianteId)?.id ??
                        x.varianteId,
                  ),
                  x.tipo == 'carga' ? 'placa ${x.valor}' : '${x.valor}',
                ),
            ].join(' '),
          ),
        ),
      );
    context.go(RutasGimnasio.hoy);
  }
}

class _Cinco extends StatelessWidget {
  const _Cinco({required this.valor, required this.alCambiar});

  final int? valor;
  final ValueChanged<int?> alCambiar;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    children: [
      for (var i = 1; i <= 5; i++)
        ChoiceChip(
          label: Text('$i'),
          selected: valor == i,
          onSelected: (s) => alCambiar(s ? i : null),
        ),
    ],
  );
}

class _TarjetaFila extends StatelessWidget {
  const _TarjetaFila({
    required this.fila,
    required this.numero,
    required this.total,
    required this.catalogo,
    required this.inventario,
    required this.alCambiar,
  });

  final _FilaRegistro fila;
  final int numero;
  final int total;
  final Catalogo catalogo;
  final Inventario inventario;
  final VoidCallback alCambiar;

  @override
  Widget build(BuildContext context) {
    final e = fila.ejercicio;
    final lleva =
        catalogo.variante(e.varianteId)?.carga == TipoCarga.pila;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilaEjercicioPlan(
          numero: numero,
          total: total,
          datos: EjercicioPlanVista(
            ejercicio: nombreDeEjercicio(catalogo, e.ejercicioId),
            varianteTexto: nombreDeVariante(catalogo, e.varianteId),
            seriesTexto: '${fila.series} × ${fila.reps}'
                '${e.porTiempo ? ' s' : ''}',
            cargaTexto: lleva && fila.carga != null
                ? mostrarCargaPasos(fila.carga!, inventario).texto
                : null,
          ),
        ),
        SelectorPasos(
          etiqueta: e.porTiempo ? 'SEGUNDOS' : 'REPS',
          valorTexto: '${fila.reps}',
          etiquetaMenos: 'Quitar una repetición',
          etiquetaMas: 'Agregar una repetición',
          alMenos: fila.reps > 0
              ? () {
                  fila.reps--;
                  alCambiar();
                }
              : null,
          alMas: () {
            fila.reps++;
            alCambiar();
          },
        ),
        if (lleva)
          SelectorPasos(
            etiqueta: 'PLACA',
            valorTexto: fila.carga == null ? '—' : '${fila.carga}',
            etiquetaMenos: 'Quitar una placa',
            etiquetaMas: 'Poner una placa más',
            alMenos: (fila.carga ?? 0) > 1
                ? () {
                    fila.carga = fila.carga! - 1;
                    alCambiar();
                  }
                : null,
            alMas: (fila.carga ?? 0) < (inventario.pasosMax ?? 60)
                ? () {
                    fila.carga = (fila.carga ?? 0) + 1;
                    alCambiar();
                  }
                : null,
          ),
      ],
    );
  }
}
