/// Datos de ejemplo **inventados** (ninguna persona ni comercio real).
library;

import 'modelos.dart';

const _fv = SeccionCompra.frutasVerduras;
const _cp = SeccionCompra.carnesPescados;
const _lh = SeccionCompra.lacteosHuevo;
const _ab = SeccionCompra.abarrotes;
const _pt = SeccionCompra.panaderia;

const platillosEjemplo = <Platillo>[
  Platillo('p-huevo', 'Huevos revueltos con frijoles', [
    Ingrediente('Huevo', 3, 'pza', _lh),
    Ingrediente('Frijoles de la olla', 1, 'taza', _ab),
    Ingrediente('Tortilla', 4, 'pza', _pt),
  ]),
  Platillo('p-avena', 'Avena con fruta', [
    Ingrediente('Avena', 50, 'g', _ab),
    Ingrediente('Leche', 250, 'ml', _lh),
    Ingrediente('Plátano', 1, 'pza', _fv),
  ]),
  Platillo('p-sandwich', 'Sándwich de jamón', [
    Ingrediente('Pan de caja', 2, 'reb', _pt),
    Ingrediente('Jamón de pavo', 2, 'reb', _cp),
    Ingrediente('Jitomate', 1, 'pza', _fv),
    Ingrediente('Lechuga', 2, 'hoja', _fv),
  ]),
  Platillo('p-pollo', 'Pollo con arroz y verduras', [
    Ingrediente('Pechuga de pollo', 200, 'g', _cp),
    Ingrediente('Arroz', 80, 'g', _ab),
    Ingrediente('Zanahoria', 1, 'pza', _fv),
    Ingrediente('Calabacita', 1, 'pza', _fv),
  ]),
  Platillo('p-lentejas', 'Sopa de lentejas', [
    Ingrediente('Lentejas', 80, 'g', _ab),
    Ingrediente('Zanahoria', 1, 'pza', _fv),
    Ingrediente('Jitomate', 1, 'pza', _fv),
    Ingrediente('Tortilla', 3, 'pza', _pt),
  ]),
  Platillo('p-pescado', 'Pescado a la plancha con ensalada', [
    Ingrediente('Filete de pescado', 180, 'g', _cp),
    Ingrediente('Lechuga', 3, 'hoja', _fv),
    Ingrediente('Jitomate', 1, 'pza', _fv),
    Ingrediente('Limón', 2, 'pza', _fv),
  ]),
  Platillo('p-quesadillas', 'Quesadillas con frijoles', [
    Ingrediente('Tortilla', 6, 'pza', _pt),
    Ingrediente('Queso Oaxaca', 120, 'g', _lh),
    Ingrediente('Frijoles de la olla', 1, 'taza', _ab),
  ]),
  Platillo('p-pasta', 'Pasta con verduras', [
    Ingrediente('Pasta', 100, 'g', _ab),
    Ingrediente('Calabacita', 1, 'pza', _fv),
    Ingrediente('Jitomate', 2, 'pza', _fv),
  ]),
  Platillo('p-yogurt', 'Yogurt con granola', [
    Ingrediente('Yogurt natural', 1, 'vaso', _lh),
    Ingrediente('Granola', 40, 'g', _ab),
    Ingrediente('Plátano', 1, 'pza', _fv),
  ]),
];

/// Menú de ejemplo de una semana (desayuno, comida, cena de lunes a domingo).
List<EntradaMenu> menuEjemplo() {
  const ids = [
    // desayuno, comida, cena
    ['p-huevo', 'p-pollo', 'p-yogurt'],
    ['p-avena', 'p-lentejas', 'p-sandwich'],
    ['p-huevo', 'p-pasta', 'p-quesadillas'],
    ['p-avena', 'p-pescado', 'p-yogurt'],
    ['p-huevo', 'p-pollo', 'p-sandwich'],
    ['p-yogurt', 'p-lentejas', 'p-quesadillas'],
    ['p-avena', 'p-pasta', 'p-yogurt'],
  ];
  return [
    for (var d = 0; d < 7; d++)
      for (final t in TiempoComida.values)
        EntradaMenu(dia: d, tiempo: t, platilloId: ids[d][t.index]),
  ];
}
