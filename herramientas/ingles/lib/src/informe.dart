/// La orden `informe`: cuánto hay frente a lo que pide cada contrato, la
/// fidelidad de cada forma y la cobertura por escalón. No es una validación: lee
/// lo que haya y lo cuenta; no juzga.
library;

import 'contexto.dart';
import 'fidelidad.dart';
import 'medidas.dart';
import 'modelo/archivo.dart';
import 'modelo/formato.dart';

/// Una parte de un contrato con lo que hay de ella en el banco.
class FilaDeParte {
  FilaDeParte({
    required this.parte,
    required this.unidades,
    required this.preguntas,
    required this.palabras,
  });

  final Parte parte;

  /// Unidades y preguntas que aportan las unidades de esa parte (las que no
  /// están retiradas), tal como las cuenta el contrato.
  final int unidades;
  final int preguntas;

  /// Las palabras de cada estímulo medible de esas unidades, ordenadas.
  final List<int> palabras;

  /// Lo que pide el contrato para UNA forma: unidades y preguntas.
  String get pideUnidades =>
      parte.unidades == null ? '?' : '${parte.unidades}';
  String get pidePreguntas {
    final r = preguntasQuePide(parte);
    return r == null ? '?' : describirRango(r);
  }

  int? get minimo => palabras.isEmpty ? null : palabras.first;
  int? get maximo => palabras.isEmpty ? null : palabras.last;

  /// La mediana: con una cantidad par, el promedio de las dos de en medio.
  num? get mediana {
    if (palabras.isEmpty) return null;
    final n = palabras.length;
    if (n.isOdd) return palabras[n ~/ 2];
    return (palabras[n ~/ 2 - 1] + palabras[n ~/ 2]) / 2;
  }

  /// El rango de palabras del contrato, con su origen y si está pendiente.
  String get rango {
    final r = rangoDePalabras(parte);
    final partes = <String>[
      if (r != null) describirRango(r) else 'sin rango',
      if (r?.origen != null) r!.origen!,
      if (parte.pendiente) 'pendiente',
    ];
    return partes.length == 1 ? partes.single : '${partes.first} (${partes.skip(1).join(', ')})';
  }
}

/// Un contrato con sus partes.
class ContratoEnInforme {
  ContratoEnInforme(this.id, this.nombre, this.filas);
  final String id;
  final String? nombre;
  final List<FilaDeParte> filas;
}

/// Una forma con su fidelidad.
class FormaEnInforme {
  FormaEnInforme(this.forma, this.fidelidad);
  final Forma forma;
  final Fidelidad fidelidad;
}

/// Lo que un escalón tiene de una habilidad: en cuántas sesiones o unidades hay
/// al menos una pregunta de esa habilidad, y cuántas preguntas son.
class FilaDeHabilidad {
  FilaDeHabilidad(this.habilidad, this.unidades, this.preguntas);
  final String habilidad;
  final int unidades;
  final int preguntas;
}

/// La cobertura de un escalón: las sesiones que dicen ser de él, los audios de
/// traslado que esas sesiones usan y sus preguntas por habilidad.
class EscalonEnInforme {
  EscalonEnInforme(this.escalon, this.sesiones, this.audios, this.filas);
  final String escalon;
  final int sesiones;
  final int audios;
  final List<FilaDeHabilidad> filas;
}

/// El informe de un conjunto de archivos.
class Informe {
  Informe._({
    required this.resumen,
    required this.contratos,
    required this.sinContrato,
    required this.formas,
    required this.escalones,
    required this.sesionesSinEscalon,
  });

  /// Una línea con cuántos archivos hay de cada tipo.
  final String resumen;
  final List<ContratoEnInforme> contratos;

  /// Unidades cuyo formato no tiene contrato: formato → (unidades, preguntas).
  final Map<String, (int, int)> sinContrato;
  final List<FormaEnInforme> formas;

  /// Null si no hay `niveles.yaml` ("sin niveles").
  final List<EscalonEnInforme>? escalones;

  /// Sesiones cuyo escalón no está en `niveles.yaml`.
  final int sesionesSinEscalon;

