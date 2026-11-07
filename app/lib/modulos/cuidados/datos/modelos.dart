/// Modelos de Cuidados (Fase 5). Sin IA y sin voz: nada de esto sale del
/// dispositivo hacia la nube ni hacia las bocinas (D3, D6).
///
/// Las fechas de pared (turnos, tomas) son locales; el servidor guarda
/// `timestamptz`. El dinero va en centavos.
library;

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../nucleo/contratos/roles.dart';

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

/// Perfil de la sesión en Cuidados, tal como lo da `cui_perfil(hogar)` del
/// servidor. Se distingue por el **tipo de sus turnos** (`cui_turnos.tipo`),
/// no por el rol de membresía (D5): la cuidadora y la hermana pueden ser
/// ambas `cuidador` o `familiar`.
enum TipoPerfil {
  dueno('dueno'),
  pareja('pareja'),
  parejaConsentida('pareja_consentida'),
  cuidadora('cuidadora'),
  hermana('hermana');

  const TipoPerfil(this.valor);

  /// Texto que devuelve `cui_perfil`.
  final String valor;

  static TipoPerfil? deServidor(Object? v) {
    for (final t in values) {
      if (t.valor == v) return t;
    }
    return null;
  }
}

/// Quién es quien usa Cuidados, según el servidor (no se deduce del rol).
///
/// Con [tipo] (lo que dijo `cui_perfil`) manda el servidor. Sin él (pruebas y
/// demostración) se deduce del rol y de [esFamiliar] / [consentimiento].
@immutable
class PerfilCuidados {
  const PerfilCuidados({
    this.esFamiliar = false,
    this.resumenAutorizado = false,
    this.consentimiento = false,
    this.tipo,
    this.sinAcceso = false,
    this.esAlbacea = false,
  });

  /// Perfil leído del servidor: [valor] es lo que devolvió `cui_perfil`
  /// (nulo = sin acceso a Cuidados).
  factory PerfilCuidados.servidor(
    Object? valor, {
    bool resumenAutorizado = false,
    bool esAlbacea = false,
  }) {
    final t = TipoPerfil.deServidor(valor);
    return PerfilCuidados(
      tipo: t,
      sinAcceso: t == null,
      esFamiliar: t == TipoPerfil.hermana,
      consentimiento: t == TipoPerfil.parejaConsentida,
      resumenAutorizado: t == TipoPerfil.hermana && resumenAutorizado,
      esAlbacea: t != null && esAlbacea,
    );
  }

  /// La hermana (turnos de tipo `hermana_visita`).
  final bool esFamiliar;

  /// El albacea autorizó que vea el resumen mensual
  /// (`cui_autorizacion_resumen.vigente`).
  final bool resumenAutorizado;

  /// La pareja dio su consentimiento (`cui_consentimientos.concedido`).
  final bool consentimiento;

  /// Lo que dijo el servidor; nulo si no se leyó de allí.
  final TipoPerfil? tipo;

  /// El servidor respondió "sin perfil": no hay acceso a Cuidados.
  final bool sinAcceso;

  /// Es el albacea vigente de Papá (D19): único que autoriza el resumen.
  /// Solo adorno de la interfaz; el servidor lo vuelve a exigir.
  final bool esAlbacea;

  /// Perfil efectivo para [rol]: el del servidor si lo hay; si no, se deduce.
  /// Nulo = sin acceso (Casa, familiar sin perfil, baja…).
  TipoPerfil? efectivo(Rol rol) {
    if (sinAcceso) return null;
    if (tipo != null) return tipo;
    return switch (rol) {
      Rol.dueno => TipoPerfil.dueno,
      Rol.coadministrador =>
        consentimiento ? TipoPerfil.parejaConsentida : TipoPerfil.pareja,
      Rol.cuidador || Rol.familiar =>
        esFamiliar
            ? TipoPerfil.hermana
            : (rol == Rol.cuidador ? TipoPerfil.cuidadora : null),
      Rol.casa => null,
    };
  }
}

/// Visita: solo en la demostración (el servidor no guarda visitas, §3).
enum TipoTurno { turno, visita }

/// `cui_turnos.tipo`.
enum FuncionTurno {
  cuidadora('cuidadora', 'Cuidadora'),
  dueno('dueno', 'Dueño'),
  hermanaVisita('hermana_visita', 'Hermana');

  const FuncionTurno(this.valor, this.etiqueta);
  final String valor;
  final String etiqueta;

  static FuncionTurno? deServidor(Object? v) {
    for (final f in values) {
      if (f.valor == v) return f;
    }
    return null;
  }
}

@immutable
class Turno {
  const Turno({
    required this.id,
    required this.personaId,
    required this.nombre,
    required this.inicio,
    required this.fin,
    this.tipo = TipoTurno.turno,
    this.funcion,
    this.plantillaId,
  });

  final String id;
  final String personaId;
  final String nombre;
  final DateTime inicio;
  final DateTime fin;
  final TipoTurno tipo;

  /// `cui_turnos.tipo` (cuidadora, dueño, hermana). Nulo en la demostración.
  final FuncionTurno? funcion;

