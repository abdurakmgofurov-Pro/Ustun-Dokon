import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/cash_provider.dart';
import '../../providers/sales_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/stat_card.dart';
import 'add_transaction_sheet.dart';
import 'expense_report_screen.dart';

class CashScreen extends ConsumerWidget {
  const CashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(cashFilterProvider);
    final txAsync = ref.watch(cashTransactionsProvider);
    final summary = ref.watch(cashSummaryProvider);
    final balance = summary.kirim - summary.rashod;

    return Scaffold(
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'rashod',
            backgroundColor: AppColors.danger,
            onPressed: () => showAddTransactionSheet(context, CashType.rashod),
            icon: const Icon(Icons.remove),
            label: const Text('Rashod'),
          ),
          const SizedBox(width: 10),
          FloatingActionButton.extended(
            heroTag: 'kirim',
            onPressed: () => showAddTransactionSheet(context, CashType.kirim),
            icon: const Icon(Icons.add),
            label: const Text('Kirim'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                        ref.read(cashFilterProvider.notifier).state =
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
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Oylik hisobot (savdo, foyda, xarajatlar)',
                  icon: const Icon(Icons.bar_chart_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const ExpenseReportScreen()),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Kirim',
                    value: formatSum(summary.kirim),
                    icon: Icons.arrow_downward,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    title: 'Rashod',
                    value: formatSum(summary.rashod),
                    icon: Icons.arrow_upward,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Balans: ${formatSum(balance)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: balance >= 0 ? AppColors.primary : AppColors.danger),
              ),
            ),
          ),
          Expanded(
            child: txAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => AsyncErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(cashTransactionsProvider)),
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      message: 'Bu davrda yozuvlar yo\'q');
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final tx = list[i];
                    final isIncome = tx.type == CashType.kirim;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: (isIncome
                                  ? AppColors.primary
                                  : AppColors.danger)
                              .withValues(alpha: 0.12),
                          child: Icon(
                            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                            color: isIncome ? AppColors.primary : AppColors.danger,
                          ),
                        ),
                        title: Text(cashCategoryLabel(tx.category)),
                        subtitle: Text(
                            '${formatDateTime(tx.createdAt)}${tx.note != null && tx.note!.isNotEmpty ? '\n${tx.note}' : ''}'),
                        isThreeLine: tx.note != null && tx.note!.isNotEmpty,
                        trailing: Text(
                          '${isIncome ? '+' : '-'}${formatSum(tx.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isIncome ? AppColors.primary : AppColors.danger,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
