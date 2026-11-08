/// Modelos de Alimentación (versión mínima, Fase 4). Sin precios, sin datos
/// de salud: solo qué se come y qué hay que comprar.
library;

import 'precios.dart';
export 'precios.dart';

enum TiempoComida {
  desayuno('Desayuno'),
  comida('Comida'),
  cena('Cena'),
  colacion('Colación');

  const TiempoComida(this.etiqueta);
  final String etiqueta;
}

/// Los dos menús del hogar (D23).
enum MenuId {
  papa('Menú de Papá'),
  pareja('Menú de la pareja y del dueño');

  const MenuId(this.etiqueta);
  final String etiqueta;
}

enum SeccionCompra {
  frutasVerduras('Frutas y verduras'),
  carnesPescados('Carnes y pescados'),
  lacteosHuevo('Lácteos y huevo'),
  abarrotes('Abarrotes'),
  panaderia('Panadería y tortillería'),
  otros('Otros');

  const SeccionCompra(this.etiqueta);
  final String etiqueta;
}

const diasSemana = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

/// Lunes (00:00, sin hora) de la semana de [fecha].
DateTime lunesDe(DateTime fecha) {
  final d = DateTime(fecha.year, fecha.month, fecha.day);
  return d.subtract(Duration(days: d.weekday - DateTime.monday));
}

class Ingrediente {
  const Ingrediente(this.nombre, this.cantidad, this.unidad, this.seccion);
  final String nombre;
  final double cantidad;
  final String unidad;
  final SeccionCompra seccion;
}

class Platillo {
  const Platillo(
    this.id,
    this.nombre,
    this.ingredientes, {
    this.duros = const [],
    this.pasos = const [],
    this.porciones = 1,
  });
  final String id;
  final String nombre;
  final List<Ingrediente> ingredientes;

  /// Alimentos duros o crudos del platillo (para advertir en el menú de Papá).
  final List<String> duros;

  /// Pasos de la receta, en orden. Vacío: el platillo no tiene receta escrita.
  /// Para la bocina conviene redactarlos sin cifras (el filtro las rechaza).
  final List<String> pasos;

  /// Para cuántas porciones rinden los ingredientes.
  final int porciones;
}

/// Suplemento de un menú: nombre, dosis y horario (texto libre de ejemplo).
class Suplemento {
  const Suplemento({
    required this.id,
    required this.nombre,
    required this.dosis,
    required this.horario,
  });
  final String id;
  final String nombre;
  final String dosis;
  final String horario;
}

/// Una celda del menú: día 0 = lunes ... 6 = domingo.
class EntradaMenu {
  const EntradaMenu({
    required this.dia,
    required this.tiempo,
    required this.platilloId,
  });
  final int dia;
  final TiempoComida tiempo;
  final String platilloId;
}

/// Renglón de la lista de compras (derivado del menú).
class ItemCompra {
  const ItemCompra({
    required this.nombre,
    required this.cantidad,
    required this.unidad,
    required this.seccion,
    required this.comprado,
    this.precio,
  });
  final String nombre;
  final double cantidad;
  final String unidad;
  final SeccionCompra seccion;
  final bool comprado;

  /// Precio del ingrediente (base o real) si se conoce; sin él no hay costo.
  final PrecioIngrediente? precio;

  /// Costo en centavos de esta cantidad, o `null` si no hay precio.
  int? get costoCentavos => precio?.costoDe(cantidad);

  /// `true` si el costo sale de un precio base supuesto (se muestra "estimado").
  bool get costoEstimado => precio?.esBase ?? false;

  /// Clave estable para guardar la marca de comprado.
  String get clave => claveCompra(nombre, unidad);
}

String claveCompra(String nombre, String unidad) =>
    '${nombre.trim().toLowerCase()}|${unidad.trim().toLowerCase()}';

/// 2.0 -> "2"; 1.5 -> "1.5".
String cantidadTexto(double c) =>
    c == c.roundToDouble() ? c.round().toString() : c.toStringAsFixed(1);
