import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show ValueListenable, immutable;
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
    final c = tokens.colors;
    final inherited = _UiDrawerPresentation.maybeOf(context);
    final effectiveSide =
        side == UiDrawerSide.start ? (inherited?.side ?? side) : side;
    final effectiveVariant = variant == UiDrawerVariant.standard
        ? (inherited?.variant ?? variant)
        : variant;
    final resolvedLeft = _resolveIsLeft(
      effectiveSide,
      Directionality.of(context),
    );
    final strings = UiLocalizations.of(context);
    final resolvedLabel = semanticsLabel ?? strings.drawer;
    final floating = effectiveVariant != UiDrawerVariant.standard;
    final direction = Directionality.of(context);
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
            : Border(
                right: resolvedLeft
                    ? BorderSide(color: c.border)
                    : BorderSide.none,
                left: resolvedLeft
                    ? BorderSide.none
                    : BorderSide(color: c.border),
              );
    final content = child ??
        _UiDrawerRegions(
          header: header,
          body: body,
          footer: footer,
        );
    Widget drawer = Padding(
      padding: floating ? resolvedMargin : EdgeInsets.zero,
      child: SizedBox(
        width: width,
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
            child: content,
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
      isLeft: _resolveIsLeft(side, Directionality.of(context)),
      adaptive: adaptive,
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
        tokens.spacing.x4,
        tokens.spacing.x4,
        tokens.spacing.x3,
        tokens.spacing.x3,
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
          if (action != null) ...[
            SizedBox(width: tokens.spacing.x2),
            action!,
          ],
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
            tokens.spacing.x2,
            tokens.spacing.x2,
            tokens.spacing.x2,
            tokens.spacing.x2,
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null && title!.isNotEmpty) ...[
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                tokens.spacing.x2,
                tokens.spacing.x1,
                tokens.spacing.x2,
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
      padding: padding ?? EdgeInsets.all(tokens.spacing.x2),
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
          Expanded(
            child: SingleChildScrollView(
              primary: false,
              child: body,
            ),
          )
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
  required bool isLeft,
  required bool adaptive,
}) {
  final tokens = UiThemeTokens.of(context);
  final base = floating ? tokens.radius.lg.x : 0.0;
  final inferred = adaptive ? _inferDeviceCornerRadius(context) : 0.0;
  final value = inferred > 0 ? inferred : base;
  final radius = Radius.circular(value);

  if (floating) return BorderRadius.all(radius);
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
  return signal.clamp(14.0, 28.0);
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
  BuildContext context,
  UiDrawerController<T> controller,
);

/// Imperative helpers for showing a [UiDrawer] overlay.
class UiDrawerScope {
  UiDrawerScope._();

  static final ValueNotifier<_DrawerStackSnapshot> _stack =
      ValueNotifier<_DrawerStackSnapshot>(const _DrawerStackSnapshot());
  static int _nextStackId = 0;

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
    final tokens = UiThemeTokens.of(context);
    final direction = Directionality.of(context);
    final isLeft = _resolveIsLeft(side, direction);
    final effectiveBlurBackdrop =
        blurBackdrop ?? variant != UiDrawerVariant.standard;
    final navigator = Navigator.of(context, rootNavigator: true);
    const drawerTransitionDuration = UiStackedMotion.drawerDuration;
    final stackId = _nextStackId++;
    _stack.value = _stack.value.push(stackId);
    var markedClosing = false;
    void markClosing() {
      if (markedClosing) return;
      markedClosing = true;
      _stack.value = _stack.value.markClosing(stackId);
    }

    void removeFromStack() {
      _stack.value = _stack.value.remove(stackId);
    }

    final capturedThemes = InheritedTheme.capture(
      from: context,
      to: navigator.context,
    );
    final route = navigator.push<T>(
      PageRouteBuilder<T>(
        opaque: false,
        barrierDismissible: barrierDismissible,
        barrierColor: const Color(0x00000000),
        transitionDuration: drawerTransitionDuration,
        reverseTransitionDuration: drawerTransitionDuration,
        pageBuilder: (ctx, animation, __) {
          final controller = UiDrawerController<T>._(([r]) {
            Navigator.of(ctx).maybePop(r);
          });
          final drawer =
              controlledBuilder?.call(ctx, controller) ?? builder(ctx);
          return capturedThemes.wrap(
            _DrawerRouteHost(
              animation: animation,
              isLeft: isLeft,
              side: side,
              variant: variant,
              stackId: stackId,
              stackListenable: _stack,
              blurBackdrop: effectiveBlurBackdrop,
              barrierColor: barrierColor ?? tokens.colors.overlay,
              transitionDuration: drawerTransitionDuration,
              onReverseStarted: markClosing,
              child: drawer,
            ),
          );
        },
        transitionsBuilder: (_, __, ___, child) => child,
      ),
    );
    route.whenComplete(removeFromStack);
    return route;
  }
}

@immutable
class _DrawerStackSnapshot {
  const _DrawerStackSnapshot({
    this.open = const <int>[],
    this.closing = const <int>{},
  });

