import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

/// Kameraga ruxsat borligini tekshiradi; yo'q bo'lsa so'raydi. Foydalanuvchi
/// butunlay rad etgan bo'lsa (permanently denied), sozlamalarga o'tishni
/// taklif qiladigan dialog ko'rsatadi va `false` qaytaradi.
Future<bool> _ensureCameraPermission(BuildContext context) async {
  var status = await Permission.camera.status;
  if (status.isGranted) return true;

  if (status.isDenied) {
    status = await Permission.camera.request();
    if (status.isGranted) return true;
  }

  if (!context.mounted) return false;

  final goToSettings = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Kameraga ruxsat kerak'),
      content: const Text(
        'Shtrix-kodni skanerlash uchun kameradan foydalanish ruxsati '
        'kerak. Ilova sozlamalaridan kamerani yoqing.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Bekor qilish'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Sozlamalarga o\'tish'),
        ),
      ],
    ),
  );

  if (goToSettings == true) {
    await openAppSettings();
  }
  return false;
}

/// Kamera orqali shtrix-kod/QR-kod skanerini ochadi va topilgan qiymatni
/// qaytaradi. Foydalanuvchi bekor qilsa `null` qaytadi. Bitta kod
/// topilishi bilan ekran avtomatik yopiladi.
Future<String?> showBarcodeScanner(BuildContext context, {String? title}) async {
  if (!await _ensureCameraPermission(context)) return null;
  if (!context.mounted) return null;
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _BarcodeScannerScreen(title: title ?? 'Skanerlash'),
    ),
  );
}

/// Uzluksiz skanerlash rejimi: har bir topilgan kod uchun [onDetect]
/// chaqiriladi (ekran yopilmaydi), u orqaga qisqa natija matnini
/// qaytaradi (masalan "✅ Non qo'shildi"), va foydalanuvchi keyingi
/// tovarni darhol skanerlashda davom etishi mumkin. "Tayyor" tugmasi
/// bosilganda ekran yopiladi.
Future<void> showContinuousBarcodeScanner(
  BuildContext context, {
  required Future<String> Function(String code) onDetect,
  String? title,
}) async {
  if (!await _ensureCameraPermission(context)) return;
  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _BarcodeScannerScreen(
        title: title ?? 'Skanerlash',
        onDetectContinuous: onDetect,
      ),
    ),
  );
}

class _BarcodeScannerScreen extends StatefulWidget {
  final String title;
  final Future<String> Function(String code)? onDetectContinuous;
  const _BarcodeScannerScreen({required this.title, this.onDetectContinuous});

  bool get isContinuous => onDetectContinuous != null;

  @override
  State<_BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<_BarcodeScannerScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _busy = false;
  bool _retrying = false;
  String? _feedback;
  Timer? _feedbackTimer;
  int _scannedCount = 0;

  @override
  void dispose() {
    _controller.dispose();
    _feedbackTimer?.cancel();
    super.dispose();
  }

  Future<void> _retryStart() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await _controller.start();
    } catch (_) {
      // Xato controller.value.error orqali ScannerErrorWidget'da ko'rsatiladi.
    }
    if (mounted) setState(() => _retrying = false);
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null || value.isEmpty) return;

    if (!widget.isContinuous) {
      Navigator.of(context).pop(value);
      return;
    }

    setState(() => _busy = true);
    final result = await widget.onDetectContinuous!(value);
    if (!mounted) return;
    _feedbackTimer?.cancel();
    setState(() {
      _feedback = result;
      _scannedCount++;
    });
    _feedbackTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _busy = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.isContinuous
            ? '${widget.title} ($_scannedCount)'
            : widget.title),
        actions: [
          IconButton(
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder: (context, state, _) => Icon(
                state.torchState == TorchState.on
                    ? Icons.flash_on
                    : Icons.flash_off,
              ),
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
          if (widget.isContinuous)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tayyor',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _ScannerError(
              error: error,
              retrying: _retrying,
              onRetry: _retryStart,
            ),
          ),
          Center(
            child: Container(
              width: 260,
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(
                    color: _busy ? Colors.greenAccent : Colors.white70,
                    width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 32,
            left: 16,
            right: 16,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _feedback != null
                  ? Container(
                      key: ValueKey(_feedback),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _feedback!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    )
                  : const Text(
                      'Shtrix-kod yoki QR-kodni ramka ichiga joylashtiring',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerError extends StatefulWidget {
  final MobileScannerException error;
  final bool retrying;
  final VoidCallback onRetry;
  const _ScannerError({
    required this.error,
    required this.retrying,
    required this.onRetry,
  });

  String get _message {
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return 'Kameraga ruxsat berilmagan. Ilova sozlamalaridan kamerani yoqing.';
      case MobileScannerErrorCode.unsupported:
        return 'Bu qurilmada kamera orqali skanerlash imkoni yo\'q.';
      case MobileScannerErrorCode.controllerAlreadyInitialized:
      case MobileScannerErrorCode.controllerUninitialized:
      case MobileScannerErrorCode.controllerDisposed:
      case MobileScannerErrorCode.controllerInitializing:
      case MobileScannerErrorCode.controllerNotAttached:
        return 'Kamera holati bilan bog\'liq nosozlik. "Qayta urinish"ni bosing.';
      case MobileScannerErrorCode.genericError:
        return 'Kamerani ochib bo\'lmadi (qurilma xatosi). Boshqa ilova kamerani band qilmaganini tekshirib, qayta urinib ko\'ring.';
    }
  }

  @override
  State<_ScannerError> createState() => _ScannerErrorState();
}

class _ScannerErrorState extends State<_ScannerError> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final error = widget.error;
    final isPermission = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 40),
              const SizedBox(height: 12),
              Text(
                widget._message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              if (isPermission)
                FilledButton(
                  onPressed: () => openAppSettings(),
                  child: const Text('Sozlamalarga o\'tish'),
                )
              else
                FilledButton(
                  onPressed: widget.retrying ? null : widget.onRetry,
                  child: widget.retrying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Qayta urinish'),
                ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() => _showDetails = !_showDetails),
                child: Text(
                  _showDetails ? 'Tafsilotni yashirish' : 'Texnik tafsilot',
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
              if (_showDetails)
                Text(
                  'Xato kodi: ${error.errorCode.name}\n${error.errorCode.message}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
