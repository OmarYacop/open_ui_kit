import 'package:flutter/material.dart';

import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

enum UiAvatarShape { circle, rounded, square }

@immutable
class UiAvatarEntry {
  const UiAvatarEntry({
    this.name,
    this.imageUrl,
    this.image,
    this.fallback,
    this.semanticLabel,
  });

  final String? name;
  final String? imageUrl;
  final Widget? image;
  final Widget? fallback;
  final String? semanticLabel;
}

/// Token-driven avatar primitive.
///
/// Use [image] for a fully controlled avatar widget, [imageUrl] for a network
/// image, or [name]/[fallback] for deterministic fallback content.
class UiAvatar extends StatelessWidget {
  const UiAvatar({
    super.key,
    this.name,
    this.imageUrl,
    this.image,
    this.fallback,
    this.size = 40,
    this.shape = UiAvatarShape.circle,
    this.showBorder = true,
    this.semanticLabel,
  });

  final String? name;
  final String? imageUrl;
  final Widget? image;
  final Widget? fallback;
  final double size;
  final UiAvatarShape shape;
  final bool showBorder;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);

    Widget content = UiBox(
      width: size,
      height: size,
      background: tokens.colors.surfaceMuted,
      border: showBorder ? Border.all(color: tokens.colors.border) : null,
      borderRadius: _borderRadius(tokens),
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      child: _content(context),
    );

    final label = semanticLabel ?? name;
    if (label != null && label.trim().isNotEmpty) {
      content = Semantics(
        image: true,
        label: label,
        child: content,
      );
    }

    return content;
  }

  BorderRadius _borderRadius(UiThemeTokens tokens) {
    switch (shape) {
      case UiAvatarShape.circle:
        return tokens.radius.pillAll;
      case UiAvatarShape.rounded:
        return tokens.radius.mdAll;
      case UiAvatarShape.square:
        return BorderRadius.zero;
    }
  }

  Widget _content(BuildContext context) {
    if (image != null) return image!;

    final url = imageUrl ?? '';
    if (url.isNotEmpty) {
      return Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(context),
      );
    }

    return _fallback(context);
  }

  Widget _fallback(BuildContext context) {
    if (fallback != null) return fallback!;

    final initials = _initials(name);
    if (initials.isNotEmpty) {
      return UiText(
        initials,
        variant: _textVariant,
        tone: UiTextTone.muted,
        textAlign: TextAlign.center,
      );
    }

    return Icon(
      Icons.account_circle_rounded,
      size: size * 0.7,
      color: UiThemeTokens.of(context).colors.textMuted,
    );
  }

  UiTextVariant get _textVariant {
    if (size < 32) return UiTextVariant.caption;
    if (size < 56) return UiTextVariant.label;
    return UiTextVariant.subheading;
  }

  String _initials(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '';

    final parts = text
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';

    final first = parts.first.characters.first.toUpperCase();
    if (parts.length == 1) return first;
    final second = parts.last.characters.first.toUpperCase();
    return '$first$second';
  }
}

/// Stacked avatar group primitive.
///
/// Use for participant piles, assignee groups, or collaborative presence. It
/// renders up to [maxVisible] avatars and optionally adds a `+N` overflow
/// avatar for remaining entries.
class UiAvatarGroup extends StatelessWidget {
  const UiAvatarGroup({
    super.key,
    required this.items,
    this.maxVisible = 3,
    this.size = 34,
    this.overlap = 16,
    this.shape = UiAvatarShape.circle,
    this.showOverflow = true,
    this.showBorder = true,
    this.overflowSemanticLabel,
  });

  final List<UiAvatarEntry> items;
  final int maxVisible;
  final double size;
  final double overlap;
  final UiAvatarShape shape;
  final bool showOverflow;
  final bool showBorder;
  final String? overflowSemanticLabel;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty || maxVisible <= 0) return const SizedBox.shrink();

    final visibleCount = items.length < maxVisible ? items.length : maxVisible;
    final overflowCount = items.length - visibleCount;
    final hasOverflow = showOverflow && overflowCount > 0;
    final renderedCount = visibleCount + (hasOverflow ? 1 : 0);
    final width = size + (renderedCount - 1) * overlap;

    return SizedBox(
      width: width,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < visibleCount; i += 1)
            Positioned.directional(
              textDirection: Directionality.of(context),
              start: i * overlap,
              child: _groupAvatar(items[i]),
            ),
          if (hasOverflow)
            Positioned.directional(
              textDirection: Directionality.of(context),
              start: visibleCount * overlap,
              child: UiAvatar(
                size: size,
                shape: shape,
                showBorder: showBorder,
                semanticLabel:
                    overflowSemanticLabel ?? '$overflowCount more people',
                fallback: UiText(
                  '+$overflowCount',
                  variant:
                      size < 32 ? UiTextVariant.caption : UiTextVariant.label,
                  tone: UiTextTone.muted,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _groupAvatar(UiAvatarEntry entry) {
    return UiAvatar(
      name: entry.name,
      imageUrl: entry.imageUrl,
      image: entry.image,
      fallback: entry.fallback,
      size: size,
      shape: shape,
      showBorder: showBorder,
      semanticLabel: entry.semanticLabel,
    );
  }
}
