// lib/services/local_database_service.dart
//
// ══════════════════════════════════════════════════════════════════════════════
// BD LOCAL RELACIONAL — SQLite via sqflite
// ══════════════════════════════════════════════════════════════════════════════
//
// DEPENDENCIA (agregar en pubspec.yaml):
//   dependencies:
//     sqflite: ^2.3.3
//     path: ^1.9.0
//
// ESQUEMA RELACIONAL (3 tablas con FK):
//
//   ┌──────────┐  1    N  ┌──────────────────────┐  1    N  ┌──────────────────────┐
//   │  stores  │──────────│      products        │──────────│ inventory_movements  │
//   │  ──────  │          │  ──────────────────  │          │  ──────────────────  │
//   │  id (PK) │          │  id (PK)             │          │  id (PK)             │
//   │  name    │          │  store_id (FK)  ──┐  │          │  product_id (FK) ──┐ │
//   │  address │          │  name            │  │          │  type               │ │
//   │  phone   │          │  sku             │  │          │  quantity           │ │
//   │  email   │          │  barcode         └──►stores    │  created_at         │ │
//   │  manager │          │  category           │          └──────────►products  │ │
//   │  ...     │◄─────────│  cost_price         │                                 │
//   └──────────┘          │  sale_price         │                                 │
//                         │  quantity           │                                 │
//                         │  min_stock          │                                 │
//                         │  ...                │                                 │
//                         └─────────────────────┘                                 │
//
// OPERACIONES CRUD completas para cada tabla.
// CONSULTAS RELACIONALES: productos con datos de tienda, movimientos con
// datos de producto, resumen de stock por tienda.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/product.dart';
import '../models/inventory_movement.dart';
import '../models/store.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constantes de esquema
// ─────────────────────────────────────────────────────────────────────────────

const _kDbName    = 'inventaria_local.db';
const _kDbVersion = 1; // Incrementar al hacer migraciones.

const _tStores    = 'stores';
const _tProducts  = 'products';
const _tMovements = 'inventory_movements';

// ─────────────────────────────────────────────────────────────────────────────
// LocalDatabaseService  (singleton)
// ─────────────────────────────────────────────────────────────────────────────

/// Capa de persistencia **relacional local** usando SQLite (sqflite).
///
/// Responsabilidades:
///  - Abrir/crear/migrar la base de datos al arrancar la app.
///  - Exponer operaciones CRUD tipadas para [Store], [Product] e
///    [InventoryMovement].
///  - Exponer consultas JOIN que cruzan tablas (stock por tienda, últimos
///    movimientos de un producto, etc.).
///
/// Uso básico:
/// ```dart
/// await LocalDatabaseService.shared.init();
/// await LocalDatabaseService.shared.upsertProduct(myProduct);
/// final List<Product> lowStock = await LocalDatabaseService.shared.getLowStockProducts();
/// ```
class LocalDatabaseService {
  LocalDatabaseService._();
  static final LocalDatabaseService shared = LocalDatabaseService._();

  Database? _db;

  // ── Inicialización ────────────────────────────────────────────────────────

  /// Abre (o crea) la base de datos SQLite.
  /// Llama a este método una sola vez en [main] o en el primer provider que
  /// necesite persistencia local.
  Future<void> init() async {
    if (_db != null) return;

    final dbPath = p.join(await getDatabasesPath(), _kDbName);

    _db = await openDatabase(
      dbPath,
      version: _kDbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      // Activar claves foráneas (SQLite las ignora por defecto).
      onOpen: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
    );

    debugPrint('[LocalDB] Base de datos abierta: $dbPath  (v$_kDbVersion)');
  }

  Database get _requireDb {
    if (_db == null) {
      throw StateError(
        '[LocalDB] La base de datos no está inicializada. '
        'Llama a LocalDatabaseService.shared.init() primero.',
      );
    }
    return _db!;
  }

  // ── DDL: creación de tablas ───────────────────────────────────────────────

