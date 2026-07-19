import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../../foundation/intl/ui_localizations.dart';
import '../../foundation/layout/layout.dart';
import '../../foundation/motion/ui_stacked_motion.dart';
import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_divider.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

/// Edge a drawer attaches to.
///
/// - [left] / [right] are **absolute** and never flip under RTL.
///   Use them for split-view or pinned-to-physical-edge surfaces.
/// - [start] / [end] are **directional** and resolve per
///   `Directionality.of(context)`: `start` is the leading edge
///   (left in LTR, right in RTL), `end` is the trailing edge.
///   These are what you almost always want for a navigation
///   drawer so the slide animation mirrors correctly in Arabic /
///   Hebrew locales.
enum UiDrawerSide { left, right, start, end }

/// Visual treatment for modal drawers.
enum UiDrawerVariant {
  /// Edge-attached drawer. This preserves the legacy surface behavior.
  standard,

  /// Floating drawer with inset margins, rounded corners, blur backdrop,
  /// and stronger elevation.
  floating,

  /// Floating drawer using the same depth scale/offset rules as stacked
  /// toasts. Useful for drill-in or nested command surfaces.
  stacked,
}

enum _UiDrawerPlacement { side, bottom }

const double _kPhoneSideDrawerMaxWidth = 324;
const double _kPhoneSideDrawerEdgeInset = 48;

@immutable
class _UiDrawerLayoutMetrics {
  const _UiDrawerLayoutMetrics({
    required this.placement,
    required this.sideWidth,
    required this.bottomMaxWidth,
    required this.bottomMaxHeight,
  });

  final _UiDrawerPlacement placement;
  final double sideWidth;
  final double bottomMaxWidth;
  final double bottomMaxHeight;

  _UiDrawerLayoutMetrics copyWith({
    _UiDrawerPlacement? placement,
    double? sideWidth,
    double? bottomMaxWidth,
    double? bottomMaxHeight,
  }) {
    return _UiDrawerLayoutMetrics(
      placement: placement ?? this.placement,
      sideWidth: sideWidth ?? this.sideWidth,
      bottomMaxWidth: bottomMaxWidth ?? this.bottomMaxWidth,
      bottomMaxHeight: bottomMaxHeight ?? this.bottomMaxHeight,
    );
  }

  static _UiDrawerLayoutMetrics resolve(
    Size size,
    double requestedWidth, {
    double? maxWidth,
  }) {
    final shortestSide = size.shortestSide;
    final isPhone = shortestSide < 600;
    final isLandscape = size.width > size.height;
    final placement = isPhone && !isLandscape
        ? _UiDrawerPlacement.side
        : _UiDrawerPlacement.bottom;

    final sideAvailable = (size.width - _kPhoneSideDrawerEdgeInset).clamp(
      0.0,
      double.infinity,
    );
    final resolvedMaxWidth = maxWidth ?? _kPhoneSideDrawerMaxWidth;
    final sideMax =
        sideAvailable < resolvedMaxWidth ? sideAvailable : resolvedMaxWidth;
    final sideWidth = requestedWidth.clamp(0.0, sideMax).toDouble();
    final bottomMaxHeight = isPhone
        ? (size.height * 0.86).clamp(240.0, 420.0)
        : (size.height * 0.72).clamp(360.0, 640.0);
    final bottomAvailable = isPhone ? size.width : size.width - 64;
    final bottomMax = maxWidth ?? (isPhone ? size.width : 720.0);
    final bottomMaxWidth = bottomAvailable.clamp(0.0, bottomMax).toDouble();

    return _UiDrawerLayoutMetrics(
      placement: placement,
      sideWidth: sideWidth,
      bottomMaxWidth: bottomMaxWidth,
      bottomMaxHeight: bottomMaxHeight,
    );
  }
}

/// Drawer content wrapper. Usually presented by [UiDrawerScope.show].
class UiDrawer extends StatelessWidget {
  const UiDrawer({
    super.key,
    this.child,
    this.header,
    this.body,
    this.footer,
    this.side = UiDrawerSide.start,
    this.width = 300,
    this.maxWidth,
    this.variant = UiDrawerVariant.standard,
    this.margin,
    this.borderRadius,
    this.adaptiveDeviceRadius = true,
    this.useSafeArea = true,
    this.safeAreaTop = true,
    this.safeAreaBottom = true,
    this.safeAreaLeft = true,
    this.safeAreaRight = true,
    this.safeAreaMinimum = EdgeInsets.zero,
    this.backgroundColor,
    this.semanticsLabel,
  })  : assert(
          child != null || header != null || body != null || footer != null,
          'Provide child or at least one structured drawer region.',
        ),
        assert(
          child == null || (header == null && body == null && footer == null),
          'child cannot be combined with header, body, or footer.',
        ),
        assert(
          maxWidth == null || maxWidth > 0,
          'maxWidth must be greater than zero.',
        );

  /// Legacy, fully custom drawer content.
  ///
  /// Prefer the named [header], [body], and [footer] regions for new drawers.
  /// The structured form pins the header and footer while allowing only the
  /// body to scroll.
  final Widget? child;

  /// Fixed region at the top of the drawer.
  final Widget? header;

  /// Scrollable drawer content between [header] and [footer].
  final Widget? body;

