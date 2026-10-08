import 'package:flutter/material.dart';

/// Farbwelt von Zoëzas: hell, warm, pastellig.
abstract final class ZColors {
  static const background = Color(0xFFF9EAF1);
  static const card = Color(0xFFFFFFFF);
  static const text = Color(0xFF29242A);
  static const textSecondary = Color(0xFF8E858B);
  static const textTertiary = Color(0xFFB9AFB5);
  static const accent = Color(0xFFD989BE);
  static const accentDeep = Color(0xFFC46FAA);
  static const accentLight = Color(0xFFF3D6E8);
  static const accentSoft = Color(0xFFFBEFF6);
  static const positive = Color(0xFF49A982);
  static const positiveLight = Color(0xFFDDF1E8);

  /// Für „drüber“ – bewusst ein sanftes Koralle statt Alarmrot.
  static const warning = Color(0xFFE39A6F);
  static const warningLight = Color(0xFFFBE7DA);
  static const negative = Color(0xFFD9707E);
  static const negativeLight = Color(0xFFF9DFE3);
  static const line = Color(0xFFF0E7EC);

  static const shadow = Color(0x0F5A2A48);

  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE59CCB), Color(0xFFC97DB6)],
  );

  /// Pastelltöne für Emoji-Kacheln, Kategorien, Konten und Ziele.
  static const pastels = <Color>[
    Color(0xFFFCE4EE), // rosé
    Color(0xFFEDE6F7), // lavendel
    Color(0xFFE2F0FB), // himmel
    Color(0xFFE2F4EA), // minze
    Color(0xFFFFEEDD), // pfirsich
    Color(0xFFFFF6D6), // butter
    Color(0xFFDDF3F3), // aqua
    Color(0xFFF6E3F4), // flieder
    Color(0xFFFBE5E0), // koralle
    Color(0xFFEAF0DC), // salbei
  ];

  /// Kräftigere Partnerfarbe zu einem Pastellton (für Diagramme, Fortschritt).
  static Color strongFor(Color pastel) {
    final hsl = HSLColor.fromColor(pastel);
    return hsl.withSaturation((hsl.saturation * 0.55).clamp(0.35, 0.6)).withLightness(0.68).toColor();
  }
}
