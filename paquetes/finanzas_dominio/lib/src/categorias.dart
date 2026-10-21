import 'libro.dart';
import 'presupuesto.dart';

/// Árbol de categorías de gasto de 3 niveles (5.2) e importador de la hoja
/// **Categorías** de `data/DATOS_SEMILLA_PRESUPUESTO.xlsx` o su CSV (10, MVP 1;
/// 6.11).
///
/// Las categorías y las cuentas de gasto son del **hogar** (regla 2 de 4.5):
/// cada categoría principal (nivel 1) tiene su cuenta de gasto; las
/// subcategorías (nivel 2) y los detalles (nivel 3) son su desglose.

/// Una categoría (`fin_categorias`).
class Categoria {
  final String id;
  final String? padreId;

  /// 1 = categoría, 2 = subcategoría, 3 = detalle.
  final int nivel;
  final String nombre;
  final String? icono;
  final String? color;

  /// Naturaleza típica de la plantilla: "Fija", "Variable", "Mixta"…
  final String naturaleza;
  final Prioridad prioridad;

  /// Renta, servicios y cuidados de largo plazo: no se recortan solos.
  final bool protegida;
  final bool esDelSistema;
  final bool oculta;
  final bool archivada;
  final bool posiblementeDeducible;

  /// Cuenta de gasto (solo en nivel 1).
  final String? cuentaGastoId;

  Categoria({
    required this.id,
    this.padreId,
    required this.nivel,
    required this.nombre,
    this.icono,
    this.color,
    this.naturaleza = '',
    this.prioridad = Prioridad.deseable,
    this.protegida = false,
    this.esDelSistema = false,
    this.oculta = false,
    this.archivada = false,
    this.posiblementeDeducible = false,
    this.cuentaGastoId,
  }) {
    if (nivel < 1 || nivel > 3) {
      throw ArgumentError.value(nivel, 'nivel', 'debe ser 1, 2 o 3');
    }
    if ((nivel == 1) != (padreId == null)) {
      throw ArgumentError('Solo las de nivel 1 van sin categoría padre');
    }
  }

  bool get visible => !oculta && !archivada;

  Categoria copiar({
    String? nombre,
    String? padreId,
    int? nivel,
    Prioridad? prioridad,
    bool? protegida,
    bool? oculta,
    bool? archivada,
    String? cuentaGastoId,
    String? naturaleza,
  }) => Categoria(
    id: id,
    padreId: padreId ?? this.padreId,
    nivel: nivel ?? this.nivel,
    nombre: nombre ?? this.nombre,
    icono: icono,
    color: color,
    naturaleza: naturaleza ?? this.naturaleza,
    prioridad: prioridad ?? this.prioridad,
    protegida: protegida ?? this.protegida,
    esDelSistema: esDelSistema,
    oculta: oculta ?? this.oculta,
    archivada: archivada ?? this.archivada,
    posiblementeDeducible: posiblementeDeducible,
    cuentaGastoId: cuentaGastoId ?? this.cuentaGastoId,
  );

  @override
  String toString() => 'Categoria($nombre, nivel $nivel)';
}

/// Consultas sobre el árbol de categorías.
class ArbolCategorias {
  final Map<String, Categoria> _porId;
  final Map<String?, List<Categoria>> _hijas = {};

  ArbolCategorias(Iterable<Categoria> categorias)
    : _porId = {for (final c in categorias) c.id: c} {
    for (final c in _porId.values) {
      _hijas.putIfAbsent(c.padreId, () => []).add(c);
    }
    for (final lista in _hijas.values) {
      lista.sort((a, b) => a.nombre.compareTo(b.nombre));
    }
  }

  List<Categoria> get todas => _porId.values.toList();

  Categoria? porId(String? id) => id == null ? null : _porId[id];

  /// Hijas directas de [padreId] (nulo = las de nivel 1), por nombre.
  List<Categoria> hijas(String? padreId) =>
      List.unmodifiable(_hijas[padreId] ?? const []);

  /// La categoría de nivel 1 de [id].
  Categoria? raiz(String id) {
    var c = _porId[id];
    while (c != null && c.padreId != null) {
      c = _porId[c.padreId];
    }
    return c;
  }

  /// [id] y todas sus descendientes.
  Set<String> conDescendientes(String id) {
    final resultado = <String>{id};
    final pendientes = [id];
    while (pendientes.isNotEmpty) {
      for (final h in _hijas[pendientes.removeLast()] ?? const <Categoria>[]) {
        if (resultado.add(h.id)) pendientes.add(h.id);
      }
    }
    return resultado;
  }

  /// "Salud › Medicinas".
  String ruta(String id) {
    final partes = <String>[];
    var c = _porId[id];
    while (c != null) {
      partes.insert(0, c.nombre);
      c = _porId[c.padreId];
    }
    return partes.join(' › ');
  }

