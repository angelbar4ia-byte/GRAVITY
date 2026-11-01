import 'dart:async';

import 'package:flutter/material.dart';

import '../tema.dart';
import '../valores_diseno.dart';
import 'sensible_ocultable.dart';

/// Fase de un hábito a eliminar (Fase 3, regla 32).
enum FaseHabito {
  noIniciado('No iniciado', 'Cuando quieras, empezamos.'),
  lineaBase('Línea base', 'Solo observamos'),
  reduccion('Reducción', 'Un paso a la vez'),
  preparacion('Preparación', 'Falta poco para el Día D'),
  diaD('Día D', 'Hoy empieza lo nuevo'),
  libre('Libre', 'Cada día cuenta'),
  mantenimiento('Mantenimiento', 'Lo construido sigue contigo');

  const FaseHabito(this.etiqueta, this.mensaje);

  final String etiqueta;
  final String mensaje;

  /// En la línea base no hay metas, racha ni semáforo.
  bool get conMetas => this != noIniciado && this != lineaBase;

  /// Desde el Día D se cuentan días libres.
  bool get cuentaDiasLibres =>
      this == diaD || this == libre || this == mantenimiento;
}

/// Semáforo del refresco ocasional (Fase 3, regla 45). Terracota, nunca rojo
/// de alarma (en la personalidad empática `peligro` es terracota).
enum EstadoRefresco {
  verde('Dentro de lo que decidiste', Icons.check_circle_outline),
  ambar('Cerca de tu límite', Icons.warning_amber_rounded),
  terracota('Más de lo previsto', Icons.info_outline);

  const EstadoRefresco(this.texto, this.icono);

  final String texto;
  final IconData icono;

  Color color(ValoresDiseno v) => switch (this) {
    EstadoRefresco.verde => v.exito,
    EstadoRefresco.ambar => v.alerta,
    EstadoRefresco.terracota => v.peligro,
  };

  /// Con enteros: verde si `usadas×4 < límite×3`; ámbar si `usadas×4 ≥
  /// límite×3` y `usadas ≤ límite`; terracota si `usadas > límite`. Con límite
  /// 0: verde sin ninguna, terracota con una o más.
  static EstadoRefresco de({required int usadas, required int limite}) {
    if (limite <= 0) return usadas > 0 ? terracota : verde;
    if (usadas > limite) return terracota;
    if (usadas * 4 >= limite * 3) return ambar;
    return verde;
  }
}

/// Semáforo del refresco ocasional: estado con texto e icono y
/// "usadas de límite".
class SemaforoRefresco extends StatelessWidget {
  const SemaforoRefresco({
    super.key,
    required this.usadas,
    required this.limite,
    this.periodo = 'esta semana',
  });

  final int usadas;
  final int limite;
  final String periodo;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final estado = EstadoRefresco.de(usadas: usadas, limite: limite);
    final color = estado.color(v);
    return Semantics(
      container: true,
      label: 'Refresco ocasional',
      value: '${estado.texto}. $usadas de $limite $periodo',
      excludeSemantics: true,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: v.espacio,
        runSpacing: v.espacio * 0.5,
        children: [
          Icon(estado.icono, size: 20, color: color),
          Text(
            estado.texto,
            style: v.lectura(
              tamano: 14,
              peso: FontWeight.w600,
              color: v.textoFuerte,
            ),
          ),
          Text(
            '$usadas de $limite $periodo',
            style: v.numero(tamano: 13, color: v.textoTenue),
          ),
        ],
      ),
    );
  }
}

/// Botón **Pausa** / *Tengo un antojo*: siempre visible, grande (56 dp) y con
/// una etiqueta discreta ("Pausa") para no anunciarle a quien mire.
class BotonPausa extends StatelessWidget {
  const BotonPausa({
    super.key,
    required this.alTocar,
    this.etiqueta = 'Pausa',
    this.expandido = false,
  });

  final VoidCallback? alTocar;

  /// `etiqueta_atajo` (P8): "Pausa" por omisión.
  final String etiqueta;
  final bool expandido;

  @override
  Widget build(BuildContext context) {
    final boton = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: 56,
        minWidth: zonaTactilMinima,
      ),
      child: FilledButton.icon(
        onPressed: alTocar,
        icon: const Icon(Icons.pause_circle_outline),
        label: Text(etiqueta),
      ),
    );
    return Semantics(
      button: true,
      label: etiqueta,
      excludeSemantics: true,
      onTap: alTocar,
      child: expandido ? SizedBox(width: double.infinity, child: boton) : boton,
    );
  }
}

/// Contador grande de **días libres** con racha actual, mejor racha y días
/// acumulados (regla 41). Una recaída pone en 0 la actual sin tocar las otras;
/// el contador no se pinta de rojo ni dice "perdiste".
class ContadorDiasLibres extends StatelessWidget {
  const ContadorDiasLibres({
    super.key,
    required this.rachaActual,
    this.mejorRacha,
    this.acumulados,
  });

