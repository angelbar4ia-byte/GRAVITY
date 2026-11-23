/// Temporizador de descanso entre series (7.2, 5.7 y 10).
///
/// **Cuenta hacia un instante final**, no con un contador que se pierda al
/// pausar la app: lo único que se guarda es [DescansoPlanificado.instanteFinal];
/// lo que se ve se calcula contra el reloj. Por eso sobrevive a girar la
/// pantalla y a que la app pase a segundo plano.
///
/// No hay un `Timer.periodic` global: el widget programa **un solo aviso de un
/// disparo** para el siguiente segundo y lo cancela al salir. Al terminar
/// vibra con `HapticFeedback` (nunca suena) y muestra una marca visual con
/// icono y palabras. Con «reducir movimiento» no dibuja el aro: solo el número.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../superficies.dart';
import '../valores_diseno.dart';
import 'piezas_gimnasio.dart';
import 'textos_gimnasio.dart';
import 'tipos_gimnasio.dart';

/// Un descanso en curso o ya terminado, descrito por su **instante final**.
///
/// Es un valor inmutable: cada ajuste devuelve uno nuevo, así que la pantalla
/// lo puede guardar en su estado (y sobrevive a girar el aparato).
@immutable
class DescansoPlanificado {
  const DescansoPlanificado({
    required this.instanteFinal,
    required this.duracionTotal,
  });

  /// Arranca un descanso de [duracion] a partir de [ahora].
  factory DescansoPlanificado.iniciar(DateTime ahora, Duration duracion) =>
      DescansoPlanificado(
        instanteFinal: ahora.add(duracion),
        duracionTotal: duracion,
      );

  /// El momento en que termina el descanso.
  final DateTime instanteFinal;

  /// La duración que se usa para dibujar el avance del aro.
  final Duration duracionTotal;

  /// Lo que falta; nunca negativo.
  Duration restante(DateTime ahora) {
    final r = instanteFinal.difference(ahora);
    return r.isNegative ? Duration.zero : r;
  }

  /// Si ya llegó el instante final.
  bool haTerminado(DateTime ahora) => !instanteFinal.isAfter(ahora);

  /// Cuánto del descanso ya pasó, de 0 a 1.
  double avance(DateTime ahora) {
    if (duracionTotal <= Duration.zero) return 1;
    final hecho =
        1 - restante(ahora).inMilliseconds / duracionTotal.inMilliseconds;
    return hecho.clamp(0.0, 1.0);
  }

  /// +15 s o −15 s para esta serie. Si resta más de lo que queda, termina ya.
  DescansoPlanificado ajustar(Duration cambio, DateTime ahora) {
    final nuevoFinal = instanteFinal.add(cambio);
    if (!nuevoFinal.isAfter(ahora)) return saltar(ahora);
    final total = duracionTotal + cambio;
    final restanteNuevo = nuevoFinal.difference(ahora);
    return DescansoPlanificado(
      instanteFinal: nuevoFinal,
      duracionTotal: total < restanteNuevo ? restanteNuevo : total,
    );
  }

  /// *Saltar*: el descanso termina en [ahora].
  DescansoPlanificado saltar(DateTime ahora) =>
      DescansoPlanificado(instanteFinal: ahora, duracionTotal: duracionTotal);

  @override
  bool operator ==(Object other) =>
      other is DescansoPlanificado &&
      other.instanteFinal == instanteFinal &&
      other.duracionTotal == duracionTotal;

  @override
  int get hashCode => Object.hash(instanteFinal, duracionTotal);

  @override
  String toString() => 'DescansoPlanificado(hasta $instanteFinal)';
}

