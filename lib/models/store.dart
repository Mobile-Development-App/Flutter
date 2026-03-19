import '../core/utils/extensions.dart';

// ─────────────────────────────────────────────
// Store  (mirrors Store struct in Swift)
// ─────────────────────────────────────────────
class Store {
  final String id;
  final String name;
  final String address;
  final String phone;
  final String email;
  final String manager;
  final int employeeCount;
  final int productCount;
  final double monthlySales;
  final bool isActive;
  final DateTime createdAt;

  const Store({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    required this.manager,
    required this.employeeCount,
    required this.productCount,
    required this.monthlySales,
    required this.isActive,
    required this.createdAt,
  });

  /// "$12.500.000"
  String get formattedSales => monthlySales.currencyFormatted;

  Store copyWith({
    String? id,
    String? name,
    String? address,
    String? phone,
    String? email,
    String? manager,
    int? employeeCount,
    int? productCount,
    double? monthlySales,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Store(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      manager: manager ?? this.manager,
      employeeCount: employeeCount ?? this.employeeCount,
      productCount: productCount ?? this.productCount,
      monthlySales: monthlySales ?? this.monthlySales,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Store.fromJson(Map<String, dynamic> json) => Store(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String,
        phone: json['phone'] as String,
        email: json['email'] as String,
        manager: json['manager'] as String,
        employeeCount: json['employeeCount'] as int,
        productCount: json['productCount'] as int,
        monthlySales: (json['monthlySales'] as num).toDouble(),
        isActive: json['isActive'] as bool? ?? true,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'phone': phone,
        'email': email,
        'manager': manager,
        'employeeCount': employeeCount,
        'productCount': productCount,
        'monthlySales': monthlySales,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Store && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
