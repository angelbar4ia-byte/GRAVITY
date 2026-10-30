/// Ajustes › Privacidad: modo privado, datos sensibles (D3, D13) y, en el
/// teléfono, el bloqueo con PIN o huella (revisión de la Fase 0, I8).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dispositivo.dart';
import '../../../app/montos/revelar_montos.dart' show mensajeRevelar;
import '../../../nucleo/contratos/dispositivo.dart';
import '../../../nucleo/contratos/roles.dart';
import '../../../nucleo/seguridad/bloqueo.dart';
import '../../../nucleo/seguridad/intentos.dart' show textoEspera;
import '../../../nucleo/seguridad/montos.dart';
import '../../../nucleo/seguridad/pin.dart';
import '../../../nucleo/seguridad/proveedores_seguridad.dart';
import '../../../nucleo/sesion/proveedores_sesion.dart';
import '../../../nucleo/tablet/controlador_tablet.dart';
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
        const _MontosOcultos(),
        const SizedBox(height: 16),
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
          'Los montos también se ocultan solos tras unos minutos sin uso. '
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

/// Ocultar los montos solos tras unos minutos sin uso (decisión del 23/oct):
/// el tiempo es editable aquí y para volver a verlos se pide el PIN (en el
/// teléfono, también la huella).
class _MontosOcultos extends ConsumerWidget {
  const _MontosOcultos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final estado = ref.watch(controladorMontosProvider);
    final controlador = ref.read(controladorMontosProvider.notifier);
    // Quién pide el PIN: la tablet (el de la persona), el bloqueo del teléfono
    // o uno propio. Se vuelve a leer al cambiar el bloqueo o la persona.
    ref.watch(controladorBloqueoProvider);
    ref.watch(controladorTabletProvider.select((e) => e.usuarioActivo?.personaId));
    final fuente = controlador.fuente;
    return Card(
      key: const ValueKey('privacidad-montos'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text('Montos', style: tema.textTheme.titleMedium),
            ),
            ListTile(
              title: const Text('Ocultar los montos tras'),
              subtitle: const Text(
                'Sin tocar la pantalla. Para volver a verlos se pide tu PIN.',
              ),
              trailing: DropdownButton<Duration>(
                key: const ValueKey('montos-ocultar-tras'),
                value: opcionesOcultarMontosTras.contains(estado.ocultarTras)
                    ? estado.ocultarTras
                    : null,
                hint: Text(textoOcultarMontosTras(estado.ocultarTras)),
                items: [
                  for (final opcion in opcionesOcultarMontosTras)
                    DropdownMenuItem(
                      value: opcion,
                      child: Text(textoOcultarMontosTras(opcion)),
                    ),
                ],
                onChanged: !estado.cargado
                    ? null
                    : (opcion) {
                        if (opcion != null) controlador.fijarOcultarTras(opcion);
                      },
              ),
            ),
            switch (fuente) {
              FuenteDePinMontos.tablet => const ListTile(
                leading: Icon(Icons.pin_outlined),
                title: Text('PIN de la tablet'),
                subtitle: Text('Se usa tu PIN de la tablet.'),
              ),
              FuenteDePinMontos.bloqueo => const ListTile(
                leading: Icon(Icons.pin_outlined),
                title: Text('PIN del bloqueo'),
                subtitle: Text('Se usa el PIN del bloqueo del teléfono.'),
              ),
              FuenteDePinMontos.propio => ListTile(
                key: const ValueKey('montos-pin-propio'),
                leading: const Icon(Icons.pin_outlined),
                title: Text(
                  estado.tienePinPropio
                      ? 'Cambiar el PIN para ver los montos'
                      : 'Crear un PIN para ver los montos',
                ),
                subtitle: Text(
                  'De ${textoDelLargoDelPin(controlador.rol)}; nada fácil como '
                  '1234.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  // Cambiar el PIN pide el actual (P1, revisión de la Fase 1b).
                  final pines = await showDialog<_PinesElegidos>(
                    context: context,
                    builder: (contexto) => _DialogoPinBloqueo(
                      titulo: 'PIN para ver los montos',
                      rol: controlador.rol,
                      pedirActual: estado.tienePinPropio,
                    ),
                  );
                  if (pines == null) return;
                  final resultado = await controlador.crearPin(
                    pines.nuevo,
                    actual: pines.actual,
                  );
                  if (resultado != ResultadoRevelar.revelado && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          mensajeRevelar(
                                resultado,
                                espera: controlador.esperaRestante(),
                              ) ??
                              'No se cambió el PIN.',
                        ),
                      ),
                    );
                  }
                },
              ),
            },
          ],
        ),
      ),
    );
  }
}

