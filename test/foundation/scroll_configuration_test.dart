import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  Widget materialHost(Widget child) {
    return MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 320, height: 200, child: child),
      ),
    );
  }

  testWidgets('removes Android decoration but preserves overscroll events', (
    tester,
  ) async {
    var overscrollNotifications = 0;

    await tester.pumpWidget(
      materialHost(
        UiScrollConfiguration(
          child: NotificationListener<OverscrollNotification>(
            onNotification: (notification) {
              overscrollNotifications++;
              return false;
            },
            child: ListView(children: const [SizedBox(height: 600)]),
          ),
        ),
      ),
    );

    expect(find.byType(StretchingOverscrollIndicator), findsNothing);
    expect(find.byType(GlowingOverscrollIndicator), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, 100));
    await tester.pump();

    expect(overscrollNotifications, greaterThan(0));
  });

  testWidgets('UiApp suppresses overscroll decoration by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      UiApp(home: ListView(children: const [SizedBox(height: 600)])),
    );

    expect(find.byType(GlowingOverscrollIndicator), findsNothing);
    expect(find.byType(StretchingOverscrollIndicator), findsNothing);
  });

  testWidgets('select popup owns the no-overscroll boundary', (tester) async {
    await tester.pumpWidget(
      materialHost(
        UiSelect<int>(
          value: 0,
          options: List.generate(
            20,
            (index) => UiSelectOption(value: index, label: 'Option $index'),
          ),
          onChanged: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('Option 0'));
    await tester.pumpAndSettle();

    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(StretchingOverscrollIndicator), findsNothing);
    expect(find.byType(GlowingOverscrollIndicator), findsNothing);
  });
}
