import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import 'pipeline_logger.dart';

// ─────────────────────────────────────────────
// AuditEvent (local audit trail)
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
// Handles: local cache, audit log, stores/employees (local-only fallback)
// JWT token storage is handled by ApiService
// ─────────────────────────────────────────────
class PersistenceService {
  PersistenceService._();
  static final PersistenceService shared = PersistenceService._();

  static const _kAuditLog  = 'inventaria_audit_log';
  static const _kSeeded    = 'inventaria_seeded';
  static const _kStores    = 'inventaria_stores';
  static const _kEmployees = 'inventaria_employees';

  // ── Generic helpers ────────────────────────

  Future<void> _saveList<T>(
    String key,
    List<T> items,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(items.map(toJson).toList()));
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

  // ── Audit log ──────────────────────────────

  Future<void> logAuditEvent(AuditEvent event) async {
    final events = await _loadList(_kAuditLog, AuditEvent.fromJson);
    events.add(event);
    final trimmed = events.length > 1000
        ? events.sublist(events.length - 1000)
        : events;
    await _saveList(_kAuditLog, trimmed, (e) => e.toJson());
    // STORAGE layer — local SharedPreferences write (offline-first)
    PipelineLogger.shared.log(
      stage:       PipelineStage.storage,
      operation:   'logAuditEvent → SharedPreferences [local]',
      recordCount: trimmed.length,
      latency:     Duration.zero,
    );
  }

  // ── Stores ─────────────────────────────────

  Future<List<Store>> loadStores() async {
    return _loadList(_kStores, Store.fromJson);
  }

  Future<void> saveStores(List<Store> stores) async {
    await _saveList(_kStores, stores, (s) => s.toJson());
  }

  // ── Employees ──────────────────────────────

  Future<List<Employee>> loadEmployees() async {
    return _loadList(_kEmployees, Employee.fromJson);
  }

  Future<void> saveEmployees(List<Employee> employees) async {
    await _saveList(_kEmployees, employees, (e) => e.toJson());
  }

  // ── Seed flag ──────────────────────────────

  Future<bool> isSeeded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kSeeded) ?? false;
  }

  Future<void> markSeeded() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSeeded, true);
  }

  Future<void> seedInitialDataIfNeeded() async {
    debugPrint('[PersistenceService] Using backend API — no local seed needed');
  }
}
