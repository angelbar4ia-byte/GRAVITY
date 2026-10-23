/// Ajustes › Privacidad: modo privado, datos sensibles (D3, D13) y, en el
/// teléfono, el bloqueo con PIN o huella (revisión de la Fase 0, I8).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dispositivo.dart';
import '../../../nucleo/contratos/dispositivo.dart';
import '../../../nucleo/seguridad/bloqueo.dart';
import '../../../nucleo/seguridad/pin.dart';
import '../../../nucleo/seguridad/proveedores_seguridad.dart';
import '../marco_seccion.dart';
import '../secciones_ajustes.dart';

class PantallaPrivacidad extends ConsumerWidget {
  const PantallaPrivacidad({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esTelefono =
        ref.watch(tipoDispositivoProvider) == TipoDispositivo.telefono;
    return MarcoSeccion(
      seccion: SeccionAjustes.privacidad,
      hijos: [
        if (esTelefono) ...[
          const _BloqueoTelefono(),
          const SizedBox(height: 16),
        ],
        const NotaAjustes(
          'El dinero y los datos clínicos nunca van a la IA en la nube ni a las '
          'bocinas.',
          icono: Icons.shield_outlined,
        ),
        const NotaAjustes(
          'Modo privado: oculta montos y datos de cuidados con un toque (en la '
          'laptop, Ctrl + Shift + O).',
          icono: Icons.visibility_off_outlined,
        ),
        const NotaAjustes(
          'Datos sensibles de Hábitos: cifrados en la nube o solo en el '
          'teléfono, a elegir (llega en la Fase 3).',
          icono: Icons.lock_outline,
        ),
      ],
    );
  }
}

String textoBloqueoTras(Duration tras) => switch (tras.inMinutes) {
  0 => 'Al instante',
  1 => '1 minuto',
  final m => '$m minutos',
};

class _BloqueoTelefono extends ConsumerStatefulWidget {
  const _BloqueoTelefono();

  @override
  ConsumerState<_BloqueoTelefono> createState() => _BloqueoTelefonoState();
}

class _BloqueoTelefonoState extends ConsumerState<_BloqueoTelefono> {
  bool _hayHuella = false;

  @override
  void initState() {
    super.initState();
    ref.read(biometriaProvider).disponible().then((hay) {
      if (mounted) setState(() => _hayHuella = hay);
    });
  }

  Future<void> _elegirPin() async {
    final pin = await showDialog<String>(
      context: context,
      builder: (contexto) => const _DialogoPinBloqueo(),
    );
    if (pin == null) return;
    await ref.read(controladorBloqueoProvider.notifier).configurarPin(pin);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final estado = ref.watch(controladorBloqueoProvider);
    final controlador = ref.read(controladorBloqueoProvider.notifier);
    final configuracion = estado.configuracion;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Bloqueo del teléfono',
                style: tema.textTheme.titleMedium,
              ),
            ),
            SwitchListTile(
              key: const ValueKey('bloqueo-activo'),
              value: estado.activo,
              title: const Text('Pedir PIN al abrir GRAVITY'),
              subtitle: const Text(
                'También al volver tras un rato en segundo plano.',
              ),
              onChanged: !estado.cargado
                  ? null
                  : (activar) =>
                        activar ? _elegirPin() : controlador.quitarBloqueo(),
            ),
            if (configuracion != null) ...[
              ListTile(
                title: const Text('Cambiar PIN'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _elegirPin,
              ),
              if (_hayHuella)
                SwitchListTile(
                  value: configuracion.huella,
                  title: const Text('Desbloquear con huella'),
                  subtitle: const Text(
                    'Con las huellas registradas en este teléfono.',
                  ),
                  onChanged: controlador.fijarHuella,
                ),
              ListTile(
                title: const Text('Bloquear tras'),
                trailing: DropdownButton<Duration>(
                  value: opcionesBloqueoTras.contains(configuracion.tras)
                      ? configuracion.tras
                      : null,
                  hint: Text(textoBloqueoTras(configuracion.tras)),
                  items: [
                    for (final opcion in opcionesBloqueoTras)
                      DropdownMenuItem(
                        value: opcion,
                        child: Text(textoBloqueoTras(opcion)),
                      ),
                  ],
                  onChanged: (opcion) {
                    if (opcion != null) controlador.fijarTiempo(opcion);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DialogoPinBloqueo extends StatefulWidget {
  const _DialogoPinBloqueo();

  @override
  State<_DialogoPinBloqueo> createState() => _DialogoPinBloqueoState();
}

class _DialogoPinBloqueoState extends State<_DialogoPinBloqueo> {
  final _pin = TextEditingController();
  final _confirmacion = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  Widget _campo(TextEditingController control, String etiqueta, Key llave) =>
      TextField(
        key: llave,
        controller: control,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: etiqueta),
      );

  void _guardar() {
    final errorPin = errorDePinNuevo(_pin.text);
    if (errorPin != null) {
      setState(() => _error = errorPin);
    } else if (_pin.text != _confirmacion.text) {
      setState(() => _error = 'Los PIN no coinciden.');
    } else {
      Navigator.of(context).pop(_pin.text);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('PIN del teléfono'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _campo(_pin, 'PIN (4 a 6 dígitos)', const Key('bloqueo-pin')),
        _campo(_confirmacion, 'Repite el PIN', const Key('bloqueo-confirmacion')),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _guardar, child: const Text('Guardar')),
    ],
  );
}
