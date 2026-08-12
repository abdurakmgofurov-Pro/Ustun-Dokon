import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../models/receipt.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sales_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/receipt_view.dart';

class SalesHistoryScreen extends ConsumerWidget {
  const SalesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(salesFilterProvider);
    final salesAsync = ref.watch(salesListProvider);
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                        '${formatDate(filter.from)} — ${formatDate(filter.to.subtract(const Duration(days: 1)))}'),
                    onPressed: () async {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2024),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                        initialDateRange: DateTimeRange(
                            start: filter.from,
                            end: filter.to.subtract(const Duration(days: 1))),
                      );
                      if (range != null) {
                        ref.read(salesFilterProvider.notifier).state =
                            SalesFilter(
                          from: DateTime(range.start.year, range.start.month,
                              range.start.day),
                          to: DateTime(range.end.year, range.end.month,
                                  range.end.day)
                              .add(const Duration(days: 1)),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: salesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => AsyncErrorView(
                  error: e, onRetry: () => ref.invalidate(salesListProvider)),
              data: (sales) {
                if (sales.isEmpty) {
                  return const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      message: 'Bu davrda savdo yo\'q');
                }
                final activeTotal = sales
                    .where((s) => !s.isCancelled)
                    .fold<double>(0, (s, e) => s + e.total);
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${sales.length} ta chek'),
                          Text('Jami: ${formatSum(activeTotal)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: sales.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _SaleTile(
                            sale: sales[i], isAdmin: isAdmin),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SaleTile extends ConsumerWidget {
  final Sale sale;
  final bool isAdmin;
  const _SaleTile({required this.sale, required this.isAdmin});

  IconData get _paymentIcon => switch (sale.paymentType) {
        PaymentType.naqd => Icons.payments_outlined,
        PaymentType.karta => Icons.credit_card,
        PaymentType.qarz => Icons.schedule,
      };

  String get _paymentLabel => switch (sale.paymentType) {
        PaymentType.naqd => 'Naqd',
        PaymentType.karta => 'Karta',
        PaymentType.qarz => 'Qarz',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final mutedIcon = onSurface.withValues(alpha: 0.35);
    return Card(
      child: ExpansionTile(
        leading: Icon(_paymentIcon,
            color: sale.isCancelled ? mutedIcon : AppColors.primary),
        title: Text(
          formatSum(sale.total),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration:
                sale.isCancelled ? TextDecoration.lineThrough : null,
            color: sale.isCancelled ? mutedIcon : onSurface,
          ),
        ),
        subtitle: Text(
            '${formatDateTime(sale.createdAt)} • $_paymentLabel'
            '${sale.customerName != null ? ' • ${sale.customerName}' : ''}'
            '${sale.isCancelled ? ' • BEKOR QILINGAN' : ''}'),
        children: [
          Consumer(builder: (context, ref, _) {
            final itemsAsync = ref.watch(saleItemsProvider(sale.id));
            return itemsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Xatolik: $e'),
              ),
              data: (items) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  children: [
                    for (final item in items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                                child: Text(
                                    '${item.productName} x${formatQty(item.qty)}')),
                            Text(formatSum(item.total)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.print_outlined, size: 18),
                          label: const Text('Chop etish'),
                          onPressed: () => showReceiptSheet(
                            context,
                            ref,
                            ReceiptData(
                              saleId: sale.id,
                              createdAt: sale.createdAt,
                              cashierName: sale.cashierName ?? '',
                              paymentType: sale.paymentType,
                              customerName: sale.customerName,
                              items: items
                                  .map((i) => ReceiptItem(
                                        name: i.productName,
                                        qty: i.qty,
                                        unit: '',
                                        price: i.price,
                                      ))
                                  .toList(),
                              total: sale.total,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isAdmin && !sale.isCancelled) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          icon: const Icon(Icons.cancel_outlined,
                              color: AppColors.danger),
                          label: const Text('Chekni bekor qilish',
                              style: TextStyle(color: AppColors.danger)),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Chekni bekor qilish'),
                                content: const Text(
                                    'Ushbu chek bekor qilinsa, tovar qoldig\'i qaytariladi. Davom etasizmi?'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Yo\'q')),
                                  FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Ha, bekor qilish')),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              await ref
                                  .read(salesControllerProvider)
                                  .cancelSale(sale.id);
                              ref.invalidate(salesListProvider);
                            }
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
