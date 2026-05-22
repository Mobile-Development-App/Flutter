class LocationAisleProduct {
  final String id;
  final String name;
  final int quantity;
  final bool lowStock;

  const LocationAisleProduct({
    required this.id,
    required this.name,
    required this.quantity,
    required this.lowStock,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'quantity': quantity,
        'lowStock': lowStock,
      };

  factory LocationAisleProduct.fromJson(Map<String, dynamic> m) =>
      LocationAisleProduct(
        id: m['id'] as String? ?? '',
        name: m['name'] as String? ?? '',
        quantity: (m['quantity'] as num?)?.toInt() ?? 0,
        lowStock: m['lowStock'] as bool? ?? false,
      );
}

class LocationAisle {
  final String key;
  final String label;
  final int productCount;
  final int lowStockCount;
  final List<LocationAisleProduct> products;

  const LocationAisle({
    required this.key,
    required this.label,
    required this.productCount,
    required this.lowStockCount,
    this.products = const [],
  });

  String get displayLabel {
    final trimmed = label.replaceAll(RegExp(r'\s*GPS:\s*[-\d.,\s]+$'), '').trim();
    return trimmed.isEmpty ? label : trimmed;
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'productCount': productCount,
        'lowStockCount': lowStockCount,
        'products': products.map((p) => p.toJson()).toList(),
      };

  factory LocationAisle.fromJson(Map<String, dynamic> m) => LocationAisle(
        key: m['key'] as String? ?? '',
        label: m['label'] as String? ?? '',
        productCount: (m['productCount'] as num?)?.toInt() ?? 0,
        lowStockCount: (m['lowStockCount'] as num?)?.toInt() ?? 0,
        products: (m['products'] as List<dynamic>?)
                ?.map((e) => LocationAisleProduct.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
      );
}

class LocationWalkSummary {
  final int aisleCount;
  final int checkedAisles;
  final int productCount;
  final int productsCovered;
  final int lowStockSpotted;
  final Duration computedIn;

  const LocationWalkSummary({
    required this.aisleCount,
    required this.checkedAisles,
    required this.productCount,
    required this.productsCovered,
    required this.lowStockSpotted,
    required this.computedIn,
  });

  double get progress =>
      aisleCount == 0 ? 0 : checkedAisles / aisleCount;

  Map<String, dynamic> toJson() => {
        'aisleCount': aisleCount,
        'checkedAisles': checkedAisles,
        'productCount': productCount,
        'productsCovered': productsCovered,
        'lowStockSpotted': lowStockSpotted,
        'computedInMs': computedIn.inMilliseconds,
      };

  factory LocationWalkSummary.fromJson(Map<String, dynamic> m) =>
      LocationWalkSummary(
        aisleCount: (m['aisleCount'] as num?)?.toInt() ?? 0,
        checkedAisles: (m['checkedAisles'] as num?)?.toInt() ?? 0,
        productCount: (m['productCount'] as num?)?.toInt() ?? 0,
        productsCovered: (m['productsCovered'] as num?)?.toInt() ?? 0,
        lowStockSpotted: (m['lowStockSpotted'] as num?)?.toInt() ?? 0,
        computedIn: Duration(
          milliseconds: (m['computedInMs'] as num?)?.toInt() ?? 0,
        ),
      );
}

class LocationWalkSession {
  final String id;
  final String storeId;
  final DateTime startedAt;
  final List<String> checkedAisleKeys;
  final List<LocationAisle> aisles;
  final LocationWalkSummary? summary;
  final DateTime? completedAt;

  const LocationWalkSession({
    required this.id,
    required this.storeId,
    required this.startedAt,
    this.checkedAisleKeys = const [],
    this.aisles = const [],
    this.summary,
    this.completedAt,
  });

  bool isChecked(String key) => checkedAisleKeys.contains(key);

  LocationWalkSession copyWith({
    List<String>? checkedAisleKeys,
    List<LocationAisle>? aisles,
    LocationWalkSummary? summary,
    DateTime? completedAt,
  }) =>
      LocationWalkSession(
        id: id,
        storeId: storeId,
        startedAt: startedAt,
        checkedAisleKeys: checkedAisleKeys ?? this.checkedAisleKeys,
        aisles: aisles ?? this.aisles,
        summary: summary ?? this.summary,
        completedAt: completedAt ?? this.completedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'storeId': storeId,
        'startedAt': startedAt.toIso8601String(),
        'checkedAisleKeys': checkedAisleKeys,
        'aisles': aisles.map((a) => a.toJson()).toList(),
        'summary': summary?.toJson(),
        'completedAt': completedAt?.toIso8601String(),
      };

  factory LocationWalkSession.fromJson(Map<String, dynamic> m) =>
      LocationWalkSession(
        id: m['id'] as String? ?? '',
        storeId: m['storeId'] as String? ?? '',
        startedAt: DateTime.parse(m['startedAt'] as String),
        checkedAisleKeys: (m['checkedAisleKeys'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        aisles: (m['aisles'] as List<dynamic>?)
                ?.map((e) => LocationAisle.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        summary: m['summary'] != null
            ? LocationWalkSummary.fromJson(
                Map<String, dynamic>.from(m['summary'] as Map))
            : null,
        completedAt: m['completedAt'] != null
            ? DateTime.tryParse(m['completedAt'] as String)
            : null,
      );
}
