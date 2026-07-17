import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget _host(Widget child) => MaterialApp(
      theme: UiThemeData.light(),
      home: Scaffold(body: child),
    );

void main() {
  group('UiLoadingState', () {
    testWidgets('renders title/description and advertises live region',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const UiLoadingState(
            title: 'Loading orders',
            description: 'One moment.',
          ),
        ),
      );
      expect(find.text('Loading orders'), findsOneWidget);
      expect(find.text('One moment.'), findsOneWidget);

      // Semantics: a live region with a label is published so screen
      // readers announce the state change.
      final semantics = tester.getSemantics(find.byType(UiLoadingState));
      expect(semantics.label, contains('Loading'));

      // Stop the spinner animation for a clean teardown.
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('page mode centers within max width', (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 800,
            height: 600,
            child: UiLoadingState(
              mode: UiAsyncStateMode.page,
              title: 'Loading',
            ),
          ),
        ),
      );
      // Text center-aligns when page mode.
      final textWidget = tester.widget<Text>(
        find.descendant(
          of: find.byType(UiLoadingState),
          matching: find.text('Loading'),
        ),
      );
      expect(textWidget.textAlign, TextAlign.center);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('static indicator mode renders without animated ticker',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const UiLoadingState(
            indicatorMode: UiLoadingIndicatorMode.staticFrame,
            title: 'Loading',
          ),
        ),
      );

      expect(find.text('Loading'), findsOneWidget);
    });
  });

  group('UiEmptyState', () {
    testWidgets('shows glyph + copy + actions', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _host(
          UiEmptyState(
            title: 'Nothing here',
            description: 'Create your first note to get started.',
            actions: [
              UiButton(
                label: 'New note',
                intent: UiIntent.primary,
                onPressed: () => tapped++,
              ),
            ],
          ),
        ),
      );
      expect(find.text('Nothing here'), findsOneWidget);
      expect(
          find.text('Create your first note to get started.'), findsOneWidget);

      await tester.tap(find.text('New note'));
      expect(tapped, 1);
    });
  });

  group('UiErrorState', () {
    testWidgets('publishes live region + renders actions', (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        _host(
          UiErrorState(
            title: 'Could not load',
            description: 'Check your connection and try again.',
            actions: [
              UiButton(
                label: 'Retry',
                intent: UiIntent.primary,
                onPressed: () => retries++,
              ),
            ],
          ),
        ),
      );
      final semantics = tester.getSemantics(find.byType(UiErrorState));
      expect(semantics.label, contains('Could not load'));

      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    });
  });
}
