import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget _host(Widget child, {Size size = const Size(390, 844)}) {
  return MaterialApp(
    theme: UiThemeData.light(),
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(
        body: child,
        bottomNavigationBar: const Text('shell bottom bar'),
      ),
    ),
  );
}

void main() {
  testWidgets('phone pushes detail above shell chrome', (
    tester,
  ) async {
    final controller = UiDualPaneController<String>();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        UiDualPane<String>(
          controller: controller,
          primaryBuilder: (context, selected, select) {
            return UiButton(label: 'Open detail', onPressed: () => select('a'));
          },
          detailBuilder: (context, selected, select) {
            return Column(
              children: [
                Text('detail:$selected'),
                UiButton(label: 'Back', onPressed: () => select(null)),
              ],
            );
          },
        ),
      ),
    );

    expect(find.text('Open detail'), findsOneWidget);
    expect(find.text('shell bottom bar'), findsOneWidget);
    expect(find.text('detail:a'), findsNothing);

    await tester.tap(find.text('Open detail'));
    await tester.pumpAndSettle();

    expect(find.text('detail:a'), findsOneWidget);
    expect(find.text('shell bottom bar'), findsNothing);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Open detail'), findsOneWidget);
    expect(find.text('shell bottom bar'), findsOneWidget);
  });

  testWidgets('wide form factor shows both panes', (tester) async {
    final controller = UiDualPaneController<String>(selected: 'a');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        UiDualPane<String>(
          controller: controller,
          primaryBuilder: (context, selected, select) => const Text('primary'),
          detailBuilder: (context, selected, select) =>
              Text('detail:$selected'),
        ),
        size: const Size(1000, 800),
      ),
    );

    expect(find.text('primary'), findsOneWidget);
    expect(find.text('detail:a'), findsOneWidget);
  });
}
