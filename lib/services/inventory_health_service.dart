import 'package:flutter/foundation.dart' show compute, kIsWeb;

// ── _safeCompute ─────────────────────────────────────────────────────────────
// dart:isolate / compute() is not supported on Flutter Web.
// On web we run the callback synchronously on the UI thread — acceptable
// because the JS engine is single-threaded anyway and there is no true
// parallelism to lose.
// On mobile/desktop we use Flutter's compute() which spawns a real Isolate.
Future<R> _safeCompute<M, R>(
  R Function(M) callback,
  M message,
) {
  if (kIsWeb) return Future.value(callback(message));
  return compute(callback, message);
}

// ─────────────────────────────────────────────────────────────────────────────
// InventoryHealthService — Sprint 4 (New Feature)
//
// MULTI-THREADING STRATEGY: 4 concurrent Isolates via Future.wait() + compute()
// ──────────────────────────────────────────────────────────────────────────────
// Runs four independent analyses simultaneously, each in its own Dart Isolate.
// All four are launched at the same time with Future.wait():
//
//   Future.wait([
//     compute(_isolateDeadStock, ds_payload),      ← Isolate 1
//     compute(_isolateExpiryRisk, er_payload),     ← Isolate 2
//     compute(_isolateMarginHealth, rows),         ← Isolate 3
//     compute(_isolateCategoryBalance, rows),      ← Isolate 4
//   ]);
//
// Total wall-clock ≈ slowest single analysis, NOT their sum.
// Each HealthCard exposes its compute time, making concurrency observable.
//
// WHY THIS IS NEW (not in Sprint 2 / Sprint 3):
//   Sprint 3 isolated single analyses independently.
//   This feature introduces a CONSOLIDATED MULTI-ISOLATE PIPELINE that merges
//   four results into a weighted Health Score (0–100) — a concept that does not
//   exist anywhere in the previous codebase.
//   The report-generator also runs in its own Isolate (Isolate 5).
// ─────────────────────────────────────────────────────────────────────────────

// ── HealthDimension ───────────────────────────────────────────────────────────

enum HealthDimension {
  deadStock('Stock Muerto', 0.25),
  expiryRisk('Riesgo de Vencimiento', 0.30),
  marginHealth('Salud de Márgenes', 0.25),
  categoryBalance('Balance de Categorías', 0.20);

  const HealthDimension(this.label, this.weight);
  final String label;
  final double weight;
}

// ── HealthCard ────────────────────────────────────────────────────────────────

class HealthCard {
  final HealthDimension dimension;
  final double score;          // 0–100
  final String headline;
  final String insight;
  final Duration computedIn;   // Isolate wall-clock time
  final int affectedCount;

  const HealthCard({
    required this.dimension,
    required this.score,
    required this.headline,
    required this.insight,
    required this.computedIn,
    required this.affectedCount,
  });

  double get weightedScore => score * dimension.weight;
}

// ── InventoryHealthReport ─────────────────────────────────────────────────────

class InventoryHealthReport {
  final double overallScore;          // 0–100 weighted composite
  final HealthCard deadStock;
  final HealthCard expiryRisk;
  final HealthCard marginHealth;
  final HealthCard categoryBalance;
  final Duration totalComputedIn;     // wall-clock for all 4 in parallel
  final DateTime generatedAt;

  const InventoryHealthReport({
    required this.overallScore,
    required this.deadStock,
    required this.expiryRisk,
    required this.marginHealth,
    required this.categoryBalance,
    required this.totalComputedIn,
    required this.generatedAt,
  });

  List<HealthCard> get cards =>
      [deadStock, expiryRisk, marginHealth, categoryBalance];

