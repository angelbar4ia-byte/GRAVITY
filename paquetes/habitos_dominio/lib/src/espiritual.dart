import 'fecha.dart';

/// Libro del canon protestante (orden canónico 1 a 66).
class LibroBiblia {
  const LibroBiblia(this.numero, this.nombre, this.nombreEn, this.capitulos,
      this.alias);
  final int numero;
  final String nombre;
  final String nombreEn;
  final int capitulos;
  final List<String> alias; // ya normalizados (sin acentos ni mayúsculas)
}

const canon = <LibroBiblia>[
  LibroBiblia(1, 'Génesis', 'Genesis', 50, ['gn', 'gen']),
  LibroBiblia(2, 'Éxodo', 'Exodus', 40, ['ex', 'exo']),
  LibroBiblia(3, 'Levítico', 'Leviticus', 27, ['lv', 'lev']),
  LibroBiblia(4, 'Números', 'Numbers', 36, ['nm', 'num']),
  LibroBiblia(5, 'Deuteronomio', 'Deuteronomy', 34, ['dt', 'deu']),
  LibroBiblia(6, 'Josué', 'Joshua', 24, ['jos']),
  LibroBiblia(7, 'Jueces', 'Judges', 21, ['jue', 'jdg']),
  LibroBiblia(8, 'Rut', 'Ruth', 4, ['rt', 'rut']),
  LibroBiblia(9, '1 Samuel', '1 Samuel', 31, ['1 sam', '1 s', '1sa']),
  LibroBiblia(10, '2 Samuel', '2 Samuel', 24, ['2 sam', '2 s', '2sa']),
  LibroBiblia(11, '1 Reyes', '1 Kings', 22, ['1 re', '1 r', '1ki']),
  LibroBiblia(12, '2 Reyes', '2 Kings', 25, ['2 re', '2 r', '2ki']),
  LibroBiblia(13, '1 Crónicas', '1 Chronicles', 29, ['1 cr', '1ch']),
  LibroBiblia(14, '2 Crónicas', '2 Chronicles', 36, ['2 cr', '2ch']),
  LibroBiblia(15, 'Esdras', 'Ezra', 10, ['esd']),
  LibroBiblia(16, 'Nehemías', 'Nehemiah', 13, ['neh', 'ne']),
  LibroBiblia(17, 'Ester', 'Esther', 10, ['est']),
  LibroBiblia(18, 'Job', 'Job', 42, ['job']),
  LibroBiblia(19, 'Salmos', 'Psalms', 150, ['sal', 'salmo', 'ps', 'psalm']),
  LibroBiblia(20, 'Proverbios', 'Proverbs', 31, ['pr', 'pro', 'prov']),
  LibroBiblia(21, 'Eclesiastés', 'Ecclesiastes', 12, ['ec', 'ecl']),
  LibroBiblia(22, 'Cantares', 'Song of Solomon', 8, ['cnt', 'cant', 'song']),
  LibroBiblia(23, 'Isaías', 'Isaiah', 66, ['is', 'isa']),
  LibroBiblia(24, 'Jeremías', 'Jeremiah', 52, ['jer']),
  LibroBiblia(25, 'Lamentaciones', 'Lamentations', 5, ['lm', 'lam']),
  LibroBiblia(26, 'Ezequiel', 'Ezekiel', 48, ['ez', 'eze']),
  LibroBiblia(27, 'Daniel', 'Daniel', 12, ['dn', 'dan']),
  LibroBiblia(28, 'Oseas', 'Hosea', 14, ['os', 'ose']),
  LibroBiblia(29, 'Joel', 'Joel', 3, ['jl', 'joe']),
  LibroBiblia(30, 'Amós', 'Amos', 9, ['am', 'amo']),
  LibroBiblia(31, 'Abdías', 'Obadiah', 1, ['abd', 'oba']),
  LibroBiblia(32, 'Jonás', 'Jonah', 4, ['jon']),
  LibroBiblia(33, 'Miqueas', 'Micah', 7, ['miq', 'mic']),
  LibroBiblia(34, 'Nahúm', 'Nahum', 3, ['nah']),
  LibroBiblia(35, 'Habacuc', 'Habakkuk', 3, ['hab']),
  LibroBiblia(36, 'Sofonías', 'Zephaniah', 3, ['sof', 'zep']),
  LibroBiblia(37, 'Hageo', 'Haggai', 2, ['hag']),
  LibroBiblia(38, 'Zacarías', 'Zechariah', 14, ['zac', 'zec']),
  LibroBiblia(39, 'Malaquías', 'Malachi', 4, ['mal']),
  LibroBiblia(40, 'Mateo', 'Matthew', 28, ['mt', 'mat']),
  LibroBiblia(41, 'Marcos', 'Mark', 16, ['mr', 'mc', 'mar', 'mk']),
  LibroBiblia(42, 'Lucas', 'Luke', 24, ['lc', 'luc', 'lk']),
  LibroBiblia(43, 'Juan', 'John', 21, ['jn', 'jua']),
  LibroBiblia(44, 'Hechos', 'Acts', 28, ['hch', 'hec', 'act']),
  LibroBiblia(45, 'Romanos', 'Romans', 16, ['ro', 'rom']),
  LibroBiblia(46, '1 Corintios', '1 Corinthians', 16, ['1 co', '1 cor', '1c']),
  LibroBiblia(47, '2 Corintios', '2 Corinthians', 13, ['2 co', '2 cor', '2c']),
  LibroBiblia(48, 'Gálatas', 'Galatians', 6, ['ga', 'gal']),
  LibroBiblia(49, 'Efesios', 'Ephesians', 6, ['ef', 'efe', 'eph']),
  LibroBiblia(50, 'Filipenses', 'Philippians', 4, ['fil', 'flp', 'php']),
  LibroBiblia(51, 'Colosenses', 'Colossians', 4, ['col']),
  LibroBiblia(52, '1 Tesalonicenses', '1 Thessalonians', 5, ['1 ts', '1 tes']),
  LibroBiblia(53, '2 Tesalonicenses', '2 Thessalonians', 3, ['2 ts', '2 tes']),
  LibroBiblia(54, '1 Timoteo', '1 Timothy', 6, ['1 ti', '1 tim']),
  LibroBiblia(55, '2 Timoteo', '2 Timothy', 4, ['2 ti', '2 tim']),
  LibroBiblia(56, 'Tito', 'Titus', 3, ['tit']),
  LibroBiblia(57, 'Filemón', 'Philemon', 1, ['flm', 'filem', 'phm']),
  LibroBiblia(58, 'Hebreos', 'Hebrews', 13, ['he', 'heb']),
  LibroBiblia(59, 'Santiago', 'James', 5, ['stg', 'sant', 'jas']),
  LibroBiblia(60, '1 Pedro', '1 Peter', 5, ['1 p', '1 pe', '1 ped']),
  LibroBiblia(61, '2 Pedro', '2 Peter', 3, ['2 p', '2 pe', '2 ped']),
  LibroBiblia(62, '1 Juan', '1 John', 5, ['1 jn', '1 jua', '1j']),
  LibroBiblia(63, '2 Juan', '2 John', 1, ['2 jn', '2 jua', '2j']),
  LibroBiblia(64, '3 Juan', '3 John', 1, ['3 jn', '3 jua', '3j']),
  LibroBiblia(65, 'Judas', 'Jude', 1, ['jud']),
  LibroBiblia(66, 'Apocalipsis', 'Revelation', 22, ['ap', 'apoc', 'rev']),
];

