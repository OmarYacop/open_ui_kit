import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../components/forms/button.dart' show UiIntent, UiSize;
import '../../components/forms/icon_button.dart';
import '../../foundation/motion/motion.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import 'ui_contour_accessory_geometry.dart';

/// One item shown in [UiContourAccessoryRelease]'s persistent bar, besides
/// the search trigger.
@immutable
class UiContourBarItem {
  const UiContourBarItem({
    required this.icon,
    required this.semanticsLabel,
    required this.onPressed,
  });

  final Widget icon;
  final String semanticsLabel;
  final VoidCallback? onPressed;
}

/// Persistent chrome releasing an independent accessory surface — the
/// second Contour interaction model, distinct from [UiContourRelease]'s
/// single shared capsule.
///
/// A bottom bar and a search accessory are **two separate surfaces** with
/// no common parent container — they share only color tokens and one
/// progress timeline (see `doc/contour.md`). On activation, the bar
/// recedes by exactly the width the accessory claims (its trailing items
/// fading as they lose room) while the accessory grows from the search
/// trigger's position to fill the freed space, with a bounded backdrop
/// blur — the one place in Contour a blur is used, because here it
/// legitimately separates two independent surfaces rather than papering
/// over weak geometry (contrast with the retired glow path, see
/// `doc/contour.md`).
///
/// Both surfaces keep their own persistent identity: the bar is one call
/// site throughout, and the accessory is a second call site throughout —
/// never a crossfaded pair standing in for either.
class UiContourAccessoryRelease extends StatefulWidget {
  const UiContourAccessoryRelease({
    super.key,
    required this.items,
    this.searchIcon = const Icon(LucideIcons.search),
    this.searchSemanticsLabel = 'Search',
    this.intent = UiIntent.neutral,
    this.accessoryChild,
    this.height = 56,
    this.expanded,
    this.onExpandedChanged,
  });

  /// Bar items shown alongside the search trigger while collapsed. These
  /// fade as the bar recedes — they are not available while the accessory
  /// is active.
  final List<UiContourBarItem> items;

  final Widget searchIcon;
  final String searchSemanticsLabel;
  final UiIntent intent;

  /// Content hosted inside the expanded accessory surface (e.g. a text
  /// field). Defaults to an empty box if omitted.
  final Widget? accessoryChild;

  final double height;

  final bool? expanded;
  final ValueChanged<bool>? onExpandedChanged;

  @override
  State<UiContourAccessoryRelease> createState() =>
      _UiContourAccessoryReleaseState();
}

