/// Pantallas donde el usuario actualiza inventario (BQ2).
const kInventoryUpdateScreens = <String>{
  'products',
  'productDetail',
  'scan',
  'stock_count',
  'location_walk',
  'restock',
  'add_product',
};

const kInventoryScreenLabels = <String, String>{
  'products': 'Inventario',
  'productDetail': 'Detalle producto',
  'scan': 'Escanear',
  'stock_count': 'Conteo en góndola',
  'location_walk': 'Recorrido ubicación',
  'restock': 'Reabastecer',
  'add_product': 'Agregar producto',
};

bool isInventoryUpdateScreen(String? screen) =>
    screen != null && kInventoryUpdateScreens.contains(screen);
