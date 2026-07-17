import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

/// Standard numeric badge used by navigation surfaces.
///
/// Bottom tabs, drawers, and rails have different geometry, but count badges
/// should use the same color, cap, and compact sizing rules.
class UiNavigationCountBadge extends StatelessWidget {
  const UiNavigationCountBadge({
    super.key,
    required this.count,
    this.compact = false,
    this.semanticsLabel,
  });

  final int count;
  final bool compact;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    final tokens = UiThemeTokens.of(context);
    final label = count > 99 ? '99+' : count.toString();
    final minWidth = compact ? 16.0 : 22.0;
    final height = compact ? 16.0 : 20.0;

    return Semantics(
      label: semanticsLabel ?? '$count new items',
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth),
        child: UiBox(
          height: height,
          borderRadius: tokens.radius.pillAll,
          background: tokens.colors.primary,
          padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 7),
          alignment: Alignment.center,
          child: UiText(
            label,
            variant: UiTextVariant.caption,
            style: TextStyle(
              color: tokens.colors.primaryForeground,
              fontSize: compact ? 10 : null,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