class _UiContourAccessoryReleaseState extends State<UiContourAccessoryRelease>
    with SingleTickerProviderStateMixin {
  late final UiContourController _controller = UiContourController(
    vsync: this,
  );
  bool _uncontrolledExpanded = false;
  bool _initialized = false;

  static const double _itemSlot = 48;
  static const double _horizontalPadding = 12;

  bool get _isExpanded => widget.expanded ?? _uncontrolledExpanded;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      if (_isExpanded) {
        _controller.open(context, duration: UiMotionDuration.instant);
      }
    }
  }

  @override
  void didUpdateWidget(covariant UiContourAccessoryRelease oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded != null && widget.expanded != oldWidget.expanded) {
      _syncTo(widget.expanded!);
    }
  }

  void _syncTo(bool expand) {
    if (expand) {
      _controller.open(context);
    } else {
      _controller.close(context);
    }
  }

  void _requestExpand(bool expand) {
    if (widget.expanded == null) {
      setState(() => _uncontrolledExpanded = expand);
    }
    widget.onExpandedChanged?.call(expand);
    _syncTo(expand);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : _itemSlot * (widget.items.length + 1);
        final barSize = Size(barWidth, widget.height);
        final sourceRect = Rect.fromLTWH(
          widget.items.length * _itemSlot,
          (widget.height - _itemSlot) / 2,
          _itemSlot,
          _itemSlot,
        );
        final accessorySize = Size(
          (barWidth - _horizontalPadding * 2).clamp(0.0, barWidth),
          widget.height - 8,
        );

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final g = UiContourAccessoryGeometrySolver.solve(
              UiContourAccessoryGeometryInput(
                barSize: barSize,
                sourceRect: sourceRect,
                accessorySize: accessorySize,
                progress: _controller.value,
              ),
            );

            return SizedBox(
              width: barWidth,
              height: widget.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fromRect(
                    // The visible clip window shrinks (g.barRect), but the
                    // bar's own content is always laid out at its full
                    // natural width via OverflowBox — never squeezed to fit
                    // a narrower box — so nothing overflows or reflows
                    // mid-transition; only what's visible changes.
                    rect: g.barRect,
                    child: ClipRect(
                      key: const ValueKey('contour-accessory-bar-window'),
                      child: OverflowBox(
                        minWidth: barSize.width,
                        maxWidth: barSize.width,
                        maxHeight: barSize.height,
                        alignment: Alignment.centerLeft,
                        child: _ContourBarSurface(
                          key: const ValueKey('contour-accessory-bar'),
                          intent: widget.intent,
                          height: widget.height,
                          items: widget.items,
                          itemSlot: _itemSlot,
                          contentVisibility: g.barContentVisibility,
                          searchIcon: widget.searchIcon,
                          searchSemanticsLabel: widget.searchSemanticsLabel,
                          searchActive: _isExpanded,
                          onSearchPressed: () => _requestExpand(true),
                        ),
                      ),
                    ),
                  ),
                  if (g.accessoryVisibility > 0)
                    Positioned.fromRect(
                      // Same clip-window-vs-natural-size split as the bar
                      // above: the accessory's content is always laid out
                      // at its full natural size and clipped to the
                      // currently-grown rect, so its close button and
                      // internal padding never get squeezed into overflow
                      // while still small.
                      rect: g.accessoryRect,
                      child: ClipRect(
                        child: OverflowBox(
                          minWidth: accessorySize.width,
                          maxWidth: accessorySize.width,
                          maxHeight: accessorySize.height,
                          alignment: Alignment.centerLeft,
                          child: ExcludeSemantics(
                            excluding: !g.accessoryInteractive,
                            child: IgnorePointer(
                              ignoring: !g.accessoryInteractive,
                              child: _ContourAccessorySurface(
                                key: const ValueKey(
                                  'contour-accessory-surface',
                                ),
                                visibility: g.accessoryVisibility,
                                onCollapse: () => _requestExpand(false),
                                child: widget.accessoryChild ??
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ContourBarSurface extends StatelessWidget {
  const _ContourBarSurface({
    super.key,
    required this.intent,
    required this.height,
    required this.items,
    required this.itemSlot,
    required this.contentVisibility,
    required this.searchIcon,
    required this.searchSemanticsLabel,
    required this.searchActive,
    required this.onSearchPressed,
  });

  final UiIntent intent;
  final double height;
  final List<UiContourBarItem> items;
  final double itemSlot;
  final double contentVisibility;
  final Widget searchIcon;
  final String searchSemanticsLabel;
  final bool searchActive;
  final VoidCallback onSearchPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.surface,
        border: Border(top: BorderSide(color: tokens.colors.border)),
      ),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            for (final item in items)
              Opacity(
                opacity: contentVisibility,
                child: ExcludeSemantics(
                  excluding: contentVisibility <= 0.01,
                  child: IgnorePointer(
                    ignoring: contentVisibility <= 0.01,
                    child: SizedBox(
                      width: itemSlot,
                      child: Center(
                        child: UiIconButton(
                          icon: item.icon,
                          semanticsLabel: item.semanticsLabel,
                          onPressed: item.onPressed,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            SizedBox(
              width: itemSlot,
              child: Center(
                child: ExcludeSemantics(
                  excluding: searchActive,
                  child: IgnorePointer(
                    ignoring: searchActive,
                    child: UiIconButton(
                      icon: searchIcon,
                      semanticsLabel: searchSemanticsLabel,
                      onPressed: onSearchPressed,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContourAccessorySurface extends StatelessWidget {
  const _ContourAccessorySurface({
    super.key,
    required this.visibility,
    required this.onCollapse,
    required this.child,
  });

  final double visibility;
  final VoidCallback onCollapse;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final effects = tokens.effects;
    // Bounded to this surface only — never a full-screen sample. Fades in
    // with the same visibility the geometry solver already produces, so
    // there is nothing here for a second, independent timeline to desync
    // from.
    final blurSigma = effects.scaleBlur(12) * visibility;

    return ClipRRect(
      borderRadius: tokens.radius.mdAll,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          if (blurSigma > 0.01)
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: const SizedBox.expand(),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.colors.surface.withValues(
                alpha: 0.72 + 0.28 * (1 - visibility.clamp(0.0, 1.0)),
              ),
              border: Border.all(color: tokens.colors.border),
              borderRadius: tokens.radius.mdAll,
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Expanded(child: Opacity(opacity: visibility, child: child)),
                UiIconButton(
                  icon: const Icon(LucideIcons.x),
                  semanticsLabel: 'Close search',
                  size: UiSize.sm,
                  onPressed: onCollapse,
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
