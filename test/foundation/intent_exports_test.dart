import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/components/forms.dart' as legacy;
import 'package:open_ui_kit/foundation.dart' as foundation;

void main() {
  test('UiIntent remains available from its canonical foundation API', () {
    const intent = foundation.UiIntent.primary;

    expect(intent, foundation.UiIntent.primary);
  });

  // Compatibility contract scheduled for removal in 1.0.0. This test should
  // be removed together with the legacy button/forms re-export.
  test('UiIntent legacy forms export remains compatible through 0.x', () {
    const legacyIntent = legacy.UiIntent.danger;
    const foundationIntent = foundation.UiIntent.danger;

    expect(legacyIntent, same(foundationIntent));
  });
}
