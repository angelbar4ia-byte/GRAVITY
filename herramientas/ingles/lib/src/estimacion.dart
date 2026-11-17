/// Minutos que estima una sesión (V22), con las fórmulas del contrato
/// `gravity-sesion-60` (`estimacion_de_minutos`) y del formato 0.5, 7 y 7.1. Las
/// cifras salen del contrato; aquí solo está cómo se combinan.
///
/// Una estimación puede quedar **incompleta**: el contrato marca pendiente algo
/// que la fórmula necesita (el lugar del audio y del texto de la lección de
/// martes y jueves, los elementos del miércoles, el tiempo de los tipos de
/// pregunta que no trae). Una estimación incompleta no se da por mala: V22 la
/// reporta como aviso, no como error, porque un dato pendiente no decide nada.
library;

import 'contexto.dart';
import 'medidas.dart';
import 'modelo/archivo.dart';
import 'modelo/contrato_sesion.dart';
import 'texto.dart';

/// Lo que estima un bloque, frente a los minutos que declara.
class EstimacionDeBloque {
  EstimacionDeBloque(this.bloque, this.minutos, this.incompleta);
  final Bloque bloque;
  final double minutos;

  /// Lo que falta para que la estimación sea completa (vacío si lo es).
  final List<String> incompleta;

  num get declarados => bloque.minutos ?? 0;
  bool get esCompleta => incompleta.isEmpty;
}

class EstimacionDeSesion {
  EstimacionDeSesion(this.bloques);
  final List<EstimacionDeBloque> bloques;

  double get total => bloques.fold(0.0, (s, b) => s + b.minutos);

  /// Todo lo que deja incompleta la estimación del total.
  List<String> get incompleta => [for (final b in bloques) ...b.incompleta];
}

double _min(num segundos) => segundos / 60;

/// Estima la sesión. Devuelve null si el contrato no trae las fórmulas (V27 lo
/// dice en el contrato): sin ellas no hay nada que calcular.
EstimacionDeSesion? estimarSesion(Sesion s, Contexto c) {
  final k = c.contratoSesion;
  if (k == null) return null;
  final ppm = k.palabrasPorMinuto;
  final segEjemplo = k.segundosPorEjemplo;
  final segFrase = k.segundosPorFrase;
  final segElemento = k.segundosPorElemento;
  final segTarjeta = k.segundosPorTarjetaNueva;
  if (ppm == null ||
      segEjemplo == null ||
      segFrase == null ||
      segElemento == null ||
      segTarjeta == null) {
    return null;
  }
  final salida = <EstimacionDeBloque>[];
  for (final b in s.bloques) {
    final falta = <String>[];
    double minutos = 0;
    switch (b) {
      case BloqueRepaso():
        minutos = (b.minutos ?? 0).toDouble();
      case BloqueLeccion():
        final pendiente = s.dia == null ? null : k.pendienteDeLeccion(s.dia!);
        if (pendiente != null) {
          falta.add(
            'el contrato marca pendiente la lección del ${s.dia}${pendiente.nota == null ? '' : ' (${_primeraOracion(pendiente.nota!)})'}',
          );
        }
        minutos =
            contarPalabras(b.explicacion ?? '') / ppm +
            _min(b.ejemplos.length * segEjemplo);
        for (final q in b.preguntas) {
          final seg = k.segundosDePregunta(q.tipo);
          if (seg == null) {
            falta.add(
              'el contrato no da el tiempo de una pregunta de tipo ${q.tipo}',
            );
          } else {
            minutos += _min(seg);
          }
        }
      case BloquePronunciacion():
        minutos = _min(b.elementos.length * segElemento);
      case BloqueProduccion():
        final t = b.tarea;
        final completa =
            t != null &&
            (t.consigna ?? '').trim().isNotEmpty &&
            t.cotejo.isNotEmpty &&
            (t.modelo ?? '').trim().isNotEmpty;
        minutos = completa ? (b.minutos ?? 0).toDouble() : 0;
      case BloqueTraslado():
        var escucha = 0.0;
        for (final id in b.audios) {
          final u = c.archivo(id);
          if (u is! Unidad || u.estimulo == null) {
            falta.add('el audio "$id" no se puede leer');
            continue;
          }
          final veces =
              u.estimulo!.reproducciones ?? k.reproduccionesDeTraslado ?? 1;
          escucha +=
              contarPalabras(piezasDeEstimulo(u).join(' ')) / ppm * veces;
        }
        minutos =
            escucha +
            _min(b.frases.length * segFrase) +
            _min(s.tarjetas.length * segTarjeta) +
            (k.minutosDeParte('traslado-tarjetas') ?? 0);
      case BloqueMiniPrueba():
        final seg = k.segundosDePregunta('opcion_multiple');
        if (seg == null) {
          falta.add('el contrato no da el tiempo por pregunta');
        } else {
          final f = c.archivo(b.forma ?? '');
          final n = f is Forma
              ? _preguntasDeForma(f, c)
              : (k.preguntasDeMiniPrueba ?? 0);
          minutos = _min(n * seg);
        }
      case BloquePruebaUnidad():
        minutos = _pruebaDeUnidad(b.forma, c, k, falta);
      case BloqueRepeticionPrueba():
        minutos = _pruebaDeUnidad(b.forma, c, k, falta);
      case BloqueConversacion():
        final persona = b.turnos.where((t) => t.esDePersona).length;
        final sistema = b.turnos.length - persona;
        minutos = _min(
          persona * k.segundosPorTurnoDePersona +
              sistema * k.segundosPorTurnoDeSistema,
        );
    }
    salida.add(EstimacionDeBloque(b, minutos, falta));
  }
  return EstimacionDeSesion(salida);
}

