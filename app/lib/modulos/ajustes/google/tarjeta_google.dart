/// Botón "Conectar cuenta de Google" de Ajustes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../nucleo/contratos/roles.dart';
import 'conexion_google.dart';

/// Muestra el botón de la cuenta personal y, solo al dueño, el de la casa.
/// Si el rol no puede ninguno, no dibuja nada.
class SeccionGoogleAjustes extends StatelessWidget {
  const SeccionGoogleAjustes({
    super.key,
    required this.rol,
    this.esMaestra = false,
  });

  final Rol rol;
  final bool esMaestra;

  @override
  Widget build(BuildContext context) {
    final personal = puedeConectarGooglePersonal(rol, esMaestra: esMaestra);
    final casa = puedeConectarGoogleCasa(rol, esMaestra: esMaestra);
    if (!personal && !casa) return const SizedBox.shrink();
    return Column(
      children: [
        if (personal)
          const _BotonGoogle(
            ambito: AmbitoGoogle.personal,
            titulo: 'Conectar cuenta de Google',
            descripcion: 'Gmail y Calendar para GRAVITY',
          ),
        if (casa)
          const _BotonGoogle(
            ambito: AmbitoGoogle.casa,
            titulo: 'Conectar cuenta de Google de la casa',
            descripcion: 'Solo el calendario de la casa',
          ),
      ],
    );
  }
}

class _BotonGoogle extends ConsumerStatefulWidget {
  const _BotonGoogle({
    required this.ambito,
    required this.titulo,
    required this.descripcion,
  });

  final AmbitoGoogle ambito;
  final String titulo;
  final String descripcion;

  @override
  ConsumerState<_BotonGoogle> createState() => _BotonGoogleState();
}

class _BotonGoogleState extends ConsumerState<_BotonGoogle>
    with WidgetsBindingObserver {
  EstadoGoogle? _estado;
  String? _mensaje;
  bool _ocupado = false;
  bool _esperandoVuelta = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _consultar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    // Al volver del navegador se consulta el estado.
    if (estado == AppLifecycleState.resumed && _esperandoVuelta) {
      _esperandoVuelta = false;
      _consultar();
    }
  }

  Future<void> _consultar() async {
    try {
      final e = await ref.read(conexionGoogleProvider).estado(widget.ambito);
      if (mounted) setState(() => _estado = e);
    } on ErrorConexionGoogle catch (e) {
      if (mounted) setState(() => _mensaje = e.mensaje);
    }
  }

  Future<void> _conectar() async {
    setState(() {
      _ocupado = true;
      _mensaje = null;
    });
    try {
      final uri = await ref
          .read(conexionGoogleProvider)
          .urlDeConexion(widget.ambito);
      final abierta = await ref.read(abrirUrlGoogleProvider)(uri);
      _esperandoVuelta = abierta;
      if (!abierta) _mensaje = 'No pude abrir el navegador.';
    } on ErrorConexionGoogle catch (e) {
      _mensaje = e.mensaje;
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _estado;
    final conectada = e?.conectada ?? false;
    final subtitulo = [
      if (conectada)
        'Conectada${e?.correo == null ? '' : ': ${e!.correo}'}'
      else
        widget.descripcion,
      ?_mensaje,
    ].join('\n');
    return ListTile(
      leading: Icon(
        conectada ? Icons.check_circle_outline : Icons.link_outlined,
      ),
      title: Text(widget.titulo),
      subtitle: Text(subtitulo),
      minTileHeight: 64,
      trailing: _ocupado
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : (_esperandoVuelta
                ? TextButton(
                    onPressed: _consultar,
                    child: const Text('Revisar'),
                  )
                : null),
      onTap: _ocupado ? null : _conectar,
    );
  }
}
