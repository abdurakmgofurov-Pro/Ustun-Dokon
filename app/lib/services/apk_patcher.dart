import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class PatchException implements Exception {
  final String message;
  PatchException(this.message);
  @override
  String toString() => message;
}

/// Avto-yangilanish uchun "farq" (patch) fayllarini qo'llaydi: o'rnatilgan
/// APK + kichik patch = yangi APK (to'liq 100+ MB yuklash o'rniga bir necha MB).
///
/// Patch formati "UDP2" (tools/release.py yaratadi), hammasi little-endian:
///   0  4  "UDP2"
///   4  8  yangi fayl hajmi
///   12 8  boshqaruv uchliklari soni (x, y, z — har biri int64)
///   20 8  zlib(boshqaruv) uzunligi
///   28 8  zlib(extra) uzunligi
///   36 8  extra xom uzunligi
///   44 4  diff bo'lagi xom hajmi (oxirgisi qisqa bo'lishi mumkin)
///   48 4  diff bo'laklari soni (N)
///   52 4*N  har bir zlib(diff bo'lagi) uzunligi
///   so'ng: zlib(boshqaruv) | zlib(extra) | N ta zlib(diff bo'lagi)
/// Algoritm — klassik bsdiff/bspatch: har uchlik uchun x bayt "eski + diff",
/// y bayt "extra" dan, keyin eski fayl ko'rsatkichi z ga suriladi.
class ApkPatcher {
  /// Faylning SHA-256 xeshi (kichik harflarda hex).
  static Future<String> sha256File(String path) =>
      Isolate.run(() => sha256FileSync(path));

  /// [patchPath] ni [basePath] ga qo'llab, natijani [outPath] ga yozadi va
  /// natijaning SHA-256 xeshini qaytaradi.
  static Future<String> apply({
    required String basePath,
    required String patchPath,
    required String outPath,
  }) =>
      Isolate.run(() => applySync(basePath, patchPath, outPath));

  static String sha256FileSync(String path) {
    final capture = _DigestCapture();
    final sink = sha256.startChunkedConversion(capture);
    final f = File(path).openSync();
    try {
      final buf = Uint8List(1 << 20);
      while (true) {
        final n = f.readIntoSync(buf);
        if (n <= 0) break;
        sink.add(Uint8List.sublistView(buf, 0, n));
      }
      sink.close();
    } finally {
      f.closeSync();
    }
    return capture.value.toString();
  }

