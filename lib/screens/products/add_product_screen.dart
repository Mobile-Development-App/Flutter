import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/extensions.dart';
import '../../core/utils/validators.dart';
import '../../services/api_service.dart';
import '../../models/product.dart';
import '../../providers/providers.dart';
import '../../widgets/app_card.dart';
import '../../services/usage_tracking_service.dart';

/// Formatter que permite solo dígitos enteros (sin decimales).
final _integerOnlyFormatter = FilteringTextInputFormatter.allow(
  RegExp(r'[0-9]'),
);

/// Formatter que permite dígitos y un punto decimal (para precios).
class _DecimalInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    // Permite vacío
    if (text.isEmpty) return newValue;
    // Solo dígitos y un punto decimal
    if (!RegExp(r'^\d*\.?\d{0,2}$').hasMatch(text)) return oldValue;
    return newValue;
  }
}

class AddProductScreen extends ConsumerStatefulWidget {
  final Product? editingProduct;
  final ScannedProductResult? fromScan;

  const AddProductScreen({super.key, this.editingProduct, this.fromScan});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _nameCtrl     = TextEditingController();
  final _skuCtrl      = TextEditingController();
  final _barcodeCtrl  = TextEditingController();
  final _supplierCtrl = TextEditingController();
  final _costCtrl     = TextEditingController();
  final _saleCtrl     = TextEditingController();
  final _qtyCtrl      = TextEditingController();
  final _minStockCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _descCtrl     = TextEditingController();
  final _imageUrlCtrl = TextEditingController();

  ProductCategory _category    = ProductCategory.other;
  DateTime? _expirationDate;
  bool _hasExpiration = false;
  bool _showSuccess   = false;
  bool _imageError    = false;

  bool get _isEditing => widget.editingProduct != null;

  // ── Validaciones de campos numéricos ──────────

  /// Precio de costo: número positivo (> 0).
  bool get _costValid     => AppValidators.isPositivePrice(_costCtrl.text);
  /// Precio de venta: número positivo (> 0).
  bool get _saleValid     => AppValidators.isPositivePrice(_saleCtrl.text);
  /// Cantidad: entero estrictamente positivo (> 0).
  bool get _qtyValid      => AppValidators.isPositiveInteger(_qtyCtrl.text);
  /// Stock mínimo: entero no-negativo (>= 0).
  bool get _minStockValid => AppValidators.isNonNegativeInteger(_minStockCtrl.text);

  double get _calculatedMargin {
    final cost = double.tryParse(_costCtrl.text) ?? 0;
    final sale = double.tryParse(_saleCtrl.text) ?? 0;
    if (cost <= 0) return 0;
    return ((sale - cost) / cost) * 100;
  }

  Color get _marginColor {
    if (_calculatedMargin >= 20) return AppColors.success;
    if (_calculatedMargin >= 10) return AppColors.warning;
    return AppColors.error;
  }

  bool get _isFormValid =>
      _nameCtrl.text.isNotEmpty &&
      _skuCtrl.text.isNotEmpty &&
      _costValid &&
      _saleValid &&
      _qtyValid &&
      _minStockValid;

  String? get _imageUrl {
    final url = _imageUrlCtrl.text.trim();
    return url.isEmpty ? null : url;
  }

