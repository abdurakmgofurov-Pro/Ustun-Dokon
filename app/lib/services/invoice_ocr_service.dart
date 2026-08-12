import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'error_log_service.dart';

class ParsedInvoiceLine {
  final String name;
  final double? qty;
  final double? price;
  /// OCR aniqlagan asl matn — foydalaniuvchi qiymatlarni tekshirib,
  /// noto'g'ri joylashgan bo'lsa tez tuzatishi uchun ko'rsatiladi.
  final String rawText;
  ParsedInvoiceLine(
      {required this.name, this.qty, this.price, required this.rawText});
}

/// Nakladnoy (tovar-transport hujjati) suratidan matnni telefonning
/// o'zida (internetsiz, bepul) tanib, jadval qatorlarini (tovar nomi /
/// soni / narxi) ajratishga harakat qiladi. Bu — taxminiy natija:
/// foydalanuvchi har doim natijani tekshirib, kerak bo'lsa tuzatishi
/// kerak, chunki aniqlik surat sifati va nakladnoy formatiga bog'liq.
/// Faqat lotin (o'zbek) alifbosidagi matnni ishonchli tanijdi.
class InvoiceOcrService {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  static final _headerWords = {
    'nomi', 'tovar', 'tovarlar', 'nomlanishi', 'soni', 'miqdori', 'narxi',
    'narx', 'summa', 'jami', 'sana', 'sanasi', 'raqami', 'hujjat',
    'nakladnoy', 'schet', 'faktura', 'kompaniya', 'yetkazib', 'beruvchi',
    'mijoz', 'imzo', 'muhr', 'jsht', 'inn', 'stir', 'birlik', 'olchov',
    'izoh', 'no', 'nо',
  };

  Future<List<String>> recognizeRows(String imagePath) async {
    final InputImage input = InputImage.fromFilePath(imagePath);
    final RecognizedText result;
    try {
      result = await _recognizer.processImage(input);
    } catch (e, st) {
      errorLogService.log('invoice_ocr', e, stackTrace: st);
      rethrow;
    }

    final lines = <({double top, double bottom, double left, String text})>[];
    for (final block in result.blocks) {
      for (final line in block.lines) {
        final box = line.boundingBox;
        lines.add((
          top: box.top.toDouble(),
          bottom: box.bottom.toDouble(),
          left: box.left.toDouble(),
          text: line.text,
        ));
      }
    }
    if (lines.isEmpty) return [];
    lines.sort((a, b) => a.top.compareTo(b.top));

    // Bir xil balandlikdagi (bitta qatorga tegishli) matn bo'laklarini
    // birlashtiramiz — jadval ustunlari ko'pincha alohida "line" sifatida
    // aniqlanadi.
    final rows = <List<({double left, String text})>>[];
    double? rowTop, rowBottom;
    for (final l in lines) {
      final center = (l.top + l.bottom) / 2;
      if (rowTop == null || center > rowBottom!) {
        rows.add([]);
        rowTop = l.top;
        rowBottom = l.bottom;
      } else {
        rowBottom = rowBottom > l.bottom ? rowBottom : l.bottom;
      }
      rows.last.add((left: l.left, text: l.text));
    }

    return rows.map((row) {
      row.sort((a, b) => a.left.compareTo(b.left));
      return row.map((e) => e.text).join('   ');
    }).toList();
  }

  /// OCR orqali olingan qator matnlarini {nomi, soni, narxi} ga ajratadi.
  /// Sarlavha/jami kabi mazmunsiz qatorlarni chiqarib tashlaydi.
  List<ParsedInvoiceLine> parseRows(List<String> rawRows) {
    final numberPattern = RegExp(r'\d[\d .,]*\d|\d');
    final result = <ParsedInvoiceLine>[];

    for (var text in rawRows) {
      final trimmed = text.trim();
      if (trimmed.isEmpty) continue;

      final lower = trimmed.toLowerCase();
      final wordsOnly = lower.replaceAll(RegExp(r'[^a-zA-Zʻʼ\s]'), '').trim();
      if (wordsOnly.isNotEmpty &&
          wordsOnly
              .split(RegExp(r'\s+'))
              .every((w) => _headerWords.contains(w))) {
        continue; // faqat sarlavha so'zlaridan iborat qator
      }

      final matches = numberPattern.allMatches(trimmed).toList();
      final numbers = <double>[];
      for (final m in matches) {
        final v = _parseNumber(m.group(0)!);
        if (v != null) numbers.add(v);
      }

      // Raqami umuman yo'q qator — bu haqiqiy tovar qatori emas (masalan
      // manzil, sarlavha yoki izoh matni), ro'yxatni chalkashtirmaslik
      // uchun o'tkazib yuboramiz.
      if (numbers.isEmpty) continue;

      // Matndan raqamlarni olib tashlab, qolganini nom sifatida olamiz.
      var name = trimmed;
      for (final m in matches.reversed) {
        name = name.replaceRange(m.start, m.end, '');
      }
      name = name.replaceAll(RegExp(r'[|_\-–—.]+'), ' ').trim();
      name = name.replaceAll(RegExp(r'\s+'), ' ');
      name = name.replaceFirst(RegExp(r'^[№#.\s]+'), '').trim();

      if (name.isEmpty || name.length < 2) continue;

      double? qty;
      double? price;
      if (numbers.length >= 3) {
        final a = numbers[numbers.length - 3];
        final b = numbers[numbers.length - 2];
        final c = numbers[numbers.length - 1];
        if (a > 0 && (a * b - c).abs() < (a * b) * 0.02) {
          qty = a;
          price = b;
        } else if (b > 0 && (b * c - a).abs() < (b * c) * 0.02) {
          qty = b;
          price = c;
        } else {
          qty = a;
          price = b;
        }
      } else if (numbers.length == 2) {
        qty = numbers[0];
        price = numbers[1];
      } else if (numbers.length == 1) {
        price = numbers[0];
      }

      result.add(ParsedInvoiceLine(
          name: name, qty: qty, price: price, rawText: trimmed));
    }

    return result;
  }

  double? _parseNumber(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;
    final lastDot = s.lastIndexOf('.');
    final lastComma = s.lastIndexOf(',');
    final lastSep = lastDot > lastComma ? lastDot : lastComma;
    if (lastSep != -1 &&
        s.length - lastSep - 1 <= 2 &&
        s.length - lastSep - 1 > 0) {
      final intPart =
          s.substring(0, lastSep).replaceAll(RegExp(r'[ .,]'), '');
      final decPart = s.substring(lastSep + 1);
      s = '$intPart.$decPart';
    } else {
      s = s.replaceAll(RegExp(r'[ .,]'), '');
    }
    return double.tryParse(s);
  }

  void dispose() => _recognizer.close();
}

final invoiceOcrService = InvoiceOcrService();