  /// Fixed region at the bottom of the drawer.
  final Widget? footer;
  final UiDrawerSide side;
  final double width;

  /// Optional maximum width used by adaptive drawer layouts.
  ///
  /// In phone portrait side mode, [width] is still the requested width and
  /// [maxWidth] caps it after reserving the fixed edge inset. In bottom mode,
  /// [maxWidth] caps the bottom panel width instead of the default large-screen
  /// maximum.
  final double? maxWidth;

  final UiDrawerVariant variant;
  final EdgeInsetsGeometry? margin;

  /// Explicit surface radius. When omitted, floating drawers use the theme's
  /// large radius and standard drawers can infer physical-edge corners from
  /// safe-area signals.
  final BorderRadiusGeometry? borderRadius;

  /// When true, standard drawers infer a physical-edge radius from device
  /// safe-area signals such as the home indicator or landscape cutout insets.
  /// Flutter does not expose exact hardware corner radii.
  final bool adaptiveDeviceRadius;

  /// Wraps the drawer surface itself in [SafeArea], keeping the panel out of
  /// display cutouts, rounded screen corners, and the home indicator.
  final bool useSafeArea;

  /// Safe-area edge controls used when [useSafeArea] is true.
  final bool safeAreaTop;
  final bool safeAreaBottom;
  final bool safeAreaLeft;
  final bool safeAreaRight;

  /// Minimum padding passed through to [SafeArea].
  final EdgeInsets safeAreaMinimum;
  final Color? backgroundColor;

  /// Spoken label announced when focus enters the drawer. Defaults to
  /// the localized "Drawer" (`UiLocalizations.drawer`) so screen-reader
  /// users know they've moved into a side panel. Pass an empty string
  /// to suppress the announcement.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final direction = Directionality.of(context);
    final c = tokens.colors;
    final inherited = _UiDrawerPresentation.maybeOf(context);
    final effectiveSide =
        side == UiDrawerSide.start ? (inherited?.side ?? side) : side;
    final effectiveVariant = variant == UiDrawerVariant.standard
        ? (inherited?.variant ?? variant)
        : variant;
    final layoutMetrics = _UiDrawerLayoutMetrics.resolve(
      MediaQuery.sizeOf(context),
      width,
      maxWidth: maxWidth,
    );
    final inheritedMetrics = inherited?.layoutMetrics;
    final effectiveLayoutMetrics = inheritedMetrics == null
        ? layoutMetrics
        : layoutMetrics.copyWith(
            placement: inheritedMetrics.placement,
            bottomMaxWidth:
                inheritedMetrics.bottomMaxWidth < layoutMetrics.bottomMaxWidth
                    ? inheritedMetrics.bottomMaxWidth
                    : layoutMetrics.bottomMaxWidth,
          );
    final placement = effectiveLayoutMetrics.placement;
    final isBottom = placement == _UiDrawerPlacement.bottom;
    final resolvedLeft = _resolveIsLeft(
      effectiveSide,
      direction,
    );
    final strings = UiLocalizations.of(context);
    final resolvedLabel = semanticsLabel ?? strings.drawer;
    final floating = effectiveVariant != UiDrawerVariant.standard;
    final baseMargin = (margin ?? EdgeInsets.all(tokens.spacing.x3)).resolve(
      direction,
    );
    final bottomMarginMinimum = margin == null
        ? baseMargin.bottom + tokens.spacing.x1
        : baseMargin.bottom;
    final resolvedMargin = floating && useSafeArea && safeAreaBottom
        ? baseMargin.copyWith(
            bottom: resolveUiEdgeAwareBottomOffset(
              context,
              minimum: bottomMarginMinimum,
            ),
          )
        : baseMargin;
    final radius = borderRadius ??
        _resolveAdaptiveRadius(
          context,
          floating: floating,
          placement: placement,
          isLeft: resolvedLeft,
          adaptive: adaptiveDeviceRadius,
        );
    final resolvedRadius = radius.resolve(direction);
    final hasRadius = _hasVisibleRadius(resolvedRadius);
    final isStackedBehind = effectiveVariant == UiDrawerVariant.stacked &&
        (inherited?.stackDepth ?? 0) > 0;
    final border = floating
        ? Border.all(color: c.border)
        : hasRadius
            ? Border.all(color: c.border)
            : isBottom
                ? Border(top: BorderSide(color: c.border))
                : Border(
                    right: resolvedLeft
                        ? BorderSide(color: c.border)
                        : BorderSide.none,
                    left: resolvedLeft
                        ? BorderSide.none
                        : BorderSide(color: c.border),
                  );
    final content =
        child ?? _UiDrawerRegions(header: header, body: body, footer: footer);
    final effectiveWidth =
        isBottom ? double.infinity : effectiveLayoutMetrics.sideWidth;
    final sizeBox = isBottom
        ? ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: effectiveLayoutMetrics.bottomMaxWidth,
              maxHeight: effectiveLayoutMetrics.bottomMaxHeight,
            ),
            child: SizedBox(width: effectiveWidth, child: content),
          )
        : SizedBox(width: effectiveWidth, child: content);
    Widget drawer = Padding(
      padding: floating ? resolvedMargin : EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: isBottom
            ? BoxConstraints(
                maxWidth: effectiveLayoutMetrics.bottomMaxWidth,
                maxHeight: effectiveLayoutMetrics.bottomMaxHeight,
              )
            : const BoxConstraints(),
        child: ClipRRect(
          borderRadius: resolvedRadius,
          child: UiBox(
            background: backgroundColor ?? c.card,
            border: border,
            borderRadius: resolvedRadius,
            boxShadow: isStackedBehind
                ? tokens.shadows.none
                : floating
                    ? tokens.shadows.lg
                    : tokens.shadows.md,
            child: sizeBox,
          ),
        ),
      ),
    );
    if (useSafeArea) {
      drawer = SafeArea(
        top: safeAreaTop,
        bottom: safeAreaBottom && !floating,
        left: safeAreaLeft,
        right: safeAreaRight,
        minimum: safeAreaMinimum,
        child: drawer,
      );
    }
    return Semantics(
      container: true,
      label: resolvedLabel.isEmpty ? null : resolvedLabel,
      child: drawer,
    );
  }

  /// Resolves the four enum values down to the binary physical axis
  /// the drawer actually renders on. Exposed on the library surface so
  /// [UiDrawerScope.show] can agree with the content widget and so
  /// tests can drive the same resolution logic.
  static bool isLeftEdge(UiDrawerSide side, TextDirection direction) =>
      _resolveIsLeft(side, direction);

  static BorderRadiusGeometry adaptiveBorderRadiusOf(
    BuildContext context, {
    required UiDrawerSide side,
    required UiDrawerVariant variant,
    bool adaptive = true,
  }) {
    return _resolveAdaptiveRadius(
      context,
      floating: variant != UiDrawerVariant.standard,
      placement: _UiDrawerPlacement.side,
      isLeft: _resolveIsLeft(side, Directionality.of(context)),
      adaptive: adaptive,
    );
  }

  /// Returns a radius that remains concentric with the drawer surface when an
  /// item is inset from its edge.
  ///
  /// Navigation rows and other nested surfaces should use this instead of a
  /// fixed token radius so floating drawers keep the same visual curvature as
  /// their outer edge.
  static BorderRadius concentricContentBorderRadiusOf(
    BuildContext context, {
    required UiDrawerSide side,
    required UiDrawerVariant variant,
    required double inset,
    bool adaptive = true,
  }) {
    final outer = adaptiveBorderRadiusOf(
      context,
      side: side,
      variant: variant,
      adaptive: adaptive,
    ).resolve(Directionality.of(context));

    Radius inner(Radius radius) => Radius.elliptical(
          (radius.x - inset).clamp(0.0, double.infinity),
          (radius.y - inset).clamp(0.0, double.infinity),
        );

    return BorderRadius.only(
      topLeft: inner(outer.topLeft),
      topRight: inner(outer.topRight),
      bottomLeft: inner(outer.bottomLeft),
      bottomRight: inner(outer.bottomRight),
    );
  }
}