String _norm(String s) {
  const de = 'áéíóúüñÁÉÍÓÚÜÑ';
  const a = 'aeiouunaeiouun';
  var r = s.toLowerCase();
  for (var i = 0; i < de.length; i++) {
    r = r.replaceAll(de[i], a[i]);
  }
  return r.replaceAll('.', '').replaceAll(RegExp(r'\s+'), ' ').trim();
}

LibroBiblia? buscarLibro(String texto) {
  final t = _norm(texto);
  for (final l in canon) {
    if (_norm(l.nombre) == t || _norm(l.nombreEn) == t || l.alias.contains(t)) {
      return l;
    }
  }
  return null;
}

class ReferenciaBiblica {
  const ReferenciaBiblica(this.libro, this.capIni,
      {this.verIni, int? capFin, this.verFin})
      : capFin = capFin ?? capIni;
  final int libro;
  final int capIni;
  final int? verIni;
  final int capFin;
  final int? verFin;

  /// Código `libro:cap:ver_ini-ver_fin` para `hab_marcas_biblia`.
  String get codigo => verIni == null
      ? '$libro:$capIni'
      : '$libro:$capIni:$verIni-${verFin ?? verIni}';

  @override
  String toString() => '$libro $capIni:$verIni-$capFin:$verFin';
}

