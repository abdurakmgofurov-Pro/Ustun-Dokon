import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase_service.dart';
import '../models/models.dart';

final customersProvider = FutureProvider<List<Customer>>((ref) async {
  final data = await sb.from('customers').select().order('full_name');
  return (data as List).map((e) => Customer.fromMap(e)).toList();
});

final debtorsProvider = Provider<List<Customer>>((ref) {
  final customers = ref.watch(customersProvider).valueOrNull ?? [];
  return customers.where((c) => c.totalDebt > 0).toList()
    ..sort((a, b) => b.totalDebt.compareTo(a.totalDebt));
});

/// Qarz to'langach tovar qaytarilib sotuv bekor qilingan mijozlar: ularning
/// qoldig'i manfiy — do'kon mijozga shuncha qarz (qaytarilishi kerak).
final creditorsProvider = Provider<List<Customer>>((ref) {
  final customers = ref.watch(customersProvider).valueOrNull ?? [];
  return customers.where((c) => c.totalDebt < 0).toList()
    ..sort((a, b) => a.totalDebt.compareTo(b.totalDebt));
});

final totalDebtProvider = Provider<double>((ref) {
  final debtors = ref.watch(debtorsProvider);
  return debtors.fold<double>(0, (sum, c) => sum + c.totalDebt);
});

final customerDebtEntriesProvider =
    FutureProvider.family<List<DebtEntry>, int>((ref, customerId) async {
  final data = await sb
      .from('debt_entries')
      .select()
      .eq('customer_id', customerId)
      .order('created_at', ascending: false);
  return (data as List).map((e) => DebtEntry.fromMap(e)).toList();
});

final customerDebtPaymentsProvider =
    FutureProvider.family<List<DebtPayment>, int>((ref, customerId) async {
  final data = await sb
      .from('debt_payments')
      .select()
      .eq('customer_id', customerId)
      .order('created_at', ascending: false);
  return (data as List).map((e) => DebtPayment.fromMap(e)).toList();
});

final customerSalesProvider =
    FutureProvider.family<List<Sale>, int>((ref, customerId) async {
  final data = await sb
      .from('sales')
      .select('*, profiles(full_name), customers(full_name)')
      .eq('customer_id', customerId)
      .order('created_at', ascending: false);
  return (data as List).map((e) => Sale.fromMap(e)).toList();
});

class CustomerController {
  Future<Customer?> addCustomer({
    required String fullName,
    String? phone,
    String? note,
  }) async {
    try {
      final data = await sb
          .from('customers')
          .insert({
            'full_name': fullName,
            'phone': (phone == null || phone.isEmpty) ? null : phone,
            'note': note,
          })
          .select()
          .single();
      return Customer.fromMap(data);
    } catch (_) {
      return null;
    }
  }

  /// Mijozga savdosiz qarz qo'shadi (faqat admin, serverda tekshiriladi).
  Future<String?> addDebt({
    required int customerId,
    required double amount,
    String? note,
  }) async {
    try {
      await sb.rpc('add_customer_debt', params: {
        'p_customer_id': customerId,
        'p_amount': amount,
        'p_note': note,
      });
      return null;
    } catch (e) {
      return "Qarz qo'shishda xatolik: $e";
    }
  }

  /// Mijozga ortiqcha to'langan pulni qaytaradi (faqat admin, serverda
  /// tekshiriladi): kassaga rashod yoziladi va mijoz qoldig'i kamayadi.
  Future<String?> refund({
    required int customerId,
    required double amount,
    String paymentMethod = 'naqd',
  }) async {
    try {
      await sb.rpc('refund_customer', params: {
        'p_customer_id': customerId,
        'p_amount': amount,
        'p_method': paymentMethod,
      });
      return null;
    } catch (e) {
      return "Pulni qaytarishda xatolik: $e";
    }
  }

  Future<String?> payDebt({
    required int customerId,
    required double amount,
    String? note,
    String paymentMethod = 'naqd',
  }) async {
    try {
      final uid = sb.auth.currentUser?.id;
      await sb.from('debt_payments').insert({
        'customer_id': customerId,
        'amount': amount,
        'note': note,
        'payment_method': paymentMethod,
        'created_by': uid,
      });
      return null;
    } catch (e) {
      return 'To\'lovni saqlashda xatolik: $e';
    }
  }
}

final customerControllerProvider = Provider((ref) => CustomerController());
