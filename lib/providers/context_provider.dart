import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/alert.dart';
import '../models/product.dart';
import '../providers/inventory_provider.dart';
import '../providers/auth_provider.dart';
import '../services/pipeline_logger.dart';

// ─────────────────────────────────────────────
// InventoryHealthScore  (0-100)
// ─────────────────────────────────────────────
class HealthScore {
  final int score;
  final String label;
  final Color color;
  final String emoji;
  final String description;

  const HealthScore({
    required this.score,
    required this.label,
    required this.color,
    required this.emoji,
    required this.description,
  });

  static HealthScore compute({
    required int total,
    required int lowStock,
    required int outOfStock,
    required int expiring,
    required int unreadAlerts,
  }) {
    if (total == 0) {
      return const HealthScore(
        score: 0,
        label: 'Sin datos',
        color: Color(0xFF8E8E93),
        emoji: '📭',
        description: 'Agrega productos para comenzar',
      );
    }

    // Weighted penalty system
    double penalty = 0;
    penalty += (outOfStock / total) * 40;     // agotados pesan 40%
    penalty += (lowStock / total) * 25;       // stock bajo pesa 25%
    penalty += (expiring / total) * 20;       // por vencer pesa 20%
    penalty += (unreadAlerts / 10).clamp(0, 15); // alertas no leídas hasta 15%

    final score = (100 - penalty).clamp(0, 100).toInt();

    if (score >= 85) {
      return HealthScore(
        score: score,
        label: 'Excelente',
        color: const Color(0xFF30D158),
        emoji: '🚀',
        description: 'Tu inventario está en óptimas condiciones',
      );
    } else if (score >= 65) {
      return HealthScore(
        score: score,
        label: 'Bueno',
        color: const Color(0xFF34C759),
        emoji: '✅',
        description: 'Inventario saludable con algunos puntos a mejorar',
      );
    } else if (score >= 45) {
      return HealthScore(
        score: score,
        label: 'Regular',
        color: const Color(0xFFFF9F0A),
        emoji: '⚠️',
        description: 'Requiere atención en varias categorías',
      );
    } else if (score >= 20) {
      return HealthScore(
        score: score,
        label: 'Crítico',
        color: const Color(0xFFFF453A),
        emoji: '🔴',
        description: 'Acción urgente requerida en el inventario',
      );
    } else {
      return HealthScore(
        score: score,
        label: 'Alerta Máxima',
        color: const Color(0xFFFF2D55),
        emoji: '🚨',
        description: 'Inventario en estado crítico — intervención inmediata',
      );
    }
  }
}

// ─────────────────────────────────────────────
// ContextualInsight — a smart message for the user
// ─────────────────────────────────────────────
class ContextualInsight {
  final String title;
  final String body;
  final IconData icon;
  final Color color;
  final InsightPriority priority;
  final String? actionLabel;
  final String? actionRoute;

  const ContextualInsight({
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
    required this.priority,
    this.actionLabel,
    this.actionRoute,
  });
}

enum InsightPriority { urgent, warning, info, positive }

// ─────────────────────────────────────────────
// ContextState — full context-aware state
// ─────────────────────────────────────────────
class ContextState {
  final HealthScore healthScore;
  final List<ContextualInsight> insights;
  final String greetingMessage;
  final String greetingSubtitle;
  final List<Product> criticalProducts;   // out of stock
  final List<Product> warningProducts;    // low stock
  final List<Product> expiringProducts;   // expiring soon
  final List<InventoryAlert> urgentAlerts;
  final bool hasUrgentAction;
  final double stockHealthPercent;        // % of products with healthy stock

  const ContextState({
    required this.healthScore,
    required this.insights,
    required this.greetingMessage,
    required this.greetingSubtitle,
    required this.criticalProducts,
    required this.warningProducts,
    required this.expiringProducts,
    required this.urgentAlerts,
    required this.hasUrgentAction,
    required this.stockHealthPercent,
  });

