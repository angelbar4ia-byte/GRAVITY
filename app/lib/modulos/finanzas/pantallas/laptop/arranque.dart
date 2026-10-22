/// Asistente de arranque (5 pasos, unos 5 minutos; 5.6 bis punto 9): libro y
/// cuentas → ingresos → compromisos y deudas → meta → sobres hasta el techo,
/// con el resumen de la cascada y *Activar semana*. Lo omitido no bloquea.
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide Semaforo, formatearCentavos, TipoLibro, puntosBaseEnCien;
import 'package:finanzas_dominio/finanzas_dominio.dart' as dom show TipoLibro;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../diseno/diseno.dart';
import '../../estado/proveedores.dart';
import '../comunes.dart';
import 'cuentas.dart';
import 'dialogos_config.dart';
import 'marco_laptop.dart';

class PantallaArranque extends StatelessWidget {
  const PantallaArranque({super.key});

  @override
  Widget build(BuildContext context) => MarcoFinanzasLaptop(
    seccion: SeccionFinanzas.arranque,
    builder: (context, c) => c.puedeAdministrar
        ? _Asistente(contexto: c)
        : const EstadoVacio(
            icono: Icons.lock_outline,
            mensaje: 'Solo quien lleva este libro lo configura.',
          ),
  );
}

class _Asistente extends ConsumerStatefulWidget {
  const _Asistente({required this.contexto});

  final ContextoFinanzas contexto;

  @override
  ConsumerState<_Asistente> createState() => _AsistenteState();
}

class _AsistenteState extends ConsumerState<_Asistente> {
  int _paso = 0;
  final _meta = TextEditingController();
  final _ahorro = TextEditingController();
  final _montos = <String, TextEditingController>{};

