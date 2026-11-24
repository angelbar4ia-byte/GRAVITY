/// **Cronómetro de la salida** (B4, F-B3): *Empezar* guarda la hora de inicio,
/// *Terminar* abre la hoja de registro.
///
/// **Se basa en instantes**: lo único que se guarda es [SalidaCronometrada.inicio];
/// lo que se ve se calcula contra el reloj. Por eso sobrevive a cerrar la app,
/// a girar la pantalla y a que el teléfono se apague la pantalla. No hay un
/// `Timer.periodic` global: el widget programa **un solo aviso de un disparo**
/// para el siguiente segundo y lo cancela al salir (y no programa nada si el
/// cronómetro no corre o ya terminó).
///
/// Se empieza y se termina **parado**, nunca en movimiento (6.6): los botones
/// miden 64 dp o más, no hay gestos finos y los números no salen de la
/// pantalla con letra grande. Sin animaciones: «reducir movimiento» no cambia
/// nada porque no hay nada que mover.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../valores_diseno.dart';
import 'piezas_bici.dart';
import 'textos_bici.dart';
import 'tipos_bici.dart';

/// Una salida cronometrada, descrita por su **instante de inicio**.
///
/// Es un valor inmutable: la pantalla lo guarda en su estado (y en el
/// almacenamiento local) y sobrevive a todo.
@immutable
class SalidaCronometrada {
  const SalidaCronometrada({required this.inicio, this.fin});

  /// Empieza la salida en [ahora].
  factory SalidaCronometrada.iniciar(DateTime ahora) =>
      SalidaCronometrada(inicio: ahora);

  /// El instante en que se tocó *Empezar*.
  final DateTime inicio;

  /// El instante en que se tocó *Terminar*; `null` si sigue en curso.
  final DateTime? fin;

  bool get terminada => fin != null;

  /// El tiempo corrido; nunca negativo (si el reloj se atrasa, queda en cero).
  Duration transcurrido(DateTime ahora) {
    final d = (fin ?? ahora).difference(inicio);
    return d.isNegative ? Duration.zero : d;
  }

  /// *Terminar*: congela el tiempo en [ahora].
  SalidaCronometrada terminar(DateTime ahora) =>
      SalidaCronometrada(inicio: inicio, fin: fin ?? ahora);

  @override
  bool operator ==(Object other) =>
      other is SalidaCronometrada && other.inicio == inicio && other.fin == fin;

  @override
  int get hashCode => Object.hash(inicio, fin);

  @override
  String toString() => 'SalidaCronometrada($inicio, fin: $fin)';
}

