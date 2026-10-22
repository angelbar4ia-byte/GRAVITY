/// Ids **estables** (UUID v5) de Finanzas.
///
/// Lo que se guarda en el servidor lleva el id del dispositivo. Cuando una
/// acción se puede repetir (reintentar sin señal, tocar dos veces, volver a
/// importar), el id sale de una clave que describe **qué** es, no de cuándo
/// se hizo: así el reintento llega con el mismo id y el servidor lo ignora
/// (`ON CONFLICT (id) DO NOTHING`, idempotencia de la cola) en lugar de chocar
/// con un único (`anula_a`, `(hogar_id, padre_id, nombre)`,
/// `(semana_id, origen, origen_id)`…) y quedar en "requiere atención".
library;

import 'package:finanzas_dominio/finanzas_dominio.dart' show normalizarNombre;
import 'package:uuid/uuid.dart';

/// Espacio de nombres de los ids estables de Finanzas.
const _espacio = 'gravity:finanzas:';

/// UUID v5 de [clave] (siempre el mismo para la misma clave).
String idEstable(String clave) =>
    const Uuid().v5(Namespace.url.value, '$_espacio$clave');

/// Claves de los ids estables. Cada una nombra lo que identifica.
abstract final class ClavesId {
  /// La anulación de un movimiento: hay a lo más una (índice único en
  /// `anula_a`), así que "Deshacer" o "Anular" repetidos dan el mismo id.
  static String anulacion(String movimientoId) => 'anulacion:$movimientoId';

  /// Una categoría o cuenta de gasto importada de la plantilla (la clave del
  /// importador ya dice su ruta en el árbol).
  static String importacion(String hogarId, String clave) => '$hogarId:$clave';

  /// La cuenta de gasto de una categoría principal creada a mano (único
  /// `(hogar_id, libro_id, nombre)` con `libro_id` nulo).
  static String cuentaDeGasto(String hogarId, String nombre) =>
      '$hogarId:cuenta-gasto:${normalizarNombre(nombre)}';

  /// Una cuenta de un libro por su tipo y su nombre (único
  /// `(hogar_id, libro_id, nombre)`).
  static String cuentaDeLibro(String libroId, String tipo, String nombre) =>
      'cuenta:$libroId:$tipo:${normalizarNombre(nombre)}';

  /// La semana activada de un libro (único `(libro_id, semana_inicio)`).
  static String semana(String libroId, String lunes) => 'semana:$libroId:$lunes';

  /// El cierre de una semana en su versión (único `(semana_id, version)`).
  static String cierre(String semanaId, int version) =>
      'cierre:$semanaId:v$version';

  /// Un renglón de partida de un cierre (único `(cierre_id, partida_id)`).
  static String cierrePartida(String cierreId, String partidaId) =>
      'cierre-partida:$cierreId:$partidaId';

  /// Un renglón de abono de un cierre (único `(cierre_id, deuda_id)`).
  static String cierreAbono(String cierreId, String deudaId) =>
      'cierre-abono:$cierreId:$deudaId';

  /// Un movimiento del remanente que se aplicó al cerrar (uno por deuda y
  /// uno de ahorro por cierre).
  static String remanente(String cierreId, String destino) =>
      'remanente:$cierreId:$destino';

  /// Una ocurrencia (único `(libro_id, origen, origen_id, fecha_programada)`).
  static String ocurrencia(
    String libroId,
    String origen,
    String origenId,
    String fechaProgramada,
  ) => 'ocurrencia:$libroId:$origen:$origenId:$fechaProgramada';

  /// Un día inhábil del hogar (único `(hogar_id, fecha)`).
  static String diaInhabil(String hogarId, String fecha) =>
      '$hogarId:dia-inhabil:$fecha';

  /// Un libro compartido por su nombre: crearlo dos veces no duplica.
  static String libroCompartido(String hogarId, String nombre) =>
      '$hogarId:libro-compartido:${normalizarNombre(nombre)}';

  /// El libro representado de una persona por su nombre.
  static String libroRepresentado(String hogarId, String nombreTitular) =>
      '$hogarId:libro-representado:${normalizarNombre(nombreTitular)}';

  /// Una persona en un libro con su papel (único vigente
  /// `(libro_id, persona_id)`).
  static String miembro(String libroId, String personaId, String papel) =>
      'miembro:$libroId:$personaId:$papel';
}
