import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// -----------------------------------------------------------------------------
// PALETTE
// -----------------------------------------------------------------------------

abstract final class AppColors {
  // Core surfaces
  static const Color canvas = Color(0xFFF3F5F2);
  static const Color canvasDeep = Color(0xFFE9EDE8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFFAFBF9);

  // Text / ink
  static const Color ink = Color(0xFF17251E);
  static const Color inkSoft = Color(0xFF2B3A32);
  static const Color muted = Color(0xFF737D76);

  // Borders / dividers
  static const Color border = Color(0xFFE2E8E3);
  static const Color borderStrong = Color(0xFFCFD8D1);

  // Greens (brand)
  static const Color green = Color(0xFF176B50);
  static const Color greenDeep = Color(0xFF103F31);
  static const Color greenSoft = Color(0xFFE8F2EC);
  static const Color greenTint = Color(0xFFD3E7DC);

  // Gold accent
  static const Color gold = Color(0xFFD6B66D);
  static const Color goldDeep = Color(0xFFB8964A);
  static const Color goldSoft = Color(0xFFF4ECD7);

  // Alert
  static const Color red = Color(0xFF9F5145);
  static const Color redSoft = Color(0xFFF5E5E2);

  // Overlay / scrim
  static const Color scrim = Color(0xCC0E1A14);
}

// -----------------------------------------------------------------------------
// SHADOWS (reusable)
// -----------------------------------------------------------------------------

abstract final class AppShadows {
  static final List<BoxShadow> soft = <BoxShadow>[
    BoxShadow(
      color: AppColors.ink.withValues(alpha: .04),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];

  static final List<BoxShadow> card = <BoxShadow>[
    BoxShadow(
      color: AppColors.ink.withValues(alpha: .05),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
    BoxShadow(
      color: AppColors.ink.withValues(alpha: .02),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static final List<BoxShadow> floating = <BoxShadow>[
    BoxShadow(
      color: AppColors.ink.withValues(alpha: .08),
      blurRadius: 28,
      offset: const Offset(0, 12),
    ),
  ];

  static List<BoxShadow> greenGlow({double alpha = .28}) => <BoxShadow>[
        BoxShadow(
          color: AppColors.greenDeep.withValues(alpha: alpha),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ];
}

// -----------------------------------------------------------------------------
// TEXT STYLE SHORTCUTS
// -----------------------------------------------------------------------------

abstract final class AppText {
  static const TextStyle eyebrow = TextStyle(
    color: AppColors.muted,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
  );

  static const TextStyle display = TextStyle(
    color: AppColors.ink,
    fontSize: 27,
    fontWeight: FontWeight.w700,
    letterSpacing: -.6,
    height: 1.15,
  );

  static const TextStyle title = TextStyle(
    color: AppColors.ink,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -.2,
  );

  static const TextStyle body = TextStyle(
    color: AppColors.muted,
    fontSize: 13,
    height: 1.6,
  );

  static const TextStyle label = TextStyle(
    color: AppColors.ink,
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    letterSpacing: -.1,
  );
}

// -----------------------------------------------------------------------------
// THEME
// -----------------------------------------------------------------------------

class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.green,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.green,
      onPrimary: Colors.white,
      primaryContainer: AppColors.greenSoft,
      onPrimaryContainer: AppColors.greenDeep,
      secondary: AppColors.greenDeep,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.greenTint,
      onSecondaryContainer: AppColors.greenDeep,
      tertiary: AppColors.gold,
      onTertiary: AppColors.ink,
      tertiaryContainer: AppColors.goldSoft,
      onTertiaryContainer: AppColors.goldDeep,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      surfaceContainerLowest: AppColors.surfaceAlt,
      surfaceContainerLow: AppColors.surface,
      surfaceContainer: AppColors.canvas,
      surfaceContainerHigh: AppColors.canvasDeep,
      onSurfaceVariant: AppColors.muted,
      outline: AppColors.borderStrong,
      outlineVariant: AppColors.border,
      error: AppColors.red,
      onError: Colors.white,
      errorContainer: AppColors.redSoft,
      onErrorContainer: AppColors.red,
      shadow: AppColors.ink,
      scrim: AppColors.scrim,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
    );

    final textTheme = _buildTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.canvas,
      canvasColor: AppColors.canvas,
      dividerColor: AppColors.border,
      disabledColor: AppColors.muted.withValues(alpha: .45),
      textTheme: textTheme,
      primaryTextTheme: textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),

      // App bar (surfaceTintColor is still valid here for AppBarTheme)
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -.3,
        ),
        iconTheme: IconThemeData(color: AppColors.ink, size: 22),
        actionsIconTheme: IconThemeData(color: AppColors.ink, size: 22),
      ),

      // Icons
      iconTheme: const IconThemeData(color: AppColors.muted, size: 22),

