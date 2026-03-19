import 'user.dart'; // for UserRole

// ─────────────────────────────────────────────
// Employee  (mirrors Employee struct in Swift)
// Note: UserRole is shared with User model
// ─────────────────────────────────────────────
class Employee {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final UserRole role;
  final String storeId;
  final String storeName;
  final DateTime joinDate;
  final bool isActive;

  const Employee({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.storeId,
    required this.storeName,
    required this.joinDate,
    required this.isActive,
  });

  /// "MG" from "María García"
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    final first = parts.isNotEmpty ? parts.first[0] : '';
    final last = parts.length > 1 ? parts.last[0] : '';
    return '$first$last'.toUpperCase();
  }

  Employee copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    UserRole? role,
    String? storeId,
    String? storeName,
    DateTime? joinDate,
    bool? isActive,
  }) {
    return Employee(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      joinDate: joinDate ?? this.joinDate,
      isActive: isActive ?? this.isActive,
    );
  }

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
        id: json['id'] as String,
        fullName: json['fullName'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String,
        role: UserRole.fromValue(json['role'] as String),
        storeId: json['storeId'] as String,
        storeName: json['storeName'] as String,
        joinDate: DateTime.parse(json['joinDate'] as String),
        isActive: json['isActive'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'role': role.value,
        'storeId': storeId,
        'storeName': storeName,
        'joinDate': joinDate.toIso8601String(),
        'isActive': isActive,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Employee && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
