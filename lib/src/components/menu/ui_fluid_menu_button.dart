import 'ui_dropdown_menu.dart';

/// Compatibility name for [UiDropdownMenu]. New code should use UiDropdownMenu.
/// Retains the original fixed width and outside-tap passthrough defaults.
class UiFluidMenuButton extends UiDropdownMenu {
  const UiFluidMenuButton({
    super.key,
    required String title,
    required super.trigger,
    super.sourceBorderRadius,
    super.destinationOffset,
    super.transitionDurationScale,
    super.menuTokens,
    required super.items,
    this.width = 300,
    String backLabel = 'Back',
  }) : super(
         title: title,
         backLabel: backLabel,
         minWidth: width,
         maxWidth: width,
         consumeOutsideTap: false,
       );

  final double width;

  @override
  String get title => super.title!;
  @override
  String get backLabel => super.backLabel!;
}
