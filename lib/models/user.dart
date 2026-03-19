import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// UserRole  (mirrors UserRole enum in Swift)
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

  static UserRole fromValue(String value) => UserRole.values.firstWhere(
        (e) => e.name == value,
        orElse: () => UserRole.viewer,
      );
}

// ─────────────────────────────────────────────
// User  (mirrors User struct in Swift)
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
    required this.phone,
    required this.role,
    required this.storeName,
    this.storeId,
    this.avatarURL,
    required this.joinDate,
    required this.isActive,
  });

  /// "SJ" from "Sarah Johnson"
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    final first = parts.isNotEmpty ? parts.first[0] : '';
    final last = parts.length > 1 ? parts.last[0] : '';
    return '$first$last'.toUpperCase();
  }

  User copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    UserRole? role,
    String? storeName,
    String? storeId,
    String? avatarURL,
    DateTime? joinDate,
    bool? isActive,
  }) {
    return User(
      id: id ?? this.id,
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
  }

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        fullName: json['fullName'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String,
        role: UserRole.fromValue(json['role'] as String),
        storeName: json['storeName'] as String,
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
