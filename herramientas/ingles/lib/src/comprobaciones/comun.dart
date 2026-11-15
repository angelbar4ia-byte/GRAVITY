import '../hallazgo.dart';
import '../modelo/archivo.dart';
import '../modelo/pregunta.dart';

Hallazgo error(Archivo a, String codigo, String mensaje, {String? id}) =>
    Hallazgo(
      archivo: a.ruta,
      id: id ?? a.id,
      codigo: codigo,
      gravedad: Gravedad.error,
      mensaje: mensaje,
    );

Hallazgo aviso(Archivo a, String codigo, String mensaje, {String? id}) =>
    Hallazgo(
      archivo: a.ruta,
      id: id ?? a.id,
      codigo: codigo,
      gravedad: Gravedad.aviso,
      mensaje: mensaje,
    );

/// Lo que falta (contrato, niveles) es aviso en `borrador` y error de
/// `validado` en adelante (plan, ficha de P1.2).
Hallazgo faltante(Archivo a, String codigo, String mensaje, {String? id}) =>
    (a.estado?.exigeLimpio ?? false)
        ? error(a, codigo, mensaje, id: id)
        : aviso(a, codigo, mensaje, id: id);

/// Preguntas con razón obligatoria (todas las objetivas): las que no son de
/// producción, repetir ni pronunciación.
bool esObjetiva(Pregunta q) =>
    q is! Repetir && q is! PronunciacionPregunta && q is! Produccion;

/// Nombre de una opción: A, B, C...
String letra(int i) => String.fromCharCode(65 + i);
