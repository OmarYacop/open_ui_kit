import 'package:flutter/widgets.dart';

/// Low-level surface primitive.
///
/// Prefer this over ad-hoc [Container] usage inside Open UI Kit components: it
/// keeps the token surface focused (bg/border/radius/padding) and renders
/// through a single [DecoratedBox] + [Padding].
class UiBox extends StatelessWidget {
  const UiBox({
    super.key,
    this.background,
    this.border,
    this.borderRadius,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.alignment,
    this.boxShadow,
    this.clipBehavior = Clip.none,
    this.child,
  });

  final Color? background;
  final BoxBorder? border;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;
  final List<BoxShadow>? boxShadow;
  final Clip clipBehavior;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    Widget content = child ?? const SizedBox.shrink();

    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    if (alignment != null) {
      content = Align(alignment: alignment!, child: content);
    }

    final hasDecoration = background != null ||
        border != null ||
        borderRadius != null ||
        (boxShadow != null && boxShadow!.isNotEmpty);

    if (hasDecoration) {
      final decoration = BoxDecoration(
        color: background,
        border: border,
        borderRadius: borderRadius,
        boxShadow: boxShadow,
      );
      if (clipBehavior != Clip.none && borderRadius != null) {
        content = ClipRRect(
          borderRadius: borderRadius!,
          clipBehavior: clipBehavior,
          child: content,
        );
      }
      content = DecoratedBox(decoration: decoration, child: content);
    }

    if (width != null || height != null) {
      content = SizedBox(width: width, height: height, child: content);
    }

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    return content;
  }
}
