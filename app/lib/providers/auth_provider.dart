import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_service.dart';
import '../models/models.dart';
import '../services/error_log_service.dart';

final authStateProvider = StreamProvider<AuthState>((ref) {
  return sb.auth.onAuthStateChange;
});

final currentProfileProvider = FutureProvider<AppProfile?>((ref) async {
  ref.watch(authStateProvider);
  final user = sb.auth.currentUser;
  if (user == null) return null;
  final data =
      await sb.from('profiles').select().eq('id', user.id).maybeSingle();
  if (data == null) return null;
  return AppProfile.fromMap(data);
});

final isAdminProvider = Provider<bool>((ref) {
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  return profile?.role == UserRole.admin;
});

class AuthController {
  Future<String?> signIn(String email, String password) async {
    try {
      await sb.auth
          .signInWithPassword(email: email.trim(), password: password);
      return null;
    } on AuthException catch (e, st) {
      errorLogService.log('auth_signin', e, stackTrace: st);
      return e.message;
    } catch (e, st) {
      errorLogService.log('auth_signin', e, stackTrace: st);
      return 'Kirishda xatolik yuz berdi: $e';
    }
  }

  Future<void> signOut() => sb.auth.signOut();

  /// Faqat admin chaqira oladi (manage-employee Edge Function server
  /// tomonida buni tekshiradi). Yangi xodim hisobini to'g'ridan-to'g'ri
  /// tasdiqlangan holda yaratadi — email tasdiqlash shart emas.
  Future<String?> createEmployee({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    try {
      final res = await sb.functions.invoke('manage-employee', body: {
        'action': 'create',
        'email': email.trim(),
        'password': password,
        'full_name': fullName,
        'role': role.name,
      });
      final data = res.data as Map?;
      if (data != null && data['error'] != null) {
        return data['error'].toString();
      }
      return null;
    } catch (e) {
      return 'Xodim qo\'shishda xatolik: $e';
    }
  }

  /// Faqat admin chaqira oladi. Xodim hisobini butunlay o'chirib tashlaydi.
  Future<String?> deleteEmployee(String userId) async {
    try {
      final res = await sb.functions.invoke('manage-employee', body: {
        'action': 'delete',
        'user_id': userId,
      });
      final data = res.data as Map?;
      if (data != null && data['error'] != null) {
        return data['error'].toString();
      }
      return null;
    } catch (e) {
      return 'Xodimni o\'chirishda xatolik: $e';
    }
  }

  Future<String?> updateRole(String profileId, UserRole role) async {
    try {
      await sb.from('profiles').update({'role': role.name}).eq('id', profileId);
      return null;
    } catch (e) {
      return 'Rolni o\'zgartirishda xatolik: $e';
    }
  }

  Future<String?> setActive(String profileId, bool isActive) async {
    try {
      await sb
          .from('profiles')
          .update({'is_active': isActive}).eq('id', profileId);
      return null;
    } catch (e) {
      return 'Holatni o\'zgartirishda xatolik: $e';
    }
  }
}

final allProfilesProvider = FutureProvider<List<AppProfile>>((ref) async {
  final data =
      await sb.from('profiles').select().order('full_name');
  return (data as List).map((e) => AppProfile.fromMap(e)).toList();
});

final authControllerProvider = Provider((ref) => AuthController());
