import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../../models/product.dart';
import '../../providers/providers.dart';
import '../../providers/inventory_provider.dart';
import '../products/add_product_screen.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen>
    with TickerProviderStateMixin {
  _ScanState _scanState = _ScanState.ready;
  ScannedProductResult? _detected;
  late AnimationController _lineCtrl;
  late Animation<double> _lineAnim;

  @override
  void initState() {
    super.initState();
    _lineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _lineAnim = Tween<double>(begin: -100, end: 100)
        .animate(CurvedAnimation(
            parent: _lineCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _lineCtrl.dispose();
    super.dispose();
  }

  void _startScan() {
    HapticManager.impact();
    setState(() => _scanState = _ScanState.scanning);
    _lineCtrl.repeat(reverse: true);

    // Simulate AI analysis after 3s
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted || _scanState != _ScanState.scanning) {
        return;
      }
      setState(() => _scanState = _ScanState.analyzing);
      _lineCtrl.stop();
      _analyzeWithAI();
    });
  }

  Future<void> _analyzeWithAI({String? barcode}) async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final duplicates =
        ref.read(inventoryProvider.notifier).findDuplicates('Producto Demo', barcode ?? '');

    final result = ScannedProductResult(
      name: 'Producto Detectado',
      brand: 'Sin marca',
      category: ProductCategory.other,
      barcode: barcode ?? '7701234567890',
      suggestedPrice: 5000,
      confidence: 85,
      isDuplicate: duplicates.isNotEmpty,
      similarProducts: duplicates,
    );

    if (mounted) {
      setState(() {
        _detected = result;
        _scanState = _ScanState.complete;
      });
      await HapticManager.success();
    }
  }

  void _resetScan() {
    HapticManager.impact();
    setState(() {
      _scanState = _ScanState.ready;
      _detected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera placeholder (dark background)
          Container(color: const Color(0xFF0A0A0A)),
          // Camera grid overlay
          Opacity(
            opacity: 0.08,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8),
              itemBuilder: (_, __) => Container(
                decoration: BoxDecoration(
                  border:
                      Border.all(color: Colors.white, width: 0.3),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _topBar(),
                const Spacer(),
                if (_scanState == _ScanState.ready ||
                    _scanState == _ScanState.scanning)
                  _scanningView(),
                if (_scanState == _ScanState.analyzing)
                  _analyzingView(),
                if (_scanState == _ScanState.complete &&
                    _detected != null)
                  _resultView(),
                const Spacer(),
                if (_scanState == _ScanState.ready)
                  _featureCards(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          _glassButton(
            icon: Icons.close_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const Spacer(),
          Text('Escaneo IA',
              style: AppTypography.headline
                  .copyWith(color: Colors.white)),
          const Spacer(),
          _glassButton(
            icon: Icons.flashlight_on_rounded,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _glassButton(
      {required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _scanningView() {
    return Column(
      children: [
        SizedBox(
          width: 260,
          height: 260,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Corner decorations
              ..._corners(),
              // Scan line
              if (_scanState == _ScanState.scanning)
                AnimatedBuilder(
                  animation: _lineAnim,
                  builder: (_, __) => Transform.translate(
                    offset: Offset(0, _lineAnim.value),
                    child: Container(
                      width: 240,
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.teaGreen
                                .withValues(alpha: 0),
                            AppColors.teaGreen,
                            AppColors.teaGreen
                                .withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _scanState == _ScanState.scanning
              ? 'Escaneando...'
              : 'Apunta la cámara al producto',
          style: AppTypography.callout
              .copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 24),
        if (_scanState == _ScanState.ready)
          GestureDetector(
            onTap: _startScan,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.teaGreen,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color:
                        AppColors.teaGreen.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.camera_enhance_rounded,
                      color: AppColors.inkBlack, size: 20),
                  const SizedBox(width: 8),
                  Text('Escanear Producto',
                      style: AppTypography.headline.copyWith(
                          color: AppColors.inkBlack)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _corners() {
    const size = 24.0;
    const stroke = 3.0;
    const color = AppColors.teaGreen;
    final positions = [
      [-115.0, -115.0, true, true],
      [115.0, -115.0, false, true],
      [-115.0, 115.0, true, false],
      [115.0, 115.0, false, false],
    ];
    return positions.map((p) {
      final x = p[0] as double;
      final y = p[1] as double;
      final left = p[2] as bool;
      final top = p[3] as bool;
      return Transform.translate(
        offset: Offset(x, y),
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _CornerPainter(
                left: left, top: top, color: color, stroke: stroke),
          ),
        ),
      );
    }).toList();
  }

  Widget _analyzingView() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(
            color: AppColors.teaGreen,
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          Text('Analizando con IA...',
              style: AppTypography.headline
                  .copyWith(color: Colors.white)),
          const SizedBox(height: 4),
          Text('Identificando producto y buscando información',
              style: AppTypography.caption
                  .copyWith(color: Colors.white60),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _resultView() {
    final r = _detected!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Confidence badge
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.teaGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    color: AppColors.teaGreen, size: 14),
                const SizedBox(width: 6),
                Text(
                    'Confianza: ${r.confidence.toStringAsFixed(0)}%',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.teaGreen)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Result card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _infoRow('Nombre', r.name),
                _infoRow('Marca', r.brand),
                _infoRow('Categoría', r.category.label),
                if (r.barcode.isNotEmpty)
                  _infoRow('Código', r.barcode),
                if (r.suggestedPrice > 0)
                  _infoRow('Precio Sugerido',
                      r.suggestedPrice.currencyFormatted),
                if (r.isDuplicate) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_rounded,
                            color: AppColors.warning, size: 16),
                        const SizedBox(width: 8),
                        Text('Posible duplicado detectado',
                            style: AppTypography.caption
                                .copyWith(
                                    color: AppColors.warning)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showAddProduct(context),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.teaGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_circle_rounded,
                            color: AppColors.inkBlack, size: 18),
                        const SizedBox(width: 6),
                        Text('Agregar',
                            style: AppTypography.callout
                                .copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.inkBlack)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _resetScan,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color:
                          Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        const Icon(
                            Icons.replay_rounded,
                            color: Colors.white,
                            size: 18),
                        const SizedBox(width: 6),
                        Text('Nuevo',
                            style: AppTypography.callout
                                .copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label,
              style: AppTypography.caption
                  .copyWith(color: Colors.white60)),
          const Spacer(),
          Text(value,
              style: AppTypography.callout.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Colors.white)),
        ],
      ),
    );
  }

  Widget _featureCards() {
    final features = [
      ['Código de Barras', Icons.barcode_reader,
          'Escanea códigos estándar'],
      ['Reconocimiento Visual', Icons.image_search_rounded,
          'Identifica por apariencia'],
      ['Texto en Etiquetas', Icons.text_fields_rounded,
          'Lee info de etiquetas'],
    ];
    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: features.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final f = features[i];
          return Container(
            width: 150,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(f[1] as IconData,
                    size: 24, color: AppColors.teaGreen),
                const SizedBox(height: 8),
                Text(f[0] as String,
                    style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                const SizedBox(height: 2),
                Text(f[2] as String,
                    style: AppTypography.caption2
                        .copyWith(color: Colors.white60),
                    maxLines: 2),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddProduct(BuildContext context) {
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
          child: AddProductScreen(fromScan: _detected),
        ),
      ),
    );
  }
}

enum _ScanState { ready, scanning, analyzing, complete }

class _CornerPainter extends CustomPainter {
  final bool left, top;
  final Color color;
  final double stroke;
  const _CornerPainter(
      {required this.left,
      required this.top,
      required this.color,
      required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    if (left && top) {
      path
        ..moveTo(0, size.height)
        ..lineTo(0, 0)
        ..lineTo(size.width, 0);
    } else if (!left && top) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height);
    } else if (left && !top) {
      path
        ..moveTo(0, 0)
        ..lineTo(0, size.height)
        ..lineTo(size.width, size.height);
    } else {
      path
        ..moveTo(0, size.height)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width, 0);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}
