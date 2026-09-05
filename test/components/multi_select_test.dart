import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

const options = [
  UiSelectOption(value: 'a', label: 'Ada'),
  UiSelectOption(value: 'b', label: 'Ben'),
  UiSelectOption(value: 'c', label: 'Cleo'),
];

void main() {
  testWidgets(
    'selects multiple options without closing and removes selections',
    (tester) async {
      Set<String> selected = {};
      await tester.pumpWidget(
        UiApp(
          home: Center(
            child: SizedBox(
              width: 320,
              child: StatefulBuilder(
                builder: (context, update) => UiMultiSelect(
                  options: options,
                  value: selected,
                  onChanged: (value) => update(() => selected = value),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(EditableText));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ada'));
      await tester.pumpAndSettle();
      expect(selected, {'a'});
      expect(
        find.byKey(const ValueKey('ui-multi-select-menu')),
        findsOneWidget,
      );
      await tester.tap(find.text('Ben'));
      await tester.pumpAndSettle();
      expect(selected, {'a', 'b'});
      await tester.tap(find.bySemanticsLabel('Remove Ada'));
      await tester.pumpAndSettle();
      expect(selected, {'b'});
    },
  );
  testWidgets(
    'keyboard skips disabled values, selects, removes and dismisses',
    (tester) async {
      Set<String> selected = {};
      final focus = FocusNode();
      await tester.pumpWidget(
        UiApp(
          home: Center(
            child: SizedBox(
              width: 320,
              child: StatefulBuilder(
                builder: (context, update) => UiMultiSelect(
                  options: options,
                  disabledValues: const {'b'},
                  value: selected,
                  focusNode: focus,
                  onChanged: (value) => update(() => selected = value),
                ),
              ),
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected, {'c'});
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();
      expect(selected, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byKey(const ValueKey('ui-multi-select-menu')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      focus.dispose();
    },
  );
  testWidgets('filters lazily and reports empty results', (tester) async {
    final many = List.generate(
      1000,
      (index) => UiSelectOption(value: index, label: 'Person $index'),
    );
    await tester.pumpWidget(
      UiApp(
        home: Center(
          child: SizedBox(
            width: 320,
            child: UiMultiSelect<int>(
              options: many,
              value: const {},
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(EditableText));
    await tester.pumpAndSettle();
    expect(find.byType(UiPressable).evaluate().length, lessThan(40));
    await tester.enterText(find.byType(EditableText), 'Person 999');
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('ui-multi-select-menu')),
        matching: find.text('Person 999'),
      ),
      findsOneWidget,
    );
    await tester.enterText(find.byType(EditableText), 'Nobody');
    await tester.pumpAndSettle();
    expect(find.text('No matching options'), findsOneWidget);
  });
  testWidgets('disabling an open control dismisses and blocks changes', (
    tester,
  ) async {
    var enabled = true;
    late StateSetter update;
    var changes = 0;
    await tester.pumpWidget(
      UiApp(
        home: Center(
          child: SizedBox(
            width: 320,
            child: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return UiMultiSelect(
                  options: options,
                  value: const {'a'},
                  enabled: enabled,
                  onChanged: (_) => changes++,
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(EditableText));
    await tester.pumpAndSettle();
    update(() => enabled = false);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ui-multi-select-menu')), findsNothing);
    await tester.tap(find.text('Ada'));
    expect(changes, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'selection limit and option replacement preserve existing values',
    (tester) async {
      Set<String> selected = {'a'};
      var currentOptions = options;
      late StateSetter update;
      await tester.pumpWidget(
        UiApp(
          home: Center(
            child: SizedBox(
              width: 320,
              child: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return UiMultiSelect(
                    options: currentOptions,
                    value: selected,
                    maxSelections: 1,
                    onChanged: (value) => update(() => selected = value),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(EditableText));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ben'));
      expect(selected, {'a'});
      update(
        () =>
            currentOptions = const [UiSelectOption(value: 'c', label: 'Cleo')],
      );
      await tester.pumpAndSettle();
      expect(selected, {'a'});
      expect(find.bySemanticsLabel('Remove a'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final direction in TextDirection.values) {
    testWidgets('long selections fit at enlarged text in $direction', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        UiApp(
          builder: (context, child) => Directionality(
            textDirection: direction,
            child: MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
          ),
          home: Padding(
            padding: const EdgeInsets.all(16),
            child: UiMultiSelect(
              options: const [
                UiSelectOption(
                  value: 'a',
                  label: 'A very long selection label that must fit',
                ),
              ],
              value: const {'a'},
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
