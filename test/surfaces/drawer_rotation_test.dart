import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  for (final variant in UiDrawerVariant.values) {
    testWidgets('open $variant drawer survives portrait landscape portrait', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      late UiDrawerController<void> controller;
      await tester.pumpWidget(
        UiApp(
          home: Builder(
            builder: (context) => UiButton(
              label: 'Open',
              onPressed: () => UiDrawerScope.show<void>(
                context,
                side: UiDrawerSide.end,
                variant: variant,
                blurBackdrop: true,
                builder: (_) => const SizedBox.shrink(),
                controlledBuilder: (context, value) {
                  controller = value;
                  return UiDrawer(
                    side: UiDrawerSide.end,
                    variant: variant,
                    width: math.min(430, MediaQuery.sizeOf(context).width - 24),
                    header: const UiDrawerHeader(title: 'Classes filters'),
                    body: const UiDrawerSection(
                      child: Column(
                        children: [
                          UiInput(label: 'Filter'),
                          SizedBox(height: 1000),
                          Text('End'),
                        ],
                      ),
                    ),
                    footer: UiDrawerFooter(
                      child: UiButton(label: 'Apply', onPressed: value.dismiss),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final inputState = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      await tester.enterText(find.byType(EditableText), 'Keep this filter');
      await tester.pump();
      for (final size in [
        const Size(844, 390),
        const Size(390, 844),
        const Size(844, 390),
        const Size(390, 844),
      ]) {
        tester.view.physicalSize = size;
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Classes filters'), findsOneWidget);
        expect(find.text('Keep this filter'), findsOneWidget);
        expect(
          tester.state<EditableTextState>(find.byType(EditableText)),
          same(inputState),
        );
        expect(inputState.widget.focusNode.hasFocus, isTrue);
      }
      controller.dismiss();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Classes filters'), findsNothing);
    });
  }
}
