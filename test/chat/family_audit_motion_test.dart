import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets(
      'distant variable-height reply seeks do not expose estimates reduced=$reduced',
      (tester) async {
        final controller = UiMessageScrollerController();
        await tester.pumpWidget(
          UiApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: UiMessageScroller(
                controller: controller,
                items: List.generate(
                  180,
                  (i) => UiMessageScrollerItem(
                    id: '$i',
                    child: SizedBox(
                      height: i % 3 == 0 ? 240 : 56,
                      child: Text('message $i'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final list = tester.widget<ListView>(find.byType(ListView));
        final fade = find
            .ancestor(
              of: find.byType(ListView),
              matching: find.byType(FadeTransition),
            )
            .first;
        var completed = false;
        final jump = controller.jumpToMessage('15', onlyIfNeeded: true)
          ..then((_) => completed = true);
        var previous = list.controller!.offset;
        var sawHiddenSeek = false;
        for (var frame = 0; frame < 120 && !completed; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          final opacity = tester.widget<FadeTransition>(fade).opacity.value;
          if (list.controller!.offset != previous && !reduced) {
            expect(
              opacity,
              0,
              reason: 'Estimated offsets must never be painted',
            );
            sawHiddenSeek = true;
          }
          previous = list.controller!.offset;
        }
        expect(await jump, isTrue);
        expect(controller.isMessageVisible('15'), isTrue);
        if (!reduced) expect(sawHiddenSeek, isTrue);
        expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
        final returnJump = controller.jumpToMessage('178', onlyIfNeeded: true);
        await tester.pumpAndSettle();
        expect(await returnJump, isTrue);
        expect(controller.isMessageVisible('178'), isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );
  }
  testWidgets('latest command interrupts a distant reply fade', (tester) async {
    final controller = UiMessageScrollerController();
    await tester.pumpWidget(
      UiApp(
        home: UiMessageScroller(
          controller: controller,
          items: List.generate(
            100,
            (i) => UiMessageScrollerItem(
              id: '$i',
              child: SizedBox(height: 100, child: Text('$i')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final first = controller.jumpToMessage('0');
    await tester.pump(const Duration(milliseconds: 32));
    final latest = controller.jumpToLatest();
    await tester.pumpAndSettle();
    expect(await first, isFalse);
    await latest;
    expect(controller.isAtLiveEdge, isTrue);
    expect(controller.isMessageVisible('99'), isTrue);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  testWidgets('nearby navigation interrupts a hidden distant seek', (
    tester,
  ) async {
    final controller = UiMessageScrollerController();
    await tester.pumpWidget(
      UiApp(
        home: UiMessageScroller(
          controller: controller,
          items: List.generate(
            100,
            (i) => UiMessageScrollerItem(
              id: '$i',
              child: SizedBox(height: 100, child: Text('$i')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final distant = controller.jumpToMessage('0');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    final nearby = controller.jumpToMessage('98');
    await tester.pumpAndSettle();
    expect(await distant, isFalse);
    expect(await nearby, isTrue);
    final fade = find
        .ancestor(
          of: find.byType(ListView),
          matching: find.byType(FadeTransition),
        )
        .first;
    expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
    expect(controller.isMessageVisible('98'), isTrue);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
