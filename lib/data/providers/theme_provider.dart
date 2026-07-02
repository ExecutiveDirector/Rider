// lib/data/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/storage_service.dart';

const _themeModeKey = 'theme_mode';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _restore();
  }

  void _restore() {
    final saved = StorageService.instance.getString(_themeModeKey);
    switch (saved) {
      case 'light':
        state = ThemeMode.light;
        break;
      case 'dark':
        state = ThemeMode.dark;
        break;
      default:
        state = ThemeMode.system;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await StorageService.instance.setString(_themeModeKey, mode.name);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (_) => ThemeModeNotifier(),
);
