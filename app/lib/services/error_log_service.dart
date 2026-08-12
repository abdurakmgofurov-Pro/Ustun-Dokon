import 'package:flutter/foundation.dart';

import '../core/supabase_service.dart';

/// Ilova xatoliklarini `app_error_logs` jadvaliga yozib boradi — shu orqali
/// muammoni foydalanuvchi telefonini ko'rmasdan, bazadan turib tashxis
/// qo'yish mumkin bo'ladi. Yozish muvaffaqiyatsiz bo'lsa (masalan internet
/// yo'q) ham ilova hech qachon shu sabab qulamaydi.
class ErrorLogService {
  Future<void> log(
    String screen,
    Object error, {
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) async {
    try {
      await sb.from('app_error_logs').insert({
        'user_id': sb.auth.currentUser?.id,
        'platform': defaultTargetPlatform.name,
        'screen': screen,
        'message': error.toString(),
        'stack_trace': stackTrace?.toString(),
        'extra': extra,
      });
    } catch (_) {
      // Log yozishning o'zi ishlamasa ham ilova ishlashda davom etadi.
    }
  }
}

final errorLogService = ErrorLogService();
