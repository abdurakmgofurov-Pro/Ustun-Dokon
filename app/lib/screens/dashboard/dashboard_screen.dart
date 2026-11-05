import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/stat_card.dart';
import '../cash/expense_report_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(dashboardProvider);
    final extras = ref.watch(dashboardExtrasProvider);
    final isAdmin = ref.watch(isAdminProvider);

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
            _SalesHero(
              data: data,
              onTap: () => context.go('/sales-history'),
            ),
            const SizedBox(height: 12),
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
                      title: 'Bugungi foyda',
                      value: formatSum(data.todayProfit),
                      icon: Icons.trending_up,
                      color: Colors.teal,
                      onTap: isAdmin
                          ? () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const ExpenseReportScreen()),
                              )
                          : null,
                    ),
                    StatCard(
                      title: 'Umumiy qarzdorlik',
                      value: formatSum(extras.totalDebt),
                      icon: Icons.people,
                      color: AppColors.warning,
                      onTap: () => context.go('/debtors'),
                    ),
                    if (isAdmin)
                      StatCard(
                        title: "Tovar qoldig'i (tannarx)",
                        value: formatSum(extras.stockCost),
                        subtitle:
                            'Sotuv narxida: ${formatSum(extras.stockRetail)}',
                        icon: Icons.inventory_2,
                        color: Colors.indigo,
                        onTap: () => context.go('/products'),
                      ),
                    StatCard(
                      title: 'Kam qolgan tovarlar',
                      value: '${extras.lowStock.length} ta',
                      icon: Icons.warning_amber,
                      color: AppColors.danger,
                      onTap: () => context.go('/products'),
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


/// Bosh sahifaning asosiy kartasi: bugungi savdo, kechagiga nisbatan o'zgarish
/// va so'nggi 7 kunning mini ustunlari (bugun to'liq yorqinlikda).
class _SalesHero extends StatelessWidget {
  final DashboardData data;
  final VoidCallback onTap;
  const _SalesHero({required this.data, required this.onTap});

  static const _weekdays = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];

  String _deltaText() {
    final pts = data.last7Days;
    final yesterday = pts.length >= 2 ? pts[pts.length - 2].total : 0.0;
    if (yesterday <= 0) {
      return data.todaySales > 0 ? "Kecha savdo bo'lmagan" : 'Bugun hali savdo yo\'q';
    }
    final pct = (data.todaySales - yesterday) / yesterday * 100;
    final sign = pct >= 0 ? '+' : '−';
    return '$sign${pct.abs().toStringAsFixed(0)}% kechagiga nisbatan';
  }

  @override
  Widget build(BuildContext context) {
    final pts = data.last7Days;
    final maxV = pts.fold<double>(0, (m, p) => p.total > m ? p.total : m);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDeep],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Bugungi savdo',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${data.todayReceipts} ta chek',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatSum(data.todaySales),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      fontFeatures: tabularFigures,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(_deltaText(),
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 18),
                SizedBox(
                  height: 64,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < pts.length; i++)
                        Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  height: 4 +
                                      (maxV > 0
                                          ? 36 * (pts[i].total / maxV)
                                          : 0),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(
                                        alpha: i == pts.length - 1
                                            ? 1
                                            : 0.35),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _weekdays[pts[i].day.weekday - 1],
                                  style: TextStyle(
                                    color: Colors.white.withValues(
                                        alpha: i == pts.length - 1
                                            ? 1
                                            : 0.7),
                                    fontSize: 11,
                                    fontWeight: i == pts.length - 1
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
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
    );
  }
}
