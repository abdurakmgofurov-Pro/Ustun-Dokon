import 'dart:convert';
import 'package:http/http.dart' as http;

/// Shtrix-kod bo'yicha ochiq internet bazasidan (Open Food Facts) tovar
/// nomini topishga harakat qiladi. Topilmasa yoki internet bo'lmasa
/// `null` qaytaradi — bu holda foydalanuvchi nomni qo'lda kiritadi.
class BarcodeLookupService {
  Future<String?> lookupName(String barcode) async {
    try {
      final uri = Uri.parse(
          'https://world.openfoodfacts.org/api/v2/product/$barcode.json?fields=product_name,product_name_en,brands');
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['status'] != 1) return null;
      final product = data['product'] as Map<String, dynamic>?;
      if (product == null) return null;
      final name = (product['product_name'] as String?)?.trim();
      final nameEn = (product['product_name_en'] as String?)?.trim();
      final brand = (product['brands'] as String?)?.trim();
      final best = (name != null && name.isNotEmpty)
          ? name
          : (nameEn != null && nameEn.isNotEmpty)
              ? nameEn
              : null;
      if (best == null) return null;
      return (brand != null && brand.isNotEmpty && !best.toLowerCase().contains(brand.toLowerCase()))
          ? '$best ($brand)'
          : best;
    } catch (_) {
      return null;
    }
  }
}

final barcodeLookupService = BarcodeLookupService();
