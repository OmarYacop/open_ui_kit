import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

import 'golden_test_host.dart';

/// Verifies actual painted pixels, not just widget presence or hit-test
/// outcomes — hit-testing is pure local-coordinate math and would not have
/// caught the double-offset `pushClipRect` bug (which only corrupted the
/// paint-time clip window). The component is deliberately positioned away
/// from the golden surface's origin so that bug — invisible at offset zero
/// — would show up here as missing/mispositioned action icons.
void main() {
  if (!isSupportedGoldenHost) return;

  Widget offsetContour({required bool expanded}) {
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 96, top: 140),
        child: UiContourRelease(
          label: 'More',
          intent: UiIntent.neutral,
          expanded: expanded,
          actions: [
            UiContourReleaseAction(
              icon: const Icon(Icons.reply_rounded),
              semanticsLabel: 'Reply',
              onPressed: () {},
            ),
            UiContourReleaseAction(
              icon: const Icon(Icons.archive_rounded),
              semanticsLabel: 'Archive',
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('collapsed, offset from origin', (tester) async {
    await pumpGoldenFrame(
      tester,
      brightness: Brightness.light,
      child: offsetContour(expanded: false),
    );
    await expectLater(
      find.byType(UiContourRelease),
      matchesGoldenFile('goldens/contour_release_collapsed_offset.png'),
    );
  });

  testWidgets(
    'expanded, offset from origin — actions must actually be painted',
    (tester) async {
      await pumpGoldenFrame(
        tester,
        brightness: Brightness.light,
        child: offsetContour(expanded: true),
      );
      await tester.pump();
      await expectLater(
        find.byType(UiContourRelease),
        matchesGoldenFile('goldens/contour_release_expanded_offset.png'),
      );
    },
  );
}
