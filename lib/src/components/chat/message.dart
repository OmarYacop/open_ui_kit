import 'package:flutter/widgets.dart';

import '../../foundation/theme/ui_theme_extensions.dart';
import 'bubble.dart';

/// A conversation row that owns identity, alignment, metadata, and actions.
class UiMessage extends StatelessWidget {
  const UiMessage({
    super.key,
    required this.child,
    this.alignment = UiChatAlignment.start,
    this.avatar,
    this.header,
    this.footer,
    this.semanticLabel,
  });

  final Widget child;
  final UiChatAlignment alignment;
  final Widget? avatar;
  final Widget? header;
  final Widget? footer;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final atEnd = alignment == UiChatAlignment.end;
    final content = Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: atEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (header != null) ...[header!, SizedBox(height: tokens.spacing.x1)],
          child,
          if (footer != null) ...[SizedBox(height: tokens.spacing.x1), footer!],
        ],
      ),
    );
    final avatarSlot = avatar == null
        ? null
        : Padding(
            padding: EdgeInsets.only(
              bottom: footer == null ? 0 : tokens.spacing.x4,
            ),
            child: avatar,
          );

    return Semantics(
      container: true,
      label: semanticLabel,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: atEnd
            ? [
                content,
                if (avatarSlot != null) ...[
                  SizedBox(width: tokens.spacing.x2),
                  avatarSlot,
                ],
              ]
            : [
                if (avatarSlot != null) ...[
                  avatarSlot,
                  SizedBox(width: tokens.spacing.x2),
                ],
                content,
              ],
      ),
    );
  }
}

class UiMessageGroup extends StatelessWidget {
  const UiMessageGroup({super.key, required this.children, this.spacing = 4});

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index != children.length - 1) SizedBox(height: spacing),
        ],
      ],
    );
  }
}
