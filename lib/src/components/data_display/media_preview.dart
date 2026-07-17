import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_box.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

/// Generic media surface with an image and a centered fallback.
///
/// Use this for cards, headers, and preview panels where remote media may be
/// absent or fail to load. The component owns the surface, clipping, and
/// fallback placement; callers provide domain-specific fallback content.
class UiMediaPreview extends StatelessWidget {
  const UiMediaPreview({
    super.key,
    this.imageUrl,
    this.image,
    this.fallback,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.backgroundColor,
    this.border,
    this.borderRadius,
    this.clipBehavior = Clip.antiAlias,
    this.fallbackBackgroundColor,
    this.fallbackBorderRadius,
    this.fallbackPadding,
  });

  final String? imageUrl;
  final Widget? image;
  final Widget? fallback;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color? backgroundColor;
  final BoxBorder? border;
  final BorderRadius? borderRadius;
  final Clip clipBehavior;
  final Color? fallbackBackgroundColor;
  final BorderRadius? fallbackBorderRadius;
  final EdgeInsetsGeometry? fallbackPadding;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);

    return UiBox(
      width: width,
      height: height,
      background: backgroundColor ?? tokens.colors.surfaceMuted,
      border: border,
      borderRadius: borderRadius,
      clipBehavior: clipBehavior,
      child: _content(context),
    );
  }

  Widget _content(BuildContext context) {
    if (image != null) return image!;

    final url = imageUrl ?? '';
    if (url.isNotEmpty) {
      return Image.network(
        url,
        width: _finiteOrNull(width),
        height: _finiteOrNull(height),
        fit: fit,
        errorBuilder: (_, __, ___) => _fallback(context),
      );
    }

    return _fallback(context);
  }

  Widget _fallback(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final fallbackChild = fallback ?? const SizedBox.shrink();
    final padded = UiBox(
      padding: fallbackPadding,
      background: fallbackBackgroundColor,
      borderRadius: fallbackBorderRadius ?? tokens.radius.pillAll,
      child: fallbackChild,
    );

    return Center(child: padded);
  }

  static double? _finiteOrNull(double? value) {
    if (value == null || !value.isFinite) return null;
    return value;
  }
}