/// «1:42:10». Horas sin ceros a la izquierda; minutos y segundos con dos
/// dígitos.
String formatoCronometro(Duration d) {
  final seg = d.inSeconds;
  final h = seg ~/ 3600;
  final m = (seg % 3600) ~/ 60;
  final s = seg % 60;
  return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// Lo que anuncia el lector de pantalla: **cambia cada minuto**, no cada
/// segundo («1 hora 42 minutos»).
String anuncioCronometro(Duration d) {
  final min = d.inMinutes;
  final h = min ~/ 60;
  final m = min % 60;
  if (h == 0 && m == 0) return 'menos de un minuto';
  final horas = h == 0 ? '' : '$h ${h == 1 ? 'hora' : 'horas'}';
  final minutos = m == 0 ? '' : '$m ${m == 1 ? 'minuto' : 'minutos'}';
  return [horas, minutos].where((x) => x.isNotEmpty).join(' ');
}

/// Tamaño del cronómetro según dónde se usa.
enum EscalaCronometro {
  /// Dentro de una tarjeta.
  tarjeta(44),

  /// Pantalla del cronómetro en el teléfono (Sport).
  pantalla(72),

  /// Números de 96 dp o más: se lee de reojo (6.4).
  grande(96);

  const EscalaCronometro(this.tamanoNumero);

  /// Tamaño de la letra del número, en dp.
  final double tamanoNumero;
}

/// Hora del sistema; se cambia en las pruebas.
DateTime _ahoraDelSistema() => DateTime.now();

/// El cronómetro: número grande, *Empezar* o *Terminar* de 64 dp.
class CronometroSalida extends StatefulWidget {
  const CronometroSalida({
    super.key,
    required this.salida,
    this.escala = EscalaCronometro.pantalla,
    this.alEmpezar,
    this.alTerminar,
    this.alRegistrar,
    this.ahora = _ahoraDelSistema,
    this.estado = EstadoVistaBici.listo,
    this.mensajes = const MensajesEstadoBici(
      vacio: 'Todavía no hay una salida en curso.',
      cargando: 'Preparando el cronómetro…',
      sinConexion: 'Sin conexión. El cronómetro funciona igual.',
      error:
          'No se pudo iniciar el cronómetro. Puedes registrar la salida '
          'después.',
    ),
    this.alReintentar,
  });

  /// La salida en curso; `null` si todavía no se empieza.
  final SalidaCronometrada? salida;
  final EscalaCronometro escala;

  /// *Empezar*: la pantalla responde con `SalidaCronometrada.iniciar(ahora)`.
  final VoidCallback? alEmpezar;

  /// *Terminar*: la pantalla responde con `salida.terminar(ahora)` y abre la
  /// hoja de registro.
  final VoidCallback? alTerminar;

  /// *Registrar lo que hice*, ya terminada.
  final VoidCallback? alRegistrar;

  /// La hora; por omisión la del sistema. Las pruebas pasan un reloj falso.
  final DateTime Function() ahora;
  final EstadoVistaBici estado;
  final MensajesEstadoBici mensajes;
  final VoidCallback? alReintentar;

  @override
  State<CronometroSalida> createState() => _EstadoCronometro();
}

class _EstadoCronometro extends State<CronometroSalida>
    with WidgetsBindingObserver {
  Timer? _aviso;
  late DateTime _ahora;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ahora = widget.ahora();
    _programar();
  }

  @override
  void didUpdateWidget(CronometroSalida anterior) {
    super.didUpdateWidget(anterior);
    _ahora = widget.ahora();
    _programar();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed && mounted) {
      setState(() => _ahora = widget.ahora());
      _programar();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _aviso?.cancel();
    super.dispose();
  }

  /// Programa el siguiente avance del número (un solo disparo). Si no corre,
  /// no programa nada.
  void _programar() {
    _aviso?.cancel();
    _aviso = null;
    final s = widget.salida;
    if (s == null || s.terminada) return;
    final resto = s.transcurrido(_ahora).inMilliseconds % 1000;
    final espera = Duration(milliseconds: 1000 - resto + 2);
    _aviso = Timer(espera, () {
      if (!mounted) return;
      setState(() => _ahora = widget.ahora());
      _programar();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.estado != EstadoVistaBici.listo) {
      return CuerpoEstadoBici(
        estado: widget.estado,
        mensajes: widget.mensajes,
        alReintentar: widget.alReintentar,
      );
    }
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final s = widget.salida;
    final transcurrido = s?.transcurrido(_ahora) ?? Duration.zero;
    final (palabra, icono, color) = switch (s) {
      null => (TextosBici.sinEmpezar, Icons.timer_outlined, v.textoTenue),
      SalidaCronometrada(terminada: true) => (
        TextosBici.terminado,
        Icons.flag_outlined,
        v.exito,
      ),
      _ => (TextosBici.enCurso, Icons.directions_bike, v.acento),
    };
    final anuncio =
        '${TextosBici.cronometro}, ${palabra.toLowerCase()}: '
        '${anuncioCronometro(transcurrido)}';
    final w = widget;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          label: anuncio,
          excludeSemantics: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatoCronometro(transcurrido),
                  key: const ValueKey('cronometro-tiempo'),
                  maxLines: 1,
                  style: v.numero(
                    tamano: w.escala.tamanoNumero,
                    peso: FontWeight.w700,
                    color: v.textoFuerte,
                  ),
                ),
              ),
              SizedBox(height: e),
              MarcaBici(
                key: const ValueKey('cronometro-estado'),
                texto: palabra,
                icono: icono,
                color: color,
                enfasis: s != null,
              ),
            ],
          ),
        ),
        SizedBox(height: e * 2),
        if (s == null) ...[
          FilledButton.icon(
            key: const ValueKey('cronometro-empezar'),
            onPressed: w.alEmpezar,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(altoAccionBici),
            ),
            icon: const Icon(Icons.play_arrow, size: 26),
            label: const Text(TextosBici.empezar),
          ),
          SizedBox(height: e),
          Text(
            TextosBici.cronometroParado,
            textAlign: TextAlign.center,
            style: v.lectura(tamano: 14, color: v.textoTenue),
          ),
        ] else if (!s.terminada)
          FilledButton.icon(
            key: const ValueKey('cronometro-terminar'),
            onPressed: w.alTerminar,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(altoAccionBici),
            ),
            icon: const Icon(Icons.stop, size: 26),
            label: const Text(TextosBici.terminar),
          )
        else if (w.alRegistrar != null)
          FilledButton.icon(
            key: const ValueKey('cronometro-registrar'),
            onPressed: w.alRegistrar,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(altoAccionBici),
            ),
            icon: const Icon(Icons.edit_note, size: 26),
            label: const Text(TextosBici.registrarLoQueHice),
          ),
      ],
    );
  }
}
