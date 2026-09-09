import 'package:flutter/widgets.dart';

import '../../foundation/theme/ui_theme_extensions.dart';

/// Local destination state; incompatible payload types never activate a region.
enum UiDropState { idle, accepting, rejecting, disabled }

typedef UiDropRegionBuilder = Widget Function(
  BuildContext context,
  UiDropState state,
);

/// Typed destination with explicit acceptance and token-driven boundary feedback.
///
/// [onAccept] is the sole commit point. Applications should also expose a button
/// or menu command for the same operation so transfer never requires dragging.
class UiDropRegion<T extends Object> extends StatelessWidget {
  const UiDropRegion({
    super.key,
    required this.builder,
    required this.onAccept,
    required this.semanticLabel,
    this.canAccept,
    this.enabled = true,
    this.showDecoration = true,
  });

  final UiDropRegionBuilder builder;
  final ValueChanged<T> onAccept;
  final bool Function(T data)? canAccept;
  final String semanticLabel;
  final bool enabled;

  /// Disable when the destination supplies its own visual drop feedback.
  final bool showDecoration;

  bool _accepts(T data) => enabled && (canAccept?.call(data) ?? true);

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return DragTarget<T>(
      onWillAcceptWithDetails: (details) => _accepts(details.data),
      onAcceptWithDetails: (details) {
        // Revalidate: application state may have changed since pointer entry.
        if (_accepts(details.data)) onAccept(details.data);
      },
      builder: (context, candidates, rejected) {
        final state = !enabled
            ? UiDropState.disabled
            : candidates.any((data) => data != null && _accepts(data))
            ? UiDropState.accepting
            : rejected.isNotEmpty || candidates.isNotEmpty
            ? UiDropState.rejecting
            : UiDropState.idle;
        final color = switch (state) {
          UiDropState.accepting => tokens.colors.primary,
          UiDropState.rejecting => tokens.colors.destructive,
          _ => tokens.colors.border,
        };
        return Semantics(
          label: semanticLabel,
          enabled: enabled,
          child: AnimatedContainer(
            duration: tokens.motion.fast,
            curve: tokens.motion.standardCurve,
            decoration: !showDecoration
                ? null
                : BoxDecoration(
                    color:
                        state == UiDropState.accepting ||
                            state == UiDropState.rejecting
                        ? color.withValues(alpha: 0.06)
                        : tokens.colors.card,
                    border: Border.all(color: color),
                    borderRadius: tokens.radius.mdAll,
                  ),
            child: builder(context, state),
          ),
        );
      },
    );
  }
}
