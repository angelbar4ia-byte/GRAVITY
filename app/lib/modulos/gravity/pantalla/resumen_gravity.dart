/// Datos que muestran la pantalla principal de GRAVITY y "Hoy" del teléfono.
///
/// En la Fase 0 son **datos de ejemplo** (nunca datos reales). Cuando existan
/// las herramientas de cada módulo (`habitos.resumen_hoy`, etc.), se reemplaza
/// [resumenGravityProvider] sin tocar las pantallas:
/// `resumenGravityProvider.overrideWith((ref) => ...)`.
///
/// Si un rol no puede ver dinero o cuidados, el campo va en `null` y el panel no
/// aparece (principio 3: nada de paneles vacíos ni bloqueados).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../diseno/componentes/nucleo_gravity.dart';
import '../../../diseno/componentes/semaforo.dart';
import '../../../nucleo/contratos/roles.dart';

@immutable
class EventoAgenda {
  const EventoAgenda(this.hora, this.titulo);

  /// "20:00" o un día ("VIE").
  final String hora;
  final String titulo;
}

@immutable
class HabitoDeHoy {
  const HabitoDeHoy(this.nombre, {this.hecho = false});

  final String nombre;
  final bool hecho;
}

@immutable
class SiguienteActividad {
  const SiguienteActividad({
    required this.hora,
    required this.titulo,
    this.detalle,
  });

  final String hora;
  final String titulo;
  final String? detalle;
}

@immutable
class PendienteCuidados {
  const PendienteCuidados(this.texto, this.estado, {this.atencion = false});

  /// Texto genérico, sin nombres de medicamentos ni datos clínicos.
  final String texto;

  /// "Pendiente", "1 nota".
  final String estado;

  /// Si requiere atención (se marca con el color de alerta y el texto).
  final bool atencion;
}

@immutable
class ResumenCuidados {
  const ResumenCuidados({
    required this.turno,
    this.pendientes = const [],
    this.avisoNucleo,
  });

  /// "Cuidadora · hasta 20:00".
  final String turno;
  final List<PendienteCuidados> pendientes;

  /// Frase genérica para el saludo del núcleo
  /// ("a las 20:00 hay un medicamento en el turno").
  final String? avisoNucleo;
}

@immutable
class ResumenFinanzasSemana {
  const ResumenFinanzasSemana({
    required this.estado,
    required this.presupuestoCentavos,
    required this.gastadoCentavos,
    this.aviso,
  });

  final EstadoSemaforo estado;
  final int presupuestoCentavos;
  final int gastadoCentavos;

  /// Aviso sin montos ("El viernes vence la tarjeta de crédito").
  final String? aviso;

  int get quedanCentavos => presupuestoCentavos - gastadoCentavos;

  /// Fracción usada del presupuesto (0 a 1 o más).
  double get usado =>
      presupuestoCentavos <= 0 ? 0 : gastadoCentavos / presupuestoCentavos;
}

enum TipoAviso { informacion, atencion, hecho }

@immutable
class AvisoGravity {
  const AvisoGravity(this.cuando, this.texto, {this.tipo = TipoAviso.informacion});

  final String cuando;
  final String texto;
  final TipoAviso tipo;
}

@immutable
class ResumenGravity {
  const ResumenGravity({
    this.enLinea = true,
    this.agenda = const [],
    this.habitos = const [],
    this.siguiente,
    this.cuidados,
    this.finanzas,
    this.avisos = const [],
  });

  final bool enLinea;
  final List<EventoAgenda> agenda;
  final List<HabitoDeHoy> habitos;
  final SiguienteActividad? siguiente;

  /// `null` si el rol no ve Cuidados.
  final ResumenCuidados? cuidados;

  /// `null` si el rol no ve dinero.
  final ResumenFinanzasSemana? finanzas;
  final List<AvisoGravity> avisos;

  int get habitosHechos => habitos.where((h) => h.hecho).length;
  int get habitosTotal => habitos.length;

  /// Datos de ejemplo de los bocetos (no son datos reales).
  static const ejemplo = ResumenGravity(
    agenda: [
      EventoAgenda('20:00', 'Inglés · lección del día'),
      EventoAgenda('21:00', 'Fuerza · 45 min'),
      EventoAgenda('22:30', 'A dormir · transición'),
    ],
    habitos: [
      HabitoDeHoy('Devocional', hecho: true),
      HabitoDeHoy('Agua', hecho: true),
      HabitoDeHoy('Lectura', hecho: true),
      HabitoDeHoy('Fuerza'),
      HabitoDeHoy('Inglés'),
    ],
    siguiente: SiguienteActividad(
      hora: '20:00',
      titulo: 'Inglés: lección del día',
      detalle: '50 min · bloque principal',
    ),
    cuidados: ResumenCuidados(
      turno: 'Cuidadora · hasta 20:00',
      pendientes: [
        PendienteCuidados('Medicamento 20:00', 'Pendiente', atencion: true),
        PendienteCuidados('Entrega de turno', '1 nota'),
      ],
      avisoNucleo: 'a las 20:00 hay un medicamento en el turno',
    ),
    finanzas: ResumenFinanzasSemana(
      estado: EstadoSemaforo.verde,
      presupuestoCentavos: 350000,
      gastadoCentavos: 217000,
      aviso: 'El viernes vence la tarjeta de crédito',
    ),
    avisos: [
      AvisoGravity(
        'VIE',
        'Vence la tarjeta de crédito',
        tipo: TipoAviso.atencion,
      ),
      AvisoGravity('SÁB 14:30', 'Revisión semanal'),
      AvisoGravity('03:00', 'Copia de seguridad hecha', tipo: TipoAviso.hecho),
    ],
  );
}

/// Resumen que muestran las pantallas. Fase 0: datos de ejemplo.
final resumenGravityProvider = Provider<ResumenGravity>(
  (ref) => ResumenGravity.ejemplo,
);

/// Módulos de la barra de módulos. Plataforma lo reemplaza con los que permite
/// el rol (espejo de la matriz de permisos).
final modulosBarraProvider = Provider<List<Modulo>>(
  (ref) => const [
    Modulo.finanzas,
    Modulo.habitos,
    Modulo.cuidados,
    Modulo.alimentacion,
    Modulo.casa,
    Modulo.ajustes,
  ],
);

/// Estado que muestra el núcleo. El asistente lo reemplaza cuando haya voz.
final estadoNucleoProvider = Provider<EstadoNucleo>(
  (ref) => EstadoNucleo.enEspera,
);
