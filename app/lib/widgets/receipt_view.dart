import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/receipt.dart';
import '../providers/store_settings_provider.dart';
import '../services/receipt_formatter.dart';
import '../services/receipt_printer_service.dart';

/// Haqiqiy qog'oz chekka o'xshab ko'rinadigan vizual chek — oq fon, qora
/// matn, monospace shrift, chiziqli ajratgichlar bilan. Tema (light/dark)
/// dan qat'i nazar doim oq qog'oz ko'rinishida bo'ladi.
class ReceiptView extends StatelessWidget {
  final ReceiptData data;
  final StoreSettings settings;
  const ReceiptView({super.key, required this.data, required this.settings});

  static const _mono = TextStyle(
    fontFamily: 'monospace',
    color: Colors.black,
    fontSize: 13,
    height: 1.4,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(settings.name,
              textAlign: TextAlign.center,
              style: _mono.copyWith(
                  fontWeight: FontWeight.bold, fontSize: 17)),
          if (settings.address.trim().isNotEmpty)
            Text(settings.address.trim(),
                textAlign: TextAlign.center, style: _mono),
          if (settings.phone.trim().isNotEmpty)
            Text(settings.phone.trim(),
                textAlign: TextAlign.center, style: _mono),
          const _Dashes(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Chek', style: _mono),
              Text(data.saleId != null ? '#${data.saleId}' : '-',
                  style: _mono),
            ],
          ),
          Text(formatDateTime(data.createdAt), style: _mono),
          Text('Kassir: ${data.cashierName}', style: _mono),
          const _Dashes(),
          for (final item in data.items) ...[
            Text(item.name, style: _mono),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    '${formatQty(item.qty)} ${item.unit} x ${formatSum(item.price)}',
                    style: _mono),
                Text(formatSum(item.total), style: _mono),
              ],
            ),
            const SizedBox(height: 2),
          ],
          const _Dashes(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('JAMI',
                  style: _mono.copyWith(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              Text(formatSum(data.total),
                  style: _mono.copyWith(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          Text('To\'lov: ${paymentTypeLabel(data.paymentType)}', style: _mono),
          if (data.paymentType.name == 'qarz') ...[
            const _Dashes(dotted: true),
            if (data.customerName != null)
              Text('Mijoz: ${data.customerName}', style: _mono),
            if (data.customerTotalDebt != null)
              Text('Jami qarzi: ${formatSum(data.customerTotalDebt!)}',
                  style: _mono.copyWith(fontWeight: FontWeight.bold)),
          ],
          const _Dashes(),
          Text(settings.footer,
              textAlign: TextAlign.center, style: _mono),
        ],
      ),
    );
  }
}

class _Dashes extends StatelessWidget {
  final bool dotted;
  const _Dashes({this.dotted = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        (dotted ? '. ' : '-') * (dotted ? 21 : 42),
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: ReceiptView._mono.copyWith(fontSize: 11),
      ),
    );
  }
}

/// Chekni ekranda ko'rsatadi va "Chop etish" tugmasi orqali Bluetooth
/// printerga yuborish imkonini beradi.
Future<void> showReceiptSheet(
  BuildContext context,
  WidgetRef ref,
  ReceiptData data,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReceiptSheet(data: data),
  );
}

class _ReceiptSheet extends ConsumerStatefulWidget {
  final ReceiptData data;
  const _ReceiptSheet({required this.data});

  @override
  ConsumerState<_ReceiptSheet> createState() => _ReceiptSheetState();
}

class _ReceiptSheetState extends ConsumerState<_ReceiptSheet> {
  bool _printing = false;

  Future<void> _print() async {
    setState(() => _printing = true);
    final settings = ref.read(storeSettingsProvider);
    final bytes = await buildReceiptBytes(widget.data, settings);
    final error = await receiptPrinterService.printBytes(bytes);
    if (!mounted) return;
    setState(() => _printing = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.danger),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Chek printerga yuborildi'),
        backgroundColor: AppColors.primary,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(storeSettingsProvider);
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Chek',
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: ReceiptView(data: widget.data, settings: settings),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: ElevatedButton.icon(
                  onPressed: _printing ? null : _print,
                  icon: _printing
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.print_outlined),
                  label: Text(_printing ? 'Yuborilmoqda...' : 'Chop etish'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
