import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase_service.dart';
import '../models/models.dart';
import 'sales_provider.dart';

final cashFilterProvider = StateProvider<SalesFilter>((ref) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  final end = DateTime(now.year, now.month + 1, 1);
  return SalesFilter(from: start, to: end);
});

final cashTransactionsProvider =
    FutureProvider.autoDispose<List<CashTransaction>>((ref) async {
  final filter = ref.watch(cashFilterProvider);
  final data = await sb
      .from('cash_transactions')
      .select()
      .gte('created_at', filter.from.toIso8601String())
      .lt('created_at', filter.to.toIso8601String())
      .order('created_at', ascending: false);
  return (data as List).map((e) => CashTransaction.fromMap(e)).toList();
});

final cashSummaryProvider =
    Provider.autoDispose<({double kirim, double rashod})>((ref) {
  final list = ref.watch(cashTransactionsProvider).valueOrNull ?? [];
  final kirim = list
      .where((e) => e.type == CashType.kirim)
      .fold<double>(0, (s, e) => s + e.amount);
  final rashod = list
      .where((e) => e.type == CashType.rashod)
      .fold<double>(0, (s, e) => s + e.amount);
  return (kirim: kirim, rashod: rashod);
});

/// Kassadagi hozirgi qoldiq (barcha davr, filtrdan mustaqil): naqd va karta
/// alohida — har bir kirim/rashod yozuvining `payment_method` bo'yicha.
class CashOnHand {
  final double cash;
  final double card;
  const CashOnHand({required this.cash, required this.card});

  double get total => cash + card;
}

Future<List<Map<String, dynamic>>> _fetchAll(
    Future<List<dynamic>> Function(int from, int to) page) async {
  const pageSize = 1000;
  final rows = <Map<String, dynamic>>[];
  for (var from = 0;; from += pageSize) {
    final chunk = await page(from, from + pageSize - 1);
    rows.addAll(chunk.cast<Map<String, dynamic>>());
    if (chunk.length < pageSize) break;
  }
  return rows;
}

final cashOnHandProvider =
    FutureProvider.autoDispose<CashOnHand>((ref) async {
  // Yozuv qo'shilsa/o'chirilsa (cashTransactionsProvider yangilansa) qayta hisoblanadi.
  ref.watch(cashTransactionsProvider);

  final tx = await _fetchAll((from, to) => sb
      .from('cash_transactions')
      .select('type, amount, payment_method')
      .order('id')
      .range(from, to));
  var cash = 0.0;
  var card = 0.0;
  for (final r in tx) {
    final amount = (r['amount'] as num).toDouble();
    final signed = r['type'] == 'kirim' ? amount : -amount;
    if (r['payment_method'] == 'karta') {
      card += signed;
    } else {
      cash += signed;
    }
  }
  return CashOnHand(cash: cash, card: card);
});

/// Xarajatlar hisoboti ekranida tanlangan oy (har doim oyning 1-kuni).
final expenseReportMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

class ExpenseCategoryTotal {
  final String category;
  final double amount;
  const ExpenseCategoryTotal({required this.category, required this.amount});
}

/// Tanlangan oy uchun savdo/tannarx/xarajat/foyda xulosasi.
class MonthlyProfitSummary {
  final double revenue;
  final double cost;
  final double expenses;
  const MonthlyProfitSummary({
    required this.revenue,
    required this.cost,
    required this.expenses,
  });

  /// Yalpi foyda: savdo summasidan tovarlar tannarxini ayirish.
  double get grossProfit => revenue - cost;

  /// Sof foyda: yalpi foydadan boshqa xarajatlarni (ijara, ish haqi va h.k.) ayirish.
  double get netProfit => grossProfit - expenses;
}

