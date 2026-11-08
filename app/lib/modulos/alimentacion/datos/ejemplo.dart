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
  ], pasos: [
    'Calienta la leche en una olla pequeña a fuego bajo.',
    'Agrega la avena y mueve hasta que espese.',
    'Sirve en un plato hondo y pon encima el plátano en rodajas.',
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
  Platillo(
    'p-pescado',
    'Pescado a la plancha con ensalada',
    [
      Ingrediente('Filete de pescado', 180, 'g', _cp),
      Ingrediente('Lechuga', 3, 'hoja', _fv),
      Ingrediente('Jitomate', 1, 'pza', _fv),
      Ingrediente('Limón', 2, 'pza', _fv),
    ],
    duros: ['verdura cruda'],
  ),
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
  Platillo(
    'p-yogurt',
    'Yogurt con granola',
    [
      Ingrediente('Yogurt natural', 1, 'vaso', _lh),
      Ingrediente('Granola', 40, 'g', _ab),
      Ingrediente('Plátano', 1, 'pza', _fv),
    ],
    duros: ['granola'],
  ),
  Platillo('p-pure', 'Puré de papa con pollo deshebrado', [
    Ingrediente('Papa', 1, 'pza', _fv),
    Ingrediente('Pechuga de pollo', 150, 'g', _cp),
    Ingrediente('Leche', 100, 'ml', _lh),
  ]),
  Platillo('p-licuado', 'Licuado de proteína con plátano', [
    Ingrediente('Leche', 250, 'ml', _lh),
    Ingrediente('Plátano', 1, 'pza', _fv),
    Ingrediente('Proteína en polvo', 1, 'cacito', _ab),
  ]),
  Platillo('p-flan', 'Flan de huevo', [
    Ingrediente('Huevo', 2, 'pza', _lh),
    Ingrediente('Leche', 200, 'ml', _lh),
  ]),
  Platillo('p-caldo', 'Caldo de pollo con verduras suaves', [
    Ingrediente('Pechuga de pollo', 150, 'g', _cp),
    Ingrediente('Zanahoria', 1, 'pza', _fv),
    Ingrediente('Calabacita', 1, 'pza', _fv),
  ]),
  Platillo(
    'p-fruta',
    'Fruta picada',
    [
      Ingrediente('Manzana', 1, 'pza', _fv),
      Ingrediente('Limón', 1, 'pza', _fv),
    ],
    duros: ['manzana cruda'],
  ),
];

/// Suplementos de ejemplo (inventados; no son indicación de nadie).
List<Suplemento> suplementosEjemplo(MenuId menu) => switch (menu) {
  MenuId.papa => const [
    Suplemento(
      id: 's1',
      nombre: 'Proteína en polvo',
      dosis: '1 cacito',
      horario: 'Colación',
    ),
    Suplemento(
      id: 's2',
      nombre: 'Multivitamínico',
      dosis: '1 tableta',
      horario: 'Desayuno',
    ),
  ],
  MenuId.pareja => const [
    Suplemento(
      id: 's3',
      nombre: 'Omega 3',
      dosis: '1 cápsula',
      horario: 'Comida',
    ),
  ],
};

/// Menú de ejemplo de una semana (desayuno, comida, cena de lunes a domingo).
List<EntradaMenu> menuEjemplo(MenuId menu) {
  // desayuno, comida, cena, colación
  const papa = [
    ['p-huevo', 'p-pure', 'p-caldo', 'p-licuado'],
    ['p-avena', 'p-lentejas', 'p-flan', 'p-yogurt'],
    ['p-huevo', 'p-pollo', 'p-caldo', 'p-licuado'],
    ['p-avena', 'p-pure', 'p-quesadillas', 'p-flan'],
    ['p-huevo', 'p-lentejas', 'p-caldo', 'p-licuado'],
    ['p-avena', 'p-pollo', 'p-flan', 'p-licuado'],
    ['p-huevo', 'p-pure', 'p-caldo', 'p-flan'],
  ];
  const pareja = [
    ['p-huevo', 'p-pollo', 'p-yogurt', 'p-fruta'],
    ['p-avena', 'p-lentejas', 'p-sandwich', 'p-fruta'],
    ['p-huevo', 'p-pasta', 'p-quesadillas', 'p-yogurt'],
    ['p-avena', 'p-pescado', 'p-yogurt', 'p-fruta'],
    ['p-huevo', 'p-pollo', 'p-sandwich', 'p-fruta'],
    ['p-yogurt', 'p-lentejas', 'p-quesadillas', 'p-fruta'],
    ['p-avena', 'p-pasta', 'p-yogurt', 'p-fruta'],
  ];
  final ids = menu == MenuId.papa ? papa : pareja;
  return [
    for (var d = 0; d < 7; d++)
      for (final t in TiempoComida.values)
        EntradaMenu(dia: d, tiempo: t, platilloId: ids[d][t.index]),
  ];
}

/// Precios base **supuestos** (inventados, sin relevancia): arrancan marcados
/// como base y se muestran "estimado". Algunos ingredientes quedan sin precio
/// a propósito: sin precio no se calcula costo.
List<PrecioIngrediente> preciosBaseEjemplo() {
  PrecioIngrediente b(String n, String u, int centavos, [double por = 1]) =>
      PrecioIngrediente(
        clave: claveCompra(n, u),
        centavos: centavos,
        porCantidad: por,
        esBase: true,
      );
  return [
    b('Huevo', 'pza', 300),
    b('Tortilla', 'pza', 100),
    b('Avena', 'g', 3000, 1000),
    b('Leche', 'ml', 2800, 1000),
    b('Plátano', 'pza', 300),
    b('Jitomate', 'pza', 400),
    b('Zanahoria', 'pza', 250),
    b('Calabacita', 'pza', 500),
    b('Arroz', 'g', 2800, 1000),
    b('Pechuga de pollo', 'g', 12000, 1000),
    b('Pasta', 'g', 2500, 1000),
  ];
}
