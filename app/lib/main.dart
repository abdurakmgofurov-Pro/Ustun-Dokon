import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'services/error_log_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    publishableKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  // Flutter widget daraxtida tutilmagan xatolarni ham bazaga yozib boramiz.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    errorLogService.log(
      'flutter_error',
      details.exception,
      stackTrace: details.stack,
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    errorLogService.log('uncaught_error', error, stackTrace: stack);
    return true;
  };

  runApp(const ProviderScope(child: UstunDokonApp()));
}