/// Standard header content for a structured [UiDrawer].
///
/// Placement, padding, and truncation are owned by the component so callers
/// only provide content and an optional trailing action.
class UiDrawerHeader extends StatelessWidget {
  const UiDrawerHeader({
    super.key,
    required this.title,
    this.description,
    this.leading,
    this.action,
  });

  final String title;
  final String? description;
  final Widget? leading;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);

    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        tokens.spacing.x6,
        tokens.spacing.x5,
        tokens.spacing.x4,
        tokens.spacing.x4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            SizedBox(width: tokens.spacing.x3),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                UiText(
                  title,
                  variant: UiTextVariant.subheading,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (description != null && description!.isNotEmpty) ...[
                  SizedBox(height: tokens.spacing.x1),
                  UiText(
                    description!,
                    variant: UiTextVariant.bodySm,
                    tone: UiTextTone.muted,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (action != null) ...[SizedBox(width: tokens.spacing.x2), action!],
        ],
      ),
    );
  }
}

/// Labelled group for use inside the structured drawer body.
class UiDrawerSection extends StatelessWidget {
  const UiDrawerSection({
    super.key,
    required this.child,
    this.title,
    this.padding,
  });

  final String? title;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return Padding(
      padding: padding ??
          EdgeInsetsDirectional.fromSTEB(
            tokens.spacing.x3,
            tokens.spacing.x3,
            tokens.spacing.x3,
            tokens.spacing.x3,
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null && title!.isNotEmpty) ...[
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                tokens.spacing.x3,
                tokens.spacing.x1,
                tokens.spacing.x3,
                tokens.spacing.x1,
              ),
              child: UiText(
                title!,
                variant: UiTextVariant.caption,
                tone: UiTextTone.muted,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          child,
        ],
      ),
    );
  }
}

/// Standard padded footer content for a structured [UiDrawer].
class UiDrawerFooter extends StatelessWidget {
  const UiDrawerFooter({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return Padding(
      padding: padding ?? EdgeInsets.all(tokens.spacing.x3),
      child: child,
    );
  }
}

class _UiDrawerRegions extends StatelessWidget {
  const _UiDrawerRegions({this.header, this.body, this.footer});

  final Widget? header;
  final Widget? body;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null) header!,
        if (header != null && body != null) const UiDivider(),
        if (body != null)
          Expanded(child: SingleChildScrollView(primary: false, child: body))
        else
          const Spacer(),
        if (footer != null && (header != null || body != null))
          const UiDivider(),
        if (footer != null) footer!,
      ],
    );
  }
}

