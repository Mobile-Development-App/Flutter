import 'dart:collection';

// ─────────────────────────────────────────────────────────────────────────────
// LRUCache<K, V>
//
// Implementación de Least-Recently-Used cache usando LinkedHashMap de Dart.
//
// ALGORITMO:
//   LinkedHashMap mantiene orden de inserción.  LRU se logra así:
//     • get(key)  → remueve y re-inserta al final = marca como "reciente".
//     • put(key)  → si lleno, elimina _map.keys.first (el más antiguo = LRU).
//
// COMPLEJIDAD: O(1) amortizado en get / put / remove gracias al hash map.
//
// USO TÍPICO:
//   final cache = LRUCache<String, MyData>(capacity: 50);
//   cache.put('key', data);
//   final hit = cache.get('key');   // null si expirado o ausente
// ─────────────────────────────────────────────────────────────────────────────

class LRUCache<K, V> {
  final int capacity;

  // LinkedHashMap mantiene orden de inserción — la clave más antigua
  // queda en keys.first y es la candidata a ser eviccionada.
  final LinkedHashMap<K, V> _map = LinkedHashMap<K, V>();

  LRUCache(this.capacity) : assert(capacity > 0, 'capacity debe ser > 0');

  // ── Lectura ─────────────────────────────────────────────────────────────────

  /// Retorna el valor asociado a [key], o `null` si no existe.
  /// Marca la entrada como "usada recientemente" (la mueve al final).
  V? get(K key) {
    if (!_map.containsKey(key)) return null;
    // Remover y re-insertar al final para marcar como reciente.
    final value = _map.remove(key) as V;
    _map[key] = value;
    return value;
  }

  // ── Escritura ────────────────────────────────────────────────────────────────

  /// Almacena [value] bajo [key].
  /// Si ya existe la clave, la renueva como "más reciente".
  /// Si se superó la capacidad, evicta la entrada menos usada recientemente.
  void put(K key, V value) {
    if (_map.containsKey(key)) {
      _map.remove(key); // eliminar para re-insertar al final
    } else if (_map.length >= capacity) {
      // Evictar LRU: el primero del mapa es el más antiguo.
      _map.remove(_map.keys.first);
    }
    _map[key] = value;
  }

  // ── Eliminación ──────────────────────────────────────────────────────────────

  /// Elimina la entrada [key] si existe.
  void remove(K key) => _map.remove(key);

  /// Elimina múltiples claves de una vez.
  void removeAll(Iterable<K> keys) {
    for (final k in keys) {
      _map.remove(k);
    }
  }

  /// Vacía el cache por completo.
  void clear() => _map.clear();

  // ── Consulta ─────────────────────────────────────────────────────────────────

  bool containsKey(K key) => _map.containsKey(key);
  int get length => _map.length;
  bool get isEmpty => _map.isEmpty;
  bool get isFull => _map.length >= capacity;

  /// Retorna todas las claves en orden de "menos reciente" a "más reciente".
  Iterable<K> get keys => _map.keys;

  @override
  String toString() =>
      'LRUCache(capacity=$capacity, size=${_map.length}, '
      'keys=${_map.keys.toList()})';
}
