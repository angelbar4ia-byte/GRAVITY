import '../contexto.dart';
import '../hallazgo.dart';
import '../modelo/archivo.dart';
import '../modelo/contrato_sesion.dart';
import '../modelo/datos.dart';
import 'comun.dart';

/// Un escalón en forma de id de forma: `A2.1` es `a21`.
String ranuraDeEscalon(String escalon) =>
    escalon.toLowerCase().replaceAll('.', '');

/// La semana con dos cifras: `3` es `03`.
String dosCifras(int n) => n.toString().padLeft(2, '0');

/// V21 · Cada sesión cumple los mínimos por bloque (formato, secciones 7 y 7.1).
/// Es error. **Todas las cifras salen del contrato `gravity-sesion-60`**
/// (`por_dia`, `minutos_parte`, `tarjetas_nuevas`, `viernes`...), no del
/// código; si el contrato no trae una cifra, no se comprueba (V27 lo dice en el
/// contrato).
///
/// Comprueba, por día y por semana:
/// - los bloques y su orden: repaso, lección, pronunciación, producción y
///   traslado; el viernes, la mini prueba en lugar del repaso (semanas 1 a 7) y
///   la conversación guiada (semanas 1, 3, 5 y 8) o la prueba por unidad
///   (semanas 2, 4, 6 y 7) en lugar de la lección. El lunes de las semanas 3,
///   5, 7 y 8 la lección puede ser `repeticion_prueba`;
/// - los minutos que declara cada bloque y el total, iguales a los del contrato;
/// - los mínimos de la lección (explicación, ejemplos, error común, preguntas),
///   los elementos de pronunciación, la producción (consigna, cotejo, modelo y
///   modalidad), el traslado (dos audios distintos, uno monólogo y otro diálogo,
///   y las frases) y las tarjetas nuevas del día;
/// - los dos audios, iguales en las cinco sesiones de la semana;
/// - las formas a las que remiten la mini prueba y la prueba por unidad (que
///   existan, sean del uso, del escalón y de la unidad que toca);
/// - la conversación guiada: turnos, turnos de la persona, y en cada uno guía,
///   modelo y variantes.
///
/// Un dato que el contrato marca pendiente no se afirma como error: la regla de
/// monólogo y diálogo da aviso, y un único aviso por sesión nombra los datos
/// pendientes en que se apoya esta comprobación.
List<Hallazgo> v21(Archivo a, Contexto c) {
  if (a is! Sesion) return const [];
  final k = c.contratoSesion;
  if (k == null || !k.declaraLaSesion) return const [];
  final dia = a.dia;
  final semana = a.semana;
  if (dia == null || semana == null) return const [];
  final h = <Hallazgo>[];
  void err(String m, {String? id}) => h.add(error(a, 'V21', m, id: id));

  final semanasDelEscalon = enteroEn(
    c.contrato('gravity-escalon')?.datos,
    'escalera.semanas_por_escalon',
  );
  if (semana < 1 || (semanasDelEscalon != null && semana > semanasDelEscalon)) {
    err(
      'la semana $semana está fuera del escalón (de 1 a ${semanasDelEscalon ?? '?'})',
    );
  }

  // ------------------------------------------------------------ estructura
  final esperados = _bloquesEsperados(k, dia, semana);
  final reales = [for (final b in a.bloques) b.tipo];
  final enLugar = [
    for (var i = 0; i < esperados.length; i++) esperados[i].join(' o '),
  ];
  var ordenOk = reales.length == esperados.length;
  if (ordenOk) {
    for (var i = 0; i < esperados.length; i++) {
      if (!esperados[i].contains(reales[i])) ordenOk = false;
    }
  }
  if (!ordenOk) {
    err(
      'los bloques de un $dia de la semana $semana deben ser, en orden: ${enLugar.join(', ')}; la sesión trae: ${reales.join(', ')}',
    );
  }

  // -------------------------------------------------------------- minutos
  var declarados = 0.0;
  for (final b in a.bloques) {
    declarados += (b.minutos ?? 0).toDouble();
    final pide = _minutosDelContrato(k, b);
    if (pide != null && b.minutos != null && b.minutos != pide) {
      err(
        'el bloque ${b.tipo} declara ${_n(b.minutos!)} minutos y el contrato pide $pide',
      );
    }
  }
  final total = k.minutosTotales;
  if (total != null && declarados != total) {
    err(
      'los bloques declaran ${_n(declarados)} minutos en total y el contrato pide $total',
    );
  }

  // ------------------------------------------------------------- contenido
  for (final b in a.bloques) {
    switch (b) {
      case BloqueLeccion():
        _leccion(a, b, k, dia, err);
      case BloquePronunciacion():
        final min = k.elementosDePronunciacion(dia);
        if (min != null && b.elementos.length < min) {
          err(
            'la pronunciación trae ${b.elementos.length} elementos y el contrato pide $min o más el $dia',
          );
        }
      case BloqueProduccion():
        _produccion(a, b, k, dia, err);
      case BloqueTraslado():
        _traslado(a, b, k, c, h);
      case BloqueConversacion():
        _conversacion(a, b, k, h);
      case BloqueMiniPrueba():
        _forma(a, b.tipo, b.forma, 'mini', k, c, h, semana: semana);
      case BloquePruebaUnidad():
        final unidad = _unidadDeSemana(k.semanasDePruebaPorUnidad, semana);
        _forma(
          a,
          b.tipo,
          b.forma,
          'prueba_unidad',
          k,
          c,
          h,
          semana: semana,
          variante: 'a',
          unidad: unidad,
        );
        if (b.repeticion == null) {
          err(
            'el bloque prueba_unidad no trae "repeticion": la forma b que se usa el lunes siguiente',
          );
        } else {
          _forma(
            a,
            '${b.tipo} (repeticion)',
            b.repeticion,
            'prueba_unidad',
            k,
            c,
            h,
            semana: semana,
            variante: 'b',
            unidad: unidad,
          );
        }
      case BloqueRepeticionPrueba():
        _forma(
          a,
          b.tipo,
          b.forma,
          'prueba_unidad',
          k,
          c,
          h,
          semana: semana,
          variante: 'b',
          unidad: _unidadDeSemana(k.semanasDeRepeticion, semana),
        );
      case BloqueRepaso():
        break;
    }
  }

  // Tarjetas nuevas del día.
  final tarjetas = k.tarjetasNuevasDelDia(dia);
  if (tarjetas != null && a.tarjetas.length != tarjetas) {
    err(
      'trae ${a.tarjetas.length} tarjetas y el contrato pide $tarjetas el $dia',
    );
  }

  // Los mismos audios en las cinco sesiones de la semana.
  if (k.mismosAudiosTodaLaSemana) {
    final propios = _audios(a);
    for (final o in c.archivos) {
      if (o is! Sesion || identical(o, a) || o.estado == Estado.retirado) {
        continue;
      }
      if (o.escalon != a.escalon || o.semana != a.semana) continue;
      final otros = _audios(o);
      if (propios.isNotEmpty &&
          otros.isNotEmpty &&
          !_mismosElementos(propios, otros)) {
        err(
          'los audios de traslado (${propios.join(', ')}) no son los de "${o.id}" (${otros.join(', ')}), y el contrato pide los mismos en las cinco sesiones de la semana',
        );
      }
    }
  }

  // Un único aviso con los datos pendientes en que esta comprobación se apoya.
  final pend = <String>[];
  final pl = k.pendienteDeLeccion(dia);
  if (pl != null) pend.add('la lección del $dia (${pl.ruta})');
  if (k.pendienteDeModalidad != null &&
      const ['lunes', 'martes', 'miercoles'].contains(dia)) {
    pend.add('la modalidad de la producción de lunes a miércoles');
  }
  if (k.pendienteDeMonologoYDialogo != null) {
    pend.add('el criterio de monólogo y diálogo del traslado');
  }
  if (k.pendienteDeTarjetasNuevas != null) {
    pend.add('el bloque en que se cuentan las tarjetas nuevas');
  }
  if (dia == 'viernes') {
    for (final p in k.pendientesDelViernes) {
      pend.add(p.ruta);
    }
  }
  if (pend.isNotEmpty) {
    h.add(
      aviso(
        a,
        'V21',
        'esta sesión se comprueba con datos que el contrato marca pendientes: ${pend.join('; ')}',
      ),
    );
  }
  return h;
}

