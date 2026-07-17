import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget _host(Widget child) => MaterialApp(
      theme: UiThemeData.light(),
      home: Scaffold(body: child),
    );

void main() {
  group('UiDialog backdrop', () {
    testWidgets('dialog surface uses modal radius and padding tokens', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const UiDialog(
            title: 'Confirm',
            actions: [Text('Cancel'), Text('Save')],
          ),
        ),
      );

      final decorations = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(UiDialog),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .toList();
      final paddings = tester
          .widgetList<Padding>(
            find.descendant(
              of: find.byType(UiDialog),
              matching: find.byType(Padding),
            ),
          )
          .map((padding) => padding.padding)
          .toList();
      final actionsRow = tester.widget<Row>(
        find.byKey(const ValueKey('ui-dialog-actions')),
      );

      expect(
        decorations.any((d) => d.borderRadius == UiRadiusTokens.standard.xlAll),
        isTrue,
      );
      expect(paddings, contains(const EdgeInsets.all(24)));
      expect(actionsRow.mainAxisAlignment, MainAxisAlignment.end);
      expect(
        tester.getTopLeft(find.text('Cancel')).dy,
        tester.getTopLeft(find.text('Save')).dy,
      );
    });

    testWidgets('alert dialog surface uses modal radius and padding tokens', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          UiAlertDialog(
            title: 'Delete account',
            description: 'This cannot be undone.',
            confirmLabel: 'Delete',
            onConfirm: () {},
            onCancel: () {},
          ),
        ),
      );

      final decorations = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(UiAlertDialog),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .toList();
      final paddings = tester
          .widgetList<Padding>(
            find.descendant(
              of: find.byType(UiAlertDialog),
              matching: find.byType(Padding),
            ),
          )
          .map((padding) => padding.padding)
          .toList();
      final actionsRow = tester.widget<Row>(
        find.byKey(const ValueKey('ui-alert-dialog-actions')),
      );

      expect(
        decorations.any((d) => d.borderRadius == UiRadiusTokens.standard.xlAll),
        isTrue,
      );
      expect(
        paddings,
        contains(
          const EdgeInsetsDirectional.only(
            top: 20,
            start: 20,
            bottom: 12,
            end: 12,
          ),
        ),
      );
      expect(actionsRow.mainAxisAlignment, MainAxisAlignment.end);
      expect(
        tester.getTopLeft(find.text('Cancel')).dy,
        tester.getTopLeft(find.text('Delete')).dy,
      );
    });

    testWidgets(
      'mounts a BackdropFilter while visible and removes it on close',
      (tester) async {
        final key = GlobalKey();
        await tester.pumpWidget(
          _host(
            Builder(
              key: key,
              builder: (context) => UiButton(
                label: 'open',
                onPressed: () => UiDialogScope.show<void>(
                  context,
                  builder: (_) => const UiDialog(title: 'Hello'),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(BackdropFilter), findsNothing);

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.byType(BackdropFilter), findsOneWidget);
        expect(find.byType(FadeTransition), findsWidgets);
        expect(find.text('Hello'), findsOneWidget);

        final navigator = Navigator.of(
          key.currentContext!,
          rootNavigator: true,
        );
        navigator.maybePop();
        await tester.pumpAndSettle();

        expect(find.byType(BackdropFilter), findsNothing);
      },
    );
  });
}
