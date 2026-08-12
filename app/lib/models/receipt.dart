import 'models.dart';

class ReceiptItem {
  final String name;
  final double qty;
  final String unit;
  final double price;

  ReceiptItem({
    required this.name,
    required this.qty,
    required this.unit,
    required this.price,
  });

  double get total => qty * price;
}

/// Chekni ekranda ko'rsatish va printerga chiqarish uchun kerak bo'ladigan
/// barcha ma'lumotlar — savdo checkout bo'lgan zahoti savat asosida yoki
/// tarixdan qayta chop etish uchun saqlangan sotuv asosida tuziladi.
class ReceiptData {
  final int? saleId;
  final DateTime createdAt;
  final String cashierName;
  final PaymentType paymentType;
  final String? customerName;
  final double? customerTotalDebt;
  final List<ReceiptItem> items;
  final double total;

  ReceiptData({
    this.saleId,
    required this.createdAt,
    required this.cashierName,
    required this.paymentType,
    this.customerName,
    this.customerTotalDebt,
    required this.items,
    required this.total,
  });
}
