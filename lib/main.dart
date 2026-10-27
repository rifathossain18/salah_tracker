import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'services/prayer_repository.dart';
import 'theme/app_theme.dart';

// -----------------------------------------------------------------------------
// ENTRY POINT
// -----------------------------------------------------------------------------

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Premium edge-to-edge system chrome:
  //   • Transparent status bar with dark icons (matches the light theme)
  //   • Navigation bar tinted to match our brand surface
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: AppColors.border,
    ),
  );

  runApp(const SalahTrackerApp());
}

// -----------------------------------------------------------------------------
// APP ROOT
// -----------------------------------------------------------------------------

class SalahTrackerApp extends StatelessWidget {
  const SalahTrackerApp({super.key, this.repository = const PrayerRepository()});

  final PrayerRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // -------------------------------------------------------------------------
      // Identity
      // -------------------------------------------------------------------------
      title: 'Salah Tracker',
      debugShowCheckedModeBanner: false,
      debugShowMaterialGrid: false,
      showPerformanceOverlay: false,
      checkerboardOffscreenLayers: false,
      checkerboardRasterCacheImages: false,
      showSemanticsDebugger: false,

      // -------------------------------------------------------------------------
      // Theme
      // -------------------------------------------------------------------------
      theme: AppTheme.light,
      themeMode: ThemeMode.light,

      // -------------------------------------------------------------------------
      // Interaction — smooth mouse-drag on web/desktop, stretch overscroll
      // -------------------------------------------------------------------------
      scrollBehavior: const _PremiumScrollBehavior(),

      // -------------------------------------------------------------------------
      // Accessibility — respect text scale but keep layout intact
      // -------------------------------------------------------------------------
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(
              minScaleFactor: 1.0,
              maxScaleFactor: 1.3,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },

      // -------------------------------------------------------------------------
      // Root screen
      // -------------------------------------------------------------------------
      home: HomeScreen(repository: repository),
    );
  }
}

// -----------------------------------------------------------------------------
// PREMIUM SCROLL BEHAVIOR
// -----------------------------------------------------------------------------

class _PremiumScrollBehavior extends MaterialScrollBehavior {
  const _PremiumScrollBehavior();

  /// Allow drag-to-scroll with a mouse — essential for web & desktop.
  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };

  /// Soft stretch overscroll on Android (more premium than the default glow).
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (getPlatform(context) == TargetPlatform.android) {
      return StretchingOverscrollIndicator(
        axisDirection: details.direction,
        child: child,
      );
    }
    return child;
  }

  /// Always-available scrollbars on desktop platforms.
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    switch (getPlatform(context)) {
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return Scrollbar(
          controller: details.controller,
          child: child,
        );
      default:
        return child;
    }
  }
}