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
            child: filtered.isEmpty
                ? const EmptyState(
                    icon: Icons.people_outline,
                    message: 'Qarzdorlar topilmadi')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final c = filtered[i];
                      return Card(
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
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
