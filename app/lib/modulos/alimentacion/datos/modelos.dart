/// Modelos de Alimentación (versión mínima, Fase 4). Sin precios, sin datos
/// de salud: solo qué se come y qué hay que comprar.
library;

import 'precios.dart';
export 'precios.dart';
export 'historial_precios.dart';
export 'analisis_historial.dart';

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
  const Ingrediente(
    this.nombre,
    this.cantidad,
    this.unidad,
    this.seccion, {
    this.codigoBarras,
  });
  final String nombre;
  final double cantidad;
  final String unidad;
  final SeccionCompra seccion;

  /// Código de barras del producto, si se capturó (opcional).
  final String? codigoBarras;

  String get clave => claveCompra(nombre, unidad);
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
    this.pendienteAlbacea = false,
  });
  final String nombre;
  final double cantidad;
  final String unidad;
  final SeccionCompra seccion;
  final bool comprado;

  /// Compra de Papá con la solicitud de pago sin resolver (albacea).
  final bool pendienteAlbacea;

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


/// Una comida del día de Papá para la cuenta Casa (D28): solo el nombre del
/// platillo. Sin perfil clínico, sin suplementos, sin alimentos duros.
class ComidaDelDia {
  const ComidaDelDia(this.tiempo, this.platillo);
  final TiempoComida tiempo;
  final String platillo;
}

/// Cuenta de Alimentación a la que pertenece una compra (despensa y lista del
/// servidor). La elige quien compra; el valor por omisión sale de su rol.
enum CuentaCompra {
  papa('Papá'),
  dueno('Dueño'),
  pareja('Pareja'),
  casa('Casa');

  const CuentaCompra(this.etiqueta);
  final String etiqueta;
}

/// Cuenta de pago (de Finanzas) que se ofrece al comprar. Solo nombre: nunca
/// saldo. [porOmision]: la que se propone antes de elegir.
class CuentaPago {
  const CuentaPago({
    required this.id,
    required this.nombre,
    this.porOmision = false,
  });
  final String id;
  final String nombre;
  final bool porOmision;
}

/// Ingrediente del catálogo del hogar. La marca no es clave: lo identifica el
/// nombre; unidad y presentación se editan sobre el mismo.
class FichaIngrediente {
  const FichaIngrediente({
    required this.id,
    required this.nombre,
    required this.unidad,
    this.presentacion = '',
  });
  final String id;
  final String nombre;
  final String unidad;
  final String presentacion;
}

/// Compra de Papá pendiente de pago, que resuelve el albacea. Lleva lo
/// comprado y su monto, nunca saldos.
class SolicitudPago {
  const SolicitudPago({
    required this.id,
    required this.ingrediente,
    required this.cantidad,
    required this.unidad,
    required this.montoCentavos,
  });
  final String id;
  final String ingrediente;
  final double cantidad;
  final String unidad;
  final int montoCentavos;
}

/// Lo que dejó registrar una compra con precio real.
class ResultadoCompra {
  const ResultadoCompra({this.pendienteAlbacea = false});

  /// La compra es de Papá y no traía cuenta de pago: el servidor dejó la
  /// solicitud al albacea (no es un error).
  final bool pendienteAlbacea;
}

/// Un renglón de la lista de compras que viene de `ali_compras` (servidor).
class CompraLista {
  const CompraLista({
    required this.nombre,
    required this.unidad,
    required this.cantidad,
    required this.seccion,
    required this.comprada,
    this.pendienteAlbacea = false,
  });
  final String nombre;
  final String unidad;
  final double cantidad;
  final SeccionCompra seccion;
  final bool comprada;

  /// Compra de Papá con la solicitud de pago sin resolver.
  final bool pendienteAlbacea;

  String get clave => claveCompra(nombre, unidad);
}


/// Tienda de la lista del hogar (Fase 8). La compra real se captura con una.
class Tienda {
  const Tienda({required this.id, required this.nombre, this.activa = true});
  final String id;
  final String nombre;

  /// `false` = desactivada (tenía compras al borrarla): sigue en el historial
  /// pero ya no se ofrece para compras nuevas.
  final bool activa;
}

/// Lo que respondió el servidor al borrar una tienda (`ali_borrar_tienda`).
enum ResultadoBorradoTienda {
  borrada,

  /// La tienda tiene compras: no se borró, se desactivó.
  desactivada;

  String get mensaje => switch (this) {
    borrada => 'Tienda borrada.',
    desactivada => 'La tienda tiene compras: se desactivó.',
  };
}

/// Mínimo de caracteres del motivo al regresar una compra.
const minCaracteresMotivoRegreso = 3;

/// Porción recomendada de un platillo para una persona del menú compartido de
/// dueño y pareja (un solo platillo, una porción por persona). La calcula el
/// servidor; la app solo la muestra. Sin datos clínicos.
class PorcionPersona {
  const PorcionPersona({
    required this.platilloId,
    required this.cuenta,
    required this.porciones,
  });
  final String platilloId;

  /// `dueno` o `pareja`.
  final CuentaCompra cuenta;
  final double porciones;
}

/// Máximo de caracteres del nombre de una tienda (mínimo 1).
const maxCaracteresTienda = 60;

/// Un ingrediente de la despensa de una cuenta: solo nombre, unidad y cantidad.
class ItemDespensa {
  const ItemDespensa({
    required this.nombre,
    required this.unidad,
    required this.cantidad,
  });
  final String nombre;
  final String unidad;
  final double cantidad;
}

/// Qué toca hacer con una compra de Papá rechazada dos veces (Fase 8 v1.7).
enum AccionGasto { reembolsar, registrar, anular }

/// Compra de Papá rechazada dos veces con su acción pendiente.
class GastoRechazado {
  const GastoRechazado({
    required this.compraId,
    required this.accion,
    required this.ingrediente,
    required this.montoCentavos,
  });
  final String compraId;
  final AccionGasto accion;
  final String ingrediente;
  final int montoCentavos;
}
