import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/customers_provider.dart';
import '../../providers/dashboard_provider.dart';

/// Mijozga savdosiz (qo'lda) qarz qo'shish — masalan eski daftar qarzlari.
/// Faqat admin; serverda ham tekshiriladi. Kassaga ta'sir qilmaydi.
Future<void> showAddDebtDialog(
    BuildContext context, WidgetRef ref, Customer customer) {
  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool loading = false;
  String? error;

  return showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text("Qarz qo'shish: ${customer.fullName}"),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Joriy qarz: ${formatSum(customer.totalDebt)}'),
              const SizedBox(height: 12),
              TextFormField(
                controller: amountCtrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: "Summa (so'm)"),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  if (n == null || n <= 0) return 'Summani kiriting';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: noteCtrl,
                decoration:
                    const InputDecoration(labelText: 'Izoh (ixtiyoriy)'),
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
                    final err =
                        await ref.read(customerControllerProvider).addDebt(
                              customerId: customer.id,
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
                    ref.invalidate(customerDebtEntriesProvider(customer.id));
                    ref.invalidate(dashboardProvider);
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
            child: const Text("Qo'shish"),
          ),
        ],
      ),
    ),
  );
}
