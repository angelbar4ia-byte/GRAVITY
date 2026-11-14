/// Documentos sensibles de Hábitos sobre el almacén de sobres de plataforma
/// (`nucleo/sensibles`): elementos con fusión del dominio, cifrados con la
/// llave del modo del tipo (local o maestra). **Nunca texto claro en disco**.
///
/// Claves de documento: `config` (singleton) y `dia:AAAA-MM-DD`.
library;

import 'dart:typed_data';

import 'package:habitos_dominio/habitos_dominio.dart';

import '../../../nucleo/sensibles/llaves_habitos.dart';
import '../../../nucleo/sensibles/sobres.dart';
import '../../../nucleo/sensibles/subida_diferida.dart' show ModosLocales;

String claveDia(DateTime f) {
  final d = soloDia(f);
  return 'dia:${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class DocumentosSensibles {
  DocumentosSensibles({
    required this.llaves,
    required this.sobres,
    required this.modos,
    required this.persona,
    DateTime Function()? ahora,
  }) : _ahora = ahora ?? DateTime.now;

  final LlavesHabitos llaves;
  final AlmacenDeSobres sobres;
  final ModosLocales modos;
  final String persona;
  final DateTime Function() _ahora;

  int get ahoraMs => _ahora().millisecondsSinceEpoch;

  Future<(List<int>, List<int>)?> _llaves(TipoSensible t) async {
    final modo = await modos.modo(persona, t);
    final lt = await llaves.llaveDeTipo(persona, t, modo);
    final li = await llaves.llaveDeIds(persona, modo);
    return lt == null || li == null ? null : (lt, li);
  }

  Future<(Sobre, DocumentoSensible)?> _abrir(
    TipoSensible t,
    String clave,
  ) async {
    final k = await _llaves(t);
    if (k == null) return null;
    final id = LlavesHabitos.idOpaco(k.$2, t, clave);
    final s = await sobres.leer(persona, id);
    if (s == null) return null;
    final m = descifrarDocumento(
      llaveDeTipo: Uint8List.fromList(k.$1),
      persona: persona,
      sobre: s,
    );
    if (m == null) return null;
    return (
      s,
      DocumentoSensible.deJson((m['doc']! as Map).cast<String, Object?>()),
    );
  }

  Future<DocumentoSensible> leer(TipoSensible t, String clave) async =>
      (await _abrir(t, clave))?.$2 ?? const DocumentoSensible({});

  /// Agrega o reemplaza un elemento (sube la revisión del sobre).
  Future<void> poner(TipoSensible t, String clave, ElementoDoc e) async {
    final k = await _llaves(t);
    if (k == null) throw StateError('Sin llave para este tipo en este equipo.');
    final actual = await _abrir(t, clave);
    final doc = fusionarDocumentos(
      actual?.$2 ?? const DocumentoSensible({}),
      DocumentoSensible({e.id: e}),
    );
    final sobre = cifrarDocumento(
      llaveDeTipo: Uint8List.fromList(k.$1),
      llaveDeIds: Uint8List.fromList(k.$2),
      persona: persona,
      tipo: t,
      claveDoc: clave,
      documento: {'clave': clave, 'doc': doc.aJson()},
      revisionAnterior: actual?.$1.revision ?? 0,
    );
    await sobres.guardar(persona, sobre);
  }

  /// Tumba (más reciente que cualquier edición).
  Future<void> quitar(TipoSensible t, String clave, String id) async {
    final v = (await leer(t, clave)).elementos[id];
    if (v == null) return;
    await poner(
      t,
      clave,
      ElementoDoc(
        id: id,
        clase: v.clase,
        modificadoEn: ahoraMs,
        eliminado: true,
      ),
    );
  }

  /// Elementos vivos de la [clase] en un documento.
  Future<List<ElementoDoc>> vivos(
    TipoSensible t,
    String clave,
    String clase,
  ) async => [
    for (final e in (await leer(t, clave)).elementos.values)
      if (!e.eliminado && e.clase == clase) e,
  ];

  /// Todos los documentos de un tipo, abiertos en memoria (exportar mis
  /// datos, revisión). Los que no abren se omiten.
  Future<Map<String, DocumentoSensible>> todos(TipoSensible t) async {
    final k = await _llaves(t);
    if (k == null) return {};
    final r = <String, DocumentoSensible>{};
    for (final s in await sobres.todos(persona, tipo: t)) {
      final m = descifrarDocumento(
        llaveDeTipo: Uint8List.fromList(k.$1),
        persona: persona,
        sobre: s,
      );
      if (m == null) continue;
      r[m['clave']! as String] = DocumentoSensible.deJson(
        (m['doc']! as Map).cast<String, Object?>(),
      );
    }
    return r;
  }
}
