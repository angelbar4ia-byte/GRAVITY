/// Puerta de la **sección reservada** de Hábitos (Fase 3, regla 100): el panel
/// de hábitos a eliminar, el SOS, el registro de consumo, el diario de oración,
/// el devocional escrito, las notas y *Mis datos* se envuelven en
/// [PuertaReservada]. Ella:
///
/// - pide el **PIN** (o la huella, en el teléfono) al entrar y vuelve a pedirlo
///   tras [minutosDeBloqueoReservado] minutos sin uso (2 por omisión);
/// - abre la pantalla con **FLAG_SECURE** (sin capturas ni vista previa);
/// - con el **modo privado** (laptop) oculta el contenido: *"Contenido
///   reservado · Toca para ver"*;
/// - en la **tablet pública** no muestra nada (esa pantalla ni se ofrece).
///
/// Reutiliza el PIN de los montos (`ControladorMontos`): el de la tablet, el del
/// bloqueo del teléfono o el propio.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../diseno/proveedores.dart' show modoPrivadoProvider;
import '../../nucleo/avisos/repositorio_avisos.dart';
import '../../nucleo/seguridad/intentos.dart';
import '../../nucleo/seguridad/montos.dart';
import '../avisos/con_avisos.dart';
import '../pantalla_segura.dart';
import '../sesion_efectiva.dart';
import '../tablet/detector_inactividad.dart';

/// Minutos sin uso tras los que lo reservado vuelve a pedir el PIN.
const minutosDeBloqueoReservado = 2;

/// ¿Lo reservado está abierto ahora? Se cierra solo al pasar el tiempo sin uso
/// y al cambiar la persona en pantalla.
final reservadoAbiertoProvider = NotifierProvider<ReservadoAbierto, bool>(
  ReservadoAbierto.new,
);

class ReservadoAbierto extends Notifier<bool> {
  @override
  bool build() {
    ref.watch(sesionEfectivaProvider.select((s) => s?.persona.id));
    return false;
  }

  void abrir() => state = true;

  void cerrar() => state = false;
}

class PuertaReservada extends ConsumerWidget {
  const PuertaReservada({
    super.key,
    required this.child,
    this.tiempo = const Duration(minutes: minutosDeBloqueoReservado),
  });

  final Widget child;
  final Duration tiempo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // La tablet pública de la casa nunca muestra lo reservado.
    if (ref.watch(tipoEquipoAvisosProvider) == TipoEquipoAvisos.tabletPublica) {
      return const _Cubierta(
        clave: 'reservado-no-disponible',
        texto: 'Esto no está disponible en la tablet de la casa.',
      );
    }
    final abierto = ref.watch(reservadoAbiertoProvider);
    final privado = ref.watch(modoPrivadoProvider);
    return PantallaSegura(
      activa: true,
      child: DetectorInactividad(
        activo: abierto,
        tiempo: tiempo,
        alVencer: () => ref.read(reservadoAbiertoProvider.notifier).cerrar(),
        child: !abierto
            ? const _PedirPin()
            : privado
            ? const _Cubierta(
                clave: 'reservado-privado',
                texto: 'Contenido reservado · Toca para ver',
              )
            : child,
      ),
    );
  }
}

class _Cubierta extends StatelessWidget {
  const _Cubierta({required this.clave, required this.texto});

  final String clave;
  final String texto;

  @override
  Widget build(BuildContext context) => Center(
    key: ValueKey(clave),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline),
          const SizedBox(width: 8),
          Flexible(child: Text(texto)),
        ],
      ),
    ),
  );
}

class _PedirPin extends ConsumerStatefulWidget {
  const _PedirPin();

  @override
  ConsumerState<_PedirPin> createState() => _PedirPinState();
}

class _PedirPinState extends ConsumerState<_PedirPin> {
  final _pin = TextEditingController();
  String? _error;
  bool _huella = false;
  bool _trabajando = false;

  @override
  void initState() {
    super.initState();
    final montos = ref.read(controladorMontosProvider.notifier);
    montos.listo.then((_) => montos.huellaDisponible()).then((hay) {
      if (mounted) setState(() => _huella = hay);
    });
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  void _resultado(ResultadoRevelar r) {
    final montos = ref.read(controladorMontosProvider.notifier);
    if (r == ResultadoRevelar.revelado) {
      ref.read(reservadoAbiertoProvider.notifier).abrir();
      return;
    }
    _pin.clear();
    setState(() {
      _trabajando = false;
      _error = switch (r) {
        ResultadoRevelar.pinIncorrecto => 'PIN incorrecto.',
        ResultadoRevelar.bloqueado =>
          'Demasiados intentos. Espera ${textoEspera(montos.esperaRestante() ?? const Duration(seconds: 30))}.',
        ResultadoRevelar.faltaPin =>
          'Primero crea tu PIN en Ajustes › Privacidad.',
        ResultadoRevelar.huellaFallida => 'No se reconoció la huella.',
        ResultadoRevelar.debeCambiarPin =>
          'Tu PIN debe ser de 6 dígitos: cámbialo en Ajustes › Privacidad.',
        ResultadoRevelar.revelado => null,
      };
    });
  }

  Future<void> _entrar() async {
    if (_trabajando) return;
    setState(() => _trabajando = true);
    final montos = ref.read(controladorMontosProvider.notifier);
    await montos.listo;
    _resultado(await montos.verificar(_pin.text));
  }

  Future<void> _conHuella() async {
    if (_trabajando) return;
    setState(() => _trabajando = true);
    _resultado(
      await ref.read(controladorMontosProvider.notifier).verificarConHuella(),
    );
  }

  @override
  Widget build(BuildContext context) => Center(
    key: const ValueKey('reservado-pide-pin'),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.lock_outline, size: 40),
            const SizedBox(height: 8),
            const Text(
              'Sección reservada',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('reservado-pin'),
              controller: _pin,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSubmitted: (_) => _entrar(),
              decoration: InputDecoration(labelText: 'PIN', errorText: _error),
            ),
            FilledButton(
              key: const ValueKey('reservado-entrar'),
              onPressed: _trabajando ? null : _entrar,
              child: const Text('Entrar'),
            ),
            if (_huella)
              TextButton.icon(
                key: const ValueKey('reservado-huella'),
                onPressed: _trabajando ? null : _conHuella,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Usar huella'),
              ),
          ],
        ),
      ),
    ),
  );
}
