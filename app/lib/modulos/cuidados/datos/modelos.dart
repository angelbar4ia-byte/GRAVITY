/// Modelos de Cuidados (Fase 5). Sin IA y sin voz: nada de esto sale del
/// dispositivo hacia la nube ni hacia las bocinas (D3, D6).
///
/// Las fechas de pared (turnos, tomas) son locales; el servidor guarda
/// `timestamptz`. El dinero va en centavos.
library;

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Id estable (UUID v5): el mismo hecho da el mismo id, así tocar dos veces o
/// reintentar sin señal no duplica (el servidor ignora el repetido).
String idEstableCuidados(String clave) =>
    const Uuid().v5(Namespace.url.value, 'gravity:cuidados:$clave');

String idNuevoCuidados() => const Uuid().v4();

DateTime soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

/// Lunes de la semana de [d] (la semana empieza en lunes).
DateTime lunesDe(DateTime d) =>
    soloFecha(d).subtract(Duration(days: d.weekday - DateTime.monday));

String _dos(int n) => n.toString().padLeft(2, '0');
String horaTexto(DateTime d) => '${_dos(d.hour)}:${_dos(d.minute)}';
String fechaClave(DateTime d) => '${d.year}-${_dos(d.month)}-${_dos(d.day)}';

/// Quién es quien usa Cuidados, según el servidor (no se deduce del rol: la
/// cuidadora y la hermana son ambas `cuidador`, D5).
@immutable
class PerfilCuidados {
  const PerfilCuidados({
    this.esFamiliar = false,
    this.resumenAutorizado = false,
    this.consentimiento = false,
  });

  /// La hermana (cuidador familiar): fila en `cui_autorizacion_resumen`.
  final bool esFamiliar;

  /// El albacea autorizó que vea el resumen mensual.
  final bool resumenAutorizado;

  /// La pareja dio su consentimiento (`cui_consentimientos` vigente).
  final bool consentimiento;
}

enum TipoTurno { turno, visita }

@immutable
class Turno {
  const Turno({
    required this.id,
    required this.personaId,
    required this.nombre,
    required this.inicio,
    required this.fin,
    this.tipo = TipoTurno.turno,
  });

  final String id;
  final String personaId;
  final String nombre;
  final DateTime inicio;
  final DateTime fin;
  final TipoTurno tipo;

  bool cubre(DateTime t) => !t.isBefore(inicio) && t.isBefore(fin);

  String get horario => '${horaTexto(inicio)} a ${horaTexto(fin)}';
}

@immutable
class Medicamento {
  const Medicamento({
    required this.id,
    required this.nombre,
    required this.dosis,
    required this.horas,
    this.activo = true,
  });

  final String id;
  final String nombre;
  final String dosis;

  /// Horas del día, `HH:mm`, en orden.
  final List<String> horas;
  final bool activo;

  Medicamento copiarCon({bool? activo, List<String>? horas}) => Medicamento(
    id: id,
    nombre: nombre,
    dosis: dosis,
    horas: horas ?? this.horas,
    activo: activo ?? this.activo,
  );
}

enum EstadoToma { pendiente, dado, noDado }

@immutable
class Toma {
  const Toma({
    required this.id,
    required this.medicamentoId,
    required this.programada,
    required this.estado,
    required this.registradaPor,
    required this.registradaPorNombre,
    required this.registradaEn,
    this.motivo,
  });

  final String id;
  final String medicamentoId;
  final DateTime programada;
  final EstadoToma estado;
  final String registradaPor;
  final String registradaPorNombre;
  final DateTime registradaEn;
  final String? motivo;

  static String idDe(String medicamentoId, DateTime programada) =>
      idEstableCuidados('toma:$medicamentoId:${programada.toIso8601String()}');
}

/// Una dosis del día: lo programado más lo registrado.
@immutable
class Dosis {
  const Dosis({required this.medicamento, required this.hora, this.toma});

  final Medicamento medicamento;
  final DateTime hora;
  final Toma? toma;

  EstadoToma get estado => toma?.estado ?? EstadoToma.pendiente;
}

enum TiempoComidaPapa {
  desayuno('Desayuno'),
  comida('Comida'),
  cena('Cena'),
  colacion('Colación');

  const TiempoComidaPapa(this.etiqueta);
  final String etiqueta;
}

enum ResultadoComida {
  comio('Comió'),
  comioPoco('Comió poco'),
  rechazo('Rechazó');

  const ResultadoComida(this.etiqueta);
  final String etiqueta;
}

@immutable
class ComidaRegistro {
  const ComidaRegistro({
    required this.id,
    required this.fecha,
    required this.tiempo,
    required this.resultado,
    required this.registradaPor,
    required this.registradaPorNombre,
    required this.registradaEn,
  });

  final String id;
  final DateTime fecha;
  final TiempoComidaPapa tiempo;
  final ResultadoComida resultado;
  final String registradaPor;
  final String registradaPorNombre;
  final DateTime registradaEn;

