import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  testWidgets(
    'hidden dual pane rebuilds across rotation under an open drawer',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final controller = UiDualPaneController<String>();
      addTearDown(controller.dispose);
      var index = 0;
      late StateSetter update;
      await tester.pumpWidget(
        UiApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return UiBottomTabScaffold(
                currentIndex: index,
                onChanged: (_) {},
                items: const [
                  UiBottomTabItem(label: 'Chats', icon: Icon(IconData(0xe001))),
                  UiBottomTabItem(
                    label: 'Classes',
                    icon: Icon(IconData(0xe002)),
                  ),
                ],
                pages: [
                  UiDualPane<String>(
                    controller: controller,
                    tabletMode: UiDualPaneTabletMode.overlayDetail,
                    primaryBuilder: (context, selected, select) => Column(
                      children: [
                        Text('Chats $selected ${MediaQuery.sizeOf(context)}'),
                        const Expanded(child: SizedBox.expand()),
                      ],
                    ),
                    detailBuilder: (_, selected, _) =>
                        Text(selected ?? 'Empty'),
                  ),
                  Builder(
                    builder: (context) => UiButton(
                      label: 'Filters',
                      onPressed: () => UiDrawerScope.show<void>(
                        context,
                        variant: UiDrawerVariant.stacked,
                        builder: (_) => const UiDrawer(
                          header: UiDrawerHeader(title: 'Filters drawer'),
                          body: Text('Filters'),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      update(() => index = 1);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      controller.select('First');
      await tester.pump();
      controller.select('Second');
      await tester.pump();
      expect(tester.takeException(), isNull);
      for (final size in [
        const Size(844, 390),
        const Size(390, 844),
        const Size(1000, 700),
        const Size(390, 844),
      ]) {
        tester.view.physicalSize = size;
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Filters drawer'), findsOneWidget);
      }
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      update(() => index = 0);
      await tester.pumpAndSettle();
      expect(controller.selected, 'Second');
      expect(find.text('Chats Second Size(390.0, 844.0)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
