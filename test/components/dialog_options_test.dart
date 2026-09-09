import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget _host(Widget dialog) => MaterialApp(home: Scaffold(body: dialog));

void main() {
  testWidgets(
    'maxWidth caps the surface and headerAction sits on the title row',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 600);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var closed = 0;
      await tester.pumpWidget(
        _host(
          UiDialog(
            title: 'Range',
            maxWidth: 288,
            headerAction: UiIconButton(
              icon: const Icon(Icons.close),
              semanticsLabel: 'Close',
              onPressed: () => closed++,
            ),
            content: const SizedBox(height: 40),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(UiBox).first).width, 288);
      final titleRect = tester.getRect(find.text('Range'));
      final closeRect = tester.getRect(find.byType(UiIconButton));
      expect(closeRect.left, greaterThan(titleRect.right));
      expect(closeRect.center.dy, closeTo(titleRect.center.dy, 24));
      await tester.tap(find.byType(UiIconButton));
      expect(closed, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'scrollable content stays inside the viewport with pinned actions',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 500);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _host(
          UiDialog(
            title: 'Tall',
            scrollable: true,
            content: const SizedBox(height: 2000, child: Text('body')),
            actions: [UiButton(label: 'Done', onPressed: () {})],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(
        tester.getSize(find.byType(UiBox).first).height,
        lessThanOrEqualTo(500),
      );
      final done = tester.getRect(find.text('Done'));
      expect(done.bottom, lessThanOrEqualTo(500));
    },
  );

  testWidgets('defaults are unchanged: 420 wide, no scroll view', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _host(const UiDialog(title: 'Plain', content: SizedBox(height: 40))),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(UiBox).first).width, 420);
    expect(find.byType(SingleChildScrollView), findsNothing);
  });
}