  /// Fila de `cui_turnos` (turno semanal) de la que sale este día.
  final String? plantillaId;

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
    this.notas = '',
  });

  final String id;
  final String nombre;
  final String dosis;
  final String notas;

  /// Horas del día, `HH:mm`, en orden.
  final List<String> horas;
  final bool activo;

  Medicamento copiarCon({bool? activo, List<String>? horas}) => Medicamento(
    id: id,
    nombre: nombre,
    dosis: dosis,
    horas: horas ?? this.horas,
    activo: activo ?? this.activo,
    notas: notas,
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

enum TipoBitacora { nota, cita, instruccion }

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
    this.paraPersonaId,
  });

  final String id;
  final String dePersonaId;
  final String deNombre;
  final String notas;
  final DateTime creadaEn;

  /// Quien sigue (`cui_entregas.para_persona`).
  final String? paraPersonaId;
}

/// Cómo se arma el texto de un cambio urgente (el servidor solo guarda
/// `texto`, 1 a 200 caracteres).
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
    required this.texto,
    required this.creadoPor,
    required this.creadoEn,
    this.paraPersonaId,
    this.atendidoPor,
    this.atendidoNombre,
    this.atendidoEn,
  });

  final String id;

  /// `cui_cambios_urgentes.texto` (1 a 200).
  final String texto;
  final String creadoPor;
  final DateTime creadoEn;

  /// Quien estaba de turno y recibió el aviso; nulo si nadie.
  final String? paraPersonaId;

  /// El servidor solo guarda `atendido_en`; quién lo atendió se sabe en la
  /// demostración y, en el servidor, solo por [paraPersonaId].
  final String? atendidoPor;
  final String? atendidoNombre;
  final DateTime? atendidoEn;

  bool get atendido => atendidoEn != null;

  CambioUrgente atender(String personaId, String nombre, DateTime en) =>
      CambioUrgente(
        id: id,
        texto: texto,
        creadoPor: creadoPor,
        creadoEn: creadoEn,
        paraPersonaId: paraPersonaId,
        atendidoPor: personaId,
        atendidoNombre: nombre,
        atendidoEn: en,
      );
}

/// `cui_gastos.estado`.
enum EstadoGasto {
  pendiente('Pendiente de confirmación', 'pendiente_confirmacion'),
  confirmado('Confirmado', 'confirmado'),
  rechazado('Rechazado', 'rechazado');

  const EstadoGasto(this.etiqueta, this.valor);
  final String etiqueta;
  final String valor;
}

/// `cui_gastos.ambito`: gasto del cuidado de Papá o de la casa.
enum AmbitoGasto {
  cuidado('Cuidado', 'cuidado'),
  casa('Casa', 'casa');

  const AmbitoGasto(this.etiqueta, this.valor);
  final String etiqueta;
  final String valor;
}

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
    this.ambito = AmbitoGasto.cuidado,
    this.registradoEn,
  });

  final String id;
  final String concepto;
  final int centavos;
  final DateTime fecha;
  final String registradoPor;
  final String registradoNombre;
  final EstadoGasto estado;
  final AmbitoGasto ambito;
  final DateTime? registradoEn;

  GastoCuidado conEstado(EstadoGasto e) => GastoCuidado(
    id: id,
    concepto: concepto,
    centavos: centavos,
    fecha: fecha,
    registradoPor: registradoPor,
    registradoNombre: registradoNombre,
    estado: e,
    ambito: ambito,
    registradoEn: registradoEn,
  );
}

/// Resumen del mes (`cui_resumen_mensual`): solo totales de gastos
/// **confirmados**, sin los de la pareja ni los del dueño. Nunca filas.
@immutable
class ResumenMensual {
  const ResumenMensual({
    required this.mes,
    required this.gastosCuidadoCentavos,
    required this.gastosCasaCentavos,
    required this.nGastos,
  });

  final DateTime mes;
  final int gastosCuidadoCentavos;
  final int gastosCasaCentavos;
  final int nGastos;

  int get totalCentavos => gastosCuidadoCentavos + gastosCasaCentavos;
}

/// Conteos del día de Papá (`cui_resumen_papa`): sin nombres, dosis ni notas.
@immutable
class ResumenPapa {
  const ResumenPapa({
    required this.dia,
    this.tomasTotal = 0,
    this.tomasDadas = 0,
    this.tomasNoDadas = 0,
    this.tomasPendientes = 0,
    this.comidasRegistradas = 0,
    this.comidasConRechazo = 0,
  });

  final DateTime dia;
  final int tomasTotal;
  final int tomasDadas;
  final int tomasNoDadas;
  final int tomasPendientes;
  final int comidasRegistradas;
  final int comidasConRechazo;
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

/// Estado de los consentimientos y autorizaciones (`cui_consentimientos` y
/// `cui_autorizacion_resumen`). Sin textos clínicos: solo quién y si sí o no.
@immutable
class EstadoConsentimientos {
  const EstadoConsentimientos({
    this.parejaId,
    this.parejaNombre = 'Pareja',
    this.parejaConcedido = false,
    this.hermanaId,
    this.hermanaNombre = 'Hermana',
    this.hermanaAutorizada = false,
  });

  final String? parejaId;
  final String parejaNombre;

  /// La pareja concedió leer la bitácora.
  final bool parejaConcedido;

  final String? hermanaId;
  final String hermanaNombre;

  /// El albacea autorizó que la hermana vea el resumen mensual.
  final bool hermanaAutorizada;
}
