import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    primarySwatch: Colors.blue,
    fontFamily: "Poppins", // ✅ Apply globally
    textTheme: const TextTheme(
      bodyLarge: TextStyle(fontWeight: FontWeight.w500),
      bodyMedium: TextStyle(fontWeight: FontWeight.w400),
      bodySmall: TextStyle(fontWeight: FontWeight.w300),
    ),
  );
}