import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'theme_mode';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    switch (saved) {
      case 'light':
        state = ThemeMode.light;
      case 'dark':
        state = ThemeMode.dark;
      default:
        state = ThemeMode.system;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }

  Future<void> toggle(Brightness currentPlatformBrightness) async {
    final isCurrentlyDark = state == ThemeMode.dark ||
        (state == ThemeMode.system &&
            currentPlatformBrightness == Brightness.dark);
    await setMode(isCurrentlyDark ? ThemeMode.light : ThemeMode.dark);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
        (ref) => ThemeModeNotifier());
