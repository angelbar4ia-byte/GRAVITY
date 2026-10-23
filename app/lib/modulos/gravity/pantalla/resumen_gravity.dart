/// Datos que muestran la pantalla principal de GRAVITY y "Hoy" del teléfono.
///
/// **Con una sesión real no hay cifras de ejemplo** (revisión de la Fase 1,
/// I9: "no se inventan datos"): mientras ningún módulo entregue su resumen, los
/// datos son [ResumenGravity.sinDatosTodavia] y las pantallas muestran un
/// estado vacío honesto ("Sin datos todavía"). Los **datos de ejemplo** de los
/// bocetos ([ResumenGravity.ejemplo], nunca datos reales) quedan solo para el
/// modo demostración (sin servidor) y las pruebas.
///
/// Cuando existan las herramientas de cada módulo (`finanzas.resumen_semana`,
/// `habitos.resumen_hoy`, etc.), se reemplaza [datosResumenGravityProvider] sin
/// tocar las pantallas:
/// `datosResumenGravityProvider.overrideWith((ref) => ...)`.
///
/// Las pantallas leen [resumenGravityProvider], que **siempre** pasa los datos
/// por el rol efectivo (D5): si un rol no puede ver dinero o cuidados, el campo
/// va en `null` y el panel no aparece (principio 3: nada de paneles vacíos ni
/// bloqueados). Cada dato lleva su módulo y se filtra con el espejo de permisos
/// (`nucleo/permisos/permisos.dart`), nunca con una tabla propia.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/sesion_efectiva.dart';
import '../../../diseno/componentes/nucleo_gravity.dart';
import '../../../diseno/componentes/semaforo.dart';
import '../../../nucleo/contratos/roles.dart';
import '../../../nucleo/permisos/permisos.dart';
import '../../../nucleo/sesion/proveedores_sesion.dart';

@immutable
class EventoAgenda {
  const EventoAgenda(this.hora, this.titulo, {required this.modulo});

  /// "20:00" o un día ("VIE").
  final String hora;
  final String titulo;

  /// Módulo del que viene; solo lo ve quien puede abrir ese módulo.
  final Modulo modulo;
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
    required this.modulo,
    this.detalle,
  });

  final String hora;
  final String titulo;
  final String? detalle;

  /// Módulo del que viene; solo lo ve quien puede abrir ese módulo.
  final Modulo modulo;
}

@immutable
class PendienteCuidados {
  const PendienteCuidados(
    this.texto,
    this.estado, {
    this.atencion = false,
    this.textoGenerico,
  });

  /// Texto para los roles que leen Cuidados (puede nombrar el medicamento).
  final String texto;

  /// "Pendiente", "1 nota".
  final String estado;

  /// Si requiere atención (se marca con el color de alerta y el texto).
  final bool atencion;

  /// Recordatorio genérico, sin nombre del medicamento ni de la persona, para
  /// el rol Casa (D3: *"Hora del medicamento de las 8:00"*). `null`: Casa no
  /// ve este pendiente.
  final String? textoGenerico;
}

@immutable
class ResumenCuidados {
  const ResumenCuidados({
    required this.turno,
    this.pendientes = const [],
    this.avisoNucleo,
    this.turnoGenerico = 'Turno de cuidados',
    this.avisoNucleoGenerico,
  });

  /// "Cuidadora · hasta 20:00" (puede llevar el nombre de quien cuida).
  final String turno;
  final List<PendienteCuidados> pendientes;

  /// Frase para el saludo del núcleo
  /// ("a las 20:00 hay un medicamento en el turno").
  final String? avisoNucleo;

  /// Turno sin nombre de persona, para el rol Casa.
  final String turnoGenerico;

  /// Frase del núcleo sin nombre de medicamento ni de persona, para el rol
  /// Casa. `null`: el núcleo no menciona cuidados a Casa.
  final String? avisoNucleoGenerico;

