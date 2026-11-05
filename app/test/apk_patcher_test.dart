import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ustun_dokon/services/apk_patcher.dart';

/// UDP2 patchini qo'lda yig'adi (tools/release.py bilan bir xil format).
Uint8List _buildPatch({
  required int newSize,
  required List<List<int>> ctrl,
  required List<int> diff,
  required List<int> extra,
  int chunk = 4,
}) {
  final c = BytesBuilder();
  for (final t in ctrl) {
    final b = ByteData(24);
    for (var i = 0; i < 3; i++) {
      b.setInt64(i * 8, t[i], Endian.little);
    }
    c.add(b.buffer.asUint8List());
  }
  final ctrlZ = zlib.encode(c.toBytes());
  final extraZ = zlib.encode(extra);
  final chunks = <List<int>>[
    for (var i = 0; i < diff.length; i += chunk)
      zlib.encode(diff.sublist(i, i + chunk > diff.length ? diff.length : i + chunk))
  ];
  final h = ByteData(52 + 4 * chunks.length);
  h.setUint8(0, 'U'.codeUnitAt(0));
  h.setUint8(1, 'D'.codeUnitAt(0));
  h.setUint8(2, 'P'.codeUnitAt(0));
  h.setUint8(3, '2'.codeUnitAt(0));
  h.setUint64(4, newSize, Endian.little);
  h.setUint64(12, ctrl.length, Endian.little);
  h.setUint64(20, ctrlZ.length, Endian.little);
  h.setUint64(28, extraZ.length, Endian.little);
  h.setUint64(36, extra.length, Endian.little);
  h.setUint32(44, chunk, Endian.little);
  h.setUint32(48, chunks.length, Endian.little);
  for (var i = 0; i < chunks.length; i++) {
    h.setUint32(52 + 4 * i, chunks[i].length, Endian.little);
  }
  final out = BytesBuilder()
    ..add(h.buffer.asUint8List())
    ..add(ctrlZ)
    ..add(extraZ);
  for (final ch in chunks) {
    out.add(ch);
  }
  return out.toBytes();
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('patch_test'));
  tearDown(() => tmp.deleteSync(recursive: true));

  String path(String n) => '${tmp.path}/$n';

  test("eski + diff + extra = yangi fayl (bo'laklar chegarasidan o'tadi)", () {
    final old = utf8.encode('Hello, old world!');
    // Yangi: "Hello, NEW world!!" = 7 bayt eskidan + 3 extra + oxirgi qism eskidan + 2 extra
    // ctrl 1: x=7 (diff 0), y=3 (extra "NEW"), z=-0 → old ko'rsatkichi 7+3? Eskida "old" ham 3 bayt.
    final expected = utf8.encode('Hello, NEW world!!');
    final diff = List<int>.filled(7 + 7, 0); // 7 + (" world!" = 7)
    final extra = utf8.encode('NEW') + utf8.encode('!');
    // ctrl 1: eskidan 7 bayt ("Hello, "), extra 3 ("NEW"), eski ko'rsatkich 3 bayt oldinga ("old" ni o'tkazib yuboradi)
    // ctrl 2: eskidan 7 bayt (" world!"), extra 1 ("!")
    final patch = _buildPatch(
      newSize: expected.length,
      ctrl: [
        [7, 3, 3],
        [7, 1, 0],
      ],
      diff: diff,
      extra: extra,
    );
    File(path('old')).writeAsBytesSync(old);
    File(path('p')).writeAsBytesSync(patch);

    final sha = ApkPatcher.applySync(path('old'), path('p'), path('new'));
    expect(File(path('new')).readAsBytesSync(), expected);
    expect(sha, sha256.convert(expected).toString());
  });

  test('diff baytlari eskiga qo\'shiladi (+1)', () {
    final old = [10, 20, 30, 40];
    final patch = _buildPatch(
      newSize: 4,
      ctrl: [
        [4, 0, 0]
      ],
      diff: [1, 1, 1, 1],
      extra: const [],
    );
    File(path('old')).writeAsBytesSync(old);
    File(path('p')).writeAsBytesSync(patch);
    ApkPatcher.applySync(path('old'), path('p'), path('new'));
    expect(File(path('new')).readAsBytesSync(), [11, 21, 31, 41]);
  });

  test('buzilgan patch PatchException beradi', () {
    File(path('old')).writeAsBytesSync([1, 2, 3]);
    File(path('p')).writeAsBytesSync(List<int>.filled(60, 7));
    expect(() => ApkPatcher.applySync(path('old'), path('p'), path('new')),
        throwsA(isA<PatchException>()));
  });

  test('sha256File kutilgan xeshni beradi', () {
    File(path('f')).writeAsBytesSync(utf8.encode('abc'));
    expect(ApkPatcher.sha256FileSync(path('f')),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
  });
}