  final int rachaActual;
  final int? mejorRacha;
  final int? acumulados;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    return Semantics(
      container: true,
      label: 'Días libres',
      value: [
        '$rachaActual ${rachaActual == 1 ? 'día' : 'días'} seguidos',
        if (mejorRacha != null) 'mejor racha $mejorRacha',
        if (acumulados != null) '$acumulados acumulados',
      ].join(', '),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              '$rachaActual',
              style: v.titulo(tamano: 56, color: v.textoFuerte),
              maxLines: 1,
            ),
          ),
          Text(
            rachaActual == 1 ? 'día libre seguido' : 'días libres seguidos',
            style: v.lectura(tamano: 14, color: v.textoTenue),
          ),
          SizedBox(height: e),
          Wrap(
            spacing: e * 2,
            runSpacing: e * 0.5,
            children: [
              if (mejorRacha != null)
                Text(
                  'Mejor racha: $mejorRacha',
                  style: v.lectura(tamano: 13, color: v.texto),
                ),
              if (acumulados != null)
                Text(
                  'Acumulados: $acumulados',
                  style: v.lectura(tamano: 13, color: v.texto),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Panel de un hábito a eliminar (G.10.3), por fase. El contenido sensible
/// (nombre, cifras) se oculta solo; **Registrar** y **Pausa** quedan siempre
/// visibles. En la línea base no hay metas ni semáforo ("Solo observamos").
class PanelHabitoEliminar extends StatelessWidget {
  const PanelHabitoEliminar({
    super.key,
    required this.nombre,
    required this.fase,
    this.estadoHoyTexto,
    this.preguntaSuave,
    this.rachaActual,
    this.mejorRacha,
    this.diasLibresAcumulados,
    this.diasParaDiaD,
    this.semaforo,
    this.alRegistrar,
    this.alAntojo,
    this.etiquetaPausa = 'Pausa',
  });

  final String nombre;
  final FaseHabito fase;

  /// "Hoy: 4 de 6", "Cero hoy".
  final String? estadoHoyTexto;

  /// Cuando se pasa el límite: "¿Qué te ayudaría mañana?" (sin rojo).
  final String? preguntaSuave;
  final int? rachaActual;
  final int? mejorRacha;
  final int? diasLibresAcumulados;
  final int? diasParaDiaD;

  /// Por ejemplo, un [SemaforoRefresco] (azúcar).
  final Widget? semaforo;
  final VoidCallback? alRegistrar;
  final VoidCallback? alAntojo;
  final String etiquetaPausa;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final contenido = DecoratedBox(
      decoration: BoxDecoration(
        color: v.panel,
        border: Border.all(color: v.borde),
        borderRadius: BorderRadius.circular(v.radioMediano),
      ),
      child: Padding(
        padding: EdgeInsets.all(e * 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextoSensible(
              nombre,
              estilo: v.titulo(tamano: 20, color: v.textoFuerte),
            ),
            SizedBox(height: e * 0.5),
            Wrap(
              spacing: e,
              runSpacing: e * 0.5,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _EtiquetaFase(fase: fase),
                Text(
                  fase.mensaje,
                  style: v.lectura(tamano: 13, color: v.textoTenue),
                ),
              ],
            ),
            if (estadoHoyTexto != null) ...[
              SizedBox(height: e * 1.5),
              TextoSensible(
                estadoHoyTexto!,
                estilo: v.numero(
                  tamano: 22,
                  peso: FontWeight.w600,
                  color: v.textoFuerte,
                ),
              ),
            ],
            if (preguntaSuave != null)
              Padding(
                padding: EdgeInsets.only(top: e * 0.5),
                child: Text(
                  preguntaSuave!,
                  style: v.lectura(tamano: 14, color: v.textoTenue),
                ),
              ),
            if (fase.cuentaDiasLibres && rachaActual != null) ...[
              SizedBox(height: e * 2),
              ContadorDiasLibres(
                rachaActual: rachaActual!,
                mejorRacha: mejorRacha,
                acumulados: diasLibresAcumulados,
              ),
            ],
            if (fase.conMetas && semaforo != null) ...[
              SizedBox(height: e * 1.5),
              semaforo!,
            ],
            if (diasParaDiaD != null && diasParaDiaD! > 0 && fase.conMetas) ...[
              SizedBox(height: e * 1.5),
              Text(
                diasParaDiaD == 1
                    ? 'Mañana es el Día D'
                    : 'Faltan $diasParaDiaD días para el Día D',
                style: v.lectura(tamano: 14, color: v.texto),
              ),
            ],
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        BloqueSensible(child: contenido),
        SizedBox(height: e * 1.5),
        Wrap(
          spacing: e,
          runSpacing: e,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: OutlinedButton(
                onPressed: alRegistrar,
                child: const Text('Registrar'),
              ),
            ),
            BotonPausa(alTocar: alAntojo, etiqueta: etiquetaPausa),
          ],
        ),
      ],
    );
  }
}

