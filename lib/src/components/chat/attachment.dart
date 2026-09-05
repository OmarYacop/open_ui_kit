import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

enum UiAttachmentState { idle, uploading, processing, error, done }

enum UiAttachmentSize { sm, md, lg }

enum UiAttachmentOrientation { horizontal, vertical }

/// A media attachment with metadata and deterministic transfer state.
///
/// The media renderer and actions stay caller-owned, so this component works
/// for files, images, audio, and links without pulling in platform packages.
class UiAttachment extends StatelessWidget {
  const UiAttachment({
    super.key,
    required this.title,
    this.description,
    this.media,
    this.actions = const [],
    this.state = UiAttachmentState.idle,
    this.progress,
    this.size = UiAttachmentSize.md,
    this.orientation = UiAttachmentOrientation.horizontal,
    this.onPressed,
    this.onLongPress,
    this.semanticLabel,
  }) : assert(progress == null || (progress >= 0 && progress <= 1));

  final String title;
  final String? description;
  final Widget? media;
  final List<Widget> actions;
  final UiAttachmentState state;
  final double? progress;
  final UiAttachmentSize size;
  final UiAttachmentOrientation orientation;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final error = state == UiAttachmentState.error;
    final active =
        state == UiAttachmentState.uploading ||
        state == UiAttachmentState.processing;
    final mediaExtent = switch (size) {
      UiAttachmentSize.sm => 40.0,
      UiAttachmentSize.md => 52.0,
      UiAttachmentSize.lg => 72.0,
    };
    final metadata = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UiText(
          title,
          variant: UiTextVariant.body,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (description != null) ...[
          SizedBox(height: tokens.spacing.x1),
          UiText(
            description!,
            variant: UiTextVariant.caption,
            tone: error ? UiTextTone.danger : UiTextTone.muted,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (active) ...[
          SizedBox(height: tokens.spacing.x2),
          _AttachmentProgress(
            value: progress,
            color: tokens.colors.primary,
            trackColor: tokens.colors.border,
          ),
        ],
      ],
    );
    final mediaSlot = media == null
        ? null
        : ClipRRect(
            borderRadius: tokens.radius.smAll,
            child: SizedBox.square(dimension: mediaExtent, child: media),
          );
    final actionRow = actions.isEmpty
        ? null
        : Row(mainAxisSize: MainAxisSize.min, children: actions);

    final body = orientation == UiAttachmentOrientation.horizontal
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (mediaSlot != null) ...[
                mediaSlot,
                SizedBox(width: tokens.spacing.x3),
              ],
              Expanded(child: metadata),
              if (actionRow != null) ...[
                SizedBox(width: tokens.spacing.x2),
                actionRow,
              ],
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (mediaSlot != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: mediaSlot,
                ),
              if (mediaSlot != null) SizedBox(height: tokens.spacing.x3),
              metadata,
              if (actionRow != null) ...[
                SizedBox(height: tokens.spacing.x2),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: actionRow,
                ),
              ],
            ],
          );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticLabel ?? _semanticDescription,
      button: onPressed != null,
      enabled: onPressed != null || onLongPress != null ? true : null,
      onTap: onPressed,
      onLongPress: onLongPress,
      child: UiPressable(
        enabled: onPressed != null || onLongPress != null,
        onPressed: onPressed,
        onLongPress: onLongPress,
        excludeFromSemantics: true,
        minTapSize: 0,
        builder: (_, interaction, __) => AnimatedOpacity(
          duration: tokens.motion.fast,
          opacity: interaction.pressed ? .78 : 1,
          child: UiBox(
            background: tokens.colors.surface,
            border: Border.all(
              color: error ? tokens.colors.danger : tokens.colors.border,
            ),
            borderRadius: tokens.radius.mdAll,
            padding: EdgeInsets.all(tokens.spacing.x3),
            child: body,
          ),
        ),
      ),
    );
  }

  String get _semanticDescription {
    final status = switch (state) {
      UiAttachmentState.idle => null,
      UiAttachmentState.uploading => 'uploading',
      UiAttachmentState.processing => 'processing',
      UiAttachmentState.error => 'upload failed',
      UiAttachmentState.done => 'uploaded',
    };
    return [title, description, status].whereType<String>().join(', ');
  }
}

class _AttachmentProgress extends StatelessWidget {
  const _AttachmentProgress({
    required this.value,
    required this.color,
    required this.trackColor,
  });

  final double? value;
  final Color color;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      value: value == null ? null : '${(value! * 100).round()}%',
      child: UiBox(
        height: 3,
        background: trackColor,
        borderRadius: BorderRadius.circular(99),
        clipBehavior: Clip.antiAlias,
        child: value == null
            ? Align(
                alignment: AlignmentDirectional.centerStart,
                child: FractionallySizedBox(
                  widthFactor: .35,
                  child: UiBox(background: color),
                ),
              )
            : Align(
                alignment: AlignmentDirectional.centerStart,
                child: FractionallySizedBox(
                  widthFactor: value,
                  child: UiBox(background: color),
                ),
              ),
      ),
    );
  }
}

/// Horizontally browsable attachment collection with compact spacing.
class UiAttachmentGroup extends StatelessWidget {
  const UiAttachmentGroup({
    super.key,
    required this.children,
    this.spacing = 8,
    this.itemWidth = 280,
    this.padding = EdgeInsets.zero,
    this.controller,
    this.semanticLabel,
  }) : assert(itemWidth > 0);

  final List<Widget> children;
  final double spacing;
  final double itemWidth;
  final EdgeInsetsGeometry padding;
  final ScrollController? controller;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticLabel,
      child: SingleChildScrollView(
        controller: controller,
        scrollDirection: Axis.horizontal,
        padding: padding,
        child: Row(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              SizedBox(width: itemWidth, child: children[index]),
              if (index != children.length - 1) SizedBox(width: spacing),
            ],
          ],
        ),
      ),
    );
  }
}