  /// Cuenta de gasto de [categoriaId] (la de su categoría principal).
  String? cuentaGastoDe(String categoriaId) => raiz(categoriaId)?.cuentaGastoId;

  /// La categoría de nivel 1 que corresponde a una cuenta de gasto.
  Categoria? deCuentaGasto(String cuentaId) {
    for (final c in _hijas[null] ?? const <Categoria>[]) {
      if (c.cuentaGastoId == cuentaId) return c;
    }
    return null;
  }

  /// Busca por nombre (sin acentos ni mayúsculas) dentro de [padreId].
  Categoria? buscar(String nombre, {String? padreId}) {
    final clave = normalizarNombre(nombre);
    for (final c in _hijas[padreId] ?? const <Categoria>[]) {
      if (normalizarNombre(c.nombre) == clave) return c;
    }
    return null;
  }
}

/// Nombre normalizado para comparar: sin acentos, en minúsculas y con un solo
/// espacio entre palabras.
String normalizarNombre(String texto) {
  const con = 'áàäâéèëêíìïîóòöôúùüûñÁÀÄÂÉÈËÊÍÌÏÎÓÒÖÔÚÙÜÛÑ';
  const sin = 'aaaaeeeeiiiioooouuuunAAAAEEEEIIIIOOOOUUUUN';
  final buffer = StringBuffer();
  for (final r in texto.trim().runes) {
    final ch = String.fromCharCode(r);
    final i = con.indexOf(ch);
    buffer.write(i >= 0 ? sin[i] : ch);
  }
  return buffer.toString().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

/// Lee un CSV (RFC 4180): comillas dobles, comillas escapadas (`""`), saltos
/// de línea dentro de comillas y fin de línea `\n` o `\r\n`. Si la primera
/// línea tiene más `;` que `,`, usa `;` como separador (Excel en español).
/// Quita la marca BOM inicial.
List<List<String>> leerCsv(String texto) {
  var t = texto;
  if (t.startsWith('﻿')) t = t.substring(1);
  final primera = t.split('\n').first;
  final separador =
      ';'.allMatches(primera).length > ','.allMatches(primera).length
      ? ';'
      : ',';
  final filas = <List<String>>[];
  var fila = <String>[];
  final celda = StringBuffer();
  var enComillas = false;
  for (var i = 0; i < t.length; i++) {
    final c = t[i];
    if (enComillas) {
      if (c == '"') {
        if (i + 1 < t.length && t[i + 1] == '"') {
          celda.write('"');
          i++;
        } else {
          enComillas = false;
        }
      } else {
        celda.write(c);
      }
      continue;
    }
    if (c == '"') {
      enComillas = true;
    } else if (c == separador) {
      fila.add(celda.toString());
      celda.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < t.length && t[i + 1] == '\n') i++;
      fila.add(celda.toString());
      celda.clear();
      filas.add(fila);
      fila = <String>[];
    } else {
      celda.write(c);
    }
  }
  if (celda.isNotEmpty || fila.isNotEmpty) {
    fila.add(celda.toString());
    filas.add(fila);
  }
  return filas;
}

/// Una fila de la hoja Categorías.
class FilaPlantilla {
  /// Número de fila en el archivo (1 = encabezado).
  final int numero;
  final String nivel1;
  final String nivel2;
  final String nivel3;
  final String naturaleza;
  final String notas;
  final String cuentaGasto;

  const FilaPlantilla({
    required this.numero,
    required this.nivel1,
    this.nivel2 = '',
    this.nivel3 = '',
    this.naturaleza = '',
    this.notas = '',
    this.cuentaGasto = '',
  });

  int get nivel => nivel3.isNotEmpty ? 3 : (nivel2.isNotEmpty ? 2 : 1);

  /// Nombres de la ruta hasta esta fila.
  List<String> get ruta => [
    nivel1,
    if (nivel2.isNotEmpty) nivel2,
    if (nivel3.isNotEmpty) nivel3,
  ];

  String get nombre => ruta.last;
}

/// Una fila que no se importó y por qué.
class FilaOmitida {
  final int numero;
  final String texto;
  final String motivo;

  const FilaOmitida(this.numero, this.texto, this.motivo);

  @override
  String toString() => 'Fila $numero ($texto): $motivo';
}

/// Lo leído de la hoja, antes de compararlo con lo que ya existe.
class LecturaPlantilla {
  final List<FilaPlantilla> filas;
  final List<FilaOmitida> omitidas;

  const LecturaPlantilla(this.filas, this.omitidas);

  int get filasLeidas => filas.length + omitidas.length;
}

