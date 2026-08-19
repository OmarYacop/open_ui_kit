import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

import 'golden_test_host.dart';

const _searchTriggerLabel = 'Search';

/// Verifies actual painted pixels for the two-independent-surfaces model:
/// a persistent bar receding while an independent, blurred accessory
/// surface grows from the search trigger's position.
void main() {
  if (!isSupportedGoldenHost) return;

  List<UiContourBarItem> items() => [
        UiContourBarItem(
          icon: const Icon(Icons.home_rounded),
          semanticsLabel: 'Home',
          onPressed: () {},
        ),
        UiContourBarItem(
          icon: const Icon(Icons.message_rounded),
          semanticsLabel: 'Messages',
          onPressed: () {},
        ),
        UiContourBarItem(
          icon: const Icon(Icons.person_rounded),
          semanticsLabel: 'Profile',
          onPressed: () {},
        ),
      ];

  Widget bar() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: 340,
        child: UiContourAccessoryRelease(
          items: items(),
          intent: UiIntent.neutral,
        ),
      ),
    );
  }

  testWidgets('collapsed bar', (tester) async {
    await pumpGoldenFrame(tester, brightness: Brightness.light, child: bar());
    await expectLater(
      find.byType(UiContourAccessoryRelease),
      matchesGoldenFile('goldens/contour_accessory_collapsed.png'),
    );
  });

  testWidgets('search accessory expanded, bounded blur visible', (
    tester,
  ) async {
    await pumpGoldenFrame(tester, brightness: Brightness.light, child: bar());
    await tester.tap(find.bySemanticsLabel(_searchTriggerLabel));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(UiContourAccessoryRelease),
      matchesGoldenFile('goldens/contour_accessory_expanded.png'),
    );
  });
}
