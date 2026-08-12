import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_service.dart';
import '../models/models.dart';
import '../services/error_log_service.dart';

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final data = await sb.from('categories').select().order('name');
  return (data as List).map((e) => Category.fromMap(e)).toList();
});

final productsProvider = FutureProvider<List<Product>>((ref) async {
  final data = await sb
      .from('products')
      .select('*, categories(name)')
      .order('name');
  return (data as List).map((e) => Product.fromMap(e)).toList();
});

final lowStockProvider = Provider<List<Product>>((ref) {
  final products = ref.watch(productsProvider).valueOrNull ?? [];
  return products.where((p) => p.isLowStock).toList();
});

class CatalogController {
  Future<String?> addCategory(String name) async {
    try {
      await sb.from('categories').insert({'name': name});
      return null;
    } on PostgrestException catch (e, st) {
      if (e.code == '23505') {
        return '"$name" nomli kategoriya allaqachon mavjud';
      }
      errorLogService.log('add_category', e, stackTrace: st);
      return 'Kategoriya qo\'shishda xatolik: ${e.message}';
    } catch (e, st) {
      errorLogService.log('add_category', e, stackTrace: st);
      return 'Kategoriya qo\'shishda xatolik: $e';
    }
  }

  Future<String?> upsertProduct({
    int? id,
    required String name,
    int? categoryId,
    required String unit,
    String? barcode,
    required double buyPrice,
    required double sellPrice,
    required double stock,
    required double minStock,
  }) async {
    try {
      final payload = {
        'name': name,
        'category_id': categoryId,
        'unit': unit,
        'barcode': (barcode == null || barcode.isEmpty) ? null : barcode,
        'buy_price': buyPrice,
        'sell_price': sellPrice,
        'stock': stock,
        'min_stock': minStock,
      };
      if (id == null) {
        await sb.from('products').insert(payload);
      } else {
        await sb.from('products').update(payload).eq('id', id);
      }
      return null;
    } on PostgrestException catch (e, st) {
      if (e.code == '23505') {
        return 'Bu shtrix-kod bilan boshqa tovar allaqachon mavjud. '
            'Tovarlar ro\'yxatida shu shtrix-kodni skanerlab, mavjud '
            'tovarni tahrirlang.';
      }
      errorLogService.log('upsert_product', e, stackTrace: st);
      return 'Mahsulotni saqlashda xatolik: ${e.message}';
    } catch (e, st) {
      errorLogService.log('upsert_product', e, stackTrace: st);
      return 'Mahsulotni saqlashda xatolik: $e';
    }
  }

  Future<String?> setProductActive(int id, bool isActive) async {
    try {
      await sb.from('products').update({'is_active': isActive}).eq('id', id);
      return null;
    } catch (e, st) {
      errorLogService.log('set_product_active', e, stackTrace: st);
      return 'Xatolik: $e';
    }
  }

  Future<String?> deleteProduct(int id) async {
    try {
      await sb.from('products').delete().eq('id', id);
      return null;
    } catch (e, st) {
      errorLogService.log('delete_product', e, stackTrace: st);
      return 'O\'chirishda xatolik: $e';
    }
  }
}

final catalogControllerProvider = Provider((ref) => CatalogController());