  static ContextState empty() => ContextState(
        healthScore: HealthScore.compute(
            total: 0,
            lowStock: 0,
            outOfStock: 0,
            expiring: 0,
            unreadAlerts: 0),
        insights: const [],
        greetingMessage: 'Bienvenido 👋',
        greetingSubtitle: 'Cargando tu inventario...',
        criticalProducts: const [],
        warningProducts: const [],
        expiringProducts: const [],
        urgentAlerts: const [],
        hasUrgentAction: false,
        stockHealthPercent: 100,
      );
}

// ─────────────────────────────────────────────
// ContextEngine — computes all context from inventory
// ─────────────────────────────────────────────
class ContextNotifier extends Notifier<ContextState> {
  @override
  ContextState build() {
    final sw = Stopwatch()..start();
    final invAsync  = ref.watch(inventoryProvider);
    final authAsync = ref.watch(authProvider);

    final inv  = invAsync.value;
    final auth = authAsync.value;

    if (inv == null) {
      sw.stop();
      PipelineLogger.shared.log(
        stage: PipelineStage.computation,
        operation: 'ContextNotifier.build(empty)',
        recordCount: 0,
        latency: sw.elapsed,
      );
      return ContextState.empty();
    }

    final products     = inv.products;
    final alerts       = inv.alerts;
    final stats        = inv.dashboardStats;
    final fullName = auth?.currentUser?.fullName;
    final firstName = fullName == null ? 'Usuario' : fullName.split(' ').first;

    final critical  = products.where((p) => p.stockStatus == StockStatus.outOfStock && p.isActive).toList();
    final warning   = products.where((p) => p.stockStatus == StockStatus.lowStock && p.isActive).toList();
    final expiring  = products.where((p) => p.isExpiringSoon).toList();
    final urgent    = alerts.where((a) => !a.isRead && a.priority == AlertPriority.high).toList();

    final health = HealthScore.compute(
      total:        products.length,
      lowStock:     stats.lowStockCount,
      outOfStock:   stats.outOfStockCount,
      expiring:     stats.expiringCount,
      unreadAlerts: inv.unreadAlertCount,
    );

    final stockHealthPercent = products.isEmpty
        ? 100.0
        : ((products.length - critical.length - warning.length) /
                products.length *
                100)
            .clamp(0, 100)
            .toDouble();

    final result = ContextState(
      healthScore:       health,
      insights:          _buildInsights(products, critical, warning, expiring, urgent, stats),
      greetingMessage:   _greeting(firstName, health),
      greetingSubtitle:  _subtitle(health, critical, warning, expiring),
      criticalProducts:  critical,
      warningProducts:   warning,
      expiringProducts:  expiring,
      urgentAlerts:      urgent,
      hasUrgentAction:   critical.isNotEmpty || urgent.isNotEmpty,
      stockHealthPercent: stockHealthPercent,
    );

    sw.stop();
    PipelineLogger.shared.log(
      stage: PipelineStage.computation,
      operation: 'ContextNotifier.build',
      recordCount: result.insights.length,
      latency: sw.elapsed,
    );

    return result;
  }

  // ── Greeting ──────────────────────────────

  String _greeting(String name, HealthScore health) {
    final hour = DateTime.now().hour;
    final timeGreet = hour < 12
        ? 'Buenos días'
        : hour < 18
            ? 'Buenas tardes'
            : 'Buenas noches';

    return '$timeGreet, $name ${health.emoji}';
  }

  String _subtitle(
    HealthScore health,
    List<Product> critical,
    List<Product> warning,
    List<Product> expiring,
  ) {
    if (critical.isNotEmpty) {
      return '${critical.length} producto${critical.length > 1 ? 's' : ''} agotado${critical.length > 1 ? 's' : ''} — requiere atención inmediata';
    }
    if (warning.isNotEmpty && expiring.isNotEmpty) {
      return '${warning.length} en stock bajo · ${expiring.length} por vencer';
    }
    if (warning.isNotEmpty) {
      return '${warning.length} producto${warning.length > 1 ? 's' : ''} con stock bajo';
    }
    if (expiring.isNotEmpty) {
      return '${expiring.length} producto${expiring.length > 1 ? 's' : ''} próximo${expiring.length > 1 ? 's' : ''} a vencer';
    }
    return health.description;
  }