  @override
  void initState() {
    super.initState();
    if (widget.editingProduct != null) {
      _populate(widget.editingProduct!);
    } else if (widget.fromScan != null) {
      _populateFromScan(widget.fromScan!);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _skuCtrl, _barcodeCtrl, _supplierCtrl,
      _costCtrl, _saleCtrl, _qtyCtrl, _minStockCtrl,
      _locationCtrl, _descCtrl, _imageUrlCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _populate(Product p) {
    _nameCtrl.text      = p.name;
    _skuCtrl.text       = p.sku;
    _barcodeCtrl.text   = p.barcode;
    _supplierCtrl.text  = p.supplier;
    _costCtrl.text      = p.costPrice.toStringAsFixed(2);
    _saleCtrl.text      = p.salePrice.toStringAsFixed(2);
    _qtyCtrl.text       = '${p.quantity}';
    _minStockCtrl.text  = '${p.minStock}';
    _locationCtrl.text  = p.location;
    _descCtrl.text      = p.description;
    _imageUrlCtrl.text  = p.imageURL ?? '';
    _category           = p.category;
    if (p.expirationDate != null) {
      _hasExpiration  = true;
      _expirationDate = p.expirationDate;
    }
  }

  void _populateFromScan(ScannedProductResult scan) {
    _nameCtrl.text   = scan.name;
    _barcodeCtrl.text = scan.barcode;
    _category        = scan.category;
    _saleCtrl.text   = scan.suggestedPrice.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Producto' : 'Agregar Producto'),
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancelar',
            style: AppTypography.callout.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        leadingWidth: 90,
      ),
      body: _showSuccess ? _successView() : _formView(isDark),
    );
  }

