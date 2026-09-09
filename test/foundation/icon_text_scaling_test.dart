import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

/// Hosts [child] under [UiApp] at a given text scale, the way an app would
/// see it when the user raises the system font size.
Widget host(Widget child, {double scale = 1, double? maxTextScale}) => UiApp(
  mode: UiThemeMode.light,
  maxTextScale: maxTextScale,
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(390, 844),
      textScaler: TextScaler.linear(scale),
    ),
    child: Center(child: child),
  ),
);

/// The rendered box of the first [Icon] inside [of].
Size iconSizeIn(WidgetTester tester, Finder of) =>
    tester.getSize(find.descendant(of: of, matching: find.byType(Icon)).first);

Future<void> pumpFrames(WidgetTester tester, [int frames = 40]) async {
  for (var frame = 0; frame < frames; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  group('uiChromeScale', () {
    test('follows the text scale up to the ceiling and never shrinks', () {
      expect(uiChromeScaleFor(TextScaler.noScaling), 1);
      expect(uiChromeScaleFor(const TextScaler.linear(.8)), 1);
      expect(
        uiChromeScaleFor(const TextScaler.linear(1.2)),
        closeTo(1.2, 1e-9),
      );
      expect(uiChromeScaleFor(const TextScaler.linear(2)), kUiChromeScaleMax);
      expect(uiChromeScaleFor(const TextScaler.linear(2), max: 1.6), 1.6);
    });
  });

  group('UiApp icon text scaling', () {
    testWidgets('a bare Icon grows with the system text scale', (tester) async {
      await tester.pumpWidget(host(const Icon(LucideIcons.star), scale: 2));
      expect(tester.getSize(find.byType(Icon)), const Size(48, 48));

      await tester.pumpWidget(host(const Icon(LucideIcons.star)));
      expect(tester.getSize(find.byType(Icon)), const Size(24, 24));
    });

    testWidgets('UiIconButton keeps stable chrome at larger text sizes', (
      tester,
    ) async {
      Widget button() => UiIconButton(
        icon: const Icon(LucideIcons.x),
        semanticsLabel: 'Close',
        onPressed: () {},
      );
      await tester.pumpWidget(host(button()));
      final restingIcon = iconSizeIn(tester, find.byType(UiIconButton));
      expect(restingIcon, const Size(22, 22));

      await tester.pumpWidget(host(button(), scale: 2));
      expect(tester.takeException(), isNull);
      final scaledIcon = iconSizeIn(tester, find.byType(UiIconButton));
      expect(scaledIcon.width, restingIcon.width);
      // Text preferences do not change icon-only control geometry.
      expect(scaledIcon.width, closeTo(22, .01));
      // The tap target never drops below 44.
      final box = tester.getSize(find.byType(UiIconButton));
      expect(box.width, greaterThanOrEqualTo(44));
    });

    testWidgets(
      'custom glyph size preserves the surface and accessible target',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          host(
            UiIconButton(
              icon: const Icon(LucideIcons.x),
              semanticsLabel: 'Close',
              visualExtent: 36,
              iconSize: 20,
              onPressed: () => taps++,
            ),
            scale: 2,
          ),
        );
        final button = find.byType(UiIconButton);
        expect(iconSizeIn(tester, button), const Size(20, 20));
        expect(tester.getSize(button), const Size(44, 44));
        expect(
          tester.getSize(
            find.descendant(of: button, matching: find.byType(UiBox)),
          ),
          const Size(36, 36),
        );
        await tester.tap(button);
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('UiSettingsList row renders at 2x without overflow', (
      tester,
    ) async {
      final list = SizedBox(
        width: 360,
        child: UiSettingsList(
          groups: const [
            UiSettingsGroup(
              title: 'General',
              items: [
                UiSettingsItem(
                  id: 'a',
                  label: 'Notifications',
                  description: 'Sounds, badges and banners',
                  leading: Icon(LucideIcons.bell),
                  trailing: Icon(LucideIcons.chevronRight),
                ),
              ],
            ),
          ],
        ),
      );
      await tester.pumpWidget(host(list));
      final leadingIconAt1 = tester.getSize(find.byIcon(LucideIcons.bell));

      await tester.pumpWidget(host(list, scale: 2));
      expect(tester.takeException(), isNull);
      final leadingIconAt2 = tester.getSize(find.byIcon(LucideIcons.bell));
      expect(leadingIconAt2.width, greaterThan(leadingIconAt1.width));
      // The trailing icon is content, so it rides the full scale.
      expect(
        tester.getSize(find.byIcon(LucideIcons.chevronRight)),
        const Size(40, 40),
      );
    });

    for (final behavior in [
      UiBottomTabOverflowBehavior.expanding,
      UiBottomTabOverflowBehavior.drawer,
    ]) {
      testWidgets('UiBottomTabScaffold ($behavior) grows icons at 1.6x', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        Widget scaffold() => UiBottomTabScaffold(
          overflowBehavior: behavior,
          items: const [
            UiBottomTabItem(label: 'Home', icon: Icon(LucideIcons.house)),
            UiBottomTabItem(label: 'Search', icon: Icon(LucideIcons.search)),
            UiBottomTabItem(label: 'Me', icon: Icon(LucideIcons.user)),
          ],
          currentIndex: 0,
          onChanged: (_) {},
          pages: const [SizedBox(), SizedBox(), SizedBox()],
        );
        await tester.pumpWidget(host(scaffold()));
        await pumpFrames(tester);
        final iconAt1 = tester.getSize(find.byIcon(LucideIcons.search));

        await tester.pumpWidget(host(scaffold(), scale: 1.6));
        await pumpFrames(tester);
        expect(tester.takeException(), isNull);
        final iconAt16 = tester.getSize(find.byIcon(LucideIcons.search));
        expect(iconAt16.width, greaterThan(iconAt1.width));
        expect(iconAt16.width, closeTo(iconAt1.width * kUiChromeScaleMax, .01));
      });
    }

    testWidgets('maxTextScale clamps text and icons together', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      TextScaler? seen;
      await tester.pumpWidget(
        UiApp(
          mode: UiThemeMode.light,
          maxTextScale: 1.3,
          home: Builder(
            builder: (context) {
              seen = MediaQuery.textScalerOf(context);
              return const Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Hello', style: TextStyle(fontSize: 10)),
                    Icon(LucideIcons.star),
                  ],
                ),
              );
            },
          ),
        ),
      );
      expect(seen!.scale(10), closeTo(13, 1e-9));
      expect(tester.getSize(find.byType(Icon)).width, closeTo(24 * 1.3, .01));
      final textBox = tester.renderObject<RenderBox>(find.byType(Text));
      // Line height of a 10pt glyph at 1.3x is ~13pt; at 2x it would be ~20.
      expect(textBox.size.height, lessThan(18));
      expect(textBox.size.height, greaterThan(10));
    });

    testWidgets('without maxTextScale the system scale passes through', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        const UiApp(
          mode: UiThemeMode.light,
          home: Center(child: Icon(LucideIcons.star)),
        ),
      );
      expect(tester.getSize(find.byType(Icon)), const Size(48, 48));
    });
  });
}
