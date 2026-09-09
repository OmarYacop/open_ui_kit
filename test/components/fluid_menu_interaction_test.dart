import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  testWidgets('More owns whole-stack dismissal and reopening starts fresh', (
    tester,
  ) async {
    await tester.pumpWidget(const UiApp(home: _MenuTestHost()));
    await tester.pumpAndSettle();
    expect(find.text('Organize').hitTestable(), findsNothing);
    await tester.tap(find.byType(UiFluidTrigger));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Organize').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to').hitTestable());
    await tester.pumpAndSettle();
    final children = tester
        .widgetList<UiMenuTransition>(find.byType(UiMenuTransition))
        .toList();
    expect(children, hasLength(2));
    final root = tester.widget<UiFluidMorph>(find.byType(UiFluidMorph));
    await tester.tapAt(const Offset(10, 400));
    await tester.pump();
    expect(root.controller.target, 0);
    for (final child in children) {
      expect(child.controller.target, 1);
    }
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('Personal').hitTestable(), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byType(UiMenuTransition), findsNothing);
    expect(find.byType(UiFluidTrigger).hitTestable(), findsOneWidget);
    await tester.tap(find.byType(UiFluidTrigger));
    await tester.pumpAndSettle();
    expect(find.text('Organize').hitTestable(), findsOneWidget);
    expect(find.byType(UiMenuTransition), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Back navigates one level before closing the root presentation', (
    tester,
  ) async {
    await tester.pumpWidget(const UiApp(home: _MenuTestHost()));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(UiFluidTrigger));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Organize').hitTestable());
    await tester.pumpAndSettle();
    final root = tester.widget<UiFluidMorph>(find.byType(UiFluidMorph));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(root.controller.target, 1);
    expect(find.byType(UiMenuTransition), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(root.controller.value, 0);
    expect(find.byType(UiFluidTrigger).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('tapping a covered menu closes only its descendants', (
    tester,
  ) async {
    await tester.pumpWidget(const UiApp(home: _MenuTestHost()));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(UiFluidTrigger));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Organize').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('More folders').hitTestable());
    await tester.pumpAndSettle();
    final root = tester.widget<UiFluidMorph>(find.byType(UiFluidMorph));
    final pages = tester
        .widgetList<UiMenuTransition>(find.byType(UiMenuTransition))
        .toList();
    expect(pages, hasLength(3));
    // The promoted header is visible above its child, but belongs to a
    // covered page. This tap restores that page, rather than invoking Back.
    await tester.tapAt(tester.getCenter(find.text('Organize')));
    await tester.pump();
    expect(root.controller.target, 1);
    expect(pages[0].controller.target, 1);
    expect(pages[1].controller.target, 0);
    expect(pages[2].controller.target, 0);
    double descendantOpacity() => tester
        .element(find.byType(UiMenuTransition).last)
        .findAncestorWidgetOfExactType<Opacity>()!
        .opacity;
    await tester.pump(const Duration(milliseconds: 30));
    expect(descendantOpacity(), inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 45));
    expect(
      descendantOpacity(),
      0,
      reason:
          'Promoted descendant headers must disappear before ancestor teardown',
    );

    // A root action remains visible while descendants retract. The first
    // tap restores the root and must not also execute New item (which dismisses).
    await tester.tapAt(tester.getCenter(find.text('New item')));
    await tester.pump();
    expect(root.controller.target, 1);
    expect(pages[0].controller.target, 0);
    await tester.pumpAndSettle();
    expect(find.byType(UiMenuTransition), findsNothing);
    expect(find.text('New item').hitTestable(), findsOneWidget);
    await tester.tap(find.text('New item'));
    await tester.pumpAndSettle();
    expect(root.controller.value, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('hold More, dwell into submenu and drag-release selects once', (
    tester,
  ) async {
    await tester.pumpWidget(const UiApp(home: _MenuTestHost()));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(UiFluidTrigger)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    final root = tester.widget<UiFluidMorph>(find.byType(UiFluidMorph));
    expect(root.controller.target, 1);
    await gesture.moveTo(tester.getCenter(find.text('Organize')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(UiMenuTransition), findsNothing);
    await tester.pump(const Duration(milliseconds: 160));
    await tester.pumpAndSettle();
    expect(find.byType(UiMenuTransition), findsOneWidget);
    await gesture.moveTo(tester.getCenter(find.text('Move to')));
    await tester.pump(const Duration(milliseconds: 360));
    await tester.pumpAndSettle();
    expect(find.byType(UiMenuTransition), findsNWidgets(2));
    await gesture.moveTo(tester.getCenter(find.text('Personal')));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(root.controller.value, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'hold without dragging leaves menu open; leaving a row cancels dwell',
    (tester) async {
      await tester.pumpWidget(const UiApp(home: _MenuTestHost()));
      await tester.pumpAndSettle();
      var gesture = await tester.startGesture(
        tester.getCenter(find.byType(UiFluidTrigger)),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.pumpAndSettle();
      final root = tester.widget<UiFluidMorph>(find.byType(UiFluidMorph));
      expect(root.controller.target, 1);
      gesture = await tester.startGesture(
        tester.getCenter(find.text('New item')),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(tester.getCenter(find.text('Organize')));
      await tester.pump(const Duration(milliseconds: 150));
      await gesture.moveTo(const Offset(10, 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(UiMenuTransition), findsNothing);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(root.controller.value, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('drag-release on the title acts as a Back entry', (tester) async {
    await tester.pumpWidget(const UiApp(home: _MenuTestHost()));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(UiFluidTrigger)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    await gesture.moveTo(tester.getCenter(find.text('Organize')));
    await tester.pump(const Duration(milliseconds: 360));
    await tester.pumpAndSettle();
    await gesture.moveTo(tester.getCenter(find.text('Rename')));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.text('Organize')));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(UiMenuTransition), findsNothing);
    expect(
      tester.widget<UiFluidMorph>(find.byType(UiFluidMorph)).controller.target,
      1,
    );
    expect(tester.takeException(), isNull);
  });
}

// Test-only composition for input, layout, and interrupted motion coverage.
class _MenuTestHost extends StatefulWidget {
  const _MenuTestHost();

  @override
  State<_MenuTestHost> createState() => __MenuTestHostState();
}

class __MenuTestHostState extends State<_MenuTestHost>
    with SingleTickerProviderStateMixin {
  late final _root = UiFluidController(vsync: this);

  @override
  void dispose() {
    _root.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UiPageScaffold(
    scrollFade: false,
    topBar: const Padding(
      padding: EdgeInsets.all(16),
      child: UiText('Stacked menus', variant: UiTextVariant.heading),
    ),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 360,
                  maxHeight: 420,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) => UiMenuStack(
                    rootController: _root,
                    rootSourceGeometry: UiFluidGeometry(
                      Rect.fromLTWH(constraints.maxWidth - 102, 12, 90, 48),
                      24,
                    ),
                    rootTrigger: UiFluidTrigger(
                      directOpen: true,
                      controller: _root,
                      label: 'More',
                      child: const Center(child: UiText('More')),
                    ),
                    title: 'Actions',
                    items: [
                      UiMenuItem(label: 'New item', onPressed: () {}),
                      UiMenuSubmenu(
                        label: 'Organize',
                        items: [
                          UiMenuItem(label: 'Rename', onPressed: () {}),
                          UiMenuSubmenu(
                            label: 'Move to',
                            items: [
                              UiMenuItem(label: 'Personal', onPressed: () {}),
                              UiMenuItem(label: 'Work', onPressed: () {}),
                              UiMenuSubmenu(
                                label: 'More folders',
                                items: [
                                  UiMenuItem(
                                    label: 'Archive',
                                    onPressed: () {},
                                  ),
                                  UiMenuItem(label: 'Ideas', onPressed: () {}),
                                ],
                              ),
                            ],
                          ),
                          UiMenuItem(label: 'Duplicate', onPressed: () {}),
                        ],
                      ),
                      UiMenuSubmenu(
                        label: 'Share',
                        items: [
                          UiMenuItem(label: 'Copy link', onPressed: () {}),
                          const UiMenuItem(
                            label: 'Invite people',
                            enabled: false,
                          ),
                        ],
                      ),
                      const UiMenuSeparator(),
                      UiMenuItem(
                        label: 'Delete',
                        destructive: true,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
