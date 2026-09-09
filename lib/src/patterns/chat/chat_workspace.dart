import '../layout/ui_dual_pane.dart';

/// Chat uses the kit's adaptive master/detail navigation directly: root routes
/// on phones, overlay detail on tablets, and inbox/detail panes on desktop.
/// Keeping the same controller preserves selection and navigation contracts.
class UiChatWorkspace<T> extends UiDualPane<T> {
  const UiChatWorkspace({
    super.key,
    required super.controller,
    required super.primaryBuilder,
    required super.detailBuilder,
    super.primaryFlex = 2,
    super.detailFlex = 3,
    super.gap = 0,
    super.tabletMode = UiDualPaneTabletMode.overlayDetail,
    super.breakpoints,
    super.showDivider,
    super.phoneUsesRootNavigator,
  });
}
