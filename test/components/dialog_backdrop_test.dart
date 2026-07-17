import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget _host(Widget child) => MaterialApp(
      theme: UiThemeData.light(),
      home: Scaffold(body: child),
    );

void main() {
  group('UiDialog backdrop', () {
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
