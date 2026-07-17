import 'ui_navigation_back_button.dart';
import 'ui_navigation_controller.dart';

/// Back-compat shim. `toBackHistoryItems()` forwards to
/// [UiNavigationController.historyItems] — new code should call the
/// controller method directly.
extension UiNavigationHistoryX on UiNavigationController {
  List<UiNavigationBackHistoryItem> toBackHistoryItems() => historyItems();
}
