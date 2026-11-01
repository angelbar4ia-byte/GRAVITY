/// Panel de hábito a eliminar (G.10.3): configurar, registrar en un toque con
/// Deshacer, fase, rachas y semáforo. Detrás de la puerta reservada.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habitos_dominio/habitos_dominio.dart' as dom;

import '../../../app/sensibles/puerta_reservada.dart';
import '../../../diseno/diseno.dart' as dis;
import '../../../nucleo/contratos/roles.dart';
import '../../../nucleo/contratos/rutas.dart';
import '../casos_uso/servicio_eliminar.dart';
import '../estado/proveedores.dart';

String nombreHabito(TipoHabito t) => t == TipoHabito.cigarrillo ? 'Cigarrillo' : 'Azúcar';

class PantallaHabitoEliminar extends ConsumerWidget {
  const PantallaHabitoEliminar({super.key, required this.tipo});
  final TipoHabito tipo;

  @override
  Widget build(BuildContext context, WidgetRef ref) => dis.TemaModulo(
        modulo: Modulo.habitos,
        submodulo: dis.Submodulo.habitosEliminar,
        child: PuertaReservada(
          child: Scaffold(
            appBar: AppBar(
              title: Text(nombreHabito(tipo)),
              leading: BackButton(onPressed: () => context.go(Rutas.habitos)),
            ),
            body: ref.watch(estadoEliminarProvider(tipo)).when(
                  loading: () => const dis.EstadoCargando(),
                  error: (_, _) => dis.EstadoError(
                    mensaje: 'No pudimos abrir esto.',
                    alReintentar: () => ref.invalidate(estadoEliminarProvider(tipo)),
                  ),
                  data: (e) => e == null ? _Configurar(tipo: tipo) : _Panel(tipo: tipo, e: e),
                ),
          ),
        ),
      );
}

class _Panel extends ConsumerWidget {
  const _Panel({required this.tipo, required this.e});
  final TipoHabito tipo;
  final EstadoHabito e;

  Future<void> _registrar(BuildContext context, WidgetRef ref, {String? categoria}) async {
    final s = ref.read(servicioEliminarProvider)!;
    final id = await s.registrarConsumo(tipo, categoria: categoria);
    ref.read(versionHabitosProvider.notifier).state++;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: const Text('Anotado'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () async {
            await s.deshacerConsumo(id);
            ref.read(versionHabitosProvider.notifier).state++;
          },
        ),
      ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fase = dis.FaseHabito.values.byName(e.fase.name);
    final enLinea = e.fase == dom.FaseHabito.lineaBase;
    final texto = enLinea
        ? 'Solo observamos'
        : e.limite != null
            ? 'Hoy: ${e.hoy} de ${e.limite}'
            : 'Hoy: ${e.hoy}';
    return ListView(padding: const EdgeInsets.all(16), children: [
      dis.PanelHabitoEliminar(
        nombre: nombreHabito(tipo),
        fase: fase,
        estadoHoyTexto: texto,
        preguntaSuave: e.superoLimite ? dom.MensajesHabitos.superoLimite : null,
        rachaActual: e.racha?.actual,
        mejorRacha: e.racha?.mejor,
        diasLibresAcumulados: e.racha?.acumulados,
        diasParaDiaD: e.diasParaDiaD,
        semaforo: tipo == TipoHabito.azucar && e.semaforo != null && e.limite != null
            ? dis.SemaforoRefresco(
                usadas: e.usadasPeriodo, limite: e.limite!, periodo: 'este periodo')
            : null,
        alRegistrar: () => _registrar(context, ref,
            categoria: tipo == TipoHabito.azucar ? 'refresco' : null),
        alAntojo: () => context.go('${Rutas.habitos}/sos'),
      ),
      if (e.recaidaHoy) ...[
        const SizedBox(height: 12),
        Text(dom.MensajesHabitos.recaida, style: Theme.of(context).textTheme.titleMedium),
        Text(dom.MensajesHabitos.recaidaAjuste),
      ],
      if (e.sugerirApoyo) ...[
        const SizedBox(height: 12),
        Text(dom.MensajesHabitos.apoyoProfesional),
      ],
      if (e.enFoco) const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text('Modo foco: solo lo esencial por unos días.'),
      ),
      if (e.ahorroCentavos != null) Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text('Ahorro: \$${(e.ahorroCentavos! / 100).toStringAsFixed(2)}'),
      ),
      const SizedBox(height: 12),
      if (enLinea)
        OutlinedButton(
          onPressed: () async {
            await ref.read(servicioEliminarProvider)!.cerrarDia(tipo);
            ref.read(versionHabitosProvider.notifier).state++;
          },
          child: const Text('Cero hoy'),
        ),
    ]);
  }
}

class _Configurar extends ConsumerStatefulWidget {
  const _Configurar({required this.tipo});
  final TipoHabito tipo;
  @override
  ConsumerState<_Configurar> createState() => _ConfigurarEstado();
}

class _ConfigurarEstado extends ConsumerState<_Configurar> {
  late DateTime inicio = dom.soloDia(DateTime.now());
  final limite = TextEditingController();
  bool semana = false;

  @override
  void dispose() {
    limite.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final azucar = widget.tipo == TipoHabito.azucar;
    final lim = int.tryParse(limite.text);
    if (azucar && lim == null) return;
    await ref.read(servicioEliminarProvider)!.configurar(ConfigHabito(
        tipo: widget.tipo, inicio: inicio, limiteOcasional: lim, periodoSemana: semana));
    ref.read(versionHabitosProvider.notifier).state++;
  }

  @override
  Widget build(BuildContext context) {
    final azucar = widget.tipo == TipoHabito.azucar;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text(azucar
          ? 'Empezamos observando una semana y luego pones tu regla.'
          : 'Empezamos con 7 días de observación, sin metas.'),
      const SizedBox(height: 12),
      ListTile(
        title: const Text('Fecha de inicio'),
        subtitle: Text('${inicio.day}/${inicio.month}/${inicio.year}'),
        onTap: () async {
          final f = await showDatePicker(
              context: context,
              initialDate: inicio,
              firstDate: DateTime(2026),
              lastDate: DateTime(2100));
          if (f != null) setState(() => inicio = dom.soloDia(f));
        },
      ),
      if (azucar) ...[
        TextField(
          controller: limite,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '¿Cuántos refrescos ocasionales permites?'),
        ),
        SwitchListTile(
            title: const Text('Contar por semana (si no, por mes)'),
            value: semana,
            onChanged: (v) => setState(() => semana = v)),
      ],
      const SizedBox(height: 12),
      FilledButton(onPressed: _guardar, child: const Text('Empezar')),
    ]);
  }
}

/// Entrada a lo reservado: aquí sí aparecen los nombres, detrás de la puerta.
class PantallaReservado extends StatelessWidget {
  const PantallaReservado({super.key});
  @override
  Widget build(BuildContext context) => dis.TemaModulo(
        modulo: Modulo.habitos,
        submodulo: dis.Submodulo.habitosEliminar,
        child: PuertaReservada(
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Reservado'),
              leading: BackButton(onPressed: () => context.go(Rutas.habitos)),
            ),
            body: ListView(children: [
              for (final t in TipoHabito.values)
                ListTile(
                  title: Text(nombreHabito(t)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('${Rutas.habitos}/eliminar/${t.name}'),
                ),
            ]),
          ),
        ),
      );
}