class _EtiquetaFase extends StatelessWidget {
  const _EtiquetaFase({required this.fase});

  final FaseHabito fase;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: v.acento),
        borderRadius: BorderRadius.circular(v.radioChico),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: v.espacio, vertical: 2),
        child: Text(
          fase.etiqueta,
          style: v.lectura(
            tamano: 12.5,
            peso: FontWeight.w600,
            color: v.textoFuerte,
          ),
        ),
      ),
    );
  }
}

/// Respiración guiada: un círculo que crece al inhalar y se encoge al exhalar,
/// siempre con el texto "Inhala" / "Exhala". Con "reducir movimiento" no se
/// anima: solo el texto con el ritmo.
class RespiracionGuiada extends StatefulWidget {
  const RespiracionGuiada({
    super.key,
    this.segundosPorFase = 4,
    this.diametro = 160,
  });

  final int segundosPorFase;
  final double diametro;

  @override
  State<RespiracionGuiada> createState() => _RespiracionGuiadaState();
}

class _RespiracionGuiadaState extends State<RespiracionGuiada>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(seconds: widget.segundosPorFase),
  );
  bool _iniciada = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final quieto = MediaQuery.disableAnimationsOf(context);
    if (quieto) {
      _c.stop();
      _iniciada = false;
    } else if (!_iniciada) {
      _iniciada = true;
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final quieto = MediaQuery.disableAnimationsOf(context);
    final s = widget.segundosPorFase;
    if (quieto) {
      return Semantics(
        label: 'Respiración guiada',
        value: 'Inhala $s segundos, exhala $s segundos',
        excludeSemantics: true,
        child: Text(
          'Inhala $s segundos · exhala $s segundos',
          textAlign: TextAlign.center,
          style: v.lectura(tamano: 18, color: v.textoFuerte),
        ),
      );
    }
    return Semantics(
      label: 'Respiración guiada',
      value: 'Inhala $s segundos, exhala $s segundos',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final inhala = _c.status != AnimationStatus.reverse;
          final t = Curves.easeInOut.transform(_c.value);
          final d = widget.diametro * (0.55 + 0.45 * t);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: widget.diametro,
                height: widget.diametro,
                child: Center(
                  child: Container(
                    width: d,
                    height: d,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color.alphaBlend(
                        v.acento.withValues(alpha: 0.18),
                        v.panel,
                      ),
                      border: Border.all(color: v.acento, width: 2),
                    ),
                  ),
                ),
              ),
              SizedBox(height: v.espacio),
              Text(
                inhala ? 'Inhala' : 'Exhala',
                style: v.lectura(
                  tamano: 20,
                  peso: FontWeight.w600,
                  color: v.textoFuerte,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Temporizador del SOS (por omisión 10 minutos; de 5 a 15). Al llegar a cero
/// pregunta "¿Sigue el antojo?" con *Sigue* y *Ya pasó*. Funciona sin señal.
class TemporizadorSos extends StatefulWidget {
  const TemporizadorSos({
    super.key,
    this.duracion = const Duration(minutes: 10),
    this.alSigue,
    this.alYaPaso,
  });

  final Duration duracion;
  final VoidCallback? alSigue;
  final VoidCallback? alYaPaso;

  @override
  State<TemporizadorSos> createState() => _TemporizadorSosState();
}

class _TemporizadorSosState extends State<TemporizadorSos> {
  late int _restante = widget.duracion.inSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  void _iniciar() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_restante <= 1) {
        t.cancel();
        setState(() => _restante = 0);
      } else {
        setState(() => _restante--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// "09:41".
  static String texto(int segundos) =>
      '${(segundos ~/ 60).toString().padLeft(2, '0')}:'
      '${(segundos % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final minutos = widget.duracion.inMinutes;
    if (_restante == 0) {
      return Semantics(
        container: true,
        liveRegion: true,
        label: '¿Sigue el antojo?',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¿Sigue el antojo?',
              textAlign: TextAlign.center,
              style: v.titulo(tamano: 22, color: v.textoFuerte),
            ),
            SizedBox(height: e * 2),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: e,
              runSpacing: e,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: OutlinedButton(
                    onPressed: widget.alSigue,
                    child: const Text('Sigue'),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: FilledButton(
                    onPressed: widget.alYaPaso,
                    child: const Text('Ya pasó'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    return Semantics(
      container: true,
      label: 'Temporizador',
      value: 'Quedan ${(_restante / 60).ceil()} minutos',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            texto(_restante),
            style: v.numero(
              tamano: 48,
              peso: FontWeight.w600,
              color: v.textoFuerte,
            ),
          ),
          SizedBox(height: e),
          Text(
            'Si en $minutos minutos sigue, repetimos.',
            textAlign: TextAlign.center,
            style: v.lectura(tamano: 14, color: v.textoTenue),
          ),
        ],
      ),
    );
  }
}
