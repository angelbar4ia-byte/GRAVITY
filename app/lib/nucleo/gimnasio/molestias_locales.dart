/// Molestias físicas de «Mi gimnasio»: **solo en el dispositivo** (spec 4.3 y 9,
/// PG-03, CA-G-36).
///
/// - Se guardan en el almacén de sobres de Hábitos como el tercer tipo
///   sensible [TipoSensible.saludLocal]: cifradas con la **llave local** de la
///   persona (nunca la maestra), sin modo y sin nube.
/// - **Nada las envía:** no hay cola, subida diferida, tabla ni función del
///   servidor para ellas; el servidor tampoco las admite (`hab_sobres.tipo`).
///   Activar la nube de los otros dos tipos no las toca ([TipoSensible.enNube]).
/// - **Solo donde hay una llave local de la persona:** el teléfono y la tablet
///   personal. La laptop («no están aquí») y la **tablet pública** ni las
///   muestran ni las guardan ([equipoAdmiteMolestias]); allí la pantalla dice
///   que no se tienen en cuenta.
/// - Ningún error ni registro lleva el texto de una molestia (R6): las
///   excepciones de este archivo no cargan datos.
library;

import 'dart:typed_data';

import 'package:habitos_dominio/habitos_dominio.dart';

import '../avisos/repositorio_avisos.dart' show TipoEquipoAvisos;
import '../sensibles/llaves_habitos.dart';
import '../sensibles/sobres.dart';
import '../sensibles/subida_diferida.dart' show ModosLocales;

/// Clave del único documento de molestias de una persona en el almacén.
const claveDocumentoMolestias = 'molestias';

/// Clase de cada elemento del documento.
const claseMolestia = 'molestia';

/// ¿Este equipo guarda y muestra molestias? Teléfono y tablet personal (donde
/// la persona tiene su llave local); no la laptop ni la tablet pública.
bool equipoAdmiteMolestias(TipoEquipoAvisos tipo) =>
    tipo == TipoEquipoAvisos.telefono ||
    tipo == TipoEquipoAvisos.tabletPersonal;

/// Este equipo no admite molestias (laptop o tablet pública). No lleva datos.
class MolestiasNoDisponibles implements Exception {
  const MolestiasNoDisponibles();

  @override
  String toString() => 'Las molestias están solo en el teléfono de la persona.';
}

/// La molestia no cumple las reglas (zona del catálogo, intensidad de 1 a 3,
/// nota de hasta 200 caracteres). No lleva el contenido.
class MolestiaInvalida implements Exception {
  const MolestiaInvalida();

  @override
  String toString() => 'La molestia no es válida.';
}

/// Qué se pudo leer de las molestias en este equipo.
class LecturaMolestias {
  const LecturaMolestias({
    this.molestias = const [],
    this.enEsteEquipo = true,
    this.bloqueada = false,
  });

  /// Las molestias de la persona en este equipo (activas y cerradas).
  final List<Molestia> molestias;

  /// `false` si este equipo no las admite (laptop o tablet pública): la
  /// pantalla dice «Las molestias están solo en tu teléfono; aquí no se tienen
  /// en cuenta».
  final bool enEsteEquipo;

  /// `true` si hay llave pero aún no se abre (tablet personal sin el PIN):
  /// mientras no se abre, el generador no las conoce.
  final bool bloqueada;

  /// Las que el generador debe tener en cuenta.
  List<Molestia> get activas => [
    for (final m in molestias)
      if (m.activa) m,
  ];
}

class MolestiasLocales {
  MolestiasLocales({
    required this.llaves,
    required this.sobres,
    required this.modos,
    required this.persona,
    required this.equipoLasAdmite,
    DateTime Function()? ahora,
  }) : _ahora = ahora ?? DateTime.now;

  final LlavesHabitos llaves;
  final AlmacenDeSobres sobres;
  final ModosLocales modos;
  final String persona;

  /// ¿Este equipo admite molestias? ([equipoAdmiteMolestias])
  final bool Function() equipoLasAdmite;
  final DateTime Function() _ahora;

  static const _tipo = TipoSensible.saludLocal;

  /// Las llaves de este tipo: siempre las locales.
  Future<(Uint8List, Uint8List)?> _llaves() async {
    final tipo = await llaves.llaveDeTipo(
      persona,
      _tipo,
      await modos.modo(persona, _tipo),
    );
    final ids = await llaves.llaveDeIds(
      persona,
      await modos.modo(persona, _tipo),
    );
    return tipo == null || ids == null ? null : (tipo, ids);
  }