BorderRadius _resolveAdaptiveRadius(
  BuildContext context, {
  required bool floating,
  required _UiDrawerPlacement placement,
  required bool isLeft,
  required bool adaptive,
}) {
  final tokens = UiThemeTokens.of(context);
  // Floating drawers are inset by x3. Add that inset to the largest standard
  // surface radius so the visible curvature still matches the app window.
  final base = floating
      ? tokens.radius.xl.x + tokens.spacing.x3
      : placement == _UiDrawerPlacement.bottom
          ? tokens.radius.xl.x
          : 0.0;
  final inferred = adaptive ? _inferDeviceCornerRadius(context) : 0.0;
  final value = inferred > base ? inferred : base;
  final radius = Radius.circular(value);

  if (floating) return BorderRadius.all(radius);
  if (placement == _UiDrawerPlacement.bottom) {
    return BorderRadius.only(topLeft: radius, topRight: radius);
  }
  if (value == 0) return BorderRadius.zero;
  return isLeft
      ? BorderRadius.only(topLeft: radius, bottomLeft: radius)
      : BorderRadius.only(topRight: radius, bottomRight: radius);
}

double _inferDeviceCornerRadius(BuildContext context) {
  final padding = MediaQuery.maybeViewPaddingOf(context) ?? EdgeInsets.zero;
  final signal = [
    padding.bottom,
    padding.left,
    padding.right,
  ].reduce((a, b) => a > b ? a : b);
  if (signal <= 0) return 0;
  return signal.clamp(14.0, 36.0);
}

bool _hasVisibleRadius(BorderRadius radius) {
  return radius.topLeft.x > 0 ||
      radius.topRight.x > 0 ||
      radius.bottomLeft.x > 0 ||
      radius.bottomRight.x > 0;
}

bool _resolveIsLeft(UiDrawerSide side, TextDirection direction) {
  switch (side) {
    case UiDrawerSide.left:
      return true;
    case UiDrawerSide.right:
      return false;
    case UiDrawerSide.start:
      return direction == TextDirection.ltr;
    case UiDrawerSide.end:
      return direction == TextDirection.rtl;
  }
}

/// Controls an open modal drawer.
class UiDrawerController<T> {
  UiDrawerController._(this._dismiss);

  final void Function([T? result]) _dismiss;

  void dismiss([T? result]) => _dismiss(result);
}

typedef UiControlledDrawerBuilder<T> = Widget Function(
    BuildContext context, UiDrawerController<T> controller);

UiControlledDrawerBuilder<dynamic>? _eraseControlledBuilder<T>(
  UiControlledDrawerBuilder<T>? builder,
) {
  if (builder == null) return null;
  return (context, controller) {
    final typedController = UiDrawerController<T>._(([result]) {
      controller.dismiss(result);
    });
    return builder(context, typedController);
  };
}

/// Controls the nested stack inside a single modal drawer route.
class UiDrawerStackController {
  UiDrawerStackController._(this._state);

  final _DrawerRouteHostState _state;

  Future<T?> push<T>({
    required WidgetBuilder builder,
    UiControlledDrawerBuilder<T>? controlledBuilder,
    UiDrawerSide? side,
    UiDrawerVariant? variant,
  }) {
    return _state.push<T>(
      builder: builder,
      controlledBuilder: controlledBuilder,
      side: side,
      variant: variant,
    );
  }

  void pop<T>([T? result]) => _state.popTop<T>(result);

  bool get canPop => _state.canPopEntry;
}

/// Accessor for the drawer stack owned by the current modal drawer route.
class UiDrawerNavigator {
  UiDrawerNavigator._();

  static UiDrawerStackController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'No UiDrawer route is active for this context.');
    return controller!;
  }

  static UiDrawerStackController? maybeOf(BuildContext context) {
    return _UiDrawerStackScope.maybeOf(context);
  }
}

/// Imperative helpers for showing a [UiDrawer] overlay.
class UiDrawerScope {
  UiDrawerScope._();

