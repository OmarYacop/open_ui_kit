import 'package:flutter/widgets.dart';

import 'ui_contour_controller.dart';
import 'ui_measured_morph.dart';

/// Composes a [UiContourController]'s single progress timeline with
/// [UiMeasuredMorph]'s layout-time geometry solver.
///
/// This is intentionally a thin composition, not a new transition engine:
/// [UiMeasuredMorph] already owns geometry correctly (both states measured
/// every frame, size lerped before paint, hit testing and semantics routed
/// only to the active state). [UiContourController] already owns the single
/// progress timeline and state machine. `UiContourMorph` only wires the two
/// together so components don't have to.
///
/// [builder] receives the controller's raw, possibly-overshooting value —
/// use it to drive bounded material or deformation treatment. Layout
/// geometry itself is always clamped to 0..1 internally.
class UiContourMorph extends StatelessWidget {
  const UiContourMorph({
    super.key,
    required this.controller,
    required this.collapsed,
    required this.expanded,
    this.alignment = Alignment.center,
    this.switchPoint = 0.5,
    this.clipBehavior = Clip.hardEdge,
  });

  final UiContourController controller;
  final Widget collapsed;
  final Widget expanded;
  final AlignmentGeometry alignment;
  final double switchPoint;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return UiMeasuredMorph(
          progress: controller.value.clamp(0.0, 1.0),
          alignment: alignment,
          switchPoint: switchPoint,
          clipBehavior: clipBehavior,
          collapsed: collapsed,
          expanded: expanded,
        );
      },
    );
  }
}
