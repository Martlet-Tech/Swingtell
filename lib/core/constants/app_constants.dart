import 'package:flutter/material.dart';

class ColorTheme {
  final Color bg;
  final Color text;
  final Color barBg;
  const ColorTheme({required this.bg, required this.text, required this.barBg});
}

const List<ColorTheme> kColorThemes = [
  ColorTheme(bg: Color(0xFFF8F3E8), text: Color(0xFF2C2C2C), barBg: Color(0xFFEEE9DC)),
  ColorTheme(bg: Color(0xFF1A1A1A), text: Color(0xFFD4D4D4), barBg: Color(0xFF111111)),
  ColorTheme(bg: Color(0xFFCCE8CC), text: Color(0xFF1A2E1A), barBg: Color(0xFFBDD9BD)),
  ColorTheme(bg: Color(0xFFF5E6C8), text: Color(0xFF3B2A14), barBg: Color(0xFFEDD9A3)),
];
