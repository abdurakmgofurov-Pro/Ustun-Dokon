import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/error_log_service.dart';
import '../services/update_service.dart';

/// Ilova ochilganda (faqat Android'da) yangi versiya bor-yo'qligini
/// tekshiradi va bo'lsa yangilashni taklif qiladi.
class UpdateGate extends StatefulWidget {
  final Widget child;
  const UpdateGate({super.key, required this.child});

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  @override
  void initState() {
    super.initState();
    if (!kIsWeb && Platform.isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
  }

  Future<void> _check() async {
    final update = await updateService.checkForUpdate();
    if (update == null || !mounted) return;
    await _showUpdateDialog(context, update);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<void> _showUpdateDialog(BuildContext context, AppUpdate update) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UpdateDialog(update: update),
    );

/// Sozlamalardagi "Ilova versiyasi" qatori: joriy versiyani ko'rsatadi va
/// (Android'da) yangilanishni qo'lda tekshirish imkonini beradi.
class UpdateTile extends StatefulWidget {
  const UpdateTile({super.key});

  @override
  State<UpdateTile> createState() => _UpdateTileState();
}

class _UpdateTileState extends State<UpdateTile> {
  String _version = '';
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    final update = await updateService.checkForUpdate();
    if (!mounted) return;
    setState(() => _checking = false);
    if (update == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Eng so'nggi versiya o'rnatilgan")));
      return;
    }
    await _showUpdateDialog(context, update);
  }

  @override
  Widget build(BuildContext context) {
    final canUpdate = !kIsWeb && Platform.isAndroid;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.system_update_outlined),
        title: Text(_version.isEmpty ? 'Ilova versiyasi' : 'Versiya $_version'),
        subtitle: canUpdate ? const Text('Yangilanishni tekshirish') : null,
        trailing: _checking
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : null,
        onTap: canUpdate && !_checking ? _check : null,
      ),
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  final AppUpdate update;
  const _UpdateDialog({required this.update});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  String? _error;

  Future<void> _install() async {
    setState(() {
      _downloading = true;
      _error = null;
    });
    try {
      await updateService.downloadAndInstall(
        widget.update,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e, st) {
      errorLogService.log('app_update', e, stackTrace: st);
      if (mounted) {
        setState(() {
          _downloading = false;
          _error = "Yuklab bo'lmadi. Internetni tekshirib qayta urinib ko'ring.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notes = widget.update.notes.trim();
    return AlertDialog(
      title: Text('Yangi versiya ${widget.update.version}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (notes.isNotEmpty) Text(notes),
          if (_downloading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress > 0 ? _progress : null),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _downloading ? null : () => Navigator.of(context).pop(),
          child: const Text('Keyinroq'),
        ),
        FilledButton(
          onPressed: _downloading ? null : _install,
          child: const Text('Yangilash'),
        ),
      ],
    );
  }
}
