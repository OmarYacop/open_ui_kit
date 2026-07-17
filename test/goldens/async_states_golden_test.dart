import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

import 'golden_test_host.dart';

void main() {
  group('async state goldens', skip: !isSupportedGoldenHost, () {
    testWidgets('UiLoadingState static page light', (tester) async {
      await pumpGoldenFrame(
        tester,
        brightness: Brightness.light,
        child: const UiLoadingState(
          mode: UiAsyncStateMode.page,
          indicatorMode: UiLoadingIndicatorMode.staticFrame,
          title: 'Loading messages',
          description: 'Please wait a moment.',
        ),
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/loading_state_page_light.png'),
      );
    });

    testWidgets('UiEmptyState page light', (tester) async {
      await pumpGoldenFrame(
        tester,
        brightness: Brightness.light,
        child: UiEmptyState(
          mode: UiAsyncStateMode.page,
          title: 'No messages',
          description: 'Start a conversation to see it here.',
          actions: [
            UiButton(
              label: 'New message',
              intent: UiIntent.primary,
              onPressed: () {},
            ),
          ],
        ),
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/empty_state_page_light.png'),
      );
    });

    testWidgets('UiErrorState inline dark', (tester) async {
      await pumpGoldenFrame(
        tester,
        brightness: Brightness.dark,
        child: UiErrorState(
          title: 'Could not load',
          description: 'Check your connection and try again.',
          actions: [
            UiButton(
              label: 'Retry',
              intent: UiIntent.primary,
              onPressed: () {},
            ),
            UiButton(
              label: 'Cancel',
              intent: UiIntent.ghost,
              onPressed: () {},
            ),
          ],
        ),
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/error_state_inline_dark.png'),
      );
    });

    testWidgets('UiButton primary + destructive row', (tester) async {
      await pumpGoldenFrame(
        tester,
        brightness: Brightness.light,
        size: const Size(320, 96),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              UiButton(
                label: 'Save',
                intent: UiIntent.primary,
                onPressed: () {},
              ),
              UiButton(
                label: 'Delete',
                intent: UiIntent.destructive,
                onPressed: () {},
              ),
              UiButton(
                label: 'Neutral',
                intent: UiIntent.neutral,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/buttons_row_light.png'),
      );
    });
  });
}
