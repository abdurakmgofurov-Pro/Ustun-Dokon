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

final totalDebtProvider = Provider<double>((ref) {
  final debtors = ref.watch(debtorsProvider);
  return debtors.fold<double>(0, (sum, c) => sum + c.totalDebt);
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

  Future<String?> payDebt({
    required int customerId,
    required double amount,
    String? note,
  }) async {
    try {
      final uid = sb.auth.currentUser?.id;
      await sb.from('debt_payments').insert({
        'customer_id': customerId,
        'amount': amount,
        'note': note,
        'created_by': uid,
      });
      return null;
    } catch (e) {
      return 'To\'lovni saqlashda xatolik: $e';
    }
  }
}

final customerControllerProvider = Provider((ref) => CustomerController());
