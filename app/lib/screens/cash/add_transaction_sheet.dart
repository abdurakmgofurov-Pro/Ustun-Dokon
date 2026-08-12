import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/cash_provider.dart';

Future<void> showAddTransactionSheet(BuildContext context, CashType type) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddTransactionSheet(type: type),
  );
}

class _AddTransactionSheet extends ConsumerStatefulWidget {
  final CashType type;
  const _AddTransactionSheet({required this.type});

  @override
  ConsumerState<_AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<_AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late String _category;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final list =
        widget.type == CashType.kirim ? incomeCategories : expenseCategories;
    _category = list.first;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final error = await ref.read(cashControllerProvider).addTransaction(
          type: widget.type,
          amount: double.parse(_amount.text),
          category: _category,
          note: _note.text.trim(),
        );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _loading = false;
        _error = error;
      });
      return;
    }
    ref.invalidate(cashTransactionsProvider);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = widget.type == CashType.kirim;
    final categories = isIncome ? incomeCategories : expenseCategories;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isIncome ? 'Kirim qo\'shish' : 'Rashod qo\'shish',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amount,
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
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Kategoriya'),
                items: [
                  for (final c in categories)
                    DropdownMenuItem(value: c, child: Text(cashCategoryLabel(c))),
                ],
                onChanged: (v) => setState(() => _category = v ?? categories.first),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                decoration: const InputDecoration(labelText: 'Izoh (ixtiyoriy)'),
                maxLines: 2,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isIncome ? AppColors.primary : AppColors.danger),
                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Saqlash'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
