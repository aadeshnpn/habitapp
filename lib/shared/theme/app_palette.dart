import 'package:flutter/material.dart';
import 'app_colors.dart';

enum AppPalette { calmGreen, energeticOrange, premiumPurple }

extension AppPaletteExtension on AppPalette {
  String get displayName => switch (this) {
    AppPalette.calmGreen       => 'Calm Green',
    AppPalette.energeticOrange => 'Energetic Orange',
    AppPalette.premiumPurple   => 'Premium Purple',
  };

  String get storageKey => name; // 'calmGreen', 'energeticOrange', 'premiumPurple'

  Color get primaryColor => switch (this) {
    AppPalette.calmGreen       => AppColors.greenPrimary,
    AppPalette.energeticOrange => AppColors.orangePrimary,
    AppPalette.premiumPurple   => AppColors.purplePrimary,
  };

  Color get streakColor => switch (this) {
    AppPalette.calmGreen       => AppColors.greenStreak,
    AppPalette.energeticOrange => AppColors.orangeStreak,
    AppPalette.premiumPurple   => AppColors.purpleStreak,
  };

  Color get accentColor => switch (this) {
    AppPalette.calmGreen       => AppColors.greenAccent,
    AppPalette.energeticOrange => AppColors.orangeAccent,
    AppPalette.premiumPurple   => AppColors.purpleAccent,
  };
}
