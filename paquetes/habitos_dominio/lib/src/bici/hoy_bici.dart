/// B1.4 · La tarjeta «Bicicleta» de Hoy (CA-B-15), el modo foco (4.10,
/// CA-B-12), «¿Cómo amaneciste?» (CA-B-10) y qué ve cada equipo (6.1, 7).
///
/// **Modo foco como booleano sin causa:** la bicicleta recibe solo `true` o
/// `false`; nunca sabe qué hábito lo causó (HB-18). Con foco no hay nota de
/// progresión ni sugerencia de aumento, la salida y el recordatorio siguen
/// disponibles y los textos de seguridad **no se ocultan** (son seguridad, no
/// incremento).
library;

import '../gimnasio/regenerativa.dart' show EstadoAnimo;
import 'mantenimiento.dart';
import 'mensajes_bici.dart';
import 'reglas_bici.dart';
import 'salida_sabado.dart';

/// Dónde se está viendo la bicicleta.
enum EquipoBici { celular, tabletPersonal, laptop, tabletPublica }

/// Qué se muestra en cada equipo (6.1, 7.1). Las rutas y el contacto viven
/// solo en el equipo donde se escribieron.
class VisibilidadBici {
  const VisibilidadBici({
    required this.tarjetaHoy,
    required this.rutas,
    required this.contacto,
    required this.textosSeguridad,
    required this.recibeRecordatorios,
  });

  final bool tarjetaHoy;
  final bool rutas;
  final bool contacto;
  final bool textosSeguridad;
  final bool recibeRecordatorios;
}

VisibilidadBici visibilidadBici(EquipoBici e) => switch (e) {
  EquipoBici.celular || EquipoBici.tabletPersonal => const VisibilidadBici(
    tarjetaHoy: true,
    rutas: true,
    contacto: true,
    textosSeguridad: true,
    recibeRecordatorios: true,
  ),
  // La laptop no muestra ni conoce rutas ni contacto; solo los textos.
  EquipoBici.laptop => const VisibilidadBici(
    tarjetaHoy: true,
    rutas: false,
    contacto: false,
    textosSeguridad: true,
    recibeRecordatorios: true,
  ),
  // Tablet pública: solo la tarjeta de Hoy, sin ruta ni contacto, y nunca
  // recibe recordatorios de la bicicleta.
  EquipoBici.tabletPublica => const VisibilidadBici(
    tarjetaHoy: true,
    rutas: false,
    contacto: false,
    textosSeguridad: false,
    recibeRecordatorios: false,
  ),
};

enum TipoTarjetaBici { ninguna, preparaTuSalida, salida }

class TarjetaHoyBici {
  const TarjetaHoyBici({
    required this.tipo,
    this.mensaje,
    this.salidaMin,
    this.regresoMin,
    this.encaje,
    this.mantenimientoToca = const [],
    this.enFoco = false,
    this.salidaDisponible = true,
    this.textosSeguridadVisibles = true,
    this.visibilidad,
  });

  final TipoTarjetaBici tipo;
  final String? mensaje;
  final int? salidaMin;
  final int? regresoMin;
  final EncajeRevision? encaje;

  /// Tareas que tocan: una línea en la preparación del viernes.
  final List<TareaMantenimiento> mantenimientoToca;
  final bool enFoco;

  /// La salida siempre está disponible (también en foco).
  final bool salidaDisponible;

  /// Los textos de seguridad **no se ocultan** nunca por el foco.
  final bool textosSeguridadVisibles;
  final VisibilidadBici? visibilidad;
}

/// Arma la tarjeta de Hoy: el **viernes** «Prepara tu salida»; el **sábado**
/// la salida con el regreso estimado y el encaje con la revisión; los demás
/// días, ninguna.
TarjetaHoyBici tarjetaHoyBici({
  required DateTime hoy,
  required EquipoBici equipo,
  required int duracionMin,
  required int revisionMin,
  bool modoFoco = false,
  bool salidaHecha = false,
  List<TareaEstado> mantenimiento = const [],
  ReglasBicicleta reglas = const ReglasBicicleta(),
}) {
  final vis = visibilidadBici(equipo);
  final toca = [
    for (final m in mantenimiento)
      if (m.estado == EstadoTarea.toca) m.tarea,
  ];
  if (hoy.weekday == DateTime.friday) {
    return TarjetaHoyBici(
      tipo: TipoTarjetaBici.preparaTuSalida,
      mensaje: MensajesBici.preparaTuSalida,
      mantenimientoToca: toca,
      enFoco: modoFoco,
      visibilidad: vis,
    );
  }
  if (hoy.weekday != DateTime.saturday) {
    return TarjetaHoyBici(
      tipo: TipoTarjetaBici.ninguna,
      enFoco: modoFoco,
      visibilidad: vis,
    );
  }
  final encaje = encajeConRevision(
    inicioMin: reglas.salidaInicioMin,
    duracionMin: duracionMin,
    revisionMin: revisionMin,
    reglas: reglas,
  );
  return TarjetaHoyBici(
    tipo: TipoTarjetaBici.salida,
    mensaje: salidaHecha
        ? MensajesBici.salidaRegistrada
        : (modoFoco ? MensajesBici.focoSalida : MensajesBici.hoyTocaSalida),
    salidaMin: reglas.salidaInicioMin,
    regresoMin: encaje.regresoMin,
    encaje: encaje,
    mantenimientoToca: toca,
    enFoco: modoFoco,
    visibilidad: vis,
  );
}

/// Con «Cansado» se propone una ruta más corta o de calle plana; **no
/// bloquea** (CA-B-10). Con las otras respuestas, no hay propuesta.
class PropuestaAnimoBici {
  const PropuestaAnimoBici(this.texto);
  final String texto;

  bool get bloquea => false;
}

PropuestaAnimoBici? propuestaPorAnimo(EstadoAnimo animo) =>
    animo == EstadoAnimo.cansado
    ? const PropuestaAnimoBici(MensajesBici.cansado)
    : null;
