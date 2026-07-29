import 'package:flutter/widgets.dart';

import 'motion/ui_motion_spec.dart';
import 'reactive/ui_clock.dart';
import 'theme/ui_theme_extensions.dart';
import '../patterns/navigation/ui_navigation_transition.dart';

/// How [UiApp] picks between its light and dark token sets.
enum UiThemeMode { system, light, dark }

/// Material-free application root.
///
/// Wraps [WidgetsApp] (not `MaterialApp`) and injects [UiThemeTokens] through a
/// [UiTheme] host, so the whole tree resolves design tokens via
/// `UiThemeTokens.of(context)` without any Material `Theme`. Routes pushed by
/// open_ui_kit overlays (`UiSheetScope`, `UiDialogScope`) sit inside the [UiTheme],
/// so sheets and dialogs are themed too.
///
/// Localization (including RTL text direction for ar/ur) comes from the
/// delegates you pass — include `GlobalWidgetsLocalizations.delegate`.
class UiApp extends StatefulWidget {
  const UiApp({
    super.key,
    this.home,
    this.lightTokens,
    this.darkTokens,
    this.mode = UiThemeMode.system,
    this.locale,
    this.localizationsDelegates = const [],
    this.supportedLocales = const [Locale('en')],
    this.localeResolutionCallback,
    this.localeListResolutionCallback,
    this.title = '',
    this.debugShowCheckedModeBanner = true,
    this.builder,
    this.navigatorKey,
    this.navigatorObservers = const [],
    this.pageTransitionDuration = UiMotionDuration.standard,
    this.pageReverseTransitionDuration = UiMotionDuration.fast,
    this.clockController,
    this.clockTickMode = UiClockTickMode.minute,
    this.clockTickInterval,
  });

  final Widget? home;
  final UiThemeTokens? lightTokens;
  final UiThemeTokens? darkTokens;
  final UiThemeMode mode;
  final Locale? locale;
  final Iterable<LocalizationsDelegate<dynamic>> localizationsDelegates;
  final Iterable<Locale> supportedLocales;
  final LocaleResolutionCallback? localeResolutionCallback;
  final LocaleListResolutionCallback? localeListResolutionCallback;
  final String title;
  final bool debugShowCheckedModeBanner;
  final TransitionBuilder? builder;
  final GlobalKey<NavigatorState>? navigatorKey;
  final List<NavigatorObserver> navigatorObservers;

  /// Default route timing. Accepts a theme token or an authored custom value.
  final UiMotionDuration pageTransitionDuration;
  final UiMotionDuration pageReverseTransitionDuration;

  final UiClockController? clockController;
  final UiClockTickMode clockTickMode;
  final Duration? clockTickInterval;

  @override
  State<UiApp> createState() => _UiAppState();
}

class _UiAppState extends State<UiApp> {
  final HeroController _heroController = HeroController();

  @override
  Widget build(BuildContext context) {
    final light = widget.lightTokens ?? UiThemeTokens.light;
    final dark = widget.darkTokens ?? UiThemeTokens.dark;
    final reducedMotion = MediaQuery.maybeDisableAnimationsOf(context) ??
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
            .disableAnimations;
    final routeDuration = widget.pageTransitionDuration.resolveFromTokens(
      light.motion,
      reducedMotion: reducedMotion,
    );
    final routeReverseDuration = widget.pageReverseTransitionDuration
        .resolveFromTokens(light.motion, reducedMotion: reducedMotion);
    final navigatorObservers = <NavigatorObserver>[
      if (!widget.navigatorObservers.any(
        (observer) => observer is HeroController,
      ))
        _heroController,
      ...widget.navigatorObservers,
    ];

    return WidgetsApp(
      key: const ValueKey('ui_app'),
      navigatorKey: widget.navigatorKey,
      navigatorObservers: navigatorObservers,
      title: widget.title,
      color: light.colors.primary,
      locale: widget.locale,
      localizationsDelegates: widget.localizationsDelegates,
      supportedLocales: widget.supportedLocales,
      localeResolutionCallback: widget.localeResolutionCallback,
      localeListResolutionCallback: widget.localeListResolutionCallback,
      debugShowCheckedModeBanner: widget.debugShowCheckedModeBanner,
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) {
        return PageRouteBuilder<T>(
          settings: settings,
          transitionDuration: routeDuration,
          reverseTransitionDuration: routeReverseDuration,
          pageBuilder: (ctx, _, __) => builder(ctx),
          transitionsBuilder: (ctx, animation, _, child) {
            final tokens = UiThemeTokens.of(ctx);
            return UiNavigationTransition(
              animation: CurvedAnimation(
                parent: animation,
                curve: tokens.motion.standardCurve,
                reverseCurve: tokens.motion.standardCurve,
              ),
              child: child,
            );
          },
        );
      },
      builder: (context, child) {
        final brightness = _brightnessFor(context);
        final tokens = brightness == Brightness.dark ? dark : light;
        final themed = UiClockScope(
          controller: widget.clockController,
          tickMode: widget.clockTickMode,
          tickInterval: widget.clockTickInterval,
          child: UiAppContext(
            title: widget.title,
            child: UiTheme(
              tokens: tokens,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
        return widget.builder == null
            ? themed
            : widget.builder!(context, themed);
      },
      home: widget.home,
    );
  }

  Brightness _brightnessFor(BuildContext context) {
    switch (widget.mode) {
      case UiThemeMode.light:
        return Brightness.light;
      case UiThemeMode.dark:
        return Brightness.dark;
      case UiThemeMode.system:
        return MediaQuery.maybePlatformBrightnessOf(context) ??
            Brightness.light;
    }
  }
}

class UiAppContext extends InheritedWidget {
  const UiAppContext({
    super.key,
    required this.title,
    required super.child,
  });

  final String title;

  static String? maybeTitleOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<UiAppContext>();
    final title = scope?.title.trim();
    return title == null || title.isEmpty ? null : title;
  }

  static String titleOf(BuildContext context, {String fallback = ''}) {
    return maybeTitleOf(context) ?? fallback;
  }

  @override
  bool updateShouldNotify(UiAppContext oldWidget) => title != oldWidget.title;
}
