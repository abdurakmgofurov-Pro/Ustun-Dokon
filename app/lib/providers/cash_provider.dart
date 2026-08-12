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
    FutureProvider<List<CashTransaction>>((ref) async {
  final filter = ref.watch(cashFilterProvider);
  final data = await sb
      .from('cash_transactions')
      .select()
      .gte('created_at', filter.from.toIso8601String())
      .lt('created_at', filter.to.toIso8601String())
      .order('created_at', ascending: false);
  return (data as List).map((e) => CashTransaction.fromMap(e)).toList();
});

final cashSummaryProvider = Provider<({double kirim, double rashod})>((ref) {
  final list = ref.watch(cashTransactionsProvider).valueOrNull ?? [];
  final kirim = list
      .where((e) => e.type == CashType.kirim)
      .fold<double>(0, (s, e) => s + e.amount);
  final rashod = list
      .where((e) => e.type == CashType.rashod)
      .fold<double>(0, (s, e) => s + e.amount);
  return (kirim: kirim, rashod: rashod);
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
  }) async {
    try {
      final uid = sb.auth.currentUser?.id;
      await sb.from('cash_transactions').insert({
        'type': type.name,
        'amount': amount,
        'category': category,
        'note': note,
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
