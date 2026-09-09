import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import '../../foundation/motion/ui_fluid_motion.dart';
import '../../foundation/primitives/ui_action_surface_owner.dart';
import '../../foundation/primitives/ui_pressable_long_press_scope.dart';
import '../../foundation/overlay/overlay.dart';
import '../../foundation/intl/intl.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import '../surfaces/ui_fluid_surface.dart';
import '../../foundation/primitives/ui_box.dart';
import '../forms/button.dart';
import '../forms/icon_button.dart';
import 'ui_dropdown_menu.dart';
import 'ui_menu_stack.dart';

class _MenuSourceSnapshot {
  const _MenuSourceSnapshot(
    this.surface,
    this.rect,
    this.corners,
    this.border,
    this.fixedContent,
  );
  final UiBox surface;
  final Rect rect;
  final BorderRadius corners;
  final BorderSide border;
  final bool fixedContent;
}

class _ShowHistoryIntent extends Intent {
  const _ShowHistoryIntent();
}

/// Shared anchored menu implementation with retained press/drag ownership.
/// Row scrolling dismisses it; internal scrolling stays within the menu.
class UiMenuAnchor extends StatefulWidget {
  const UiMenuAnchor({
    super.key,
    this.title,
    this.trigger,
    this.triggerBuilder,
    this.sourceBorderRadius,
    this.destinationOffset = Offset.zero,
    this.transitionDurationScale = 1,
    required this.items,
    this.minWidth = 180,
    this.maxWidth = 280,
    this.backLabel,
    this.openOnLongPress = true,
    this.closeOnSelect = true,
    this.dismissOnTapOutside = true,
    this.consumeOutsideTap = true,
    this.scrollBehavior = UiMenuScrollBehavior.dismiss,
    this.onTriggerPressed,
  });

  final Offset destinationOffset;
  final double transitionDurationScale;
  final String? title;
  final String? backLabel;
  final Widget? trigger;
  final BorderRadiusGeometry? sourceBorderRadius;
  final Widget Function(BuildContext context, VoidCallback activate)?
  triggerBuilder;
  final List<UiMenuNode> items;
  final double minWidth, maxWidth;
  final bool openOnLongPress,
      closeOnSelect,
      dismissOnTapOutside,
      consumeOutsideTap;
  final UiMenuScrollBehavior scrollBehavior;

  /// Optional primary tap action; holding still opens the menu.
  final VoidCallback? onTriggerPressed;

  @override
  State<UiMenuAnchor> createState() => _UiMenuAnchorState();
}

