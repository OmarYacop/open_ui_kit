import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  final controls = <String, Widget Function()>{
    'input': () => const UiInput(
      label: 'Field',
      helper: 'Guidance',
      errorText: 'Required',
    ),
    'slider': () => UiSlider(
      label: 'Field',
      helper: 'Guidance',
      errorText: 'Required',
      value: .5,
      onChanged: (_) {},
    ),
    'rating': () => UiRating(
      label: 'Field',
      helper: 'Guidance',
      errorText: 'Required',
      value: 2,
      onChanged: (_) {},
    ),
  };
  for (final entry in controls.entries) {
    testWidgets('${entry.key} gives its error one live semantic owner', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        UiApp(
          home: Center(child: SizedBox(width: 320, child: entry.value())),
        ),
      );
      final owner = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.liveRegion == true,
      );
      expect(owner, findsOneWidget);
      expect(
        tester.getSemantics(owner).getSemanticsData().label,
        'Error: Required',
      );
      expect(find.text('Guidance'), findsNothing);
      expect(find.text('Field'), findsOneWidget);
      handle.dispose();
    });
  }
}