  /// Present a modal drawer from [side]. Returns the result passed to
  /// `Navigator.maybePop`.
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    UiControlledDrawerBuilder<T>? controlledBuilder,
    UiDrawerSide side = UiDrawerSide.start,
    UiDrawerVariant variant = UiDrawerVariant.standard,
    bool barrierDismissible = true,
    bool? blurBackdrop,
    Color? barrierColor,
  }) {
    final nested = UiDrawerNavigator.maybeOf(context);
    if (nested != null) {
      return nested.push<T>(
        builder: builder,
        controlledBuilder: controlledBuilder,
        side: side,
        variant: variant,
      );
    }

    final tokens = UiThemeTokens.of(context);
    final direction = Directionality.of(context);
    final effectiveBlurBackdrop =
        blurBackdrop ?? variant != UiDrawerVariant.standard;
    final navigator = Navigator.of(context, rootNavigator: true);
    final motion = tokens.motion;
    final drawerTransitionDuration = motion.standard == Duration.zero
        ? Duration.zero
        : UiStackedMotion.drawerDuration;

    final capturedThemes = InheritedTheme.capture(
      from: context,
      to: navigator.context,
    );
    final route = navigator.push<T>(
      PageRouteBuilder<T>(
        opaque: false,
        barrierDismissible: false,
        barrierColor: const Color(0x00000000),
        transitionDuration: drawerTransitionDuration,
        reverseTransitionDuration: drawerTransitionDuration,
        pageBuilder: (ctx, animation, __) {
          return capturedThemes.wrap(
            _DrawerRouteHost(
              animation: animation,
              side: side,
              variant: variant,
              direction: direction,
              builder: builder,
              controlledBuilder: _eraseControlledBuilder(controlledBuilder),
              blurBackdrop: effectiveBlurBackdrop,
              barrierColor: barrierColor ?? tokens.colors.overlay,
              barrierDismissible: barrierDismissible,
              transitionDuration: drawerTransitionDuration,
              onDismissRoute: ([result]) {
                Navigator.of(ctx).maybePop(result);
              },
            ),
          );
        },
        transitionsBuilder: (_, __, ___, child) => child,
      ),
    );
    return route;
  }

  /// Push a nested drawer into the currently active drawer route.
  static Future<T?> push<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    UiControlledDrawerBuilder<T>? controlledBuilder,
    UiDrawerSide? side,
    UiDrawerVariant? variant,
  }) {
    return UiDrawerNavigator.of(context).push<T>(
      builder: builder,
      controlledBuilder: controlledBuilder,
      side: side,
      variant: variant,
    );
  }
}

@immutable
class _DrawerStackSnapshot {
  const _DrawerStackSnapshot({
    this.open = const <int>[],
    this.closing = const <int>{},
    this.drag,
  });

  final List<int> open;
  final Set<int> closing;
  final _DrawerStackDrag? drag;

  _DrawerStackSnapshot push(int id) {
    return _DrawerStackSnapshot(
      open: [...open, id],
      closing: closing,
      drag: null,
    );
  }

  _DrawerStackSnapshot markClosing(int id) {
    if (!open.contains(id) || closing.contains(id)) return this;
    return _DrawerStackSnapshot(
      open: open,
      closing: {...closing, id},
      drag: drag,
    );
  }

  _DrawerStackSnapshot remove(int id) {
    return _DrawerStackSnapshot(
      open: [
        for (final openId in open)
          if (openId != id) openId,
      ],
      closing: {
        for (final closingId in closing)
          if (closingId != id) closingId,
      },
      drag: drag?.id == id ? null : drag,
    );
  }

  _DrawerStackSnapshot updateDrag(int id, double progress) {
    if (!open.contains(id)) return this;
    return _DrawerStackSnapshot(
      open: open,
      closing: closing,
      drag: _DrawerStackDrag(id: id, progress: progress.clamp(0.0, 1.0)),
    );
  }

  _DrawerStackSnapshot clearDrag(int id) {
    if (drag?.id != id) return this;
    return _DrawerStackSnapshot(open: open, closing: closing);
  }

  List<int> effectiveStackFor(int id) {
    return [
      for (final openId in open)
        if (!closing.contains(openId) || openId == id) openId,
    ];
  }
}

@immutable
class _DrawerStackDrag {
  const _DrawerStackDrag({required this.id, required this.progress});

  final int id;
  final double progress;
}

class _UiDrawerStackScope extends InheritedWidget {
  const _UiDrawerStackScope({
    required this.controller,
    required super.child,
  });

  final UiDrawerStackController controller;

  static UiDrawerStackController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_UiDrawerStackScope>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(_UiDrawerStackScope oldWidget) {
    return controller != oldWidget.controller;
  }
}

class _UiDrawerPresentation extends InheritedWidget {
  const _UiDrawerPresentation({
    required this.side,
    required this.variant,
    required this.layoutMetrics,
    required this.stackDepth,
    required super.child,
  });

  final UiDrawerSide side;
  final UiDrawerVariant variant;
  final _UiDrawerLayoutMetrics layoutMetrics;
  final int stackDepth;

  static _UiDrawerPresentation? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_UiDrawerPresentation>();
  }

  @override
  bool updateShouldNotify(_UiDrawerPresentation oldWidget) {
    return side != oldWidget.side ||
        variant != oldWidget.variant ||
        layoutMetrics != oldWidget.layoutMetrics ||
        stackDepth != oldWidget.stackDepth;
  }
}

class _DrawerRouteHost extends StatefulWidget {
  const _DrawerRouteHost({
    required this.animation,
    required this.side,
    required this.variant,
    required this.direction,
    required this.builder,
    required this.controlledBuilder,
    required this.blurBackdrop,
    required this.barrierColor,
    required this.barrierDismissible,
    required this.transitionDuration,
    required this.onDismissRoute,
  });

  final Animation<double> animation;
  final UiDrawerSide side;
  final UiDrawerVariant variant;
  final TextDirection direction;
  final WidgetBuilder builder;
  final UiControlledDrawerBuilder<dynamic>? controlledBuilder;
  final bool blurBackdrop;
  final Color barrierColor;
  final bool barrierDismissible;
  final Duration transitionDuration;
  final void Function([dynamic result]) onDismissRoute;

  @override
  State<_DrawerRouteHost> createState() => _DrawerRouteHostState();
}

