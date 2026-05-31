import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  // App info
  static const String appName = 'SwingTell';
  static const String appVersion = '1.0.0';

  // TTS
  static const double minSpeed = 0.5;
  static const double maxSpeed = 3.0;
  static const double defaultSpeed = 1.0;
  static const List<double> presetSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 2.5, 3.0];

  // Reading
  static const Duration progressSaveInterval = Duration(seconds: 30);

  // File formats
  static const List<String> supportedExtensions = ['epub'];

  // UI
  static const Color primaryColor = Color(0xFF8B7355); // Warm brown
  static const Color accentColor = Color(0xFFC4A882); // Light tan
  static const Color darkBg = Color(0xFF1A1614); // Dark warm background
  static const Color darkSurface = Color(0xFF2A2520);
  static const Color darkText = Color(0xFFE8E0D8);
}
