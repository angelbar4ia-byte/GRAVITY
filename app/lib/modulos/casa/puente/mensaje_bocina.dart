/// Salida hacia las bocinas (D6, D3).
///
/// GRAVITY solo habla por la bocina con recordatorios genéricos, pasos de
/// receta y la lectura de la lista de compras. Sin nombres de medicamentos ni
/// de personas, sin cifras ni dinero. Lo dicho pasa por Google, así que el
/// filtro corre **antes** de enviar y la única forma de crear un
/// [MensajeBocina] es validarlo.
library;

import 'frases.dart';

enum TipoMensajeBocina { recordatorioGenerico, pasoReceta, listaCompras }

/// Texto ya validado. Constructor privado: solo lo crea [FiltroBocina].
final class MensajeBocina {
  const MensajeBocina._(this.tipo, this.texto);
  final TipoMensajeBocina tipo;
  final String texto;
}

enum MotivoRechazo {
  vacio,
  demasiadoLargo,
  contieneCifras,
  contieneDinero,
  contieneDatoClinico,
  contieneNombre,
  contieneEnlace,
}

final class ResultadoFiltro {
  const ResultadoFiltro.ok(MensajeBocina this.mensaje) : motivo = null;
  const ResultadoFiltro.rechazado(MotivoRechazo this.motivo) : mensaje = null;
  final MensajeBocina? mensaje;
  final MotivoRechazo? motivo;
  bool get aceptado => mensaje != null;
}

final class FiltroBocina {
  /// [nombresPropios]: nombres de personas de la casa (se pasan en tiempo de
  /// ejecución desde el servidor; no se guardan en el repositorio).
  /// [medicamentos]: nombres de medicamentos conocidos, mismo origen.
  FiltroBocina({
    Iterable<String> nombresPropios = const [],
    Iterable<String> medicamentos = const [],
  }) : _nombres = nombresPropios
           .map(normalizarFrase)
           .where((s) => s.isNotEmpty)
           .toSet(),
       _meds = medicamentos
           .map(normalizarFrase)
           .where((s) => s.isNotEmpty)
           .toSet();

  static const int maximoCaracteres = 280;

  final Set<String> _nombres;
  final Set<String> _meds;

  /// Terminología clínica y de dosis que nunca se dice en voz alta, aunque no
  /// se conozca el medicamento concreto.
  static final RegExp _clinico = RegExp(
    r'\b(mg|mcg|ml|gotas?|pastillas?|tabletas?|capsulas?|dosis|medicamentos?|'
    r'medicina|insulina|inyeccion|diagnostico|alzheimer|demencia|glucosa|'
    r'presion arterial|receta medica|tratamiento)\b',
  );
  static final RegExp _dinero = RegExp(
    r'(\$|\b(pesos?|dolares?|mxn|usd|euros?|saldo|deuda|presupuesto|precio|'
    r'costo|cuesta|pago|pagar|tarjeta|cuenta bancaria)\b)',
  );
  static final RegExp _enlace = RegExp(r'(https?:|www\.|@\w)');

  ResultadoFiltro validar(TipoMensajeBocina tipo, String texto) {
    final t = texto.trim();
    if (t.isEmpty) return const ResultadoFiltro.rechazado(MotivoRechazo.vacio);
    if (t.length > maximoCaracteres) {
      return const ResultadoFiltro.rechazado(MotivoRechazo.demasiadoLargo);
    }
    if (_enlace.hasMatch(t)) {
      return const ResultadoFiltro.rechazado(MotivoRechazo.contieneEnlace);
    }
    final n = normalizarFrase(t);
    if (_dinero.hasMatch(t.toLowerCase()) || _dinero.hasMatch(n)) {
      return const ResultadoFiltro.rechazado(MotivoRechazo.contieneDinero);
    }
    if (RegExp(r'\d').hasMatch(t)) {
      return const ResultadoFiltro.rechazado(MotivoRechazo.contieneCifras);
    }
    if (_clinico.hasMatch(n) || _contieneAlguno(n, _meds)) {
      return const ResultadoFiltro.rechazado(MotivoRechazo.contieneDatoClinico);
    }
    if (_contieneAlguno(n, _nombres)) {
      return const ResultadoFiltro.rechazado(MotivoRechazo.contieneNombre);
    }
    return ResultadoFiltro.ok(MensajeBocina._(tipo, t));
  }

  bool _contieneAlguno(String normalizado, Set<String> palabras) {
    final padded = ' $normalizado ';
    return palabras.any((p) => padded.contains(' $p '));
  }
}
