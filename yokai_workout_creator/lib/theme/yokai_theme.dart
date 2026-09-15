import 'package:flutter/material.dart';

class YokaiTheme {
  static const red = Color(0xFFE63840);
  static const background = Color(0xFF0C0D10);
  static const surface = Color(0xFF191B21);
  static ThemeData get dark => ThemeData(
    useMaterial3: true, brightness: Brightness.dark, scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.fromSeed(seedColor: red, brightness: Brightness.dark,
      primary: red, surface: surface),
    appBarTheme: const AppBarTheme(backgroundColor: background, centerTitle: false),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14)),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
      minimumSize: const Size(48, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1))),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
