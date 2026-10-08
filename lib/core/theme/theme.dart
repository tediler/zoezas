import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'colors.dart';
import 'typography.dart';

abstract final class ZRadius {
  static const card = 24.0;
  static const cardLarge = 28.0;
  static const tile = 14.0;
  static const input = 18.0;
  static const pill = 999.0;
}

ThemeData buildZoezasTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: ZColors.accent, brightness: Brightness.light).copyWith(
    primary: ZColors.accentDeep,
    onPrimary: Colors.white,
    secondary: ZColors.accent,
    surface: ZColors.card,
    onSurface: ZColors.text,
    onSurfaceVariant: ZColors.textSecondary,
    outline: ZColors.line,
    outlineVariant: ZColors.line,
    error: ZColors.negative,
    surfaceTint: Colors.transparent,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: ZFonts.sans,
    scaffoldBackgroundColor: ZColors.background,
    splashFactory: InkSparkle.splashFactory,
  );

  final text = base.textTheme.apply(bodyColor: ZColors.text, displayColor: ZColors.text, fontFamily: ZFonts.sans);

  return base.copyWith(
    textTheme: text,
    appBarTheme: const AppBarTheme(
      backgroundColor: ZColors.background,
      foregroundColor: ZColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      titleTextStyle: ZText.sectionTitle,
    ),
    dividerTheme: const DividerThemeData(color: ZColors.line, thickness: 1, space: 1),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: ZColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(ZRadius.cardLarge))),
      showDragHandle: false,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: ZColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZRadius.cardLarge)),
      titleTextStyle: ZText.sectionTitle,
      contentTextStyle: ZText.body,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ZColors.accentSoft,
      hintStyle: ZText.body.copyWith(color: ZColors.textTertiary),
      labelStyle: ZText.secondary,
      floatingLabelStyle: ZText.secondary.copyWith(color: ZColors.accentDeep),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(ZRadius.input), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ZRadius.input),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ZRadius.input),
        borderSide: const BorderSide(color: ZColors.accentLight, width: 1.5),
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: ZColors.accentDeep,
      selectionColor: ZColors.accentLight,
      selectionHandleColor: ZColors.accentDeep,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ZColors.text,
      contentTextStyle: ZText.body.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 0,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : ZColors.textTertiary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? ZColors.accent : ZColors.line,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: ZColors.card,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: ZColors.accentSoft,
      headerForegroundColor: ZColors.text,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZRadius.cardLarge)),
      dayShape: const WidgetStatePropertyAll(CircleBorder()),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: ZColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 6,
      shadowColor: ZColors.shadow,
      textStyle: ZText.body,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ZColors.accentDeep,
        textStyle: ZText.label,
        shape: const StadiumBorder(),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
