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

  testWidgets('tablet overlay mode preserves primary and focuses detail', (
    tester,
  ) async {
    final controller = UiDualPaneController<String>();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        UiDualPane<String>(
          controller: controller,
          tabletMode: UiDualPaneTabletMode.overlayDetail,
          primaryBuilder: (context, selected, select) =>
              UiButton(label: 'Open detail', onPressed: () => select('a')),
          detailBuilder: (context, selected, select) => Column(
            children: [
              Text('detail:$selected'),
              UiButton(label: 'Close detail', onPressed: () => select(null)),
            ],
          ),
        ),
        size: const Size(700, 1000),
      ),
    );

    await tester.tap(find.text('Open detail'));
    await tester.pumpAndSettle();

    expect(find.text('Open detail'), findsOneWidget);
    expect(find.text('detail:a'), findsOneWidget);

    await tester.tap(find.text('Close detail'));
    await tester.pump();
    expect(
      find.text('detail:a'),
      findsOneWidget,
      reason: 'Overlay detail should remain mounted during reverse motion.',
    );
    await tester.pumpAndSettle();
    expect(find.text('detail:a'), findsNothing);
  });

  testWidgets('wide detail can stay collapsed until selection', (tester) async {
    final controller = UiDualPaneController<String>();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        UiDualPane<String>(
          controller: controller,
          collapseDetailWithoutSelection: true,
          primaryBuilder: (context, selected, select) =>
              UiButton(label: 'Open detail', onPressed: () => select('a')),
          detailBuilder: (context, selected, select) =>
              Text('detail:$selected'),
        ),
        size: const Size(1200, 800),
      ),
    );

    expect(find.text('detail:null'), findsNothing);
    expect(
      find.byKey(const ValueKey('ui-dual-pane-wide-primary-only')),
      findsOneWidget,
    );
    final initialPrimaryWidth = tester
        .getSize(
          find.byKey(const ValueKey('ui-dual-pane-wide-primary-only')),
        )
        .width;

    await tester.tap(find.text('Open detail'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    final animatingPrimaryWidth = tester
        .getSize(
          find.byKey(const ValueKey('ui-dual-pane-wide-primary')),
        )
        .width;
    expect(animatingPrimaryWidth, lessThan(initialPrimaryWidth));

    await tester.pumpAndSettle();

    expect(find.text('detail:a'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ui-dual-pane-wide-primary-only')),
      findsNothing,
    );
    final settledPrimaryWidth = tester
        .getSize(
          find.byKey(const ValueKey('ui-dual-pane-wide-primary')),
        )
        .width;
    final settledDetailWidth = tester
        .getSize(
          find.byKey(const ValueKey('ui-dual-pane-wide-detail')),
        )
        .width;
    expect(animatingPrimaryWidth, greaterThan(settledPrimaryWidth));
    expect(settledDetailWidth, greaterThan(settledPrimaryWidth));

    controller.clear();
    await tester.pump();

    expect(
      find.text('detail:a'),
      findsOneWidget,
      reason: 'The detail remains mounted while its reverse transition runs.',
    );

    await tester.pumpAndSettle();
    expect(find.text('detail:a'), findsNothing);
    expect(
      find.byKey(const ValueKey('ui-dual-pane-wide-primary-only')),
      findsOneWidget,
    );
  });
}
