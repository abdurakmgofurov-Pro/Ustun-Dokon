enum UserRole { admin, sotuvchi }

UserRole userRoleFromString(String value) =>
    value == 'admin' ? UserRole.admin : UserRole.sotuvchi;

class AppProfile {
  final String id;
  final String fullName;
  final UserRole role;
  final bool isActive;

  AppProfile({
    required this.id,
    required this.fullName,
    required this.role,
    required this.isActive,
  });

  factory AppProfile.fromMap(Map<String, dynamic> map) => AppProfile(
        id: map['id'] as String,
        fullName: map['full_name'] as String? ?? '',
        role: userRoleFromString(map['role'] as String? ?? 'sotuvchi'),
        isActive: map['is_active'] as bool? ?? true,
      );
}

class Category {
  final int id;
  final String name;

  Category({required this.id, required this.name});

  factory Category.fromMap(Map<String, dynamic> map) => Category(
        id: map['id'] as int,
        name: map['name'] as String,
      );
}

class Product {
  final int id;
  final String name;
  final int? categoryId;
  final String? categoryName;
  final String unit;
  final String? barcode;
  final double buyPrice;
  final double sellPrice;
  final double stock;
  final double minStock;
  final bool isActive;

  Product({
    required this.id,
    required this.name,
    this.categoryId,
    this.categoryName,
    required this.unit,
    this.barcode,
    required this.buyPrice,
    required this.sellPrice,
    required this.stock,
    required this.minStock,
    required this.isActive,
  });

  bool get isLowStock => stock <= minStock;

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: map['id'] as int,
        name: map['name'] as String,
        categoryId: map['category_id'] as int?,
        categoryName: (map['categories'] as Map<String, dynamic>?)?['name']
            as String?,
        unit: map['unit'] as String? ?? 'dona',
        barcode: map['barcode'] as String?,
        buyPrice: (map['buy_price'] as num?)?.toDouble() ?? 0,
        sellPrice: (map['sell_price'] as num?)?.toDouble() ?? 0,
        stock: (map['stock'] as num?)?.toDouble() ?? 0,
        minStock: (map['min_stock'] as num?)?.toDouble() ?? 0,
        isActive: map['is_active'] as bool? ?? true,
      );
}

class Customer {
  final int id;
  final String fullName;
  final String? phone;
  final String? note;
  final double totalDebt;

  Customer({
    required this.id,
    required this.fullName,
    this.phone,
    this.note,
    required this.totalDebt,
  });

  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
        id: map['id'] as int,
        fullName: map['full_name'] as String,
        phone: map['phone'] as String?,
        note: map['note'] as String?,
        totalDebt: (map['total_debt'] as num?)?.toDouble() ?? 0,
      );
}

enum PaymentType { naqd, karta, qarz }

PaymentType paymentTypeFromString(String value) => PaymentType.values
    .firstWhere((e) => e.name == value, orElse: () => PaymentType.naqd);

class CartItem {
  final Product product;
  double qty;

  CartItem({required this.product, this.qty = 1});

  double get total => product.sellPrice * qty;
}

class Sale {
  final int id;
  final String? cashierId;
  final String? cashierName;
  final int? customerId;
  final String? customerName;
  final double total;
  final PaymentType paymentType;
  final bool isCancelled;
  final DateTime createdAt;

  Sale({
    required this.id,
    this.cashierId,
    this.cashierName,
    this.customerId,
    this.customerName,
    required this.total,
    required this.paymentType,
    required this.isCancelled,
    required this.createdAt,
  });

  factory Sale.fromMap(Map<String, dynamic> map) => Sale(
        id: map['id'] as int,
        cashierId: map['cashier_id'] as String?,
        cashierName: (map['profiles'] as Map<String, dynamic>?)?['full_name']
            as String?,
        customerId: map['customer_id'] as int?,
        customerName: (map['customers'] as Map<String, dynamic>?)?['full_name']
            as String?,
        total: (map['total'] as num?)?.toDouble() ?? 0,
        paymentType:
            paymentTypeFromString(map['payment_type'] as String? ?? 'naqd'),
        isCancelled: map['is_cancelled'] as bool? ?? false,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

enum CashType { kirim, rashod }

CashType cashTypeFromString(String value) =>
    value == 'kirim' ? CashType.kirim : CashType.rashod;

class CashTransaction {
  final int id;
  final CashType type;
  final double amount;
  final String category;
  final String? note;
  final DateTime createdAt;

  CashTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    this.note,
    required this.createdAt,
  });

  factory CashTransaction.fromMap(Map<String, dynamic> map) =>
      CashTransaction(
        id: map['id'] as int,
        type: cashTypeFromString(map['type'] as String? ?? 'kirim'),
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        category: map['category'] as String? ?? 'boshqa',
        note: map['note'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

class DebtPayment {
  final int id;
  final int customerId;
  final double amount;
  final String? note;
  final DateTime createdAt;

  DebtPayment({
    required this.id,
    required this.customerId,
    required this.amount,
    this.note,
    required this.createdAt,
  });

  factory DebtPayment.fromMap(Map<String, dynamic> map) => DebtPayment(
        id: map['id'] as int,
        customerId: map['customer_id'] as int,
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        note: map['note'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
