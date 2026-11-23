/// Inventario de la persona y filtro de variantes (5.2, 3.1 y 3.2).
library;

import 'tipos.dart';

enum EstadoItem { disponible, noDisponible, futuro }

/// Una banda de la persona (4.2, `hab_ent_bandas`).
class BandaInventario {
  const BandaInventario({
    required this.id,
    required this.nombre,
    required this.orden,
    this.cantidad = 1,
    this.activa = true,
    this.resistenciaKgX10,
  });

  final String id;
  final String nombre;

  /// De la más ligera a la más fuerte; la ordena la persona.
  final int orden;
  final int cantidad;
  final bool activa;

  /// kg × 10 si la persona los leyó de la etiqueta [confirmar en la banda].
  final int? resistenciaKgX10;

  /// Una banda inactiva o con cantidad 0 no cuenta (CA-G-07).
  bool get cuenta => activa && cantidad > 0;
}

/// Campos que la persona confirma en el aparato (3.2). Mientras no estén
/// aquí, no entran a ningún cálculo (CA-G-04).
class CamposAparato {
  static const pasosMax = 'pasos_max';
  static const kgPorPasoX10 = 'kg_por_paso_x10';
  static const relacionPolea = 'relacion_polea';
  static const anclajeEstacion = 'anclaje_estacion';
  static const bancoPlano = 'banco_plano';
  static const capacidadBancoKg = 'capacidad_banco_kg';
}

class Inventario {
  const Inventario({
    this.items = const {},
    this.bandas = const [],
    this.confirmaciones = const {},
  });

  /// El inicial de la persona: el Marcy con sus cuatro puestos, el banco y la
  /// caminadora (F-E4). Sin bandas ni accesorios hasta que los agregue.
  factory Inventario.inicial() => const Inventario(
    items: {
      'marcy_mwm7119': EstadoItem.disponible,
      'marcy.press': EstadoItem.disponible,
      'marcy.polea_alta': EstadoItem.disponible,
      'marcy.polea_baja': EstadoItem.disponible,
      'marcy.cojin_curl': EstadoItem.disponible,
      'banco_inclinado': EstadoItem.disponible,
      'caminadora': EstadoItem.disponible,
    },
  );

  /// Id de catálogo (o `otro:<texto>`) → estado.
  final Map<String, EstadoItem> items;
  final List<BandaInventario> bandas;

  /// Campo (de [CamposAparato]) → valor confirmado en el aparato.
  final Map<String, int> confirmaciones;

  Inventario conItem(String id, EstadoItem estado) => Inventario(
    items: {...items, id: estado},
    bandas: bandas,
    confirmaciones: confirmaciones,
  );

  Inventario sinItem(String id) => Inventario(
    items: {...items}..remove(id),
    bandas: bandas,
    confirmaciones: confirmaciones,
  );

  Inventario conBandas(List<BandaInventario> b) =>
      Inventario(items: items, bandas: b, confirmaciones: confirmaciones);

  Inventario confirmando(String campo, int valor) => Inventario(
    items: items,
    bandas: bandas,
    confirmaciones: {...confirmaciones, campo: valor},
  );

  EstadoItem? estadoDe(String id) => items[id];

  /// Equipo `futuro` («cuando lo tengas»): se lista aparte y no genera nada.
  List<String> get equipoFuturo => [
    for (final e in items.entries)
      if (e.value == EstadoItem.futuro) e.key,
  ]..sort();

  /// ¿Hay al menos una banda activa con cantidad?
  bool get hayBandas => bandas.any((b) => b.cuenta);

  List<BandaInventario> get bandasActivas => [
    for (final b in bandas)
      if (b.cuenta) b,
  ]..sort((a, b) => a.orden.compareTo(b.orden));

  /// ¿Está disponible el id? Un puesto exige también su aparato; las bandas
  /// salen de la lista de bandas; lo `futuro` o `no_disponible` no cuenta.
  bool disponible(String id, Catalogo c) {
    if (id == 'bandas') return hayBandas;
    if (items[id] != EstadoItem.disponible) return false;
    final padre = c.item(id)?.padre;
    if (padre != null) return items[padre] == EstadoItem.disponible;
    return true;
  }

  bool anclaDisponible(Ancla a, Catalogo c) => switch (a) {
    Ancla.pisar => true,
    Ancla.puerta => disponible('ancla_puerta', c),
    Ancla.estacion =>
      disponible('marcy_mwm7119', c) &&
          confirmaciones[CamposAparato.anclajeEstacion] == 1,
  };

  /// 5.2: todos los `requiere` disponibles y, si es de banda, el ancla.
  bool varianteDisponible(Variante v, Catalogo c) {
    for (final r in v.requiere) {
      if (!disponible(r, c)) return false;
    }
    if (v.ancla != null && !anclaDisponible(v.ancla!, c)) return false;
    return true;
  }

  // ---- Confirmaciones del Marcy (CA-G-04) --------------------------------

  /// Número de pasos de la pila, solo si la persona lo confirmó.
  int? get pasosMax => confirmaciones[CamposAparato.pasosMax];

  /// kg × 10 por paso, solo si la persona lo confirmó.
  int? get kgPorPasoX10 => confirmaciones[CamposAparato.kgPorPasoX10];

  /// ¿Está esa carga (en pasos) en el último paso de la pila? Solo se detecta
  /// con `pasos_max` **confirmado**; la «pila de 68 kg» del diseño no cuenta.
  bool enTopeDePila(int pasos) => pasosMax != null && pasos >= pasosMax!;

  /// ¿Es válida esa carga? Nunca pasa de `pasos_max` si está confirmado.
  bool cargaValida(int pasos) =>
      pasos >= 0 && (pasosMax == null || pasos <= pasosMax!);
}

/// Cómo se muestra una carga de la pila (CA-G-04).
class CargaMostrada {
  const CargaMostrada(this.texto, {this.kgX10});
  final String texto;

  /// Solo con `kg_por_paso` confirmado.
  final int? kgX10;
}

/// «placa 5» y, solo si se confirmó cuánto vale un paso, «placa 5 · 12.5 kg».
CargaMostrada mostrarCargaPasos(int pasos, Inventario inv) {
  final kg = inv.kgPorPasoX10;
  if (kg == null) return CargaMostrada('placa $pasos');
  final x10 = pasos * kg;
  return CargaMostrada(
    'placa $pasos · ${x10 ~/ 10}.${x10 % 10} kg',
    kgX10: x10,
  );
}

/// Texto del dato del diseño: se muestra «aprox.» y no entra a cálculos.
String textoPilaAproximada(Catalogo c) {
  final d = c.datoAparato('pila_kg_aprox');
  return d?.valor == null ? '' : 'aprox. ${d!.valor} ${d.unidad ?? ''}'.trim();
}
