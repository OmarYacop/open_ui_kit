import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget _host(Widget child, {double width = 520}) {
  return MaterialApp(
    theme: UiThemeData.light(),
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, child: child),
      ),
    ),
  );
}

void main() {
  group('UiActionGroupGeometrySolver', () {
    test('horizontal expansion keeps slots contiguous and bounded', () {
      final geometry = UiActionGroupGeometrySolver.solveHorizontal(
        fromItems: const [
          UiActionGroupGeometryItem(id: 'primary', flex: 2),
          UiActionGroupGeometryItem(id: 'toggle', fixedExtent: 92),
        ],
        toItems: const [
          UiActionGroupGeometryItem(id: 'primary'),
          UiActionGroupGeometryItem(id: 'a'),
          UiActionGroupGeometryItem(id: 'b'),
          UiActionGroupGeometryItem(id: 'c'),
          UiActionGroupGeometryItem(id: 'toggle'),
        ],
        maxWidth: 520,
        height: 44,
        spacing: 8,
        progress: 0.48,
      );

      expect(geometry.size.width, 520);
      for (var i = 0; i < geometry.slots.length; i++) {
        final slot = geometry.slots[i];
        expect(slot.rect.left, greaterThanOrEqualTo(0));
        expect(slot.rect.right, lessThanOrEqualTo(520.01));
        if (i > 0) {
          expect(
            slot.rect.left,
            greaterThanOrEqualTo(geometry.slots[i - 1].rect.right),
          );
        }
      }
      expect(geometry.slots.first.rect.left, 0);
      expect(geometry.slots.last.rect.right, closeTo(520, 0.01));
      for (var i = 1; i < geometry.slots.length; i++) {
        final gap =
            geometry.slots[i].rect.left - geometry.slots[i - 1].rect.right;
        expect(gap, greaterThanOrEqualTo(7.99));
      }
    });

    test('horizontal collapse preserves expanded order while slots exit', () {
      final geometry = UiActionGroupGeometrySolver.solveHorizontal(
        fromItems: const [
          UiActionGroupGeometryItem(id: 'primary'),
          UiActionGroupGeometryItem(id: 'secondary'),
          UiActionGroupGeometryItem(id: 'third'),
          UiActionGroupGeometryItem(id: 'toggle'),
        ],
        toItems: const [
          UiActionGroupGeometryItem(id: 'primary', flex: 2),
          UiActionGroupGeometryItem(id: 'toggle', fixedExtent: 92),
        ],
        maxWidth: 520,
        height: 32,
        spacing: 8,
        progress: 0.35,
      );

      final ids = geometry.slots.map((slot) => slot.id).toList();
      expect(ids, orderedEquals(['primary', 'secondary', 'third', 'toggle']));
      for (var i = 1; i < geometry.slots.length; i++) {
        expect(
          geometry.slots[i].rect.left,
          greaterThanOrEqualTo(geometry.slots[i - 1].rect.right),
        );
      }
      expect(geometry.slots.last.rect.right, closeTo(520, 0.01));
    });

    test('horizontal entering content waits for usable slot space', () {
      final geometry = UiActionGroupGeometrySolver.solveHorizontal(
        fromItems: const [
          UiActionGroupGeometryItem(id: 'primary', flex: 2),
          UiActionGroupGeometryItem(id: 'toggle', fixedExtent: 92),
        ],
        toItems: const [
          UiActionGroupGeometryItem(id: 'primary'),
          UiActionGroupGeometryItem(id: 'a'),
          UiActionGroupGeometryItem(id: 'b'),
          UiActionGroupGeometryItem(id: 'c'),
          UiActionGroupGeometryItem(id: 'toggle'),
        ],
        maxWidth: 520,
        height: 44,
        spacing: 8,
        progress: 0.2,
      );

      final entering = geometry.slots.firstWhere((slot) => slot.id == 'a');

      expect(entering.opacity, greaterThan(0));
      expect(entering.contentOpacity, 0);
    });
  });

  group('UiSmartActionGroup', () {
    testWidgets('collapses actions behind a more button and expands inline', (
      tester,
    ) async {
      var selected = '';

      await tester.pumpWidget(
        _host(
          UiSmartActionGroup(
            actions: [
              UiSmartActionGroupAction(
                id: 'enter',
                label: 'Enter',
                onPressed: () => selected = 'enter',
              ),
              UiSmartActionGroupAction(
                id: 'end',
                label: 'End class',
                intent: UiIntent.danger,
                onPressed: () => selected = 'end',
              ),
              UiSmartActionGroupAction(
                id: 'absent',
                label: 'Mark absent',
                intent: UiIntent.neutral,
                onPressed: () => selected = 'absent',
              ),
            ],
          ),
        ),
      );

      expect(find.text('Enter'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
      expect(find.text('End class'), findsNothing);
      expect(find.text('Mark absent'), findsNothing);
      expect(
        tester.getTopLeft(find.text('More')).dx,
        greaterThan(tester.getTopLeft(find.text('Enter')).dx),
      );

      await tester.tap(find.text('More'));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();

      expect(find.text('End class'), findsOneWidget);
      expect(find.text('Mark absent'), findsOneWidget);
      expect(find.text('Less'), findsOneWidget);

      await tester.tap(find.text('Mark absent'));
      await tester.pumpAndSettle();

      expect(selected, 'absent');
      expect(find.text('Less'), findsOneWidget);
      expect(find.text('End class'), findsOneWidget);
    });

    testWidgets('can collapse after action when configured', (tester) async {
      var selected = '';

      await tester.pumpWidget(
        _host(
          UiSmartActionGroup(
            collapseOnAction: true,
            actions: [
              UiSmartActionGroupAction(
                id: 'primary',
                label: 'Primary',
                onPressed: () => selected = 'primary',
              ),
              UiSmartActionGroupAction(
                id: 'secondary',
                label: 'Secondary',
                onPressed: () => selected = 'secondary',
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Secondary'));
      await tester.pumpAndSettle();

      expect(selected, 'secondary');
      expect(find.text('More'), findsOneWidget);
      expect(find.text('Secondary'), findsNothing);
    });

    testWidgets('does not constrain button content during width reveal', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          UiSmartActionGroup(
            duration: const UiMotionDuration.custom(
              Duration(milliseconds: 320),
            ),
            actions: [
              UiSmartActionGroupAction(
                id: 'primary',
                label: 'Primary action',
                onPressed: () {},
              ),
              UiSmartActionGroupAction(
                id: 'secondary',
                label: 'Secondary action',
                intent: UiIntent.neutral,
                onPressed: () {},
              ),
              UiSmartActionGroupAction(
                id: 'danger',
                label: 'Danger action',
                intent: UiIntent.danger,
                onPressed: () {},
              ),
            ],
          ),
          width: 520,
        ),
      );

      await tester.tap(find.text('More'));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'keeps the mechanical renderer overflow-free during wide morphs', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          UiSmartActionGroup(
            duration: const UiMotionDuration.custom(
              Duration(milliseconds: 320),
            ),
            actions: [
              UiSmartActionGroupAction(
                id: 'primary',
                label: 'Primary',
                onPressed: () {},
              ),
              UiSmartActionGroupAction(
                id: 'secondary',
                label: 'Secondary',
                onPressed: () {},
              ),
              UiSmartActionGroupAction(
                id: 'third',
                label: 'Third',
                onPressed: () {},
              ),
            ],
          ),
          width: 520,
        ),
      );

      expect(find.text('Primary'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);

      await tester.tap(find.text('More'));
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.text('Primary'), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.pumpAndSettle();

      expect(find.text('Secondary'), findsOneWidget);
      expect(find.text('Third'), findsOneWidget);
      expect(find.text('Less'), findsOneWidget);
    });

    testWidgets('uses equal expanded slots by default', (tester) async {
      await tester.pumpWidget(
        _host(
          UiSmartActionGroup(
            initiallyExpanded: true,
            actions: [
              UiSmartActionGroupAction(
                id: 'one',
                label: 'One',
                flex: 4,
                expandedFlex: 4,
                onPressed: () {},
              ),
              UiSmartActionGroupAction(
                id: 'two',
                label: 'Two',
                flex: 1,
                expandedFlex: 3,
                onPressed: () {},
              ),
              UiSmartActionGroupAction(
                id: 'three',
                label: 'Three',
                onPressed: () {},
              ),
            ],
          ),
          width: 520,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('One'), findsOneWidget);
      expect(find.text('Two'), findsOneWidget);
      expect(find.text('Three'), findsOneWidget);
      expect(find.text('Less'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('supports controlled expanded state', (tester) async {
      var expanded = false;

      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              return UiSmartActionGroup(
                expanded: expanded,
                onExpandedChanged: (value) => setState(() => expanded = value),
                actions: [
                  UiSmartActionGroupAction(
                    id: 'primary',
                    label: 'Primary',
                    onPressed: () {},
                  ),
                  UiSmartActionGroupAction(
                    id: 'secondary',
                    label: 'Secondary',
                    onPressed: () {},
                  ),
                ],
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();

      expect(expanded, isTrue);
      expect(find.text('Secondary'), findsOneWidget);

      await tester.tap(find.text('Less'));
      await tester.pumpAndSettle();

      expect(expanded, isFalse);
      expect(find.text('Secondary'), findsNothing);
    });

    testWidgets('uses a horizontal scroll fallback in compact widths', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          UiSmartActionGroup(
            initiallyExpanded: true,
            actions: [
              UiSmartActionGroupAction(
                id: 'one',
                label: 'One',
                onPressed: () {},
              ),
              UiSmartActionGroupAction(
                id: 'two',
                label: 'Two',
                onPressed: () {},
              ),
              UiSmartActionGroupAction(
                id: 'three',
                label: 'Three',
                onPressed: () {},
              ),
            ],
          ),
          width: 320,
        ),
      );
      await tester.pumpAndSettle();

      final oneTop = tester.getTopLeft(find.text('One')).dy;
      final twoTop = tester.getTopLeft(find.text('Two')).dy;
      final threeTop = tester.getTopLeft(find.text('Three')).dy;
      final groupHeight =
          tester.getSize(find.byType(UiSmartActionGroup)).height;

      expect(twoTop, oneTop);
      expect(threeTop, oneTop);
      expect(groupHeight, 44);
    });

    testWidgets('keeps compact collapsed actions on one row', (tester) async {
      await tester.pumpWidget(
        _host(
          UiSmartActionGroup(
            actions: [
              UiSmartActionGroupAction(
                id: 'primary',
                label: 'Primary',
                onPressed: () {},
              ),
              UiSmartActionGroupAction(
                id: 'secondary',
                label: 'Secondary',
                onPressed: () {},
              ),
            ],
          ),
          width: 320,
        ),
      );

      final primaryTop = tester.getTopLeft(find.text('Primary')).dy;
      final moreTop = tester.getTopLeft(find.text('More')).dy;
      final groupHeight =
          tester.getSize(find.byType(UiSmartActionGroup)).height;

      expect(moreTop, primaryTop);
      expect(groupHeight, 44);
    });

    testWidgets('paints button surfaces at the solved slot height', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          UiSmartActionGroup(
            actions: [
              UiSmartActionGroupAction(
                id: 'primary',
                label: 'Primary',
                onPressed: () {},
              ),
              UiSmartActionGroupAction(
                id: 'secondary',
                label: 'Secondary',
                onPressed: () {},
              ),
            ],
          ),
          width: 320,
        ),
      );

      final surfaces = find.descendant(
        of: find.byType(UiSmartActionGroup),
        matching: find.byWidgetPredicate((widget) {
          if (widget is! DecoratedBox) return false;
          final decoration = widget.decoration;
          return decoration is BoxDecoration &&
              decoration.color != null &&
              decoration.borderRadius != null;
        }),
      );

      expect(surfaces, findsNWidgets(2));
      for (var i = 0; i < 2; i++) {
        expect(tester.getSize(surfaces.at(i)).height, 44);
      }
    });

    testWidgets('compact expansion stays on one scrollable row', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          UiSmartActionGroup(
            duration: const UiMotionDuration.custom(
              Duration(milliseconds: 320),
            ),
            actions: [
              UiSmartActionGroupAction(
                id: 'primary',
                label: 'Primary',
                onPressed: () {},
              ),
              UiSmartActionGroupAction(
                id: 'secondary',
                label: 'Secondary',
                onPressed: () {},
              ),
              UiSmartActionGroupAction(
                id: 'third',
                label: 'Third',
                onPressed: () {},
              ),
            ],
          ),
          width: 320,
        ),
      );

      await tester.tap(find.text('More'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(
        tester.getTopLeft(find.text('Secondary')).dy,
        tester.getTopLeft(find.text('Primary')).dy,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpAndSettle();

      expect(find.text('Secondary'), findsOneWidget);
      expect(find.text('Third'), findsOneWidget);
      expect(find.text('Less'), findsOneWidget);
      expect(tester.getSize(find.byType(UiSmartActionGroup)).height, 44);
    });
  });

  group('UiConfirmActionGroup', () {
    testWidgets('morphs labels and calls confirm after confirmation', (
      tester,
    ) async {
      var confirmed = false;
      var cancelled = false;
      var secondaryPressed = false;

      await tester.pumpWidget(
        _host(
          UiConfirmActionGroup(
            actionLabel: 'Save',
            confirmLabel: 'Confirm save',
            secondaryLabel: 'Dismiss',
            cancelLabel: 'Cancel',
            onConfirm: () => confirmed = true,
            onCancel: () => cancelled = true,
            onSecondaryPressed: () => secondaryPressed = true,
            duration: const UiMotionDuration.custom(
              Duration(milliseconds: 260),
            ),
          ),
        ),
      );

      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);
      expect(find.text('Confirm save'), findsNothing);

      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();
      expect(secondaryPressed, isTrue);
      expect(confirmed, isFalse);

      await tester.tap(find.text('Save'));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();

      expect(find.text('Confirm save'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(cancelled, isTrue);
      expect(find.text('Save'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm save'));
      await tester.pumpAndSettle();

      expect(confirmed, isTrue);
    });

    testWidgets('supports controlled confirming state', (tester) async {
      var confirming = false;

      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              return UiConfirmActionGroup(
                confirming: confirming,
                onConfirmingChanged: (value) {
                  setState(() => confirming = value);
                },
                actionLabel: 'Delete',
                confirmLabel: 'Confirm delete',
                cancelLabel: 'Cancel',
                onConfirm: () {},
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(confirming, isTrue);
      expect(find.text('Confirm delete'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(confirming, isFalse);
      expect(find.text('Delete'), findsOneWidget);
    });
  });
}
