import 'package:flutter/widgets.dart';

import '../../foundation/theme/ui_theme_extensions.dart';
import 'ui_cupertino_back_gesture.dart';
import 'ui_navigation_transition.dart';

/// Open UI Kit's standard [PageRoute]: [UiNavigationTransition] visuals
/// (default [UiNavigationTransitionStyle.softShift] — a fade + subtle
/// shift + scale, not a plain cross-fade) with iOS's progressive
/// edge-swipe-to-pop gesture layered on top via
/// [UiCupertinoBackGestureMixin].
///
/// This is what [UiApp] pushes by default for any route it generates and
/// what [UiDualPane] uses for its phone-pushed detail pane, so a plain
/// `Navigator.push` and a purpose-built pattern both read as the same
/// "signature" push/pop — including the interactive drag, which moves
/// this route's own transition directly rather than a separately-tracked
/// preview (see [UiCupertinoBackGestureMixin] for why that distinction
/// matters: it's what keeps the reveal showing the real page underneath,
/// live, instead of a stale snapshot).
///
/// Most call sites want [BuildContext.pushUiPage] rather than
/// constructing this directly.
class UiPageRoute<T> extends PageRouteBuilder<T>
    with UiCupertinoBackGestureMixin<T> {
  UiPageRoute({
    required WidgetBuilder builder,
    super.settings,
    this.swipeBackEnabled = true,
    UiNavigationTransitionStyle transitionStyle =
        UiNavigationTransitionStyle.softShift,
    super.transitionDuration = const Duration(milliseconds: 220),
    super.reverseTransitionDuration = const Duration(milliseconds: 160),
    super.opaque,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final tokens = UiThemeTokens.of(context);
            return UiNavigationTransition(
              animation: CurvedAnimation(
                parent: animation,
                curve: tokens.motion.standardCurve,
                reverseCurve: tokens.motion.standardCurve,
              ),
              style: transitionStyle,
              reverse: animation.status == AnimationStatus.reverse,
              child: child,
            );
          },
        );

  /// Whether this route may be dismissed via the iOS edge-swipe-back
  /// gesture. [UiCupertinoBackGestureMixin] only ever attaches it on iOS
  /// regardless of this flag; set to `false` for routes that must only be
  /// left via an explicit in-page action (e.g. a required onboarding
  /// step).
  final bool swipeBackEnabled;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final transitioned = super.buildTransitions(
      context,
      animation,
      secondaryAnimation,
      child,
    );
    if (!swipeBackEnabled) return transitioned;
    return wrapWithBackGesture(context, transitioned);
  }
}

/// App-wide fallback for [UiPageRoute]'s style and swipe-back behavior.
/// [UiApp] provides this from its own `defaultPageTransitionStyle` /
/// `defaultPageSwipeBackEnabled` constructor arguments; [BuildContext.pushUiPage]
/// reads it whenever a call doesn't override those explicitly, so changing
/// the app-wide default and overriding a single push both work — one isn't
/// an escape hatch that bypasses the other.
class UiPageRouteDefaults extends InheritedWidget {
  const UiPageRouteDefaults({
    super.key,
    required this.transitionStyle,
    required this.swipeBackEnabled,
    required super.child,
  });

  final UiNavigationTransitionStyle transitionStyle;
  final bool swipeBackEnabled;

  static UiPageRouteDefaults? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<UiPageRouteDefaults>();
  }

  @override
  bool updateShouldNotify(UiPageRouteDefaults oldWidget) {
    return transitionStyle != oldWidget.transitionStyle ||
        swipeBackEnabled != oldWidget.swipeBackEnabled;
  }
}

/// Pushes [builder] on a [UiPageRoute] — Open UI Kit's standard page push.
///
/// [transitionStyle] and [swipeBackEnabled] default to whatever [UiApp]
/// was configured with ([UiPageRouteDefaults], read ambiently) when a call
/// doesn't pass them explicitly — falling back further to
/// [UiNavigationTransitionStyle.softShift] / `true` outside a [UiApp] (e.g.
/// in isolated widget tests).
extension UiPageNavigation on BuildContext {
  Future<T?> pushUiPage<T>(
    WidgetBuilder builder, {
    RouteSettings? settings,
    bool rootNavigator = false,
    bool? swipeBackEnabled,
    UiNavigationTransitionStyle? transitionStyle,
  }) {
    final defaults = UiPageRouteDefaults.maybeOf(this);
    return Navigator.of(this, rootNavigator: rootNavigator).push<T>(
      UiPageRoute<T>(
        builder: builder,
        settings: settings,
        swipeBackEnabled:
            swipeBackEnabled ?? defaults?.swipeBackEnabled ?? true,
        transitionStyle: transitionStyle ??
            defaults?.transitionStyle ??
            UiNavigationTransitionStyle.softShift,
      ),
    );
  }
}