  // ── Insights ──────────────────────────────

  List<ContextualInsight> _buildInsights(
    List<Product> all,
    List<Product> critical,
    List<Product> warning,
    List<Product> expiring,
    List<InventoryAlert> urgent,
    dynamic stats,
  ) {
    final insights = <ContextualInsight>[];

    // 1. Critical stock
    if (critical.isNotEmpty) {
      final names = critical.take(2).map((p) => p.name).join(', ');
      final extra = critical.length > 2 ? ' y ${critical.length - 2} más' : '';
      insights.add(ContextualInsight(
        title: 'Productos Agotados',
        body: '$names$extra ${critical.length > 1 ? 'están' : 'está'} sin stock. Reabastecer urgente.',
        icon: Icons.cancel_rounded,
        color: const Color(0xFFFF453A),
        priority: InsightPriority.urgent,
        actionLabel: 'Reabastecer',
        actionRoute: 'restock',
      ));
    }

    // 2. Low stock warning
    if (warning.isNotEmpty) {
      // Find the most critical (closest to 0)
      final sorted = [...warning]..sort((a, b) => a.quantity.compareTo(b.quantity));
      final worst = sorted.first;
      insights.add(ContextualInsight(
        title: 'Stock Bajo',
        body: '${warning.length} producto${warning.length > 1 ? 's' : ''} cerca del límite. "${worst.name}" tiene solo ${worst.quantity} unidades.',
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFFF9F0A),
        priority: InsightPriority.warning,
        actionLabel: 'Ver productos',
        actionRoute: 'products',
      ));
    }

    // 3. Expiring soon
    if (expiring.isNotEmpty) {
      final soonest = expiring.reduce((a, b) =>
          (a.expirationDate ?? DateTime(9999))
                  .isBefore(b.expirationDate ?? DateTime(9999))
              ? a
              : b);
      final days = soonest.expirationDate
              ?.difference(DateTime.now())
              .inDays ??
          0;
      insights.add(ContextualInsight(
        title: 'Productos por Vencer',
        body: '"${soonest.name}" vence en $days día${days == 1 ? '' : 's'}. ${expiring.length > 1 ? 'Hay ${expiring.length} productos afectados.' : ''}',
        icon: Icons.access_time_rounded,
        color: const Color(0xFFFF9F0A),
        priority: InsightPriority.warning,
        actionLabel: 'Revisar',
        actionRoute: 'products',
      ));
    }

    // 4. Margin opportunity — products with low margin
    if (all.isNotEmpty) {
      final lowMargin = all.where((p) => p.profitMargin < 10 && p.profitMargin > 0).toList();
      if (lowMargin.isNotEmpty) {
        insights.add(ContextualInsight(
          title: 'Oportunidad de Margen',
          body: '${lowMargin.length} producto${lowMargin.length > 1 ? 's tienen' : ' tiene'} margen menor al 10%. Considera ajustar precios.',
          icon: Icons.trending_up_rounded,
          color: const Color(0xFF0A84FF),
          priority: InsightPriority.info,
          actionLabel: 'Ver productos',
          actionRoute: 'products',
        ));
      }
    }

    // 5. Positive feedback when everything is good
    if (critical.isEmpty && warning.isEmpty && expiring.isEmpty && all.isNotEmpty) {
      insights.add(ContextualInsight(
        title: 'Inventario Saludable',
        body: 'Todos tus productos tienen stock suficiente. ¡Excelente gestión!',
        icon: Icons.verified_rounded,
        color: const Color(0xFF30D158),
        priority: InsightPriority.positive,
      ));
    }

    // Show most urgent first
    insights.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    return insights;
  }
}

final contextProvider = NotifierProvider<ContextNotifier, ContextState>(
  ContextNotifier.new,
);
