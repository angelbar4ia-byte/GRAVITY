/// Gadgets de módulos que llegan en fases futuras, **solo de diseño** (P4 de la
/// Fase 4): se ven y se prueban con datos de ejemplo, sin lógica, sin base de
/// datos y sin rutas. Cada fase los conecta cuando construya su módulo.
///
/// - Cuidados (Fase 5): [RelojDelTurno] y [CronometroCuidados]. Textos
///   impersonales; la personalidad de Cuidados los lleva a alto contraste.
/// - Alimentación (Fase 7): [ListaCompras] y [MenuSemana], sin precios.
/// - Hábitos (Fase 8): [Velocimetro] y [SerieDescanso].
///
/// Todos leen colores, fuentes y formas del tema; ninguno usa valores fijos.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../componentes/barra_progreso.dart';
import '../componentes/tarjeta_modulo.dart';
import '../superficies.dart';
import '../valores_diseno.dart';

String _mmss(Duration d) {
  final minutos = d.inMinutes.toString().padLeft(2, '0');
  final segundos = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutos:$segundos';
}

String _hhmm(int minutosDelDia) =>
    '${(minutosDelDia ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutosDelDia % 60).toString().padLeft(2, '0')}';

/// Anillo de avance con la pista y el avance del tema (3:1 entre sí).
class _Anillo extends CustomPainter {
  _Anillo({
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
    final rect = Offset.zero & size;
    final area = rect.deflate(grosor / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(area, 0, 2 * math.pi, false, base..color = pista);
    canvas.drawArc(
      area,
      -math.pi / 2,
      2 * math.pi * avance.clamp(0.0, 1.0),
      false,
      base..color = color,
    );
  }

  @override
  bool shouldRepaint(_Anillo old) =>
      old.avance != avance ||
      old.color != color ||
      old.pista != pista ||
      old.grosor != grosor;
}

// --- Cuidados ----------------------------------------------------------------

/// **Reloj del turno** (Cuidados): ¿quién está de turno y qué sigue? Muestra
/// quién, el horario, cuánto falta y la siguiente tarea. Textos impersonales.
class RelojDelTurno extends StatelessWidget {
  const RelojDelTurno({
    super.key,
    required this.persona,
    required this.inicioMin,
    required this.finMin,
    required this.ahoraMin,
    required this.siguiente,
    this.horaSiguienteMin,
  });

  /// Datos de ejemplo (ninguna persona real).
  factory RelojDelTurno.ejemplo({Key? key}) => RelojDelTurno(
    key: key,
    persona: 'Persona de ejemplo',
    inicioMin: 8 * 60,
    finMin: 20 * 60,
    ahoraMin: 14 * 60 + 30,
    siguiente: 'Medicamento de la tarde',
    horaSiguienteMin: 16 * 60,
  );

  final String persona;
  final int inicioMin;
  final int finMin;
  final int ahoraMin;
  final String siguiente;
  final int? horaSiguienteMin;

  double get avance =>
      ((ahoraMin - inicioMin) / (finMin - inicioMin)).clamp(0.0, 1.0);

  Duration get falta => Duration(minutes: (finMin - ahoraMin).clamp(0, 1440));

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final hora = horaSiguienteMin == null
        ? ''
        : ' a las ${_hhmm(horaSiguienteMin!)}';
    final falta = this.falta;
    final textoFalta = 'Faltan ${falta.inHours} h ${falta.inMinutes % 60} min';
    return Semantics(
      container: true,
      label:
          'Reloj del turno. De turno: $persona, de ${_hhmm(inicioMin)} a '
          '${_hhmm(finMin)}. $textoFalta. Sigue: $siguiente$hora.',
      excludeSemantics: true,
      child: TarjetaModulo(
        titulo: 'Turno',
        icono: Icons.schedule,
        child: Row(
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: CustomPaint(
                painter: _Anillo(
                  avance: avance,
                  color: v.acento,
                  pista: v.pista,
                  grosor: 10,
                ),
                child: Center(
                  child: Text(
                    '${(avance * 100).round()} %',
                    style: v.numero(
                      tamano: 18,
                      peso: FontWeight.w600,
                      color: v.textoFuerte,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: e * 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    persona,
                    style: v.titulo(tamano: 20),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${_hhmm(inicioMin)} a ${_hhmm(finMin)} · $textoFalta',
                    style: v.lectura(tamano: 14, color: v.textoTenue),
                  ),
                  SizedBox(height: e),
                  Text(
                    'Sigue: $siguiente$hora',
                    style: v.lectura(
                      tamano: 15,
                      peso: FontWeight.w600,
                      color: v.textoFuerte,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// **Cronómetro** (Cuidados): para medir una toma o una actividad. Cifras
/// grandes y tres botones de 56 dp. Solo diseño: los callbacks los conecta
/// la fase 5.
class CronometroCuidados extends StatelessWidget {
  const CronometroCuidados({
    super.key,
    required this.tiempo,
    this.corriendo = false,
    this.alAlternar,
    this.alReiniciar,
  });

  factory CronometroCuidados.ejemplo({Key? key}) => CronometroCuidados(
    key: key,
    tiempo: const Duration(minutes: 3, seconds: 27),
  );

  final Duration tiempo;
  final bool corriendo;
  final VoidCallback? alAlternar;
  final VoidCallback? alReiniciar;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    return TarjetaModulo(
      titulo: 'Cronómetro',
      icono: Icons.timer_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label:
                'Cronómetro: ${tiempo.inMinutes} minutos '
                '${tiempo.inSeconds % 60} segundos, '
                '${corriendo ? 'en marcha' : 'detenido'}',
            excludeSemantics: true,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _mmss(tiempo),
                key: const ValueKey('cronometro-tiempo'),
                style: v.numero(
                  tamano: 56,
                  peso: FontWeight.w700,
                  color: v.textoFuerte,
                ),
              ),
            ),
          ),
          SizedBox(height: e * 1.5),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: e * 1.5,
            runSpacing: e,
            children: [
              FilledButton.icon(
                key: const ValueKey('cronometro-alternar'),
                style: FilledButton.styleFrom(minimumSize: const Size(120, 56)),
                onPressed: alAlternar ?? () {},
                icon: Icon(corriendo ? Icons.pause : Icons.play_arrow),
                label: Text(corriendo ? 'Pausar' : 'Iniciar'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('cronometro-reiniciar'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(120, 56),
                ),
                onPressed: alReiniciar ?? () {},
                icon: const Icon(Icons.replay),
                label: const Text('Reiniciar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Alimentación -----------------------------------------------------------

/// Un renglón de la lista de compras (sin precios ni dinero).
class RenglonCompra {
  const RenglonCompra(this.nombre, {this.cantidad, this.hecho = false});

  final String nombre;
  final String? cantidad;
  final bool hecho;
}

/// **Lista de compras** (Alimentación): ¿qué falta? Letra grande, filas de
/// 56 dp que se pueden tocar con las manos ocupadas. El estado va con icono y
/// texto ("Pendiente" o "Listo"), nunca solo con el color.
class ListaCompras extends StatelessWidget {
  const ListaCompras({super.key, required this.renglones, this.alAlternar});

  factory ListaCompras.ejemplo({Key? key}) => ListaCompras(
    key: key,
    renglones: const [
      RenglonCompra('Jitomate', cantidad: '1 kg', hecho: true),
      RenglonCompra('Avena', cantidad: '2 bolsas'),
      RenglonCompra('Leche', cantidad: '3 litros'),
      RenglonCompra('Huevo', cantidad: '1 caja', hecho: true),
      RenglonCompra('Limones', cantidad: '6'),
    ],
  );

  final List<RenglonCompra> renglones;
  final ValueChanged<int>? alAlternar;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final hechos = renglones.where((r) => r.hecho).length;
    return TarjetaModulo(
      titulo: 'Lista de compras',
      icono: Icons.shopping_basket_outlined,
      accion: Text(
        '$hechos de ${renglones.length}',
        style: v.numero(tamano: 14, color: v.textoTenue),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BarraProgreso(
            valor: renglones.isEmpty ? 0 : hechos / renglones.length,
            textoValor: '$hechos de ${renglones.length} comprados',
          ),
          for (var i = 0; i < renglones.length; i++)
            _FilaCompra(
              renglon: renglones[i],
              alTocar: alAlternar == null ? null : () => alAlternar!(i),
            ),
        ],
      ),
    );
  }
}

class _FilaCompra extends StatelessWidget {
  const _FilaCompra({required this.renglon, this.alTocar});

  final RenglonCompra renglon;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final estado = renglon.hecho ? 'Listo' : 'Pendiente';
    final cantidad = renglon.cantidad == null ? '' : ', ${renglon.cantidad}';
    final detalle = renglon.cantidad == null
        ? estado
        : '${renglon.cantidad} · $estado';
    return Semantics(
      container: true,
      button: alTocar != null,
      checked: renglon.hecho,
      label: '${renglon.nombre}$cantidad. $estado',
      excludeSemantics: true,
      onTap: alTocar,
      child: InkWell(
        onTap: alTocar,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(
            children: [
              Icon(
                renglon.hecho
                    ? Icons.check_circle_outline
                    : Icons.radio_button_unchecked,
                color: renglon.hecho ? v.exito : v.textoTenue,
              ),
              SizedBox(width: v.espacio * 1.5),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: v.espacio * 0.5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        renglon.nombre,
                        style: v
                            .lectura(
                              tamano: 18,
                              peso: FontWeight.w600,
                              color: renglon.hecho
                                  ? v.textoTenue
                                  : v.textoFuerte,
                            )
                            .copyWith(
                              decoration: renglon.hecho
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                      ),
                      Text(
                        detalle,
                        style: v.lectura(tamano: 14, color: v.textoTenue),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un día del menú de la semana.
class DiaMenu {
  const DiaMenu(this.dia, this.comida, this.cena);

  final String dia;
  final String comida;
  final String cena;
}

/// **Menú de la semana** (Alimentación): ¿qué comemos? Siete días, hoy marcado
/// con la palabra "Hoy" y un icono, además del color.
class MenuSemana extends StatelessWidget {
  const MenuSemana({super.key, required this.dias, required this.hoy});

  factory MenuSemana.ejemplo({Key? key}) => MenuSemana(
    key: key,
    hoy: 2,
    dias: const [
      DiaMenu('Lunes', 'Lentejas con arroz', 'Quesadillas'),
      DiaMenu('Martes', 'Pollo con verduras', 'Avena con fruta'),
      DiaMenu('Miércoles', 'Sopa de verdura', 'Huevo con frijoles'),
      DiaMenu('Jueves', 'Pescado al horno', 'Ensalada'),
      DiaMenu('Viernes', 'Pasta con jitomate', 'Sándwich'),
      DiaMenu('Sábado', 'Caldo de res', 'Tostadas'),
      DiaMenu('Domingo', 'Arroz con huevo', 'Fruta y yogur'),
    ],
  );

  final List<DiaMenu> dias;

  /// Índice del día de hoy en [dias].
  final int hoy;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    return TarjetaModulo(
      titulo: 'Menú de la semana',
      icono: Icons.restaurant_menu,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < dias.length; i++)
            Semantics(
              container: true,
              label:
                  '${dias[i].dia}${i == hoy ? ', hoy' : ''}. Comida: '
                  '${dias[i].comida}. Cena: ${dias[i].cena}.',
              excludeSemantics: true,
              child: Container(
                constraints: const BoxConstraints(minHeight: 56),
                margin: EdgeInsets.symmetric(vertical: v.espacio * 0.25),
                padding: EdgeInsets.symmetric(
                  horizontal: v.espacio * 1.5,
                  vertical: v.espacio,
                ),
                decoration: BoxDecoration(
                  color: i == hoy ? v.chipSeleccionado : null,
                  border: i == hoy
                      ? Border.all(color: v.acento, width: v.grosorBorde)
                      : null,
                  borderRadius: BorderRadius.circular(v.radioChico),
                ),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: v.espacio * 2,
                  runSpacing: v.espacio * 0.5,
                  children: [
                    SizedBox(
                      width: 104,
                      child: Row(
                        children: [
                          if (i == hoy) ...[
                            Icon(Icons.today, size: 16, color: v.acento),
                            SizedBox(width: v.espacio * 0.5),
                          ],
                          Flexible(
                            child: Text(
                              i == hoy ? 'Hoy' : dias[i].dia,
                              style: v.lectura(
                                tamano: 15,
                                peso: FontWeight.w700,
                                color: v.textoFuerte,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Comida: ${dias[i].comida}',
                      style: v.lectura(tamano: 15),
                    ),
                    Text(
                      'Cena: ${dias[i].cena}',
                      style: v.lectura(tamano: 15, color: v.textoTenue),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// --- Hábitos (bici y entrenamiento) ------------------------------------------

/// Arco del velocímetro: 240 grados, de la pista al avance.
class _ArcoVelocidad extends CustomPainter {
  _ArcoVelocidad({
    required this.fraccion,
    required this.color,
    required this.pista,
  });

  final double fraccion;
  final Color color;
  final Color pista;

  @override
  void paint(Canvas canvas, Size size) {
    const inicio = math.pi * 5 / 6; // 150 grados
    const barrido = math.pi * 4 / 3; // 240 grados
    final grosor = size.shortestSide * 0.09;
    final area = (Offset.zero & size).deflate(grosor / 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(area, inicio, barrido, false, p..color = pista);
    canvas.drawArc(
      area,
      inicio,
      barrido * fraccion.clamp(0.0, 1.0),
      false,
      p..color = color,
    );
  }

  @override
  bool shouldRepaint(_ArcoVelocidad old) =>
      old.fraccion != fraccion || old.color != color || old.pista != pista;
}

/// **Velocímetro y cronómetro** (bici): ¿a qué ritmo voy? Número enorme que se
/// lee de reojo; el arco es de apoyo y no lleva información que falte en el
/// número. Pensado para alto contraste (sol) y sin nada que leer en movimiento.
class Velocimetro extends StatelessWidget {
  const Velocimetro({
    super.key,
    required this.velocidadKmh,
    this.maximaKmh = 60,
    required this.tiempo,
    this.distanciaKm,
  });

  factory Velocimetro.ejemplo({Key? key}) => Velocimetro(
    key: key,
    velocidadKmh: 24,
    tiempo: const Duration(minutes: 41, seconds: 8),
    distanciaKm: 15.6,
  );

  final double velocidadKmh;
  final double maximaKmh;
  final Duration tiempo;
  final double? distanciaKm;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final distancia = distanciaKm == null
        ? ''
        : ' · ${distanciaKm!.toStringAsFixed(1)} km';
    return Semantics(
      container: true,
      label:
          'Velocímetro: ${velocidadKmh.round()} kilómetros por hora. '
          'Tiempo ${tiempo.inMinutes} minutos ${tiempo.inSeconds % 60} segundos'
          '${distanciaKm == null ? '' : ', ${distanciaKm!.toStringAsFixed(1)} kilómetros'}',
      excludeSemantics: true,
      child: TarjetaModulo(
        titulo: 'Bici',
        icono: Icons.directions_bike,
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1.4,
              child: CustomPaint(
                painter: _ArcoVelocidad(
                  fraccion: velocidadKmh / maximaKmh,
                  color: v.acento,
                  pista: v.pista,
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${velocidadKmh.round()}',
                          key: const ValueKey('velocimetro-valor'),
                          style: v.titulo(tamano: 96, peso: FontWeight.w700),
                        ),
                        Text(
                          'km/h',
                          style: v.lectura(tamano: 18, color: v.textoTenue),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: e),
            Text(
              '${_mmss(tiempo)}$distancia',
              style: v.numero(
                tamano: 28,
                peso: FontWeight.w700,
                color: v.textoFuerte,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// **Serie y descanso** (entrenamiento): ¿qué sigue y cuánto descanso?
class SerieDescanso extends StatelessWidget {
  const SerieDescanso({
    super.key,
    required this.ejercicio,
    required this.serie,
    required this.seriesTotales,
    required this.repeticiones,
    required this.descansoRestante,
    required this.descansoTotal,
    this.siguiente,
  });

  factory SerieDescanso.ejemplo({Key? key}) => SerieDescanso(
    key: key,
    ejercicio: 'Sentadilla',
    serie: 3,
    seriesTotales: 4,
    repeticiones: 10,
    descansoRestante: const Duration(seconds: 45),
    descansoTotal: const Duration(seconds: 90),
    siguiente: 'Peso muerto',
  );

  final String ejercicio;
  final int serie;
  final int seriesTotales;
  final int repeticiones;
  final Duration descansoRestante;
  final Duration descansoTotal;
  final String? siguiente;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final avance = descansoTotal.inSeconds == 0
        ? 0.0
        : 1 - descansoRestante.inSeconds / descansoTotal.inSeconds;
    return Semantics(
      container: true,
      label:
          '$ejercicio, serie $serie de $seriesTotales, $repeticiones '
          'repeticiones. Descanso: ${descansoRestante.inSeconds} segundos'
          '${siguiente == null ? '' : '. Sigue: $siguiente'}',
      excludeSemantics: true,
      child: TarjetaModulo(
        titulo: 'Serie y descanso',
        icono: Icons.fitness_center,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ejercicio,
                    style: v.titulo(tamano: 28),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Serie $serie de $seriesTotales · $repeticiones rep.',
                    style: v.lectura(
                      tamano: 16,
                      peso: FontWeight.w600,
                      color: v.textoFuerte,
                    ),
                  ),
                  if (siguiente != null) ...[
                    SizedBox(height: e),
                    Text(
                      'Sigue: $siguiente',
                      style: v.lectura(tamano: 14, color: v.textoTenue),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: e * 2),
            SizedBox(
              width: 104,
              height: 104,
              child: CustomPaint(
                painter: _Anillo(
                  avance: avance,
                  color: v.acento,
                  pista: v.pista,
                  grosor: 10,
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _mmss(descansoRestante),
                          key: const ValueKey('descanso-restante'),
                          style: v.numero(
                            tamano: 22,
                            peso: FontWeight.w700,
                            color: v.textoFuerte,
                          ),
                        ),
                        Text(
                          'descanso',
                          style: v.lectura(tamano: 12, color: v.textoTenue),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
