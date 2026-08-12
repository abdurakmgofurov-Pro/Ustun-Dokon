import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../widgets/barcode_scanner_sheet.dart';
import '../../widgets/empty_state.dart';
import 'invoice_scan_screen.dart';
import 'product_form_sheet.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      floatingActionButton: isAdmin
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'invoiceScan',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const InvoiceScanScreen()),
                  ),
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: const Text('Nakladnoydan kirim'),
                  backgroundColor: AppColors.secondary,
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: 'addProduct',
                  onPressed: () => showProductFormSheet(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Tovar qo\'shish'),
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Tovar qidirish...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Shtrix-kod bo\'yicha topish / qo\'shish',
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () => _scanToFindOrCreate(context, isAdmin),
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
                    .where((p) => p.name.toLowerCase().contains(_query))
                    .toList();
                if (filtered.isEmpty) {
                  return const EmptyState(
                      icon: Icons.inventory_2_outlined,
                      message: 'Tovar topilmadi');
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final p = filtered[i];
                    return _ProductTile(product: p, isAdmin: isAdmin);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _scanToFindOrCreate(BuildContext context, bool isAdmin) async {
    final code = await showBarcodeScanner(context, title: 'Tovarni skanerlash');
    if (code == null || !context.mounted) return;
    final products = ref.read(productsProvider).valueOrNull ?? [];
    final match = products.where((p) => p.barcode == code).toList();
    if (match.isNotEmpty) {
      if (isAdmin) {
        showProductFormSheet(context, product: match.first);
      } else {
        setState(() => _query = match.first.name.toLowerCase());
      }
      return;
    }
    if (isAdmin) {
      showProductFormSheet(context, initialBarcode: code);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Shtrix-kod "$code" bo\'yicha tovar topilmadi'),
        backgroundColor: AppColors.danger,
      ));
    }
  }
}

class _ProductTile extends ConsumerWidget {
  final Product product;
  final bool isAdmin;
  const _ProductTile({required this.product, required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(product.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            '${product.categoryName ?? 'Kategoriyasiz'} • ${formatSum(product.sellPrice)} / ${product.unit}'),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${formatQty(product.stock)} ${product.unit}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: product.isLowStock
                    ? AppColors.danger
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (isAdmin)
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit') {
                    showProductFormSheet(context, product: product);
                  } else if (v == 'delete') {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Tovarni o\'chirish'),
                        content: Text(
                            '"${product.name}" tovarini o\'chirmoqchimisiz?'),
                        actions: [
                          TextButton(
                              onPressed: () =>
                                  Navigator.pop(context, false),
                              child: const Text('Bekor qilish')),
                          FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('O\'chirish')),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await ref
                          .read(catalogControllerProvider)
                          .deleteProduct(product.id);
                      ref.invalidate(productsProvider);
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Tahrirlash')),
                  PopupMenuItem(value: 'delete', child: Text('O\'chirish')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
