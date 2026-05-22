import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../../models/product.dart';
import '../../providers/providers.dart';
import '../../services/inventory_health_service.dart';
import '../../widgets/widgets.dart';
import '../notifications/notifications_screen.dart';
import '../products/add_product_screen.dart';
import '../products/product_detail_screen.dart';
import '../products/products_screen.dart';
import '../restock/restock_screen.dart';
import '../settings/settings_screen.dart';
import '../inventory/location_walk_screen.dart';
// Sprint 3 — BQ5: screen session tracking
import '../../core/utils/screen_tracker_mixin.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin, ScreenTrackerMixin {

  @override
  String get trackedScreenName => 'home'; // BQ5
  late AnimationController _pulseCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _pulse;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _pulse = Tween<double>(begin: 0.97, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = context.isDark;
    final invAsync = ref.watch(inventoryProvider);
    final ctx      = ref.watch(contextProvider);
    final healthAsync = ref.watch(inventoryHealthProvider);
    final pinnedAsync = ref.watch(pinnedProductsProvider);
    final invState = invAsync.value;
    final pinnedIds = pinnedAsync.valueOrNull ?? <String>{};
    final pinnedProducts = invState?.products
            .where((product) => pinnedIds.contains(product.id))
            .toList() ??
        <Product>[];

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: FadeTransition(
        opacity: _fade,
        child: RefreshIndicator(
          onRefresh: () => ref.read(inventoryProvider.notifier).refreshData(),
          color: AppColors.freshSky,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _sliverAppBar(context, isDark, invState),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 16),
                    // ── Context Banner ──
                    _contextBanner(ctx, isDark),
                    const SizedBox(height: 20),
                    // ── Health Score ──
                    _healthScoreCard(ctx, healthAsync.value, isDark),
                    const SizedBox(height: 20),
                    // ── Pinned Products ──
                    _pinnedProductsSection(pinnedProducts, isDark),
                    const SizedBox(height: 20),
                    // ── Stats Grid ──
                    _statsGrid(invState, ctx),
                    const SizedBox(height: 20),
                    // ── Urgent Insights ──
                    if (ctx.insights.isNotEmpty) ...[
                      _insightsSection(ctx, isDark),
                      const SizedBox(height: 20),
                    ],
                    // ── Critical Products ──
                    if (ctx.criticalProducts.isNotEmpty) ...[
                      _criticalSection(ctx, isDark),
                      const SizedBox(height: 20),
                    ],
                    // ── Expiring Products ──
                    if (ctx.expiringProducts.isNotEmpty) ...[
                      _expiringSection(context, ctx, isDark),
                      const SizedBox(height: 20),
                    ],
                    // ── Sales Chart ──
                    _salesChart(isDark),
                    const SizedBox(height: 20),
                    // ── Quick Actions ──
                    _quickActions(context, isDark, ctx),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // AppBar
  // ─────────────────────────────────────────────
  Widget _sliverAppBar(
      BuildContext context, bool isDark, InventoryState? inv) {
    final ctx = ref.watch(contextProvider);

    return SliverAppBar(
      expandedHeight: 0,
      pinned: true,
      backgroundColor:
          isDark ? AppColors.darkNavBackground : AppColors.inkBlack,
      title: Row(
        children: [
          // Logo miniatura en el AppBar
          Image.asset(
            'assets/images/logo.png',
            width: 32,
            height: 32,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('InventarIA',
                  style: AppTypography.headline.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w700)),
              Text(ctx.healthScore.label,
                  style: AppTypography.caption2.copyWith(
                      color: ctx.healthScore.color)),
            ],
          ),
        ],
      ),
      leading: IconButton(
        icon: Icon(Icons.settings_rounded,
            color: isDark ? AppColors.darkTextPrimary : Colors.white),
        onPressed: () => _showSheet(context, const SettingsScreen()),
      ),
      actions: [
        // Urgent badge if has critical issues
        if (ctx.hasUrgentAction)
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, child) => Transform.scale(
              scale: _pulse.value,
              child: child,
            ),
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF453A),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.priority_high_rounded,
                    color: Colors.white, size: 12),
                const SizedBox(width: 3),
                Text('Urgente',
                    style: AppTypography.caption2.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        // Notifications
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(Icons.notifications_rounded,
                  color: isDark ? AppColors.darkTextPrimary : Colors.white),
              onPressed: () =>
                  _showSheet(context, const NotificationsScreen()),
            ),
            if ((inv?.unreadAlertCount ?? 0) > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                      color: Color(0xFFFF453A), shape: BoxShape.circle),
                  child: Text(
                    '${(inv?.unreadAlertCount ?? 0) > 9 ? '9+' : inv?.unreadAlertCount}',
                    style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // Context Banner — dynamic greeting + status
  // ─────────────────────────────────────────────
  Widget _contextBanner(ContextState ctx, bool isDark) {
    final hasIssues = ctx.criticalProducts.isNotEmpty ||
        ctx.warningProducts.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasIssues
              ? [const Color(0xFF1C1C2E), const Color(0xFF2C1810)]
              : [AppColors.deepSpaceBlue, const Color(0xFF0A2547)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: hasIssues
            ? Border.all(
                color: const Color(0xFFFF453A).withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ctx.greetingMessage,
              style: AppTypography.title3
                  .copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(ctx.greetingSubtitle,
              style: AppTypography.callout.copyWith(color: Colors.white70)),
          if (ctx.criticalProducts.isNotEmpty) ...[
            const SizedBox(height: 14),
            _urgentBannerRow(ctx),
          ],
        ],
      ),
    );
  }

  Widget _urgentBannerRow(ContextState ctx) {
    return Row(
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, child) => Transform.scale(
            scale: _pulse.value,
            child: child,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFF453A),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_rounded, color: Colors.white, size: 13),
              const SizedBox(width: 5),
              Text(
                '${ctx.criticalProducts.length} agotado${ctx.criticalProducts.length > 1 ? 's' : ''}',
                style: AppTypography.caption.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ]),
          ),
        ),
        if (ctx.warningProducts.isNotEmpty) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9F0A).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFFFF9F0A).withValues(alpha: 0.4)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.warning_rounded,
                  color: Color(0xFFFF9F0A), size: 13),
              const SizedBox(width: 5),
              Text(
                '${ctx.warningProducts.length} stock bajo',
                style: AppTypography.caption.copyWith(
                    color: const Color(0xFFFF9F0A),
                    fontWeight: FontWeight.w600),
              ),
            ]),
          ),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────
  // Health Score Card
  // ─────────────────────────────────────────────
  Widget _healthScoreCard(
    ContextState ctx,
    InventoryHealthReport? report,
    bool isDark,
  ) {
    final h = report != null ? HealthScore.fromReport(report) : ctx.healthScore;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Circular score
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(72, 72),
                  painter: _ScorePainter(
                    score: h.score / 100,
                    color: h.color,
                    isDark: isDark,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${h.score}',
                        style: AppTypography.title2.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: h.color)),
                    Text('/ 100',
                        style: AppTypography.caption2
                            .copyWith(color: AppColors.textTertiary, fontSize: 9)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Text info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('Salud del Inventario',
                      style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: h.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(h.label,
                        style: AppTypography.caption2.copyWith(
                            color: h.color, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 8),
                // Stock health bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: h.score / 100,
                    minHeight: 6,
                    backgroundColor: isDark
                        ? AppColors.darkSurfaceSecondary
                        : AppColors.surfaceSecondary,
                    valueColor: AlwaysStoppedAnimation<Color>(h.color),
                  ),
                ),
                const SizedBox(height: 8),
                Text(h.description,
                    style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pinnedProductsSection(List<Product> pinnedProducts, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          icon: Icons.star_rounded,
          iconColor: const Color(0xFFFFC107),
          title: 'Productos fijados',
          badge: pinnedProducts.isEmpty ? null : '${pinnedProducts.length}',
          badgeColor: const Color(0xFFFFC107),
        ),
        const SizedBox(height: 12),
        if (pinnedProducts.isEmpty)
          AppCard(
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC107).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.star_border_rounded,
                      color: Color(0xFFFFC107), size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Fija un producto desde su detalle para verlo aquí y mantenerlo a mano.',
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: pinnedProducts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, index) => _pinnedProductCard(
                pinnedProducts[index],
                isDark,
              ),
            ),
          ),
      ],
    );
  }

  Widget _pinnedProductCard(Product product, bool isDark) {
    final statusColor = product.stockStatus.color;
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(product: product),
          ),
        );
      },
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFFFC107).withValues(alpha: 0.28),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: product.category.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(product.category.icon,
                      color: product.category.color, size: 18),
                ),
                const Spacer(),
                Icon(Icons.star_rounded, color: const Color(0xFFFFC107)),
              ],
            ),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            Row(
              children: [
                Icon(Icons.inventory_2_outlined, size: 12, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  '${product.quantity} uds',
                  style: AppTypography.caption2.copyWith(color: statusColor),
                ),
              ],
            ),
            Text(
              product.stockStatus.label,
              style: AppTypography.caption2.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Stats Grid — context-aware colors & trends
  // ─────────────────────────────────────────────
  Widget _statsGrid(InventoryState? inv, ContextState ctx) {
    final stats = inv?.dashboardStats;
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.45,
      children: [
        StatCard(
          title: 'Total Productos',
          value: '${stats?.totalProducts ?? 0}',
          icon: Icons.inventory_2_rounded,
          iconColor: AppColors.deepSpaceBlue,
        ),
        StatCard(
          title: 'Stock Bajo',
          value: '${stats?.lowStockCount ?? 0}',
          icon: Icons.warning_rounded,
          iconColor: (stats?.lowStockCount ?? 0) > 0
              ? AppColors.warning
              : AppColors.success,
        ),
        StatCard(
          title: 'Agotados',
          value: '${stats?.outOfStockCount ?? 0}',
          icon: Icons.cancel_rounded,
          iconColor: (stats?.outOfStockCount ?? 0) > 0
              ? AppColors.error
              : AppColors.success,
        ),
        StatCard(
          title: 'Valor en Stock',
          value: (stats?.totalStockValue ?? 0.0).compactCurrency,
          icon: Icons.monetization_on_rounded,
          iconColor: AppColors.success,
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // Insights Section
  // ─────────────────────────────────────────────
  Widget _insightsSection(ContextState ctx, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          icon: Icons.auto_awesome_rounded,
          iconColor: AppColors.teaGreen,
          title: 'Análisis en Tiempo Real',
          badge: ctx.insights
                  .where((i) => i.priority == InsightPriority.urgent)
                  .isNotEmpty
              ? 'Acción requerida'
              : null,
          badgeColor: AppColors.error,
        ),
        const SizedBox(height: 12),
        ...ctx.insights.take(3).map((insight) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _insightCard(insight, isDark),
            )),
      ],
    );
  }

  Widget _insightCard(ContextualInsight insight, bool isDark) {
    final isUrgent = insight.priority == InsightPriority.urgent;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUrgent
            ? insight.color.withValues(alpha: 0.08)
            : isDark
                ? AppColors.darkSurface
                : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUrgent
              ? insight.color.withValues(alpha: 0.25)
              : (isDark
                  ? AppColors.darkSurfaceSecondary
                  : AppColors.surfaceSecondary),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: insight.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                Icon(insight.icon, color: insight.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(insight.title,
                      style: AppTypography.callout.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary)),
                  if (isUrgent) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF453A),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('URGENTE',
                          style: AppTypography.caption2.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 9)),
                    ),
                  ],
                ]),
                const SizedBox(height: 4),
                Text(insight.body,
                    style: AppTypography.caption.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary)),
                if (insight.actionLabel != null) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _navigateInsight(insight),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(insight.actionLabel!,
                            style: AppTypography.caption.copyWith(
                                color: insight.color,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded,
                            color: insight.color, size: 13),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Critical Products — agotados
  // ─────────────────────────────────────────────
  Widget _criticalSection(ContextState ctx, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          icon: Icons.cancel_rounded,
          iconColor: const Color(0xFFFF453A),
          title: 'Productos Agotados',
          badge: '${ctx.criticalProducts.length}',
          badgeColor: const Color(0xFFFF453A),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ctx.criticalProducts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) =>
                _criticalProductChip(ctx.criticalProducts[i], isDark),
          ),
        ),
      ],
    );
  }

  Widget _criticalProductChip(dynamic product, bool isDark) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFFFF453A).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFF453A).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('AGOTADO',
                style: AppTypography.caption2.copyWith(
                    color: const Color(0xFFFF453A),
                    fontWeight: FontWeight.w800,
                    fontSize: 9)),
          ),
          Text(product.name,
              style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          Row(children: [
            Icon(Icons.inventory_2_outlined,
                size: 12, color: AppColors.textTertiary),
            const SizedBox(width: 4),
            Text('0 uds',
                style: AppTypography.caption2
                    .copyWith(color: AppColors.textTertiary)),
          ]),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Expiring Products
  // ─────────────────────────────────────────────
  Widget _expiringSection(
      BuildContext context, ContextState ctx, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _sectionHeader(
                icon: Icons.access_time_rounded,
                iconColor: const Color(0xFFFF9F0A),
                title: 'Próximos a Vencer',
                badge: '${ctx.expiringProducts.length}',
                badgeColor: const Color(0xFFFF9F0A),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LocationWalkScreen(),
                ),
              ),
              child: const Text('Ver recorrido'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.all(0),
          child: Column(
            children: ctx.expiringProducts.take(3).toList().asMap().entries.map((entry) {
              final i = entry.key;
              final product = entry.value;
              final days = product.expirationDate
                      ?.difference(DateTime.now())
                      .inDays ??
                  0;
              final isLast = i == (ctx.expiringProducts.take(3).length - 1);
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9F0A).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.access_time_rounded,
                            color: Color(0xFFFF9F0A), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(product.name,
                                  style: AppTypography.callout.copyWith(
                                      fontWeight: FontWeight.w600)),
                              Text('${product.quantity} uds en stock',
                                  style: AppTypography.caption.copyWith(
                                      color: AppColors.textSecondary)),
                            ]),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: days <= 7
                              ? const Color(0xFFFF453A).withValues(alpha: 0.1)
                              : const Color(0xFFFF9F0A).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          days == 0
                              ? 'Hoy'
                              : days == 1
                                  ? 'Mañana'
                                  : '$days días',
                          style: AppTypography.caption.copyWith(
                              color: days <= 7
                                  ? const Color(0xFFFF453A)
                                  : const Color(0xFFFF9F0A),
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ]),
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      color: isDark
                          ? AppColors.darkSurfaceSecondary
                          : AppColors.surfaceSecondary,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // Sales Chart — real data from analyticsProvider
  // ─────────────────────────────────────────────
  Widget _salesChart(bool isDark) {
    final analyticsAsync = ref.watch(analyticsProvider);
    final analytics = analyticsAsync.value;
    final salesData = analytics?.salesData ?? [];
    final isLoading = analyticsAsync.isLoading;

    final totalSales =
        salesData.fold<double>(0.0, (s, p) => s + p.sales);
    final spots = salesData.asMap().entries
        .map((e) => FlSpot(
            e.key.toDouble(), e.value.sales / 1000000))
        .toList();

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.trending_up_rounded,
                  color: AppColors.success, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ventas del Período',
                    style: AppTypography.callout
                        .copyWith(fontWeight: FontWeight.w600)),
                Text(
                  salesData.isEmpty
                      ? 'Sin datos'
                      : totalSales.compactCurrency,
                  style: AppTypography.caption.copyWith(
                      color: salesData.isEmpty
                          ? AppColors.textTertiary
                          : AppColors.success),
                ),
              ],
            ),
            const Spacer(),
            if (isLoading)
              const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.freshSky)),
          ]),
          const SizedBox(height: 16),
          if (salesData.isEmpty)
            Container(
              height: 100,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bar_chart_rounded,
                      color: AppColors.textTertiary, size: 32),
                  const SizedBox(height: 8),
                  Text('Sin datos de ventas aún',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textTertiary)),
                ],
              ),
            )
          else
            SizedBox(
              height: 140,
              child: LineChart(LineChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < salesData.length) {
                          return Text(
                              salesData[i].date.dayOfWeek,
                              style: AppTypography.caption2.copyWith(
                                  color: AppColors.textTertiary,
                                  fontSize: 10));
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.freshSky,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.freshSky.withValues(alpha: 0.25),
                          AppColors.freshSky.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              )),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Quick Actions — context-aware priorities
  // ─────────────────────────────────────────────
  Widget _quickActions(
      BuildContext context, bool isDark, ContextState ctx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          icon: Icons.bolt_rounded,
          iconColor: AppColors.teaGreen,
          title: 'Acciones Rápidas',
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.2,
          children: [
            // Restock — highlight if there are critical/warning products
            _actionTile(
              icon: Icons.refresh_rounded,
              title: 'Reabastecer',
              subtitle: ctx.criticalProducts.isNotEmpty
                  ? '${ctx.criticalProducts.length} urgente${ctx.criticalProducts.length > 1 ? 's' : ''}'
                  : 'Gestionar stock',
              color: ctx.criticalProducts.isNotEmpty
                  ? const Color(0xFFFF453A)
                  : AppColors.deepSpaceBlue,
              urgent: ctx.criticalProducts.isNotEmpty,
              isDark: isDark,
              onTap: () => _showSheet(context, const RestockScreen()),
            ),
            _actionTile(
              icon: Icons.add_circle_rounded,
              title: 'Nuevo Producto',
              subtitle: 'Agregar al inventario',
              color: AppColors.teaGreen,
              isDark: isDark,
              onTap: () => _showSheet(context, const AddProductScreen()),
            ),
            _actionTile(
              icon: Icons.inventory_2_rounded,
              title: 'Ver Inventario',
              subtitle: 'Todos los productos',
              color: AppColors.freshSky,
              isDark: isDark,
              onTap: () => _showSheet(context, const ProductsScreen()),
            ),
            _actionTile(
              icon: Icons.map_rounded,
              title: 'Recorrido por ubicación',
              subtitle: 'Marca pasillos revisados',
              color: AppColors.freshSky,
              isDark: isDark,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LocationWalkScreen(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
    bool urgent = false,
  }) {
    return GestureDetector(
      onTap: () {
        onTap();
        HapticManager.impact();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: urgent
              ? color.withValues(alpha: 0.08)
              : isDark
                  ? AppColors.darkSurface
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: urgent
                ? color.withValues(alpha: 0.3)
                : isDark
                    ? AppColors.darkSurfaceSecondary
                    : AppColors.surfaceSecondary,
          ),
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title,
                    style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary),
                    maxLines: 1),
                Text(subtitle,
                    style: AppTypography.caption2.copyWith(
                        color: urgent ? color : AppColors.textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (urgent)
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) =>
                  Transform.scale(scale: _pulse.value, child: child),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: color, shape: BoxShape.circle),
              ),
            ),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────
  Widget _sectionHeader({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? badge,
    Color? badgeColor,
  }) {
    return Row(children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 15),
      ),
      const SizedBox(width: 8),
      Text(title, style: AppTypography.headline),
      if (badge != null) ...[
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: (badgeColor ?? iconColor).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(badge,
              style: AppTypography.caption2.copyWith(
                  color: badgeColor ?? iconColor,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    ]);
  }

  void _navigateInsight(ContextualInsight insight) {
    HapticManager.impact();
    switch (insight.actionRoute) {
      case 'restock':
        _showSheet(context, const RestockScreen());
      case 'products':
        _showSheet(context, const ProductsScreen());
      default:
        _showSheet(context, const NotificationsScreen());
    }
  }

  void _showSheet(BuildContext context, Widget child) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.95,
        maxChildSize: 0.95,
        builder: (_, __) => ClipRRect(
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Score ring painter
// ─────────────────────────────────────────────
class _ScorePainter extends CustomPainter {
  final double score;
  final Color color;
  final bool isDark;

  const _ScorePainter(
      {required this.score, required this.color, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) - 5;

    // Background ring
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = isDark
            ? AppColors.darkSurfaceSecondary
            : AppColors.surfaceSecondary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7,
    );

    // Score arc
    final rect =
        Rect.fromCircle(center: Offset(cx, cy), radius: r);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * score,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ScorePainter old) =>
      old.score != score || old.color != color;
}
