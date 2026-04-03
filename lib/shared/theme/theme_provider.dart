import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_palette.dart';
import 'app_theme.dart';

@immutable
class ThemeState {
  final AppPalette palette;
  final ThemeMode mode; // system, light, dark

  const ThemeState({
    this.palette = AppPalette.calmGreen,
    this.mode = ThemeMode.system,
  });

  ThemeState copyWith({AppPalette? palette, ThemeMode? mode}) {
    return ThemeState(
      palette: palette ?? this.palette,
      mode: mode ?? this.mode,
    );
  }
}

class ThemeNotifier extends AsyncNotifier<ThemeState> {
  static const _paletteKey = 'theme_palette';
  static const _modeKey    = 'theme_mode';

  @override
  Future<ThemeState> build() async {
    // Load from SharedPreferences on startup
    final prefs = await SharedPreferences.getInstance();
    final paletteStr = prefs.getString(_paletteKey);
    final modeStr    = prefs.getString(_modeKey);
    return ThemeState(
      palette: _paletteFromString(paletteStr),
      mode:    _modeFromString(modeStr),
    );
  }

  Future<void> setPalette(AppPalette palette) async {
    final current = state.value ?? const ThemeState();
    state = AsyncData(current.copyWith(palette: palette));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_paletteKey, palette.storageKey);
  }

  Future<void> setMode(ThemeMode mode) async {
    final current = state.value ?? const ThemeState();
    state = AsyncData(current.copyWith(mode: mode));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, _modeToString(mode));
  }

  /// Returns the correct ThemeData for the current palette + mode,
  /// using [platformBrightness] when mode is ThemeMode.system.
  ThemeData themeData(Brightness platformBrightness) {
    final themeState = state.value ?? const ThemeState();
    final brightness = themeState.mode == ThemeMode.system
        ? platformBrightness
        : (themeState.mode == ThemeMode.dark ? Brightness.dark : Brightness.light);
    return AppTheme.buildTheme(palette: themeState.palette, brightness: brightness);
  }

  // --- Helpers ---

  static AppPalette _paletteFromString(String? value) {
    return AppPalette.values.firstWhere(
      (p) => p.storageKey == value,
      orElse: () => AppPalette.calmGreen,
    );
  }

  static ThemeMode _modeFromString(String? value) {
    return switch (value) {
      'light'  => ThemeMode.light,
      'dark'   => ThemeMode.dark,
      'system' => ThemeMode.system,
      _        => ThemeMode.system,
    };
  }

  static String _modeToString(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light  => 'light',
      ThemeMode.dark   => 'dark',
      ThemeMode.system => 'system',
    };
  }
}

final themeProvider = AsyncNotifierProvider<ThemeNotifier, ThemeState>(ThemeNotifier.new);
