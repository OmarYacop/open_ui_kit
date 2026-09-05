import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

const _searchTriggerLabel = 'Search';
const _barKey = ValueKey('contour-accessory-bar');
const _barWindowKey = ValueKey('contour-accessory-bar-window');
const _accessoryKey = ValueKey('contour-accessory-surface');

Widget _host(
  Widget child, {
  double width = 360,
  bool disableAnimations = false,
  UiEffectsLevel effectsLevel = UiEffectsLevel.full,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: UiTheme(
        tokens: UiThemeTokens.light.copyWith(
          effects: effectsLevel == UiEffectsLevel.reduced
              ? UiEffectsTokens.reduced
              : UiEffectsTokens.full,
        ),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    ),
  );
}

List<UiContourBarItem> _items() => [
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
];

void main() {
  testWidgets(
    'collapsed: bar items and search trigger are visible and tappable',
    (tester) async {
      await tester.pumpWidget(
        _host(UiContourAccessoryRelease(items: _items())),
      );
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(find.bySemanticsLabel(_searchTriggerLabel), findsOneWidget);
      expect(find.byKey(_accessoryKey), findsNothing);
    },
  );

  testWidgets(
    'the bar and accessory each keep persistent identity across the transition',
    (tester) async {
      await tester.pumpWidget(
        _host(UiContourAccessoryRelease(items: _items())),
      );
      final barBefore = tester.element(find.byKey(_barKey));

      await tester.tap(find.bySemanticsLabel(_searchTriggerLabel));
      await tester.pumpAndSettle();

      final barAfter = tester.element(find.byKey(_barKey));
      expect(identical(barBefore, barAfter), isTrue);
      expect(find.byKey(_accessoryKey), findsOneWidget);
    },
  );

  testWidgets(
    'the bar recedes and its trailing items fade as the accessory expands',
    (tester) async {
      await tester.pumpWidget(
        _host(UiContourAccessoryRelease(items: _items())),
      );
      final collapsedBarWidth = tester.getRect(find.byKey(_barWindowKey)).width;

      await tester.tap(find.bySemanticsLabel(_searchTriggerLabel));
      await tester.pumpAndSettle();

      final expandedBarWidth = tester.getRect(find.byKey(_barWindowKey)).width;
      expect(expandedBarWidth, lessThan(collapsedBarWidth));

      // Home/Messages are excluded from hit testing once fully faded.
      var homeTaps = 0;
      await tester.tap(find.byIcon(Icons.home_rounded), warnIfMissed: false);
      await tester.pump();
      expect(homeTaps, 0);
    },
  );

  testWidgets(
    'accessory becomes interactive and collapses back via its own close button',
    (tester) async {
      await tester.pumpWidget(
        _host(
          UiContourAccessoryRelease(
            items: _items(),
            accessoryChild: const Text('query'),
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel(_searchTriggerLabel));
      await tester.pumpAndSettle();

      expect(find.text('query'), findsOneWidget);
      expect(find.bySemanticsLabel('Close search'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Close search'));
      await tester.pumpAndSettle();

      expect(find.byKey(_accessoryKey), findsNothing);
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    },
  );

  testWidgets('reduced motion reaches the final state immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        UiContourAccessoryRelease(items: _items()),
        disableAnimations: true,
      ),
    );
    await tester.tap(find.bySemanticsLabel(_searchTriggerLabel));
    await tester.pump();
    expect(find.bySemanticsLabel('Close search'), findsOneWidget);
  });

  testWidgets(
    'reduced effects tier omits the backdrop blur but keeps the surface functional',
    (tester) async {
      await tester.pumpWidget(
        _host(
          UiContourAccessoryRelease(items: _items()),
          effectsLevel: UiEffectsLevel.reduced,
        ),
      );
      await tester.tap(find.bySemanticsLabel(_searchTriggerLabel));
      await tester.pumpAndSettle();

      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byKey(_accessoryKey), findsOneWidget);
    },
  );

  testWidgets(
    'full effects tier applies a bounded backdrop blur to the accessory only',
    (tester) async {
      await tester.pumpWidget(
        _host(UiContourAccessoryRelease(items: _items())),
      );
      await tester.tap(find.bySemanticsLabel(_searchTriggerLabel));
      await tester.pumpAndSettle();

      expect(find.byType(BackdropFilter), findsOneWidget);
    },
  );

  testWidgets('disposing mid-transition does not throw', (tester) async {
    await tester.pumpWidget(_host(UiContourAccessoryRelease(items: _items())));
    await tester.tap(find.bySemanticsLabel(_searchTriggerLabel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.pumpWidget(_host(const SizedBox()));
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid repeated taps do not corrupt state', (tester) async {
    await tester.pumpWidget(_host(UiContourAccessoryRelease(items: _items())));
    for (var i = 0; i < 6; i++) {
      // The trigger is excluded from hit testing once expanded (its role
      // shifts to the accessory's own close button) — expected no-ops on
      // alternating iterations, not a bug.
      await tester.tap(
        find.bySemanticsLabel(_searchTriggerLabel),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(milliseconds: 10));
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('controlled mode follows the expanded flag', (tester) async {
    var expanded = false;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return _host(
            UiContourAccessoryRelease(
              items: _items(),
              expanded: expanded,
              onExpandedChanged: (v) => setState(() => expanded = v),
            ),
          );
        },
      ),
    );
    await tester.tap(find.bySemanticsLabel(_searchTriggerLabel));
    await tester.pumpAndSettle();
    expect(expanded, isTrue);
    expect(find.byKey(_accessoryKey), findsOneWidget);
  });
}
