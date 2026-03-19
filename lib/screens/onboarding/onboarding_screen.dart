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
  final Color color;
  const _OnboardingPage(
      {required this.icon,
      required this.title,
      required this.description,
      required this.color});
}

const _pages = [
  _OnboardingPage(
    icon: Icons.camera_enhance_rounded,
    title: 'Escaneo con IA',
    description:
        'Escanea tus productos con la cámara y nuestra IA los reconocerá automáticamente, ahorrándote tiempo en el registro de inventario.',
    color: AppColors.deepSpaceBlue,
  ),
  _OnboardingPage(
    icon: Icons.notifications_active_rounded,
    title: 'Alertas Inteligentes',
    description:
        'Recibe notificaciones cuando tus productos estén por agotarse, próximos a vencer o cuando sea momento de reabastecer.',
    color: AppColors.warning,
  ),
  _OnboardingPage(
    icon: Icons.bar_chart_rounded,
    title: 'Analítica en Tiempo Real',
    description:
        'Visualiza el rendimiento de tu inventario con gráficos y estadísticas que te ayudan a tomar mejores decisiones de negocio.',
    color: AppColors.teaGreen,
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() =>
      _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _current = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _complete() =>
      ref.read(authProvider.notifier).completeOnboarding();

  void _next() {
    HapticManager.impact();
    if (_current < _pages.length - 1) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut);
    } else {
      _complete();
    }
  }

  void _back() {
    HapticManager.impact();
    _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Skip
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _complete,
                child: Text('Omitir',
                    style: AppTypography.callout
                        .copyWith(color: AppColors.textSecondary)),
              ),
            ),
            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _current = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _pageView(_pages[i]),
              ),
            ),
            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _current ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _current
                        ? AppColors.deepSpaceBlue
                        : AppColors.textTertiary
                            .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Buttons
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
                      child: Text(_current < _pages.length - 1
                          ? 'Siguiente'
                          : 'Comenzar'),
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
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: page.color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: page.color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
              ),
              Icon(page.icon, size: 56, color: page.color),
            ],
          ),
          const SizedBox(height: 40),
          Text(page.title,
              style: AppTypography.title,
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(
            page.description,
            style: AppTypography.body
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
