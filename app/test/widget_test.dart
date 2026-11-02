import 'package:flutter_test/flutter_test.dart';
import 'package:ustun_dokon/models/models.dart';
import 'package:ustun_dokon/providers/cart_provider.dart';

Product _product(int id, {double price = 1000, double stock = 5}) => Product(
      id: id,
      name: 'Tovar $id',
      unit: 'dona',
      buyPrice: 600,
      sellPrice: price,
      stock: stock,
      minStock: 2,
      isActive: true,
    );

void main() {
  group('CartNotifier', () {
    test("bir xil tovar qo'shilsa miqdor oshadi va jami to'g'ri hisoblanadi", () {
      final cart = CartNotifier();
      final p = _product(1, price: 2500);
      cart.add(p);
      cart.add(p);
      expect(cart.state.length, 1);
      expect(cart.state.first.qty, 2);
      expect(cart.total, 5000);
    });

    test('qoldiqdan ortiq qo\'shib bo\'lmaydi', () {
      final cart = CartNotifier();
      final p = _product(1, stock: 2);
      cart.add(p);
      cart.add(p);
      cart.add(p);
      expect(cart.state.first.qty, 2);
    });

    test("qoldig'i 0 bo'lgan tovar savatga tushmaydi", () {
      final cart = CartNotifier();
      cart.add(_product(1, stock: 0));
      expect(cart.state, isEmpty);
    });

    test("setQty 0 yoki manfiy bo'lsa tovar o'chadi", () {
      final cart = CartNotifier();
      cart.add(_product(1));
      cart.setQty(1, 0);
      expect(cart.state, isEmpty);
    });

    test('setQty kasr miqdorni (kg) qabul qiladi', () {
      final cart = CartNotifier();
      cart.add(_product(1, price: 10000));
      cart.setQty(1, 1.5);
      expect(cart.total, 15000);
    });

    test("remove va clear savatni tozalaydi", () {
      final cart = CartNotifier();
      cart.add(_product(1));
      cart.add(_product(2));
      cart.remove(1);
      expect(cart.state.map((c) => c.product.id), [2]);
      cart.clear();
      expect(cart.state, isEmpty);
    });
  });

  group('Product', () {
    test('isLowStock minimal chegarada ham true', () {
      expect(_product(1, stock: 2).isLowStock, true);
      expect(_product(1, stock: 3).isLowStock, false);
    });

    test("fromMap bo'sh maydonlarga standart qiymat qo'yadi", () {
      final p = Product.fromMap({'id': 7, 'name': 'Non'});
      expect(p.unit, 'dona');
      expect(p.sellPrice, 0);
      expect(p.stock, 0);
      expect(p.isActive, true);
    });
  });
}
