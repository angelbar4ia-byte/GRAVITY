/// Lectura de Alimentación para las bocinas (D6): solo lectura, texto corto y
/// sin cifras, precios ni datos clínicos.
///
/// Solo usa el **menú de la pareja y del dueño**: el de Papá lleva su perfil
/// clínico y nunca se dice en voz alta. No inventa nada: sin receta activa o
/// sin pasos escritos, dice que no hay receta.
library;

import '../datos/modelos.dart';
import '../datos/repositorio.dart';

/// Dónde va la persona en la receta que cocina. Es solo memoria de la sesión
/// (no es un dato de Alimentación): no se guarda ni se marca nada.
class CocinaPasoAPaso {
  String? platilloId;

  /// Paso actual (0 = primero). Solo vale si [iniciada].
  int indice = 0;
  bool iniciada = false;

  void reiniciar() {
    platilloId = null;
    indice = 0;
    iniciada = false;
  }
}

/// Orden en que se busca la receta de hoy cuando no hay una activa.
const _ordenReceta = [
  TiempoComida.comida,
  TiempoComida.cena,
  TiempoComida.desayuno,
  TiempoComida.colacion,
];

const sinRecetaVoz = 'No hay una receta para cocinar ahora.';
const _noEmpiezaVoz =
    'Todavía no empiezas la receta. Di siguiente paso para empezar.';

class LecturaVozAlimentacion {
  LecturaVozAlimentacion(this._repo, this._cocina, {required this.ahora});

  final RepositorioAlimentacion _repo;
  final CocinaPasoAPaso _cocina;
  final DateTime Function() ahora;

  static const nombres = {
    'alimentacion.receta_siguiente_paso',
    'alimentacion.receta_paso_anterior',
    'alimentacion.receta_repetir_paso',
    'alimentacion.que_cocino_hoy',
    'alimentacion.leer_lista_compras',
  };

  /// Texto para [herramienta], o `null` si no es una de las cinco.
  Future<String?> responder(String herramienta) async => switch (herramienta) {
    'alimentacion.receta_siguiente_paso' => _siguiente(),
    'alimentacion.receta_paso_anterior' => _anterior(),
    'alimentacion.receta_repetir_paso' => _repetir(),
    'alimentacion.que_cocino_hoy' => _queCocinoHoy(),
    'alimentacion.leer_lista_compras' => _listaCompras(),
    _ => null,
  };

  Future<List<EntradaMenu>> _menuDeHoy() async {
    final hoy = ahora();
    final dia = DateTime(hoy.year, hoy.month, hoy.day).weekday - 1;
    return [
      for (final e in await _repo.menu(MenuId.pareja, lunesDe(hoy)))
        if (e.dia == dia) e,
    ];
  }

  /// La receta activa; si no hay, la primera de hoy que tenga pasos escritos.
  Future<Platillo?> _receta() async {
    final platillos = {for (final p in await _repo.platillos()) p.id: p};
    final activa = platillos[_cocina.platilloId];
    if (activa != null && activa.pasos.isNotEmpty) return activa;
    _cocina.reiniciar();
    final hoy = await _menuDeHoy();
    for (final t in _ordenReceta) {
      for (final e in hoy.where((x) => x.tiempo == t)) {
        final p = platillos[e.platilloId];
        if (p != null && p.pasos.isNotEmpty) {
          _cocina.platilloId = p.id;
          return p;
        }
      }
    }
    return null;
  }

  Future<String> _siguiente() async {
    final p = await _receta();
    if (p == null) return sinRecetaVoz;
    if (!_cocina.iniciada) {
      _cocina
        ..iniciada = true
        ..indice = 0;
      return p.pasos.first;
    }
    if (_cocina.indice >= p.pasos.length - 1) {
      return 'Ese era el último paso. ${p.pasos.last}';
    }
    _cocina.indice++;
    return p.pasos[_cocina.indice];
  }

  Future<String> _anterior() async {
    final p = await _receta();
    if (p == null) return sinRecetaVoz;
    if (!_cocina.iniciada) return _noEmpiezaVoz;
    if (_cocina.indice == 0) return 'Estás en el primer paso. ${p.pasos.first}';
    _cocina.indice--;
    return p.pasos[_cocina.indice];
  }

  Future<String> _repetir() async {
    final p = await _receta();
    if (p == null) return sinRecetaVoz;
    if (!_cocina.iniciada) return _noEmpiezaVoz;
    return p.pasos[_cocina.indice];
  }

  Future<String> _queCocinoHoy() async {
    final platillos = {for (final p in await _repo.platillos()) p.id: p};
    final hoy = await _menuDeHoy();
    final partes = <String>[];
    for (final t in TiempoComida.values) {
      final nombres = [
        for (final e in hoy.where((x) => x.tiempo == t))
          if (platillos[e.platilloId] != null) platillos[e.platilloId]!.nombre,
      ];
      if (nombres.isNotEmpty) {
        partes.add('${t.etiqueta}, ${nombres.join(' y ')}');
      }
    }
    if (partes.isEmpty) return 'No hay menú para hoy.';
    return 'Hoy toca: ${partes.join('. ')}.';
  }

  /// Solo nombres de lo que falta por comprar: sin cantidades ni precios.
  Future<String> _listaCompras() async {
    final lunes = lunesDe(ahora());
    final menu = await _repo.menu(MenuId.pareja, lunes);
    final platillos = await _repo.platillos();
    final comprados = await _repo.comprados(MenuId.pareja, lunes);
    final falta = <String>[];
    final vistos = <String>{};
    final porId = {for (final p in platillos) p.id: p};
    final items = <Ingrediente>[];
    for (final e in menu) {
      items.addAll(porId[e.platilloId]?.ingredientes ?? const []);
    }
    items.sort((a, b) {
      final s = a.seccion.index.compareTo(b.seccion.index);
      return s != 0 ? s : a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
    });
    for (final i in items) {
      if (comprados.contains(claveCompra(i.nombre, i.unidad))) continue;
      if (vistos.add(i.nombre.trim().toLowerCase())) falta.add(i.nombre);
    }
    if (menu.isEmpty || items.isEmpty) return 'La lista de compras está vacía.';
    if (falta.isEmpty) return 'Ya compraste todo lo de la lista.';
    // El filtro de la bocina acepta hasta 280 caracteres: se corta antes.
    const prefijo = 'Falta comprar: ';
    const cola = ' y algunas cosas más.';
    var texto = prefijo;
    var cabenTodos = true;
    for (var k = 0; k < falta.length; k++) {
      final sep = k == 0 ? '' : ', ';
      if ('$texto$sep${falta[k]}$cola'.length > 270 && k < falta.length - 1) {
        cabenTodos = false;
        break;
      }
      texto = '$texto$sep${falta[k]}';
    }
    return cabenTodos ? '$texto.' : '$texto$cola';
  }
}
