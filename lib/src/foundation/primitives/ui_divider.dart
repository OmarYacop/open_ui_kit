import 'package:flutter/widgets.dart';

import '../theme/ui_theme_extensions.dart';

/// Thin neutral divider. Horizontal by default.
class UiDivider extends StatelessWidget {
  const UiDivider({
    super.key,
    this.axis = Axis.horizontal,
    this.thickness = 1,
    this.indent = 0,
    this.endIndent = 0,
    this.color,
  });

  final Axis axis;
  final double thickness;
  final double indent;
  final double endIndent;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? UiThemeTokens.of(context).colors.border;

    if (axis == Axis.horizontal) {
      return Padding(
        padding: EdgeInsetsDirectional.only(start: indent, end: endIndent),
        child: Container(height: thickness, color: resolvedColor),
      );
    }
    return Padding(
      padding: EdgeInsets.only(top: indent, bottom: endIndent),
      child: Container(width: thickness, color: resolvedColor),
    );
  }
}
