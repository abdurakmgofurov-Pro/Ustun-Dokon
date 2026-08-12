import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/stat_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(dashboardProvider);
    final extras = ref.watch(dashboardExtrasProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(dashboardProvider),
      child: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AsyncErrorView(
          error: e,
          onRetry: () => ref.invalidate(dashboardProvider),
        ),
        data: (data) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth > 900 ? 4 : (c.maxWidth > 600 ? 2 : 1);
                return GridView.count(
                  crossAxisCount: cols,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 2.6,
                  children: [
                    StatCard(
                      title: 'Bugungi savdo',
                      value: formatSum(data.todaySales),
                      subtitle: '${data.todayReceipts} ta chek',
                      icon: Icons.point_of_sale,
                      color: AppColors.primary,
                    ),
                    StatCard(
                      title: 'Bugungi foyda',
                      value: formatSum(data.todayProfit),
                      icon: Icons.trending_up,
                      color: Colors.teal,
                    ),
                    StatCard(
                      title: 'Umumiy qarzdorlik',
                      value: formatSum(extras.totalDebt),
                      icon: Icons.people,
                      color: AppColors.warning,
                    ),
                    StatCard(
                      title: 'Kam qolgan tovarlar',
                      value: '${extras.lowStock.length} ta',
                      icon: Icons.warning_amber,
                      color: AppColors.danger,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'So\'nggi 7 kunlik savdo',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: _WeeklyChart(points: data.last7Days),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bugun ko\'p sotilgan tovarlar',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          if (data.topProducts.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'Hali savdo bo\'lmagan',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            )
                          else
                            for (final p in data.topProducts)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(p.name)),
                                    Text(
                                      formatQty(p.qty),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (extras.lowStock.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.warning_amber,
                            color: AppColors.danger,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Kam qolgan tovarlar',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final p in extras.lowStock)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(child: Text(p.name)),
                              Text(
                                '${formatQty(p.stock)} ${p.unit}',
                                style: const TextStyle(color: AppColors.danger),
                              ),
                            ],
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.go('/products'),
                          child: const Text('Tovarlarga o\'tish'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  final List<DailyPoint> points;
  const _WeeklyChart({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.every((p) => p.total == 0)) {
      return const EmptyState(
        icon: Icons.bar_chart,
        message: 'Hali savdo ma\'lumotlari yo\'q',
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final axisColor = scheme.onSurface.withValues(alpha: 0.5);
    final gridColor = scheme.onSurface.withValues(alpha: 0.08);
    final trackColor = scheme.onSurface.withValues(alpha: 0.06);
    final maxY = points
        .map((p) => p.total)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final chartMaxY = maxY == 0 ? 10.0 : maxY * 1.2;
    return BarChart(
      BarChartData(
        maxY: chartMaxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: chartMaxY / 4,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: gridColor, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= points.length) return const SizedBox();
                final d = points[i].day;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${d.day}/${d.month}',
                    style: TextStyle(fontSize: 11, color: axisColor),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: points[i].total,
                  width: 18,
                  borderRadius: BorderRadius.circular(6),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [AppColors.primary, AppColors.secondary],
                  ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: chartMaxY,
                    color: trackColor,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
