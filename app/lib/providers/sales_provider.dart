import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase_service.dart';
import '../models/models.dart';

class SalesFilter {
  final DateTime from;
  final DateTime to;
  const SalesFilter({required this.from, required this.to});
}

final salesFilterProvider = StateProvider<SalesFilter>((ref) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  return SalesFilter(from: start, to: start.add(const Duration(days: 1)));
});

final salesListProvider = FutureProvider<List<Sale>>((ref) async {
  final filter = ref.watch(salesFilterProvider);
  final data = await sb
      .from('sales')
      .select('*, profiles(full_name), customers(full_name)')
      .gte('created_at', filter.from.toIso8601String())
      .lt('created_at', filter.to.toIso8601String())
      .order('created_at', ascending: false);
  return (data as List).map((e) => Sale.fromMap(e)).toList();
});

class SaleItemRow {
  final int id;
  final String productName;
  final double qty;
  final double price;

  SaleItemRow({
    required this.id,
    required this.productName,
    required this.qty,
    required this.price,
  });

  double get total => qty * price;

  factory SaleItemRow.fromMap(Map<String, dynamic> map) => SaleItemRow(
        id: map['id'] as int,
        productName:
            (map['products'] as Map<String, dynamic>?)?['name'] as String? ??
                '',
        qty: (map['qty'] as num).toDouble(),
        price: (map['price'] as num).toDouble(),
      );
}

final saleItemsProvider =
    FutureProvider.family<List<SaleItemRow>, int>((ref, saleId) async {
  final data = await sb
      .from('sale_items')
      .select('*, products(name)')
      .eq('sale_id', saleId);
  return (data as List).map((e) => SaleItemRow.fromMap(e)).toList();
});

class CheckoutResult {
  final int? saleId;
  final String? error;
  const CheckoutResult({this.saleId, this.error});
}

class SalesController {
  Future<CheckoutResult> checkout({
    required List<CartItem> cart,
    required PaymentType paymentType,
    int? customerId,
  }) async {
    if (cart.isEmpty) {
      return const CheckoutResult(error: 'Savat bo\'sh');
    }
    try {
      final saleId = await sb.rpc('create_sale', params: {
        'p_payment_type': paymentType.name,
        'p_customer_id': customerId,
        'p_items': cart
            .map((c) => {
                  'product_id': c.product.id,
                  'qty': c.qty,
                  'price': c.product.sellPrice,
                })
            .toList(),
      });
      return CheckoutResult(saleId: saleId as int?);
    } catch (e) {
      return CheckoutResult(
          error: e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<String?> cancelSale(int saleId) async {
    try {
      await sb.from('sales').update({'is_cancelled': true}).eq('id', saleId);
      return null;
    } catch (e) {
      return 'Bekor qilishda xatolik: $e';
    }
  }
}

final salesControllerProvider = Provider((ref) => SalesController());
