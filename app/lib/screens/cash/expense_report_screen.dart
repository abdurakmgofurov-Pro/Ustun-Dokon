import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../providers/cash_provider.dart';
import '../../widgets/empty_state.dart';

const _monthNames = [
  'Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun',
  'Iyul', 'Avgust', 'Sentyabr', 'Oktyabr', 'Noyabr', 'Dekabr',
];

/// Kassadan tashqari (rashod) xarajatlarni oy bo'yicha, kategoriyalarga
/// ajratib ko'rsatadigan alohida hisobot ekrani. Kassa (kirim-chiqim)
/// ro'yxatidan farqli o'laroq, faqat rashodlarni oyma-oy taqqoslash uchun.
class ExpenseReportScreen extends ConsumerWidget {
  const ExpenseReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(expenseReportMonthProvider);
    final reportAsync = ref.watch(expenseReportProvider);
    final now = DateTime.now();
    final isCurrentMonth = month.year == now.year && month.month == now.month;

    return Scaffold(
      appBar: AppBar(title: const Text('Xarajatlar hisoboti')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => ref
                      .read(expenseReportMonthProvider.notifier)
                      .state = DateTime(month.year, month.month - 1, 1),
                ),
                SizedBox(
                  width: 170,
                  child: Text(
                    '${_monthNames[month.month - 1]} ${month.year}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: isCurrentMonth
                      ? null
                      : () => ref
                          .read(expenseReportMonthProvider.notifier)
                          .state = DateTime(month.year, month.month + 1, 1),
                ),
              ],
            ),
          ),
          Expanded(
            child: reportAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => AsyncErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(expenseReportProvider)),
              data: (rows) {
                if (rows.isEmpty) {
                  return const EmptyState(
                      icon: Icons.pie_chart_outline_outlined,
                      message: 'Bu oyda xarajat yozuvlari yo\'q');
                }
                final total =
                    rows.fold<double>(0, (s, r) => s + r.amount);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Card(
                      color: AppColors.danger.withValues(alpha: 0.08),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Jami xarajat',
                                style:
                                    TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                              formatSum(total),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.danger,
                                  fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    for (final row in rows) ...[
                      _CategoryBar(
                        label: cashCategoryLabel(row.category),
                        amount: row.amount,
                        percent: total > 0 ? row.amount / total : 0,
                      ),
                      const SizedBox(height: 14),
                    ],
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

class _CategoryBar extends StatelessWidget {
  final String label;
  final double amount;
  final double percent;
  const _CategoryBar(
      {required this.label, required this.amount, required this.percent});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(
              '${formatSum(amount)}  (${(percent * 100).toStringAsFixed(0)}%)',
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 8,
            backgroundColor: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.08),
            valueColor: const AlwaysStoppedAnimation(AppColors.danger),
          ),
        ),
      ],
    );
  }
}
