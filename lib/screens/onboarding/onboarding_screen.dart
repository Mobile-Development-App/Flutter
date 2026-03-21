import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../../providers/providers.dart';

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String description;
  final Color accentColor;
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.accentColor,
  });
}

const _pages = [
  _OnboardingPage(
    icon: Icons.camera_enhance_rounded,
    title: 'Escaneo con IA',
    description:
        'Escanea tus productos con la cámara y nuestra IA los reconocerá automáticamente, ahorrándote tiempo en el registro.',
    accentColor: AppColors.teaGreen,
  ),
  _OnboardingPage(
    icon: Icons.notifications_active_rounded,
    title: 'Alertas Inteligentes',
    description:
        'Recibe notificaciones cuando tus productos estén por agotarse, próximos a vencer o cuando sea momento de reabastecer.',
    accentColor: AppColors.warning,
  ),
  _OnboardingPage(
    icon: Icons.bar_chart_rounded,
    title: 'Analítica en Tiempo Real',
    description:
        'Visualiza el rendimiento de tu inventario con gráficas que te ayudan a tomar mejores decisiones de negocio.',
    accentColor: AppColors.freshSky,
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _pageController = PageController();
  late AnimationController _animCtrl;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _complete() => ref.read(authProvider.notifier).completeOnboarding();

  void _next() {
    HapticManager.impact();
    if (_current < _pages.length - 1) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut);
    } else {
      _complete();
    }
  }

  void _back() {
    HapticManager.impact();
    _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    // Always use brand dark aesthetic for onboarding
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Step counter
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.darkSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0x1AFFFFFF), width: 0.5),
                    ),
                    child: Text(
                      '${_current + 1} / ${_pages.length}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.darkTextSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _complete,
                    child: Text(
                      'Omitir',
                      style: AppTypography.callout.copyWith(
                          color: AppColors.darkTextSecondary),
                    ),
                  ),
                ],
              ),
            ),

            // ── Pages ─────────────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _current = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _pageView(_pages[i]),
              ),
            ),

            // ── Progress dots ─────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _current ? 28 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _current
                        ? _pages[_current].accentColor
                        : AppColors.darkBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 36),

            // ── Navigation buttons ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  if (_current > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _back,
                        style: secondaryButtonStyle,
                        child: const Text('Atrás'),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _next,
                      style: primaryButtonStyle,
                      child: Text(
                        _current < _pages.length - 1 ? 'Siguiente' : 'Comenzar',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _pageView(_OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with layered glow effect
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: page.accentColor.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: page.accentColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: page.accentColor.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: page.accentColor.withValues(alpha: 0.3),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
              Icon(page.icon, size: 52, color: page.accentColor),
            ],
          ),
          const SizedBox(height: 44),
          Text(
            page.title,
            style: AppTypography.title.copyWith(
              color: AppColors.darkTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            page.description,
            style: AppTypography.body.copyWith(
              color: AppColors.darkTextSecondary,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