final _patron =
    RegExp(r'^(.*?)\s+(\d+)(?::(\d+))?(?:-(\d+)(?::(\d+))?)?$');

/// Analiza `Juan 3:16`, `Jn 3:16-18`, `1 Co 13:4–7`, `Sal 23`,
/// `Génesis 1:1-2:3`. Nulo si no se entiende.
ReferenciaBiblica? analizarReferencia(String texto) {
  final t = texto.replaceAll(RegExp('[–—]'), '-').trim();
  final m = _patron.firstMatch(t);
  if (m == null) return null;
  final l = buscarLibro(m.group(1)!);
  if (l == null) return null;
  final c1 = int.parse(m.group(2)!);
  final v1 = m.group(3) == null ? null : int.parse(m.group(3)!);
  final a = m.group(4) == null ? null : int.parse(m.group(4)!);
  final b = m.group(5) == null ? null : int.parse(m.group(5)!);
  if (c1 < 1 || c1 > l.capitulos) return null;
  if (a == null) return ReferenciaBiblica(l.numero, c1, verIni: v1);
  if (v1 == null) return ReferenciaBiblica(l.numero, c1, capFin: a);
  if (b != null) {
    return ReferenciaBiblica(l.numero, c1, verIni: v1, capFin: a, verFin: b);
  }
  return ReferenciaBiblica(l.numero, c1, verIni: v1, verFin: a);
}

class Capitulo {
  const Capitulo(this.libro, this.cap);
  final int libro;
  final int cap;
  @override
  bool operator ==(Object other) =>
      other is Capitulo && other.libro == libro && other.cap == cap;
  @override
  int get hashCode => libro * 1000 + cap;
  @override
  String toString() => '$libro:$cap';
}

List<Capitulo> capitulosDe(int desdeLibro, int hastaLibro) => [
      for (final l in canon)
        if (l.numero >= desdeLibro && l.numero <= hastaLibro)
          for (var c = 1; c <= l.capitulos; c++) Capitulo(l.numero, c)
    ];

/// Reparte [n] capítulos en [dias]: `n div d` cada uno y uno más a los
/// primeros `n mod d` (regla 81).
List<int> repartirEnDias(int n, int dias) {
  final q = n ~/ dias, r = n % dias;
  return [for (var i = 0; i < dias; i++) i < r ? q + 1 : q];
}

enum TipoPlan { rutaInicio, nt90, salmosProverbios30, biblia1Ano, libro }

enum EstadoDiaPlan { pendiente, hecho, parcial, saltado, movido }

class DiaPlan {
  DiaPlan(this.dia, this.fecha, this.capitulos,
      [this.estado = EstadoDiaPlan.pendiente]);
  final int dia;
  final DateTime fecha;
  List<Capitulo> capitulos;
  EstadoDiaPlan estado;
}

/// Plan con sus días materializados.
class PlanLectura {
  PlanLectura(this.tipo, this.dias);
  final TipoPlan tipo;
  final List<DiaPlan> dias;

  int get totalCapitulos => dias.fold(0, (a, d) => a + d.capitulos.length);

  /// % entero hacia abajo sin contar saltados ni movidos (regla 83).
  int avancePct() {
    var tot = 0, leidos = 0;
    for (final d in dias) {
      if (d.estado == EstadoDiaPlan.saltado || d.estado == EstadoDiaPlan.movido) {
        continue;
      }
      tot += d.capitulos.length;
      if (d.estado == EstadoDiaPlan.hecho) leidos += d.capitulos.length;
    }
    return tot == 0 ? 0 : (leidos * 100) ~/ tot;
  }
}

/// Fechas de lectura desde [inicio], saltando los días fuera de [mascara].
List<DateTime> _fechas(DateTime inicio, int n, int mascara) {
  final r = <DateTime>[];
  var d = soloDia(inicio);
  while (r.length < n) {
    if (mascara & mascaraDia(d) != 0) r.add(d);
    d = sumarDias(d, 1);
  }
  return r;
}

PlanLectura _armar(TipoPlan t, List<List<Capitulo>> porDia, DateTime inicio,
    int mascara) {
  final f = _fechas(inicio, porDia.length, mascara);
  return PlanLectura(t, [
    for (var i = 0; i < porDia.length; i++) DiaPlan(i + 1, f[i], porDia[i])
  ]);
}

