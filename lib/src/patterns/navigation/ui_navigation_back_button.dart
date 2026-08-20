import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../foundation/icons/ui_directional_icons.dart';
import '../../foundation/motion/ui_motion_transitions.dart';
import '../../foundation/overlay/overlay.dart';
import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

@immutable
class UiNavigationBackHistoryItem {
  const UiNavigationBackHistoryItem({
    required this.title,
    this.subtitle,
    this.value,
  });

  final String title;
  final String? subtitle;
  final Object? value;
}

@immutable
class UiNavigationBackPopTarget {
  const UiNavigationBackPopTarget(this.count)
      : assert(count > 0, 'count must be greater than zero');

  final int count;
}

/// iOS-style back affordance: a chevron, with [label] kept for
/// accessibility and as the seeded root of the long-press history menu
/// even when it isn't painted. Set [showLabel] to restore the previous
/// chevron-plus-title look for apps that still want it.
class UiNavigationBackButton extends StatefulWidget {
  const UiNavigationBackButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.showLabel = false,
    this.history = const <UiNavigationBackHistoryItem>[],
    this.onHistorySelected,
  });

  final String label;
  final VoidCallback onPressed;

  /// Whether [label] is painted next to the chevron. Defaults to `false`
  /// (iOS-style chevron-only), leaving more room for the title and
  /// trailing actions. [label] still drives the semantics announcement and
  /// the history menu's seeded root entry either way.
  final bool showLabel;
  final List<UiNavigationBackHistoryItem> history;
  final ValueChanged<UiNavigationBackHistoryItem>? onHistorySelected;

  @override
  State<UiNavigationBackButton> createState() => _UiNavigationBackButtonState();
}

class _UiNavigationBackButtonState extends State<UiNavigationBackButton> {
  final GlobalKey _targetKey = GlobalKey();
  final Object _tapRegionGroup = Object();
  OverlayEntry? _menuEntry;
  bool _openAbove = false;
  double _menuMaxHeight = 320;
  double _menuWidth = 220;
  bool _contentFits = true;
  double _overlayLeft = 0;
  double _overlayTop = 0;

  @override
  void dispose() {
    _removeMenu();
    super.dispose();
  }

  void _toggleMenu() {
    if (_menuEntry != null) {
      _removeMenu();
      return;
    }
    final layeredOverlay = UiLayeredOverlay.maybeOf(
      context,
      UiOverlayLayer.floating,
    );
    final overlay = layeredOverlay ?? Overlay.maybeOf(context);
    if (overlay == null) return;
    if (!_resolvePlacement(overlay)) return;

    // UiLayeredOverlayHost's per-layer Overlays are siblings of the page
    // content inside its own Stack, not ancestors of it — so
    // InheritedTheme.capture (which requires `to` to be an ancestor of
    // `from`) doesn't apply, and isn't needed: both branches already share
    // every ancestor above UiLayeredOverlayHost. Only capture for the plain
    // Overlay.maybeOf fallback, where the overlay (e.g. WidgetsApp's root)
    // genuinely is an ancestor.
    if (layeredOverlay != null) {
      _menuEntry = OverlayEntry(
        builder: (overlayContext) => _buildMenuOverlay(overlayContext),
      );
    } else {
      final capturedThemes = InheritedTheme.capture(
        from: context,
        to: overlay.context,
      );
      _menuEntry = OverlayEntry(
        builder: (overlayContext) =>
            capturedThemes.wrap(_buildMenuOverlay(overlayContext)),
      );
    }
    overlay.insert(_menuEntry!);
  }

  void _removeMenu() {
    _menuEntry?.remove();
    _menuEntry = null;
  }

