import 'package:flutter/material.dart';
import '../services/api_service.dart';

// ─────────────────────────────────────────────
// UserRole — maps backend OWNER | ADMIN | EMPLOYEE
// ─────────────────────────────────────────────
enum UserRole {
  owner('Propietario'),
  manager('Gerente'),
  employee('Empleado'),
  viewer('Observador');

  const UserRole(this.label);
  final String label;

  IconData get icon {
    switch (this) {
      case owner:
        return Icons.workspace_premium_rounded;
      case manager:
        return Icons.manage_accounts_rounded;
      case employee:
        return Icons.person_rounded;
      case viewer:
        return Icons.visibility_rounded;
    }
  }

  String get value => name;

  // Backend sends: OWNER, ADMIN, MANAGER, EMPLOYEE
  static UserRole fromBackend(String? val) {
    switch ((val ?? '').toUpperCase()) {
      case 'OWNER':
      case 'ADMIN':
        return UserRole.owner;
      case 'MANAGER':
        return UserRole.manager;
      case 'EMPLOYEE':
        return UserRole.employee;
      default:
        return UserRole.viewer;
    }
  }

  static UserRole fromValue(String value) => UserRole.values.firstWhere(
        (e) => e.name == value,
        orElse: () => UserRole.viewer,
      );

  // What to send TO backend
  String get backendValue =>
      this == UserRole.owner ? 'OWNER' : 'EMPLOYEE';
}

// ─────────────────────────────────────────────
// User
// Backend /auth/login returns:
//   { uid, storeId, email, name, role }
// Backend /auth/register returns:
//   { uid, storeId, email, name, role }
// ─────────────────────────────────────────────
class User {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final UserRole role;
  final String storeName;
  final String? storeId;
  final String? avatarURL;
  final DateTime joinDate;
  final bool isActive;

  const User({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone = '',
    required this.role,
    this.storeName = '',
    this.storeId,
    this.avatarURL,
    required this.joinDate,
    required this.isActive,
  });

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    final first = parts.isNotEmpty ? parts.first[0] : '';
    final last  = parts.length > 1 ? parts.last[0] : '';
    return '$first$last'.toUpperCase();
  }

  // ── From backend JSON ──
  // Handles both { uid, name, ... } and { id, fullName, ... }
  factory User.fromBackendJson(Map<String, dynamic> json) => User(
        id: json['uid'] as String? ??
            json['id'] as String? ?? '',
        fullName: json['name'] as String? ??
            json['fullName'] as String? ?? 'Usuario',
        email: json['email'] as String? ?? '',
        role: UserRole.fromBackend(json['role'] as String?),
        storeId: json['storeId'] as String?,
        storeName: json['storeName'] as String? ?? '',
        joinDate: ApiService.parseDate(json['createdAt']) ?? DateTime.now(),
        isActive: json['isActive'] as bool? ?? true,
      );

  // ── Local JSON (SharedPreferences cache) ──
  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        fullName: json['fullName'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String? ?? '',
        role: UserRole.fromValue(json['role'] as String),
        storeName: json['storeName'] as String? ?? '',
        storeId: json['storeId'] as String?,
        avatarURL: json['avatarURL'] as String?,
        joinDate: DateTime.parse(json['joinDate'] as String),
        isActive: json['isActive'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'role': role.value,
        'storeName': storeName,
        if (storeId != null) 'storeId': storeId,
        if (avatarURL != null) 'avatarURL': avatarURL,
        'joinDate': joinDate.toIso8601String(),
        'isActive': isActive,
      };

  User copyWith({
    String? fullName,
    String? email,
    String? phone,
    UserRole? role,
    String? storeName,
    String? storeId,
    String? avatarURL,
    DateTime? joinDate,
    bool? isActive,
  }) =>
      User(
        id: id,
        fullName: fullName ?? this.fullName,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        role: role ?? this.role,
        storeName: storeName ?? this.storeName,
        storeId: storeId ?? this.storeId,
        avatarURL: avatarURL ?? this.avatarURL,
        joinDate: joinDate ?? this.joinDate,
        isActive: isActive ?? this.isActive,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