List<List<Capitulo>> _partir(List<Capitulo> seq, int dias) {
  final cuentas = repartirEnDias(seq.length, dias);
  var p = 0;
  return [
    for (final c in cuentas) seq.sublist(p, p += c),
  ];
}

PlanLectura generarPlan(TipoPlan tipo, DateTime inicio,
    {int mascaraDias = 127, int? libro, int capitulosPorDia = 1}) {
  if (mascaraDias & 127 == 0) {
    throw ArgumentError.value(mascaraDias, 'mascaraDias', 'Elige al menos un día de lectura.');
  }
  if (tipo == TipoPlan.libro && (libro == null || libro < 1 || libro > 66)) {
    throw ArgumentError.value(libro, 'libro', 'Elige un libro del 1 al 66.');
  }
  if (capitulosPorDia < 1) {
    throw ArgumentError.value(capitulosPorDia, 'capitulosPorDia', 'Mínimo 1.');
  }
  switch (tipo) {
    case TipoPlan.rutaInicio:
      return _armar(tipo, _partir(capitulosDe(43, 43), 21), inicio, mascaraDias);
    case TipoPlan.nt90:
      return _armar(tipo, _partir(capitulosDe(40, 66), 90), inicio, mascaraDias);
    case TipoPlan.biblia1Ano:
      return _armar(tipo, _partir(capitulosDe(1, 66), 365), inicio, mascaraDias);
    case TipoPlan.libro:
      final seq = capitulosDe(libro!, libro);
      final dias = (seq.length + capitulosPorDia - 1) ~/ capitulosPorDia;
      return _armar(tipo, _partir(seq, dias), inicio, mascaraDias);
    case TipoPlan.salmosProverbios30:
      final porDia = <List<Capitulo>>[];
      for (var d = 1; d <= 30; d++) {
        porDia.add([
          for (var s = 5 * (d - 1) + 1; s <= 5 * d; s++) Capitulo(19, s),
          Capitulo(20, d),
          if (d == 30) const Capitulo(20, 31),
        ]);
      }
      return _armar(tipo, porDia, inicio, mascaraDias);
  }
}

/// *Ponerme al día* (regla 82): los capítulos de días pasados pendientes se
/// reparten entre los próximos [k] días de lectura, sin mover la fecha final.
void ponerAlDia(PlanLectura p, DateTime hoy, int k) {
  final h = soloDia(hoy);
  final pasados = p.dias
      .where((d) => d.fecha.isBefore(h) && d.estado == EstadoDiaPlan.pendiente)
      .toList();
  final extra = [for (final d in pasados) ...d.capitulos];
  if (extra.isEmpty) return;
  final futuros = p.dias
      .where((d) => !d.fecha.isBefore(h) && d.estado == EstadoDiaPlan.pendiente)
      .take(k)
      .toList();
  if (futuros.isEmpty) return;
  for (final d in pasados) {
    d.estado = EstadoDiaPlan.movido;
  }
  final cuentas = repartirEnDias(extra.length, futuros.length);
  var i = 0;
  for (var j = 0; j < futuros.length; j++) {
    futuros[j].capitulos = [...futuros[j].capitulos, ...extra.sublist(i, i += cuentas[j])];
  }
}

/// *Saltar*: los días pasados pendientes quedan `saltado` (no cuentan).
void saltarAtrasados(PlanLectura p, DateTime hoy) {
  for (final d in p.dias) {
    if (d.fecha.isBefore(soloDia(hoy)) && d.estado == EstadoDiaPlan.pendiente) {
      d.estado = EstadoDiaPlan.saltado;
    }
  }
}

/// *Reiniciar el tramo*: los días pendientes se recorren a partir de hoy.
void reiniciarTramo(PlanLectura p, DateTime hoy, int mascara) {
  final pend = p.dias.where((d) => d.estado == EstadoDiaPlan.pendiente).toList();
  final f = _fechas(hoy, pend.length, mascara);
  final nuevos = [
    for (var i = 0; i < pend.length; i++)
      DiaPlan(pend[i].dia, f[i], pend[i].capitulos)
  ];
  for (var i = 0; i < pend.length; i++) {
    final idx = p.dias.indexOf(pend[i]);
    p.dias[idx] = nuevos[i];
  }
}
