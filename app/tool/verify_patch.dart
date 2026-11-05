// Patchni haqiqiy fayllarda sinash: dart run tool/verify_patch.dart <eski.apk> <patch.bin> <yangi.apk-ning-sha256-si> <natija.apk>
// Ilovadagi ApkPatcher aynan shu kod — telefonda ishlaydigan algoritmning o'zi.
import 'dart:io';

import 'package:ustun_dokon/services/apk_patcher.dart';

void main(List<String> args) {
  if (args.length != 4) {
    stderr.writeln('Foydalanish: verify_patch <eski.apk> <patch.bin> <kutilgan-sha256> <natija.apk>');
    exit(2);
  }
  final sw = Stopwatch()..start();
  final got = ApkPatcher.applySync(args[0], args[1], args[3]);
  stdout.writeln('sha256: $got (${sw.elapsedMilliseconds} ms)');
  if (got != args[2].toLowerCase()) {
    stderr.writeln('MOS EMAS: kutilgan ${args[2]}');
    exit(1);
  }
  stdout.writeln('OK: patch to\'g\'ri qo\'llandi');
}