  /// Measures the trigger and available viewport space, mirroring the
  /// placement policy [UiDropdownMenu] and `UiSelect` share — bounded
  /// width/height, flips above the trigger when there's more room there,
  /// and scrolls once the history is too tall to fit either way.
  bool _resolvePlacement(OverlayState overlay) {
    final tokens = UiThemeTokens.of(context);
    final textScaler =
        MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    final surfaceInset = tokens.spacing.x2 / 1.5;
    final itemGap = tokens.spacing.x1;

    final estimated = widget.history.fold<double>(
          surfaceInset * 2,
          (height, item) => height + _rowHeight(tokens, textScaler, item),
        ) +
        math.max(0, widget.history.length - 1) * itemGap;
    final desiredWidth = _preferredWidth(tokens, textScaler, surfaceInset);

    final geometry = resolveUiAnchoredOverlayGeometry(
      context: context,
      targetKey: _targetKey,
      overlay: overlay,
      desiredHeight: estimated,
      maxHeight: estimated,
      desiredWidth: desiredWidth,
      minWidth: math.min(180, desiredWidth),
    );
    if (geometry == null) return false;

    _openAbove = geometry.openAbove;
    _menuMaxHeight = math.max(0, geometry.maxHeight - surfaceInset * 2);
    _menuWidth = math.max(
      0,
      math.min(desiredWidth, geometry.width) - surfaceInset * 2,
    );
    _contentFits = estimated <= geometry.maxHeight + 0.5;
    final outerHeight = math.min(estimated, geometry.maxHeight);
    _overlayLeft = geometry.targetOverlayRect.left + geometry.horizontalOffset;
    _overlayTop = geometry.openAbove
        ? geometry.targetOverlayRect.top - geometry.gap - outerHeight
        : geometry.targetOverlayRect.bottom + geometry.gap;
    return true;
  }

  double _rowHeight(
    UiThemeTokens tokens,
    TextScaler textScaler,
    UiNavigationBackHistoryItem item,
  ) {
    final bodyStyle = tokens.typography.body;
    final titleHeight =
        textScaler.scale(bodyStyle.fontSize ?? 14) * (bodyStyle.height ?? 1);
    var height = titleHeight + tokens.spacing.x3;
    if (item.subtitle != null) {
      final captionStyle = tokens.typography.caption;
      height += textScaler.scale(captionStyle.fontSize ?? 12) *
          (captionStyle.height ?? 1);
    }
    return height;
  }

  double _preferredWidth(
    UiThemeTokens tokens,
    TextScaler textScaler,
    double surfaceInset,
  ) {
    double textWidth(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      return painter.width;
    }

    final rowPadding = tokens.spacing.x2 * 2;
    final bodyStyle = tokens.typography.body;
    final captionStyle = tokens.typography.caption;
    var contentWidth = 0.0;
    for (final item in widget.history) {
      var width = rowPadding + textWidth(item.title, bodyStyle);
      if (item.subtitle != null) {
        width = math.max(
          width,
          rowPadding + textWidth(item.subtitle!, captionStyle),
        );
      }
      contentWidth = math.max(contentWidth, width);
    }
    return math.min(320, math.max(180, contentWidth + surfaceInset * 2));
  }

