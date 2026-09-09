import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  for (final scale in [1.0, 1.15, 2.0]) {
    testWidgets(
      'back and menu chrome match at scale $scale',
      (tester) async {
        await tester.pumpWidget(
          UiApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UiNavigationBackButton(label: 'Back', onPressed: () {}),
                    UiIconButton(
                      semanticsLabel: 'Menu',
                      icon: const Icon(IconData(0xe000)),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        final buttons = find.byType(UiIconButton);
        final surfaces = [
          for (var i = 0; i < 2; i++)
            tester.getSize(
              find.descendant(of: buttons.at(i), matching: find.byType(UiBox)),
            ),
        ];
        expect(surfaces[0], surfaces[1]);
        expect(surfaces[0].width, 44);
        final chevron = tester.widget<Icon>(
          find.descendant(
            of: find.byType(UiNavigationBackButton),
            matching: find.byType(Icon),
          ),
        );
        expect(chevron.size, 32);
        expect(chevron.applyTextScaling, isFalse);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.iOS,
        TargetPlatform.android,
      }),
    );
  }
}
