import 'package:flutter/material.dart';

import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_brand.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import 'ui_page_scaffold.dart';
import 'ui_safe_viewport.dart';

/// Generic app shell: optional top/bottom bars around a body.
class UiAppShell extends StatelessWidget {
  const UiAppShell({
    super.key,
    required this.body,
    this.topBar,
    this.bottomBar,
    this.safeArea = false,
    this.backgroundColor,
  });

  final Widget body;
  final Widget? topBar;
  final Widget? bottomBar;
  final bool safeArea;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return UiPageScaffold(
      body: body,
      topBar: topBar,
      bottomBar: bottomBar,
      backgroundColor: backgroundColor,
      safeViewportMode:
          safeArea ? UiSafeViewportMode.all : UiSafeViewportMode.none,
    );
  }
}

/// Simple top bar with title, leading and trailing slots.
class UiAppBar extends StatelessWidget {
  const UiAppBar({
    super.key,
    this.title,
    this.brand,
    this.leading,
    this.trailing,
  });

  final String? title;
  final UiBrand? brand;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final brightness = Theme.of(context).brightness;
    final logo = brand?.resolveLogo(brightness);
    return UiBox(
      background: tokens.colors.surface,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.x4,
        vertical: tokens.spacing.x3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            SizedBox(width: tokens.spacing.x2),
          ],
          Expanded(
            child: Row(
              children: [
                if (logo != null) ...[
                  Flexible(
                    child: Semantics(
                      container: true,
                      label: '${brand!.displayName} logo',
                      child: ExcludeSemantics(
                        child: logo,
                      ),
                    ),
                  ),
                  if (title != null) SizedBox(width: tokens.spacing.x2),
                ],
                if (title != null)
                  Expanded(
                    child: UiText(
                      title!,
                      variant: UiTextVariant.subheading,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
          ),
          if (trailing != null) ...[
            SizedBox(width: tokens.spacing.x2),
            trailing!,
          ],
        ],
      ),
    );
  }
}
