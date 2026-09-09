import 'package:flutter/widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../components/forms/icon_button.dart';
import '../../foundation/primitives/ui_focus_ring.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

/// A caller-owned unsent attachment. Media rendering and inspection stay with
/// the application; omit [mediaBuilder] for a compact file/recording row.
class UiChatDraftAttachment {
  const UiChatDraftAttachment({
    required this.id,
    required this.name,
    required this.removeLabel,
    required this.previewLabel,
    required this.onRemove,
    required this.onPreview,
    this.description,
    this.icon = LucideIcons.fileText,
    this.mediaBuilder,
  });

  final Object id;
  final String name, removeLabel, previewLabel;
  final String? description;
  final IconData icon;
  final VoidCallback onRemove, onPreview;

  /// Honor the supplied fit. A single image receives loose, bounded constraints
  /// so its natural aspect ratio is retained; a batch receives square bounds.
  final Widget Function(BuildContext context, BoxFit fit)? mediaBuilder;
}

/// Inline attachment staging, intended for [UiChatComposer]'s attachmentShelf.
/// A single media preview keeps its natural ratio, batches scroll horizontally,
/// and document rows scroll vertically. The conversation retains visible space.
class UiChatAttachmentTray extends StatelessWidget {
  const UiChatAttachmentTray({
    super.key,
    required this.attachments,
    this.enabled = true,
    this.onAdd,
    this.addLabel = 'Add attachment',
    this.maxHeight = 160,
  }) : assert(maxHeight >= 48);

  final List<UiChatDraftAttachment> attachments;
  final bool enabled;
  final VoidCallback? onAdd;
  final String addLabel;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    final tokens = UiThemeTokens.of(context);
    final media = attachments
        .where((item) => item.mediaBuilder != null)
        .toList();
    final files = attachments
        .where((item) => item.mediaBuilder == null)
        .toList();
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        primary: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (media.isNotEmpty)
              SingleChildScrollView(
                primary: false,
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final item in media) ...[
                      _media(context, item, attachments.length == 1),
                      SizedBox(width: tokens.spacing.x2),
                    ],
                    if (onAdd != null && attachments.length > 1)
                      SizedBox.square(
                        dimension: 88,
                        child: UiIconButton(
                          semanticsLabel: addLabel,
                          icon: const Icon(LucideIcons.plus),
                          onPressed: enabled ? onAdd : null,
                          borderRadius: tokens.radius.mdAll,
                        ),
                      ),
                  ],
                ),
              ),
            for (final item in files)
              Row(
                key: ValueKey(item.id),
                children: [
                  Expanded(
                    child: _preview(
                      context,
                      item,
                      Padding(
                        padding: EdgeInsets.all(tokens.spacing.x2),
                        child: Row(
                          children: [
                            Icon(item.icon, color: tokens.colors.textMuted),
                            SizedBox(width: tokens.spacing.x2),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  UiText(
                                    item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (item.description != null)
                                    UiText(
                                      item.description!,
                                      variant: UiTextVariant.caption,
                                      tone: UiTextTone.muted,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _remove(context, item),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _media(BuildContext context, UiChatDraftAttachment item, bool single) {
    final tokens = UiThemeTokens.of(context);
    return Stack(
      key: ValueKey(item.id),
      children: [
        _preview(
          context,
          item,
          ClipRRect(
            borderRadius: tokens.radius.mdAll,
            child: single
                ? ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: 88,
                      minHeight: 48,
                      maxWidth: 240,
                      maxHeight: maxHeight,
                    ),
                    child: item.mediaBuilder!(context, BoxFit.contain),
                  )
                : SizedBox.square(
                    dimension: 88,
                    child: item.mediaBuilder!(context, BoxFit.cover),
                  ),
          ),
        ),
        PositionedDirectional(top: 0, end: 0, child: _remove(context, item)),
      ],
    );
  }

  Widget _preview(
    BuildContext context,
    UiChatDraftAttachment item,
    Widget child,
  ) {
    final tokens = UiThemeTokens.of(context);
    return UiPressable(
      semanticsLabel: item.previewLabel,
      enabled: enabled,
      onPressed: enabled ? item.onPreview : null,
      minTapSize: 48,
      builder: (_, state, child) => UiFocusRing(
        visible: state.focused,
        borderRadius: tokens.radius.mdAll,
        child: Opacity(
          opacity: enabled ? (state.pressed ? .8 : 1) : .5,
          child: child,
        ),
      ),
      child: child,
    );
  }

  Widget _remove(BuildContext context, UiChatDraftAttachment item) {
    final tokens = UiThemeTokens.of(context);
    return SizedBox.square(
      dimension: 48,
      child: UiIconButton(
        semanticsLabel: item.removeLabel,
        icon: const Icon(LucideIcons.x, size: 16),
        onPressed: enabled ? item.onRemove : null,
        backgroundColor: tokens.colors.surface,
        foregroundColor: tokens.colors.textPrimary,
        borderColor: tokens.colors.border,
        borderRadius: tokens.radius.pillAll,
        surfaceMargin: EdgeInsets.all(tokens.spacing.x2),
      ),
    );
  }
}