/// Tanlangan oydagi (bekor qilinmagan) savdolar bo'yicha jami sotuv,
/// tovarlar tannarxi (sale_items.cost — sotilgan paytdagi kirim narxi)
/// va shu oydagi rashodlarni hisoblab, foyda xulosasini qaytaradi.
final profitReportProvider = FutureProvider<MonthlyProfitSummary>((ref) async {
  final month = ref.watch(expenseReportMonthProvider);
  final nextMonth = DateTime(month.year, month.month + 1, 1);

  final salesData = await sb
      .from('sales')
      .select('total, sale_items(qty, cost)')
      .gte('created_at', month.toIso8601String())
      .lt('created_at', nextMonth.toIso8601String())
      .eq('is_cancelled', false);

  double revenue = 0;
  double cost = 0;
  for (final row in (salesData as List)) {
    final map = row as Map<String, dynamic>;
    revenue += (map['total'] as num).toDouble();
    final items = (map['sale_items'] as List?) ?? const [];
    for (final it in items) {
      final m = it as Map<String, dynamic>;
      cost += (m['qty'] as num).toDouble() * (m['cost'] as num).toDouble();
    }
  }

  final expensesData = await sb
      .from('cash_transactions')
      .select('amount')
      .eq('type', 'rashod')
      .gte('created_at', month.toIso8601String())
      .lt('created_at', nextMonth.toIso8601String());
  double expenses = 0;
  for (final row in (expensesData as List)) {
    expenses += ((row as Map<String, dynamic>)['amount'] as num).toDouble();
  }

  return MonthlyProfitSummary(revenue: revenue, cost: cost, expenses: expenses);
});

/// Tanlangan oydagi rashodlarni kategoriya bo'yicha guruhlab, kamayish
/// tartibida qaytaradi.
final expenseReportProvider =
    FutureProvider<List<ExpenseCategoryTotal>>((ref) async {
  final month = ref.watch(expenseReportMonthProvider);
  final nextMonth = DateTime(month.year, month.month + 1, 1);
  final data = await sb
      .from('cash_transactions')
      .select()
      .eq('type', 'rashod')
      .gte('created_at', month.toIso8601String())
      .lt('created_at', nextMonth.toIso8601String());

  final totals = <String, double>{};
  for (final e in (data as List)) {
    final tx = CashTransaction.fromMap(e as Map<String, dynamic>);
    totals[tx.category] = (totals[tx.category] ?? 0) + tx.amount;
  }
  final result = totals.entries
      .map((e) => ExpenseCategoryTotal(category: e.key, amount: e.value))
      .toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));
  return result;
});

const expenseCategories = [
  'ijaraq',
  'ish_haqi',
  'kommunal',
  'tovar_xaridi',
  'transport',
  'boshqa',
];

const incomeCategories = [
  'kapital',
  'boshqa_daromad',
];

String cashCategoryLabel(String key) {
  const labels = {
    'ijaraq': 'Ijara',
    'ish_haqi': 'Ish haqi',
    'kommunal': 'Kommunal',
    'tovar_xaridi': 'Tovar xaridi',
    'transport': 'Transport',
    'boshqa': 'Boshqa',
    'kapital': 'Kapital kiritish',
    'boshqa_daromad': 'Boshqa daromad',
    'savdo': 'Savdo',
    'qarz_tolovi': 'Qarz to\'lovi',
  };
  return labels[key] ?? key;
}

class CashController {
  Future<String?> addTransaction({
    required CashType type,
    required double amount,
    required String category,
    String? note,
    String paymentMethod = 'naqd',
  }) async {
    try {
      final uid = sb.auth.currentUser?.id;
      await sb.from('cash_transactions').insert({
        'type': type.name,
        'amount': amount,
        'category': category,
        'note': note,
        'payment_method': paymentMethod,
        'created_by': uid,
      });
      return null;
    } catch (e) {
      return 'Yozuvni saqlashda xatolik: $e';
    }
  }

  Future<String?> deleteTransaction(int id) async {
    try {
      await sb.from('cash_transactions').delete().eq('id', id);
      return null;
    } catch (e) {
      return 'O\'chirishda xatolik: $e';
    }
  }
}

final cashControllerProvider = Provider((ref) => CashController());
