import 'package:flutter/widgets.dart';

import 'motion/ui_motion_spec.dart';
import 'reactive/ui_clock.dart';
import 'scrolling/ui_scroll_configuration.dart';
import 'theme/ui_theme_extensions.dart';
import '../patterns/navigation/ui_navigation_transition.dart';
import '../patterns/navigation/ui_navigator_history.dart';
import '../patterns/navigation/ui_page_route.dart';

/// How [UiApp] picks between its light and dark token sets.
enum UiThemeMode {
  /// Follow the operating-system appearance dynamically.
  system,

  /// Always resolve [UiApp.lightTokens], regardless of system appearance.
  light,

  /// Always resolve [UiApp.darkTokens], regardless of system appearance.
  dark,
}

/// Material-free application root.
///
/// Wraps [WidgetsApp] and injects [UiThemeTokens] through a
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
    this.defaultPageTransitionStyle = UiNavigationTransitionStyle.softShift,
    this.defaultPageSwipeBackEnabled = true,
    this.clockController,
    this.clockTickMode = UiClockTickMode.minute,
    this.clockTickInterval,
  });

  final Widget? home;
  final UiThemeTokens? lightTokens;
  final UiThemeTokens? darkTokens;

  /// Appearance policy. Use [UiThemeMode.light] or [UiThemeMode.dark] to force
  /// a mode; [UiThemeMode.system] is only the default, not a restriction.
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

  /// App-wide default for any route [UiApp] generates itself (e.g. a plain
  /// `Navigator.pushNamed`) and for [BuildContext.pushUiPage] calls that
  /// don't override it. Defaults to [UiNavigationTransitionStyle.softShift]
  /// — the kit's signature push/pop, not a plain cross-fade. A single
  /// `pushUiPage`/[UiPageRoute] call can still override this per route via
  /// its own `transitionStyle` argument.
  final UiNavigationTransitionStyle defaultPageTransitionStyle;

  /// App-wide default for whether pushed routes support the progressive
  /// iOS edge-swipe-back gesture (see [UiCupertinoBackGestureMixin] — it
  /// only ever attaches on iOS regardless of this flag). A single
  /// `pushUiPage`/[UiPageRoute] call can still override this per route via
  /// its own `swipeBackEnabled` argument.
  final bool defaultPageSwipeBackEnabled;

  final UiClockController? clockController;
  final UiClockTickMode clockTickMode;
  final Duration? clockTickInterval;

  @override
  State<UiApp> createState() => _UiAppState();
}

class _UiAppState extends State<UiApp> {
  final HeroController _heroController = HeroController();
  final UiNavigatorHistoryObserver _historyObserver =
      UiNavigatorHistoryObserver();

  @override
  void dispose() {
    _historyObserver.dispose();
    super.dispose();
  }

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
      if (!widget.navigatorObservers.any(
        (observer) => observer is UiNavigatorHistoryObserver,
      ))
        _historyObserver,
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
      // UiPageRoute is Open UI Kit's standard push/pop: the same
      // UiNavigationTransition (softShift by default — fade + subtle
      // shift + scale, not a plain cross-fade) plus a progressive
      // iOS edge-swipe-to-pop, matching how iOS users actually expect a
      // push to behave. Any route WidgetsApp generates by default — and
      // BuildContext.pushUiPage, for routes pushed explicitly — both go
      // through this, so every push/pop in an app built on UiApp reads as
      // one signature motion.
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) {
        return UiPageRoute<T>(
          settings: settings,
          builder: builder,
          transitionDuration: routeDuration,
          reverseTransitionDuration: routeReverseDuration,
          transitionStyle: widget.defaultPageTransitionStyle,
          swipeBackEnabled: widget.defaultPageSwipeBackEnabled,
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
              child: UiPageRouteDefaults(
                transitionStyle: widget.defaultPageTransitionStyle,
                swipeBackEnabled: widget.defaultPageSwipeBackEnabled,
                child: UiNavigatorHistoryScope(
                  observer: _historyObserver,
                  child: UiScrollConfiguration(
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
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