/// Error de formato de la hoja (falta una columna obligatoria).
class ErrorPlantilla implements Exception {
  final String mensaje;
  const ErrorPlantilla(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Largo máximo de un nombre de categoría.
const int largoMaximoNombreCategoria = 80;

/// Lee la tabla de la hoja Categorías (la primera fila no vacía es el
/// encabezado). Columnas, sin importar acentos ni mayúsculas:
/// "Categoría (nivel 1)", "Subcategoría (nivel 2)", "Detalle (nivel 3)",
/// "Naturaleza típica", "Notas o ejemplos" y "Cuenta de gasto". Solo la
/// primera es obligatoria. Las filas vacías se saltan sin contarlas.
LecturaPlantilla leerPlantillaCategorias(List<List<String>> tabla) {
  var inicio = 0;
  while (inicio < tabla.length &&
      tabla[inicio].every((c) => c.trim().isEmpty)) {
    inicio++;
  }
  if (inicio >= tabla.length) {
    throw const ErrorPlantilla('El archivo está vacío');
  }
  final encabezado = [for (final c in tabla[inicio]) normalizarNombre(c)];
  int columna(bool Function(String) coincide) =>
      encabezado.indexWhere(coincide);
  final c1 = columna((c) => c.startsWith('categoria') || c.contains('nivel 1'));
  if (c1 < 0) {
    throw const ErrorPlantilla(
      'No encontré la columna "Categoría (nivel 1)". ¿Es la hoja Categorías?',
    );
  }
  final c2 = columna(
    (c) => c.startsWith('subcategoria') || c.contains('nivel 2'),
  );
  final c3 = columna((c) => c.startsWith('detalle') || c.contains('nivel 3'));
  final cNat = columna((c) => c.startsWith('naturaleza'));
  final cNotas = columna((c) => c.startsWith('notas'));
  final cCuenta = columna((c) => c.startsWith('cuenta'));

  String celda(List<String> fila, int i) => i < 0 || i >= fila.length
      ? ''
      : fila[i].trim().replaceAll(RegExp(r'\s+'), ' ');

  final filas = <FilaPlantilla>[];
  final omitidas = <FilaOmitida>[];
  for (var i = inicio + 1; i < tabla.length; i++) {
    final crudo = tabla[i];
    if (crudo.every((c) => c.trim().isEmpty)) continue;
    final numero = i + 1;
    final f = FilaPlantilla(
      numero: numero,
      nivel1: celda(crudo, c1),
      nivel2: celda(crudo, c2),
      nivel3: celda(crudo, c3),
      naturaleza: celda(crudo, cNat),
      notas: celda(crudo, cNotas),
      cuentaGasto: celda(crudo, cCuenta),
    );
    final texto = [
      f.nivel1,
      f.nivel2,
      f.nivel3,
    ].where((t) => t.isNotEmpty).join(' › ');
    if (f.nivel1.isEmpty) {
      omitidas.add(FilaOmitida(numero, texto, 'Falta la categoría de nivel 1'));
    } else if (f.nivel3.isNotEmpty && f.nivel2.isEmpty) {
      omitidas.add(
        FilaOmitida(numero, texto, 'Un detalle necesita su subcategoría'),
      );
    } else if (f.ruta.any((n) => n.length > largoMaximoNombreCategoria)) {
      omitidas.add(
        FilaOmitida(
          numero,
          texto,
          'Nombre de más de $largoMaximoNombreCategoria caracteres',
        ),
      );
    } else {
      filas.add(f);
    }
  }
  return LecturaPlantilla(filas, omitidas);
}

/// Prioridad sugerida a partir de la naturaleza típica de la plantilla.
///
/// Interpretación (editable por categoría): "Discrecional" → discrecional;
/// "Fija", "Variable" y "Recurrente" → necesario; "Mixta" y "Eventual" →
/// deseable.
Prioridad prioridadSugerida(String naturaleza) {
  final n = normalizarNombre(naturaleza);
  if (n.contains('discrecional')) return Prioridad.discrecional;
  if (n.contains('fija') ||
      n.contains('variable') ||
      n.contains('recurrente')) {
    return Prioridad.necesario;
  }
  return Prioridad.deseable;
}

/// Protegida por defecto (5.6 bis, punto 6, regla 5; P12): renta y servicios
/// ("Vivienda y servicios") y los cuidados de largo plazo.
bool protegidaSugerida(List<String> ruta) {
  final normal = ruta.map(normalizarNombre).toList();
  return normal.first == 'vivienda y servicios' ||
      normal.any((n) => n.contains('cuidados de largo plazo'));
}

/// Lo que se va a crear al importar.
class PlanImportacion {
  final List<Categoria> nuevas;

  /// Una cuenta de gasto del hogar por cada categoría de nivel 1 nueva.
  final List<Cuenta> cuentasNuevas;
  final List<FilaOmitida> omitidas;
  final int filasLeidas;

  const PlanImportacion({
    required this.nuevas,
    required this.cuentasNuevas,
    required this.omitidas,
    required this.filasLeidas,
  });

  int get filasCreadas => filasLeidas - omitidas.length;
  bool get sinCambios => nuevas.isEmpty && cuentasNuevas.isEmpty;
}

/// Compara la [lectura] con las categorías y cuentas que ya existen y arma lo
/// que hay que crear. **Reimportar no duplica**: una ruta que ya existe (por
/// nombre, sin acentos ni mayúsculas, dentro de su padre) se omite con el
/// motivo "Ya existe"; una fila repetida en el archivo, con "Repetida en el
/// archivo".
///
/// Cada categoría nueva de nivel 1 recibe su **cuenta de gasto** del hogar
/// (`de_gasto`, sin libro), o se liga a una que ya tenga su nombre. Si a una
/// subcategoría le falta su categoría padre en el archivo, la crea.
PlanImportacion planearImportacionCategorias(
  LecturaPlantilla lectura, {
  Iterable<Categoria> existentes = const [],
  Iterable<Cuenta> cuentasExistentes = const [],
  required String Function() generarId,
  bool delSistema = true,
}) {
  final arbol = ArbolCategorias(existentes);
  final cuentasPorNombre = {
    for (final c in cuentasExistentes) normalizarNombre(c.nombre): c,
  };
  final nuevas = <Categoria>[];
  final cuentas = <Cuenta>[];
  final omitidas = [...lectura.omitidas];
  // Ruta normalizada → id (lo que existe y lo que se va creando).
  final porRuta = <String, String>{};
  for (final c in arbol.todas) {
    porRuta[[for (final p in arbol.ruta(c.id).split(' › ')) normalizarNombre(p)]
            .join('/')] =
        c.id;
  }
  final vistasEnArchivo = <String>{};

  String crear(List<String> ruta, FilaPlantilla fila) {
    final nivel = ruta.length;
    final claveRuta = [for (final p in ruta) normalizarNombre(p)].join('/');
    final padreId = nivel == 1
        ? null
        : porRuta[[
            for (final p in ruta.sublist(0, nivel - 1)) normalizarNombre(p),
          ].join('/')];
    String? cuentaId;
    if (nivel == 1) {
      final nombre = ruta.first;
      final existente = cuentasPorNombre[normalizarNombre(nombre)];
      if (existente != null && existente.tipo == TipoCuenta.deGasto) {
        cuentaId = existente.id;
      } else {
        final nombreCuenta = existente == null ? nombre : '$nombre (gasto)';
        final cuenta = Cuenta(
          id: generarId(),
          nombre: nombreCuenta,
          tipo: TipoCuenta.deGasto,
        );
        cuentas.add(cuenta);
        cuentasPorNombre[normalizarNombre(nombreCuenta)] = cuenta;
        cuentaId = cuenta.id;
      }
    }
    final id = generarId();
    final categoria = Categoria(
      id: id,
      padreId: padreId,
      nivel: nivel,
      nombre: ruta.last,
      naturaleza: fila.naturaleza,
      prioridad: prioridadSugerida(fila.naturaleza),
      protegida: protegidaSugerida(ruta),
      esDelSistema: delSistema,
      cuentaGastoId: cuentaId,
    );
    nuevas.add(categoria);
    porRuta[claveRuta] = id;
    return id;
  }

  for (final fila in lectura.filas) {
    final ruta = fila.ruta;
    final clave = [for (final p in ruta) normalizarNombre(p)].join('/');
    final texto = ruta.join(' › ');
    if (!vistasEnArchivo.add(clave)) {
      omitidas.add(FilaOmitida(fila.numero, texto, 'Repetida en el archivo'));
      continue;
    }
    if (porRuta.containsKey(clave)) {
      omitidas.add(FilaOmitida(fila.numero, texto, 'Ya existe'));
      continue;
    }
    // Crea los padres que falten (con la naturaleza de esta fila).
    for (var n = 1; n < ruta.length; n++) {
      final sub = ruta.sublist(0, n);
      final k = [for (final p in sub) normalizarNombre(p)].join('/');
      if (!porRuta.containsKey(k)) {
        vistasEnArchivo.add(k);
        crear(sub, fila);
      }
    }
    crear(ruta, fila);
  }
  omitidas.sort((a, b) => a.numero.compareTo(b.numero));
  return PlanImportacion(
    nuevas: List.unmodifiable(nuevas),
    cuentasNuevas: List.unmodifiable(cuentas),
    omitidas: List.unmodifiable(omitidas),
    filasLeidas: lectura.filasLeidas,
  );
}
