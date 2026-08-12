import 'package:intl/intl.dart';

final _sum = NumberFormat('#,##0.##');
final _date = DateFormat('dd.MM.yyyy');
final _dateTime = DateFormat('dd.MM.yyyy HH:mm');

String formatSum(num value) =>
    "${_sum.format(value).replaceAll(',', ' ')} so'm";

String formatQty(num value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  var s = value.toStringAsFixed(3);
  s = s.replaceFirst(RegExp(r'0+$'), '');
  s = s.replaceFirst(RegExp(r'\.$'), '');
  return s;
}

String formatDate(DateTime dt) => _date.format(dt.toLocal());

String formatDateTime(DateTime dt) => _dateTime.format(dt.toLocal());
