import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

import 'package:contour_example/drag_drop_workbench.dart';

void main() {
  for (final width in [320.0, 834.0, 1280.0]) {
    testWidgets(
      'workbench fits at $width and exposes transfer without dragging',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 1100));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(const UiApp(home: DragDropWorkbench()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Move to Ready'));
        await tester.tap(find.text('Move to Ready'));
        await tester.pumpAndSettle();
        expect(find.text('Moved to Ready'), findsOneWidget);
        expect(find.text('Component handoff moved to Ready.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
