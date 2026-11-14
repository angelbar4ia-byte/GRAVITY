/// SOS "Pausa / Tengo un antojo" (reglas 58 a 62). Pasos y textos del
/// dominio. El antojo se guarda cifrado en `habitos_sensibles`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habitos_dominio/habitos_dominio.dart';

import '../../../app/sensibles/puerta_reservada.dart';
import '../../../diseno/diseno.dart' as dis;
import '../../../nucleo/contratos/roles.dart';
import '../../../nucleo/contratos/rutas.dart';
import '../casos_uso/servicio_eliminar.dart';
import '../estado/proveedores.dart';

class PantallaPausa extends ConsumerStatefulWidget {
  const PantallaPausa({super.key});
  @override
  ConsumerState<PantallaPausa> createState() => _PantallaPausaEstado();
}

class _PantallaPausaEstado extends ConsumerState<PantallaPausa> {
  final sesion = SesionSos();
  TipoHabito habito = TipoHabito.cigarrillo;
  String? tecnica;
  int intensidad = 3;
  bool guardado = false;
  ConfigHabito? cfg;
  String? disparador;

  /// Al elegir el hábito se leen sus motivos, disparadores y reemplazos
  /// (cifrados, solo en este equipo) para mostrarlos en los pasos siguientes.
  Future<void> _cargarConfig() async {
    try {
      final c = await ref.read(servicioEliminarProvider)?.config(habito);
      if (mounted) setState(() => cfg = c);
    } catch (_) {
      // Sin llave en este equipo: el SOS sigue sin motivos.
    }
  }

  void _ir() {
    final veniaDeElegir = sesion.paso == PasoSos.queEs;
    setState(sesion.avanzar);
    if (veniaDeElegir) _cargarConfig();
  }

  Future<void> _guardar() async {
    if (guardado) return;
    guardado = true;
    try {
      await ref
          .read(servicioEliminarProvider)
          ?.guardarAntojo(
            habito,
            resultado: sesion.resultado ?? ResultadoAntojo.superado,
            tecnica: tecnica,
            intensidad: intensidad,
            disparador: disparador,
          );
    } catch (_) {
      // Sin llave en este equipo: el SOS igual cumplió su papel.
    }
  }

  @override
  Widget build(BuildContext context) {
    final cuerpo = switch (sesion.paso) {
      PasoSos.pausa => _Paso(
        TextosSos.pausa,
        const dis.RespiracionGuiada(),
        'Seguir',
        _ir,
      ),
      PasoSos.queEs => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(TextosSos.queEs, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final t in TipoHabito.values)
            ListTile(
              title: Text(nombreHabitoSos(t)),
              selected: habito == t,
              trailing: habito == t ? const Icon(Icons.check) : null,
              onTap: () => setState(() => habito = t),
            ),
          FilledButton(onPressed: _ir, child: const Text('Seguir')),
        ],
      ),
      PasoSos.tecnica => _Tecnicas(
        motivos: cfg?.motivos ?? const [],
        reemplazos: cfg?.reemplazos ?? const [],
        elegida: tecnica,
        alElegir: (t) => setState(() => tecnica = t),
        alSeguir: _ir,
      ),
      PasoSos.temporizador => Column(
        children: [
          Text(TextosSos.temporizador),
          _Motivos(motivos: cfg?.motivos ?? const []),
          dis.TemporizadorSos(
            duracion: Duration(minutes: sesion.minutos),
            alSigue: () => setState(() => sesion.terminarTiempo(sigue: true)),
            alYaPaso: () => setState(() => sesion.terminarTiempo(sigue: false)),
          ),
          TextButton(
            onPressed: () => setState(sesion.registrarConsumo),
            child: const Text('Terminé consumiendo'),
          ),
        ],
      ),
      PasoSos.registro => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            TextosSos.registro,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (cfg != null && cfg!.disparadores.isNotEmpty) ...[
            const Text('¿Qué lo disparó?'),
            Wrap(
              spacing: 8,
              children: [
                for (final d in cfg!.disparadores)
                  ChoiceChip(
                    label: Text(d),
                    selected: disparador == d,
                    onSelected: (v) =>
                        setState(() => disparador = v ? d : null),
                  ),
              ],
            ),
          ],
          Slider(
            value: intensidad.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            label: '$intensidad',
            onChanged: (v) => setState(() => intensidad = v.round()),
          ),
          FilledButton(onPressed: _ir, child: const Text('Cerrar')),
        ],
      ),
      PasoSos.cierre => _Paso(
        sesion.resultado == ResultadoAntojo.superado
            ? TextosSos.cierreSuperado
            : TextosSos.cierreConsumo,
        const SizedBox.shrink(),
        'Listo',
        () async {
          await _guardar();
          if (context.mounted) context.go(Rutas.habitos);
        },
      ),
    };
    return dis.TemaModulo(
      modulo: Modulo.habitos,
      submodulo: dis.Submodulo.habitosEliminar,
      child: PuertaReservada(
        child: Scaffold(
          appBar: AppBar(title: const Text('Pausa')),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Center(child: SingleChildScrollView(child: cuerpo)),
          ),
        ),
      ),
    );
  }
}

String nombreHabitoSos(TipoHabito t) =>
    t == TipoHabito.cigarrillo ? 'Cigarrillo' : 'Azúcar';

class _Paso extends StatelessWidget {
  const _Paso(this.texto, this.extra, this.boton, this.alTocar);
  final String texto;
  final Widget extra;
  final String boton;
  final VoidCallback alTocar;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        texto,
        style: Theme.of(context).textTheme.titleLarge,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 16),
      extra,
      const SizedBox(height: 16),
      FilledButton(onPressed: alTocar, child: Text(boton)),
    ],
  );
}

/// Los motivos de la persona, en sus palabras (hasta 3), sin juicio.
class _Motivos extends StatelessWidget {
  const _Motivos({required this.motivos});
  final List<String> motivos;
  @override
  Widget build(BuildContext context) => motivos.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Semantics(
            container: true,
            label: 'Tus motivos',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Recuerda por qué',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                for (final m in motivos.take(3))
                  Text(m, textAlign: TextAlign.center),
              ],
            ),
          ),
        );
}

class _Tecnicas extends StatelessWidget {
  const _Tecnicas({
    required this.motivos,
    required this.reemplazos,
    required this.elegida,
    required this.alElegir,
    required this.alSeguir,
  });
  final List<String> motivos;
  final List<String> reemplazos;
  final String? elegida;
  final ValueChanged<String> alElegir;
  final VoidCallback alSeguir;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(TextosSos.tecnica, style: Theme.of(context).textTheme.titleLarge),
      _Motivos(motivos: motivos),
      for (final r in reemplazos.take(3))
        ListTile(
          title: Text(r),
          subtitle: const Text('Mi reemplazo'),
          selected: elegida == 'reemplazo',
          onTap: () => alElegir('reemplazo'),
        ),
      for (final t in ordenarTecnicas(const []))
        ListTile(
          title: Text(tecnicasSos[t]!),
          selected: elegida == t,
          onTap: () => alElegir(t),
        ),
      FilledButton(
        onPressed: elegida == null ? null : alSeguir,
        child: const Text('Empezar'),
      ),
    ],
  );
}
