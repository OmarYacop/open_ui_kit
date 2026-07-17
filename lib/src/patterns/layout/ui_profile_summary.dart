import 'package:flutter/widgets.dart';

import '../../components/data_display/avatar.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

/// Centered profile summary pattern: avatar, primary name, optional subtitle,
/// and optional action row.
///
/// Use this for account headers, profile drawers, and person detail summaries.
/// Pass [avatar] for a fully custom image widget, or [imageUrl] for a network
/// image with the kit's token-driven fallback.
class UiProfileSummary extends StatelessWidget {
  const UiProfileSummary({
    super.key,
    required this.name,
    this.subtitle,
    this.imageUrl,
    this.avatar,
    this.fallback,
    this.actions = const <Widget>[],
    this.avatarSize = 120,
    this.nameMaxLines = 2,
  });

  final String name;
  final String? subtitle;
  final String? imageUrl;
  final Widget? avatar;
  final Widget? fallback;
  final List<Widget> actions;
  final double avatarSize;
  final int nameMaxLines;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        UiAvatar(
          name: name,
          imageUrl: imageUrl,
          image: avatar,
          fallback: fallback,
          size: avatarSize,
        ),
        SizedBox(height: tokens.spacing.x3),
        UiText(
          name,
          variant: UiTextVariant.subheading,
          textAlign: TextAlign.center,
          maxLines: nameMaxLines,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null) ...[
          SizedBox(height: tokens.spacing.x1),
          UiText(
            subtitle!,
            variant: UiTextVariant.bodySm,
            tone: UiTextTone.muted,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (actions.isNotEmpty) ...[
          SizedBox(height: tokens.spacing.x4),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: tokens.spacing.x2,
            runSpacing: tokens.spacing.x2,
            children: actions,
          ),
        ],
      ],
    );
  }
}
