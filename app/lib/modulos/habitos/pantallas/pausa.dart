/// SOS "Pausa / Tengo un antojo" (reglas 58 a 62). Los pasos y textos salen
/// del dominio. El registro del antojo se guarda en el documento cifrado de
/// `habitos_sensibles` (pendiente: almacén de documentos, ver reporte).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:habitos_dominio/habitos_dominio.dart';

import '../../../diseno/diseno.dart';
import '../../../nucleo/contratos/roles.dart';
import '../../../nucleo/contratos/rutas.dart';

class PantallaPausa extends StatefulWidget {
  const PantallaPausa({super.key});
  @override
  State<PantallaPausa> createState() => _PantallaPausaEstado();
}

class _PantallaPausaEstado extends State<PantallaPausa> {
  final sesion = SesionSos();
  String? tecnica;

  void _ir() => setState(sesion.avanzar);

  @override
  Widget build(BuildContext context) {
    final cuerpo = switch (sesion.paso) {
      PasoSos.pausa => _Paso(TextosSos.pausa, const RespiracionGuiada(), 'Seguir', _ir),
      PasoSos.queEs => _Paso(TextosSos.queEs, const SizedBox.shrink(), 'Seguir', _ir),
      PasoSos.tecnica => _Tecnicas(
          elegida: tecnica,
          alElegir: (t) => setState(() => tecnica = t),
          alSeguir: _ir),
      PasoSos.temporizador => Column(children: [
          Text(TextosSos.temporizador),
          TemporizadorSos(
            duracion: Duration(minutes: sesion.minutos),
            alSigue: () => setState(() => sesion.terminarTiempo(sigue: true)),
            alYaPaso: () => setState(() => sesion.terminarTiempo(sigue: false)),
          ),
        ]),
      PasoSos.registro => _Paso(TextosSos.registro, const SizedBox.shrink(), 'Cerrar', _ir),
      PasoSos.cierre => _Paso(
          sesion.resultado == ResultadoAntojo.superado
              ? TextosSos.cierreSuperado
              : TextosSos.cierreConsumo,
          const SizedBox.shrink(),
          'Listo',
          () => context.go(Rutas.habitos)),
    };
    return TemaModulo(
      modulo: Modulo.habitos,
      child: Scaffold(
        appBar: AppBar(title: const Text('Pausa')),
        body: Padding(padding: const EdgeInsets.all(20), child: Center(child: cuerpo)),
      ),
    );
  }
}

class _Paso extends StatelessWidget {
  const _Paso(this.texto, this.extra, this.boton, this.alTocar);
  final String texto;
  final Widget extra;
  final String boton;
  final VoidCallback alTocar;
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Text(texto, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        extra,
        const SizedBox(height: 16),
        FilledButton(onPressed: alTocar, child: Text(boton)),
      ]);
}

class _Tecnicas extends StatelessWidget {
  const _Tecnicas({required this.elegida, required this.alElegir, required this.alSeguir});
  final String? elegida;
  final ValueChanged<String> alElegir;
  final VoidCallback alSeguir;
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Text(TextosSos.tecnica, style: Theme.of(context).textTheme.titleLarge),
        for (final t in ordenarTecnicas(const []))
          ListTile(
            title: Text(tecnicasSos[t]!),
            selected: elegida == t,
            onTap: () => alElegir(t),
          ),
        FilledButton(onPressed: elegida == null ? null : alSeguir, child: const Text('Empezar')),
      ]);
}