  Widget _buildMenuOverlay(BuildContext context) {
    final tokens = UiThemeTokens.of(this.context);
    final c = tokens.colors;
    final surfaceInset = tokens.spacing.x2 / 1.5;
    final direction = Directionality.of(this.context);
    final origin = (_openAbove
            ? AlignmentDirectional.bottomStart
            : AlignmentDirectional.topStart)
        .resolve(direction);

    return Stack(
      children: [
        Positioned(
          left: _overlayLeft,
          top: _overlayTop,
          child: UiAnchoredOverlayTapRegion(
            groupId: _tapRegionGroup,
            onDismiss: _removeMenu,
            child: _HistoryMenuEntrance(
              origin: origin,
              child: UiBox(
                background: c.popover,
                border: Border.all(color: c.border),
                borderRadius: tokens.radius.lgAll,
                boxShadow: tokens.shadows.md,
                padding: EdgeInsets.all(surfaceInset),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: _menuWidth,
                    maxWidth: _menuWidth,
                    maxHeight: _menuMaxHeight,
                  ),
                  child: Builder(
                    builder: (context) {
                      final rows = <Widget>[];
                      for (final item in widget.history) {
                        if (rows.isNotEmpty) {
                          rows.add(SizedBox(height: tokens.spacing.x1));
                        }
                        rows.add(
                          _HistoryRow(
                            item: item,
                            onTap: () {
                              _removeMenu();
                              final onHistorySelected =
                                  widget.onHistorySelected;
                              if (onHistorySelected != null) {
                                onHistorySelected(item);
                              } else {
                                widget.onPressed();
                              }
                            },
                          ),
                        );
                      }
                      final content = Column(
                        key: const Key('ui_navigation_back_history_content'),
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: rows,
                      );
                      return _contentFits
                          ? content
                          : SingleChildScrollView(child: content);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;

    return KeyedSubtree(
      key: _targetKey,
      child: UiPressable(
        onPressed: widget.onPressed,
        onLongPress: widget.history.isEmpty ? null : _toggleMenu,
        semanticsLabel: widget.label,
        minTapSize: 0,
        builder: (context, state, _) {
          final foreground = state.pressed
              ? c.textPrimary.withValues(alpha: 0.55)
              : state.hovered || state.focused
                  ? c.textPrimary.withValues(alpha: 0.78)
                  : c.textPrimary;

          return TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: foreground),
            duration: tokens.motion.fast,
            curve: tokens.motion.standardCurve,
            builder: (context, color, _) {
              final resolvedColor = color ?? foreground;
              return UiBox(
                background: const Color(0x00000000),
                borderRadius: tokens.radius.smAll,
                padding: EdgeInsets.zero,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      UiDirectionalIcons.chevronBack(context),
                      size: widget.showLabel ? 17 : 20,
                      color: resolvedColor,
                    ),
                    if (widget.showLabel) ...[
                      SizedBox(width: tokens.spacing.x1 / 2),
                      Flexible(
                        child: UiText(
                          widget.label,
                          variant: UiTextVariant.body,
                          style: TextStyle(color: resolvedColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item, required this.onTap});

  final UiNavigationBackHistoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;

    return Semantics(
      button: true,
      label: item.title,
      excludeSemantics: true,
      child: UiPressable(
        onPressed: onTap,
        minTapSize: 0,
        excludeFromSemantics: true,
        builder: (context, state, _) {
          final hover = state.hovered || state.pressed || state.focused;
          return UiBox(
            background: hover ? c.accent : const Color(0x00000000),
            borderRadius: tokens.radius.smAll,
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.x2,
              vertical: tokens.spacing.x3 / 2,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UiText(
                  item.title,
                  variant: UiTextVariant.body,
                  style: TextStyle(color: c.popoverForeground),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.subtitle != null)
                  UiText(
                    item.subtitle!,
                    variant: UiTextVariant.caption,
                    tone: UiTextTone.muted,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Fade + scale entrance for the history flyout, anchored so the surface
/// grows toward the trigger regardless of which side it opens on. Mirrors
/// the same treatment `UiDropdownMenu` and `UiSelect` use, so every
/// floating menu in the kit shares one motion language. There is
/// deliberately no matching exit animation — those menus remove their
/// overlay entry immediately on close too.
class _HistoryMenuEntrance extends StatefulWidget {
  const _HistoryMenuEntrance({
    required this.child,
    this.origin = Alignment.topLeft,
  });

  final Widget child;
  final Alignment origin;

  @override
  State<_HistoryMenuEntrance> createState() => _HistoryMenuEntranceState();
}

class _HistoryMenuEntranceState extends State<_HistoryMenuEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion = UiThemeTokens.motionOf(context);
    _controller.duration = motion.fast;
    if (_started) return;
    _started = true;
    if (motion.fast == Duration.zero) {
      _controller.value = 1.0;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = UiThemeTokens.motionOf(context);
    final curved = CurvedAnimation(
      parent: _controller,
      curve: motion.standardCurve,
    );
    return UiFadeScaleTransition(
      animation: curved,
      beginScale: 0.96,
      alignment: widget.origin,
      repaintBoundary: true,
      child: widget.child,
    );
  }
}
