import 'package:contour_example/bottom_navigation_main.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  testWidgets('canonical example selects a secondary page and opens search', (
    tester,
  ) async {
    await tester.pumpWidget(const UiApp(home: BottomNavigationExample()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ui_drawer_handle')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('ui_drawer_destination_library')),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<UiExpandingBottomTabBar>(find.byType(UiExpandingBottomTabBar))
          .currentIndex,
      7,
    );
    await tester.tap(find.bySemanticsLabel('Search'));
    await tester.pumpAndSettle();
    expect(find.byType(UiInput), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
