import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/cash_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/barcode_lookup_service.dart';
import '../../services/invoice_ocr_service.dart';
import '../../widgets/barcode_scanner_sheet.dart';

class InvoiceScanScreen extends ConsumerStatefulWidget {
  const InvoiceScanScreen({super.key});

  @override
  ConsumerState<InvoiceScanScreen> createState() => _InvoiceScanScreenState();
}

class _RowDraft {
  final TextEditingController name;
  final TextEditingController qty;
  final TextEditingController price;
  int? matchedProductId;
  String? barcode;
  /// OCR aniqlagan asl matn (agar shtrix-kod/qo'lda qo'shilgan bo'lsa — bo'sh).
  final String rawText;
  _RowDraft({
    String name = '',
    String qty = '',
    String price = '',
    this.barcode,
    this.rawText = '',
  })  : name = TextEditingController(text: name),
        qty = TextEditingController(text: qty),
        price = TextEditingController(text: price);

  void dispose() {
    name.dispose();
    qty.dispose();
    price.dispose();
  }
}

class _InvoiceScanScreenState extends ConsumerState<InvoiceScanScreen> {
  File? _image;
  bool _scanning = false;
  bool _applying = false;
  String? _error;
  final List<_RowDraft> _rows = [];

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return;
    setState(() {
      _image = File(picked.path);
      _error = null;
    });
  }

  Future<void> _scan() async {
    if (_image == null) return;
    setState(() {
      _scanning = true;
      _error = null;
    });
    List<ParsedInvoiceLine> parsed;
    try {
      final rawRows = await invoiceOcrService.recognizeRows(_image!.path);
      parsed = invoiceOcrService.parseRows(rawRows);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _error = 'Skanerlashda xatolik: $e';
      });
      return;
    }
    if (!mounted) return;
    setState(() => _scanning = false);
    if (parsed.isEmpty) {
      setState(() => _error =
          'Matn topilmadi. Suratni tekisroq va yorug\'roq olib qayta urinib ko\'ring, yoki qatorlarni qo\'lda qo\'shing.');
    }

    final products = ref.read(productsProvider).valueOrNull ?? [];
    for (final r in _rows) {
      r.dispose();
    }
    _rows.clear();
    for (final line in parsed) {
      final match = products
          .where((p) =>
              p.name.trim().toLowerCase() == line.name.trim().toLowerCase())
          .toList();
      final draft = _RowDraft(
        name: line.name,
        qty: line.qty != null ? formatQty(line.qty!) : '',
        price: line.price != null ? line.price!.toStringAsFixed(0) : '',
        rawText: line.rawText,
      );
      if (match.isNotEmpty) draft.matchedProductId = match.first.id;
      setState(() => _rows.add(draft));
    }
  }

  void _addManualRow() {
    setState(() => _rows.add(_RowDraft()));
  }

  /// Shtrix/QR-kodni skanerlaydi: avval mahalliy bazadan (mavjud tovar)
  /// qidiradi, topilmasa ochiq internet bazasidan nomini olishga
  /// harakat qiladi. Hech biri topilmasa, bo'sh qator qo'shiladi va
  /// foydalanuvchi nomni qo'lda kiritadi.
  Future<void> _addByBarcode() async {
    final code = await showBarcodeScanner(context, title: 'Tovarni skanerlash');
    if (code == null || !mounted) return;

    final products = ref.read(productsProvider).valueOrNull ?? [];
    final match = products.where((p) => p.barcode == code).firstOrNull;
    if (match != null) {
      setState(() => _rows.add(_RowDraft(
            name: match.name,
            price: match.buyPrice > 0 ? match.buyPrice.toStringAsFixed(0) : '',
            barcode: code,
          )..matchedProductId = match.id));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Internet bazasidan tovar nomi izlanmoqda...'),
      duration: Duration(seconds: 2),
    ));
    final foundName = await barcodeLookupService.lookupName(code);
    if (!mounted) return;
    if (foundName != null) {
      setState(() => _rows.add(_RowDraft(name: foundName, barcode: code)));
    } else {
      setState(() => _rows.add(_RowDraft(barcode: code)));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Tovar nomi topilmadi — shtrix-kod saqlandi, nomini qo\'lda kiriting'),
      ));
    }
  }

  void _removeRow(int index) {
    setState(() => _rows.removeAt(index).dispose());
  }

  double get _total {
    var sum = 0.0;
    for (final r in _rows) {
      final qty = double.tryParse(r.qty.text.replaceAll(',', '.')) ?? 0;
      final price = double.tryParse(r.price.text.replaceAll(',', '.')) ?? 0;
      sum += qty * price;
    }
    return sum;
  }

  Future<void> _apply() async {
    final products = ref.read(productsProvider).valueOrNull ?? [];
    final catalog = ref.read(catalogControllerProvider);
    int applied = 0;

    setState(() {
      _applying = true;
      _error = null;
    });

    for (final r in _rows) {
      final name = r.name.text.trim();
      final qty = double.tryParse(r.qty.text.replaceAll(',', '.'));
      final price = double.tryParse(r.price.text.replaceAll(',', '.'));
      if (name.isEmpty || qty == null || qty <= 0 || price == null || price < 0) {
        continue;
      }

      String? err;
      if (r.matchedProductId != null) {
        final existing =
            products.where((p) => p.id == r.matchedProductId).firstOrNull;
        if (existing != null) {
          err = await catalog.upsertProduct(
            id: existing.id,
            name: existing.name,
            categoryId: existing.categoryId,
            unit: existing.unit,
            barcode: existing.barcode,
            buyPrice: price,
            sellPrice: existing.sellPrice,
            stock: existing.stock + qty,
            minStock: existing.minStock,
          );
        }
      } else {
        err = await catalog.upsertProduct(
          id: null,
          name: name,
          categoryId: null,
          unit: 'dona',
          barcode: r.barcode,
          buyPrice: price,
          sellPrice: price,
          stock: qty,
          minStock: 0,
        );
      }
      if (err != null) {
        if (!mounted) return;
        setState(() {
          _applying = false;
          _error = 'Xatolik ("$name"): $err';
        });
        return;
      }
      applied++;
    }

    if (applied == 0) {
      setState(() {
        _applying = false;
        _error = 'Kirim qilish uchun kamida bitta to\'g\'ri qator kerak';
      });
      return;
    }

    final total = _total;
    if (total > 0) {
      await ref.read(cashControllerProvider).addTransaction(
            type: CashType.rashod,
            amount: total,
            category: 'tovar_xaridi',
            note: 'Nakladnoy orqali kirim ($applied ta tovar)',
          );
    }

    ref.invalidate(productsProvider);
    ref.invalidate(cashTransactionsProvider);
    ref.invalidate(dashboardProvider);

    if (!mounted) return;
    setState(() => _applying = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$applied ta tovar bo\'yicha kirim qilindi'),
      backgroundColor: AppColors.primary,
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nakladnoydan kirim')),
      body: _rows.isEmpty ? _buildCaptureStep() : _buildRegisterStep(),
    );
  }

  Widget _buildCaptureStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Nakladnoy (tovar-transport hujjati) suratini oling yoki tanlang. '
            'Dastur undagi tovar nomi, soni va narxini telefonning o\'zida '
            'o\'qib, tahrirlash mumkin bo\'lgan ro\'yxat sifatida ko\'rsatadi. '
            'Natijani skanerlashdan keyin albatta tekshirib chiqing — '
            'aniqlik surat sifatiga bog\'liq.',
          ),
          const SizedBox(height: 16),
          if (_image != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(_image!, height: 260, fit: BoxFit.cover),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Kamera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galereya'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Row(children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('yoki'),
            ),
            Expanded(child: Divider()),
          ]),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _addByBarcode,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Shtrix/QR-kod skanerlab qo\'shish'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: (_image == null || _scanning) ? null : _scan,
            icon: _scanning
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.document_scanner_outlined),
            label: Text(_scanning ? 'Skanerlanmoqda...' : 'Suratni skanerlash'),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterStep() {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final r = _rows[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: r.name,
                              decoration:
                                  const InputDecoration(labelText: 'Tovar nomi'),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close,
                                color: AppColors.danger),
                            onPressed: () => _removeRow(i),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: r.qty,
                              keyboardType: const TextInputType
                                  .numberWithOptions(decimal: true),
                              decoration:
                                  const InputDecoration(labelText: 'Soni'),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Soni va narxni almashtirish',
                            icon: const Icon(Icons.swap_horiz),
                            onPressed: () => setState(() {
                              final tmp = r.qty.text;
                              r.qty.text = r.price.text;
                              r.price.text = tmp;
                            }),
                          ),
                          Expanded(
                            child: TextField(
                              controller: r.price,
                              keyboardType: const TextInputType
                                  .numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                  labelText: 'Kirim narxi'),
                            ),
                          ),
                        ],
                      ),
                      if (r.rawText.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'OCR: ${r.rawText}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontStyle: FontStyle.italic,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (r.matchedProductId != null
                                    ? AppColors.primary
                                    : AppColors.warning)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            r.matchedProductId != null
                                ? 'Mavjud tovar — qoldiq oshiriladi'
                                : 'Yangi tovar sifatida qo\'shiladi',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: r.matchedProductId != null
                                  ? AppColors.primary
                                  : AppColors.warning,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addManualRow,
                        icon: const Icon(Icons.add),
                        label: const Text('Qo\'lda qo\'shish'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addByBarcode,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Skanerlash'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Jami summa:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(formatSum(_total),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary)),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: AppColors.danger)),
                ],
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _applying ? null : _apply,
                  child: _applying
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Kirim qilish'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