  static String idDe(DateTime fecha, TiempoComidaPapa t) =>
      idEstableCuidados('comida:${fechaClave(fecha)}:${t.name}');
}

enum TipoBitacora { nota, cita }

@immutable
class EntradaBitacora {
  const EntradaBitacora({
    required this.id,
    required this.tipo,
    required this.texto,
    required this.autorId,
    required this.autorNombre,
    required this.creadaEn,
    this.programadaEn,
  });

  final String id;
  final TipoBitacora tipo;
  final String texto;
  final String autorId;
  final String autorNombre;
  final DateTime creadaEn;

  /// Solo en citas: cuándo es.
  final DateTime? programadaEn;
}

/// Entrega de turno: notas para quien sigue.
@immutable
class Entrega {
  const Entrega({
    required this.id,
    required this.dePersonaId,
    required this.deNombre,
    required this.notas,
    required this.creadaEn,
  });

  final String id;
  final String dePersonaId;
  final String deNombre;
  final String notas;
  final DateTime creadaEn;
}

enum AccionCambio {
  suspender('Suspender'),
  agregar('Agregar');

  const AccionCambio(this.etiqueta);
  final String etiqueta;
}

@immutable
class CambioUrgente {
  const CambioUrgente({
    required this.id,
    required this.accion,
    required this.nota,
    required this.creadoPor,
    required this.creadoEn,
    this.medicamentoId,
    this.medicamentoNombre,
    this.atendidoPor,
    this.atendidoNombre,
    this.atendidoEn,
  });

  final String id;
  final AccionCambio accion;
  final String nota;
  final String creadoPor;
  final DateTime creadoEn;
  final String? medicamentoId;

  /// Para "agregar" un medicamento que aún no está en la lista.
  final String? medicamentoNombre;
  final String? atendidoPor;
  final String? atendidoNombre;
  final DateTime? atendidoEn;

  bool get atendido => atendidoEn != null;

  CambioUrgente atender(String personaId, String nombre, DateTime en) =>
      CambioUrgente(
        id: id,
        accion: accion,
        nota: nota,
        creadoPor: creadoPor,
        creadoEn: creadoEn,
        medicamentoId: medicamentoId,
        medicamentoNombre: medicamentoNombre,
        atendidoPor: personaId,
        atendidoNombre: nombre,
        atendidoEn: en,
      );
}

enum EstadoGasto {
  pendiente('Pendiente de confirmación'),
  confirmado('Confirmado'),
  rechazado('Rechazado');

  const EstadoGasto(this.etiqueta);
  final String etiqueta;
}

/// A quién corresponde un gasto o una línea del resumen. La hermana no ve lo
/// de la pareja ni del dueño (D5).
enum Titular { papa, casa, pareja, dueno }

@immutable
class GastoCuidado {
  const GastoCuidado({
    required this.id,
    required this.concepto,
    required this.centavos,
    required this.fecha,
    required this.registradoPor,
    required this.registradoNombre,
    this.estado = EstadoGasto.pendiente,
    this.titular = Titular.papa,
  });

  final String id;
  final String concepto;
  final int centavos;
  final DateTime fecha;
  final String registradoPor;
  final String registradoNombre;
  final EstadoGasto estado;
  final Titular titular;

  GastoCuidado conEstado(EstadoGasto e) => GastoCuidado(
    id: id,
    concepto: concepto,
    centavos: centavos,
    fecha: fecha,
    registradoPor: registradoPor,
    registradoNombre: registradoNombre,
    estado: e,
    titular: titular,
  );
}

@immutable
class LineaResumen {
  const LineaResumen({
    required this.concepto,
    required this.centavos,
    required this.titular,
  });

  final String concepto;
  final int centavos;
  final Titular titular;
}

@immutable
class ResumenMensual {
  const ResumenMensual({required this.mes, required this.lineas});

  final DateTime mes;
  final List<LineaResumen> lineas;

  int get totalCentavos => lineas.fold(0, (s, l) => s + l.centavos);

  /// Lo que ve la hermana: sin lo de la pareja ni del dueño (se vuelve a
  /// filtrar en la app aunque el servidor ya lo haga).
  ResumenMensual paraFamiliar() => ResumenMensual(
    mes: mes,
    lineas: [
      for (final l in lineas)
        if (l.titular != Titular.pareja && l.titular != Titular.dueno) l,
    ],
  );
}

/// Error de Cuidados con mensaje para la persona.
class ErrorCuidados implements Exception {
  const ErrorCuidados(this.mensaje);
  final String mensaje;

  static const sinPermiso = ErrorCuidados('No tienes permiso para hacer eso.');
  static const conexion = ErrorCuidados(
    'Sin conexión. Se intentará de nuevo más tarde.',
  );

  @override
  String toString() => mensaje;
}
