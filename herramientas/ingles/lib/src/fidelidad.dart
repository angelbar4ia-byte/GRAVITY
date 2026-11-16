/// Fidelidad de una forma (formato, sección 5): cuánto se parece a la prueba
/// oficial. La calcula la herramienta; ninguna fuente la afirma por su cuenta.
library;

import 'contexto.dart';
import 'medidas.dart';
import 'modelo/archivo.dart';
import 'modelo/formato.dart';

/// El resultado: `completa` solo si no hay ningún motivo para ser `reducida`.
class Fidelidad {
  const Fidelidad(this.motivos);

  /// Todo lo que impide que la forma sea completa, en el orden del contrato.
  final List<String> motivos;

  bool get completa => motivos.isEmpty;

  /// `completa` o `reducida`, como se muestra en el cuaderno y en la app.
  String get etiqueta => completa ? 'completa' : 'reducida';
}

/// Calcula la fidelidad de [f] con el contrato de su formato.
///
/// Es `completa` solo si, para CADA parte del contrato:
///
/// - la forma la usa, con el número de unidades y de preguntas que pide el
///   contrato (se cuentan preguntas y estímulos, no archivos: un archivo con
///   `estimulo: ninguno` aporta tantas unidades como preguntas lleve), y cada
///   unidad con las preguntas por unidad que pide;
/// - todos los estímulos están dentro de su rango de palabras;
/// - si es de escucha, cada unidad tiene un estímulo de audio con guion y se
///   oye las veces que pide el contrato;
/// - el contrato no marca la parte como pendiente.
///
/// Además, una unidad con un estímulo de imagen sin archivo (formato, 4.1), una
/// unidad retirada o una unidad que es de otra parte u otro formato impiden la
/// fidelidad completa. Sin contrato no se puede calcular nada y la forma es
/// `reducida`: la herramienta no inventa contratos.
///
/// Una forma que no usa alguna parte del contrato (por ejemplo, una práctica de
/// una sola parte) es `reducida` con el motivo "falta la parte" (o "faltan N
/// partes", todas juntas y al principio): no se parece al examen entero.
Fidelidad calcularFidelidad(Forma f, Contexto c) {
  final contrato = c.contrato(f.formato);
  if (contrato == null) {
    return Fidelidad([
      f.formato == null
          ? 'la forma no declara su formato: no hay contrato contra el que comprobarla'
          : 'sin contrato: no existe el formato "${f.formato}" en formatos/ y no se puede comprobar contra nada',
    ]);
  }
  final motivos = <String>[];
  final usos = <String, List<SeccionForma>>{};
  for (final s in f.secciones) {
    if (s.parte != null) (usos[s.parte!] ??= []).add(s);
  }
  for (final id in usos.keys) {
    if (contrato.parte(id) == null) {
      motivos.add('la forma usa la parte "$id", que no está en el contrato');
    }
  }
  final faltan = <String>[];
  final deLasPartes = <String>[];
  for (final seccion in contrato.secciones) {
    for (final parte in seccion.partes) {
      final secciones = usos[parte.id];
      if (secciones == null || secciones.isEmpty) {
        faltan.add('"${parte.id}"');
      } else {
        deLasPartes.addAll(_motivosDeParte(f, c, seccion, parte, secciones));
      }
    }
  }
  // Lo que falta, junto y primero; después, parte por parte, lo que no cuadra.
  if (faltan.length == 1) {
    motivos.add('falta la parte ${faltan.single}');
  } else if (faltan.isNotEmpty) {
    motivos.add('faltan ${faltan.length} partes del contrato: ${faltan.join(', ')}');
  }
  motivos.addAll(deLasPartes);
  return Fidelidad(motivos);
}

String _cuantas(int n, String uno, String varios) => '$n ${n == 1 ? uno : varios}';

String _veces(int? n) => n == 1 ? '1 vez' : '${n ?? 0} veces';

/// Una parte con su sección: `escucha` si el contrato lo dice por el tipo de
/// estímulo, por las reproducciones o por el nombre de la sección.
bool _esDeEscucha(Seccion s, Parte p) =>
    p.tipoEstimulo == 'audio' ||
    p.reproducciones != null ||
    s.id.contains('listening') ||
    s.id.contains('escucha');

