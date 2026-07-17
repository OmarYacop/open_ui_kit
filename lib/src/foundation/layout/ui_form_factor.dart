import 'package:flutter/widgets.dart';

/// Canonical form-factor classifier shared by layout, navigation, and
/// adaptive components.
///
/// The kit historically exposed `UiNavigationFormFactor` inside
/// `UiResponsiveNavigationScaffold`; this enum is the foundation-level
/// equivalent. The navigation scaffold's enum is retained as a
/// synonym for source-level backwards compatibility, but new code
/// should consume [UiFormFactor].
enum UiFormFactor { phone, tablet, desktop }

/// Default breakpoints used when callers don't override. Picked to
/// match Material 3 / Apple HIG recommendations:
///
/// - `< 600dp` → phone
/// - `600..900dp` → tablet (small landscape / foldable / portrait iPad)
/// - `>= 900dp` → desktop (iPad landscape / macOS / Android tablet L)
@immutable
class UiBreakpoints {
  const UiBreakpoints({
    this.phone = 600,
    this.desktop = 900,
  }) : assert(
          phone < desktop,
          'phone breakpoint must be strictly less than desktop',
        );

  /// Max width below which the layout is treated as a phone.
  final double phone;

  /// Min width at or above which the layout is treated as a desktop.
  final double desktop;

  /// Default breakpoints. Use when no per-app override is desired.
  static const UiBreakpoints standard = UiBreakpoints();

  /// Resolve the form factor for a given [width] (logical pixels).
  UiFormFactor resolve(double width) {
    if (width >= desktop) return UiFormFactor.desktop;
    if (width >= phone) return UiFormFactor.tablet;
    return UiFormFactor.phone;
  }
}

/// Read the current [UiFormFactor] from [BuildContext].
///
/// Uses `MediaQuery.sizeOf(context).width` so the widget rebuilds when
/// the viewport changes (rotation, window resize, split-view). Pass
/// [breakpoints] to use a custom classifier for the call site.
UiFormFactor uiFormFactorOf(
  BuildContext context, {
  UiBreakpoints breakpoints = UiBreakpoints.standard,
}) {
  final width = MediaQuery.sizeOf(context).width;
  return breakpoints.resolve(width);
}

/// Adaptive builder that dispatches by form factor.
///
/// Three composition patterns cover the "adaptation strategies" the
/// kit uses across components; pick the one that fits the call site:
///
/// ### 1. Mode switching — show a completely different subtree
///
/// ```dart
/// UiAdaptive.mode(
///   phone: (_) => const _PhoneDrawer(),
///   tablet: (_) => const _TabletSidebar(),
///   desktop: (_) => const _DesktopSidebar(),
/// )
/// ```
///
/// Missing form factors fall back to the next-smallest that was
/// provided, so `tablet: null` with a `phone:` builder will use the
/// phone build on tablet. This lets callers opt-in only where the
/// layout actually differs.
///
/// ### 2. Variant — same widget, different values
///
/// ```dart
/// UiAdaptive.variant<double>(
///   phone: 16.0,
///   tablet: 24.0,
///   desktop: 32.0,
///   builder: (context, padding) => Padding(
///     padding: EdgeInsets.all(padding),
///     child: child,
///   ),
/// )
/// ```
///
/// ### 3. Section visibility — hide/show sub-regions by form factor
///
/// ```dart
/// UiAdaptive.visible(
///   phone: false,     // drop on small screens
///   tablet: true,
///   desktop: true,
///   child: const _DetailPanel(),
/// )
/// ```
///
/// `UiAdaptive.visible(phone: false, ...)` returns a zero-size
/// `SizedBox.shrink()` — the subtree is not built, so it's safe for
/// heavy children.
class UiAdaptive extends StatelessWidget {
  const UiAdaptive._({
    super.key,
    this.modeBuilder,
    this.variantValue,
    this.variantBuilder,
    this.visibleChild,
    this.visibleMap,
    this.breakpoints = UiBreakpoints.standard,
  });

  /// Dispatch to a different widget per form factor.
  ///
  /// Missing entries fall back to smaller form factors (tablet → phone,
  /// desktop → tablet → phone). At least one builder must be non-null.
  factory UiAdaptive.mode({
    Key? key,
    WidgetBuilder? phone,
    WidgetBuilder? tablet,
    WidgetBuilder? desktop,
    UiBreakpoints breakpoints = UiBreakpoints.standard,
  }) {
    assert(
      phone != null || tablet != null || desktop != null,
      'UiAdaptive.mode requires at least one builder',
    );
    return UiAdaptive._(
      key: key,
      modeBuilder: (context, ff) {
        switch (ff) {
          case UiFormFactor.desktop:
            return (desktop ?? tablet ?? phone)!(context);
          case UiFormFactor.tablet:
            return (tablet ?? phone ?? desktop)!(context);
          case UiFormFactor.phone:
            return (phone ?? tablet ?? desktop)!(context);
        }
      },
      breakpoints: breakpoints,
    );
  }

  /// Feed a form-factor-varying value into a single builder.
  ///
  /// Missing entries fall back to smaller form factors (tablet → phone,
  /// desktop → tablet → phone). [phone] is required because it
  /// anchors the fallback chain.
  static UiAdaptive variant<T>({
    Key? key,
    required T phone,
    T? tablet,
    T? desktop,
    required Widget Function(BuildContext context, T value) builder,
    UiBreakpoints breakpoints = UiBreakpoints.standard,
  }) {
    return UiAdaptive._(
      key: key,
      variantValue: (ff) {
        switch (ff) {
          case UiFormFactor.desktop:
            return desktop ?? tablet ?? phone;
          case UiFormFactor.tablet:
            return tablet ?? phone;
          case UiFormFactor.phone:
            return phone;
        }
      },
      variantBuilder: (context, value) =>
          builder(context, value as T),
      breakpoints: breakpoints,
    );
  }

  /// Toggle section visibility by form factor.
  ///
  /// Defaults show [child] on all form factors — override per
  /// form factor with `false` to drop the subtree entirely.
  factory UiAdaptive.visible({
    Key? key,
    required Widget child,
    bool phone = true,
    bool tablet = true,
    bool desktop = true,
    UiBreakpoints breakpoints = UiBreakpoints.standard,
  }) {
    return UiAdaptive._(
      key: key,
      visibleChild: child,
      visibleMap: {
        UiFormFactor.phone: phone,
        UiFormFactor.tablet: tablet,
        UiFormFactor.desktop: desktop,
      },
      breakpoints: breakpoints,
    );
  }

  final Widget Function(BuildContext, UiFormFactor)? modeBuilder;
  final Object? Function(UiFormFactor)? variantValue;
  final Widget Function(BuildContext, Object?)? variantBuilder;
  final Widget? visibleChild;
  final Map<UiFormFactor, bool>? visibleMap;
  final UiBreakpoints breakpoints;

  @override
  Widget build(BuildContext context) {
    final ff = uiFormFactorOf(context, breakpoints: breakpoints);
    if (modeBuilder != null) {
      return modeBuilder!(context, ff);
    }
    if (variantBuilder != null && variantValue != null) {
      return variantBuilder!(context, variantValue!(ff));
    }
    if (visibleChild != null && visibleMap != null) {
      final visible = visibleMap![ff] ?? true;
      return visible ? visibleChild! : const SizedBox.shrink();
    }
    // Unreachable — factory constructors guarantee exactly one path.
    return const SizedBox.shrink();
  }
}
