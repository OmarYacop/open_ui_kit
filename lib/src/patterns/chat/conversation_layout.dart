import 'package:flutter/widgets.dart';

import '../../foundation/theme/ui_theme_extensions.dart';
import '../layout/ui_scroll_edge_fade.dart';

/// A conversation viewport with floating header and composer surfaces.
///
/// Use inside a page scaffold. The history builder receives the exact reserved
/// content padding; pass it to [UiMessageScroller] or an application timeline.
/// [headerExtent] includes the top safe inset. [composerExtent] is the measured
/// dock height; [obscuredBottomInset] reserves an IME or replacement panel owned
/// by the host. This widget never applies keyboard avoidance a second time.
class UiConversationLayout extends StatelessWidget {
  const UiConversationLayout({
    super.key,
    required this.header,
    required this.composer,
    required this.historyBuilder,
    required this.headerExtent,
    required this.composerExtent,
    this.composerBottomGap = 0,
    this.obscuredBottomInset = 0,
    this.composerHorizontalPadding,
    this.fadeHistory = true,
    this.historyBottomGap,
  }) : assert(headerExtent >= 0),
       assert(composerExtent >= 0),
       assert(composerBottomGap >= 0),
       assert(obscuredBottomInset >= 0);

  final Widget header;
  final Widget composer;
  final Widget Function(BuildContext context, EdgeInsets padding)
  historyBuilder;
  final double headerExtent;
  final double composerExtent;
  final double composerBottomGap;
  final double obscuredBottomInset;
  final double? composerHorizontalPadding;
  final bool fadeHistory;
  final double? historyBottomGap;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final bottom = composerExtent + composerBottomGap + obscuredBottomInset;
    final history = historyBuilder(
      context,
      EdgeInsets.only(
        top: headerExtent + tokens.spacing.x2,
        bottom: bottom + (historyBottomGap ?? tokens.spacing.x4),
      ),
    );
    return Stack(
      children: [
        Positioned.fill(
          child: fadeHistory
              ? UiScrollEdgeFade(
                  backgroundColor: tokens.colors.background,
                  extent: headerExtent + tokens.spacing.x6,
                  bottomExtent: bottom + tokens.spacing.x4,
                  maxOpacity: .84,
                  child: history,
                )
              : history,
        ),
        PositionedDirectional(
          start: 0,
          end: 0,
          bottom: 0,
          child: Padding(
            padding: EdgeInsets.only(
              left: composerHorizontalPadding ?? tokens.spacing.x2,
              right: composerHorizontalPadding ?? tokens.spacing.x2,
              bottom: composerBottomGap,
            ),
            child: composer,
          ),
        ),
        PositionedDirectional(top: 0, start: 0, end: 0, child: header),
      ],
    );
  }
}
