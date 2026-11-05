import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'apk_patcher.dart';
import 'error_log_service.dart';

/// GitHub Releases'dagi eng so'nggi relizni tekshiradi (repo ochiq —
/// token kerak emas). Reliz teg'i `v1.2.3` ko'rinishida, to'liq APK
/// `ustun-dokon.apk` nomi bilan biriktirilgan bo'lishi kerak. Reliz
/// `update.json` va `patch-<eski>-to-<yangi>.bin` fayllarini ham o'z ichiga
/// olsa (tools/release.py shuni yaratadi), o'rnatilgan versiya uchun mos patch
/// bo'lganda faqat o'zgargan qism (odatda bir necha MB) yuklanadi.
const _repo = 'abdurakmgofurov-Pro/Ustun-Dokon';
const _apkName = 'ustun-dokon.apk';
const _channel = MethodChannel('ustun/updater');

class AppUpdate {
  final String version;
  final String notes;
  final String apkUrl;
  final int apkSize;
  final String? apkSha256;
  final String? patchUrl;
  final int patchSize;
  final String? patchFromSha256;

  const AppUpdate({
    required this.version,
    required this.notes,
    required this.apkUrl,
    this.apkSize = 0,
    this.apkSha256,
    this.patchUrl,
    this.patchSize = 0,
    this.patchFromSha256,
  });

  bool get hasPatch => patchUrl != null && patchFromSha256 != null;

  /// Yuklab olinadigan hajm (bayt): patch bo'lsa u, aks holda to'liq APK.
  int get downloadSize => hasPatch ? patchSize : apkSize;
}

class UpdateService {
  /// Yangi versiya bo'lsa [AppUpdate], aks holda (yoki internet/xato bo'lsa)
  /// null qaytaradi — yangilanish tekshiruvi hech qachon ilovani to'xtatmaydi.
  Future<AppUpdate?> checkForUpdate() async {
    try {
      final res = await http
          .get(
            Uri.https('api.github.com', '/repos/$_repo/releases/latest'),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final latest = (json['tag_name'] as String).replaceFirst('v', '');
      final current = (await PackageInfo.fromPlatform()).version;
      if (!_isNewer(latest, current)) return null;

      final assets = (json['assets'] as List).cast<Map<String, dynamic>>();
      Map<String, dynamic>? asset(String name) =>
          assets.where((a) => a['name'] == name).firstOrNull;

      final apk = asset(_apkName);
      if (apk == null) return null;

      // update.json bo'lsa — hash va (mos bo'lsa) patch ma'lumoti.
      String? apkSha;
      String? patchUrl;
      var patchSize = 0;
      String? patchFrom;
      final manifestAsset = asset('update.json');
      if (manifestAsset != null) {
        try {
          final mres = await http
              .get(Uri.parse(manifestAsset['browser_download_url'] as String))
              .timeout(const Duration(seconds: 10));
          if (mres.statusCode == 200) {
            final m = jsonDecode(mres.body) as Map<String, dynamic>;
            if (m['version'] == latest) {
              apkSha = (m['apk'] as Map<String, dynamic>)['sha256'] as String?;
              final p = (m['patches'] as Map<String, dynamic>?)?[current]
                  as Map<String, dynamic>?;
              final pAsset = p == null ? null : asset(p['name'] as String);
              if (p != null && pAsset != null) {
                patchUrl = pAsset['browser_download_url'] as String;
                patchSize = (pAsset['size'] as num).toInt();
                patchFrom = p['from_sha256'] as String;
              }
            }
          }
        } catch (_) {
          // update.json o'qilmasa — to'liq APK bilan davom etamiz.
        }
      }

      return AppUpdate(
        version: latest,
        notes: (json['body'] as String?) ?? '',
        apkUrl: apk['browser_download_url'] as String,
        apkSize: (apk['size'] as num?)?.toInt() ?? 0,
        apkSha256: apkSha,
        patchUrl: patchUrl,
        patchSize: patchSize,
        patchFromSha256: patchFrom,
      );
    } catch (_) {
      return null;
    }
  }

  /// Yangilanishni yuklab o'rnatuvchini ochadi. Avval kichik patch (agar bor
  /// bo'lsa); u ishlamasa (mos kelmasa, buzilsa) to'liq APK. [onProgress] 0..1
  /// (0 — noaniq), [onStatus] — hozirgi bosqich matni.
  Future<void> downloadAndInstall(
    AppUpdate update, {
    required void Function(double) onProgress,
    void Function(String)? onStatus,
  }) async {
    final dir = await getTemporaryDirectory();
    final apkFile = File('${dir.path}/$_apkName');

    if (update.hasPatch) {
      try {
        await _installViaPatch(update, dir, apkFile, onProgress, onStatus);
        return;
      } catch (e, st) {
        errorLogService.log('update_patch', e, stackTrace: st);
        onProgress(0);
      }
    }

    onStatus?.call('Yuklanmoqda...');
    await _download(update.apkUrl, apkFile, onProgress);
    if (update.apkSha256 != null) {
      onStatus?.call('Tekshirilmoqda...');
      final got = await ApkPatcher.sha256File(apkFile.path);
      if (got != update.apkSha256) {
        await apkFile.delete();
        throw HttpException('Yuklangan fayl buzilgan');
      }
    }
    await _open(apkFile);
  }

  Future<void> _installViaPatch(
    AppUpdate update,
    Directory dir,
    File apkFile,
    void Function(double) onProgress,
    void Function(String)? onStatus,
  ) async {
    final basePath = await _channel.invokeMethod<String>('apkPath');
    if (basePath == null) throw StateError('O\'rnatilgan APK yo\'li topilmadi');

    onStatus?.call('Tekshirilmoqda...');
    final baseSha = await ApkPatcher.sha256File(basePath);
    if (baseSha != update.patchFromSha256) {
      throw StateError('O\'rnatilgan APK patchga mos emas');
    }

    final patchFile = File('${dir.path}/update.patch');
    onStatus?.call('Yangilanish yuklanmoqda...');
    await _download(update.patchUrl!, patchFile, onProgress);

    onProgress(0);
    onStatus?.call('Yangi versiya tayyorlanmoqda...');
    final sha = await ApkPatcher.apply(
      basePath: basePath,
      patchPath: patchFile.path,
      outPath: apkFile.path,
    );
    await patchFile.delete();
    if (update.apkSha256 != null && sha != update.apkSha256) {
      await apkFile.delete();
      throw StateError('Patch natijasi kutilgan faylga mos emas');
    }
    await _open(apkFile);
  }

  Future<void> _download(
    String url,
    File file,
    void Function(double) onProgress,
  ) async {
    if (await file.exists()) await file.delete();
    final client = http.Client();
    try {
      final res = await client.send(http.Request('GET', Uri.parse(url)));
      if (res.statusCode != 200) {
        throw HttpException('Yuklab olib bo\'lmadi (${res.statusCode})');
      }
      final total = res.contentLength ?? 0;
      var received = 0;
      final sink = file.openWrite();
      try {
        await for (final chunk in res.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) onProgress(received / total);
        }
      } finally {
        await sink.close();
      }
    } finally {
      client.close();
    }
  }

  Future<void> _open(File apk) => OpenFilex.open(apk.path,
      type: 'application/vnd.android.package-archive');

  bool _isNewer(String latest, String current) {
    final a = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final b = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }
}

final updateService = UpdateService();
