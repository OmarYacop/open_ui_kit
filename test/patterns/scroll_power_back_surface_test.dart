import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  testWidgets(
    'page and conversation enable blur on Android and Apple',
    (tester) async {
      await tester.pumpWidget(
        UiApp(
          home: UiPageScaffold(
            body: UiConversationLayout(
              header: const SizedBox(height: 80),
              composer: const SizedBox(height: 56),
              headerExtent: 80,
              composerExtent: 56,
              historyBuilder: (_, _) => const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final fade in tester.widgetList<UiScrollEdgeFade>(
        find.byType(UiScrollEdgeFade),
      )) {
        expect(fade.enableProgressiveBlur, isTrue);
        expect(fade.topProtectionExtent, 0);
      }
      expect(
        find.byKey(const Key('ui_scroll_edge_progressive_blur')),
        findsNWidgets(2),
      );
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.macOS,
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'explicit blur opt-out keeps the historical platform tint',
    (tester) async {
      const background = Color(0xff123456);
      await tester.pumpWidget(
        UiApp(
          home: const UiScrollEdgeFade(
            backgroundColor: background,
            enableProgressiveBlur: false,
            child: SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('ui_scroll_edge_progressive_blur')),
        findsNothing,
      );
      final gradients = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((w) => w.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.gradient)
          .whereType<LinearGradient>()
          .toList();
      for (final gradient in gradients) {
        expect(gradient.stops, [0.0, .12, 1.0]);
        expect(
          gradient.colors.first,
          const Color(0xffffffff).withValues(alpha: .84),
        );
        expect(gradient.colors.last.a, 0);
      }
      expect(gradients.length, 2);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.macOS,
      TargetPlatform.android,
    }),
  );

  for (final direction in TextDirection.values) {
    testWidgets('back surface stays compact in a tight chat slot $direction', (
      tester,
    ) async {
      double? surface;
      for (final inChat in [false, true]) {
        final back = UiNavigationBackButton(label: 'Back', onPressed: () {});
        await tester.pumpWidget(
          UiApp(
            home: Directionality(
              textDirection: direction,
              child: Center(
                child: inChat
                    ? UiChatHeader(title: 'Chat', leading: back)
                    : back,
              ),
            ),
          ),
        );
        final button = find.byType(UiIconButton);
        final box = find.descendant(of: button, matching: find.byType(UiBox));
        final size = tester.getSize(box);
        expect(size, const Size(44, 44));
        expect(tester.getSize(button).width, greaterThanOrEqualTo(44));
        if (surface != null) expect(size.width, surface);
        surface = size.width;
        expect(tester.takeException(), isNull);
      }
    });
  }
}