  /// Construye el informe de unos archivos ya leídos.
  factory Informe.de(List<Archivo> archivos) {
    final c = Contexto(archivos);
    final vivos = [for (final a in archivos) if (a.estado != Estado.retirado) a];
    final unidades = [for (final a in vivos) if (a is Unidad) a];
    final sesiones = [for (final a in vivos) if (a is Sesion) a];
    final formas = [for (final a in vivos) if (a is Forma) a];
    final contratosLeidos = [for (final a in vivos) if (a is ArchivoFormato) a];

    final resumen = '${archivos.length} archivos leídos: '
        '${_cuantas(unidades.length, 'unidad', 'unidades')}, '
        '${_cuantas(sesiones.length, 'sesión', 'sesiones')}, '
        '${_cuantas(formas.length, 'forma', 'formas')}, '
        '${_cuantas(contratosLeidos.length, 'contrato', 'contratos')}, '
        '${_cuantas(archivos.whereType<ArchivoNiveles>().length, 'archivo de niveles', 'archivos de niveles')}'
        '${archivos.any((a) => a is ArchivoIlegible) ? ', ${archivos.whereType<ArchivoIlegible>().length} ilegibles (corre validar)' : ''}.';

    // Cobertura de cada contrato.
    final contratos = <ContratoEnInforme>[];
    for (final a in contratosLeidos) {
      final filas = <FilaDeParte>[];
      for (final s in a.contrato.secciones) {
        for (final p in s.partes) {
          final deLaParte = [
            for (final u in unidades)
              if (u.formato == a.id && u.parte == p.id) u,
          ];
          filas.add(FilaDeParte(
            parte: p,
            unidades: deLaParte.fold(0, (n, u) => n + contarUnidades(u)),
            preguntas: deLaParte.fold(0, (n, u) => n + contarPreguntas(u)),
            palabras: [
              for (final u in deLaParte) for (final m in medidasDeEstimulo(u)) m.palabras,
            ]..sort(),
          ));
        }
      }
      contratos.add(ContratoEnInforme(a.id, a.contrato.nombre, filas));
    }

    // Unidades cuyo contrato no existe.
    final sinContrato = <String, (int, int)>{};
    for (final u in unidades) {
      if (u.formato == null || c.contrato(u.formato) != null) continue;
      final (n, q) = sinContrato[u.formato!] ?? (0, 0);
      sinContrato[u.formato!] = (n + contarUnidades(u), q + contarPreguntas(u));
    }

    return Informe._(
      resumen: resumen,
      contratos: contratos,
      sinContrato: sinContrato,
      formas: [for (final f in formas) FormaEnInforme(f, calcularFidelidad(f, c))],
      escalones: c.niveles == null ? null : _escalones(c, sesiones, unidades),
      sesionesSinEscalon: c.niveles == null
          ? 0
          : sesiones.where((s) => !c.niveles!.escalones.contains(s.escalon)).length,
    );
  }

