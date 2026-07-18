import 'package:flutter/material.dart';

class SapTheme {
  static const black = Color(0xFF101010);
  static const yellow = Color(0xFFFCDC04);
  static const red = Color(0xFFD90000);
  static const paper = Color(0xFFFAFBF8);
  static const ink = Color(0xFF17231F);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: black,
      brightness: Brightness.light,
      primary: black,
      secondary: yellow,
      tertiary: red,
      surface: paper,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      splashFactory: InkRipple.splashFactory,
      scaffoldBackgroundColor: const Color(0xFFF4F6F3),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFFE1E5E0)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: black,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? black
              : Colors.black54;
          return TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: black,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
