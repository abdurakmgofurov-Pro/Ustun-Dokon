import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void add(Product product) {
    final idx = state.indexWhere((c) => c.product.id == product.id);
    if (idx >= 0) {
      final item = state[idx];
      if (item.qty + 1 > product.stock) return;
      state = [
        for (var i = 0; i < state.length; i++)
          if (i == idx) CartItem(product: item.product, qty: item.qty + 1) else state[i]
      ];
    } else {
      if (product.stock <= 0) return;
      state = [...state, CartItem(product: product)];
    }
  }

  void setQty(int productId, double qty) {
    if (qty <= 0) {
      remove(productId);
      return;
    }
    state = [
      for (final c in state)
        if (c.product.id == productId) CartItem(product: c.product, qty: qty) else c
    ];
  }

  void remove(int productId) {
    state = state.where((c) => c.product.id != productId).toList();
  }

  void clear() {
    state = [];
  }

  double get total => state.fold(0, (s, c) => s + c.total);
}

final cartProvider =
    StateNotifierProvider<CartNotifier, List<CartItem>>((ref) => CartNotifier());

final cartTotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0, (s, c) => s + c.total);
});