String textoOcultarMontosTras(Duration tras) =>
    tras.inMinutes == 1 ? '1 minuto' : '${tras.inMinutes} minutos';

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
    // Cambiar un PIN pide el actual, también el de los montos si ya hay uno
    // propio (P1, revisión de la Fase 1b).
    final hayPin =
        ref.read(controladorBloqueoProvider).activo ||
        ref.read(controladorMontosProvider).tienePinPropio;
    final pines = await showDialog<_PinesElegidos>(
      context: context,
      builder: (contexto) => _DialogoPinBloqueo(
        rol: ref.read(sesionActualProvider)?.rol,
        pedirActual: hayPin,
      ),
    );
    if (pines == null) return;
    final controlador = ref.read(controladorBloqueoProvider.notifier);
    final resultado = await controlador.configurarPin(
      pines.nuevo,
      actual: pines.actual,
    );
    if (resultado == ResultadoBloqueo.abierto || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          resultado == ResultadoBloqueo.bloqueado
              ? 'Demasiados intentos. Espera '
                    '${textoEspera(controlador.esperaRestante() ?? const Duration(seconds: 30))}.'
              : 'PIN actual incorrecto. No se cambió.',
        ),
      ),
    );
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

/// Lo que devuelve el diálogo de elegir un PIN: el actual (si se pidió) y el
/// nuevo.
typedef _PinesElegidos = ({String? actual, String nuevo});

class _DialogoPinBloqueo extends StatefulWidget {
  const _DialogoPinBloqueo({
    this.titulo = 'PIN del teléfono',
    this.rol,
    this.pedirActual = false,
  });

  final String titulo;

  /// De su rol depende el largo del PIN (6 dígitos si ve dinero; D18, 23/oct).
  final Rol? rol;

  /// Ya hay un PIN: para cambiarlo se pide el actual (P1, revisión de la
  /// Fase 1b).
  final bool pedirActual;

  @override
  State<_DialogoPinBloqueo> createState() => _DialogoPinBloqueoState();
}

class _DialogoPinBloqueoState extends State<_DialogoPinBloqueo> {
  final _actual = TextEditingController();
  final _pin = TextEditingController();
  final _confirmacion = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _actual.dispose();
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
    if (widget.pedirActual && _actual.text.isEmpty) {
      setState(() => _error = 'Escribe tu PIN actual.');
      return;
    }
    final error = errorDePinNuevoConfirmado(
      _pin.text,
      _confirmacion.text,
      rol: widget.rol,
    );
    if (error != null) {
      setState(() => _error = error);
    } else {
      Navigator.of(context).pop((
        actual: widget.pedirActual ? _actual.text : null,
        nuevo: _pin.text,
      ));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.titulo),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.pedirActual)
          _campo(_actual, 'PIN actual', const Key('bloqueo-pin-actual')),
        _campo(
          _pin,
          widget.pedirActual
              ? 'PIN nuevo (${textoDelLargoDelPin(widget.rol)})'
              : 'PIN (${textoDelLargoDelPin(widget.rol)})',
          const Key('bloqueo-pin'),
        ),
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
