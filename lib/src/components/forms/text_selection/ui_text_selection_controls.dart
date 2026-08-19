import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../foundation/theme/ui_theme_extensions.dart';

/// Platform-adaptive selection handles for [UiInput].
///
/// Mirrors the default handle appearance Material's `TextField` and
/// Cupertino's `CupertinoTextField` get from `materialTextSelectionControls`
/// / `cupertinoTextSelectionControls` (a teardrop on Android, a bar-and-ball
/// on iOS, none on desktop), built entirely from `package:flutter/widgets.dart`
/// so this kit never depends on Material or Cupertino.
///
/// Every variant mixes in [TextSelectionHandleControls] so [EditableText]
/// defers to `contextMenuBuilder` for the toolbar instead of this class's
/// (deprecated) `buildToolbar`.
TextSelectionControls get uiAdaptiveTextSelectionControls {
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return _uiCupertinoTextSelectionControls;
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
      return _uiMaterialTextSelectionControls;
    case TargetPlatform.macOS:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return _uiDesktopTextSelectionControls;
  }
}

final _uiMaterialTextSelectionControls = _UiMaterialTextSelectionControls();
final _uiCupertinoTextSelectionControls = _UiCupertinoTextSelectionControls();
final _uiDesktopTextSelectionControls = _UiDesktopTextSelectionControls();

// ---------------------------------------------------------------------------
// Android-styled ("teardrop") handles. Ported from
// `material/text_selection.dart`'s `MaterialTextSelectionControls`.
// ---------------------------------------------------------------------------

class _UiMaterialTextSelectionControls extends TextSelectionControls
    with TextSelectionHandleControls {
  static const _handleSize = 22.0;

  @override
  Size getHandleSize(double textLineHeight) =>
      const Size(_handleSize, _handleSize);

  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    double textHeight, [
    VoidCallback? onTap,
  ]) {
    final handleColor = UiThemeTokens.colorsOf(context).primary;
    final handle = SizedBox.square(
      dimension: _handleSize,
      child: CustomPaint(
        painter: _UiMaterialSelectionHandlePainter(color: handleColor),
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.translucent,
        ),
      ),
    );

    // `handle` is a circle with a square in its top-left quadrant (an onion
    // pointing to 10:30). Rotate it to point straight up or up-right
    // depending on the handle type.
    return switch (type) {
      TextSelectionHandleType.left => Transform.rotate(
          angle: math.pi / 2,
          child: handle,
        ),
      TextSelectionHandleType.right => handle,
      TextSelectionHandleType.collapsed => Transform.rotate(
          angle: math.pi / 4,
          child: handle,
        ),
    };
  }

  @override
  Offset getHandleAnchor(TextSelectionHandleType type, double textLineHeight) {
    return switch (type) {
      TextSelectionHandleType.collapsed => const Offset(_handleSize / 2, -4),
      TextSelectionHandleType.left => const Offset(_handleSize, 0),
      TextSelectionHandleType.right => Offset.zero,
    };
  }
}

class _UiMaterialSelectionHandlePainter extends CustomPainter {
  _UiMaterialSelectionHandlePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final radius = size.width / 2;
    final circle = Rect.fromCircle(
      center: Offset(radius, radius),
      radius: radius,
    );
    final point = Rect.fromLTWH(0, 0, radius, radius);
    final path = Path()
      ..addOval(circle)
      ..addRect(point);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_UiMaterialSelectionHandlePainter oldDelegate) =>
      color != oldDelegate.color;
}

// ---------------------------------------------------------------------------
// iOS-styled ("bar and ball") handles. Ported from
// `cupertino/text_selection.dart`'s `CupertinoTextSelectionControls`.
// ---------------------------------------------------------------------------

