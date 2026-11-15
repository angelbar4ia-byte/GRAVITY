import '../contexto.dart';
import '../hallazgo.dart';
import '../modelo/archivo.dart';
import '../modelo/pregunta.dart';
import 'comun.dart';

/// V04 · Una sola correcta: la primera opción, con `porque`; en preguntas
/// abiertas, `aceptadas` no vacía.
///
/// Una opción distinta de la primera que lleve `porque` es una segunda
/// correcta: los distractores llevan `porque_no`.
List<Hallazgo> v04(Archivo a, Contexto c) {
  final h = <Hallazgo>[];
  for (final q in preguntasDe(a)) {
    switch (q) {
      case OpcionMultiple():
        h.addAll(_opciones(a, q.id, q.opciones));
      case HuecoOpciones():
        h.addAll(_opciones(a, q.id, q.opciones));
      case HuecoAbierto():
        h.addAll(_abierta(a, q.id, q.aceptadas));
      case FormacionPalabra():
        h.addAll(_abierta(a, q.id, q.aceptadas));
      case Transformacion():
        h.addAll(_abierta(a, q.id, q.aceptadas));
      case CompletarNota():
        h.addAll(_abierta(a, q.id, q.aceptadas));
      case OrdenarPalabras():
        h.addAll(_abierta(a, q.id, q.aceptadas));
      case RespuestaCorta():
        h.addAll(_abierta(a, q.id, q.aceptadas));
      default:
        break;
    }
  }
  return h;
}

List<Hallazgo> _opciones(Archivo a, String id, List<Opcion> opciones) {
  final h = <Hallazgo>[];
  if (opciones.isEmpty) return h;
  if ((opciones.first.porque ?? '').trim().isEmpty) {
    h.add(error(a, 'V04', 'la primera opción es la correcta y debe llevar "porque"', id: id));
  }
  for (var i = 1; i < opciones.length; i++) {
    if ((opciones[i].porque ?? '').trim().isNotEmpty) {
      h.add(error(a, 'V04', 'la opción ${letra(i)} lleva "porque": solo la primera puede ser correcta (los distractores llevan "porque_no")', id: id));
    }
  }
  return h;
}

List<Hallazgo> _abierta(Archivo a, String id, List<String> aceptadas) => [
      if (aceptadas.isEmpty)
        error(a, 'V04', '"aceptadas" no puede estar vacía: se listan todas las respuestas válidas', id: id),
    ];
