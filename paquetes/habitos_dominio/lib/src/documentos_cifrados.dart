import 'dart:convert';

/// Primitivas de cifrado que el dominio solo declara (la app implementa
/// AES-256-GCM, HKDF y HMAC-SHA256 con pointycastle).
abstract class Cifrador {
  /// Devuelve `nonce ‖ texto cifrado ‖ etiqueta`.
  List<int> cifrar({
    required List<int> llave,
    required List<int> datos,
    required List<int> aad,
  });

  /// Lanza [FormatException] si la etiqueta o los datos asociados no cuadran.
  List<int> descifrar({
    required List<int> llave,
    required List<int> sobre,
    required List<int> aad,
  });

  /// HKDF-SHA256 con `info`.
  List<int> derivar({required List<int> llave, required String info});

  List<int> hmac(List<int> llave, List<int> datos);
}

/// Datos asociados: ata el sobre a su persona, tipo, id y revisión.
List<int> datosAsociados(
        String persona, String tipo, String id, int revision) =>
    utf8.encode('gravity-hab-v1|$persona|$tipo|$id|$revision');

String _b64(List<int> b) => base64Url.encode(b).replaceAll('=', '');
List<int> _deb64(String s) =>
    base64Url.decode(s + '=' * ((4 - s.length % 4) % 4));

const _versionSobre = 1;

/// Sobre cifrado como lo guarda `hab_sobres.cifrado`.
String sellarSobre(
  Cifrador c, {
  required List<int> llaveDelTipo,
  required String persona,
  required String tipo,
  required String id,
  required int revision,
  required Map<String, Object?> documento,
}) {
  final ct = c.cifrar(
    llave: llaveDelTipo,
    datos: utf8.encode(jsonEncode(documento)),
    aad: datosAsociados(persona, tipo, id, revision),
  );
  return _b64([_versionSobre, ...ct]);
}

Map<String, Object?> abrirSobre(
  Cifrador c,
  String sobre, {
  required List<int> llaveDelTipo,
  required String persona,
  required String tipo,
  required String id,
  required int revision,
}) {
  final b = _deb64(sobre);
  if (b.isEmpty || b.first != _versionSobre) {
    throw const FormatException('Versión de sobre desconocida.');
  }
  final pt = c.descifrar(
    llave: llaveDelTipo,
    sobre: b.sublist(1),
    aad: datosAsociados(persona, tipo, id, revision),
  );
  return (jsonDecode(utf8.decode(pt)) as Map).cast<String, Object?>();
}

/// Id opaco del sobre: primeros 16 bytes de HMAC(llave de ids, tipo‖clave).
String idDeSobre(Cifrador c, List<int> llaveDeIds, String tipo, String claveDoc) {
  final h = c.hmac(llaveDeIds, utf8.encode('$tipo|$claveDoc')).sublist(0, 16);
  final x = h.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
  return '${x.substring(0, 8)}-${x.substring(8, 12)}-${x.substring(12, 16)}-'
      '${x.substring(16, 20)}-${x.substring(20, 32)}';
}

/// Un elemento de un documento (regla 91).
class ElementoDoc {
  const ElementoDoc({
    required this.id,
    required this.clase,
    required this.modificadoEn,
    this.eliminado = false,
    this.datos = const {},
  });
  final String id;
  final String clase;
  final int modificadoEn; // ms desde 1970
  final bool eliminado;
  final Map<String, Object?> datos;

  Map<String, Object?> aJson() => {
        'clase': clase,
        'modificado_en': modificadoEn,
        'eliminado': eliminado,
        'datos': datos,
      };

  static ElementoDoc deJson(String id, Map<String, Object?> j) => ElementoDoc(
        id: id,
        clase: j['clase']! as String,
        modificadoEn: j['modificado_en']! as int,
        eliminado: (j['eliminado'] as bool?) ?? false,
        datos: ((j['datos'] as Map?) ?? const {}).cast<String, Object?>(),
      );

  String get _clave => jsonEncode(aJson());
}

/// Documento cifrado: `{v, elementos}`.
class DocumentoSensible {
  const DocumentoSensible(this.elementos);
  final Map<String, ElementoDoc> elementos;

  Map<String, Object?> aJson() => {
        'v': 1,
        'elementos': {for (final e in elementos.values) e.id: e.aJson()},
      };

  static DocumentoSensible deJson(Map<String, Object?> j) {
    final m = (j['elementos'] as Map).cast<String, Object?>();
    return DocumentoSensible({
      for (final e in m.entries)
        e.key: ElementoDoc.deJson(e.key, (e.value! as Map).cast<String, Object?>())
    });
  }
}

/// Fusión por elemento: gana el `modificado_en` más reciente; en empate, la
/// tumba y luego el contenido mayor (determinista). Conmutativa e idempotente.
DocumentoSensible fusionarDocumentos(DocumentoSensible a, DocumentoSensible b) {
  final r = <String, ElementoDoc>{...a.elementos};
  for (final e in b.elementos.values) {
    final x = r[e.id];
    if (x == null || _gana(e, x)) r[e.id] = e;
  }
  return DocumentoSensible(r);
}

bool _gana(ElementoDoc n, ElementoDoc v) {
  if (n.modificadoEn != v.modificadoEn) return n.modificadoEn > v.modificadoEn;
  if (n.eliminado != v.eliminado) return n.eliminado;
  return n._clave.compareTo(v._clave) > 0;
}

/// Cifrador falso SOLO para pruebas del dominio (no es seguro).
class CifradorFalso implements Cifrador {
  List<int> _flujo(List<int> llave, int n) =>
      [for (var i = 0; i < n; i++) (llave[i % llave.length] * 31 + i) & 255];

  int _tag(List<int> llave, List<int> aad, List<int> ct) {
    var t = 7;
    for (final x in [...llave, ...aad, ...ct]) {
      t = (t * 131 + x) & 0xFFFFFF;
    }
    return t;
  }

  @override
  List<int> cifrar({
    required List<int> llave,
    required List<int> datos,
    required List<int> aad,
  }) {
    final f = _flujo(llave, datos.length);
    final ct = [for (var i = 0; i < datos.length; i++) datos[i] ^ f[i]];
    final t = _tag(llave, aad, ct);
    return [...ct, t >> 16 & 255, t >> 8 & 255, t & 255];
  }

  @override
  List<int> descifrar({
    required List<int> llave,
    required List<int> sobre,
    required List<int> aad,
  }) {
    if (sobre.length < 3) throw const FormatException('Sobre corto.');
    final ct = sobre.sublist(0, sobre.length - 3);
    final t = _tag(llave, aad, ct);
    final g = sobre.sublist(sobre.length - 3);
    if (g[0] != t >> 16 & 255 || g[1] != t >> 8 & 255 || g[2] != t & 255) {
      throw const FormatException('Etiqueta inválida.');
    }
    final f = _flujo(llave, ct.length);
    return [for (var i = 0; i < ct.length; i++) ct[i] ^ f[i]];
  }

  @override
  List<int> derivar({required List<int> llave, required String info}) =>
      hmac(llave, utf8.encode(info));

  @override
  List<int> hmac(List<int> llave, List<int> datos) => [
        for (var j = 0; j < 32; j++)
          () {
            var h = 2166136261 ^ (j * 16777619);
            for (final x in [...llave, 0, ...datos]) {
              h = ((h ^ x) * 16777619) & 0xFFFFFFFF;
            }
            return (h ^ (h >> 13) ^ (h >> 24)) & 255;
          }()
      ];
}