/// «00:48». Los segundos se redondean hacia arriba para que nunca marque
/// 00:00 antes de terminar.
String formatoDescanso(Duration d) {
  final seg = (d.inMilliseconds / 1000).ceil();
  final m = seg ~/ 60;
  final s = seg % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// Segundos que anuncia el lector de pantalla: de 15 en 15 (7.2 y 10).
int segundosAnunciados(Duration restante) {
  final seg = (restante.inMilliseconds / 1000).ceil();
  return (seg ~/ 15) * 15;
}

/// Tamaño del temporizador según dónde se usa.
enum EscalaTemporizador {
  /// Dentro de la tarjeta del gadget.
  compacta(34),

  /// Sesión en curso en el teléfono: el temporizador ocupa 64 dp o más.
  sesion(60),

  /// Tablet, legible desde 2 m: números de más de 96 dp (7.2).
  tablet(112);

  const EscalaTemporizador(this.tamanoNumero);

  /// Tamaño de la letra del número, en dp.
  final double tamanoNumero;
}

/// Hora del sistema; se cambia en las pruebas.
DateTime _ahoraDelSistema() => DateTime.now();

/// Vibración corta por omisión del fin del descanso.
Future<void> vibracionFinDescanso() => HapticFeedback.heavyImpact();

/// El temporizador de descanso: número grande, aro, +15 s, −15 s y *Saltar*.
class TemporizadorDescanso extends StatefulWidget {
  const TemporizadorDescanso({
    super.key,
    required this.descanso,
    this.escala = EscalaTemporizador.sesion,
    this.alMasQuince,
    this.alMenosQuince,
    this.alSaltar,
    this.alTerminar,
    this.ahora = _ahoraDelSistema,
    this.vibrar = vibracionFinDescanso,
    this.estado = EstadoVistaGimnasio.listo,
    this.mensajes = const MensajesEstadoGimnasio(
      vacio: TextosGimnasio.sinDescanso,
      cargando: 'Preparando el descanso…',
      sinConexion: 'Sin conexión. El descanso funciona igual.',
      error: 'No se pudo iniciar el descanso. Puedes seguir sin él.',
    ),
    this.alReintentar,
  });

  /// El descanso en curso; `null` si no hay (se muestra «Sin descanso en curso»).
  final DescansoPlanificado? descanso;
  final EscalaTemporizador escala;

  /// +15 s: la pantalla responde con `descanso.ajustar(15 s, ahora)`.
  final VoidCallback? alMasQuince;

  /// −15 s.
  final VoidCallback? alMenosQuince;

  /// *Saltar*: la pantalla responde con `descanso.saltar(ahora)`.
  final VoidCallback? alSaltar;

  /// Se llama **una vez** al llegar al instante final (también si la app
  /// vuelve de segundo plano y ya había terminado).
  final VoidCallback? alTerminar;

  /// La hora; por omisión la del sistema. Las pruebas pasan un reloj falso.
  final DateTime Function() ahora;

  /// La vibración del fin; por omisión `HapticFeedback`.
  final Future<void> Function() vibrar;
  final EstadoVistaGimnasio estado;
  final MensajesEstadoGimnasio mensajes;
  final VoidCallback? alReintentar;

  @override
  State<TemporizadorDescanso> createState() => _EstadoTemporizador();
}

class _EstadoTemporizador extends State<TemporizadorDescanso>
    with WidgetsBindingObserver {
  Timer? _aviso;
  late DateTime _ahora;

  /// El instante final del que ya se avisó el fin (para avisar una sola vez).
  DateTime? _finAvisado;

  /// Si este widget vio correr el descanso: solo entonces vibra al terminar.
  bool _vioCorrer = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ahora = widget.ahora();
    _revisar(enBuild: true);
  }

  @override
  void didUpdateWidget(TemporizadorDescanso anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.descanso != widget.descanso) {
      _vioCorrer = false;
      _finAvisado = null;
    }
    _ahora = widget.ahora();
    _revisar(enBuild: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed && mounted) {
      setState(() => _ahora = widget.ahora());
      _revisar(enBuild: false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _aviso?.cancel();
    super.dispose();
  }

  /// Programa el siguiente avance del número (un solo disparo) o avisa el fin.
  void _revisar({required bool enBuild}) {
    _aviso?.cancel();
    _aviso = null;
    final d = widget.descanso;
    if (d == null) return;
    final falta = d.restante(_ahora);
    if (falta > Duration.zero) {
      _vioCorrer = true;
      final resto = falta.inMilliseconds % 1000;
      final espera = Duration(milliseconds: resto == 0 ? 1000 : resto + 2);
      _aviso = Timer(espera, () {
        if (!mounted) return;
        setState(() => _ahora = widget.ahora());
        _revisar(enBuild: false);
      });
      return;
    }
    if (_finAvisado == d.instanteFinal) return;
    _finAvisado = d.instanteFinal;
    final reciente =
        _ahora.difference(d.instanteFinal) < const Duration(seconds: 3);
    final vibra = _vioCorrer && reciente;
    void avisar() {
      if (!mounted) return;
      if (vibra) widget.vibrar();
      widget.alTerminar?.call();
    }

    if (enBuild) {
      SchedulerBinding.instance.addPostFrameCallback((_) => avisar());
    } else {
      avisar();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.estado != EstadoVistaGimnasio.listo) {
      return CuerpoEstadoGimnasio(
        estado: widget.estado,
        mensajes: widget.mensajes,
        alReintentar: widget.alReintentar,
      );
    }
    final d = widget.descanso;
    if (d == null) {
      return CuerpoEstadoGimnasio(
        estado: EstadoVistaGimnasio.vacio,
        mensajes: widget.mensajes,
      );
    }
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final terminado = d.haTerminado(_ahora);
    final falta = d.restante(_ahora);
    final quieto = MediaQuery.disableAnimationsOf(context);
    final tamano = widget.escala.tamanoNumero;
    final diametro = tamano * 2.5;

    final numero = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        formatoDescanso(falta),
        key: const ValueKey('descanso-restante'),
        maxLines: 1,
        style: v.numero(
          tamano: tamano,
          peso: FontWeight.w700,
          color: v.textoFuerte,
        ),
      ),
    );

    final marca = terminado
        ? MarcaGimnasio(
            key: const ValueKey('descanso-terminado'),
            texto: TextosGimnasio.descansoTerminado,
            icono: Icons.notifications_active_outlined,
            color: v.exito,
            enfasis: true,
          )
        : Text(
            TextosGimnasio.descanso,
            style: v.lectura(tamano: 14, color: v.textoTenue),
          );

    // Lo que lee el lector de pantalla: cambia cada 15 s, no cada segundo.
    final anuncio = terminado
        ? TextosGimnasio.descansoTerminado
        : '${TextosGimnasio.descanso}: '
              '${_textoSegundos(segundosAnunciados(falta))}';

    final centro = quieto
        ? ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: altoAccionSesion,
              minWidth: altoAccionSesion,
            ),
            child: Center(child: numero),
          )
        : SizedBox(
            width: diametro,
            height: diametro,
            child: CustomPaint(
              painter: _AroDescanso(
                avance: terminado ? 1 : d.avance(_ahora),
                color: terminado ? v.exito : v.acento,
                pista: v.pista,
                grosor: math.max(8, tamano * 0.16),
              ),
              child: Padding(
                padding: EdgeInsets.all(diametro * 0.18),
                child: Center(child: numero),
              ),
            ),
          );

    final w = widget;
    final hayControles =
        !terminado &&
        (w.alMasQuince != null ||
            w.alMenosQuince != null ||
            w.alSaltar != null);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          container: true,
          liveRegion: true,
          label: anuncio,
          excludeSemantics: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              centro,
              SizedBox(height: e),
              marca,
            ],
          ),
        ),
        if (hayControles) ...[
          SizedBox(height: e * 1.5),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: e,
            runSpacing: e,
            children: [
              if (w.alMenosQuince != null)
                _BotonDescanso(
                  texto: TextosGimnasio.menos15,
                  etiqueta: 'Quitar 15 segundos al descanso',
                  alTocar: w.alMenosQuince,
                ),
              if (w.alMasQuince != null)
                _BotonDescanso(
                  texto: TextosGimnasio.mas15,
                  etiqueta: 'Agregar 15 segundos al descanso',
                  alTocar: w.alMasQuince,
                ),
              if (w.alSaltar != null)
                _BotonDescanso(
                  texto: TextosGimnasio.saltar,
                  etiqueta: 'Saltar el descanso',
                  alTocar: w.alSaltar,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

String _textoSegundos(int seg) =>
    seg <= 0 ? 'menos de 15 segundos' : '$seg segundos';

/// Botón de ajuste del descanso: 56 dp de alto, con etiqueta accesible.
class _BotonDescanso extends StatelessWidget {
  const _BotonDescanso({
    required this.texto,
    required this.etiqueta,
    required this.alTocar,
  });

  final String texto;
  final String etiqueta;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: alTocar != null,
      onTap: alTocar,
      label: etiqueta,
      excludeSemantics: true,
      child: OutlinedButton(
        onPressed: alTocar,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(
            BotonPasoGimnasio.tamano,
            BotonPasoGimnasio.tamano,
          ),
        ),
        child: Text(texto),
      ),
    );
  }
}

/// Aro de avance del descanso: pista y avance del tema (3:1 entre sí).
class _AroDescanso extends CustomPainter {
  const _AroDescanso({
    required this.avance,
    required this.color,
    required this.pista,
    required this.grosor,
  });

  final double avance;
  final Color color;
  final Color pista;
  final double grosor;

  @override
  void paint(Canvas canvas, Size size) {
    final area = (Offset.zero & size).deflate(grosor / 2);
    final pincel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(area, 0, math.pi * 2, false, pincel..color = pista);
    // El aro se vacía conforme corre el descanso.
    final queda = (1 - avance).clamp(0.0, 1.0);
    if (queda > 0) {
      canvas.drawArc(
        area,
        -math.pi / 2,
        math.pi * 2 * queda,
        false,
        pincel..color = color,
      );
    } else {
      canvas.drawArc(area, 0, math.pi * 2, false, pincel..color = color);
    }
  }

  @override
  bool shouldRepaint(_AroDescanso old) =>
      old.avance != avance ||
      old.color != color ||
      old.pista != pista ||
      old.grosor != grosor;
}