  Future<(Sobre, DocumentoSensible)?> _abrir(
    Uint8List llaveTipo,
    String id,
  ) async {
    final sobre = await sobres.leer(persona, id);
    if (sobre == null) return null;
    final m = descifrarDocumento(
      llaveDeTipo: llaveTipo,
      persona: persona,
      sobre: sobre,
    );
    if (m == null) return null;
    return (
      sobre,
      DocumentoSensible.deJson((m['doc']! as Map).cast<String, Object?>()),
    );
  }

  /// Lee las molestias. En un equipo que no las admite, o con la llave aún
  /// bloqueada, devuelve la lectura vacía con su motivo (no lanza).
  Future<LecturaMolestias> leer() async {
    if (!equipoLasAdmite()) return const LecturaMolestias(enEsteEquipo: false);
    final Uint8List llaveTipo;
    final Uint8List llaveIds;
    try {
      final k = await _llaves();
      if (k == null) return const LecturaMolestias();
      (llaveTipo, llaveIds) = k;
    } on LlaveBloqueada {
      return const LecturaMolestias(bloqueada: true);
    } on LlaveNoPermitida {
      return const LecturaMolestias(enEsteEquipo: false);
    }
    final id = LlavesHabitos.idOpaco(llaveIds, _tipo, claveDocumentoMolestias);
    final abierto = await _abrir(llaveTipo, id);
    if (abierto == null) return const LecturaMolestias();
    return LecturaMolestias(
      molestias: [
        for (final e in abierto.$2.elementos.values)
          if (!e.eliminado && e.clase == claseMolestia)
            Molestia.deMapaLocal(e.id, e.datos),
      ]..sort((a, b) => a.desde.compareTo(b.desde)),
    );
  }

  /// Solo las activas (lo que el generador tiene en cuenta). Vacío donde no se
  /// admiten.
  Future<List<Molestia>> activas() async => (await leer()).activas;

  /// Agrega o reemplaza una molestia. Lanza [MolestiasNoDisponibles] en un
  /// equipo que no las admite y [MolestiaInvalida] si no cumple las reglas.
  Future<void> guardar(Molestia molestia) async {
    if (!equipoLasAdmite()) throw const MolestiasNoDisponibles();
    if (!molestia.valida ||
        molestia.id.isEmpty ||
        (molestia.nota?.length ?? 0) > 200) {
      throw const MolestiaInvalida();
    }
    await _poner(
      ElementoDoc(
        id: molestia.id,
        clase: claseMolestia,
        modificadoEn: _ahora().millisecondsSinceEpoch,
        datos: molestia.aMapaLocal(),
      ),
    );
  }

  /// Borra una molestia (queda una tumba, como el resto de lo sensible).
  Future<void> quitar(String id) async {
    if (!equipoLasAdmite()) throw const MolestiasNoDisponibles();
    await _poner(
      ElementoDoc(
        id: id,
        clase: claseMolestia,
        modificadoEn: _ahora().millisecondsSinceEpoch,
        eliminado: true,
      ),
    );
  }

  /// Borra todas las molestias de este equipo (Mis datos › borrar).
  Future<int> borrarTodas() => sobres.borrar(persona, tipo: _tipo);

  Future<void> _poner(ElementoDoc elemento) async {
    final k = await _llaves();
    if (k == null) throw StateError('Sin llave en este equipo.');
    final (llaveTipo, llaveIds) = k;
    final id = LlavesHabitos.idOpaco(llaveIds, _tipo, claveDocumentoMolestias);
    final actual = await _abrir(llaveTipo, id);
    final doc = fusionarDocumentos(
      actual?.$2 ?? const DocumentoSensible({}),
      DocumentoSensible({elemento.id: elemento}),
    );
    final sobre = cifrarDocumento(
      llaveDeTipo: llaveTipo,
      llaveDeIds: llaveIds,
      persona: persona,
      tipo: _tipo,
      claveDoc: claveDocumentoMolestias,
      documento: {'clave': claveDocumentoMolestias, 'doc': doc.aJson()},
      revisionAnterior: actual?.$1.revision ?? 0,
    );
    await sobres.guardar(persona, sobre);
  }
}