  final List<int> open;
  final Set<int> closing;

  _DrawerStackSnapshot push(int id) {
    return _DrawerStackSnapshot(
      open: [...open, id],
      closing: closing,
    );
  }

  _DrawerStackSnapshot markClosing(int id) {
    if (!open.contains(id) || closing.contains(id)) return this;
    return _DrawerStackSnapshot(
      open: open,
      closing: {...closing, id},
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
    );
  }

  List<int> effectiveStackFor(int id) {
    return [
      for (final openId in open)
        if (!closing.contains(openId) || openId == id) openId,
    ];
  }
}

class _UiDrawerPresentation extends InheritedWidget {
  const _UiDrawerPresentation({
    required this.side,
    required this.variant,
    required this.stackDepth,
    required super.child,
  });

  final UiDrawerSide side;
  final UiDrawerVariant variant;
  final int stackDepth;

  static _UiDrawerPresentation? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_UiDrawerPresentation>();
  }

  @override
  bool updateShouldNotify(_UiDrawerPresentation oldWidget) {
    return side != oldWidget.side ||
        variant != oldWidget.variant ||
        stackDepth != oldWidget.stackDepth;
  }
}

class _DrawerRouteHost extends StatefulWidget {
  const _DrawerRouteHost({
    required this.animation,
    required this.isLeft,
    required this.side,
    required this.variant,
    required this.stackId,
    required this.stackListenable,
    required this.blurBackdrop,
    required this.barrierColor,
    required this.transitionDuration,
    required this.onReverseStarted,
    required this.child,
  });

  final Animation<double> animation;
  final bool isLeft;
  final UiDrawerSide side;
  final UiDrawerVariant variant;
  final int stackId;
  final ValueListenable<_DrawerStackSnapshot> stackListenable;
  final bool blurBackdrop;
  final Color barrierColor;
  final Duration transitionDuration;
  final VoidCallback onReverseStarted;
  final Widget child;

  @override
  State<_DrawerRouteHost> createState() => _DrawerRouteHostState();
}

class _DrawerRouteHostState extends State<_DrawerRouteHost> {
  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_handleAnimationStatus);
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
    super.dispose();
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.reverse) {
      widget.onReverseStarted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: widget.animation,
      curve: UiStackedMotion.drawerCurve,
      reverseCurve: UiStackedMotion.drawerCurve.flipped,
    );
    return ValueListenableBuilder<_DrawerStackSnapshot>(
      valueListenable: widget.stackListenable,
      child: widget.child,
      builder: (context, snapshot, drawer) {
        final stack = snapshot.effectiveStackFor(widget.stackId);
        final index = stack.indexOf(widget.stackId);
        final stackDepth = index < 0 ? 0 : stack.length - 1 - index;
        final isClosing = widget.animation.status == AnimationStatus.reverse ||
            snapshot.closing.contains(widget.stackId) ||
            widget.animation.status == AnimationStatus.dismissed;
        final isBaseLayer = (snapshot.open.isNotEmpty &&
                snapshot.open.first == widget.stackId) ||
            (snapshot.open.isEmpty && isClosing);
        return Stack(
          fit: StackFit.expand,
          children: [
            if (isBaseLayer)
              _DrawerBackdrop(
                animation: curved,
                color: widget.barrierColor,
                blur: widget.blurBackdrop,
              ),
            AnimatedBuilder(
              animation: curved,
              builder: (context, _) {
                final direction =
                    widget.isLeft ? AxisDirection.right : AxisDirection.left;
                final depthValue = widget.variant == UiDrawerVariant.stacked
                    ? stackDepth.toDouble()
                    : 0.0;
                return UiStackedOverlaySurface(
                  depth: depthValue,
                  stackDirection: direction,
                  depthOffsetStep: UiStackedMotion.drawerNestedOffsetStep,
                  duration: UiStackedMotion.drawerStackDuration,
                  curve: UiStackedMotion.drawerCurve,
                  scaleAlignment: widget.isLeft
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  applyOpacity: false,
                  implicitScaleAnimation: false,
                  child: Align(
                    alignment: widget.isLeft
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: FractionalTranslation(
                      translation: Offset(
                        widget.isLeft ? -(1 - curved.value) : 1 - curved.value,
                        0,
                      ),
                      child: _UiDrawerPresentation(
                        side: widget.side,
                        variant: widget.variant,
                        stackDepth: stackDepth,
                        child: drawer!,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _DrawerBackdrop extends StatelessWidget {
  const _DrawerBackdrop({
    required this.animation,
    required this.color,
    required this.blur,
  });

  final Animation<double> animation;
  final Color color;
  final bool blur;

  @override
  Widget build(BuildContext context) {
    Widget backdrop = ColoredBox(color: color);
    if (blur) {
      backdrop = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: backdrop,
      );
    }
    return IgnorePointer(
      child: RepaintBoundary(
        child: FadeTransition(
          opacity: animation,
          child: backdrop,
        ),
      ),
    );
  }
}
