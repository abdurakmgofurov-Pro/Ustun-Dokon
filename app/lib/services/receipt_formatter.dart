import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../core/format.dart';
import '../models/models.dart';
import '../models/receipt.dart';
import '../providers/store_settings_provider.dart';

String paymentTypeLabel(PaymentType type) => switch (type) {
      PaymentType.naqd => 'Naqd pul',
      PaymentType.karta => 'Plastik karta',
      PaymentType.qarz => 'Qarzga',
    };

/// [ReceiptData]dan 58/80mm termal printer uchun ESC/POS baytlarini tuzadi.
Future<List<int>> buildReceiptBytes(
    ReceiptData data, StoreSettings settings) async {
  final profile = await CapabilityProfile.load();
  final paperSize =
      settings.paperWidthMm >= 80 ? PaperSize.mm80 : PaperSize.mm58;
  final generator = Generator(paperSize, profile);
  final bytes = <int>[];

  bytes.addAll(generator.text(
    settings.name,
    styles: const PosStyles(
      align: PosAlign.center,
      bold: true,
      height: PosTextSize.size2,
      width: PosTextSize.size2,
    ),
  ));
  if (settings.address.trim().isNotEmpty) {
    bytes.addAll(generator.text(settings.address.trim(),
        styles: const PosStyles(align: PosAlign.center)));
  }
  if (settings.phone.trim().isNotEmpty) {
    bytes.addAll(generator.text(settings.phone.trim(),
        styles: const PosStyles(align: PosAlign.center)));
  }
  bytes.addAll(generator.hr());

  bytes.addAll(generator.row([
    PosColumn(text: 'Chek', width: 6),
    PosColumn(
      text: data.saleId != null ? '#${data.saleId}' : '-',
      width: 6,
      styles: const PosStyles(align: PosAlign.right),
    ),
  ]));
  bytes.addAll(generator.text(formatDateTime(data.createdAt)));
  bytes.addAll(generator.text('Kassir: ${data.cashierName}'));
  bytes.addAll(generator.hr());

  for (final item in data.items) {
    bytes.addAll(generator.text(item.name));
    bytes.addAll(generator.row([
      PosColumn(
        text: '${formatQty(item.qty)} ${item.unit} x ${formatSum(item.price)}',
        width: 8,
      ),
      PosColumn(
        text: formatSum(item.total),
        width: 4,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]));
  }
  bytes.addAll(generator.hr());

  bytes.addAll(generator.row([
    PosColumn(
      text: 'JAMI',
      width: 5,
      styles: const PosStyles(bold: true, height: PosTextSize.size2),
    ),
    PosColumn(
      text: formatSum(data.total),
      width: 7,
      styles: const PosStyles(
          bold: true, align: PosAlign.right, height: PosTextSize.size2),
    ),
  ]));
  bytes.addAll(generator.text('To\'lov: ${paymentTypeLabel(data.paymentType)}'));

  if (data.paymentType == PaymentType.qarz) {
    bytes.addAll(generator.hr(ch: '.'));
    if (data.customerName != null) {
      bytes.addAll(generator.text('Mijoz: ${data.customerName}'));
    }
    if (data.customerTotalDebt != null) {
      bytes.addAll(generator.text(
          'Jami qarzi: ${formatSum(data.customerTotalDebt!)}',
          styles: const PosStyles(bold: true)));
    }
  }

  bytes.addAll(generator.hr());
  bytes.addAll(generator.text(settings.footer,
      styles: const PosStyles(align: PosAlign.center)));
  bytes.addAll(generator.feed(2));
  bytes.addAll(generator.cut());

  return bytes;
}
