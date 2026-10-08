import 'package:flutter/material.dart';

import 'colors.dart';

abstract final class ZFonts {
  /// Moderne, gut lesbare UI-Schrift.
  static const sans = 'WorkSans';

  /// Charaktervolle Serifenschrift für Geldbeträge. Alternative: 'Merriweather'.
  static const serif = 'Eczar';
}

/// Textstile, die über das Material-TextTheme hinausgehen.
abstract final class ZText {
  static const _tabular = [FontFeature.tabularFigures()];

  // Beträge (Serif) -----------------------------------------------------------
  static const amountHero = TextStyle(
    fontFamily: ZFonts.serif,
    fontSize: 64,
    height: 1.0,
    letterSpacing: -1.5,
    color: ZColors.text,
    fontWeight: FontWeight.w400,
  );
  static const amountLarge = TextStyle(
    fontFamily: ZFonts.serif,
    fontSize: 36,
    height: 1.05,
    letterSpacing: -0.6,
    color: ZColors.text,
  );
  static const amountMedium = TextStyle(
    fontFamily: ZFonts.serif,
    fontSize: 24,
    height: 1.1,
    letterSpacing: -0.3,
    color: ZColors.text,
  );
  static const amountSmall = TextStyle(fontFamily: ZFonts.serif, fontSize: 18, height: 1.15, color: ZColors.text);

  /// Beträge in Listen: Sans mit gleich breiten Ziffern, damit Spalten ruhig wirken.
  static const amountList = TextStyle(
    fontFamily: ZFonts.sans,
    fontSize: 15.5,
    fontWeight: FontWeight.w600,
    color: ZColors.text,
    fontFeatures: _tabular,
  );

  // UI (Sans) -----------------------------------------------------------------
  static const overline = TextStyle(
    fontFamily: ZFonts.sans,
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
    color: ZColors.textSecondary,
  );
  static const greeting = TextStyle(
    fontFamily: ZFonts.sans,
    fontSize: 23,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    color: ZColors.text,
    height: 1.2,
  );
  static const screenTitle = TextStyle(
    fontFamily: ZFonts.sans,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.6,
    color: ZColors.text,
  );
  static const sectionTitle = TextStyle(
    fontFamily: ZFonts.sans,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: ZColors.text,
  );
  static const itemTitle = TextStyle(
    fontFamily: ZFonts.sans,
    fontSize: 15.5,
    fontWeight: FontWeight.w600,
    color: ZColors.text,
  );
  static const body = TextStyle(fontFamily: ZFonts.sans, fontSize: 15, height: 1.4, color: ZColors.text);
  static const secondary = TextStyle(
    fontFamily: ZFonts.sans,
    fontSize: 13.5,
    height: 1.35,
    color: ZColors.textSecondary,
  );
  static const small = TextStyle(fontFamily: ZFonts.sans, fontSize: 12, height: 1.3, color: ZColors.textSecondary);
  static const label = TextStyle(
    fontFamily: ZFonts.sans,
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    color: ZColors.text,
  );
  static const fina = TextStyle(fontFamily: ZFonts.sans, fontSize: 14.5, height: 1.4, color: ZColors.text);
}