class _UiCupertinoTextSelectionControls extends TextSelectionControls
    with TextSelectionHandleControls {
  static const _handleRadius = 6.0;
  static const _handleOverlap = 1.5;

  @override
  Size getHandleSize(double textLineHeight) {
    return Size(
      _handleRadius * 2,
      textLineHeight + _handleRadius * 2 - _handleOverlap,
    );
  }

  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    double textLineHeight, [
    VoidCallback? onTap,
  ]) {
    // iOS selection handles do not respond to taps.
    final handleColor = UiThemeTokens.colorsOf(context).primary;
    final customPaint = CustomPaint(
      painter: _UiCupertinoSelectionHandlePainter(handleColor),
    );

    switch (type) {
      case TextSelectionHandleType.left:
        return SizedBox.fromSize(
          size: getHandleSize(textLineHeight),
          child: customPaint,
        );
      case TextSelectionHandleType.right:
        final desiredSize = getHandleSize(textLineHeight);
        return Transform(
          transform: Matrix4.identity()
            ..translateByDouble(
              desiredSize.width / 2,
              desiredSize.height / 2,
              0,
              1,
            )
            ..rotateZ(math.pi)
            ..translateByDouble(
              -desiredSize.width / 2,
              -desiredSize.height / 2,
              0,
              1,
            ),
          child: SizedBox.fromSize(size: desiredSize, child: customPaint),
        );
      // iOS draws an invisible box so a collapsed handle can still receive
      // gestures without showing a marker (the caret is the only affordance).
      case TextSelectionHandleType.collapsed:
        return SizedBox.fromSize(size: getHandleSize(textLineHeight));
    }
  }

  @override
  Offset getHandleAnchor(TextSelectionHandleType type, double textLineHeight) {
    final handleSize = getHandleSize(textLineHeight);
    switch (type) {
      // The circle is at the top for the left handle; the anchor point is
      // all the way at the bottom of the line.
      case TextSelectionHandleType.left:
        return Offset(handleSize.width / 2, handleSize.height);
      // The right handle is vertically flipped; the anchor point sits near
      // the top of the circle to give slight overlap.
      case TextSelectionHandleType.right:
        return Offset(
          handleSize.width / 2,
          handleSize.height - 2 * _handleRadius + _handleOverlap,
        );
      // A collapsed handle anchors itself so it's centered.
      case TextSelectionHandleType.collapsed:
        return Offset(
          handleSize.width / 2,
          textLineHeight + (handleSize.height - textLineHeight) / 2,
        );
    }
  }
}

class _UiCupertinoSelectionHandlePainter extends CustomPainter {
  const _UiCupertinoSelectionHandlePainter(this.color);

  final Color color;
  static const _handleRadius = 6.0;
  static const _handleOverlap = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    const halfStrokeWidth = 1.0;
    final paint = Paint()..color = color;
    final circle = Rect.fromCircle(
      center: const Offset(_handleRadius, _handleRadius),
      radius: _handleRadius,
    );
    final line = Rect.fromPoints(
      const Offset(
        _handleRadius - halfStrokeWidth,
        2 * _handleRadius - _handleOverlap,
      ),
      Offset(_handleRadius + halfStrokeWidth, size.height),
    );
    final path = Path()
      ..addOval(circle)
      ..addRect(line);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_UiCupertinoSelectionHandlePainter oldDelegate) =>
      color != oldDelegate.color;
}

// ---------------------------------------------------------------------------
// Desktop: no handles, mouse-driven selection only. Ported from
// `material/desktop_text_selection.dart`'s `DesktopTextSelectionControls`.
// ---------------------------------------------------------------------------

class _UiDesktopTextSelectionControls extends TextSelectionControls
    with TextSelectionHandleControls {
  @override
  Size getHandleSize(double textLineHeight) => Size.zero;

  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    double textLineHeight, [
    VoidCallback? onTap,
  ]) =>
      const SizedBox.shrink();

  @override
  Offset getHandleAnchor(TextSelectionHandleType type, double textLineHeight) =>
      Offset.zero;
}
