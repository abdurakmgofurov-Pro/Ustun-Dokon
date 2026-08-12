import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../providers/customers_provider.dart';
import '../../widgets/empty_state.dart';

class DebtorDetailScreen extends ConsumerWidget {
  final int customerId;
  const DebtorDetailScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersProvider);
    final paymentsAsync = ref.watch(customerDebtPaymentsProvider(customerId));
    final salesAsync = ref.watch(customerSalesProvider(customerId));

    final customer = customersAsync.valueOrNull
        ?.where((c) => c.id == customerId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(customer?.fullName ?? 'Mijoz')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPayDialog(context, ref),
        icon: const Icon(Icons.payments_outlined),
        label: const Text('To\'lov qilish'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text('Joriy qarz', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  Text(
                    formatSum(customer?.totalDebt ?? 0),
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold, color: AppColors.danger),
                  ),
                  if (customer?.phone != null) ...[
                    const SizedBox(height: 6),
                    Text(customer!.phone!,
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6))),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Qarzga olingan savdolar',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          salesAsync.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator()),
            error: (e, _) => Text('Xatolik: $e'),
            data: (sales) {
              final debtSales = sales.where((s) => !s.isCancelled).toList();
              if (debtSales.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('Hali qarz yozuvi yo\'q',
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5))),
                );
              }
              return Column(
                children: [
                  for (final s in debtSales)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.receipt_long_outlined),
                        title: Text(formatSum(s.total)),
                        subtitle: Text(formatDateTime(s.createdAt)),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Text('To\'lovlar tarixi',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          paymentsAsync.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator()),
            error: (e, _) => Text('Xatolik: $e'),
            data: (payments) {
              if (payments.isEmpty) {
                return const EmptyState(
                    icon: Icons.history, message: 'Hali to\'lov bo\'lmagan');
              }
              return Column(
                children: [
                  for (final p in payments)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.check_circle_outline,
                            color: AppColors.primary),
                        title: Text(formatSum(p.amount)),
                        subtitle: Text(
                            '${formatDateTime(p.createdAt)}${p.note != null && p.note!.isNotEmpty ? ' • ${p.note}' : ''}'),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _showPayDialog(BuildContext context, WidgetRef ref) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;
    String? error;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Qarz to\'lovi'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: amountCtrl,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Summa (so\'m)'),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Summani kiriting';
                    if (double.tryParse(v) == null) return 'Noto\'g\'ri son';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(labelText: 'Izoh (ixtiyoriy)'),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: const TextStyle(color: AppColors.danger)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Bekor qilish'),
            ),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setState(() => loading = true);
                      final err = await ref
                          .read(customerControllerProvider)
                          .payDebt(
                            customerId: customerId,
                            amount: double.parse(amountCtrl.text),
                            note: noteCtrl.text.trim(),
                          );
                      if (err != null) {
                        setState(() {
                          loading = false;
                          error = err;
                        });
                        return;
                      }
                      ref.invalidate(customersProvider);
                      ref.invalidate(customerDebtPaymentsProvider(customerId));
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    },
              child: const Text('Saqlash'),
            ),
          ],
        ),
      ),
    );
  }
}
