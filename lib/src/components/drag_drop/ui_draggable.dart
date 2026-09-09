import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/theme/ui_theme_extensions.dart';

/// Gesture policy for an in-app drag. Adaptive waits on touch/stylus and
/// starts immediately with a mouse, preserving touch scrolling.
enum UiDragActivation { adaptive, immediate, longPress }

/// A typed drag source for arbitrary content.
///
/// [feedbackBuilder] must build an independent, non-interactive preview; do not
/// reuse globally keyed editors or other live state from [child]. The preview
/// keeps the source's measured size and inherited theme. Applications own data
/// changes in the receiving [DragTarget], never at pickup.
class UiDraggable<T extends Object> extends StatefulWidget {
  const UiDraggable({
    super.key,
    required this.data,
    required this.child,
    required this.feedbackBuilder,
    required this.semanticLabel,
    this.enabled = true,
    this.activation = UiDragActivation.adaptive,
    this.onDragStarted,
    this.onDragEnd,
    this.childWhenDragging,
    this.decorateFeedback = true,
  });

  final T data;
  final Widget child;
  final WidgetBuilder feedbackBuilder;
  final String semanticLabel;
  final bool enabled;
  final UiDragActivation activation;
  final VoidCallback? onDragStarted;
  final ValueChanged<DraggableDetails>? onDragEnd;

  /// Optional source replacement while the item is lifted.
  final Widget? childWhenDragging;

  /// Disable for feedback that owns its own surface treatment.
  final bool decorateFeedback;

  @override
  State<UiDraggable<T>> createState() => _UiDraggableState<T>();
}

class _UiDraggableState<T extends Object> extends State<UiDraggable<T>> {
  final _sourceKey = GlobalKey();
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final child = Semantics(
      label: widget.semanticLabel,
      enabled: widget.enabled,
      child: MouseRegion(
        cursor: !widget.enabled
            ? SystemMouseCursors.basic
            : _dragging
            ? SystemMouseCursors.grabbing
            : SystemMouseCursors.grab,
        child: widget.child,
      ),
    );
    void started() {
      setState(() => _dragging = true);
      widget.onDragStarted?.call();
    }

    void ended(DraggableDetails details) {
      if (mounted) setState(() => _dragging = false);
      widget.onDragEnd?.call(details);
    }

    final feedback = Builder(
      builder: (_) {
        final box = _sourceKey.currentContext?.findRenderObject() as RenderBox?;
        return InheritedTheme.captureAll(
          context,
          SizedBox(
            width: box?.size.width,
            height: box?.size.height,
            child: UiTheme(
              tokens: tokens,
              child: widget.decorateFeedback
                  ? UiDragPreview(child: widget.feedbackBuilder(context))
                  : widget.feedbackBuilder(context),
            ),
          ),
        );
      },
    );
    final placeholder = ExcludeSemantics(
      child: widget.childWhenDragging ?? Opacity(opacity: 0.3, child: child),
    );
    final delay = switch (widget.activation) {
      UiDragActivation.immediate => Duration.zero,
      UiDragActivation.longPress => kLongPressTimeout,
      UiDragActivation.adaptive => kLongPressTimeout,
    };
    final source = widget.activation == UiDragActivation.adaptive
        ? _AdaptiveDraggable<T>(
            data: widget.data,
            feedback: feedback,
            maxSimultaneousDrags: widget.enabled ? 1 : 0,
            childWhenDragging: placeholder,
            onDragStarted: started,
            onDragEnd: ended,
            child: child,
          )
        : widget.activation == UiDragActivation.immediate
        ? Draggable<T>(
            data: widget.data,
            feedback: feedback,
            maxSimultaneousDrags: widget.enabled ? 1 : 0,
            childWhenDragging: placeholder,
            onDragStarted: started,
            onDragEnd: ended,
            child: child,
          )
        : LongPressDraggable<T>(
            data: widget.data,
            delay: delay,
            feedback: feedback,
            maxSimultaneousDrags: widget.enabled ? 1 : 0,
            childWhenDragging: placeholder,
            onDragStarted: started,
            onDragEnd: ended,
            child: child,
          );
    return DefaultTextStyle.merge(
      key: _sourceKey,
      style: TextStyle(color: tokens.colors.foreground),
      child: source,
    );
  }
}

class _AdaptiveDraggable<T extends Object> extends Draggable<T> {
  const _AdaptiveDraggable({
    required super.data,
    required super.feedback,
    required super.child,
    required super.childWhenDragging,
    required super.maxSimultaneousDrags,
    required super.onDragStarted,
    required super.onDragEnd,
  });

  @override
  MultiDragGestureRecognizer createRecognizer(
    GestureMultiDragStartCallback onStart,
  ) {
    return _AdaptiveDragRecognizer()..onStart = onStart;
  }
}

class _AdaptiveDragRecognizer extends DelayedMultiDragGestureRecognizer {
  @override
  MultiDragPointerState createNewPointerState(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.mouse) {
      final recognizer = ImmediateMultiDragGestureRecognizer();
      final state = recognizer.createNewPointerState(event);
      recognizer.dispose();
      return state;
    }
    return super.createNewPointerState(event);
  }
}

/// Shared lifted surface for custom drag feedback and sortable proxies.
class UiDragPreview extends StatelessWidget {
  const UiDragPreview({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: tokens.motion.fast,
      curve: tokens.motion.standardCurve,
      builder: (context, value, child) => DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.colors.card,
          borderRadius: tokens.radius.mdAll,
          boxShadow: BoxShadow.lerpList(
            tokens.shadows.none,
            tokens.shadows.lg,
            value,
          ),
        ),
        child: child,
      ),
      child: child,
    );
  }
}
