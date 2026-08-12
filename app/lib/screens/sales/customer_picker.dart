import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../providers/customers_provider.dart';

Future<Customer?> showCustomerPicker(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<Customer>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _CustomerPickerSheet(),
  );
}

class _CustomerPickerSheet extends ConsumerStatefulWidget {
  const _CustomerPickerSheet();

  @override
  ConsumerState<_CustomerPickerSheet> createState() =>
      _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends ConsumerState<_CustomerPickerSheet> {
  String _query = '';
  final _newName = TextEditingController();
  final _newPhone = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _newName.dispose();
    _newPhone.dispose();
    super.dispose();
  }

  Future<void> _createAndSelect() async {
    if (_newName.text.trim().isEmpty) return;
    setState(() => _creating = true);
    final customer = await ref.read(customerControllerProvider).addCustomer(
          fullName: _newName.text.trim(),
          phone: _newPhone.text.trim(),
        );
    if (!mounted) return;
    setState(() => _creating = false);
    if (customer != null) {
      ref.invalidate(customersProvider);
      Navigator.of(context).pop(customer);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Mijozni tanlang', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                  hintText: 'Qidirish...', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: customersAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Xatolik: $e')),
                data: (customers) {
                  final filtered = customers
                      .where((c) =>
                          c.fullName.toLowerCase().contains(_query) ||
                          (c.phone ?? '').contains(_query))
                      .toList();
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final c = filtered[i];
                      return ListTile(
                        title: Text(c.fullName),
                        subtitle: Text(c.phone ?? ''),
                        trailing: c.totalDebt > 0
                            ? Text(formatSum(c.totalDebt),
                                style: const TextStyle(color: Colors.red))
                            : null,
                        onTap: () => Navigator.of(context).pop(c),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(),
            Text('Yangi mijoz qo\'shish',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _newName,
                    decoration: const InputDecoration(labelText: 'Ism'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _newPhone,
                    decoration: const InputDecoration(labelText: 'Telefon'),
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _creating ? null : _createAndSelect,
              child: _creating
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Qo\'shish va tanlash'),
            ),
          ],
        ),
      ),
    );
  }
}