String _n(num n) => n == n.roundToDouble() ? '${n.round()}' : '$n';

List<String> _audios(Sesion s) => [
  for (final b in s.bloques)
    if (b is BloqueTraslado) ...b.audios,
];

bool _mismosElementos(List<String> a, List<String> b) {
  final x = {...a};
  final y = {...b};
  return x.length == y.length && x.containsAll(y);
}

/// Los tipos de bloque que admite cada posición, según el día y la semana.
List<List<String>> _bloquesEsperados(ContratoSesion k, String dia, int semana) {
  final miniSemanas = k.semanasDeMiniPrueba;
  final repaso =
      k.repasoSustituidoPor(dia) == 'mini_prueba' &&
          (miniSemanas == null || miniSemanas.contains(semana))
      ? 'mini_prueba'
      : 'repaso';
  final sustituto = k.leccionSustituidaPor(dia);
  final List<String> leccion;
  if (sustituto != null) {
    final semanasPu = k.semanasDePruebaPorUnidad ?? const [];
    leccion = [
      semanasPu.contains(semana) && dia == 'viernes'
          ? 'prueba_unidad'
          : sustituto,
    ];
  } else {
    final rep = k.semanasDeRepeticion ?? const [];
    leccion = [
      'leccion',
      if (rep.contains(semana) && dia == 'lunes') 'repeticion_prueba',
    ];
  }
  return [
    [repaso],
    leccion,
    ['pronunciacion'],
    ['produccion'],
    ['traslado'],
  ];
}