  Future<void> _onCreate(Database db, int version) async {
    // ── Tabla 1: stores ────────────────────────────────────────────────────
    // PK: id (TEXT) — mismo UUID que usa Firestore para facilitar la sincronización.
    await db.execute('''
      CREATE TABLE $_tStores (
        id             TEXT    PRIMARY KEY NOT NULL,
        name           TEXT    NOT NULL,
        address        TEXT    NOT NULL DEFAULT '',
        phone          TEXT    NOT NULL DEFAULT '',
        email          TEXT    NOT NULL DEFAULT '',
        manager        TEXT    NOT NULL DEFAULT '',
        employee_count INTEGER NOT NULL DEFAULT 0,
        product_count  INTEGER NOT NULL DEFAULT 0,
        monthly_sales  REAL    NOT NULL DEFAULT 0.0,
        is_active      INTEGER NOT NULL DEFAULT 1,  -- 0=false, 1=true
        created_at     TEXT    NOT NULL             -- ISO-8601
      )
    ''');

    // ── Tabla 2: products ──────────────────────────────────────────────────
    // FK: store_id → stores(id)  (ON DELETE SET NULL)
    await db.execute('''
      CREATE TABLE $_tProducts (
        id              TEXT    PRIMARY KEY NOT NULL,
        name            TEXT    NOT NULL,
        sku             TEXT    NOT NULL DEFAULT '',
        barcode         TEXT    NOT NULL DEFAULT '',
        category        TEXT    NOT NULL DEFAULT 'other',
        supplier        TEXT    NOT NULL DEFAULT '',
        cost_price      REAL    NOT NULL DEFAULT 0.0,
        sale_price      REAL    NOT NULL DEFAULT 0.0,
        quantity        INTEGER NOT NULL DEFAULT 0,
        min_stock       INTEGER NOT NULL DEFAULT 0,
        location        TEXT    NOT NULL DEFAULT '',
        expiration_date TEXT,                        -- ISO-8601 o NULL
        image_url       TEXT,
        description     TEXT    NOT NULL DEFAULT '',
        last_updated    TEXT    NOT NULL,            -- ISO-8601
        is_active       INTEGER NOT NULL DEFAULT 1,
        store_id        TEXT    REFERENCES $_tStores(id) ON DELETE SET NULL,
        category_id     TEXT,
        supplier_id     TEXT
      )
    ''');

    // Índice para búsquedas frecuentes por tienda y por estado de stock.
    await db.execute(
      'CREATE INDEX idx_products_store_id ON $_tProducts(store_id)',
    );
    await db.execute(
      'CREATE INDEX idx_products_quantity ON $_tProducts(quantity)',
    );

    // ── Tabla 3: inventory_movements ───────────────────────────────────────
    // FK: product_id → products(id)  (ON DELETE CASCADE)
    // Si se borra un producto se borran automáticamente todos sus movimientos.
    await db.execute('''
      CREATE TABLE $_tMovements (
        id          TEXT    PRIMARY KEY NOT NULL,
        product_id  TEXT    NOT NULL REFERENCES $_tProducts(id) ON DELETE CASCADE,
        type        TEXT    NOT NULL,   -- 'sale' | 'restock' | 'adjust' | 'unknown'
        quantity    INTEGER NOT NULL DEFAULT 0,
        created_at  TEXT    NOT NULL   -- ISO-8601
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_movements_product_id ON $_tMovements(product_id)',
    );
    await db.execute(
      'CREATE INDEX idx_movements_created_at ON $_tMovements(created_at)',
    );

    debugPrint('[LocalDB] Tablas creadas: $_tStores, $_tProducts, $_tMovements');
  }

  // ── DDL: migraciones ──────────────────────────────────────────────────────
  // Al incrementar _kDbVersion, agrega un bloque para cada salto de versión.

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('[LocalDB] Migrando de v$oldVersion → v$newVersion');
    // Ejemplo futuro:
    // if (oldVersion < 2) {
    //   await db.execute('ALTER TABLE $_tProducts ADD COLUMN tags TEXT');
    // }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CRUD — STORES
  // ══════════════════════════════════════════════════════════════════════════

  /// Inserta o reemplaza una tienda.
  Future<void> upsertStore(Store store) async {
    await _requireDb.insert(
      _tStores,
      _storeToRow(store),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Inserta o reemplaza varias tiendas en una sola transacción.
  Future<void> upsertStores(List<Store> stores) async {
    final db = _requireDb;
    await db.transaction((txn) async {
      for (final s in stores) {
        await txn.insert(
          _tStores,
          _storeToRow(s),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Retorna todas las tiendas activas.
  Future<List<Store>> getStores({bool onlyActive = true}) async {
    final rows = await _requireDb.query(
      _tStores,
      where: onlyActive ? 'is_active = 1' : null,
      orderBy: 'name ASC',
    );
    return rows.map(_rowToStore).toList();
  }

  /// Retorna una tienda por ID, o null si no existe.
  Future<Store?> getStore(String id) async {
    final rows = await _requireDb.query(
      _tStores,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _rowToStore(rows.first);
  }

  /// Elimina una tienda. Los productos con esa store_id quedan con store_id=NULL.
  Future<void> deleteStore(String id) async {
    await _requireDb.delete(_tStores, where: 'id = ?', whereArgs: [id]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CRUD — PRODUCTS
  // ══════════════════════════════════════════════════════════════════════════

  /// Inserta o reemplaza un producto.
  Future<void> upsertProduct(Product product) async {
    await _requireDb.insert(
      _tProducts,
      _productToRow(product),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Inserta o reemplaza varios productos en una sola transacción.
  Future<void> upsertProducts(List<Product> products) async {
    final db = _requireDb;
    await db.transaction((txn) async {
      for (final prod in products) {
        await txn.insert(
          _tProducts,
          _productToRow(prod),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Retorna todos los productos (opcionalmente filtrados por tienda).
  Future<List<Product>> getProducts({String? storeId, bool onlyActive = true}) async {
    String? where;
    List<Object?>? args;

    if (storeId != null && onlyActive) {
      where = 'store_id = ? AND is_active = 1';
      args  = [storeId];
    } else if (storeId != null) {
      where = 'store_id = ?';
      args  = [storeId];
    } else if (onlyActive) {
      where = 'is_active = 1';
    }

    final rows = await _requireDb.query(
      _tProducts,
      where: where,
      whereArgs: args,
      orderBy: 'name ASC',
    );
    return rows.map(_rowToProduct).toList();
  }

  /// Retorna un producto por ID, o null si no existe.
  Future<Product?> getProduct(String id) async {
    final rows = await _requireDb.query(
      _tProducts,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _rowToProduct(rows.first);
  }

  /// Retorna productos con stock ≤ min_stock (críticos para reposición).
  Future<List<Product>> getLowStockProducts({String? storeId}) async {
    final whereExtra = storeId != null ? ' AND store_id = ?' : '';
    final args = <Object?>[if (storeId != null) storeId];

    final rows = await _requireDb.rawQuery(
      '''
      SELECT * FROM $_tProducts
      WHERE is_active = 1
        AND quantity <= min_stock$whereExtra
      ORDER BY quantity ASC
      ''',
      args,
    );
    return rows.map(_rowToProduct).toList();
  }

  /// Búsqueda por nombre o SKU (LIKE, case-insensitive).
  Future<List<Product>> searchProducts(String query) async {
    final q = '%$query%';
    final rows = await _requireDb.rawQuery(
      '''
      SELECT * FROM $_tProducts
      WHERE is_active = 1
        AND (name LIKE ? OR sku LIKE ? OR barcode LIKE ?)
      ORDER BY name ASC
      LIMIT 50
      ''',
      [q, q, q],
    );
    return rows.map(_rowToProduct).toList();
  }

  /// Actualiza solo el campo `quantity` (ajuste de stock rápido).
  Future<void> updateProductQuantity(String productId, int newQuantity) async {
    await _requireDb.update(
      _tProducts,
      {
        'quantity':     newQuantity,
        'last_updated': DateTime.now().toIso8601String(),
      },
      where:     'id = ?',
      whereArgs: [productId],
    );
  }

  /// Marca un producto como inactivo (soft-delete).
  Future<void> deactivateProduct(String productId) async {
    await _requireDb.update(
      _tProducts,
      {'is_active': 0, 'last_updated': DateTime.now().toIso8601String()},
      where:     'id = ?',
      whereArgs: [productId],
    );
  }

  /// Elimina un producto (hard-delete) y en cascada sus movimientos.
  Future<void> deleteProduct(String productId) async {
    await _requireDb.delete(_tProducts, where: 'id = ?', whereArgs: [productId]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CRUD — INVENTORY MOVEMENTS
  // ══════════════════════════════════════════════════════════════════════════

  /// Inserta un movimiento de inventario.
  Future<void> insertMovement(InventoryMovement movement) async {
    await _requireDb.insert(
      _tMovements,
      _movementToRow(movement),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Inserta varios movimientos en una sola transacción.
  Future<void> insertMovements(List<InventoryMovement> movements) async {
    final db = _requireDb;
    await db.transaction((txn) async {
      for (final m in movements) {
        await txn.insert(
          _tMovements,
          _movementToRow(m),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Retorna los últimos N movimientos de un producto.
  Future<List<InventoryMovement>> getMovementsForProduct(
    String productId, {
    int limit = 50,
  }) async {
    final rows = await _requireDb.query(
      _tMovements,
      where:     'product_id = ?',
      whereArgs: [productId],
      orderBy:   'created_at DESC',
      limit:     limit,
    );
    return rows.map(_rowToMovement).toList();
  }

  /// Retorna todos los movimientos en un rango de fechas.
  Future<List<InventoryMovement>> getMovementsByDateRange(
    DateTime from,
    DateTime to, {
    String? productId,
  }) async {
    final whereExtra = productId != null ? ' AND product_id = ?' : '';
    final args = <Object?>[
      from.toIso8601String(),
      to.toIso8601String(),
      if (productId != null) productId,
    ];

    final rows = await _requireDb.rawQuery(
      '''
      SELECT * FROM $_tMovements
      WHERE created_at >= ? AND created_at <= ?$whereExtra
      ORDER BY created_at DESC
      ''',
      args,
    );
    return rows.map(_rowToMovement).toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CONSULTAS RELACIONALES (JOIN)
  // ══════════════════════════════════════════════════════════════════════════

  /// Retorna un resumen de stock agrupado por tienda.
  /// Resultado: [{ store_id, store_name, total_products, low_stock_count,
  ///               total_quantity, total_value }]
  Future<List<Map<String, dynamic>>> getStockSummaryByStore() async {
    return _requireDb.rawQuery('''
      SELECT
        s.id            AS store_id,
        s.name          AS store_name,
        COUNT(p.id)     AS total_products,
        SUM(CASE WHEN p.quantity <= p.min_stock THEN 1 ELSE 0 END)
                        AS low_stock_count,
        SUM(p.quantity) AS total_quantity,
        SUM(p.quantity * p.sale_price)
                        AS total_value
      FROM $_tStores s
      LEFT JOIN $_tProducts p
             ON p.store_id = s.id AND p.is_active = 1
      WHERE s.is_active = 1
      GROUP BY s.id, s.name
      ORDER BY s.name ASC
    ''');
  }

  /// Retorna los últimos movimientos con nombre de producto incluido.
  /// Útil para el feed de actividad reciente.
  Future<List<Map<String, dynamic>>> getRecentMovementsWithProductName({
    int limit = 30,
  }) async {
    return _requireDb.rawQuery(
      '''
      SELECT
        m.id          AS movement_id,
        m.type,
        m.quantity,
        m.created_at,
        p.id          AS product_id,
        p.name        AS product_name,
        p.sku,
        p.store_id
      FROM $_tMovements m
      INNER JOIN $_tProducts p ON p.id = m.product_id
      ORDER BY m.created_at DESC
      LIMIT ?
      ''',
      [limit],
    );
  }

  /// Cuenta ventas y reposiciones de un producto en los últimos N días.
  Future<Map<String, int>> getMovementCountsByType(
    String productId, {
    int days = 30,
  }) async {
    final since = DateTime.now()
        .subtract(Duration(days: days))
        .toIso8601String();

    final rows = await _requireDb.rawQuery(
      '''
      SELECT type, SUM(quantity) AS total
      FROM $_tMovements
      WHERE product_id = ? AND created_at >= ?
      GROUP BY type
      ''',
      [productId, since],
    );

    return {for (final r in rows) r['type'] as String: (r['total'] as int?) ?? 0};
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UTILIDADES
  // ══════════════════════════════════════════════════════════════════════════

  /// Elimina todos los datos (útil en logout o tests).
  Future<void> clearAll() async {
    final db = _requireDb;
    await db.transaction((txn) async {
      await txn.delete(_tMovements);
      await txn.delete(_tProducts);
      await txn.delete(_tStores);
    });
    debugPrint('[LocalDB] Todas las tablas vaciadas.');
  }

  /// Cierra la conexión (normalmente no es necesario en producción).
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MAPPERS — Modelo ↔ Row
  // ══════════════════════════════════════════════════════════════════════════

  // ── Store ────────────────────────────────────────────────────────────────

  Map<String, Object?> _storeToRow(Store s) => {
        'id':             s.id,
        'name':           s.name,
        'address':        s.address,
        'phone':          s.phone,
        'email':          s.email,
        'manager':        s.manager,
        'employee_count': s.employeeCount,
        'product_count':  s.productCount,
        'monthly_sales':  s.monthlySales,
        'is_active':      s.isActive ? 1 : 0,
        'created_at':     s.createdAt.toIso8601String(),
      };

  Store _rowToStore(Map<String, Object?> row) => Store(
        id:            row['id']            as String,
        name:          row['name']          as String,
        address:       row['address']       as String? ?? '',
        phone:         row['phone']         as String? ?? '',
        email:         row['email']         as String? ?? '',
        manager:       row['manager']       as String? ?? '',
        employeeCount: row['employee_count'] as int?    ?? 0,
        productCount:  row['product_count']  as int?    ?? 0,
        monthlySales:  (row['monthly_sales'] as num?    ?? 0).toDouble(),
        isActive:      (row['is_active']    as int?    ?? 1) == 1,
        createdAt:     DateTime.parse(row['created_at'] as String),
      );

  // ── Product ───────────────────────────────────────────────────────────────

  Map<String, Object?> _productToRow(Product p) => {
        'id':              p.id,
        'name':            p.name,
        'sku':             p.sku,
        'barcode':         p.barcode,
        'category':        p.category.value,
        'supplier':        p.supplier,
        'cost_price':      p.costPrice,
        'sale_price':      p.salePrice,
        'quantity':        p.quantity,
        'min_stock':       p.minStock,
        'location':        p.location,
        'expiration_date': p.expirationDate?.toIso8601String(),
        'image_url':       p.imageURL,
        'description':     p.description,
        'last_updated':    p.lastUpdated.toIso8601String(),
        'is_active':       p.isActive ? 1 : 0,
        'store_id':        p.storeId,
        'category_id':     p.categoryId,
        'supplier_id':     p.supplierId,
      };

  Product _rowToProduct(Map<String, Object?> row) => Product(
        id:             row['id']       as String,
        name:           row['name']     as String,
        sku:            row['sku']      as String? ?? '',
        barcode:        row['barcode']  as String? ?? '',
        category:       ProductCategory.fromValue(
                            row['category'] as String? ?? 'other'),
        supplier:       row['supplier'] as String? ?? '',
        costPrice:      (row['cost_price']  as num? ?? 0).toDouble(),
        salePrice:      (row['sale_price']  as num? ?? 0).toDouble(),
        quantity:       row['quantity']  as int?    ?? 0,
        minStock:       row['min_stock'] as int?    ?? 0,
        location:       row['location']  as String? ?? '',
        expirationDate: row['expiration_date'] != null
            ? DateTime.tryParse(row['expiration_date'] as String)
            : null,
        imageURL:       row['image_url']   as String?,
        description:    row['description'] as String? ?? '',
        lastUpdated:    DateTime.parse(row['last_updated'] as String),
        isActive:       (row['is_active']  as int? ?? 1) == 1,
        storeId:        row['store_id']    as String?,
        categoryId:     row['category_id'] as String?,
        supplierId:     row['supplier_id'] as String?,
      );

  // ── InventoryMovement ─────────────────────────────────────────────────────

  Map<String, Object?> _movementToRow(InventoryMovement m) => {
        'id':         m.id,
        'product_id': m.productId,
        'type':       m.type.name,   // 'sale' | 'restock' | 'adjust' | 'unknown'
        'quantity':   m.quantity,
        'created_at': m.createdAt.toIso8601String(),
      };

  InventoryMovement _rowToMovement(Map<String, Object?> row) =>
      InventoryMovement(
        id:        row['id']         as String,
        productId: row['product_id'] as String,
        type:      InventoryMovementType.fromBackend(row['type'] as String?),
        quantity:  row['quantity']   as int? ?? 0,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
}
