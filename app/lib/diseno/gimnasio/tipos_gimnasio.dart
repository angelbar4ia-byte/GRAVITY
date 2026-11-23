/// Tipos de **presentación** de «Mi gimnasio»: datos ya calculados que las
/// pantallas entregan a los componentes. No importan el dominio de Hábitos:
/// quien arma la pantalla (G5) convierte lo que calcula el dominio a estos
/// tipos simples. Cada estado lleva **icono y palabra**, nunca solo color.
library;

import 'package:flutter/material.dart';

/// Qué muestra un componente: su contenido o uno de los cuatro estados de
/// pantalla (`DISENO_UX_UI.md:49`). Sin reintentos automáticos: el botón
/// *Reintentar* lo toca la persona.
enum EstadoVistaGimnasio {
  /// Con contenido.
  listo,

  /// Sin datos todavía; con una sola acción sugerida.
  vacio,

  /// Esperando datos.
  cargando,

  /// Sin red: la sesión funciona igual, solo se avisa (9.1).
  sinConexion,

  /// Algo falló; sin culpa y con *Reintentar*.
  error,
}

/// Estado de confirmación de un dato del equipo (3.1): lo que la app **no**
/// puede dar por cierto hasta que la persona lo verifica en el aparato.
enum EstadoConfirmacionDato {
  /// Está en el diseño v1.18: orientación, con la marca «aprox.».
  delDiseno('Aprox., según el distribuidor', Icons.info_outline),

  /// Falta verificarlo («confirmar en el aparato»): no entra a ningún
  /// cálculo.
  confirmar('Sin confirmar', Icons.fact_check_outlined),

  /// La persona lo verificó y lo escribió.
  confirmado('Confirmado', Icons.check_circle_outline);

  const EstadoConfirmacionDato(this.texto, this.icono);

  final String texto;
  final IconData icono;
}

/// Si un aparato, puesto o accesorio cuenta para armar sesiones (4.2).
enum DisponibilidadAparato {
  disponible('Disponible', Icons.check_circle_outline),
  noDisponible('No disponible', Icons.block),

  /// Solo dato: no genera nada hasta que se tenga.
  futuro('Cuando lo tengas', Icons.schedule);

  const DisponibilidadAparato(this.texto, this.icono);

  final String texto;
  final IconData icono;
}

/// Estado de una serie dentro de la sesión (10: icono y texto).
enum EstadoSerie {
  pendiente('Pendiente', Icons.radio_button_unchecked),
  actual('Ahora', Icons.play_circle_outline),
  hecha('Hecha', Icons.check_circle),
  enDescanso('En descanso', Icons.timer_outlined),
  conPrecaucion('Con precaución', Icons.warning_amber_outlined),
  omitida('Omitida', Icons.remove_circle_outline);

  const EstadoSerie(this.texto, this.icono);

  final String texto;
  final IconData icono;
}

/// Una serie planeada o hecha, para los chips de la sesión.
@immutable
class SerieVista {
  const SerieVista({
    required this.numero,
    required this.estado,
    this.repeticiones,
    this.cargaTexto,
  });

  /// 1, 2, 3…
  final int numero;
  final EstadoSerie estado;

  /// Repeticiones planeadas o hechas; `null` si es por tiempo.
  final int? repeticiones;

  /// «placa 3», «banda verde»; `null` sin carga.
  final String? cargaTexto;
}

/// Lo que toca un día del plan semanal (5.6).
enum TipoDiaPlan {
  fuerzaA('Fuerza A', 'A', Icons.fitness_center),
  fuerzaB('Fuerza B', 'B', Icons.fitness_center),
  fuerzaC('Fuerza C', 'C', Icons.fitness_center),
  regenerativa1('Regenerativa 1', 'R1', Icons.self_improvement),
  regenerativa2('Regenerativa 2', 'R2', Icons.self_improvement),
  bicicleta('Bicicleta', 'Bici', Icons.directions_bike),
  descanso('Descanso', 'Libre', Icons.bedtime_outlined);

  const TipoDiaPlan(this.texto, this.codigo, this.icono);

  /// Nombre completo («Fuerza A»).
  final String texto;

  /// Código corto para la tira de la semana («A», «R1», «Bici»).
  final String codigo;
  final IconData icono;

  /// Si es una sesión de fuerza (A, B o C).
  bool get esFuerza => this == fuerzaA || this == fuerzaB || this == fuerzaC;
}

/// Cómo va un día del plan.
enum EstadoDiaPlan {
  pendiente('Pendiente', Icons.radio_button_unchecked),
  hecho('Hecho', Icons.check_circle_outline),
  parcial('Hecho a medias', Icons.timelapse),
  saltado('Saltado', Icons.remove_circle_outline);

  const EstadoDiaPlan(this.texto, this.icono);

  final String texto;
  final IconData icono;
}

/// Tipo de semana del ciclo (4.4): sirve para que una caída de carga **no se
/// lea como retroceso**.
enum TipoSemanaVista {
  carga('Carga', Icons.fitness_center),
  descarga('Descarga', Icons.spa_outlined),
  reentrada('Reentrada', Icons.replay),
  foco('Foco', Icons.filter_center_focus);

  const TipoSemanaVista(this.texto, this.icono);

  final String texto;
  final IconData icono;
}

/// Intensidad de una molestia que la persona registró (5.10).
enum NivelMolestia {
  leve('Leve', Icons.looks_one_outlined),
  moderada('Moderada', Icons.looks_two_outlined),
  fuerte('Fuerte', Icons.looks_3_outlined);

  const NivelMolestia(this.texto, this.icono);

  final String texto;
  final IconData icono;
}

/// Qué récord es (6.2).
enum TipoRecordVista {
  mejorCarga('Mejor carga', Icons.fitness_center),
  mejoresRepeticiones('Más repeticiones', Icons.repeat),
  mejorTiempo('Mejor tiempo', Icons.timer_outlined),
  mejorBanda('Mejor banda', Icons.linear_scale);

  const TipoRecordVista(this.texto, this.icono);

  final String texto;
  final IconData icono;
}

/// Unidad de la carga de un ejercicio (3.2): pasos de la pila (placas) o
/// bandas. El peso corporal no tiene selector.
enum UnidadCarga {
  placa('placa', 'Quitar una placa', 'Poner una placa más'),
  banda('banda', 'Banda anterior', 'Banda siguiente');

  const UnidadCarga(this.palabra, this.textoMenos, this.textoMas);

  /// «placa» o «banda».
  final String palabra;

  /// Etiqueta accesible del botón −.
  final String textoMenos;

  /// Etiqueta accesible del botón +.
  final String textoMas;
}