  /// Solo los recordatorios genéricos (rol Casa, D3 y D5).
  ResumenCuidados soloRecordatoriosGenericos() => ResumenCuidados(
    turno: turnoGenerico,
    turnoGenerico: turnoGenerico,
    pendientes: [
      for (final p in pendientes)
        if (p.textoGenerico case final generico?)
          PendienteCuidados(
            generico,
            p.estado,
            atencion: p.atencion,
            textoGenerico: generico,
          ),
    ],
    avisoNucleo: avisoNucleoGenerico,
    avisoNucleoGenerico: avisoNucleoGenerico,
  );
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
  const AvisoGravity(
    this.cuando,
    this.texto, {
    required this.modulo,
    this.tipo = TipoAviso.informacion,
  });

  final String cuando;
  final String texto;
  final TipoAviso tipo;

  /// Módulo del aviso; solo lo ve quien puede abrir ese módulo (los avisos de
  /// Cuidados, solo quien lee Cuidados completo).
  final Modulo modulo;
}

/// Cuánto de un módulo muestra el resumen a un rol.
enum VistaResumen {
  /// Nada: ni el panel ni sus avisos.
  nada,

  /// Solo recordatorios genéricos, sin nombre de medicamento ni de persona
  /// (Casa en Cuidados, D3).
  generica,

  /// Todo lo que el módulo entrega para ese rol.
  completa,
}

/// Vista del resumen de [modulo] para [rol], **siempre** con el espejo de
/// permisos: el módulo aparece solo si el rol puede abrirlo (`puedeAbrir`, que
/// exige leer); si el rol solo ve recordatorios genéricos
/// (`soloRecordatoriosGenericos`), solo esos; si depende del consentimiento
/// (`dependeDelConsentimiento`), nada hasta que la persona representada lo dé
/// (D2).
/// Sin rol (nadie ha entrado), nada.
VistaResumen vistaResumen(
  Rol? rol,
  Modulo modulo, {
  bool conConsentimiento = false,
}) {
  if (rol == null || !puedeAbrir(rol, modulo)) return VistaResumen.nada;
  if (soloRecordatoriosGenericos(rol, modulo)) return VistaResumen.generica;
  if (dependeDelConsentimiento(rol, modulo)) {
    return conConsentimiento ? VistaResumen.completa : VistaResumen.nada;
  }
  return VistaResumen.completa;
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
    this.sinDatos = false,
  });

  final bool enLinea;

  /// `true` si ningún módulo ha entregado todavía su resumen: las pantallas
  /// dicen "Sin datos todavía" en lugar de "Nada pendiente". Con datos
  /// (o de ejemplo), `false`.
  final bool sinDatos;
  final List<EventoAgenda> agenda;

  /// Hábitos de hoy (módulo Hábitos).
  final List<HabitoDeHoy> habitos;
  final SiguienteActividad? siguiente;

  /// `null` si el rol no ve Cuidados.
  final ResumenCuidados? cuidados;

  /// `null` si el rol no ve dinero.
  final ResumenFinanzasSemana? finanzas;
  final List<AvisoGravity> avisos;

  int get habitosHechos => habitos.where((h) => h.hecho).length;
  int get habitosTotal => habitos.length;

  /// Solo lo que [rol] puede ver (D5). Sin rol, solo el estado de conexión.
  ///
  /// - Finanzas, si el rol puede abrir Finanzas.
  /// - Cuidados, si el rol lee Cuidados; para Casa, solo los recordatorios
  ///   genéricos; con consentimiento pendiente (D2), nada.
  /// - Agenda, hábitos, lo que sigue y avisos, según el módulo de cada uno.
  ResumenGravity paraRol(Rol? rol, {bool conConsentimientoCuidados = false}) {
    VistaResumen vista(Modulo modulo) => vistaResumen(
      rol,
      modulo,
      conConsentimiento: modulo == Modulo.cuidados && conConsentimientoCuidados,
    );
    bool completo(Modulo modulo) => vista(modulo) == VistaResumen.completa;
    final siguiente = this.siguiente;
    return ResumenGravity(
      enLinea: enLinea,
      sinDatos: sinDatos,
      agenda: [
        for (final evento in agenda)
          if (completo(evento.modulo)) evento,
      ],
      habitos: completo(Modulo.habitos) ? habitos : const [],
      siguiente: siguiente != null && completo(siguiente.modulo)
          ? siguiente
          : null,
      cuidados: switch (vista(Modulo.cuidados)) {
        VistaResumen.completa => cuidados,
        VistaResumen.generica => cuidados?.soloRecordatoriosGenericos(),
        VistaResumen.nada => null,
      },
      finanzas: completo(Modulo.finanzas) ? finanzas : null,
      avisos: [
        for (final aviso in avisos)
          if (completo(aviso.modulo)) aviso,
      ],
    );
  }

  /// Lo que se muestra con una sesión real mientras ningún módulo entregue su
  /// resumen: nada inventado, solo el aviso honesto.
  static const sinDatosTodavia = ResumenGravity(sinDatos: true);

  /// Datos de ejemplo de los bocetos (no son datos reales). Solo para el modo
  /// demostración y las pruebas.
  static const ejemplo = ResumenGravity(
    agenda: [
      EventoAgenda('20:00', 'Inglés · lección del día', modulo: Modulo.habitos),
      EventoAgenda('21:00', 'Fuerza · 45 min', modulo: Modulo.habitos),
      EventoAgenda('22:30', 'A dormir · transición', modulo: Modulo.habitos),
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
      modulo: Modulo.habitos,
    ),
    cuidados: ResumenCuidados(
      turno: 'Cuidadora · hasta 20:00',
      turnoGenerico: 'Turno de cuidados · hasta 20:00',
      pendientes: [
        PendienteCuidados(
          'Medicamento 20:00',
          'Pendiente',
          atencion: true,
          textoGenerico: 'Recordatorio de cuidados 20:00',
        ),
        PendienteCuidados('Entrega de turno', '1 nota'),
      ],
      avisoNucleo: 'a las 20:00 hay un medicamento en el turno',
      avisoNucleoGenerico: 'a las 20:00 hay un recordatorio de cuidados',
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
        modulo: Modulo.finanzas,
        tipo: TipoAviso.atencion,
      ),
      AvisoGravity('SÁB 14:30', 'Revisión semanal', modulo: Modulo.finanzas),
      AvisoGravity(
        '03:00',
        'Copia de seguridad hecha',
        modulo: Modulo.ajustes,
        tipo: TipoAviso.hecho,
      ),
    ],
  );
}

