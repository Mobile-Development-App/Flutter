class StockCountLine {
  final String productId;
  final String productName;
  final String sku;
  final int systemQuantity;
  final int countedQuantity;
  final DateTime recordedAt;

  const StockCountLine({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.systemQuantity,
    required this.countedQuantity,
    required this.recordedAt,
  });

  int get variance => countedQuantity - systemQuantity;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'productName': productName,
        'sku': sku,
        'systemQuantity': systemQuantity,
        'countedQuantity': countedQuantity,
        'recordedAt': recordedAt.toIso8601String(),
      };

  factory StockCountLine.fromJson(Map<String, dynamic> m) => StockCountLine(
        productId: m['productId'] as String,
        productName: m['productName'] as String,
        sku: m['sku'] as String,
        systemQuantity: (m['systemQuantity'] as num).toInt(),
        countedQuantity: (m['countedQuantity'] as num).toInt(),
        recordedAt: DateTime.parse(m['recordedAt'] as String),
      );
}

class StockCountSummary {
  final int matchCount;
  final int overCount;
  final int underCount;
  final int totalVarianceUnits;
  final Duration computedIn;

  const StockCountSummary({
    required this.matchCount,
    required this.overCount,
    required this.underCount,
    required this.totalVarianceUnits,
    required this.computedIn,
  });

  int get totalLines => matchCount + overCount + underCount;

  Map<String, dynamic> toJson() => {
        'matchCount': matchCount,
        'overCount': overCount,
        'underCount': underCount,
        'totalVarianceUnits': totalVarianceUnits,
        'computedInMs': computedIn.inMilliseconds,
      };

  factory StockCountSummary.fromJson(Map<String, dynamic> m) =>
      StockCountSummary(
        matchCount: (m['matchCount'] as num).toInt(),
        overCount: (m['overCount'] as num).toInt(),
        underCount: (m['underCount'] as num).toInt(),
        totalVarianceUnits: (m['totalVarianceUnits'] as num).toInt(),
        computedIn:
            Duration(milliseconds: (m['computedInMs'] as num).toInt()),
      );
}

class StockCountSession {
  final String id;
  final String storeId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final List<StockCountLine> lines;
  final StockCountSummary? summary;
  final bool syncPending;

  const StockCountSession({
    required this.id,
    required this.storeId,
    required this.startedAt,
    this.completedAt,
    this.lines = const [],
    this.summary,
    this.syncPending = false,
  });

  bool get isActive => completedAt == null;

  StockCountSession copyWith({
    DateTime? completedAt,
    List<StockCountLine>? lines,
    StockCountSummary? summary,
    bool? syncPending,
  }) =>
      StockCountSession(
        id: id,
        storeId: storeId,
        startedAt: startedAt,
        completedAt: completedAt ?? this.completedAt,
        lines: lines ?? this.lines,
        summary: summary ?? this.summary,
        syncPending: syncPending ?? this.syncPending,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'storeId': storeId,
        'startedAt': startedAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'lines': lines.map((l) => l.toJson()).toList(),
        'summary': summary?.toJson(),
        'syncPending': syncPending,
      };

  factory StockCountSession.fromJson(Map<String, dynamic> m) =>
      StockCountSession(
        id: m['id'] as String,
        storeId: m['storeId'] as String,
        startedAt: DateTime.parse(m['startedAt'] as String),
        completedAt: m['completedAt'] != null
            ? DateTime.parse(m['completedAt'] as String)
            : null,
        lines: (m['lines'] as List? ?? [])
            .map((e) => StockCountLine.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList(),
        summary: m['summary'] != null
            ? StockCountSummary.fromJson(
                Map<String, dynamic>.from(m['summary'] as Map))
            : null,
        syncPending: m['syncPending'] as bool? ?? false,
      );
}
