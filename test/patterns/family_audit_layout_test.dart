import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  for (final direction in TextDirection.values) {
    testWidgets(
      'family drawer keeps single-line compact columns at 360px and 1.15 ($direction)',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(360, 800);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final controller = UiBottomTabDrawerController();
        await tester.pumpWidget(
          UiApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 800),
                textScaler: TextScaler.linear(1.15),
              ),
              child: Directionality(
                textDirection: direction,
                child: UiExpandingBottomTabBar(
                  controller: controller,
                  currentIndex: 0,
                  onChanged: (_) {},
                  items: [
                    for (final name in [
                      'Home',
                      'Classes',
                      'My Children',
                      'Library',
                      'Notifications',
                      'Account',
                    ])
                      UiBottomTabItem(
                        id: name,
                        label: name,
                        icon: const Icon(IconData(0xe001)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        controller.open();
        await tester.pumpAndSettle();
        final label = find.text('Notifications');
        final paragraph = tester.renderObject<RenderParagraph>(label);
        final boxes = paragraph.getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 13),
        );
        expect(boxes.map((box) => box.top).toSet().length, 1);
        expect(paragraph.maxLines, 1);
        expect(paragraph.overflow, TextOverflow.ellipsis);
        expect(
          tester.getTopLeft(find.text('Home')).dy,
          tester.getTopLeft(find.text('Library')).dy,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );
  }
  testWidgets(
    'conversation protects the full header without clipping history',
    (tester) async {
      await tester.pumpWidget(
        UiApp(
          home: UiConversationLayout(
            header: const SizedBox(height: 80),
            composer: const SizedBox(height: 56),
            headerExtent: 80,
            composerExtent: 56,
            historyBuilder: (_, padding) =>
                const ColoredBox(color: Color(0xFFFFFFFF)),
          ),
        ),
      );
      final fade = tester.widget<UiScrollEdgeFade>(
        find.byType(UiScrollEdgeFade),
      );
      expect(fade.topProtectionExtent, 0);
      expect(fade.enableProgressiveBlur, isTrue);
      expect(fade.extent, greaterThan(80));
      final gradients = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .map((box) => box.gradient)
          .whereType<LinearGradient>();
      expect(
        gradients.any(
          (gradient) =>
              gradient.colors.first.a < 1 &&
              (gradient.stops == null || gradient.stops![1] <= .12),
        ),
        isTrue,
      );
    },
  );
}