  Widget _successView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 64,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _isEditing ? 'Producto Actualizado' : 'Producto Agregado',
              style: AppTypography.title,
            ),
            const SizedBox(height: 8),
            Text(
              _isEditing
                  ? '${_nameCtrl.text} se ha actualizado correctamente'
                  : '${_nameCtrl.text} se ha agregado al inventario',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 200,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: primaryButtonStyle,
                child: const Text('Continuar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formView(bool isDark) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (widget.fromScan != null) _aiBanner(),
          const SizedBox(height: 8),

          _imageSection(isDark),
          const SizedBox(height: 16),

          _section(
            title: 'Información Básica',
            icon: Icons.info_outline_rounded,
            children: [
              _field('Nombre del producto', _nameCtrl, 'Ej: Leche Entera 1L', isDark, isRequired: true),
              _field('SKU', _skuCtrl, 'Ej: DAI-001', isDark, isRequired: true),
              _field(
                'Código de barras',
                _barcodeCtrl,
                'Ej: 7701234567890',
                isDark,
                keyboardType: TextInputType.number,
                inputFormatters: [_integerOnlyFormatter],
              ),
              _categoryPicker(isDark),
              _field('Proveedor', _supplierCtrl, 'Ej: Lácteos Alpina', isDark),
            ],
          ),
          const SizedBox(height: 16),

          // ── Precios ──────────────────────────────
          _section(
            title: 'Precios',
            icon: Icons.monetization_on_outlined,
            children: [
              // Regla informativa visible
              _numericRulesBanner(
                icon: Icons.info_outline_rounded,
                message:
                    'Solo se permiten valores numéricos positivos (mayores a 0). '
                    'Se aceptan hasta 2 decimales separados por punto (ej: 1500.50).',
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _field(
                      'Precio de costo',
                      _costCtrl,
                      'Ej: 800.00',
                      isDark,
                      isRequired: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [_DecimalInputFormatter()],
                      errorText: _costCtrl.text.isNotEmpty && !_costValid
                          ? 'Ingresa un valor mayor a 0'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      'Precio de venta',
                      _saleCtrl,
                      'Ej: 1200.00',
                      isDark,
                      isRequired: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [_DecimalInputFormatter()],
                      errorText: _saleCtrl.text.isNotEmpty && !_saleValid
                          ? 'Ingresa un valor mayor a 0'
                          : null,
                    ),
                  ),
                ],
              ),
              // Advertencia si precio de venta es menor que el de costo
              if (_costValid && _saleValid &&
                  (double.tryParse(_saleCtrl.text) ?? 0) <
                      (double.tryParse(_costCtrl.text) ?? 0))
                _warningBanner(
                  'El precio de venta es menor al costo. Verifica los valores.',
                ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _marginColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.percent_rounded, color: _marginColor, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Margen de ganancia:',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _calculatedMargin.percentFormatted,
                      style: AppTypography.callout.copyWith(
                        color: _marginColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Inventario ───────────────────────────
          _section(
            title: 'Inventario',
            icon: Icons.inventory_outlined,
            children: [
              // Regla informativa visible
              _numericRulesBanner(
                icon: Icons.info_outline_rounded,
                message:
                    'Cantidad: entero positivo (mínimo 1). '
                    'Stock mínimo: entero no-negativo (0 o más). '
                    'No se aceptan decimales ni valores negativos.',
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _field(
                      'Cantidad',
                      _qtyCtrl,
                      'Ej: 10',
                      isDark,
                      isRequired: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [_integerOnlyFormatter],
                      errorText: _qtyCtrl.text.isNotEmpty && !_qtyValid
                          ? 'Entero positivo (≥ 1)'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      'Stock mínimo',
                      _minStockCtrl,
                      'Ej: 3',
                      isDark,
                      isRequired: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [_integerOnlyFormatter],
                      errorText: _minStockCtrl.text.isNotEmpty && !_minStockValid
                          ? 'Entero no-negativo (≥ 0)'
                          : null,
                    ),
                  ),
                ],
              ),
              _field(
                'Ubicación',
                _locationCtrl,
                'Ej: Pasillo 3, Estante A',
                isDark,
              ),
              SwitchListTile(
                value: _hasExpiration,
                onChanged: (v) => setState(() => _hasExpiration = v),
                activeThumbColor: AppColors.deepSpaceBlue,
                activeTrackColor: AppColors.deepSpaceBlue.withValues(alpha: 0.4),
                title: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tiene fecha de vencimiento',
                      style: AppTypography.callout,
                    ),
                  ],
                ),
                contentPadding: EdgeInsets.zero,
              ),
              if (_hasExpiration)
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _expirationDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) {
                      setState(() => _expirationDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceSecondary
                          : AppColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 16,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _expirationDate != null
                              ? _expirationDate!.shortFormatted
                              : 'Seleccionar fecha',
                          style: AppTypography.body,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          _section(
            title: 'Descripción',
            icon: Icons.notes_rounded,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceSecondary
                      : AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Descripción del producto...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isFormValid ? _save : null,
              style: primaryButtonStyle,
              child: Text(_isEditing ? 'Guardar Cambios' : 'Agregar Producto'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── Banners informativos ──────────────────────

  /// Banner de reglas numéricas (azul informativo).
  Widget _numericRulesBanner({required IconData icon, required String message}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.deepSpaceBlue.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.deepSpaceBlue.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.deepSpaceBlue),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: AppTypography.caption2.copyWith(
                color: AppColors.deepSpaceBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Banner de advertencia (amarillo).
  Widget _warningBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 14, color: AppColors.warning),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: AppTypography.caption2.copyWith(
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Secciones e imagen ────────────────────────

  Widget _imageSection(bool isDark) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.image_outlined, size: 16, color: AppColors.deepSpaceBlue),
              const SizedBox(width: 6),
              Text('Imagen del Producto', style: AppTypography.headline),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Opcional',
                  style: AppTypography.caption2.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _imagePreview(isDark),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'URL de la imagen',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _imageUrlCtrl,
                      keyboardType: TextInputType.url,
                      onChanged: (_) => setState(() => _imageError = false),
                      decoration: const InputDecoration(
                        hintText: 'https://...',
                        prefixIcon: Icon(
                          Icons.link_rounded,
                          size: 18,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pega la URL de una imagen. Si se deja vacío se usará el ícono de la categoría.',
                      style: AppTypography.caption2.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _imagePreview(bool isDark) {
    final url   = _imageUrl;
    final color = _categoryColor;

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null && !_imageError
          ? Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) {
                return progress == null
                    ? child
                    : Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color,
                        ),
                      );
              },
              errorBuilder: (_, __, ___) {
                // Antipatrón corregido: no llamar setState durante build.
                // addPostFrameCallback garantiza que el frame terminó.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !_imageError) setState(() => _imageError = true);
                });
                return _defaultIcon(color);
              },
            )
          : _defaultIcon(color),
    );
  }

  Widget _defaultIcon(Color color) {
    return Center(
      child: Icon(_category.icon, color: color, size: 32),
    );
  }

  Color get _categoryColor {
    switch (_category) {
      case ProductCategory.beverages:    return AppColors.freshSky;
      case ProductCategory.dairy:        return AppColors.info;
      case ProductCategory.snacks:       return AppColors.warning;
      case ProductCategory.cleaning:     return AppColors.teaGreen;
      case ProductCategory.personalCare: return Colors.pink;
      case ProductCategory.grains:       return Colors.brown;
      case ProductCategory.fruits:       return AppColors.success;
      case ProductCategory.meat:         return AppColors.error;
      case ProductCategory.bakery:       return Colors.orange;
      case ProductCategory.frozen:       return AppColors.freshSky;
      case ProductCategory.condiments:   return Colors.red;
      case ProductCategory.other:        return AppColors.textSecondary;
    }
  }

  Widget _aiBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.deepSpaceBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded,
              color: AppColors.deepSpaceBlue, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detectado por IA',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Los campos fueron completados automáticamente. Verifica la información.',
                  style: AppTypography.caption2.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.deepSpaceBlue),
              const SizedBox(width: 6),
              Text(title, style: AppTypography.headline),
            ],
          ),
          const SizedBox(height: 14),
          ...children.expand((w) => [w, const SizedBox(height: 12)]).toList()
            ..removeLast(),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    String hint,
    bool isDark, {
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
            ),
            if (isRequired) ...[
              const SizedBox(width: 3),
              Text(
                '*',
                style: AppTypography.caption.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ] else ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Opcional',
                  style: AppTypography.caption2.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
          ),
        ),
      ],
    );
  }

  Widget _categoryPicker(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Categoría',
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceSecondary
                : AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButton<ProductCategory>(
            value: _category,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            items: ProductCategory.values
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Row(
                      children: [
                        Icon(c.icon, size: 16),
                        const SizedBox(width: 8),
                        Text(c.label),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _category = v);
            },
          ),
        ),
      ],
    );
  }

  void _save() {
    // Doble guarda: el botón solo se habilita si _isFormValid,
    // pero se verifica aquí también por seguridad.
    if (!_isFormValid) return;

    final cost     = double.parse(_costCtrl.text.trim());
    final sale     = double.parse(_saleCtrl.text.trim());
    final qty      = int.parse(_qtyCtrl.text.trim());
    final minStock = int.parse(_minStockCtrl.text.trim());

    final product = Product(
      id: widget.editingProduct?.id ?? const Uuid().v4(),
      name:      _nameCtrl.text.trim(),
      sku:       _skuCtrl.text.trim(),
      barcode:   _barcodeCtrl.text.trim(),
      category:  _category,
      supplier:  _supplierCtrl.text.trim(),
      costPrice: cost,
      salePrice: sale,
      quantity:  qty,
      minStock:  minStock,
      location:  _locationCtrl.text.trim(),
      expirationDate: _hasExpiration ? _expirationDate : null,
      description: _descCtrl.text.trim(),
      imageURL:    _imageUrl,
      lastUpdated: DateTime.now(),
      isActive:    true,
      storeId:     widget.editingProduct?.storeId    ?? ApiService.shared.storeId,
      categoryId:  widget.editingProduct?.categoryId ?? _category.label,
      supplierId:  widget.editingProduct?.supplierId ?? _supplierCtrl.text.trim(),
    );

    if (_isEditing) {
      ref.read(inventoryProvider.notifier).updateProduct(product);
      UsageTrackingService.shared.markEntryInaccurate(product.id);
    } else {
      ref.read(inventoryProvider.notifier).addProduct(product);
      final viaBarcode = widget.fromScan != null;
      UsageTrackingService.shared.trackProductEntry(
        productId: product.id,
        viaBarcode: viaBarcode,
        isAccurate: true,
      );
    }

    setState(() => _showSuccess = true);
  }
}