String _primeraOracion(String nota) {
  final i = nota.indexOf('. ');
  final t = i < 0 ? nota : nota.substring(0, i + 1);
  return t.length > 110 ? '${t.substring(0, 107)}...' : t;
}

int _preguntasDeForma(Forma f, Contexto c) {
  var n = 0;
  for (final id in unidadesDeFormaTodas(f)) {
    final u = c.archivo(id);
    if (u is Unidad) n += contarPreguntas(u);
  }
  return n;
}

/// Las unidades que lista una forma, en orden y con repeticiones.
List<String> unidadesDeFormaTodas(Forma f) => [
  for (final s in f.secciones) ...s.unidades,
];

/// Una prueba por unidad: 40 segundos por pregunta más el audio, si lo lleva
/// (palabras ÷ 150 por las reproducciones). Sin la forma, con las cifras del
/// contrato (20 con audio, 15 sin).
double _pruebaDeUnidad(
  String? id,
  Contexto c,
  ContratoSesion k,
  List<String> falta,
) {
  final seg = k.segundosDePregunta('opcion_multiple');
  final ppm = k.palabrasPorMinuto;
  if (seg == null || ppm == null) {
    falta.add(
      'el contrato no da el tiempo por pregunta ni las palabras por minuto',
    );
    return 0;
  }
  final f = c.archivo(id ?? '');
  var preguntas = 0;
  var audio = 0.0;
  if (f is Forma) {
    for (final uid in unidadesDeFormaTodas(f)) {
      final u = c.archivo(uid);
      if (u is! Unidad) continue;
      preguntas += contarPreguntas(u);
      if (u.estimulo?.tipo == 'audio') {
        final veces =
            u.estimulo!.reproducciones ?? k.reproduccionesDePrueba ?? 1;
        audio += contarPalabras(piezasDeEstimulo(u).join(' ')) / ppm * veces;
      }
    }
  } else {
    preguntas = k.preguntasDePruebaConAudio ?? 0;
  }
  return _min(preguntas * seg) + audio;
}