num? _minutosDelContrato(ContratoSesion k, Bloque b) => switch (b) {
  BloqueRepaso() || BloqueMiniPrueba() => k.minutosDeParte('repaso'),
  BloqueLeccion() ||
  BloqueConversacion() ||
  BloquePruebaUnidad() ||
  BloqueRepeticionPrueba() => k.minutosDeParte('leccion'),
  BloquePronunciacion() => k.minutosDeParte('pronunciacion'),
  BloqueProduccion() => k.minutosDeParte('produccion'),
  BloqueTraslado() => k.minutosTraslado,
};

void _leccion(
  Sesion s,
  BloqueLeccion b,
  ContratoSesion k,
  String dia,
  void Function(String, {String? id}) err,
) {
  if (k.exigeExplicacion(dia) && (b.explicacion ?? '').trim().isEmpty) {
    err('la lección del $dia necesita explicación');
  }
  final ej = k.ejemplosMinimos(dia);
  if (ej != null && b.ejemplos.length < ej) {
    err(
      'la lección trae ${b.ejemplos.length} ejemplos y el contrato pide $ej o más el $dia',
    );
  }
  if (k.exigeErrorComun(dia) && b.errorComun == null) {
    err('la lección del $dia necesita un error común');
  }
  final preg = k.preguntasMinimasDeLeccion(dia);
  if (preg != null && b.preguntas.length < preg) {
    err(
      'la lección trae ${b.preguntas.length} preguntas y el contrato pide $preg o más el $dia',
    );
  }
}

void _produccion(
  Sesion s,
  BloqueProduccion b,
  ContratoSesion k,
  String dia,
  void Function(String, {String? id}) err,
) {
  final t = b.tarea;
  if (t == null) {
    err('la producción no trae tarea');
    return;
  }
  final falta = <String>[];
  for (final r in k.requisitosDeProduccion) {
    final ok = switch (r) {
      'consigna' => (t.consigna ?? '').trim().isNotEmpty,
      'cotejo' => t.cotejo.isNotEmpty,
      'modelo' => (t.modelo ?? '').trim().isNotEmpty,
      _ => true,
    };
    if (!ok) falta.add(r);
  }
  if (falta.isNotEmpty) {
    err('la tarea de producción necesita ${falta.join(', ')}', id: t.id);
  }
  final modalidad = k.modalidadDeProduccion(dia);
  if (modalidad != null && t.modalidad != null && t.modalidad != modalidad) {
    err(
      'la producción del $dia es de ${t.modalidad} y el contrato pide $modalidad',
      id: t.id,
    );
  }
}

void _traslado(
  Sesion s,
  BloqueTraslado b,
  ContratoSesion k,
  Contexto c,
  List<Hallazgo> h,
) {
  void err(String m) => h.add(error(s, 'V21', m));
  final n = k.audiosDeTraslado;
  if (n != null && b.audios.length != n) {
    err('el traslado trae ${b.audios.length} audios y el contrato pide $n');
  }
  if (b.audios.toSet().length != b.audios.length && k.audiosDistintosEntreSi) {
    err('los audios del traslado deben ser distintos entre sí');
  }
  final frases = k.frasesMinimas;
  if (frases != null && b.frases.length < frases) {
    err(
      'el traslado trae ${b.frases.length} frases para repetir y el contrato pide $frases o más',
    );
  }
  // Un monólogo y un diálogo. Mientras el criterio esté pendiente en el
  // contrato, es un aviso.
  final voces = <List<String>>[];
  for (final id in b.audios) {
    final u = c.archivo(id);
    if (u is! Unidad || u.estimulo == null) continue;
    voces.add(
      {
        for (final t in u.estimulo!.guion)
          if (t.voz != 'N') t.voz,
      }.toList(),
    );
  }
  if (voces.length == 2 && (k.audiosDeTraslado ?? 2) == 2) {
    final monologos = voces.where((v) => v.length == 1).length;
    final dialogos = voces.where((v) => v.length >= 2).length;
    if (monologos != 1 || dialogos != 1) {
      final mensaje =
          'el traslado debe traer un monólogo (una sola voz, sin contar N) y un diálogo (dos o más voces); trae $monologos monólogos y $dialogos diálogos';
      final p = k.pendienteDeMonologoYDialogo;
      h.add(
        p != null
            ? aviso(
                s,
                'V21',
                '$mensaje (criterio pendiente en el contrato, no se da por error)',
              )
            : error(s, 'V21', mensaje),
      );
    }
  }
}

