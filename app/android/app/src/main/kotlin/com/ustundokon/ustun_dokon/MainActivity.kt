package com.ustundokon.ustun_dokon

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Avto-yangilanish: patchni o'rnatilgan APK'ga qo'llash uchun shu
        // ilovaning o'zi o'rnatilgan APK fayli yo'li kerak.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ustun/updater")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "apkPath" -> result.success(applicationContext.packageCodePath)
                    else -> result.notImplemented()
                }
            }
    }
}
