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

/// Oylik hisobot: tanlangan oy uchun jami sotuv, tovarlar tannarxi, yalpi
/// va sof foyda, hamda rashodlarning kategoriya bo'yicha taqsimoti — oyma-oy
/// (oldinga/orqaga) solishtirib ko'rish uchun bitta ekranda.
class ExpenseReportScreen extends ConsumerWidget {
  const ExpenseReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(expenseReportMonthProvider);
    final reportAsync = ref.watch(expenseReportProvider);
    final profitAsync = ref.watch(profitReportProvider);
    final now = DateTime.now();
    final isCurrentMonth = month.year == now.year && month.month == now.month;

    return Scaffold(
      appBar: AppBar(title: const Text('Oylik hisobot')),
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
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                profitAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => AsyncErrorView(
                      error: e,
                      onRetry: () => ref.invalidate(profitReportProvider)),
                  data: (p) => _ProfitSummary(summary: p),
                ),
                const SizedBox(height: 28),
                Text('Xarajatlar taqsimoti',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                reportAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => AsyncErrorView(
                      error: e,
                      onRetry: () => ref.invalidate(expenseReportProvider)),
                  data: (rows) {
                    if (rows.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: EmptyState(
                            icon: Icons.pie_chart_outline_outlined,
                            message: 'Bu oyda xarajat yozuvlari yo\'q'),
                      );
                    }
                    final total = rows.fold<double>(0, (s, r) => s + r.amount);
                    return Column(
                      children: [
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfitSummary extends StatelessWidget {
  final MonthlyProfitSummary summary;
  const _ProfitSummary({required this.summary});

  @override
  Widget build(BuildContext context) {
    final netColor =
        summary.netProfit >= 0 ? AppColors.primary : AppColors.danger;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _MiniStat(
                  label: 'Jami sotuv', value: formatSum(summary.revenue)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniStat(
                  label: 'Tovar tannarxi', value: formatSum(summary.cost)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MiniStat(
                  label: 'Yalpi foyda',
                  value: formatSum(summary.grossProfit)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniStat(
                  label: 'Xarajatlar', value: formatSum(summary.expenses)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          color: netColor.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Sof foyda',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  formatSum(summary.netProfit),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: netColor,
                      fontSize: 17),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6))),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
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