class _UiMenuAnchorState extends State<UiMenuAnchor>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _anchor = GlobalKey();
  final _focus = FocusNode();
  final _gestures = UiMenuGestureController();
  final _scrolls = <ScrollPosition>{};
  late final _motion = UiFluidController(
    vsync: this,
    durationScale: widget.transitionDurationScale,
  )..addListener(_tick);
  OverlayEntry? _entry;
  Rect? _viewport, _source, _menuBounds;
  Size? _triggerSize;
  Offset? _anchorOrigin;
  _MenuSourceSnapshot? _restingSource;
  bool _openAbove = false;
  MediaQueryData? _openingMetrics;
  OverlayState? _overlay;
  bool _held = false, _focusedMenu = false, _menuOwnsFocus = false;
  Offset? _heldPosition;
  bool _cleanupScheduled = false;
  bool _overlayRebuildScheduled = false;

  void _scheduleOverlayRebuild() {
    if (_entry == null || _overlayRebuildScheduled) return;
    _overlayRebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overlayRebuildScheduled = false;
      if (mounted) _entry?.markNeedsBuild();
    });
  }

  @override
  void initState() {
    super.initState();
    _focus.skipTraversal = widget.triggerBuilder != null;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleOverlayRebuild();
  }

  @override
  void didUpdateWidget(UiMenuAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _focus.skipTraversal = widget.triggerBuilder != null;
    if (widget.destinationOffset != oldWidget.destinationOffset &&
        _entry != null) {
      final entry = _entry;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _entry != entry) return;
        _remove();
        _motion.value = 0;
      });
    } else {
      _scheduleOverlayRebuild();
    }
  }

  @override
  void didChangeMetrics() {
    if (_entry == null) return;
    final now = MediaQueryData.fromView(View.of(context));
    final before = _openingMetrics;
    if (before == null) {
      _remove();
      _motion.value = 0;
      return;
    }
    if (now.size == before.size &&
        now.devicePixelRatio == before.devicePixelRatio &&
        now.viewInsets == before.viewInsets &&
        now.viewPadding == before.viewPadding) {
      return;
    }
    final onlyInsetsChanged =
        now.size == before.size &&
        now.devicePixelRatio == before.devicePixelRatio &&
        now.viewPadding == before.viewPadding;
    // A keyboard that retreats while a menu is open (for example an
    // attachment menu opened from a focused composer) only moves the anchor:
    // follow it instead of tearing the menu down mid-animation.
    if (onlyInsetsChanged &&
        now.viewInsets.bottom <= before.viewInsets.bottom) {
      _openingMetrics = now;
      WidgetsBinding.instance.addPostFrameCallback((_) => _followAnchor());
      return;
    }
    _remove();
    _motion.value = 0;
  }

  /// Focus normally lands inside the menu so arrow keys work immediately.
  /// While a soft keyboard is up (a menu opened from a focused composer),
  /// moving focus off the text field would dismiss it, so focus stays put.
  bool get _softKeyboardVisible =>
      (_openingMetrics?.viewInsets.bottom ?? 0) > 0;

  void _tick() {
    if (_entry != null &&
        _motion.target == 1 &&
        _motion.value > .5 &&
        !_focusedMenu) {
      _focusedMenu = true;
      if (!_softKeyboardVisible) {
        _menuOwnsFocus = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _entry != null) _gestures.focus();
        });
      }
    }
    if (_entry == null ||
        _motion.value != 0 ||
        _motion.target != 0 ||
        _cleanupScheduled) {
      return;
    }
    _cleanupScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cleanupScheduled = false;
      if (mounted && _motion.value == 0 && _motion.target == 0) _remove();
    });
  }

  void _remove({bool notify = true}) {
    final ownsFocus = _menuOwnsFocus;
    _menuOwnsFocus = false;
    _restingSource = null;
    _held = false;
    _focusedMenu = false;
    _heldPosition = null;
    if (notify) _gestures.cancel();
    for (final position in _scrolls) {
      position.removeListener(_scrolled);
    }
    _scrolls.clear();
    final entry = _entry;
    _entry = null;
    entry?.remove();
    entry?.dispose();
    if (notify && mounted && entry != null) {
      setState(() {});
      // Only reclaim focus that the menu took; a composer field that kept
      // focus (soft keyboard up) keeps it.
      if (ownsFocus) _focus.requestFocus();
    }
  }

  void _scrolled() {
    if (widget.scrollBehavior == UiMenuScrollBehavior.dismiss) {
      _remove();
      _motion.value = 0;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _followAnchor());
    }
  }

  void _followAnchor() {
    if (mounted && _entry != null && _overlay != null) {
      final anchor = _anchor.currentContext?.findRenderObject();
      final box = _overlay!.context.findRenderObject();
      if (anchor is! RenderBox || box is! RenderBox) return;
      final rect = MatrixUtils.transformRect(
        anchor.getTransformTo(box),
        Offset.zero & anchor.size,
      );
      _viewport = _viewport!.shift(rect.topLeft - _anchorOrigin!);
      _anchorOrigin = rect.topLeft;
      _entry!.markNeedsBuild();
    }
  }

  double _preferredWidth() {
    final tokens = UiThemeTokens.of(context);
    double measure(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: tokens.typography.bodySm),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    var width = 0.0;
    void visit(List<UiMenuNode> nodes) {
      for (final node in nodes) {
        if (node is UiMenuGroup) {
          visit(node.items);
          continue;
        }
        final label = switch (node) {
          UiMenuItem() => node.label,
          UiMenuSubmenu() => node.label,
          _ => '',
        };
        final leading = switch (node) {
          UiMenuItem() => node.leading,
          UiMenuSubmenu() => node.leading,
          _ => null,
        };
        width = math.max(
          width,
          measure(label) +
              tokens.spacing.x1 * 2 +
              tokens.menu.rowPaddingHorizontal * 2 +
              (leading == null ? 0 : tokens.menu.iconSize + tokens.spacing.x2) +
              (node is UiMenuSubmenu ? tokens.menu.iconSize : 0) +
              (node is UiMenuItem && node.shortcut != null
                  ? measure(node.shortcut!.label) + tokens.spacing.x3
                  : 0),
        );
      }
    }

    visit(widget.items);
    return width.clamp(
      widget.minWidth,
      math.max(widget.minWidth, widget.maxWidth),
    );
  }

  void _close() {
    if (_entry != null && _motion.target != 0) _motion.close(context);
  }

  // Inspect only the known kit button surface, not arbitrary decorations in
  // custom triggers. UiBox exposes the resolved paint values used by the button.
  Element? _buttonSurface() {
    Element? result;
    void visit(Element element, bool inButton) {
      if (result != null) return;
      final isButton =
          inButton ||
          element.widget is UiButton ||
          element.widget is UiIconButton;
      if (isButton && element.widget is UiBox) {
        result = element;
        return;
      }
      element.visitChildren((child) => visit(child, isButton));
    }

    final root = _anchor.currentContext;
    if (widget.triggerBuilder != null && root is Element) visit(root, false);
    return result;
  }

  _MenuSourceSnapshot? _captureSource() {
    final element = _buttonSurface();
    final rendered = element?.findRenderObject();
    if (element == null || rendered is! RenderBox || !rendered.hasSize) {
      return null;
    }
    final overlay =
        UiLayeredOverlay.maybeOf(context, UiOverlayLayer.modal) ??
        Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject()! as RenderBox;
    final rect = MatrixUtils.transformRect(
      rendered.getTransformTo(overlayBox),
      Offset.zero & rendered.size,
    );
    final surface = element.widget as UiBox;
    // Resolve oversized pill tokens to the corners actually painted BEFORE
    // applying the press transform. Interpolating 999px toward 16px leaves
    // the outline clamped for most of the transition, then snaps at the end.
    final resolved =
        (widget.sourceBorderRadius ??
                surface.borderRadius ??
                UiThemeTokens.of(context).radius.pillAll)
            .resolve(Directionality.of(context))
            .toRRect(Offset.zero & rendered.size)
            .scaleRadii();
    final radius = BorderRadius.only(
      topLeft: Radius.elliptical(resolved.tlRadiusX, resolved.tlRadiusY),
      topRight: Radius.elliptical(resolved.trRadiusX, resolved.trRadiusY),
      bottomLeft: Radius.elliptical(resolved.blRadiusX, resolved.blRadiusY),
      bottomRight: Radius.elliptical(resolved.brRadiusX, resolved.brRadiusY),
    );
    final sx = rect.width / rendered.size.width;
    final sy = rect.height / rendered.size.height;
    Radius scaled(Radius r) => Radius.elliptical(r.x * sx, r.y * sy);
    return _MenuSourceSnapshot(
      surface,
      rect,
      BorderRadius.only(
        topLeft: scaled(radius.topLeft),
        topRight: scaled(radius.topRight),
        bottomLeft: scaled(radius.bottomLeft),
        bottomRight: scaled(radius.bottomRight),
      ),
      (surface.border?.top ?? BorderSide.none).scale((sx + sy) / 2),
      element.findAncestorWidgetOfExactType<UiIconButton>() != null,
    );
  }

  void _show() {
    if (_entry != null || widget.items.isEmpty) return;
    final overlay =
        UiLayeredOverlay.maybeOf(context, UiOverlayLayer.modal) ??
        Overlay.of(context);
    _overlay = overlay;
    final anchor = _anchor.currentContext!.findRenderObject()! as RenderBox;
    final box = overlay.context.findRenderObject()! as RenderBox;
    _triggerSize = anchor.size;
    _anchorOrigin = MatrixUtils.transformRect(
      anchor.getTransformTo(box),
      Offset.zero & anchor.size,
    ).topLeft;
    final initialSource = _captureSource();
    final restingSource = _restingSource ?? initialSource;
    final surface = restingSource?.surface;
    final rect =
        restingSource?.rect ??
        MatrixUtils.transformRect(
          anchor.getTransformTo(box),
          Offset.zero & anchor.size,
        );
    final media = MediaQuery.of(context);
    _openingMetrics = MediaQueryData.fromView(View.of(context));
    final safe = Rect.fromLTRB(
      media.padding.left,
      media.padding.top,
      box.size.width - media.padding.right,
      box.size.height - math.max(media.padding.bottom, media.viewInsets.bottom),
    );
    final tokens = UiThemeTokens.of(context);
    final inset = tokens.spacing.x3;
    final offset = widget.destinationOffset;
    assert(
      offset.dx.isFinite && offset.dy.isFinite,
      'destinationOffset must be finite.',
    );
    final destinationAnchor = rect.shift(offset);
    final gap = -rect.height;
    final width = math.min(_preferredWidth() + inset * 2, safe.width);
    // The stack insets its surface inside the viewport. Share the trigger
    // edge; the modal paint layer keeps the menu above navigation titles.
    final belowTop = (destinationAnchor.bottom + gap - inset).clamp(
      safe.top,
      safe.bottom,
    );
    final aboveBottom = (destinationAnchor.top - gap + inset).clamp(
      safe.top,
      safe.bottom,
    );
    final below = safe.bottom - belowTop;
    final above = aboveBottom - safe.top;
    final openBelow = below >= math.min(tokens.menu.maxHeight, above);
    var height = math.min(tokens.menu.maxHeight, openBelow ? below : above);
    final scaler = MediaQuery.textScalerOf(context);
    final minimumHeight =
        math.max(
          tokens.menu.rowMinHeight,
          scaler.scale(tokens.typography.bodySm.fontSize!) *
                  (tokens.typography.bodySm.height ?? 1) +
              tokens.menu.rowPaddingVertical * 2,
        ) +
        tokens.spacing.x1 * 2 +
        inset * 2;
    final useSafeBounds = height < math.min(minimumHeight, safe.height);
    _openAbove = !useSafeBounds && !openBelow;
    if (useSafeBounds) height = math.min(tokens.menu.maxHeight, safe.height);
    final direction = Directionality.of(context);
    final rrect =
        (restingSource?.corners ??
                widget.sourceBorderRadius ??
                surface?.borderRadius ??
                tokens.radius.pillAll)
            .resolve(direction)
            .toRRect(Offset.zero & rect.size)
            .scaleRadii();
    final sourceCorners = BorderRadius.only(
      topLeft: Radius.elliptical(rrect.tlRadiusX, rrect.tlRadiusY),
      topRight: Radius.elliptical(rrect.trRadiusX, rrect.trRadiusY),
      bottomLeft: Radius.elliptical(rrect.blRadiusX, rrect.blRadiusY),
      bottomRight: Radius.elliptical(rrect.brRadiusX, rrect.brRadiusY),
    );
    final left =
        (direction == TextDirection.ltr
                ? destinationAnchor.right - width + inset
                : destinationAnchor.left - inset)
            .clamp(safe.left, safe.right - width);
    final top = useSafeBounds
        ? (destinationAnchor.top - inset).clamp(safe.top, safe.bottom - height)
        : openBelow
        ? belowTop
        : aboveBottom - height;
    final menuViewport = Rect.fromLTWH(left, top, width, height);
    // Retain the trigger inside the animation viewport, even though the
    // expanded menu lives below it (or above it near the bottom edge).
    _viewport = menuViewport.expandToInclude(rect);
    _menuBounds = menuViewport.shift(-_viewport!.topLeft);
    _source = rect.shift(-_viewport!.topLeft);
    final themes = InheritedTheme.capture(from: context, to: null);
    _entry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          if (widget.consumeOutsideTap && widget.dismissOnTapOutside)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close,
              ),
            ),
          Positioned.fromRect(
            rect: _viewport!,
            child: themes.wrap(
              Directionality(
                textDirection: direction,
                child: UiTheme(
                  tokens: UiThemeTokens.of(context),
                  child: UiMenuStack(
                    title: widget.title ?? UiLocalizations.of(context).menu,
                    backLabel:
                        widget.backLabel ?? UiLocalizations.of(context).back,
                    closeOnSelect: widget.closeOnSelect,
                    dismissOnTapOutside: widget.dismissOnTapOutside,
                    items: widget.onTriggerPressed == null
                        ? widget.items
                        : [
                            for (final item in widget.items)
                              if (item is UiMenuItem)
                                UiMenuItem(
                                  label: item.label,
                                  subtitle: item.subtitle,
                                  leading: item.leading,
                                  shortcut: item.shortcut,
                                  enabled: item.enabled,
                                  loading: item.loading,
                                  destructive: item.destructive,
                                  onPressed: () {
                                    // Release the popup's PopScope before a history
                                    // action changes the route stack.
                                    _remove();
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (mounted) item.onPressed?.call();
                                        });
                                  },
                                )
                              else
                                item,
                          ],
                    rootInitialSourceGeometry: initialSource == null
                        ? null
                        : UiFluidGeometry(
                            initialSource.rect.shift(-_viewport!.topLeft),
                            initialSource.corners.topLeft.x,
                            corners: initialSource.corners,
                          ),
                    rootInitialSourceColor: initialSource?.surface.background,
                    rootInitialSourceBorder: initialSource?.border,
                    rootSourceColor: surface?.background,
                    rootSourceBorder: restingSource?.border,
                    rootSourceFit: restingSource?.fixedContent == true
                        ? BoxFit.none
                        : BoxFit.contain,
                    rootSourceShadows: surface?.boxShadow,
                    rootController: _motion,
                    rootMenuBounds: _menuBounds,
                    rootAlignBottom: _openAbove,
                    gestureController: _gestures,
                    handleSystemBack: false,
                    rootSourceGeometry: UiFluidGeometry(
                      _source!,
                      sourceCorners.topLeft.x,
                      corners: sourceCorners,
                    ),
                    rootTrigger: UiFluidTrigger(
                      directOpen: true,
                      controller: _motion,
                      label: widget.title ?? UiLocalizations.of(context).menu,
                      child: ExcludeSemantics(
                        child: surface == null
                            ? _trigger(paintSurface: false)
                            : UiBox(
                                padding: surface.padding,
                                alignment: surface.alignment,
                                child: surface.child,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    context.visitAncestorElements((element) {
      if (element case StatefulElement(state: final ScrollableState state)) {
        if (_scrolls.add(state.position)) state.position.addListener(_scrolled);
      }
      return true;
    });
    overlay.insert(_entry!);
    setState(() {});
  }

  void _hold(LongPressStartDetails details) {
    _show();
    _held = true;
    _motion.open(context, direct: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_held || _entry == null) return;
      _gestures.begin();
      if (_heldPosition != null) _gestures.update(_heldPosition!);
    });
  }

  void _activate() {
    if (widget.onTriggerPressed != null) {
      widget.onTriggerPressed!();
      return;
    }
    _show();
    _motion.open(context, direct: true);
  }

  void _openMenu() {
    _show();
    _motion.open(context, direct: true);
  }

  void _moveHold(LongPressMoveUpdateDetails details) {
    if (!_held) return;
    _heldPosition = details.globalPosition;
    _gestures.update(details.globalPosition);
  }

  void _endHold(LongPressEndDetails details) {
    if (!_held) return;
    _gestures.end(details);
    _held = false;
    _heldPosition = null;
  }

  void _cancelHold() {
    _held = false;
    _gestures.cancel();
  }

  bool get _canHold => widget.openOnLongPress && widget.items.isNotEmpty;

  Widget _trigger({required bool paintSurface}) {
    final tokens = UiThemeTokens.of(context);
    final trigger =
        widget.triggerBuilder?.call(context, _activate) ?? widget.trigger!;
    if (paintSurface && widget.triggerBuilder != null) {
      // A real button owns its complete surface and hit target. Supply held
      // gestures to that button's recognizer instead of wrapping a second one.
      return UiPressableLongPressScope(
        onStart: _canHold ? _hold : null,
        onMoveUpdate: _canHold ? _moveHold : null,
        onEnd: _canHold ? _endHold : null,
        onCancel: _canHold ? _cancelHold : null,
        onSemanticLongPress: _canHold ? _openMenu : null,
        child: trigger,
      );
    }
    final child = UiActionSurfaceOwner(child: IgnorePointer(child: trigger));
    if (!paintSurface) return child;
    return DecoratedBox(
      decoration: tokens.radius.decoration(
        color: tokens.colors.surface.withValues(
          alpha: tokens.menu.surfaceOpacity,
        ),
        borderRadius: widget.sourceBorderRadius ?? tokens.radius.pillAll,
        border: Border.all(
          color:
              tokens.menu.borderColor ??
              tokens.colors.textPrimary.withValues(
                alpha: tokens.menu.borderOpacity,
              ),
          width: tokens.menu.borderWidth,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _entry == null,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _gestures.back();
    },
    // The button recognizes the hold. Retain its pointer route while the
    // source hands its paint to the morph in the overlay.
    child: Listener(
      onPointerDown: (_) {
        if (_entry == null) _restingSource = _captureSource();
      },
      onPointerMove: (event) {
        if (widget.triggerBuilder == null || !_held) return;
        _heldPosition = event.position;
        _gestures.update(event.position);
      },
      onPointerUp: (event) {
        if (widget.triggerBuilder == null || !_held) return;
        _endHold(LongPressEndDetails(globalPosition: event.position));
      },
      onPointerCancel: (_) {
        if (widget.triggerBuilder != null && _held) _cancelHold();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        excludeFromSemantics: true,
        onTapDown: widget.triggerBuilder != null
            ? null
            : (_) {
                if (widget.onTriggerPressed != null) return;
                _show();
                _motion.press(context);
              },
        onTapUp: widget.triggerBuilder != null
            ? null
            : (_) => widget.onTriggerPressed != null
                  ? widget.onTriggerPressed!()
                  : _motion.open(context, direct: true),
        onTapCancel: widget.triggerBuilder != null
            ? null
            : () {
                if (!_held) _motion.cancelPress(context);
              },
        onLongPressStart: widget.triggerBuilder == null && _canHold
            ? _hold
            : null,
        onLongPressMoveUpdate: widget.triggerBuilder == null && _canHold
            ? _moveHold
            : null,
        onLongPressEnd: widget.triggerBuilder == null && _canHold
            ? _endHold
            : null,
        onLongPressCancel: widget.triggerBuilder == null && _canHold
            ? _cancelHold
            : null,
        child: MergeSemantics(
          child: Semantics(
            container: true,
            enabled: widget.triggerBuilder == null || _entry != null
                ? true
                : null,
            button: widget.triggerBuilder == null || _entry != null
                ? true
                : null,
            label: widget.triggerBuilder == null || _entry != null
                ? widget.title
                : null,
            onTap: widget.triggerBuilder == null || _entry != null
                ? _activate
                : null,
            onLongPress: widget.triggerBuilder == null && _canHold
                ? _openMenu
                : null,
            child: FocusableActionDetector(
              focusNode: _focus,

              shortcuts: const {
                SingleActivator(LogicalKeyboardKey.f10, shift: true):
                    _ShowHistoryIntent(),
                SingleActivator(LogicalKeyboardKey.arrowDown, alt: true):
                    _ShowHistoryIntent(),
              },
              actions: {
                _ShowHistoryIntent: CallbackAction<_ShowHistoryIntent>(
                  onInvoke: (_) {
                    _openMenu();
                    return null;
                  },
                ),
                if (widget.triggerBuilder == null || _entry != null)
                  ActivateIntent: CallbackAction<ActivateIntent>(
                    onInvoke: (_) {
                      _activate();
                      return null;
                    },
                  ),
              },
              child: KeyedSubtree(
                key: _anchor,
                child: _entry == null
                    ? ExcludeSemantics(
                        excluding:
                            widget.triggerBuilder == null &&
                            widget.title != null,
                        child: _trigger(paintSurface: true),
                      )
                    : SizedBox.fromSize(size: _triggerSize),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _remove(notify: false);
    _motion.dispose();
    _focus.dispose();
    super.dispose();
  }
}
