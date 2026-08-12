import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase_service.dart';
import 'catalog_provider.dart';
import 'customers_provider.dart';

class DailyPoint {
  final DateTime day;
  final double total;
  DailyPoint(this.day, this.total);
}

class DashboardData {
  final double todaySales;
  final double todayProfit;
  final int todayReceipts;
  final List<DailyPoint> last7Days;
  final List<({String name, double qty})> topProducts;

  DashboardData({
    required this.todaySales,
    required this.todayProfit,
    required this.todayReceipts,
    required this.last7Days,
    required this.topProducts,
  });
}

final dashboardProvider = FutureProvider<DashboardData>((ref) async {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final weekStart = todayStart.subtract(const Duration(days: 6));

  final salesRaw = await sb
      .from('sales')
      .select('id, total, created_at, is_cancelled, '
          'sale_items(qty, price, products(name, buy_price))')
      .gte('created_at', weekStart.toIso8601String())
      .eq('is_cancelled', false);

  final sales = salesRaw as List;

  double todaySales = 0;
  double todayProfit = 0;
  int todayReceipts = 0;
  final Map<String, double> byDay = {
    for (var i = 0; i < 7; i++)
      _dayKey(todayStart.subtract(Duration(days: 6 - i))): 0,
  };
  final Map<String, double> productQty = {};

  for (final row in sales) {
    final createdAt = DateTime.parse(row['created_at'] as String).toLocal();
    final total = (row['total'] as num).toDouble();
    final dayKey = _dayKey(DateTime(createdAt.year, createdAt.month, createdAt.day));
    if (byDay.containsKey(dayKey)) {
      byDay[dayKey] = (byDay[dayKey] ?? 0) + total;
    }

    final isToday = !createdAt.isBefore(todayStart) &&
        createdAt.isBefore(todayStart.add(const Duration(days: 1)));
    if (isToday) {
      todaySales += total;
      todayReceipts += 1;
      final items = (row['sale_items'] as List?) ?? [];
      for (final item in items) {
        final qty = (item['qty'] as num).toDouble();
        final price = (item['price'] as num).toDouble();
        final product = item['products'] as Map<String, dynamic>?;
        final buyPrice = (product?['buy_price'] as num?)?.toDouble() ?? 0;
        todayProfit += (price - buyPrice) * qty;
        final name = product?['name'] as String? ?? 'Noma\'lum';
        productQty[name] = (productQty[name] ?? 0) + qty;
      }
    }
  }

  final last7Days = byDay.entries
      .map((e) => DailyPoint(DateTime.parse(e.key), e.value))
      .toList()
    ..sort((a, b) => a.day.compareTo(b.day));

  final topProducts = productQty.entries
      .map((e) => (name: e.key, qty: e.value))
      .toList()
    ..sort((a, b) => b.qty.compareTo(a.qty));

  return DashboardData(
    todaySales: todaySales,
    todayProfit: todayProfit,
    todayReceipts: todayReceipts,
    last7Days: last7Days,
    topProducts: topProducts.take(5).toList(),
  );
});

String _dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

final dashboardExtrasProvider = Provider((ref) {
  final lowStock = ref.watch(lowStockProvider);
  final totalDebt = ref.watch(totalDebtProvider);
  return (lowStock: lowStock, totalDebt: totalDebt);
});