List<String> _motivosDeParte(
  Forma f,
  Contexto c,
  Seccion seccion,
  Parte parte,
  List<SeccionForma> secciones,
) {
  final p = '"${parte.id}"';
  final m = <String>[];
  if (secciones.length > 1) {
    m.add('la parte $p aparece en ${secciones.length} secciones de la forma');
  }
  if (parte.pendiente) {
    m.add('el contrato tiene datos pendientes en la parte $p');
  }

  // Las unidades de la parte, sin repetir.
  final unidades = <Unidad>[];
  final vistas = <String>{};
  for (final s in secciones) {
    for (final id in s.unidades) {
      if (!vistas.add(id)) {
        m.add('la unidad "$id" está repetida en la parte $p');
        continue;
      }
      final x = c.archivo(id);
      if (x == null) {
        m.add('la unidad "$id" no existe');
      } else if (x is! Unidad) {
        m.add('"$id" no es una unidad');
      } else {
        unidades.add(x);
      }
    }
  }

  var nUnidades = 0;
  var nPreguntas = 0;
  final rango = parte.pendiente ? null : rangoDePalabras(parte);
  for (final u in unidades) {
    nUnidades += contarUnidades(u);
    nPreguntas += contarPreguntas(u);
    final id = '"${u.id}"';

    if (u.estado == Estado.retirado) m.add('la unidad $id está retirada');
    if (u.parte != parte.id) {
      m.add('la unidad $id es de la parte "${u.parte}" y la forma la usa en $p');
    }
    if (u.formato != f.formato) {
      m.add('la unidad $id es del formato "${u.formato}" y la forma es de "${f.formato}"');
    }
    final e = u.estimulo;
    if (e != null && e.tipo == 'imagen' && (e.archivo ?? '').isEmpty) {
      m.add('la unidad $id tiene un estímulo de imagen sin archivo: solo se muestra su descripción');
    }

    final porUnidad = parte.preguntasPorUnidad;
    if (e?.tipo != 'ninguno' && porUnidad != null && !enRango(contarPreguntas(u), porUnidad)) {
      m.add('la unidad $id tiene ${_cuantas(contarPreguntas(u), 'pregunta', 'preguntas')} y el contrato de $p pide ${describirRango(porUnidad)} por unidad');
    }

    if (rango != null) {
      for (final medida in medidasDeEstimulo(u)) {
        if (!enRango(medida.palabras, rango)) {
          m.add('${medida.id == u.id ? 'la unidad $id' : 'la oración original de "${medida.id}"'} tiene ${_cuantas(medida.palabras, 'palabra', 'palabras')} y el contrato de $p pide ${describirRango(rango)}');
        }
      }
    }

    if (_esDeEscucha(seccion, parte)) {
      if (e == null || e.tipo != 'audio') {
        m.add('la parte $p es de escucha y la unidad $id no tiene estímulo de audio con guion');
      } else {
        if (turnosDeHabla(e).isEmpty) {
          m.add('el audio de la unidad $id no tiene guion con turnos de habla');
        }
        if (parte.reproducciones != null && e.reproducciones != parte.reproducciones) {
          m.add('el audio de la unidad $id se oye ${_veces(e.reproducciones)} y el contrato de $p pide ${_veces(parte.reproducciones)}');
        }
      }
    }
  }

  final pideUnidades = parte.unidades;
  if (pideUnidades != null) {
    if (nUnidades != pideUnidades) {
      m.add('la parte $p tiene ${_cuantas(nUnidades, 'unidad', 'unidades')} y el contrato pide $pideUnidades');
    }
  } else if (!parte.pendiente) {
    m.add('el contrato no da el número de unidades de la parte $p');
  }
  final pidePreguntas = preguntasQuePide(parte);
  if (pidePreguntas != null) {
    if (!enRango(nPreguntas, pidePreguntas)) {
      m.add('la parte $p tiene ${_cuantas(nPreguntas, 'pregunta', 'preguntas')} y el contrato pide ${describirRango(pidePreguntas)}');
    }
  } else if (!parte.pendiente) {
    m.add('el contrato no da el número de preguntas de la parte $p');
  }
  return m;
}
