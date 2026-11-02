import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// GitHub Releases'dagi eng so'nggi relizni tekshiradi (repo ochiq —
/// token kerak emas). Reliz teg'i `v1.2.3` ko'rinishida, APK fayli esa
/// `ustun-dokon.apk` nomi bilan biriktirilgan bo'lishi kerak.
const _repo = 'abdurakmgofurov-Pro/Ustun-Dokon';
const _apkName = 'ustun-dokon.apk';

class AppUpdate {
  final String version;
  final String notes;
  final String apkUrl;
  const AppUpdate(
      {required this.version, required this.notes, required this.apkUrl});
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
      final apk = assets.where((a) => a['name'] == _apkName).firstOrNull;
      if (apk == null) return null;

      return AppUpdate(
        version: latest,
        notes: (json['body'] as String?) ?? '',
        apkUrl: apk['browser_download_url'] as String,
      );
    } catch (_) {
      return null;
    }
  }

  /// APK'ni yuklab oladi ([onProgress] 0..1) va o'rnatuvchini ochadi.
  Future<void> downloadAndInstall(
    AppUpdate update, {
    required void Function(double) onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$_apkName');

    final client = http.Client();
    try {
      final res = await client.send(http.Request('GET', Uri.parse(update.apkUrl)));
      if (res.statusCode != 200) {
        throw HttpException("Yuklab olib bo'lmadi (${res.statusCode})");
      }
      final total = res.contentLength ?? 0;
      var received = 0;
      final sink = file.openWrite();
      await for (final chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress(received / total);
      }
      await sink.close();
    } finally {
      client.close();
    }

    await OpenFilex.open(file.path,
        type: 'application/vnd.android.package-archive');
  }

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
