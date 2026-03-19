import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';

// ─────────────────────────────────────────────
// AuditEvent
// ─────────────────────────────────────────────
class AuditEvent {
  final String id;
  final String userId;
  final String userName;
  final String action;
  final String entityType;
  final String? entityId;
  final String? entityName;
  final String details;
  final DateTime timestamp;

  const AuditEvent({
    required this.id,
    required this.userId,
    required this.userName,
    required this.action,
    required this.entityType,
    this.entityId,
    this.entityName,
    required this.details,
    required this.timestamp,
  });

  factory AuditEvent.create({
    required String userId,
    required String userName,
    required String action,
    required String entityType,
    String? entityId,
    String? entityName,
    required String details,
  }) =>
      AuditEvent(
        id: const Uuid().v4(),
        userId: userId,
        userName: userName,
        action: action,
        entityType: entityType,
        entityId: entityId,
        entityName: entityName,
        details: details,
        timestamp: DateTime.now(),
      );

  factory AuditEvent.fromJson(Map<String, dynamic> json) => AuditEvent(
        id: json['id'] as String,
        userId: json['userId'] as String,
        userName: json['userName'] as String,
        action: json['action'] as String,
        entityType: json['entityType'] as String,
        entityId: json['entityId'] as String?,
        entityName: json['entityName'] as String?,
        details: json['details'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'action': action,
        'entityType': entityType,
        if (entityId != null) 'entityId': entityId,
        if (entityName != null) 'entityName': entityName,
        'details': details,
        'timestamp': timestamp.toIso8601String(),
      };
}

// ─────────────────────────────────────────────
// PersistenceService
// Uses SharedPreferences only — no path_provider, no dart:io.
// Works reliably on Android, iOS and web.
// ─────────────────────────────────────────────
class PersistenceService {
  PersistenceService._();
  static final PersistenceService shared = PersistenceService._();

  // ── Keys ──────────────────────────────────
  static const _kProducts   = 'inventaria_products';
  static const _kStores     = 'inventaria_stores';
  static const _kEmployees  = 'inventaria_employees';
  static const _kAlerts     = 'inventaria_alerts';
  static const _kOrders     = 'inventaria_orders';
  static const _kSuppliers  = 'inventaria_suppliers';
  static const _kUser       = 'inventaria_current_user';
  static const _kAuditLog   = 'inventaria_audit_log';
  static const _kSeeded     = 'inventaria_seeded';

  // ── Generic helpers ────────────────────────

  Future<void> _saveList<T>(
    String key,
    List<T> items,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(items.map(toJson).toList());
      await prefs.setString(key, encoded);
    } catch (e) {
      debugPrint('[PersistenceService] saveList $key error: $e');
    }
  }

  Future<List<T>> _loadList<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[PersistenceService] loadList $key error: $e');
      return [];
    }
  }

  Future<void> _saveSingle<T>(
    String key,
    T item,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(toJson(item)));
    } catch (e) {
      debugPrint('[PersistenceService] saveSingle $key error: $e');
    }
  }

  Future<T?> _loadSingle<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return null;
      return fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[PersistenceService] loadSingle $key error: $e');
      return null;
    }
  }

  Future<bool> _exists(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(key);
  }

  Future<void> _delete(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  // ── Typed helpers ──────────────────────────

  Future<void> saveProducts(List<Product> items) =>
      _saveList(_kProducts, items, (p) => p.toJson());
  Future<List<Product>> loadProducts() =>
      _loadList(_kProducts, Product.fromJson);

  Future<void> saveStores(List<Store> items) =>
      _saveList(_kStores, items, (s) => s.toJson());
  Future<List<Store>> loadStores() =>
      _loadList(_kStores, Store.fromJson);

  Future<void> saveEmployees(List<Employee> items) =>
      _saveList(_kEmployees, items, (e) => e.toJson());
  Future<List<Employee>> loadEmployees() =>
      _loadList(_kEmployees, Employee.fromJson);

  Future<void> saveAlerts(List<InventoryAlert> items) =>
      _saveList(_kAlerts, items, (a) => a.toJson());
  Future<List<InventoryAlert>> loadAlerts() =>
      _loadList(_kAlerts, InventoryAlert.fromJson);

  Future<void> saveOrders(List<Order> items) =>
      _saveList(_kOrders, items, (o) => o.toJson());
  Future<List<Order>> loadOrders() =>
      _loadList(_kOrders, Order.fromJson);

  Future<void> saveSuppliers(List<Supplier> items) =>
      _saveList(_kSuppliers, items, (s) => s.toJson());
  Future<List<Supplier>> loadSuppliers() =>
      _loadList(_kSuppliers, Supplier.fromJson);

  // ── User session ───────────────────────────

  Future<void> saveUser(User user) =>
      _saveSingle(_kUser, user, (u) => u.toJson());
  Future<User?> loadUser() =>
      _loadSingle(_kUser, User.fromJson);
  Future<void> clearUser() => _delete(_kUser);

  // ── Audit log ──────────────────────────────

  Future<void> logAuditEvent(AuditEvent event) async {
    try {
      final events = await _loadList(_kAuditLog, AuditEvent.fromJson);
      events.add(event);
      final trimmed = events.length > 1000
          ? events.sublist(events.length - 1000)
          : events;
      await _saveList(_kAuditLog, trimmed, (e) => e.toJson());
    } catch (e) {
      debugPrint('[PersistenceService] logAuditEvent error: $e');
    }
  }

  Future<List<AuditEvent>> loadAuditLog() =>
      _loadList(_kAuditLog, AuditEvent.fromJson);

  // ── First launch seed ──────────────────────

  Future<void> seedInitialDataIfNeeded() async {
    try {
      final already = await _exists(_kSeeded);
      if (already) return;

      await saveProducts(MockData.products);
      await saveStores(MockData.stores);
      await saveEmployees(MockData.employees);
      await saveAlerts(MockData.alerts);
      await saveOrders(MockData.orders);
      await saveSuppliers(MockData.suppliers);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kSeeded, true);

      debugPrint('[PersistenceService] Initial data seeded');
    } catch (e) {
      debugPrint('[PersistenceService] seedInitialDataIfNeeded error: $e');
    }
  }
}
