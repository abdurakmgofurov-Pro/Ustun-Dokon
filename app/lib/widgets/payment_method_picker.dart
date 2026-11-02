import 'package:flutter/material.dart';

/// Pul qaysi usulda kirgani/chiqqanini tanlash: 'naqd' yoki 'karta'.
class PaymentMethodPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const PaymentMethodPicker(
      {super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
            value: 'naqd', label: Text('Naqd'), icon: Icon(Icons.payments_outlined)),
        ButtonSegment(
            value: 'karta', label: Text('Karta'), icon: Icon(Icons.credit_card)),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

String paymentMethodLabel(String method) => method == 'karta' ? 'Karta' : 'Naqd';