class _DrawerRouteHostState extends State<_DrawerRouteHost>
    with TickerProviderStateMixin {
  final ValueNotifier<_DrawerStackSnapshot> _stackListenable =
      ValueNotifier<_DrawerStackSnapshot>(const _DrawerStackSnapshot());
  final List<_DrawerStackEntry<dynamic>> _entries =
      <_DrawerStackEntry<dynamic>>[];
  late final UiDrawerStackController _stackController;
  late final AnimationController _dragController;
  int _nextEntryId = 0;
  int? _activeDragEntryId;
  bool _routeMarkedClosing = false;

  @override
  void initState() {
    super.initState();
    _stackController = UiDrawerStackController._(this);
    _dragController = AnimationController(
      vsync: this,
      value: 0,
      duration: widget.transitionDuration,
    );
    _dragController.addListener(_publishOwnedDragProgress);
    widget.animation.addStatusListener(_handleAnimationStatus);
    final rootEntry = _createEntry<dynamic>(
      builder: widget.builder,
      controlledBuilder: widget.controlledBuilder,
      side: widget.side,
      variant: widget.variant,
      direction: widget.direction,
      isRoot: true,
      animation: widget.animation,
    );
    _entries.add(rootEntry);
    _stackListenable.value = _stackListenable.value.push(rootEntry.id);
  }

  @override
  void didUpdateWidget(_DrawerRouteHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation == widget.animation) return;
    oldWidget.animation.removeStatusListener(_handleAnimationStatus);
    widget.animation.addStatusListener(_handleAnimationStatus);
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_handleAnimationStatus);
    _dragController.removeListener(_publishOwnedDragProgress);
    _clearOwnedDrag();
    _dragController.dispose();
    _stackListenable.dispose();
    for (final entry in _entries) {
      if (!entry.isRoot) entry.dispose();
    }
    super.dispose();
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.reverse && !_routeMarkedClosing) {
      _routeMarkedClosing = true;
      final ids = _entries.map((entry) => entry.id).toList();
      var snapshot = _stackListenable.value;
      for (final id in ids) {
        snapshot = snapshot.markClosing(id);
      }
      _stackListenable.value = snapshot;
    }
  }

  bool get canPopEntry => _entries.length > 1;

  Future<T?> push<T>({
    required WidgetBuilder builder,
    UiControlledDrawerBuilder<T>? controlledBuilder,
    UiDrawerSide? side,
    UiDrawerVariant? variant,
  }) {
    final controller = AnimationController(
      vsync: this,
      duration: widget.transitionDuration,
    );
    final entry = _createEntry<T>(
      builder: builder,
      controlledBuilder: controlledBuilder,
      side: side ?? widget.side,
      variant: variant ?? widget.variant,
      direction: _entries.isEmpty ? widget.direction : _entries.last.direction,
      isRoot: false,
      animation: controller,
    );
    setState(() {
      _entries.add(entry);
      _stackListenable.value = _stackListenable.value.push(entry.id);
    });
    controller.forward();
    return entry.completer.future;
  }

  void popTop<T>([T? result]) {
    if (_entries.length <= 1) {
      widget.onDismissRoute(result);
      return;
    }
    _popEntry(_entries.last.id, result);
  }

  _DrawerStackEntry<T> _createEntry<T>({
    required WidgetBuilder builder,
    required UiControlledDrawerBuilder<T>? controlledBuilder,
    required UiDrawerSide side,
    required UiDrawerVariant variant,
    required TextDirection direction,
    required bool isRoot,
    required Animation<double> animation,
  }) {
    return _DrawerStackEntry<T>(
      id: _nextEntryId++,
      builder: builder,
      controlledBuilder: _eraseControlledBuilder(controlledBuilder),
      side: side,
      variant: variant,
      direction: direction,
      isRoot: isRoot,
      animation: animation,
    );
  }

  Future<void> _popEntry<T>(int id, [T? result]) async {
    final entry = _entryFor(id);
    if (entry == null || entry.isClosing) return;
    entry.isClosing = true;
    _stackListenable.value = _stackListenable.value.markClosing(id);

    final animation = entry.animation;
    if (animation is AnimationController) {
      await animation.reverse();
    }
    if (!mounted) return;

    _removeEntry(entry, result);
  }

  void _removeEntry<T>(_DrawerStackEntry<dynamic> entry, [T? result]) {
    if (_activeDragEntryId == entry.id) {
      _activeDragEntryId = null;
      _dragController.value = 0;
    }
    setState(() {
      _entries.removeWhere((candidate) => candidate.id == entry.id);
      _stackListenable.value = _stackListenable.value.remove(entry.id);
    });
    if (!entry.completer.isCompleted) {
      entry.completer.complete(result);
    }
    if (!entry.isRoot) entry.dispose();
  }

  _DrawerStackEntry<dynamic>? _entryFor(int id) {
    for (final entry in _entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  int? get _topEntryId => _entries.isEmpty ? null : _entries.last.id;

  void _handleBackdropPressed() {
    if (_entries.length > 1) {
      popTop<dynamic>();
      return;
    }
    if (widget.barrierDismissible) {
      widget.onDismissRoute();
    }
  }

  void _handleDragStart(_DrawerStackEntry<dynamic> entry) {
    if (widget.animation.status != AnimationStatus.completed) return;
    if (_topEntryId != entry.id) return;
    _dragController.stop();
    _activeDragEntryId = entry.id;
    _publishOwnedDragProgress();
  }

  void _handleDragUpdate(
    _DrawerStackEntry<dynamic> entry,
    double primaryDelta,
  ) {
    if (widget.animation.status != AnimationStatus.completed) return;
    if (_activeDragEntryId != entry.id) return;
    if (primaryDelta == 0) return;

    final layoutMetrics = _UiDrawerLayoutMetrics.resolve(
      MediaQuery.sizeOf(context),
      300,
    );
    final isBottom = layoutMetrics.placement == _UiDrawerPlacement.bottom;
    final isLeft = _resolveIsLeft(entry.side, entry.direction);
    final closingDelta =
        isBottom ? primaryDelta : (isLeft ? -primaryDelta : primaryDelta);
    final drawerSize = entry.key.currentContext?.size;
    final drawerExtent = isBottom
        ? (drawerSize?.height ?? layoutMetrics.bottomMaxHeight)
        : (drawerSize?.width ?? MediaQuery.sizeOf(context).width);
    if (drawerExtent <= 0) return;

    _dragController.value =
        (_dragController.value + closingDelta / drawerExtent).clamp(0.0, 1.0);
  }

  void _handleDragEnd(
    _DrawerStackEntry<dynamic> entry,
    double primaryVelocity,
  ) {
    if (widget.animation.status != AnimationStatus.completed) return;
    if (_activeDragEntryId != entry.id) return;
    final layoutMetrics = _UiDrawerLayoutMetrics.resolve(
      MediaQuery.sizeOf(context),
      300,
    );
    final isBottom = layoutMetrics.placement == _UiDrawerPlacement.bottom;
    final isLeft = _resolveIsLeft(entry.side, entry.direction);
    final velocity = isBottom
        ? primaryVelocity
        : isLeft
            ? -primaryVelocity
            : primaryVelocity;
    final shouldDismiss = velocity > 700 || _dragController.value > 0.35;

    if (shouldDismiss) {
      _dragController.animateTo(1).whenComplete(() {
        if (!mounted) return;
        if (entry.isRoot) {
          widget.onDismissRoute();
        } else {
          _removeEntry(entry);
        }
      });
    } else {
      _dragController.animateBack(0).whenComplete(_clearOwnedDrag);
    }
  }

  void _handleDragCancel(_DrawerStackEntry<dynamic> entry) {
    if (widget.animation.status == AnimationStatus.completed) {
      if (_activeDragEntryId != entry.id) return;
      _dragController.animateBack(0).whenComplete(_clearOwnedDrag);
    }
  }

  void _publishOwnedDragProgress() {
    final id = _activeDragEntryId;
    if (id == null) return;
    _stackListenable.value = _stackListenable.value.updateDrag(
      id,
      _dragController.value,
    );
  }

  void _clearOwnedDrag() {
    final id = _activeDragEntryId ?? _stackListenable.value.drag?.id;
    if (id == null) {
      return;
    }
    _activeDragEntryId = null;
    _dragController.value = 0;
    _stackListenable.value = _stackListenable.value.clearDrag(id);
  }

  Widget _buildEntry(
    BuildContext context,
    _DrawerStackSnapshot snapshot,
    _DrawerStackEntry<dynamic> entry,
    Widget drawer,
  ) {
    final isLeft = _resolveIsLeft(entry.side, entry.direction);
    final layoutMetrics = _UiDrawerLayoutMetrics.resolve(
      MediaQuery.sizeOf(context),
      300,
    );
    final isBottom = layoutMetrics.placement == _UiDrawerPlacement.bottom;
    final stack = snapshot.effectiveStackFor(entry.id);
    final index = stack.indexOf(entry.id);
    final stackDepth = index < 0 ? 0 : stack.length - 1 - index;
    final drag = snapshot.drag;
    final draggedIndex = drag == null ? -1 : stack.indexOf(drag.id);
    final activeDragProgress = drag?.id == entry.id ? drag!.progress : 0.0;
    final dragControlsDepth = draggedIndex > index;
    final depthDragProgress = dragControlsDepth ? drag!.progress : 0.0;
    final motion = UiThemeTokens.of(context).motion;
    final drawerCurve = motion.standard == Duration.zero
        ? motion.standardCurve
        : UiStackedMotion.drawerCurve;
    final drawerStackDuration = motion.standard == Duration.zero
        ? Duration.zero
        : UiStackedMotion.drawerStackDuration;
    final curved = CurvedAnimation(
      parent: entry.animation,
      curve: drawerCurve,
      reverseCurve: drawerCurve.flipped,
    );

    return AnimatedBuilder(
      animation: curved,
      builder: (context, _) {
        final direction = isBottom
            ? AxisDirection.up
            : isLeft
                ? AxisDirection.right
                : AxisDirection.left;
        final visibleFraction =
            (curved.value * (1 - activeDragProgress)).clamp(0.0, 1.0);
        final depthValue = entry.variant == UiDrawerVariant.stacked
            ? (stackDepth - depthDragProgress).clamp(0.0, double.infinity)
            : 0.0;
        final depthOffsetStep = isBottom
            ? UiStackedMotion.drawerNestedOffsetStep +
                layoutMetrics.bottomMaxHeight * UiStackedMotion.scaleStep
            : UiStackedMotion.drawerNestedOffsetStep;
        return UiStackedOverlaySurface(
          depth: depthValue,
          stackDirection: direction,
          depthOffsetStep: depthOffsetStep,
          duration: dragControlsDepth ? Duration.zero : drawerStackDuration,
          curve: drawerCurve,
          scaleAlignment: isBottom
              ? Alignment.bottomCenter
              : isLeft
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
          applyOpacity: false,
          implicitScaleAnimation: false,
          child: Align(
            alignment: isBottom
                ? Alignment.bottomCenter
                : isLeft
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart:
                  isBottom ? null : (_) => _handleDragStart(entry),
              onHorizontalDragUpdate: isBottom
                  ? null
                  : (details) {
                      _handleDragUpdate(entry, details.primaryDelta ?? 0);
                    },
              onHorizontalDragEnd: isBottom
                  ? null
                  : (details) {
                      _handleDragEnd(entry, details.primaryVelocity ?? 0);
                    },
              onHorizontalDragCancel:
                  isBottom ? null : () => _handleDragCancel(entry),
              onVerticalDragStart:
                  isBottom ? (_) => _handleDragStart(entry) : null,
              onVerticalDragUpdate: isBottom
                  ? (details) {
                      _handleDragUpdate(entry, details.primaryDelta ?? 0);
                    }
                  : null,
              onVerticalDragEnd: isBottom
                  ? (details) {
                      _handleDragEnd(entry, details.primaryVelocity ?? 0);
                    }
                  : null,
              onVerticalDragCancel:
                  isBottom ? () => _handleDragCancel(entry) : null,
              child: FractionalTranslation(
                translation: Offset(
                  isBottom
                      ? 0
                      : isLeft
                          ? -(1 - visibleFraction)
                          : 1 - visibleFraction,
                  isBottom ? 1 - visibleFraction : 0,
                ),
                child: KeyedSubtree(
                  key: entry.key,
                  child: Directionality(
                    textDirection: entry.direction,
                    child: _UiDrawerPresentation(
                      side: entry.side,
                      variant: entry.variant,
                      layoutMetrics: layoutMetrics,
                      stackDepth: stackDepth,
                      child: drawer,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: widget.animation,
      curve: UiStackedMotion.drawerCurve,
      reverseCurve: UiStackedMotion.drawerCurve.flipped,
    );
    return PopScope(
      canPop: _entries.length <= 1,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _entries.length <= 1) return;
        popTop<dynamic>();
      },
      child: _UiDrawerStackScope(
        controller: _stackController,
        child: ValueListenableBuilder<_DrawerStackSnapshot>(
          valueListenable: _stackListenable,
          builder: (context, snapshot, _) {
            final drag = snapshot.drag;
            final rootDragProgress =
                drag?.id == (_entries.isEmpty ? null : _entries.first.id)
                    ? drag!.progress
                    : 0.0;
            return Stack(
              fit: StackFit.expand,
              children: [
                _DrawerBackdrop(
                  animation: curved,
                  dragProgress: rootDragProgress,
                  color: widget.barrierColor,
                  blur: widget.blurBackdrop,
                  onPressed: _handleBackdropPressed,
                ),
                for (final entry in List<_DrawerStackEntry<dynamic>>.of(
                  _entries,
                ))
                  Builder(
                    key: ValueKey<int>(entry.id),
                    builder: (entryContext) {
                      final controller = UiDrawerController<dynamic>._(([r]) {
                        if (entry.isRoot) {
                          widget.onDismissRoute(r);
                        } else {
                          _popEntry<dynamic>(entry.id, r);
                        }
                      });
                      final drawer = entry.controlledBuilder?.call(
                            entryContext,
                            controller,
                          ) ??
                          entry.builder(entryContext);
                      return _buildEntry(
                        entryContext,
                        snapshot,
                        entry,
                        drawer,
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DrawerStackEntry<T> {
  _DrawerStackEntry({
    required this.id,
    required this.builder,
    required this.controlledBuilder,
    required this.side,
    required this.variant,
    required this.direction,
    required this.isRoot,
    required this.animation,
  });

  final int id;
  final WidgetBuilder builder;
  final UiControlledDrawerBuilder<dynamic>? controlledBuilder;
  final UiDrawerSide side;
  final UiDrawerVariant variant;
  final TextDirection direction;
  final bool isRoot;
  final Animation<double> animation;
  final GlobalKey key = GlobalKey();
  final Completer<T?> completer = Completer<T?>();
  bool isClosing = false;

  void dispose() {
    final animation = this.animation;
    if (animation is AnimationController) {
      animation.dispose();
    }
  }
}

class _DrawerBackdrop extends StatelessWidget {
  const _DrawerBackdrop({
    required this.animation,
    required this.dragProgress,
    required this.color,
    required this.blur,
    required this.onPressed,
  });

  final Animation<double> animation;
  final double dragProgress;
  final Color color;
  final bool blur;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    Widget backdrop = ColoredBox(color: color);
    if (blur) {
      backdrop = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: backdrop,
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: animation,
          child: backdrop,
          builder: (context, child) {
            return Opacity(
              opacity: (animation.value * (1 - dragProgress)).clamp(
                0.0,
                1.0,
              ),
              child: child,
            );
          },
        ),
      ),
    );
  }
}