  String get scoreLabel {
    if (overallScore >= 80) return 'Excelente';
    if (overallScore >= 60) return 'Bueno';
    if (overallScore >= 40) return 'Regular';
    return 'Crítico';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payload types (compute() transfers by copy — must be serialisable)
// ─────────────────────────────────────────────────────────────────────────────

class _DeadStockPayload {
  final List<Map<String, dynamic>> rows;
  final int windowDays;
  const _DeadStockPayload(this.rows, this.windowDays);
}

class _ExpiryPayload {
  final List<Map<String, dynamic>> rows;
  final int thresholdDays;
  const _ExpiryPayload(this.rows, this.thresholdDays);
}

class _ReportPayload {
  final double overall;
  final String label;
  final List<Map<String, dynamic>> cards;
  final String generatedAt;
  const _ReportPayload(this.overall, this.label, this.cards, this.generatedAt);
}

// ─────────────────────────────────────────────────────────────────────────────
// Top-level Isolate functions
// MUST be top-level — compute() spawns a clean Isolate with no heap access.
// ─────────────────────────────────────────────────────────────────────────────

/// Isolate 1: Dead Stock
/// Products with stock > 0 and lastUpdated older than windowDays.
/// Score = 100 × (1 − dead/active).
Map<String, dynamic> _isolateDeadStock(_DeadStockPayload p) {
  final sw = Stopwatch()..start();
  final cutoff = DateTime.now().subtract(Duration(days: p.windowDays));
  final active = p.rows.where((r) => r['isActive'] as bool).toList();
  final dead = active.where((r) {
    final qty = (r['quantity'] as num).toInt();
    if (qty <= 0) return false;
    final lu = DateTime.parse(r['lastUpdated'] as String);
    return lu.isBefore(cutoff);
  }).toList();
  final total = active.length;
  final deadCount = dead.length;
  final ratio = total > 0 ? deadCount / total : 0.0;
  final score = ((1.0 - ratio) * 100).clamp(0.0, 100.0);
  sw.stop();
  return {
    'score': score,
    'affectedCount': deadCount,
    'totalActive': total,
    'elapsedMs': sw.elapsedMilliseconds,
  };
}

/// Isolate 2: Expiry Risk
/// Products expiring within thresholdDays.
/// Score = 100 × (1 − expiring/total-with-expiry).
Map<String, dynamic> _isolateExpiryRisk(_ExpiryPayload p) {
  final sw = Stopwatch()..start();
  final now = DateTime.now();
  final cutoff = now.add(Duration(days: p.thresholdDays));
  final withExpiry =
      p.rows.where((r) => r['expirationDate'] != null).toList();
  final expiring = withExpiry.where((r) {
    final exp = DateTime.parse(r['expirationDate'] as String);
    return exp.isAfter(now) && exp.isBefore(cutoff);
  }).toList();
  final total = withExpiry.length;
  final ratio = total > 0 ? expiring.length / total : 0.0;
  final score = ((1.0 - ratio) * 100).clamp(0.0, 100.0);
  sw.stop();
  return {
    'score': score,
    'affectedCount': expiring.length,
    'totalWithExpiry': total,
    'elapsedMs': sw.elapsedMilliseconds,
  };
}

/// Isolate 3: Margin Health
/// % of active products with profitMargin >= 10.
Map<String, dynamic> _isolateMarginHealth(List<Map<String, dynamic>> rows) {
  final sw = Stopwatch()..start();
  final active = rows.where((r) => r['isActive'] as bool).toList();
  if (active.isEmpty) {
    sw.stop();
    return {'score': 100.0, 'affectedCount': 0, 'avgMargin': 0.0,
            'elapsedMs': sw.elapsedMilliseconds};
  }
  double totalMargin = 0;
  int lowCount = 0;
  for (final r in active) {
    final m = (r['profitMargin'] as num).toDouble();
    totalMargin += m;
    if (m < 10.0) lowCount++;
  }
  final avg = totalMargin / active.length;
  final healthyRatio = (active.length - lowCount) / active.length;
  final score = (healthyRatio * 100).clamp(0.0, 100.0);
  sw.stop();
  return {
    'score': score,
    'affectedCount': lowCount,
    'avgMargin': avg,
    'elapsedMs': sw.elapsedMilliseconds,
  };
}

/// Isolate 4: Category Balance
/// Herfindahl-Hirschman complement (normalised 0–100).
/// 100 = perfectly even, 0 = all stock in one category.
Map<String, dynamic> _isolateCategoryBalance(
    List<Map<String, dynamic>> rows) {
  final sw = Stopwatch()..start();
  final active = rows.where((r) => r['isActive'] as bool).toList();
  if (active.isEmpty) {
    sw.stop();
    return {'score': 100.0, 'affectedCount': 0, 'dominantCategory': '',
            'elapsedMs': sw.elapsedMilliseconds};
  }
  final totals = <String, int>{};
  for (final r in active) {
    final cat = r['category'] as String;
    final qty = (r['quantity'] as num).toInt();
    totals[cat] = (totals[cat] ?? 0) + qty;
  }
  final grandTotal = totals.values.fold<int>(0, (a, b) => a + b);
  if (grandTotal == 0) {
    sw.stop();
    return {'score': 100.0, 'affectedCount': totals.length,
            'dominantCategory': '', 'elapsedMs': sw.elapsedMilliseconds};
  }
  final n = totals.length;
  double hhi = 0.0;
  for (final qty in totals.values) {
    final p = qty / grandTotal;
    hhi += p * p;
  }
  final minHhi = n > 1 ? 1.0 / n : 1.0;
  double score;
  if ((1.0 - minHhi).abs() < 1e-9) {
    score = 100.0;
  } else {
    score = ((1.0 - hhi) / (1.0 - minHhi) * 100).clamp(0.0, 100.0);
  }
  final dominant = totals.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  sw.stop();
  return {
    'score': score,
    'affectedCount': n,
    'dominantCategory': dominant,
    'elapsedMs': sw.elapsedMilliseconds,
  };
}

/// Isolate 5: Report Generator
/// Assembles a plain-text health report — in its own Isolate to keep the
/// UI thread free even for large catalogs.
String _isolateGenerateReport(_ReportPayload p) {
  final buf = StringBuffer();
  buf.writeln('══════════════════════════════════════');
  buf.writeln('  REPORTE DE SALUD DE INVENTARIO');
  buf.writeln('  Generado: ${p.generatedAt}');
  buf.writeln('══════════════════════════════════════');
  buf.writeln('  Puntaje Global : ${p.overall.toStringAsFixed(1)} / 100');
  buf.writeln('  Estado         : ${p.label}');
  buf.writeln('──────────────────────────────────────');
  for (final c in p.cards) {
    buf.writeln('▸ ${c['label']}');
    buf.writeln('  Puntaje : ${(c['score'] as double).toStringAsFixed(1)} / 100');
    buf.writeln('  Resumen : ${c['headline']}');
    buf.writeln('  Acción  : ${c['insight']}');
    buf.writeln('  Tiempo  : ${c['elapsedMs']} ms (Isolate)');
    buf.writeln();
  }
  buf.writeln('══════════════════════════════════════');
  return buf.toString();
}

// ─────────────────────────────────────────────────────────────────────────────
// InventoryHealthService — public API
// ─────────────────────────────────────────────────────────────────────────────

class InventoryHealthService {
  InventoryHealthService._();
  static final InventoryHealthService shared = InventoryHealthService._();

  /// Runs 4 analyses concurrently in separate Isolates.
  /// [products] must be a list of wire-format maps (see [toWireFormat]).
  Future<InventoryHealthReport> analyse(
    List<Map<String, dynamic>> products, {
    int deadStockWindowDays = 30,
    int expiryThresholdDays = 15,
  }) async {
    final wallClock = Stopwatch()..start();

    // ── Launch 4 Isolates simultaneously ─────────────────────────────────────
    final results = await Future.wait([
      _safeCompute(_isolateDeadStock,
          _DeadStockPayload(products, deadStockWindowDays)),
      _safeCompute(_isolateExpiryRisk,
          _ExpiryPayload(products, expiryThresholdDays)),
      _safeCompute(_isolateMarginHealth, products),
      _safeCompute(_isolateCategoryBalance, products),
    ]);

    wallClock.stop();

    final ds = results[0];
    final er = results[1];
    final mh = results[2];
    final cb = results[3];

    final deadCard = HealthCard(
      dimension: HealthDimension.deadStock,
      score: (ds['score'] as num).toDouble(),
      headline:
          _deadStockHeadline(ds['affectedCount'] as int, ds['totalActive'] as int),
      insight: _deadStockInsight(ds['affectedCount'] as int),
      computedIn: Duration(milliseconds: ds['elapsedMs'] as int),
      affectedCount: ds['affectedCount'] as int,
    );

    final expiryCard = HealthCard(
      dimension: HealthDimension.expiryRisk,
      score: (er['score'] as num).toDouble(),
      headline: _expiryHeadline(
          er['affectedCount'] as int,
          er['totalWithExpiry'] as int,
          expiryThresholdDays),
      insight: _expiryInsight(er['affectedCount'] as int),
      computedIn: Duration(milliseconds: er['elapsedMs'] as int),
      affectedCount: er['affectedCount'] as int,
    );

    final marginCard = HealthCard(
      dimension: HealthDimension.marginHealth,
      score: (mh['score'] as num).toDouble(),
      headline: _marginHeadline(
          mh['affectedCount'] as int, (mh['avgMargin'] as num).toDouble()),
      insight: _marginInsight(
          mh['affectedCount'] as int, (mh['avgMargin'] as num).toDouble()),
      computedIn: Duration(milliseconds: mh['elapsedMs'] as int),
      affectedCount: mh['affectedCount'] as int,
    );

    final balanceCard = HealthCard(
      dimension: HealthDimension.categoryBalance,
      score: (cb['score'] as num).toDouble(),
      headline: _balanceHeadline(
          cb['affectedCount'] as int, cb['dominantCategory'] as String),
      insight: _balanceInsight((cb['score'] as num).toDouble()),
      computedIn: Duration(milliseconds: cb['elapsedMs'] as int),
      affectedCount: cb['affectedCount'] as int,
    );

    final overall = (deadCard.weightedScore +
            expiryCard.weightedScore +
            marginCard.weightedScore +
            balanceCard.weightedScore)
        .clamp(0.0, 100.0);

    return InventoryHealthReport(
      overallScore: overall,
      deadStock: deadCard,
      expiryRisk: expiryCard,
      marginHealth: marginCard,
      categoryBalance: balanceCard,
      totalComputedIn: wallClock.elapsed,
      generatedAt: DateTime.now(),
    );
  }

  /// Generates a plaintext summary in a dedicated Isolate (Isolate 5).
  Future<String> generateTextReport(InventoryHealthReport report) {
    final payload = _ReportPayload(
      report.overallScore,
      report.scoreLabel,
      report.cards
          .map((c) => {
                'label': c.dimension.label,
                'score': c.score,
                'headline': c.headline,
                'insight': c.insight,
                'elapsedMs': c.computedIn.inMilliseconds,
              })
          .toList(),
      _fmt(report.generatedAt),
    );
    return _safeCompute(_isolateGenerateReport, payload);
  }

  // ── Wire format ─────────────────────────────────────────────────────────────

  static Map<String, dynamic> toWireFormat(dynamic p) => {
        'id': p.id as String,
        'isActive': p.isActive as bool,
        'quantity': p.quantity as int,
        'minStock': p.minStock as int,
        'profitMargin': p.profitMargin as double,
        'expirationDate': (p.expirationDate as DateTime?)?.toIso8601String(),
        'lastUpdated': (p.lastUpdated as DateTime).toIso8601String(),
        'category': p.category.label as String,
      };

  // ── Headline / insight generators ───────────────────────────────────────────

  String _deadStockHeadline(int dead, int total) {
    if (dead == 0) return 'Sin productos estancados';
    return '$dead de $total producto${dead != 1 ? 's' : ''} sin movimiento (>30 días)';
  }

  String _deadStockInsight(int dead) {
    if (dead == 0) return 'Inventario activo. Excelente rotación.';
    if (dead <= 3) return 'Revisa precios o traslada a otra ubicación.';
    return 'Considera promociones o liquidación para liberar capital.';
  }

  String _expiryHeadline(int expiring, int total, int days) {
    if (total == 0) return 'Sin productos con fecha de vencimiento';
    if (expiring == 0) return 'Sin vencimientos en $days días';
    return '$expiring producto${expiring != 1 ? 's' : ''} vence${expiring == 1 ? '' : 'n'} en <$days días';
  }

  String _expiryInsight(int expiring) {
    if (expiring == 0) return 'Sin riesgo de pérdida por vencimiento.';
    if (expiring <= 2) return 'Prioriza su venta o donación esta semana.';
    return 'Activa alertas de vencimiento y ajusta reposición.';
  }

  String _marginHeadline(int low, double avg) {
    if (low == 0) return 'Todos los márgenes son saludables (≥10 %)';
    return '$low producto${low != 1 ? 's' : ''} con margen <10 % — '
        'promedio: ${avg.toStringAsFixed(1)} %';
  }

  String _marginInsight(int low, double avg) {
    if (low == 0) return 'Rentabilidad estable. Sigue monitoreando costos.';
    if (avg < 5) return 'Margen promedio crítico. Revisa precios urgentemente.';
    return 'Ajusta precios o negocia costos con proveedores.';
  }

  String _balanceHeadline(int cats, String dominant) {
    if (cats == 0) return 'Sin categorías con stock';
    if (dominant.isEmpty) return '$cats categorías activas';
    return '$cats categoría${cats != 1 ? 's' : ''} — mayor volumen: $dominant';
  }

  String _balanceInsight(double score) {
    if (score >= 70) return 'Distribución saludable entre categorías.';
    if (score >= 40) return 'Considera diversificar el portafolio de productos.';
    return 'Alta concentración en una categoría — riesgo de liquidez.';
  }

  String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}  '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}
