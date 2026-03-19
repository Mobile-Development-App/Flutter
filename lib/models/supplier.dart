// ─────────────────────────────────────────────
// Supplier  (mirrors Supplier struct in Swift)
// ─────────────────────────────────────────────
class Supplier {
  final String id;
  final String name;
  final String contactName;
  final String email;
  final String phone;
  final String address;
  final String category;
  final bool isActive;

  const Supplier({
    required this.id,
    required this.name,
    required this.contactName,
    required this.email,
    required this.phone,
    required this.address,
    required this.category,
    required this.isActive,
  });

  Supplier copyWith({
    String? id,
    String? name,
    String? contactName,
    String? email,
    String? phone,
    String? address,
    String? category,
    bool? isActive,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      contactName: contactName ?? this.contactName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
    );
  }

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
        id: json['id'] as String,
        name: json['name'] as String,
        contactName: json['contactName'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String,
        address: json['address'] as String,
        category: json['category'] as String,
        isActive: json['isActive'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'contactName': contactName,
        'email': email,
        'phone': phone,
        'address': address,
        'category': category,
        'isActive': isActive,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Supplier && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