/// Datos del resumen **antes** de filtrar por rol.
///
/// - Modo demostración (sin servidor): los datos de ejemplo de los bocetos.
/// - Sesión real: [ResumenGravity.sinDatosTodavia] hasta que cada módulo
///   entregue el suyo (las fases siguientes lo reemplazan y deben pedir solo lo
///   que el rol puede ver: el filtro de [resumenGravityProvider] es la última
///   defensa, no la única).
final datosResumenGravityProvider = Provider<ResumenGravity>(
  (ref) => ref.watch(servicioSesionProvider).esDemostracion
      ? ResumenGravity.ejemplo
      : ResumenGravity.sinDatosTodavia,
);

/// Resumen que muestran las pantallas: los datos pasados por el rol efectivo
/// (la persona de la sesión o, en la tablet, la que entró con PIN).
final resumenGravityProvider = Provider<ResumenGravity>(
  (ref) => ref
      .watch(datosResumenGravityProvider)
      .paraRol(ref.watch(rolEfectivoProvider)),
);

/// Módulos de la barra de módulos para [rol]: los navegables (espejo de la
/// matriz de permisos) más Ajustes si el rol puede abrirlo. Sin rol, ninguno.
List<Modulo> modulosDeLaBarra(Rol? rol) => rol == null
    ? const []
    : [
        ...modulosNavegables(rol),
        if (puedeAbrir(rol, Modulo.ajustes)) Modulo.ajustes,
      ];

/// Módulos de la barra de módulos de la laptop, según el rol efectivo.
final modulosBarraProvider = Provider<List<Modulo>>(
  (ref) => modulosDeLaBarra(ref.watch(rolEfectivoProvider)),
);

/// Estado que muestra el núcleo. El asistente lo reemplaza cuando haya voz.
final estadoNucleoProvider = Provider<EstadoNucleo>(
  (ref) => EstadoNucleo.enEspera,
);
