import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

import '../../foundation/motion/ui_stacked_motion.dart';
import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import '../forms/button.dart' show UiIntent;

/// Stack position for toasts.
///
/// [adaptive] places toasts at the top on compact/mobile viewports and at the
/// bottom start corner on wider viewports.
enum UiToastPosition { adaptive, top, bottom }

/// Optional action button attached to a toast.
@immutable
class UiToastAction {
  const UiToastAction({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;
}

/// Sonner-like toast surface.
///
/// Defaults to a compact, high-contrast card. Intent tokens drive color
/// without leaking system look, so it reads as design-system output
/// across both light and dark.
class UiToast extends StatelessWidget {
  const UiToast({
    super.key,
    required this.message,
    this.title,
    this.intent = UiIntent.defaultIntent,
    this.leading,
    this.action,
    this.onDismiss,
  });

  final String message;
  final String? title;
  final UiIntent intent;
  final Widget? leading;
  final UiToastAction? action;

  /// Invoked when the user taps the close affordance. Rarely set by
  /// callers directly — the toaster injects its own dismiss callback.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    final isDarkTheme = c.background.computeLuminance() < 0.2;

    var (bg, fg, accent) = switch (intent) {
      UiIntent.primary => (c.primary, c.primaryForeground, c.primaryForeground),
      UiIntent.destructive => (
          c.destructive,
          c.destructiveForeground,
          c.destructiveForeground,
        ),
      UiIntent.danger => (
          c.destructive,
          c.destructiveForeground,
          c.destructiveForeground,
        ),
      UiIntent.secondary => (c.secondary, c.secondaryForeground, c.foreground),
      _ => (c.popover, c.popoverForeground, c.popoverForeground),
    };
    final borderColor = c.border.withValues(alpha: 0.92);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.hasBoundedWidth
            ? math.min(420.0, constraints.maxWidth)
            : 420.0;

        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth, minHeight: 52),
          child: UiBox(
            background: bg,
            border: Border.all(color: borderColor, width: 1),
            borderRadius: tokens.radius.lgAll,
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.x5,
              vertical: tokens.spacing.x4,
            ),
            boxShadow: tokens.shadows.lg,
            child: Row(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (leading != null) ...[
                  IconTheme.merge(
                    data: IconThemeData(color: accent, size: 18),
                    child: leading!,
                  ),
                  SizedBox(width: tokens.spacing.x3),
                ],
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null) ...[
                        UiText(
                          title!,
                          variant: UiTextVariant.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: fg),
                        ),
                        SizedBox(height: tokens.spacing.x1),
                      ],
                      UiText(
                        message,
                        variant: UiTextVariant.bodySm,
                        softWrap: true,
                        style: TextStyle(color: fg),
                      ),
                    ],
                  ),
                ),
                if (action != null) ...[
                  SizedBox(width: tokens.spacing.x3),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 128),
                    child: UiPressable(
                      onPressed: action!.onPressed,
                      minTapSize: 0,
                      builder: (context, state, _) {
                        final isDefaultDark =
                            intent == UiIntent.defaultIntent && isDarkTheme;
                        final actionBg = isDefaultDark
                            ? (state.pressed
                                ? const Color(0xFFE4E4E7)
                                : state.hovered
                                    ? const Color(0xFFEDEDF0)
                                    : const Color(0xFFF4F4F5))
                            : state.hovered || state.pressed
                                ? c.accent
                                : const Color(0x00000000);
                        final actionFg =
                            isDefaultDark ? const Color(0xFF18181B) : accent;
                        return UiBox(
                          padding: EdgeInsets.symmetric(
                            horizontal: tokens.spacing.x2,
                            vertical: tokens.spacing.x1,
                          ),
                          borderRadius: tokens.radius.smAll,
                          background: actionBg,
                          border: Border.all(
                            color: isDefaultDark
                                ? const Color(0x00000000)
                                : accent.withValues(
                                    alpha: state.hovered ? 0.7 : 0.35,
                                  ),
                          ),
                          child: UiText(
                            action!.label,
                            variant: UiTextVariant.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: actionFg,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// --- Toaster --------------------------------------------------------------

@immutable
class _ToastSpec {
  const _ToastSpec({
    required this.id,
    required this.builder,
    required this.duration,
    required this.position,
  });
  final int id;
  final WidgetBuilder builder;
  final Duration duration;
  final UiToastPosition position;
}

class _ToastController {
  static final _ToastController instance = _ToastController._();
  _ToastController._();
  static const Duration exitDuration = Duration(milliseconds: 180);

  final ValueNotifier<List<_ToastSpec>> _visible =
      ValueNotifier<List<_ToastSpec>>(const []);
  final Map<int, Timer> _timers = <int, Timer>{};
  final Set<int> _dismissing = <int>{};
  int _nextId = 0;
  int _maxVisible = 3;

  ValueListenable<List<_ToastSpec>> get visibleListenable => _visible;

  int get maxVisible => _maxVisible;
  bool isDismissing(int id) => _dismissing.contains(id);

  void setMaxVisible(int value) {
    if (value < 1) value = 1;
    if (value == _maxVisible) return;
    _maxVisible = value;
    final overflow = _visible.value.length - _maxVisible;
    if (overflow <= 0) return;
    final trimmed = _visible.value.sublist(overflow);
    for (final dropped in _visible.value.take(overflow)) {
      _dismissing.remove(dropped.id);
      _timers.remove(dropped.id)?.cancel();
    }
    _visible.value = trimmed;
  }

  VoidCallback push(_ToastSpec spec) {
    if (_visible.value.length >= _maxVisible) {
      // Keep the stack strict: when full, drop the oldest visible toast
      // and show the newest immediately (Sonner-like behavior).
      final dropped = _visible.value.first;
      _dismissing.remove(dropped.id);
      _timers.remove(dropped.id)?.cancel();
      _visible.value = [..._visible.value.skip(1), spec];
      _scheduleDismiss(spec);
    } else {
      _visible.value = [..._visible.value, spec];
      _scheduleDismiss(spec);
    }
    return () => dismiss(spec.id);
  }

  void _scheduleDismiss(_ToastSpec spec) {
    _timers[spec.id]?.cancel();
    _timers[spec.id] = Timer(spec.duration, () => dismiss(spec.id));
  }

  void dismiss(int id) {
    if (_dismissing.contains(id)) return;
    if (_visible.value.indexWhere((s) => s.id == id) == -1) return;
    _timers.remove(id)?.cancel();
    _dismissing.add(id);
    // Trigger rebuild so slots can animate exit.
    _visible.value = [..._visible.value];
    Timer(exitDuration, () {
      _dismissing.remove(id);
      final next = [..._visible.value];
      next.removeWhere((s) => s.id == id);
      _visible.value = next;
    });
  }

  void clear() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _dismissing.clear();
    _visible.value = const [];
  }

  int nextId() => _nextId++;
}

/// Sonner-like toaster.
///
/// Call [UiToaster.show] / [UiToaster.showToast] from anywhere with a
/// [BuildContext] whose subtree has an `Overlay`. The first call installs
/// a single overlay entry; subsequent toasts stack and, when the stack is
/// full, the oldest visible toast is replaced by the newest.
class UiToaster {
  UiToaster._();

  static OverlayEntry? _hostEntry;
  static int? _installedThemeSignature;

  /// Maximum number of toasts visible at once. Defaults to 3 (matches
  /// Sonner's default).
  static int get maxVisible => _ToastController.instance.maxVisible;
  static set maxVisible(int value) =>
      _ToastController.instance.setMaxVisible(value);

  /// Shows a simple titled message.
  static VoidCallback show(
    BuildContext context, {
    required String message,
    String? title,
    UiIntent intent = UiIntent.defaultIntent,
    Widget? leading,
    UiToastAction? action,
    Duration duration = const Duration(seconds: 3),
    UiToastPosition position = UiToastPosition.adaptive,
  }) {
    return showToast(
      context,
      (_) => UiToast(
        title: title,
        message: message,
        intent: intent,
        leading: leading,
        action: action,
      ),
      duration: duration,
      position: position,
    );
  }

  /// Shows an arbitrary widget as the toast surface.
  static VoidCallback showToast(
    BuildContext context,
    WidgetBuilder builder, {
    Duration duration = const Duration(seconds: 3),
    UiToastPosition position = UiToastPosition.adaptive,
  }) {
    _installHost(context);
    final id = _ToastController.instance.nextId();
    return _ToastController.instance.push(
      _ToastSpec(
        id: id,
        builder: builder,
        duration: duration,
        position: position,
      ),
    );
  }

  /// Removes every visible toast.
  static void dismissAll() => _ToastController.instance.clear();

  /// Tracks the overlay we last inserted into. Reset when that overlay is
  /// torn down (between tests or page swaps) so we re-install on the next
  /// toast request instead of trying to reuse a detached entry.
  static OverlayState? _installedInto;

  static void _installHost(BuildContext context) {
    final overlay = Overlay.of(context);
    final tokens = UiThemeTokens.of(context);
    final themeSignature = Object.hash(
      tokens.colors.background.toARGB32(),
      tokens.colors.surface.toARGB32(),
      tokens.colors.textPrimary.toARGB32(),
      tokens.colors.border.toARGB32(),
      tokens.colors.primary.toARGB32(),
    );
    if (_hostEntry != null &&
        _installedInto == overlay &&
        _installedThemeSignature == themeSignature) {
      return;
    }
    // Reinstall when overlay target or theme signature changes so toasts
    // always follow the active subtree theme (light/dark/system).
    _hostEntry?.remove();
    final capturedThemes = InheritedTheme.capture(
      from: context,
      to: overlay.context,
    );
    _hostEntry = OverlayEntry(
      builder: (_) => capturedThemes.wrap(const _ToastHost()),
    );
    overlay.insert(_hostEntry!);
    _installedInto = overlay;
    _installedThemeSignature = themeSignature;
  }
}

/// Back-compat shim for the older API.
class UiToastOverlay {
  UiToastOverlay._();

  /// Legacy entrypoint: shows a single ready-made toast widget. Forwards
  /// to [UiToaster.showToast].
  static VoidCallback show(
    BuildContext context, {
    required Widget toast,
    Duration duration = const Duration(seconds: 3),
    UiToastPosition position = UiToastPosition.adaptive,
  }) {
    return UiToaster.showToast(
      context,
      (_) => toast,
      duration: duration,
      position: position,
    );
  }
}

class _ToastHost extends StatelessWidget {
  const _ToastHost();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<_ToastSpec>>(
      valueListenable: _ToastController.instance.visibleListenable,
      builder: (context, specs, _) {
        if (specs.isEmpty) return const SizedBox.shrink();
        final mediaSize = MediaQuery.maybeSizeOf(context);
        final isCompact = mediaSize == null || mediaSize.shortestSide < 600;
        final topSpecs =
            specs.where((s) => _resolvesTop(s.position, isCompact)).toList();
        final bottomSpecs =
            specs.where((s) => s.position == UiToastPosition.bottom).toList();
        final adaptiveBottomSpecs = specs
            .where(
              (s) => s.position == UiToastPosition.adaptive && !isCompact,
            )
            .toList();
        return IgnorePointer(
          ignoring: false,
          child: Stack(
            children: [
              if (topSpecs.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: _ToastLane(
                      specs: topSpecs, position: UiToastPosition.top),
                ),
              if (bottomSpecs.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _ToastLane(
                    specs: bottomSpecs,
                    position: UiToastPosition.bottom,
                  ),
                ),
              if (adaptiveBottomSpecs.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _ToastLane(
                    specs: adaptiveBottomSpecs,
                    position: UiToastPosition.bottom,
                    alignEnd: true,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  bool _resolvesTop(UiToastPosition position, bool isCompact) {
    return switch (position) {
      UiToastPosition.top => true,
      UiToastPosition.bottom => false,
      UiToastPosition.adaptive => isCompact,
    };
  }
}

class _ToastLane extends StatelessWidget {
  const _ToastLane({
    required this.specs,
    required this.position,
    this.alignEnd = false,
  });
  final List<_ToastSpec> specs;
  final UiToastPosition position;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final mq = MediaQuery.maybeOf(context);
    final padding = mq?.padding ?? EdgeInsets.zero;
    final isBottom = position == UiToastPosition.bottom;

    // Front-most toast is the most recently pushed.
    final ordered = [...specs];
    if (!isBottom) {
      // For top position, reverse so newest is nearest the edge too.
    }

    return Padding(
      padding: EdgeInsets.only(
        left: tokens.spacing.x4,
        right: tokens.spacing.x4,
        top: isBottom ? 0 : padding.top + tokens.spacing.x4,
        bottom: isBottom ? padding.bottom + tokens.spacing.x4 : 0,
      ),
      child: Align(
        alignment: _alignment(isBottom),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: _alignment(isBottom),
          children: [
            for (var i = 0; i < ordered.length; i++)
              _ToastSlot(
                key: ValueKey<int>(ordered[i].id),
                spec: ordered[i],
                depth: ordered.length - 1 - i,
                isBottom: isBottom,
                dismissing: _ToastController.instance.isDismissing(
                  ordered[i].id,
                ),
              ),
          ],
        ),
      ),
    );
  }

  AlignmentDirectional _alignment(bool isBottom) {
    if (isBottom && alignEnd) return AlignmentDirectional.bottomEnd;
    return isBottom
        ? AlignmentDirectional.bottomCenter
        : AlignmentDirectional.topCenter;
  }
}

class _ToastSlot extends StatefulWidget {
  const _ToastSlot({
    super.key,
    required this.spec,
    required this.depth,
    required this.isBottom,
    required this.dismissing,
  });
  final _ToastSpec spec;
  final int depth;
  final bool isBottom;
  final bool dismissing;

  @override
  State<_ToastSlot> createState() => _ToastSlotState();
}

class _ToastSlotState extends State<_ToastSlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(vsync: this);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion = UiThemeTokens.of(context).motion;
    _enter.duration = motion.standard;
    if (_started) return;
    _started = true;
    if (motion.standard == Duration.zero) {
      _enter.value = 1.0;
    } else {
      _enter.forward();
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = UiThemeTokens.of(context).motion;
    return AnimatedBuilder(
      animation: _enter,
      builder: (context, child) {
        final t = motion.standardCurve.transform(_enter.value);
        return UiStackedOverlaySurface(
          depth: widget.depth.toDouble(),
          stackDirection:
              widget.isBottom ? AxisDirection.up : AxisDirection.down,
          entranceDirection:
              widget.isBottom ? AxisDirection.up : AxisDirection.down,
          entranceProgress: t,
          entranceDistance: 20,
          visible: !widget.dismissing,
          duration: motion.fast,
          curve: motion.standardCurve,
          child: child!,
        );
      },
      child: _Dismissible(
        onDismiss: () => _ToastController.instance.dismiss(widget.spec.id),
        child: Builder(builder: widget.spec.builder),
      ),
    );
  }
}

class _Dismissible extends StatelessWidget {
  const _Dismissible({required this.child, required this.onDismiss});
  final Widget child;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0).abs() > 200) onDismiss();
      },
      child: child,
    );
  }
}