void _conversacion(
  Sesion s,
  BloqueConversacion b,
  ContratoSesion k,
  List<Hallazgo> h,
) {
  void err(String m, {String? id}) => h.add(error(s, 'V21', m, id: id));
  final min = k.turnosMinimosDeConversacion;
  if (min != null && b.turnos.length < min) {
    err(
      'la conversación guiada trae ${b.turnos.length} turnos y el contrato pide $min o más',
    );
  }
  final persona = b.turnos.where((t) => t.esDePersona).length;
  if (persona < k.turnosMinimosDeLaPersona) {
    err(
      'la conversación guiada trae $persona turnos de la persona y se piden ${k.turnosMinimosDeLaPersona} o más',
    );
  }
  var i = 0;
  for (final t in b.turnos) {
    i++;
    if (!t.esDePersona) continue;
    final donde = 'el turno $i de la conversación guiada';
    if ((t.guia ?? '').trim().isEmpty) err('$donde no trae guía');
    if (t.modelo.isEmpty) err('$donde no trae modelo');
    if (t.variantes.length < k.variantesMinimasPorTurno) {
      err(
        '$donde trae ${t.variantes.length} variantes aceptables y se piden ${k.variantesMinimasPorTurno} o más',
      );
    }
    if (t.palabrasClave.isEmpty) {
      h.add(
        aviso(
          s,
          'V21',
          '$donde no trae palabras clave: la app no podrá darlo por logrado',
        ),
      );
    }
  }
}

/// La forma a la que remite un bloque: que exista, sea del uso, del escalón y
/// de la unidad que toca, y se llame como el formato manda. [unidad] es la
/// unidad del escalón que corresponde a la semana (null en la mini prueba).
void _forma(
  Sesion s,
  String bloque,
  String? id,
  String uso,
  ContratoSesion k,
  Contexto c,
  List<Hallazgo> h, {
  required int semana,
  String? variante,
  int? unidad,
}) {
  if (id == null) return;
  void err(String m) => h.add(error(s, 'V21', 'el bloque $bloque: $m'));
  final f = c.archivo(id);
  if (f is! Forma) return; // V02 ya lo dice
  if (f.uso != uso) err('la forma "$id" es de uso ${f.uso} y se pide $uso');
  if (s.escalon != null && f.escalon != null && f.escalon != s.escalon) {
    err(
      'la forma "$id" es del escalón ${f.escalon} y la sesión es de ${s.escalon}',
    );
  }
  if (variante != null && f.variante != null && f.variante != variante) {
    err('la forma "$id" es la variante ${f.variante} y aquí va la $variante');
  }
  final esc = s.escalon == null ? null : ranuraDeEscalon(s.escalon!);
  if (uso == 'mini') {
    if (esc != null) {
      final esperado = 'mini-$esc-s${dosCifras(semana)}';
      if (id != esperado) {
        err(
          'la mini prueba de la semana $semana de ${s.escalon} debe llamarse "$esperado", no "$id"',
        );
      }
    }
    return;
  }
  if (unidad == null) return;
  if (f.unidadDelEscalon != null && f.unidadDelEscalon != unidad) {
    err(
      'la forma "$id" es la unidad ${f.unidadDelEscalon} del escalón y la semana $semana corresponde a la unidad $unidad',
    );
  }
  if (esc != null && variante != null) {
    final esperado = 'pu-$esc-u$unidad-$variante';
    if (id != esperado) {
      err('la forma de la semana $semana debe llamarse "$esperado", no "$id"');
    }
  }
}

/// La unidad del escalón que toca una semana: su posición (desde 1) en la lista
/// de semanas del contrato, o null si la semana no está.
int? _unidadDeSemana(List<int>? semanas, int semana) {
  if (semanas == null) return null;
  final i = semanas.indexOf(semana);
  return i < 0 ? null : i + 1;
}
