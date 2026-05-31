import 'package:flutter/material.dart';
import 'utils/constants.dart';

class AppTheme {
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: AppConstants.primaryColor,
          secondary: AppConstants.accentColor,
          surface: AppConstants.darkSurface,
          onSurface: AppConstants.darkText,
        ),
        scaffoldBackgroundColor: AppConstants.darkBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppConstants.darkSurface,
          foregroundColor: AppConstants.darkText,
          elevation: 0,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(
            color: AppConstants.darkText,
            fontSize: 18,
            height: 1.8,
          ),
          bodyMedium: TextStyle(
            color: AppConstants.darkText,
            fontSize: 16,
            height: 1.7,
          ),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: AppConstants.primaryColor,
          inactiveTrackColor: AppConstants.darkSurface,
          thumbColor: AppConstants.accentColor,
        ),
      );

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(
          primary: AppConstants.primaryColor,
          secondary: AppConstants.accentColor,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 18, height: 1.8),
          bodyMedium: TextStyle(fontSize: 16, height: 1.7),
        ),
      );
}
