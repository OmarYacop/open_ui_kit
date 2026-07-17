import 'package:flutter/widgets.dart';

import 'theme/ui_theme_extensions.dart';

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
class UiApp extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    final light = lightTokens ?? UiThemeTokens.light;
    final dark = darkTokens ?? UiThemeTokens.dark;

    return WidgetsApp(
      key: const ValueKey('ui_app'),
      navigatorKey: navigatorKey,
      navigatorObservers: navigatorObservers,
      title: title,
      color: light.colors.primary,
      locale: locale,
      localizationsDelegates: localizationsDelegates,
      supportedLocales: supportedLocales,
      localeResolutionCallback: localeResolutionCallback,
      localeListResolutionCallback: localeListResolutionCallback,
      debugShowCheckedModeBanner: debugShowCheckedModeBanner,
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) {
        return PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (ctx, _, __) => builder(ctx),
          transitionsBuilder: (ctx, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        );
      },
      builder: (context, child) {
        final brightness = _brightnessFor(context);
        final tokens = brightness == Brightness.dark ? dark : light;
        final themed = UiAppContext(
          title: title,
          child: UiTheme(
            tokens: tokens,
            child: child ?? const SizedBox.shrink(),
          ),
        );
        return builder == null ? themed : builder!(context, themed);
      },
      home: home,
    );
  }

  Brightness _brightnessFor(BuildContext context) {
    switch (mode) {
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
