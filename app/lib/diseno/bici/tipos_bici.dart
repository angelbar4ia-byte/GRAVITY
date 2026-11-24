/// Tipos de **presentación** de «Bicicleta»: datos ya calculados que las
/// pantallas entregan a los componentes. No importan el dominio de Hábitos:
/// quien arma la pantalla (B5) convierte lo que calcula el dominio a estos
/// tipos simples. Cada estado lleva **icono y palabra**, nunca solo color.
library;

import 'package:flutter/material.dart';

/// Qué muestra un componente: su contenido o uno de los cuatro estados de
/// pantalla (`DISENO_UX_UI.md:49`). Sin reintentos automáticos: el botón
/// *Reintentar* lo toca la persona.
enum EstadoVistaBici {
  /// Con contenido.
  listo,

  /// Sin datos todavía; con una sola acción sugerida.
  vacio,

  /// Esperando datos.
  cargando,

  /// Sin red: la bicicleta funciona igual, solo se avisa (RB7).
  sinConexion,

  /// Algo falló; sin culpa y con *Reintentar*.
  error,
}

/// En qué momento está la tarjeta de Hoy (6.1, B1).
enum MomentoSalida {
  /// Viernes en la noche: «Prepara tu salida».
  vispera,

  /// Sábado, antes de salir: *Salí* o *Empezar*.
  diaDeSalida,

  /// Con el cronómetro corriendo.
  enCurso,

  /// Ya registrada.
  hecha,

  /// No salió (por clima, seguridad u otra razón): sin mensaje de ruptura.
  omitida,
}

/// Estado de un punto de la lista de preparación (6.6: «Casco, marcado» o
/// «Casco, pendiente»).
enum EstadoPunto {
  pendiente('Pendiente', Icons.radio_button_unchecked),
  marcado('Marcado', Icons.check_circle);

  const EstadoPunto(this.texto, this.icono);

  final String texto;
  final IconData icono;
}

/// En qué momento se revisa la lista (4.2).
enum MomentoPreparacion {
  vispera('Viernes en la noche', Icons.nights_stay_outlined),
  antesDeSalir('Antes de salir', Icons.directions_bike);

  const MomentoPreparacion(this.texto, this.icono);

  final String texto;
  final IconData icono;
}

/// A qué tipo de ruta aplica un punto (4.2).
enum AmbitoPunto {
  todas('', Icons.checklist),
  calle('Solo en calle', Icons.traffic_outlined),
  terreno('Solo en terreno', Icons.terrain);

  const AmbitoPunto(this.texto, this.icono);

  /// Vacío si aplica siempre.
  final String texto;
  final IconData icono;
}

/// La superficie de toda la salida (4.5).
enum SuperficieSalida {
  calle('Calle', Icons.add_road),
  terreno('Terreno', Icons.terrain),
  mixta('Mixta', Icons.alt_route);

  const SuperficieSalida(this.texto, this.icono);

  final String texto;
  final IconData icono;
}

/// Las cinco casillas de clima (4.3). Ninguna bloquea nada.
enum ClimaBici {
  despejado('Despejado', Icons.wb_sunny_outlined),
  nublado('Nublado', Icons.cloud_outlined),
  lluvia('Posible lluvia', Icons.water_drop_outlined),
  calor('Mucho calor', Icons.thermostat),
  frio('Frío', Icons.ac_unit);

  const ClimaBici(this.texto, this.icono);

  final String texto;
  final IconData icono;
}

/// Si la salida cabe antes de la revisión semanal (4.7).
enum EncajeRevision {
  cabe('Cabe', Icons.check_circle_outline),
  cabeJusto('Cabe justo', Icons.timelapse),
  noCabe('No cabe', Icons.event_busy_outlined);

  const EncajeRevision(this.texto, this.icono);

  final String texto;
  final IconData icono;
}

/// Estado de una tarea de mantenimiento (4.8). **Nunca «vencida»**: sin
/// ningún registro es «sin registro», y «toca» no bloquea nada.
enum EstadoTarea {
  alDia('Al día', Icons.check_circle_outline),
  toca('Toca', Icons.build_outlined),
  sinRegistro('Sin registro', Icons.help_outline);

  const EstadoTarea(this.texto, this.icono);

  final String texto;
  final IconData icono;
}

/// A qué app externa apunta un enlace (3.1 y 3.12).
enum TipoEnlace {
  musica('Música', Icons.music_note_outlined),
  mapa('Mapa', Icons.map_outlined),
  clima('Clima', Icons.cloud_outlined);

  const TipoEnlace(this.texto, this.icono);

  final String texto;
  final IconData icono;
}

/// Cómo cuenta la ruta para la regla de 48 horas (4.6).
enum CargaPiernas {
  normal('Normal', Icons.fitness_center),
  ligera('Ligera', Icons.air),
  porEsfuerzo('Por esfuerzo', Icons.speed);

  const CargaPiernas(this.texto, this.icono);

  final String texto;
  final IconData icono;
}
