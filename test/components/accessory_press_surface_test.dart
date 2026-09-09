import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  for (final rtl in [false, true]) {
    testWidgets(
      'accessory paints larger chrome with fixed icon and target rtl=$rtl',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundaryKey = GlobalKey();
        final controller = UiBottomTabDrawerController();
        addTearDown(controller.dispose);
        var taps = 0;
        Widget host(bool reduced) => UiApp(
          mode: UiThemeMode.dark,
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(390, 844),
              disableAnimations: reduced,
            ),
            child: Directionality(
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              child: RepaintBoundary(
                key: boundaryKey,
                child: ColoredBox(
                  color: const Color(0xff000000),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: UiExpandingBottomTabBar(
                      controller: controller,
                      items: const [
                        UiBottomTabItem(label: 'Home'),
                        UiBottomTabItem(label: 'Chats'),
                      ],
                      currentIndex: 1,
                      onChanged: (_) {},
                      accessory: UiBottomTabAccessory(
                        height: 48,
                        collapsedWidth: 48,
                        collapsedHeight: 48,
                        child: UiIconButton(
                          key: const ValueKey('accessory-button'),
                          icon: const SizedBox(
                            key: ValueKey('accessory-icon'),
                            width: 20,
                            height: 20,
                          ),
                          size: UiSize.lg,
                          semanticsLabel: 'Search',
                          onPressed: () => taps++,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpWidget(host(false));
        await tester.pumpAndSettle();
        final button = find.byKey(const ValueKey('accessory-button'));
        final icon = find.byKey(const ValueKey('accessory-icon'));
        final surface = find
            .ancestor(of: button, matching: find.byType(UiFluidSurface))
            .first;
        final resting = tester.getRect(surface);
        final hitRect = tester.getRect(button);
        final iconRect = tester.getRect(icon);
        final sample = Offset(resting.left - 2, resting.center.dy);
        Future<int> redAtSample() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final position = boundary.globalToLocal(sample);
          final image = await boundary.toImage();
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final red = bytes.getUint8(
            (position.dy.floor() * image.width + position.dx.floor()) * 4,
          );
          image.dispose();
          return red;
        }

        final before = (await tester.runAsync(redAtSample))!;
        final press = await tester.startGesture(hitRect.center);
        await tester.pump(const Duration(milliseconds: 110));
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.getRect(surface).width, greaterThan(resting.width + 5));
        expect(tester.getRect(button).left, closeTo(hitRect.left, .001));
        expect(tester.getRect(button).size, hitRect.size);
        expect(tester.getRect(icon).left, closeTo(iconRect.left, .001));
        expect(tester.getRect(icon).top, closeTo(iconRect.top, .001));
        expect(tester.getRect(icon).width, closeTo(iconRect.width, .001));
        expect(tester.getRect(icon).height, closeTo(iconRect.height, .001));
        expect(
          await tester.runAsync(redAtSample),
          greaterThan(before + 10),
          reason: 'The painted fill must reach outside its resting outline, not only the layout rectangle.',
        );
        await press.cancel();
        await tester.pumpAndSettle();
        expect(tester.getRect(surface), resting);
        expect(taps, 0);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(taps, 1);
        await tester.pumpWidget(host(true));
        await tester.pumpAndSettle();
        final reducedPress = await tester.startGesture(
          tester.getCenter(button),
        );
        await tester.pump(const Duration(milliseconds: 110));
        await tester.pumpAndSettle();
        expect(tester.getRect(surface), resting);
        await reducedPress.cancel();
        await tester.pumpAndSettle();
        await tester.pumpWidget(host(false));
        await tester.pumpAndSettle();
        final interrupted = await tester.startGesture(tester.getCenter(button));
        await tester.pump(const Duration(milliseconds: 110));
        await tester.pumpWidget(const SizedBox.shrink());
        await interrupted.cancel();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
