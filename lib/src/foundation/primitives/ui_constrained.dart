import 'package:flutter/widgets.dart';

/// Loosens incoming layout constraints before applying local size caps.
///
/// Use this when a child should keep a max/min size even inside parents that
/// pass tight constraints, such as [Positioned] with both horizontal edges set.
class UiConstrained extends StatelessWidget {
  const UiConstrained({
    super.key,
    required this.child,
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
    this.alignment = Alignment.center,
    this.widthFactor,
    this.heightFactor,
  })  : assert(minWidth == null || minWidth >= 0),
        assert(maxWidth == null || maxWidth >= 0),
        assert(minHeight == null || minHeight >= 0),
        assert(maxHeight == null || maxHeight >= 0),
        assert(
          minWidth == null || maxWidth == null || minWidth <= maxWidth,
          'minWidth must be less than or equal to maxWidth.',
        ),
        assert(
          minHeight == null || maxHeight == null || minHeight <= maxHeight,
          'minHeight must be less than or equal to maxHeight.',
        );

  final Widget child;
  final double? minWidth;
  final double? maxWidth;
  final double? minHeight;
  final double? maxHeight;
  final AlignmentGeometry alignment;
  final double? widthFactor;
  final double? heightFactor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      widthFactor: widthFactor,
      heightFactor: heightFactor,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: minWidth ?? 0,
          maxWidth: maxWidth ?? double.infinity,
          minHeight: minHeight ?? 0,
          maxHeight: maxHeight ?? double.infinity,
        ),
        child: child,
      ),
    );
  }
}