  static String applySync(String basePath, String patchPath, String outPath) {
    final patch = File(patchPath).readAsBytesSync();
    final bd = ByteData.sublistView(patch);
    if (patch.length < 52 ||
        String.fromCharCodes(patch.sublist(0, 4)) != 'UDP2') {
      throw PatchException('Patch formati noto\'g\'ri');
    }
    final newSize = bd.getUint64(4, Endian.little);
    final ctrlCount = bd.getUint64(12, Endian.little);
    final ctrlZ = bd.getUint64(20, Endian.little);
    final extraZ = bd.getUint64(28, Endian.little);
    final extraRaw = bd.getUint64(36, Endian.little);
    final chunkCount = bd.getUint32(48, Endian.little);

    var off = 52;
    final chunkLens = <int>[
      for (var i = 0; i < chunkCount; i++)
        bd.getUint32(off + 4 * i, Endian.little)
    ];
    off += 4 * chunkCount;

    Uint8List inflate(int start, int len) => Uint8List.fromList(
        zlib.decode(Uint8List.sublistView(patch, start, start + len)));

    final ctrl = inflate(off, ctrlZ);
    off += ctrlZ;
    final extra = inflate(off, extraZ);
    off += extraZ;
    if (ctrl.length != ctrlCount * 24 || extra.length != extraRaw) {
      throw PatchException('Patch buzilgan (uzunlik mos emas)');
    }
    final chunkStarts = <int>[];
    for (final l in chunkLens) {
      chunkStarts.add(off);
      off += l;
    }
    if (off != patch.length) {
      throw PatchException('Patch buzilgan (hajm mos emas)');
    }
    final diffReader = _ChunkedZlib(patch, chunkStarts, chunkLens);
    final cd = ByteData.sublistView(ctrl);

    final old = File(basePath).openSync();
    final out = File(outPath).openSync(mode: FileMode.write);
    final capture = _DigestCapture();
    final hash = sha256.startChunkedConversion(capture);
    try {
      final oldSize = old.lengthSync();
      const bufSize = 1 << 20;
      final diffBuf = Uint8List(bufSize);
      final oldBuf = Uint8List(bufSize);
      var oldPos = 0;
      var newPos = 0;
      var extraPos = 0;

      void emit(Uint8List buf, int n) {
        out.writeFromSync(buf, 0, n);
        hash.add(Uint8List.sublistView(buf, 0, n));
        newPos += n;
      }

      for (var c = 0; c < ctrlCount; c++) {
        final x = cd.getInt64(c * 24, Endian.little);
        final y = cd.getInt64(c * 24 + 8, Endian.little);
        final z = cd.getInt64(c * 24 + 16, Endian.little);
        if (x < 0 || y < 0 || newPos + x + y > newSize) {
          throw PatchException('Patch buzilgan (boshqaruv)');
        }

        var rem = x;
        while (rem > 0) {
          final n = rem < bufSize ? rem : bufSize;
          diffReader.readInto(diffBuf, n);
          _readOld(old, oldSize, oldPos, oldBuf, n);
          for (var i = 0; i < n; i++) {
            diffBuf[i] = diffBuf[i] + oldBuf[i];
          }
          emit(diffBuf, n);
          oldPos += n;
          rem -= n;
        }

        if (y > 0) {
          if (extraPos + y > extra.length) {
            throw PatchException('Patch buzilgan (extra)');
          }
          var left = y;
          while (left > 0) {
            final n = left < bufSize ? left : bufSize;
            emit(Uint8List.sublistView(extra, extraPos, extraPos + n), n);
            extraPos += n;
            left -= n;
          }
        }
        oldPos += z;
      }
      if (newPos != newSize) {
        throw PatchException('Natija hajmi mos emas');
      }
      out.flushSync();
    } finally {
      old.closeSync();
      out.closeSync();
    }
    hash.close();
    return capture.value.toString();
  }

  /// Eski fayldan [pos] dan [n] bayt o'qiydi; fayldan tashqari qismlar 0.
  static void _readOld(
      RandomAccessFile f, int size, int pos, Uint8List buf, int n) {
    final start = pos < 0 ? 0 : pos;
    final end = pos + n > size ? size : pos + n;
    if (start == pos && end == pos + n) {
      _readFully(f, pos, buf, 0, n);
      return;
    }
    buf.fillRange(0, n, 0);
    if (end > start) {
      _readFully(f, start, buf, start - pos, end - start);
    }
  }

  static void _readFully(
      RandomAccessFile f, int pos, Uint8List buf, int bufOff, int len) {
    f.setPositionSync(pos);
    var got = 0;
    while (got < len) {
      final r = f.readIntoSync(buf, bufOff + got, bufOff + len);
      if (r <= 0) throw PatchException('Eski fayl kutilganidan qisqa');
      got += r;
    }
  }
}

/// Bo'laklarga bo'lingan zlib oqimini ketma-ket o'qiydi (xotirani tejash uchun
/// diff to'liq emas, bittadan bo'lak ochiladi).
class _ChunkedZlib {
  final Uint8List data;
  final List<int> starts;
  final List<int> lens;
  int _idx = 0;
  Uint8List _cur = Uint8List(0);
  int _pos = 0;
  _ChunkedZlib(this.data, this.starts, this.lens);

  void readInto(Uint8List dst, int len) {
    var done = 0;
    while (done < len) {
      if (_pos >= _cur.length) {
        if (_idx >= lens.length) {
          throw PatchException('Patch buzilgan (diff tugadi)');
        }
        _cur = Uint8List.fromList(zlib.decode(
            Uint8List.sublistView(data, starts[_idx], starts[_idx] + lens[_idx])));
        _idx++;
        _pos = 0;
        continue;
      }
      final avail = _cur.length - _pos;
      final n = (len - done) < avail ? (len - done) : avail;
      dst.setRange(done, done + n, _cur, _pos);
      _pos += n;
      done += n;
    }
  }
}

class _DigestCapture implements Sink<Digest> {
  late Digest value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}
