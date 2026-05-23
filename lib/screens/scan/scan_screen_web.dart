import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../../core/utils/screen_tracker_mixin.dart';
import '../../providers/providers.dart';
import 'scan_screen.dart';

// ─────────────────────────────────────────────
// ScanScreenWeb
// Chrome no soporta el paquete camera de Flutter.
// En web: el usuario ingresa el código manualmente
// o lo escanea con un lector físico de barras (USB/BT)
// que funciona como teclado.
// ─────────────────────────────────────────────
class ScanScreenWeb extends ConsumerStatefulWidget {
  const ScanScreenWeb({super.key});

  @override
  ConsumerState<ScanScreenWeb> createState() => _ScanScreenWebState();
}

class _ScanScreenWebState extends ConsumerState<ScanScreenWeb>
    with ScreenTrackerMixin {
  @override
  String get trackedScreenName => 'scan';

  final _barcodeCtrl = TextEditingController();
  final _focusNode = FocusNode();
  ScanState _state = ScanState.ready;
  ScanResult? _result;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    // Auto-focus so USB barcode readers work immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final barcode = _barcodeCtrl.text.trim();
    if (barcode.isEmpty) return;

    setState(() {
      _state = ScanState.analyzing;
      _errorMsg = null;
    });

    await HapticManager.impact();

    // 1. Search in local inventory
    final existing =
        ref.read(inventoryProvider.notifier).findProductByBarcode(barcode);

    if (existing != null) {
      await recordScanSession(
        barcode: barcode,
        foundInInventory: true,
        productName: existing.name,
        productId: existing.id,
      );
      ref.invalidate(quickScanHistoryProvider);
      setState(() {
        _result = ScanResult(
          barcode: barcode,
          existingProduct: existing,
          openFoodData: null,
        );
        _state = ScanState.found;
      });
      return;
    }

    // 2. Open Food Facts lookup
    final foodData = await OpenFoodFactsService.lookup(barcode);
    await recordScanSession(
      barcode: barcode,
      foundInInventory: false,
      productName: foodData?['name'] as String?,
      brand: foodData?['brand'] as String?,
    );
    ref.invalidate(quickScanHistoryProvider);

    setState(() {
      _result = ScanResult(
        barcode: barcode,
        existingProduct: null,
        openFoodData: foodData,
      );
      _state = ScanState.notFound;
    });
  }

  void _reset() {
    _barcodeCtrl.clear();
    setState(() {
      _state = ScanState.ready;
      _result = null;
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0A0F1E), Color(0xFF050A12)],
              ),
            ),
          ),
          // Grid overlay
          Opacity(
            opacity: 0.04,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8),
              itemBuilder: (_, __) => Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 0.3),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _topBar(),
                const Spacer(),
                _body(),
                const Spacer(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          ScanUI.glassButton(
            icon: Icons.close_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const Spacer(),
          Text('Buscar Producto',
              style: AppTypography.headline
                  .copyWith(color: Colors.white)),
          const Spacer(),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_state) {
      case ScanState.ready:
      case ScanState.error:
        return _inputView();
      case ScanState.initializing:
      case ScanState.analyzing:
        return _loadingView();
      case ScanState.found:
        return ScanUI.foundCard(context, _result!, _reset);
      case ScanState.notFound:
        return ScanUI.notFoundCard(context, _result!, _reset);
    }
  }

  Widget _inputView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.teaGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.teaGreen.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.qr_code_scanner_rounded,
                color: AppColors.teaGreen, size: 36),
          ),
          const SizedBox(height: 24),
          Text(
            'Ingresa el código de barras',
            style: AppTypography.title.copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Escríbelo manualmente o usa un lector de\ncódigos de barras conectado al computador',
            style: AppTypography.callout
                .copyWith(color: Colors.white54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Input field
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.teaGreen.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: Icon(Icons.barcode_reader,
                      color: AppColors.teaGreen, size: 22),
                ),
                Expanded(
                  child: TextField(
                    controller: _barcodeCtrl,
                    focusNode: _focusNode,
                    style: AppTypography.headline
                        .copyWith(color: Colors.white),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: 'Ej: 7701234567890',
                      hintStyle: AppTypography.callout
                          .copyWith(color: Colors.white30),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 16),
                    ),
                  ),
                ),
                // Clear
                if (_barcodeCtrl.text.isNotEmpty)
                  IconButton(
                    onPressed: () {
                      _barcodeCtrl.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.clear_rounded,
                        color: Colors.white38, size: 18),
                  ),
              ],
            ),
          ),

          if (_errorMsg != null) ...[
            const SizedBox(height: 8),
            Text(_errorMsg!,
                style: AppTypography.caption
                    .copyWith(color: AppColors.error)),
          ],

          const SizedBox(height: 16),

          // Search button
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _barcodeCtrl.text.isNotEmpty ? _search : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: _barcodeCtrl.text.isNotEmpty
                      ? AppColors.teaGreen
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: _barcodeCtrl.text.isNotEmpty
                          ? AppColors.inkBlack
                          : Colors.white30,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Buscar producto',
                      style: AppTypography.headline.copyWith(
                        color: _barcodeCtrl.text.isNotEmpty
                            ? AppColors.inkBlack
                            : Colors.white30,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Info tip
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: Colors.white38, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Para escanear con cámara, usa la app móvil en Android o iOS',
                    style: AppTypography.caption
                        .copyWith(color: Colors.white38),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingView() {
    return ScanUI.glassCard(
      child: Column(children: [
        const CircularProgressIndicator(
            color: AppColors.teaGreen, strokeWidth: 3),
        const SizedBox(height: 16),
        Text('Buscando producto...',
            style: AppTypography.headline
                .copyWith(color: Colors.white)),
        const SizedBox(height: 4),
        Text('Consultando inventario y base de datos',
            style:
                AppTypography.caption.copyWith(color: Colors.white60),
            textAlign: TextAlign.center),
      ]),
    );
  }
}
