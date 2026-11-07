/// Lado del dueño de la vista temporal (D24): tarjeta que avisa de una
/// solicitud para **autorizar 30 minutos** o **rechazar**, y que permite
/// **cancelar** una autorización vigente.
///
/// Los textos salen del catálogo cerrado [textosVistaPapa] (D20): sin montos,
/// sin cuentas y sin nombres. Dentro de la app se ve además el motivo que
/// escribió el familiar (texto de la persona, sin cifras del libro).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/sesion_efectiva.dart';
import '../../../../diseno/diseno.dart' show ValoresDiseno;
import '../../../../diseno/proveedores.dart' show relojProvider;
import '../../../../nucleo/contratos/roles.dart';
import '../../datos/vista_papa.dart';
import '../../estado/proveedores_vista_papa.dart';
import 'vista_temporal_papa.dart' show formatoContador;

/// Catálogo cerrado de textos de esta vista (D20): lo único que se dice del
/// asunto en avisos y tarjetas. Sin dígitos, "\$" ni nombres propios.
const Map<String, String> textosVistaPapa = {
  'solicitud_vista': 'Solicitud de vista: Familiar',
  'vista_autorizada': 'Vista autorizada: Familiar',
};

class TarjetaVistaPapaDueno extends ConsumerStatefulWidget {
  const TarjetaVistaPapaDueno({super.key});

  @override
  ConsumerState<TarjetaVistaPapaDueno> createState() => _EstadoTarjeta();
}

class _EstadoTarjeta extends ConsumerState<TarjetaVistaPapaDueno> {
  Timer? _pulso;
  int _ticks = 0;
  late DateTime _ahora = ref.read(relojProvider).ahora();
  String? _error;

  @override
  void initState() {
    super.initState();
    _pulso = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _ticks++;
      setState(() => _ahora = ref.read(relojProvider).ahora());
      if (_ticks % 5 == 0) {
        ref.read(solicitudesVistaPapaProvider.notifier).refrescar();
      }
    });
  }

  @override
  void dispose() {
    _pulso?.cancel();
    super.dispose();
  }

  Future<void> _responder(SolicitudVista s, AccionVista accion) async {
    try {
      await ref
          .read(solicitudesVistaPapaProvider.notifier)
          .responder(s.id, accion);
      if (mounted) setState(() => _error = null);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Solo el dueño responde (la pareja, si el dueño lo habilita más adelante).
    if (ref.watch(sesionEfectivaProvider)?.rol != Rol.dueno) {
      return const SizedBox.shrink();
    }
    final todas = ref.watch(solicitudesVistaPapaProvider).value ?? const [];
    final pendientes = [
      for (final s in todas)
        if (s.estadoEn(_ahora) == EstadoVista.pendiente) s,
    ];
    final vigentes = [
      for (final s in todas)
        if (s.vigenteEn(_ahora)) s,
    ];
    if (pendientes.isEmpty && vigentes.isEmpty) return const SizedBox.shrink();
    final v = ValoresDiseno.de(context);

    return Card(
      key: const ValueKey('vista-papa-tarjeta-dueno'),
      child: Padding(
        padding: EdgeInsets.all(v.espacio * 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final s in pendientes) ...[
              Text(
                textosVistaPapa['solicitud_vista']!,
                style: v.lectura(tamano: 16),
              ),
              SizedBox(height: v.espacio / 2),
              Text(
                s.motivo,
                key: ValueKey('vista-papa-motivo-${s.id}'),
                style: v.lectura(tamano: 14, color: v.textoTenue),
              ),
              SizedBox(height: v.espacio),
              Wrap(
                spacing: v.espacio,
                children: [
                  FilledButton(
                    key: ValueKey('vista-papa-autorizar-${s.id}'),
                    onPressed: () => _responder(s, AccionVista.autorizar),
                    child: const Text('Autorizar 30 min'),
                  ),
                  OutlinedButton(
                    key: ValueKey('vista-papa-rechazar-${s.id}'),
                    onPressed: () => _responder(s, AccionVista.rechazar),
                    child: const Text('Rechazar'),
                  ),
                ],
              ),
              SizedBox(height: v.espacio * 2),
            ],
            for (final s in vigentes) ...[
              Text(
                textosVistaPapa['vista_autorizada']!,
                style: v.lectura(tamano: 16),
              ),
              SizedBox(height: v.espacio / 2),
              Text(
                'Quedan ${formatoContador(s.restanteEn(_ahora))}',
                key: ValueKey('vista-papa-restante-${s.id}'),
                style: v.lectura(tamano: 14, color: v.textoTenue),
              ),
              SizedBox(height: v.espacio),
              OutlinedButton(
                key: ValueKey('vista-papa-cancelar-${s.id}'),
                onPressed: () => _responder(s, AccionVista.cancelar),
                child: const Text('Cancelar la vista'),
              ),
            ],
            if (_error != null)
              Padding(
                padding: EdgeInsets.only(top: v.espacio),
                child: Text(
                  _error!,
                  style: v.lectura(tamano: 14, color: v.peligro),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
