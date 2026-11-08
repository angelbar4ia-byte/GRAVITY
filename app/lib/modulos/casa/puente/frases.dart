/// Frases fijas de las bocinas (D6) y su traducción a herramientas (D9).
///
/// Cada frase de Google Home activa una escena virtual del puente; el puente
/// la recibe como [EventoFrase] y la traduce a una herramienta de GRAVITY
/// **solo si el rol que la pide puede usarla**. Si no, no pasa nada (sin
/// error visible, sin voz, sin rastro de datos).
///
/// Las bocinas siempre tienen el rol Casa (D5: la voz no identifica). Dueño,
/// pareja y familiar solo reciben por la bocina lo que está en esta tabla; la
/// cuidadora no tiene acceso a este canal.
library;

import '../../../nucleo/contratos/roles.dart';

/// Una frase fija aprobada.
final class FraseFija {
  const FraseFija({
    required this.id,
    required this.texto,
    required this.herramienta,
    required this.roles,
  });

  /// Identificador de la escena virtual en el puente (sin acentos).
  final String id;

  /// Lo que se dice: "Hey Google, texto".
  final String texto;

  /// Herramienta de GRAVITY a ejecutar (formato `modulo.accion`).
  final String herramienta;

  /// Roles que pueden usarla.
  final Set<Rol> roles;
}

/// Roles con acceso al canal de bocinas. La cuidadora queda fuera (D5, D18).
const Set<Rol> rolesDeBocina = {
  Rol.casa,
  Rol.dueno,
  Rol.coadministrador,
  Rol.familiar,
};

/// Tabla cerrada frase -> herramienta -> roles (aprobada 8/nov/2026).
/// Ninguna frase lleva datos libres (D6). Todas son de lectura.
const List<FraseFija> frasesFijas = [
  FraseFija(
    id: 'siguiente_paso',
    texto: 'siguiente paso',
    herramienta: 'alimentacion.receta_siguiente_paso',
    roles: rolesDeBocina,
  ),
  FraseFija(
    id: 'paso_anterior',
    texto: 'paso anterior',
    herramienta: 'alimentacion.receta_paso_anterior',
    roles: rolesDeBocina,
  ),
  FraseFija(
    id: 'repite_paso',
    texto: 'repite el paso',
    herramienta: 'alimentacion.receta_repetir_paso',
    roles: rolesDeBocina,
  ),
  FraseFija(
    id: 'que_cocino_hoy',
    texto: 'qué cocino hoy',
    herramienta: 'alimentacion.que_cocino_hoy',
    roles: rolesDeBocina,
  ),
  FraseFija(
    id: 'lee_lista_compras',
    texto: 'lee la lista de compras',
    herramienta: 'alimentacion.leer_lista_compras',
    roles: rolesDeBocina,
  ),
];

/// Normaliza para comparar: minúsculas, sin acentos, sin signos, espacios simples.
String normalizarFrase(String s) {
  const de = 'áàäâéèëêíìïîóòöôúùüûñ';
  const a = 'aaaaeeeeiiiioooouuuun';
  final b = StringBuffer();
  for (final c in s.toLowerCase().runes) {
    final ch = String.fromCharCode(c);
    final i = de.indexOf(ch);
    b.write(i >= 0 ? a[i] : ch);
  }
  return b
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Busca por id de escena o por texto; `null` si no está en la tabla.
FraseFija? buscarFrase(String entrada) {
  final n = normalizarFrase(entrada);
  for (final f in frasesFijas) {
    if (f.id == entrada || normalizarFrase(f.texto) == n) return f;
  }
  return null;
}

/// Lo que el puente recibe de Google Home / Home Assistant.
final class EventoFrase {
  const EventoFrase({required this.frase, required this.rol, this.bocina});

  /// Id de escena o texto de la frase.
  final String frase;

  /// Rol con el que corre el puente (siempre [Rol.casa] en las bocinas).
  final Rol rol;

  /// Bocina donde se escuchó, para responder ahí (D6).
  final String? bocina;
}

/// Ejecuta una herramienta de GRAVITY con el rol dado. En la app real lo
/// implementa el registro de herramientas (que vuelve a revisar el rol);
/// en pruebas, uno falso.
abstract interface class EjecutorHerramienta {
  Future<void> ejecutar(String herramienta, {required Rol rol, String? bocina});
}

enum ResultadoFrase { ejecutada, rolNoPermitido, fraseDesconocida }

/// Traduce frases a herramientas respetando la tabla y el rol.
final class TraductorFrases {
  const TraductorFrases(this._ejecutor, {this.tabla = frasesFijas});

  final EjecutorHerramienta _ejecutor;
  final List<FraseFija> tabla;

  Future<ResultadoFrase> procesar(EventoFrase evento) async {
    final n = normalizarFrase(evento.frase);
    FraseFija? frase;
    for (final f in tabla) {
      if (f.id == evento.frase || normalizarFrase(f.texto) == n) {
        frase = f;
        break;
      }
    }
    if (frase == null) return ResultadoFrase.fraseDesconocida;
    if (!frase.roles.contains(evento.rol)) return ResultadoFrase.rolNoPermitido;
    await _ejecutor.ejecutar(
      frase.herramienta,
      rol: evento.rol,
      bocina: evento.bocina,
    );
    return ResultadoFrase.ejecutada;
  }
}
