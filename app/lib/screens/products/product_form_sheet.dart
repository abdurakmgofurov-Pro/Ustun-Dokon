import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/catalog_provider.dart';
import '../../services/barcode_lookup_service.dart';
import '../../widgets/barcode_scanner_sheet.dart';

Future<void> showProductFormSheet(BuildContext context,
    {Product? product, String? initialBarcode}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _ProductFormSheet(product: product, initialBarcode: initialBarcode),
  );
}

class _ProductFormSheet extends ConsumerStatefulWidget {
  final Product? product;
  final String? initialBarcode;
  const _ProductFormSheet({this.product, this.initialBarcode});

  @override
  ConsumerState<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends ConsumerState<_ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _buyPrice;
  late final TextEditingController _sellPrice;
  late final TextEditingController _marginPercent;
  late final TextEditingController _stock;
  late final TextEditingController _minStock;
  late final TextEditingController _barcode;
  String _unit = 'dona';
  int? _categoryId;
  bool _loading = false;
  String? _error;
  bool _syncing = false;

  static const _units = ['dona', 'kg', 'litr', 'quti', 'pachka'];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _buyPrice = TextEditingController(text: p?.buyPrice.toString() ?? '');
    _sellPrice = TextEditingController(text: p?.sellPrice.toString() ?? '');
    _marginPercent = TextEditingController(text: _computeMargin(p));
    _stock = TextEditingController(text: p?.stock.toString() ?? '0');
    _minStock = TextEditingController(text: p?.minStock.toString() ?? '0');
    _barcode =
        TextEditingController(text: p?.barcode ?? widget.initialBarcode ?? '');
    _unit = p?.unit ?? 'dona';
    _categoryId = p?.categoryId;

    _buyPrice.addListener(_onPricesChanged);
    _sellPrice.addListener(_onPricesChanged);
    _marginPercent.addListener(_onMarginChanged);

    if (p == null && widget.initialBarcode != null && _name.text.trim().isEmpty) {
      _lookupNameForBarcode(widget.initialBarcode!);
    }
  }

  Future<void> _lookupNameForBarcode(String code) async {
    final found = await barcodeLookupService.lookupName(code);
    if (!mounted || found == null || _name.text.trim().isNotEmpty) return;
    setState(() => _name.text = found);
  }

  static String _computeMargin(Product? p) {
    if (p == null || p.buyPrice <= 0) return '';
    final margin = (p.sellPrice - p.buyPrice) / p.buyPrice * 100;
    return _trim(margin);
  }

  static String _trim(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }

  void _onPricesChanged() {
    if (_syncing) return;
    final buy = double.tryParse(_buyPrice.text);
    final sell = double.tryParse(_sellPrice.text);
    if (buy == null || buy <= 0 || sell == null) return;
    _syncing = true;
    _marginPercent.text = _trim((sell - buy) / buy * 100);
    _syncing = false;
  }

  void _onMarginChanged() {
    if (_syncing) return;
    final buy = double.tryParse(_buyPrice.text);
    final margin = double.tryParse(_marginPercent.text);
    if (buy == null || buy <= 0 || margin == null) return;
    _syncing = true;
    _sellPrice.text = _trim(buy * (1 + margin / 100));
    _syncing = false;
  }

  @override
  void dispose() {
    _name.dispose();
    _buyPrice.dispose();
    _sellPrice.dispose();
    _marginPercent.dispose();
    _stock.dispose();
    _minStock.dispose();
    _barcode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final error = await ref.read(catalogControllerProvider).upsertProduct(
          id: widget.product?.id,
          name: _name.text.trim(),
          categoryId: _categoryId,
          unit: _unit,
          barcode: _barcode.text.trim(),
          buyPrice: double.parse(_buyPrice.text),
          sellPrice: double.parse(_sellPrice.text),
          stock: double.parse(_stock.text),
          minStock: double.parse(_minStock.text),
        );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _loading = false;
        _error = error;
      });
      return;
    }
    ref.invalidate(productsProvider);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                Text(
                  widget.product == null
                      ? 'Yangi tovar qo\'shish'
                      : 'Tovarni tahrirlash',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Tovar nomi'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Nomini kiriting' : null,
                ),
                const SizedBox(height: 12),
                categoriesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => const SizedBox(),
                  data: (categories) => DropdownButtonFormField<int?>(
                    initialValue: _categoryId,
                    decoration:
                        const InputDecoration(labelText: 'Kategoriya'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('—')),
                      for (final c in categories)
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _unit,
                        decoration:
                            const InputDecoration(labelText: 'O\'lchov birligi'),
                        items: [
                          for (final u in _units)
                            DropdownMenuItem(value: u, child: Text(u)),
                        ],
                        onChanged: (v) => setState(() => _unit = v ?? 'dona'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _barcode,
                        decoration: InputDecoration(
                          labelText: 'Shtrix-kod',
                          suffixIcon: IconButton(
                            tooltip: 'Skanerlash',
                            icon: const Icon(Icons.qr_code_scanner),
                            onPressed: () async {
                              final code = await showBarcodeScanner(context,
                                  title: 'Shtrix-kodni skanerlash');
                              if (code == null || !mounted) return;

                              // Bu shtrix-kod boshqa (yoki shu) tovarga
                              // allaqachon tegishli bo'lsa — yangi tovar
                              // sifatida saqlashga urinib, unique
                              // xatoga uchramaslik uchun to'g'ridan-to'g'ri
                              // o'sha tovarni tahrirlash rejimiga o'tamiz.
                              final products =
                                  ref.read(productsProvider).valueOrNull ??
                                      [];
                              final existing = products
                                  .where((p) =>
                                      p.barcode == code &&
                                      p.id != widget.product?.id)
                                  .firstOrNull;
                              if (existing != null) {
                                Navigator.of(context).pop();
                                showProductFormSheet(context,
                                    product: existing);
                                return;
                              }

                              _barcode.text = code;
                              if (_name.text.trim().isNotEmpty) return;
                              final found =
                                  await barcodeLookupService.lookupName(code);
                              if (found != null) _name.text = found;
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _buyPrice,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Kirim narxi'),
                        validator: _numValidator,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _sellPrice,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Sotish narxi'),
                        validator: _numValidator,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _marginPercent,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Marja (%)',
                    helperText:
                        'Kirim/sotish narxidan avtomatik hisoblanadi. O\'zgartirsangiz, sotish narxi qayta hisoblanadi.',
                    helperMaxLines: 2,
                    prefixIcon: Icon(Icons.percent),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _stock,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Joriy qoldiq'),
                        validator: _numValidator,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _minStock,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Minimal qoldiq'),
                        validator: _numValidator,
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AppColors.danger)),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Saqlash'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _numValidator(String? v) {
    if (v == null || v.isEmpty) return 'Kiriting';
    if (double.tryParse(v) == null) return 'Noto\'g\'ri son';
    return null;
  }
}
