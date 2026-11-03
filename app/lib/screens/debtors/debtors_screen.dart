import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../providers/customers_provider.dart';
import '../../widgets/empty_state.dart';

class DebtorsScreen extends ConsumerStatefulWidget {
  const DebtorsScreen({super.key});

  @override
  ConsumerState<DebtorsScreen> createState() => _DebtorsScreenState();
}

class _DebtorsScreenState extends ConsumerState<DebtorsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final debtors = ref.watch(debtorsProvider);
    final totalDebt = ref.watch(totalDebtProvider);
    final filtered = debtors
        .where((c) => c.fullName.toLowerCase().contains(_query))
        .toList();
    final creditors = ref
        .watch(creditorsProvider)
        .where((c) => c.fullName.toLowerCase().contains(_query))
        .toList();

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Umumiy qarzdorlik',
                    style: Theme.of(context).textTheme.bodyMedium),
                Text(formatSum(totalDebt),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold, color: AppColors.warning)),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                      hintText: 'Mijoz qidirish...',
                      prefixIcon: Icon(Icons.search)),
                  onChanged: (v) => setState(() => _query = v.toLowerCase()),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty && creditors.isEmpty
                ? const EmptyState(
                    icon: Icons.people_outline,
                    message: 'Qarzdorlar topilmadi')
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      for (final c in filtered)
                        Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                                child: Icon(Icons.person_outline)),
                            title: Text(c.fullName),
                            subtitle: Text(c.phone ?? ''),
                            trailing: Text(
                              formatSum(c.totalDebt),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.danger),
                            ),
                            onTap: () => context.go('/debtors/${c.id}'),
                          ),
                        ),
                      if (creditors.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                          child: Text(
                              "Do'kon qaytarishi kerak (ortiqcha to'lov)",
                              style: Theme.of(context).textTheme.titleSmall),
                        ),
                        for (final c in creditors)
                          Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                  child: Icon(Icons.undo_outlined)),
                              title: Text(c.fullName),
                              subtitle: Text(c.phone ?? ''),
                              trailing: Text(
                                formatSum(-c.totalDebt),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary),
                              ),
                              onTap: () => context.go('/debtors/${c.id}'),
                            ),
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
