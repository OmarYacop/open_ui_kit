import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget host(Widget child, {bool reduced = false, bool dark = false}) => UiApp(
  mode: dark ? UiThemeMode.dark : UiThemeMode.light,
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Center(child: SizedBox(width: 320, height: 400, child: child)),
  ),
);

Widget source({
  bool enabled = true,
  UiDragActivation activation = UiDragActivation.immediate,
}) => UiDraggable<String>(
  data: 'alpha',
  semanticLabel: 'Alpha',
  enabled: enabled,
  activation: activation,
  feedbackBuilder: (_) => const Text('Moving Alpha'),
  child: const SizedBox(
    key: ValueKey('source'),
    height: 60,
    child: Text('Alpha'),
  ),
);

void main() {
  testWidgets('accepted drop commits once and restores source', (tester) async {
    final accepted = <String>[];
    await tester.pumpWidget(
      host(
        Column(
          children: [
            source(),
            const SizedBox(height: 60),
            UiDropRegion<String>(
              semanticLabel: 'Archive',
              onAccept: accepted.add,
              builder: (_, state) => SizedBox(
                key: const ValueKey('target'),
                height: 100,
                child: Text(state.name),
              ),
            ),
          ],
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('source'))),
    );
    await gesture.moveBy(const Offset(0, 15));
    await tester.pump();
    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey('target'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('accepting'), findsOneWidget);
    expect(find.text('Moving Alpha'), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(accepted, ['alpha']);
    expect(find.text('Moving Alpha'), findsNothing);
    expect(find.text('idle'), findsOneWidget);
  });

  testWidgets('reject, disabled source and outside drop never commit', (
    tester,
  ) async {
    for (final enabled in [true, false]) {
      final accepted = <String>[];
      await tester.pumpWidget(
        host(
          Column(
            children: [
              source(enabled: enabled),
              const SizedBox(height: 60),
              UiDropRegion<String>(
                semanticLabel: 'Archive',
                canAccept: (_) => false,
                onAccept: accepted.add,
                builder: (_, state) => SizedBox(
                  key: const ValueKey('target'),
                  height: 100,
                  child: Text(state.name),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.dragFrom(
        tester.getCenter(find.byKey(const ValueKey('source'))),
        const Offset(0, 140),
      );
      await tester.pumpAndSettle();
      expect(accepted, isEmpty);
      expect(find.text('Moving Alpha'), findsNothing);
    }
  });

  testWidgets(
    'adaptive touch preserves scroll while mouse starts immediately',
    (tester) async {
      await tester.pumpWidget(
        host(source(activation: UiDragActivation.adaptive)),
      );
      var gesture = await tester.startGesture(
        tester.getCenter(find.text('Alpha')),
      );
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      expect(find.text('Moving Alpha'), findsNothing);
      await gesture.up();
      gesture = await tester.startGesture(
        tester.getCenter(find.text('Alpha')),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      expect(find.text('Moving Alpha'), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('table default path has no reorder machinery', (tester) async {
    await tester.pumpWidget(
      host(
        const UiDataTable(
          columns: [UiDataColumn(label: 'Name')],
          rows: [
            UiDataRow(cells: [Text('Alpha')]),
          ],
        ),
      ),
    );
    expect(find.byType(ReorderableList), findsNothing);
    expect(find.byType(UiDragHandle), findsNothing);
    expect(find.byType(DragTarget<Object>), findsNothing);
  });

  testWidgets(
    'keyboard moves use final indices, preserve focus and row actions',
    (tester) async {
      final items = ['Alpha', 'Beta', 'Gamma'];
      var taps = 0;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) => UiDataTable(
              columns: const [UiDataColumn(label: 'Name')],
              rows: [
                for (final item in items)
                  UiDataRow(
                    key: ValueKey(item),
                    semanticLabel: item,
                    cells: [Text(item)],
                    onTap: () => taps++,
                  ),
              ],
              onReorder: (from, to) =>
                  setState(() => items.insert(to, items.removeAt(from))),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Alpha'));
      expect(taps, 1);
      final handle = find.byType(UiDragHandle).first;
      Focus.of(
        tester.element(
          find.descendant(of: handle, matching: find.byType(MouseRegion)).first,
        ),
      ).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(items, ['Beta', 'Alpha', 'Gamma']);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(items, ['Beta', 'Gamma', 'Alpha']);
      expect(taps, 1);
    },
  );

  testWidgets('pointer reordering commits final destination', (tester) async {
    final items = ['Alpha', 'Beta', 'Gamma'];
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) => UiReorderableList<String>(
            items: items,
            itemKey: ValueKey.new,
            itemLabel: (item) => item,
            onReorder: (from, to) =>
                setState(() => items.insert(to, items.removeAt(from))),
            itemBuilder: (_, item, index, handle) => SizedBox(
              height: 64,
              child: Row(children: [handle, Text(item)]),
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(UiDragHandle).first),
    );
    await gesture.moveBy(const Offset(0, 10));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 190));
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(items, ['Beta', 'Gamma', 'Alpha']);
  });

  testWidgets('lazy table sorting does not eagerly build cell content', (
    tester,
  ) async {
    var builds = 0;
    await tester.pumpWidget(
      host(
        UiDataTable.lazy(
          columns: const [UiDataColumn(label: 'Name')],
          rowCount: 10000,
          rowBuilder: (_, index) {
            builds++;
            return UiDataRow(cells: [Text('Row $index')]);
          },
          rowKeyBuilder: (index) => ValueKey(index),
          onReorder: (_, _) {},
          maxBodyHeight: 220,
        ),
      ),
    );
    expect(builds, lessThan(30));
    expect(find.byType(UiDragHandle), findsWidgets);
  });

  testWidgets('disabled sorting removes keyboard and semantic move actions', (
    tester,
  ) async {
    var moves = 0;
    await tester.pumpWidget(
      host(
        UiReorderableList<String>(
          items: const ['Alpha', 'Beta'],
          itemKey: ValueKey.new,
          itemLabel: (item) => item,
          enabled: false,
          onReorder: (_, _) => moves++,
          itemBuilder: (_, item, index, handle) =>
              Row(children: [handle, Text(item)]),
        ),
      ),
    );
    final handles = tester.widgetList<Semantics>(
      find.descendant(
        of: find.byType(UiDragHandle),
        matching: find.byType(Semantics),
      ),
    );
    expect(
      handles.every(
        (s) => s.properties.customSemanticsActions?.isEmpty ?? true,
      ),
      isTrue,
    );
    await tester.drag(find.byType(UiDragHandle).first, const Offset(0, 90));
    await tester.pumpAndSettle();
    expect(moves, 0);
  });

  testWidgets('narrow RTL dark surface and reduced motion remain usable', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        Directionality(
          textDirection: TextDirection.rtl,
          child: UiDropRegion<String>(
            semanticLabel: 'Archive',
            onAccept: (_) {},
            builder: (_, state) => const Text('Archive'),
          ),
        ),
        reduced: true,
        dark: true,
      ),
    );
    final container = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(UiDropRegion<String>),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect(container.duration, Duration.zero);
    expect(tester.takeException(), isNull);
  });
  testWidgets('disabling a hovered target prevents its commit', (tester) async {
    var enabled = true;
    late StateSetter update;
    final accepted = <String>[];
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Column(
              children: [
                source(),
                const SizedBox(height: 60),
                UiDropRegion<String>(
                  semanticLabel: 'Archive',
                  enabled: enabled,
                  onAccept: accepted.add,
                  builder: (_, state) => SizedBox(
                    key: const ValueKey('target'),
                    height: 100,
                    child: Text(state.name),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('source'))),
    );
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey('target'))),
    );
    await tester.pump();
    expect(find.text('accepting'), findsOneWidget);
    update(() => enabled = false);
    await tester.pump();
    expect(find.text('disabled'), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(accepted, isEmpty);
  });

  testWidgets('external order changes cancel a drag without stale indices', (
    tester,
  ) async {
    final items = ['Alpha', 'Beta', 'Gamma'];
    late StateSetter update;
    var moves = 0;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return UiReorderableList<String>(
              items: items,
              itemKey: ValueKey.new,
              itemLabel: (item) => item,
              onReorder: (_, _) => moves++,
              itemBuilder: (_, item, index, handle) => SizedBox(
                height: 64,
                child: Row(children: [handle, Text(item)]),
              ),
            );
          },
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(UiDragHandle).first),
    );
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump();
    update(() => items.removeAt(0));
    await tester.pumpAndSettle();
    await gesture.moveBy(const Offset(0, 120));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(moves, 0);
    expect(items, ['Beta', 'Gamma']);
    expect(tester.takeException(), isNull);
  });
  testWidgets('sorting preserves explicit lazy table row extent', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        UiDataTable.lazy(
          columns: const [UiDataColumn(label: 'Name')],
          rowCount: 3,
          rowBuilder: (_, index) => UiDataRow(cells: [Text('Item $index')]),
          rowKeyBuilder: ValueKey.new,
          onReorder: (_, _) {},
          rowExtent: 72,
        ),
      ),
    );
    expect(
      tester.getCenter(find.text('Item 1')).dy -
          tester.getCenter(find.text('Item 0')).dy,
      72,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'drop boundary transitions progress then settle at token duration',
    (tester) async {
      await tester.pumpWidget(
        host(
          Column(
            children: [
              source(),
              const SizedBox(height: 60),
              UiDropRegion<String>(
                semanticLabel: 'Archive',
                onAccept: (_) {},
                builder: (_, state) => SizedBox(
                  key: const ValueKey('target'),
                  height: 100,
                  child: Text(state.name),
                ),
              ),
            ],
          ),
        ),
      );
      BoxDecoration paint() =>
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byType(UiDropRegion<String>),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      final idle = paint().border!.top.color;
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('source'))),
      );
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('target'))),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final midpoint = paint().border!.top.color;
      await tester.pump(const Duration(milliseconds: 60));
      final settled = paint().border!.top.color;
      expect(midpoint, isNot(idle));
      expect(midpoint, isNot(settled));
      expect(settled, UiThemeData.light().colors.primary);
      await gesture.up();
      await tester.pumpAndSettle();
    },
  );
}
