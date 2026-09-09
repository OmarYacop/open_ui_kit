import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import '../navigation/ui_compact_navigation_metrics.dart';
import '../navigation/ui_navigator_history.dart';

/// Compact centered conversation title, with leading navigation and trailing
/// avatar/actions. Grows with text scaling; callers provide localized labels
/// and accessible action widgets.
class UiChatHeader extends StatelessWidget {
  const UiChatHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.controlExtent = 44,
  }) : assert(controlExtent >= 44);
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  /// Equal square slots for back and avatar/group controls.
  /// Defaults to the large navigation back button's 44 logical pixel surface.
  /// Provide a larger extent when using custom controls.
  final double controlExtent;

  @override
  Widget build(BuildContext context) {
    // This header is a page's chrome in place of UiSliverNavigationBar, so
    // it publishes the same history-menu title later pages' back buttons
    // list. Inline panes and hidden tabs are filtered out by the scope.
    UiNavigatorHistoryScope.registerPageTitle(context, title);
    final tokens = UiThemeTokens.of(context);
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height:
            uiCompactNavigationRowHeight(
              context,
              controlExtent: controlExtent,
              hasSubtitle: subtitle != null,
            ) +
            tokens.spacing.x2,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.x3,
            0,
            tokens.spacing.x3,
            tokens.spacing.x2,
          ),
          child: NavigationToolbar(
            centerMiddle: true,
            middleSpacing: tokens.spacing.x2,
            leading: leading == null
                ? null
                : Center(
                    widthFactor: 1,
                    child: SizedBox.square(
                      dimension: controlExtent,
                      child: leading,
                    ),
                  ),
            trailing: trailing == null
                ? null
                : SizedBox.square(
                    dimension: controlExtent,
                    child: FittedBox(child: trailing),
                  ),
            middle: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                UiText(
                  title,
                  variant: UiTextVariant.subheading,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  UiText(
                    subtitle!,
                    variant: UiTextVariant.caption,
                    tone: UiTextTone.muted,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
