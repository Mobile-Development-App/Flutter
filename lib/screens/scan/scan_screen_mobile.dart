import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:camera/camera.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../../core/utils/screen_tracker_mixin.dart';
import '../../providers/providers.dart';
import 'scan_screen.dart';

// ─────────────────────────────────────────────
// ScanScreenMobile — real camera + ML Kit
// Only used on Android & iOS
// ─────────────────────────────────────────────
class ScanScreenMobile extends ConsumerStatefulWidget {
  const ScanScreenMobile({super.key});

  @override
  ConsumerState<ScanScreenMobile> createState() =>
      _ScanScreenMobileState();
}

class _ScanScreenMobileState extends ConsumerState<ScanScreenMobile>
    with WidgetsBindingObserver, ScreenTrackerMixin {
  @override
  String get trackedScreenName => 'scan';

  CameraController? _camera;
  BarcodeScanner? _scanner;
  bool _isProcessing = false;
  bool _torchOn = false;
  ScanState _state = ScanState.initializing;
  String? _errorMsg;
  String? _lastBarcode;
  ScanResult? _result;
  DateTime _lastProcess = DateTime(2000);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scanner = BarcodeScanner(formats: [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.qrCode,
      BarcodeFormat.upca,
      BarcodeFormat.upce,
    ]);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    _scanner?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_camera == null) return;
    if (state == AppLifecycleState.inactive) {
      _camera?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _state = ScanState.error;
          _errorMsg = 'No se encontró cámara en este dispositivo';
        });
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final ctrl = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await ctrl.initialize();
      if (!mounted) return;
      _camera = ctrl;
      setState(() => _state = ScanState.ready);
      await ctrl.startImageStream(_onCameraImage);
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = ScanState.error;
          _errorMsg = 'Error al iniciar la cámara: $e';
        });
      }
    }
  }

  void _onCameraImage(CameraImage image) async {
    if (_isProcessing || _state != ScanState.ready) return;
    final now = DateTime.now();
    if (now.difference(_lastProcess).inMilliseconds < 500) return;
    _lastProcess = now;
    _isProcessing = true;

    try {
      final camera = _camera;
      if (camera == null) return;
      final inputImage = _buildInputImage(image, camera);
      if (inputImage == null) return;
      final barcodes = await _scanner!.processImage(inputImage);
      if (barcodes.isEmpty) return;
      final barcode = barcodes.first.rawValue;
      if (barcode == null || barcode.isEmpty) return;
      if (barcode == _lastBarcode) return;
      _lastBarcode = barcode;
      await camera.stopImageStream();
      await HapticManager.success();
      if (mounted) {
        setState(() => _state = ScanState.analyzing);
        await _processBarcode(barcode);
      }
    } catch (_) {
    } finally {
      _isProcessing = false;
    }
  }

  InputImage? _buildInputImage(
      CameraImage image, CameraController controller) {
    try {
      final rotation = InputImageRotationValue.fromRawValue(
            controller.description.sensorOrientation,
          ) ??
          InputImageRotation.rotation0deg;
      final format =
          InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;
      return InputImage.fromBytes(
        bytes: image.planes[0].bytes,
        metadata: InputImageMetadata(
          size:
              Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _processBarcode(String barcode) async {
    final existing = ref
        .read(inventoryProvider.notifier)
        .findProductByBarcode(barcode);

    if (existing != null) {
      await recordScanSession(
        barcode: barcode,
        foundInInventory: true,
        productName: existing.name,
        productId: existing.id,
      );
      ref.invalidate(quickScanHistoryProvider);
      if (mounted) {
        setState(() {
          _result = ScanResult(
              barcode: barcode,
              existingProduct: existing,
              openFoodData: null);
          _state = ScanState.found;
        });
      }
      return;
    }

    final foodData = await OpenFoodFactsService.lookup(barcode);
    await recordScanSession(
      barcode: barcode,
      foundInInventory: false,
      productName: foodData?['name'] as String?,
      brand: foodData?['brand'] as String?,
    );
    ref.invalidate(quickScanHistoryProvider);
    if (mounted) {
      setState(() {
        _result = ScanResult(
            barcode: barcode,
            existingProduct: null,
            openFoodData: foodData);
        _state = ScanState.notFound;
      });
    }
  }

  void _resetScan() {
    setState(() {
      _state = ScanState.ready;
      _result = null;
      _lastBarcode = null;
    });
    _camera?.startImageStream(_onCameraImage);
  }

  Future<void> _toggleTorch() async {
    try {
      _torchOn = !_torchOn;
      await _camera?.setFlashMode(
          _torchOn ? FlashMode.torch : FlashMode.off);
      setState(() {});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_camera != null && _camera!.value.isInitialized)
            Positioned.fill(child: CameraPreview(_camera!))
          else
            Container(color: const Color(0xFF0A0A0A)),
          if (_state == ScanState.ready)
            Positioned.fill(child: _ScanOverlayPainterWidget()),
          SafeArea(
            child: Column(
              children: [
                _topBar(),
                const Spacer(),
                _body(),
                const Spacer(),
                if (_state == ScanState.ready)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Text(
                      'Apunta la cámara al código de barras',
                      style: AppTypography.caption
                          .copyWith(color: Colors.white60),
                    ),
                  )
                else
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
          Text('Escanear Producto',
              style: AppTypography.headline
                  .copyWith(color: Colors.white)),
          const Spacer(),
          ScanUI.glassButton(
            icon: _torchOn
                ? Icons.flashlight_off_rounded
                : Icons.flashlight_on_rounded,
            onTap: _toggleTorch,
          ),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_state) {
      case ScanState.initializing:
        return ScanUI.glassCard(
          child: Column(children: [
            const CircularProgressIndicator(
                color: AppColors.teaGreen, strokeWidth: 3),
            const SizedBox(height: 16),
            Text('Iniciando cámara...',
                style: AppTypography.callout
                    .copyWith(color: Colors.white)),
          ]),
        );
      case ScanState.error:
        return ScanUI.glassCard(
          child: Column(children: [
            const Icon(Icons.camera_alt_rounded,
                color: AppColors.error, size: 40),
            const SizedBox(height: 12),
            Text(_errorMsg ?? 'Error de cámara',
                style: AppTypography.callout
                    .copyWith(color: Colors.white),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ScanUI.actionButton(
              label: 'Reintentar',
              icon: Icons.refresh_rounded,
              color: AppColors.teaGreen,
              textColor: AppColors.inkBlack,
              onTap: _initCamera,
            ),
          ]),
        );
      case ScanState.ready:
        return _cornersWidget();
      case ScanState.analyzing:
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
                style: AppTypography.caption
                    .copyWith(color: Colors.white60),
                textAlign: TextAlign.center),
          ]),
        );
      case ScanState.found:
        return ScanUI.foundCard(context, _result!, _resetScan);
      case ScanState.notFound:
        return ScanUI.notFoundCard(context, _result!, _resetScan);
    }
  }

  Widget _cornersWidget() {
    const size = 24.0;
    const stroke = 3.0;
    const color = AppColors.teaGreen;
    // El rect de overlay mide 260×260 px. Cada corner widget mide 24×24 px.
    // Con alignment: center, el origen del widget está en center - 12 = 118 px
    // del borde → el offset correcto es ±118 para que el trazo quede exacto.
    final positions = [
      [-118.0, -118.0, true, true],
      [118.0, -118.0, false, true],
      [-118.0, 118.0, true, false],
      [118.0, 118.0, false, false],
    ];
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: positions.map((p) {
          return Transform.translate(
            offset: Offset(p[0] as double, p[1] as double),
            child: SizedBox(
              width: size,
              height: size,
              child: CustomPaint(
                painter: _CornerPainter(
                  left: p[2] as bool,
                  top: p[3] as bool,
                  color: color,
                  stroke: stroke,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ScanOverlayPainterWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ScanOverlayPainter());
  }
}

class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const windowSize = 260.0;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: windowSize,
        height: windowSize);
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.zero))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
    canvas.drawRect(
      rect,
      Paint()
        ..color = AppColors.teaGreen.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_ScanOverlayPainter old) => false;
}

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