  @override
  void dispose() {
    _meta.dispose();
    _ahorro.dispose();
    for (final c in _montos.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _lista(List<String> renglones, String vacio) => renglones.isEmpty
      ? Text(vacio)
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final r in renglones) Text('• $r')],
        );

  Widget _boton(String texto, Widget Function() dialogo, {Key? key}) => OutlinedButton.icon(
    key: key,
    onPressed: () => showDialog<void>(context: context, builder: (_) => dialogo()),
    icon: const Icon(Icons.add),
    label: Text(texto),
  );

  @override
  Widget build(BuildContext context) {
    final c = widget.contexto;
    final d = c.datos;
    final semana = Semana.de(c.hoy);
    final plan = armarPlanDelLibro(d, c.libroId, semana).plan;
    final parametros = d.parametrosDe(c.libroId);
    if (_meta.text.isEmpty) {
      _meta.text = CampoPorcentaje.texto(parametros.metaRemanentePuntosBase);
      _ahorro.text = CampoPorcentaje.texto(parametros.ahorroMinimoConDeudaPuntosBase);
    }
    final ocultos = ref.watch(montosOcultosProvider);
    final servicio = ref.read(servicioFinanzasProvider);
    final fijos = plan.partidas
        .where((r) => r.origen.tipo != TipoPartida.variable)
        .fold(0, (t, r) => t + r.semanal);
    final paraSobres = plan.techo - fijos;
    final sobres = d.sobresDe(c.libroId);
    final yaActiva = d.semanaGuardada(c.libroId, semana) != null;

    final pasos = <(String, Widget)>[
      (
        'Libro y cuentas',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${opcionDe(c.libro!, c.permiso, c.personaId).etiqueta} · '
              '${nombreTipoLibro(c.libro!.tipo)} · '
              'lo llevan: ${c.libro!.vigentes(c.hoy).map((m) => c.carga.nombreDe(m.personaId)).join(', ')}. '
              'La semana empieza en lunes.',
            ),
            const SizedBox(height: 8),
            _lista(
              [
                for (final x in d.cuentasDe(c.libroId))
                  if (x.clase == ClaseCuenta.activo || x.clase == ClaseCuenta.pasivo)
                    '${x.nombre} (${nombreTipoCuenta(x.tipo)})',
              ],
              'Aún no hay cuentas: agrega tu efectivo, tu banco y tus tarjetas con '
              'su saldo de hoy.',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _boton(
                  'Agregar cuenta',
                  () => DialogoCuenta(contexto: c),
                  key: const ValueKey('arranque-cuenta'),
                ),
                if (d.categorias.isEmpty && c.administraHogar)
                  TextButton(
                    key: const ValueKey('arranque-importar'),
                    onPressed: () => context.go(SeccionFinanzas.importar.ruta),
                    child: const Text('Importar las categorías de la plantilla'),
                  ),
                TextButton(
                  key: const ValueKey('arranque-libros'),
                  onPressed: () => context.go(SeccionFinanzas.ajustes.ruta),
                  child: const Text('Libros compartidos y de papá (albaceas)'),
                ),
              ],
            ),
          ],
        ),
      ),
      (
        'Ingresos',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _lista(
              [
                for (final i in d.ingresosDe(c.libroId))
                  if (i.vigenciaActual != null)
                    '${i.nombre}: ${descripcionCalendario(i.vigenciaActual!.calendario)}',
              ],
              'Agrega cada ingreso con su forma (semanal, catorcenal, '
              'quincenal, mensual o cada N meses), su día y su neto.',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _boton(
                  'Agregar ingreso',
                  () => DialogoIngreso(contexto: c),
                  key: const ValueKey('arranque-ingreso'),
                ),
                // Libro de papá (P15): la forma ya va; montos y fechas, no.
                if (c.libro!.tipo == dom.TipoLibro.representado)
                  for (final p in PlantillaIngreso.deRepresentado)
                    _boton(
                      p.nombre,
                      () => DialogoIngreso(contexto: c, plantilla: p),
                      key: ValueKey('arranque-plantilla-${p.nombre}'),
                    ),
              ],
            ),
          ],
        ),
      ),
      (
        'Compromisos y deudas',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _lista(
              [
                for (final x in d.compromisosDe(c.libroId)) x.nombre,
                for (final x in d.deudasDe(c.libroId)) '${x.nombre} (deuda)',
              ],
              'Renta, servicios, reservas (placas, predial) y deudas con su abono.',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _boton('Agregar compromiso', () => DialogoCompromiso(contexto: c)),
                _boton('Agregar deuda', () => DialogoDeuda(contexto: c)),
              ],
            ),
          ],
        ),
      ),
      (
        'Meta',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Meta de remanente: lo que quieres que quede después del '
              'presupuesto y la deuda. La regla: primero pagar deuda, '
              'después ahorrar. Las deudas reciben el extra por costo, o en '
              'el orden de tu grupo prioritario (Compromisos y deudas).',
            ),
            Row(
              children: [
                Expanded(
                  child: CampoPorcentaje(
                    key: const ValueKey('arranque-meta'),
                    controlador: _meta,
                    etiqueta: 'Meta de remanente',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CampoPorcentaje(
                    controlador: _ahorro,
                    etiqueta: 'Ahorro mínimo con deuda (del remanente)',
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  key: const ValueKey('arranque-guardar-meta'),
                  onPressed: () {
                    final meta = CampoPorcentaje.puntosBase(_meta.text);
                    final ahorro = CampoPorcentaje.puntosBase(_ahorro.text);
                    if (meta == null || ahorro == null) {
                      avisar(context, 'Escribe porcentajes de 0 a 100.');
                      return;
                    }
                    intentar(
                      context,
                      () => servicio.guardarParametros(
                        parametros.copiar(
                          metaRemanentePuntosBase: meta,
                          ahorroMinimoConDeudaPuntosBase: ahorro,
                        ),
                      ),
                    );
                  },
                  child: const Text('Guardar meta'),
                ),
              ],
            ),
          ],
        ),
      ),
      (
        'Sobres hasta el techo',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Techo de presupuesto: '),
                Monto(plan.techo),
                const Text('  ·  para sobres: '),
                Monto(paraSobres),
              ],
            ),
            const SizedBox(height: 8),
            for (final s in sobres)
              Row(
                children: [
                  Expanded(child: Text(s.nombre)),
                  SizedBox(
                    width: 160,
                    child: CampoMonto(
                      key: ValueKey('arranque-sobre-${s.id}'),
                      controlador: _montos.putIfAbsent(
                        s.id,
                        () => TextEditingController(text: textoDeCentavos(s.montoSemanal)),
                      ),
                      etiqueta: 'Por semana',
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _boton('Agregar sobre', () => DialogoSobre(contexto: c)),
                if (sobres.isNotEmpty && paraSobres > 0)
                  OutlinedButton(
                    key: const ValueKey('arranque-sugerir'),
                    onPressed: () {
                      // Reparte lo que queda para sobres en proporción a lo
                      // escrito (o en partes iguales): el usuario ajusta.
                      final actuales = [
                        for (final s in sobres)
                          centavosDeTexto(_montos[s.id]?.text ?? '') ?? s.montoSemanal,
                      ];
                      final total = actuales.fold(0, (t, x) => t + x);
                      final pesos = total == 0
                          ? List.filled(sobres.length, 1)
                          : actuales;
                      final partes = repartirConMayorResto(
                        [for (final p in pesos) p * paraSobres],
                        pesos.fold(0, (t, x) => t + x),
                      );
                      setState(() {
                        for (var i = 0; i < sobres.length; i++) {
                          _montos[sobres[i].id]!.text = textoDeCentavos(partes[i]);
                        }
                      });
                    },
                    child: const Text('Sugerir hasta el techo'),
                  ),
                if (sobres.isNotEmpty)
                  FilledButton(
                    key: const ValueKey('arranque-guardar-sobres'),
                    onPressed: () => intentar(context, () async {
                      for (final s in sobres) {
                        final monto = centavosDeTexto(_montos[s.id]?.text ?? '');
                        if (monto != null && monto != s.montoSemanal) {
                          await servicio.guardarSobre(s.conMonto(monto));
                        }
                      }
                    }),
                    child: const Text('Guardar sobres'),
                  ),
              ],
            ),
          ],
        ),
      ),
    ];

    return ContenidoLaptop(
      children: [
        Stepper(
          key: const ValueKey('arranque-pasos'),
          physics: const NeverScrollableScrollPhysics(),
          currentStep: _paso,
          onStepTapped: (i) => setState(() => _paso = i),
          onStepContinue: _paso < pasos.length - 1 ? () => setState(() => _paso++) : null,
          onStepCancel: _paso > 0 ? () => setState(() => _paso--) : null,
          controlsBuilder: (context, detalles) => Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                if (detalles.onStepContinue != null)
                  FilledButton(
                    key: const ValueKey('arranque-siguiente'),
                    onPressed: detalles.onStepContinue,
                    child: const Text('Siguiente'),
                  ),
                const SizedBox(width: 8),
                if (detalles.onStepCancel != null)
                  TextButton(onPressed: detalles.onStepCancel, child: const Text('Atrás')),
                const SizedBox(width: 8),
                if (detalles.onStepContinue != null)
                  TextButton(
                    onPressed: detalles.onStepContinue,
                    child: const Text('Omitir por ahora'),
                  ),
              ],
            ),
          ),
          steps: [
            for (var i = 0; i < pasos.length; i++)
              Step(
                title: Text('${i + 1}. ${pasos[i].$1}'),
                content: pasos[i].$2,
                isActive: i == _paso,
                state: i < _paso ? StepState.complete : StepState.indexed,
              ),
          ],
        ),
        TarjetaModulo(
          key: const ValueKey('arranque-resumen'),
          titulo: 'Resumen: ${textoSemana(semana)}',
          icono: Icons.waterfall_chart,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GadgetCascada(
                montosOcultos: ocultos,
                escalones: [
                  EscalonCascada(etiqueta: 'Ingreso', planeadoCentavos: plan.ingreso),
                  EscalonCascada(etiqueta: '− Presupuesto', planeadoCentavos: plan.presupuesto),
                  EscalonCascada(etiqueta: '− Deuda', planeadoCentavos: plan.deudaPlaneada),
                  EscalonCascada(
                    etiqueta: '= Remanente',
                    planeadoCentavos: plan.remanente,
                    tono: tonoDe(plan.semaforoDelRemanente),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    'Remanente ${formatearPuntosBase(plan.tasaRemanentePuntosBase)} '
                    '(meta ${formatearPuntosBase(plan.parametros.metaRemanentePuntosBase, decimales: 0)}) · techo ',
                  ),
                  Monto(plan.techo),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: yaActiva
                    ? const Text('La semana ya está activada.')
                    : FilledButton.icon(
                        key: const ValueKey('arranque-activar'),
                        onPressed: plan.ingreso == 0 && plan.partidas.isEmpty
                            ? null
                            : () async {
                                if (await intentar(
                                      context,
                                      () => servicio.activarSemana(c.libroId, semana),
                                    ) &&
                                    context.mounted) {
                                  context.go(SeccionFinanzas.semana.ruta);
                                }
                              },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Activar semana'),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
