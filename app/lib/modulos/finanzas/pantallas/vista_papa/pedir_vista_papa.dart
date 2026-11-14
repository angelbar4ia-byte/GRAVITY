/// Pantalla del familiar: "Pedir ver finanzas de Papá" (D24).
///
/// Estados: sin solicitud (motivo + Pedir), pendiente (esperando), autorizada
/// (la vista temporal con su contador), y rechazada, cancelada o vencida (se
/// puede pedir otra vez). Sin autorización vigente no se muestra nada de Papá.
library;

import 'dart:async';

import 'package:finanzas_dominio/finanzas_dominio.dart'
    show mensajeMotivoCorto, motivoValido;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../diseno/diseno.dart' show ValoresDiseno;
import '../../../../diseno/proveedores.dart' show relojProvider;
import '../../datos/vista_papa.dart';
import '../../estado/proveedores_vista_papa.dart';
import '../../../../app/sesion_efectiva.dart';
import 'vista_temporal_papa.dart';

/// Cada cuántos segundos se vuelve a preguntar al servidor (por si el dueño
/// cancela).
const segundosEntreConsultasVistaPapa = 3;

class PantallaPedirVistaPapa extends ConsumerStatefulWidget {
  const PantallaPedirVistaPapa({super.key});

  @override
  ConsumerState<PantallaPedirVistaPapa> createState() => _EstadoPantalla();
}

class _EstadoPantalla extends ConsumerState<PantallaPedirVistaPapa> {
  final _motivo = TextEditingController();
  Timer? _pulso;
  int _ticks = 0;
  late DateTime _ahora = ref.read(relojProvider).ahora();
  bool _enviando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pulso = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _ticks++;
      setState(() => _ahora = ref.read(relojProvider).ahora());
      if (_ticks % segundosEntreConsultasVistaPapa == 0) {
        ref.read(solicitudesVistaPapaProvider.notifier).refrescar();
      }
    });
  }

  @override
  void dispose() {
    _pulso?.cancel();
    _motivo.dispose();
    super.dispose();
  }

  SolicitudVista? _ultima(List<SolicitudVista> todas) {
    final yo = ref.read(sesionEfectivaProvider)?.persona.id;
    for (final s in todas) {
      if (s.solicitanteId == yo) return s; // la más reciente primero
    }
    return null;
  }

  Future<void> _pedir() async {
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await ref.read(solicitudesVistaPapaProvider.notifier).pedir(_motivo.text);
      _motivo.clear();
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _cancelar(SolicitudVista s) async {
    try {
      await ref
          .read(solicitudesVistaPapaProvider.notifier)
          .responder(s.id, AccionVista.cancelar);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final todas = ref.watch(solicitudesVistaPapaProvider);
    final v = ValoresDiseno.de(context);
    final s = todas.hasValue ? _ultima(todas.requireValue) : null;
    final estado = s?.estadoEn(_ahora);

    // Autorizada y vigente: solo la vista; nada más de Papá en esta pantalla.
    if (s != null && estado == EstadoVista.autorizada) {
      return VistaTemporalPapa(solicitud: s, ahora: _ahora);
    }

    final Widget cuerpo;
    if (todas.isLoading && !todas.hasValue) {
      cuerpo = const Center(child: CircularProgressIndicator());
    } else if (todas.hasError && !todas.hasValue) {
      cuerpo = _Mensaje(
        clave: 'vista-papa-error',
        texto: 'No se pudo consultar. Revisa tu conexión e inténtalo de nuevo.',
        accion: TextButton(
          onPressed: () =>
              ref.read(solicitudesVistaPapaProvider.notifier).refrescar(),
          child: const Text('Reintentar'),
        ),
      );
    } else if (estado == EstadoVista.pendiente) {
      cuerpo = _Mensaje(
        clave: 'vista-papa-pendiente',
        texto: 'Solicitud enviada. Esperando la respuesta del dueño.',
        accion: OutlinedButton(
          key: const ValueKey('vista-papa-cancelar-pedido'),
          onPressed: () => _cancelar(s!),
          child: const Text('Cancelar solicitud'),
        ),
      );
    } else {
      final aviso = switch (estado) {
        EstadoVista.rechazada => 'La solicitud anterior fue rechazada.',
        EstadoVista.cancelada => 'La vista se cerró: fue cancelada.',
        EstadoVista.vencida => 'La vista terminó: se acabaron los 30 minutos.',
        _ => null,
      };
      cuerpo = _Formulario(
        aviso: aviso,
        control: _motivo,
        error: _error,
        enviando: _enviando,
        alPedir: _pedir,
        alCambiar: () => setState(() => _error = null),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Finanzas de Papá')),
      body: Padding(padding: EdgeInsets.all(v.espacio * 2), child: cuerpo),
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.clave, required this.texto, this.accion});

  final String clave;
  final String texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(texto, key: ValueKey(clave), style: v.lectura(tamano: 16)),
        if (accion != null) ...[SizedBox(height: v.espacio * 2), accion!],
      ],
    );
  }
}

class _Formulario extends StatelessWidget {
  const _Formulario({
    required this.aviso,
    required this.control,
    required this.error,
    required this.enviando,
    required this.alPedir,
    required this.alCambiar,
  });

  final String? aviso;
  final TextEditingController control;
  final String? error;
  final bool enviando;
  final VoidCallback alPedir;
  final VoidCallback alCambiar;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    return ListenableBuilder(
      listenable: control,
      builder: (context, _) {
        final escrito = control.text.trim().isNotEmpty;
        final valido = motivoValido(control.text);
        return ListView(
          children: [
            if (aviso != null) ...[
              Text(
                aviso!,
                key: const ValueKey('vista-papa-aviso'),
                style: v.lectura(tamano: 14, color: v.textoTenue),
              ),
              SizedBox(height: v.espacio * 2),
            ],
            Text('Pedir ver finanzas de Papá', style: v.lectura(tamano: 18)),
            SizedBox(height: v.espacio),
            Text(
              'El dueño decide. Si autoriza, verás las finanzas de Papá por '
              '30 minutos, solo para leer. No se puede copiar, exportar ni '
              'capturar la pantalla.',
              style: v.lectura(tamano: 14, color: v.textoTenue),
            ),
            SizedBox(height: v.espacio * 2),
            TextField(
              key: const ValueKey('vista-papa-motivo'),
              controller: control,
              maxLength: 200,
              maxLines: 2,
              onChanged: (_) => alCambiar(),
              decoration: InputDecoration(
                labelText: 'Motivo',
                helperText: 'Por qué quieres verlas.',
                errorText: escrito && !valido ? mensajeMotivoCorto : null,
                errorMaxLines: 3,
              ),
            ),
            if (error != null)
              Padding(
                padding: EdgeInsets.only(top: v.espacio),
                child: Text(
                  error!,
                  key: const ValueKey('vista-papa-error-envio'),
                  style: v.lectura(tamano: 14, color: v.peligro),
                ),
              ),
            SizedBox(height: v.espacio * 2),
            FilledButton(
              key: const ValueKey('vista-papa-pedir'),
              onPressed: valido && !enviando ? alPedir : null,
              child: const Text('Pedir'),
            ),
          ],
        );
      },
    );
  }
}
