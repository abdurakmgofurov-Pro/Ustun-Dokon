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
