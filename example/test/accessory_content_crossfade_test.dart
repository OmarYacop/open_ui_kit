import 'package:contour_example/main.dart' as app;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

void main() {
  testWidgets('switching directly between two tabs that both have an accessory '
      'cross-dissolves the icon instead of cutting instantly', (tester) async {
    tester.view.physicalSize = const Size(420, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    app.main();
    await tester.pumpAndSettle();

    final demoFinder = find.byKey(
      const ValueKey('real-bottom-tab-accessory-demo'),
    );
    await tester.scrollUntilVisible(
      demoFinder,
      200,
      scrollable: find.byType(Scrollable).first,
    );

    // Home -> Messages goes through presence (accessory didn't exist on
    // Home), so settle there first — this test cares about the next step.
    await tester.tap(
      find.descendant(of: demoFinder, matching: find.text('Messages')),
    );
    await tester.pumpAndSettle();

    final messagesIcon = find.descendant(
      of: demoFinder,
      matching: find.byIcon(LucideIcons.mail),
    );
    final profileIcon = find.descendant(
      of: demoFinder,
      matching: find.byIcon(LucideIcons.userSearch),
    );
    expect(messagesIcon, findsOneWidget);
    expect(profileIcon, findsNothing);

    // Messages -> Profile: both already have an accessory, so this is the
    // shell-stays-put, content-crossfades case — the one the presence-only
    // model could not cover.
    await tester.tap(
      find.descendant(of: demoFinder, matching: find.text('Profile')),
    );
    await tester.pump();

    // Immediately after the switch, both endpoints must be visible —
    // that is the entire point of a cross-dissolve.
    expect(messagesIcon, findsOneWidget);
    expect(profileIcon, findsOneWidget);

    await tester.pumpAndSettle();
    expect(messagesIcon, findsNothing);
    expect(profileIcon, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
