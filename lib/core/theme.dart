import 'package:flutter/material.dart';

/// Palette from the GDD: soft purples and deep blues for the world, high
/// saturation and warm tones reserved for what the child makes.
abstract final class SP {
  static const night = Color(0xFF17102F);
  static const dusk = Color(0xFF2A1D5C);
  static const plum = Color(0xFF3B1F4A);
  static const lilac = Color(0xFFB9A7F5);
  static const cream = Color(0xFFFFF4E6);
  static const teal = Color(0xFF5EF2D6);
  static const pink = Color(0xFFFF7AB6);
  static const amber = Color(0xFFFFC857);
  static const muted = Color(0xFFA99CCF);
  static const card = Color(0xFF241A4D);
  static const cardLine = Color(0xFF3A2D6E);

  static const font = 'Andika';

  /// Minimum touch target for children (GDD: > 64 dp; we go bigger).
  static const kidTarget = 88.0;

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: font,
      colorScheme: ColorScheme.fromSeed(
        seedColor: lilac,
        brightness: Brightness.dark,
        surface: night,
        primary: teal,
        secondary: pink,
      ),
      scaffoldBackgroundColor: night,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: cream, displayColor: cream),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: teal,
          foregroundColor: night,
          minimumSize: const Size(160, 56),
          textStyle: const TextStyle(fontFamily: font, fontSize: 18, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cream,
          minimumSize: const Size(120, 52),
          side: const BorderSide(color: cardLine, width: 1.5),
          textStyle: const TextStyle(fontFamily: font, fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      sliderTheme: const SliderThemeData(activeTrackColor: teal, thumbColor: teal),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? night : muted),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? teal : card),
      ),
    );
  }
}
