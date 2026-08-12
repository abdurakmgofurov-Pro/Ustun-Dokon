import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../models/receipt.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/customers_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/sales_provider.dart';
import '../../widgets/barcode_scanner_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/receipt_view.dart';
import 'customer_picker.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final cart = ref.watch(cartProvider);
    final total = ref.watch(cartTotalProvider);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Tovar qidirish...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Shtrix-kod skanerlash',
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () => _scanAndAddToCart(context),
                ),
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => AsyncErrorView(
                  error: e, onRetry: () => ref.invalidate(productsProvider)),
              data: (products) {
                final filtered = products
                    .where((p) =>
                        p.isActive && p.name.toLowerCase().contains(_query))
                    .toList();
                if (filtered.isEmpty) {
                  return const EmptyState(
                      icon: Icons.inventory_2_outlined,
                      message: 'Tovar topilmadi');
                }
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 120),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    childAspectRatio: 1.3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final p = filtered[i];
                    final inCart =
                        cart.where((c) => c.product.id == p.id).firstOrNull;
                    return _ProductCard(
                      product: p,
                      qtyInCart: inCart?.qty ?? 0,
                      onTap: p.stock <= 0
                          ? null
                          : () => ref.read(cartProvider.notifier).add(p),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Material(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _openCart(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.white,
                            child: Text('${cart.length}',
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text('Savatni ko\'rish',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16)),
                          ),
                          Text(formatSum(total),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  void _openCart(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CartSheet(),
    );
  }

  Future<void> _scanAndAddToCart(BuildContext context) async {
    await showContinuousBarcodeScanner(
      context,
      title: 'Tovarni skanerlash',
      onDetect: (code) async {
        final products = ref.read(productsProvider).valueOrNull ?? [];
        final product = products
            .where((p) => p.barcode == code && p.isActive)
            .firstOrNull;
        if (product == null) {
          return '❌ Shtrix-kod "$code" topilmadi';
        }
        final inCart = ref
            .read(cartProvider)
            .where((c) => c.product.id == product.id)
            .firstOrNull;
        final nextQty = (inCart?.qty ?? 0) + 1;
        if (nextQty > product.stock) {
          return '⚠️ "${product.name}" qoldig\'i yetarli emas';
        }
        ref.read(cartProvider.notifier).add(product);
        return '✅ "${product.name}" savatga qo\'shildi';
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final double qtyInCart;
  final VoidCallback? onTap;
  const _ProductCard({required this.product, required this.qtyInCart, this.onTap});

  @override
  Widget build(BuildContext context) {
    final outOfStock = product.stock <= 0;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(formatSum(product.sellPrice),
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      outOfStock
                          ? 'Qoldiq yo\'q'
                          : '${formatQty(product.stock)} ${product.unit}',
                      style: TextStyle(
                        fontSize: 12,
                        color: outOfStock
                            ? AppColors.danger
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  if (qtyInCart > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(formatQty(qtyInCart),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartSheet extends ConsumerStatefulWidget {
  const _CartSheet();

  @override
  ConsumerState<_CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends ConsumerState<_CartSheet> {
  PaymentType _paymentType = PaymentType.naqd;
  Customer? _customer;
  bool _loading = false;
  String? _error;

  Future<void> _checkout() async {
    final cart = ref.read(cartProvider);
    final total = ref.read(cartTotalProvider);
    if (_paymentType == PaymentType.qarz && _customer == null) {
      setState(() => _error = 'Qarzga savdo uchun mijozni tanlang');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref.read(salesControllerProvider).checkout(
          cart: cart,
          paymentType: _paymentType,
          customerId: _customer?.id,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.error != null) {
      setState(() => _error = result.error);
      return;
    }
    final cashierName =
        ref.read(currentProfileProvider).valueOrNull?.fullName ?? '';
    final receipt = ReceiptData(
      saleId: result.saleId,
      createdAt: DateTime.now(),
      cashierName: cashierName,
      paymentType: _paymentType,
      customerName: _customer?.fullName,
      customerTotalDebt: _paymentType == PaymentType.qarz && _customer != null
          ? _customer!.totalDebt + total
          : null,
      items: cart
          .map((c) => ReceiptItem(
                name: c.product.name,
                qty: c.qty,
                unit: c.product.unit,
                price: c.product.sellPrice,
              ))
          .toList(),
      total: total,
    );
    ref.read(cartProvider.notifier).clear();
    ref.invalidate(productsProvider);
    ref.invalidate(salesListProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(customersProvider);
    Navigator.of(context).pop();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Savdo muvaffaqiyatli amalga oshirildi'),
        backgroundColor: AppColors.primary,
      ));
      await showReceiptSheet(context, ref, receipt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final total = ref.watch(cartTotalProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Savat',
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  TextButton(
                    onPressed: () {
                      ref.read(cartProvider.notifier).clear();
                      Navigator.pop(context);
                    },
                    child: const Text('Tozalash'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: cart.length,
                itemBuilder: (context, i) {
                  final item = cart[i];
                  return ListTile(
                    title: Text(item.product.name),
                    subtitle: Text(
                        '${formatSum(item.product.sellPrice)} / ${item.product.unit}'),
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => ref
                              .read(cartProvider.notifier)
                              .setQty(item.product.id, item.qty - 1),
                        ),
                        _QtyEditor(item: item),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: item.qty + 1 > item.product.stock
                              ? null
                              : () => ref
                                  .read(cartProvider.notifier)
                                  .add(item.product),
                        ),
                      ],
                    ),
                    trailing: Text(formatSum(item.total),
                        style:
                            const TextStyle(fontWeight: FontWeight.bold)),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Jami:',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(formatSum(total),
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<PaymentType>(
                    segments: const [
                      ButtonSegment(
                          value: PaymentType.naqd, label: Text('Naqd')),
                      ButtonSegment(
                          value: PaymentType.karta, label: Text('Karta')),
                      ButtonSegment(
                          value: PaymentType.qarz, label: Text('Qarz')),
                    ],
                    selected: {_paymentType},
                    onSelectionChanged: (s) =>
                        setState(() => _paymentType = s.first),
                  ),
                  if (_paymentType == PaymentType.qarz) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final c = await showCustomerPicker(context, ref);
                        if (c != null) setState(() => _customer = c);
                      },
                      icon: const Icon(Icons.person_outline),
                      label: Text(_customer == null
                          ? 'Mijozni tanlang'
                          : _customer!.fullName),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: AppColors.danger)),
                  ],
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: (cart.isEmpty || _loading) ? null : _checkout,
                    child: _loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Sotish'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Savatdagi tovar miqdorini to'g'ridan-to'g'ri kiritish uchun maydon.
/// Kasr sonlarni ham qabul qiladi (masalan 1.5 kg).
class _QtyEditor extends ConsumerStatefulWidget {
  final CartItem item;
  const _QtyEditor({required this.item});

  @override
  ConsumerState<_QtyEditor> createState() => _QtyEditorState();
}

class _QtyEditorState extends ConsumerState<_QtyEditor> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: formatQty(widget.item.qty));
  }

  @override
  void didUpdateWidget(covariant _QtyEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = double.tryParse(_controller.text.replaceAll(',', '.'));
    if (current != widget.item.qty) {
      _controller.text = formatQty(widget.item.qty);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply(String value) {
    final product = widget.item.product;
    final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) {
      _controller.text = formatQty(widget.item.qty);
      return;
    }
    final clamped = parsed > product.stock ? product.stock : parsed;
    ref.read(cartProvider.notifier).setQty(product.id, clamped);
    _controller.text = formatQty(clamped);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      child: TextField(
        controller: _controller,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
        ),
        onSubmitted: _apply,
        onTapOutside: (_) => _apply(_controller.text),
      ),
    );
  }
}