      // Cards (surfaceTintColor removed)
      cardTheme: CardThemeData(
        color: AppColors.surface,
        shadowColor: AppColors.ink.withValues(alpha: .06),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // Bottom nav (surfaceTintColor removed)
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 3,
        backgroundColor: AppColors.surface,
        shadowColor: AppColors.ink.withValues(alpha: .06),
        indicatorColor: AppColors.greenSoft,
        indicatorShape: const StadiumBorder(),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.greenDeep : AppColors.muted,
            size: 22,
          );
        }),
        labelTextStyle:
            WidgetStateProperty.resolveWith<TextStyle?>((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? AppColors.greenDeep : AppColors.muted,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: .1,
          );
        }),
      ),

      // Side rail (surfaceTintColor removed)
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        selectedIconTheme: const IconThemeData(color: AppColors.greenDeep),
        unselectedIconTheme: const IconThemeData(color: AppColors.muted),
        selectedLabelTextStyle: const TextStyle(
          color: AppColors.greenDeep,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: AppColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        indicatorColor: AppColors.greenSoft,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),

      // Buttons
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.muted,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            letterSpacing: .1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.ink,
          disabledBackgroundColor: AppColors.canvasDeep,
          disabledForegroundColor: AppColors.muted,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            letterSpacing: .1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            letterSpacing: .1,
          ),
          side: const BorderSide(color: AppColors.borderStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.green,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: .1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.ink,
          highlightColor: AppColors.greenSoft,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13.5),
        labelStyle: const TextStyle(color: AppColors.muted, fontSize: 13.5),
        floatingLabelStyle:
            const TextStyle(color: AppColors.green, fontSize: 13),
        prefixIconColor: AppColors.muted,
        suffixIconColor: AppColors.muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.green, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.red, width: 1.5),
        ),
      ),

      // Dialogs (surfaceTintColor removed)
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        shadowColor: AppColors.ink.withValues(alpha: .12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        titleTextStyle: const TextStyle(
          color: AppColors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -.3,
        ),
        contentTextStyle: const TextStyle(
          color: AppColors.muted,
          fontSize: 13.5,
          height: 1.55,
        ),
      ),

      // Bottom sheet (surfaceTintColor removed)
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        modalBackgroundColor: AppColors.surface,
        modalBarrierColor: Color(0x660E1A14),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      // Snack bar
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.greenDeep,
        actionTextColor: AppColors.gold,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 4,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),

      // Tooltips
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.ink.withValues(alpha: .92),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          letterSpacing: .1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        waitDuration: const Duration(milliseconds: 350),
      ),

      // Time picker (used by HomeScreen)
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        dialBackgroundColor: AppColors.greenSoft,
        dialHandColor: AppColors.green,
        dialTextColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return AppColors.ink;
        }),
        entryModeIconColor: WidgetStateColor.resolveWith(
          (_) => AppColors.green,
        ),
        hourMinuteColor: AppColors.greenSoft,
        hourMinuteTextColor: AppColors.greenDeep,
        hourMinuteShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        dayPeriodColor: AppColors.greenSoft,
        dayPeriodTextColor: AppColors.greenDeep,
        dayPeriodBorderSide: const BorderSide(color: AppColors.border),
        dayPeriodShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        helpTextStyle: const TextStyle(
          color: AppColors.muted,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
        cancelButtonStyle: TextButton.styleFrom(
          foregroundColor: AppColors.muted,
        ),
        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: AppColors.green,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.greenSoft,
        selectedColor: AppColors.green,
        disabledColor: AppColors.canvasDeep,
        labelStyle: const TextStyle(
          color: AppColors.greenDeep,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),

      // Selection
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.green,
        selectionColor: AppColors.greenTint,
        selectionHandleColor: AppColors.green,
      ),

      // Progress
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.green,
        linearTrackColor: AppColors.greenSoft,
        circularTrackColor: AppColors.greenSoft,
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),

      // Scrollbar
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
          return states.contains(WidgetState.dragged)
              ? AppColors.muted
              : AppColors.borderStrong;
        }),
        radius: const Radius.circular(20),
        thickness: WidgetStateProperty.all<double?>(6.0),
        interactive: true,
      ),

      // ListTile
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.green,
        textColor: AppColors.ink,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),

      // Popup menu
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        elevation: 6,
        shadowColor: AppColors.ink.withValues(alpha: .12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        textStyle: const TextStyle(
          color: AppColors.ink,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Page transitions (CupertinoPageTransitionsBuilder requires cupertino.dart import)
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Typography
  // ---------------------------------------------------------------------------

  static TextTheme _buildTextTheme(TextTheme base) {
    return base
        .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink)
        .copyWith(
          displayLarge: const TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.5,
            color: AppColors.ink,
            height: 1.1,
          ),
          displayMedium: const TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
            color: AppColors.ink,
            height: 1.12,
          ),
          displaySmall: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            letterSpacing: -.7,
            color: AppColors.ink,
            height: 1.15,
          ),
          headlineLarge: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -.6,
            color: AppColors.ink,
            height: 1.2,
          ),
          headlineMedium: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -.5,
            color: AppColors.ink,
            height: 1.22,
          ),
          headlineSmall: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -.4,
            color: AppColors.ink,
            height: 1.25,
          ),
          titleLarge: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -.3,
            color: AppColors.ink,
            height: 1.3,
          ),
          titleMedium: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -.2,
            color: AppColors.ink,
            height: 1.35,
          ),
          titleSmall: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: -.1,
            color: AppColors.ink,
            height: 1.4,
          ),
          bodyLarge: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: AppColors.ink,
            height: 1.55,
          ),
          bodyMedium: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w400,
            color: AppColors.ink,
            height: 1.55,
          ),
          bodySmall: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppColors.muted,
            height: 1.5,
          ),
          labelLarge: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: .1,
            color: AppColors.ink,
          ),
          labelMedium: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            letterSpacing: .2,
            color: AppColors.muted,
          ),
          labelSmall: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: .8,
            color: AppColors.muted,
          ),
        );
  }
}