  /// El informe en texto, listo para imprimir.
  String aTexto({String? ruta}) {
    final b = StringBuffer();
    b.writeln('Informe${ruta == null ? '' : ' de $ruta'}');
    b.writeln(resumen);
    b.writeln();
    b.writeln('1. Cobertura por contrato y parte');
    b.writeln('   Unidades y preguntas: las que hay en el banco / las que pide el contrato para una forma.');
    b.writeln('   Palabras: mínimo / mediana / máximo de los estímulos, frente al rango del contrato.');
    if (contratos.isEmpty) b.writeln('   sin contratos');
    for (final c in contratos) {
      b.writeln();
      b.writeln('${c.id}${c.nombre == null ? '' : ' · ${c.nombre}'}');
      _tabla(b, [
        ['parte', 'unidades', 'preguntas', 'palabras (mín / med / máx)', 'rango del contrato'],
        for (final f in c.filas)
          [
            f.parte.id,
            '${f.unidades} / ${f.pideUnidades}',
            '${f.preguntas} / ${f.pidePreguntas}',
            f.palabras.isEmpty ? '-' : '${f.minimo} / ${_numero(f.mediana!)} / ${f.maximo}',
            f.rango,
          ],
      ]);
    }
    if (sinContrato.isNotEmpty) {
      b.writeln();
      b.writeln('Unidades de formatos sin contrato:');
      for (final e in sinContrato.entries) {
        b.writeln('  ${e.key}: ${_cuantas(e.value.$1, 'unidad', 'unidades')}, ${_cuantas(e.value.$2, 'pregunta', 'preguntas')}');
      }
    }

    b.writeln();
    b.writeln('2. Fidelidad de las formas');
    if (formas.isEmpty) b.writeln('   sin formas');
    for (final f in formas) {
      b.writeln('   ${f.forma.id} (${f.forma.uso ?? 'sin uso'}, ${f.forma.formato ?? 'sin formato'}, ${f.forma.estado?.name ?? 'sin estado'}): ${f.fidelidad.etiqueta}');
      for (final m in f.fidelidad.motivos) {
        b.writeln('     - $m');
      }
    }

    b.writeln();
    b.writeln('3. Cobertura por escalón');
    final es = escalones;
    if (es == null) {
      b.writeln('   sin niveles');
    } else {
      b.writeln('   Sesiones y audios de traslado de cada escalón; unidades = sesiones o audios con al menos una pregunta de la habilidad.');
      if (es.isEmpty) b.writeln('   niveles.yaml no lista ningún escalón');
      for (final e in es) {
        b.writeln('   ${e.escalon}: ${_cuantas(e.sesiones, 'sesión', 'sesiones')}, ${_cuantas(e.audios, 'audio de traslado', 'audios de traslado')}');
        if (e.filas.isEmpty) {
          b.writeln('     sin preguntas');
        } else {
          _tabla(b, [
            ['habilidad', 'unidades', 'preguntas'],
            for (final f in e.filas) [f.habilidad, '${f.unidades}', '${f.preguntas}'],
          ], sangria: '     ');
        }
      }
      if (sesionesSinEscalon > 0) {
        b.writeln('   ${_cuantas(sesionesSinEscalon, 'sesión', 'sesiones')} con un escalón que niveles.yaml no lista');
      }
    }
    return b.toString();
  }
}

/// La cobertura de cada escalón de `niveles.yaml`: sus sesiones (por el campo
/// `escalon`) y los audios que usan. Las unidades de examen no entran: declaran
/// su etapa (`nivel`), no su escalón.
List<EscalonEnInforme> _escalones(Contexto c, List<Sesion> sesiones, List<Unidad> unidades) {
  final niveles = c.niveles!;
  final salida = <EscalonEnInforme>[];
  for (final escalon in niveles.escalones) {
    final deEscalon = [for (final s in sesiones) if (s.escalon == escalon) s];
    final audios = <Unidad>[];
    for (final s in deEscalon) {
      for (final b in s.bloques) {
        if (b is! BloqueTraslado) continue;
        for (final id in b.audios) {
          final u = c.archivo(id);
          if (u is Unidad && !audios.any((x) => identical(x, u))) audios.add(u);
        }
      }
    }
    final archivos = <Archivo>[...deEscalon, ...audios];
    final conteo = <String, (Set<Archivo>, int)>{};
    for (final a in archivos) {
      for (final q in preguntasDe(a)) {
        final h = q.habilidad;
        if (h == null) continue;
        final (donde, n) = conteo[h] ?? (<Archivo>{}, 0);
        conteo[h] = (donde..add(a), n + preguntasQueAporta(q));
      }
    }
    final orden = [
      ...niveles.habilidades.where(conteo.containsKey),
      ...(conteo.keys.where((h) => !niveles.habilidades.contains(h)).toList()..sort()),
    ];
    salida.add(EscalonEnInforme(
      escalon,
      deEscalon.length,
      audios.length,
      [for (final h in orden) FilaDeHabilidad(h, conteo[h]!.$1.length, conteo[h]!.$2)],
    ));
  }
  return salida;
}

String _cuantas(int n, String uno, String varios) => '$n ${n == 1 ? uno : varios}';

/// Un número sin ceros inútiles: `394`, `7.5`.
String _numero(num n) => n == n.roundToDouble() ? '${n.round()}' : '$n';

/// Escribe una tabla con las columnas alineadas a la izquierda.
void _tabla(StringBuffer b, List<List<String>> filas, {String sangria = '  '}) {
  final ancho = [
    for (var i = 0; i < filas.first.length; i++)
      filas.map((f) => f[i].length).reduce((a, x) => a > x ? a : x),
  ];
  for (final f in filas) {
    final celdas = [
      for (var i = 0; i < f.length; i++) i == f.length - 1 ? f[i] : f[i].padRight(ancho[i]),
    ];
    b.writeln('$sangria${celdas.join('  ')}');
  }
}
