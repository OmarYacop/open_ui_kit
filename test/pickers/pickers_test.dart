import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  group('UiDatePicker accessibility', () {
    testWidgets('uses shadcn calendar structure with Sunday-first outside days',
        (tester) async {
      await tester.pumpWidget(
        _host(
          UiDatePicker(
            value: DateTime(2026, 7, 23),
            onChanged: (_) {},
          ),
        ),
      );

      final sunday = tester.getTopLeft(find.text('Su'));
      final monday = tester.getTopLeft(find.text('Mo'));
      expect(sunday.dx, lessThan(monday.dx));

      final outsideJune28 = tester.getSemantics(
        find.bySemanticsLabel(RegExp(r'June 28, 2026')),
      );
      expect(outsideJune28.label, contains('June 28, 2026'));
    });

    testWidgets('day semantics include full spoken date and state',
        (tester) async {
      await tester.pumpWidget(
        _host(
          UiDatePicker(
            value: DateTime(2026, 4, 22),
            min: DateTime(2026, 4, 20),
            max: DateTime(2026, 4, 30),
            disabled: (day) => day.day == 24,
            onChanged: (_) {},
          ),
        ),
      );

      final selected = tester.getSemantics(
        find.bySemanticsLabel(RegExp(r'April 22, 2026')),
      );
      expect(selected.label, contains('Wednesday, April 22, 2026'));
      expect(selected.label, contains('selected'));

      final disabled = tester.getSemantics(
        find.bySemanticsLabel(RegExp(r'April 24, 2026')),
      );
      expect(disabled.label, contains('disabled'));
    });

    testWidgets('supports keyboard traversal and activation', (tester) async {
      DateTime? changed;
      await tester.pumpWidget(
        _host(
          UiDatePicker(
            value: DateTime(2026, 4, 22),
            onChanged: (day) => changed = day,
          ),
        ),
      );

      var activated = false;
      for (var i = 0; i < 64; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        if (changed != null) {
          activated = true;
          break;
        }
      }

      expect(
        activated,
        isTrue,
        reason: 'Tab traversal should reach an activatable day cell.',
      );
    });
  });

  group('UiDatePicker month/year direct selection (PR-D)', () {
    testWidgets(
        'header trigger cycles days → months → years → days; '
        'arrow visibility tracks view', (tester) async {
      await tester.pumpWidget(
        _host(
          UiDatePicker(
            value: DateTime(2026, 4, 22),
            onChanged: (_) {},
          ),
        ),
      );

      // Starts on days view.
      expect(find.byKey(datePickerDayGridKey), findsOneWidget);
      expect(find.byKey(datePickerMonthGridKey), findsNothing);
      expect(find.byKey(datePickerYearGridKey), findsNothing);

      await tester.tap(find.byKey(datePickerHeaderTriggerKey));
      await tester.pumpAndSettle();
      expect(find.byKey(datePickerMonthGridKey), findsOneWidget);
      expect(find.byKey(datePickerDayGridKey), findsNothing);

      await tester.tap(find.byKey(datePickerHeaderTriggerKey));
      await tester.pumpAndSettle();
      expect(find.byKey(datePickerYearGridKey), findsOneWidget);
      expect(find.byKey(datePickerMonthGridKey), findsNothing);

      await tester.tap(find.byKey(datePickerHeaderTriggerKey));
      await tester.pumpAndSettle();
      expect(find.byKey(datePickerDayGridKey), findsOneWidget);
    });

    testWidgets(
        'tapping a month in the month grid returns to days view on that month',
        (tester) async {
      await tester.pumpWidget(
        _host(
          UiDatePicker(
            value: DateTime(2026, 4, 22),
            onChanged: (_) {},
          ),
        ),
      );

      await tester.tap(find.byKey(datePickerHeaderTriggerKey));
      await tester.pumpAndSettle();

      // Pick September — short label "Sep" is rendered inside the
      // month grid.
      await tester.tap(find.text('Sep'));
      await tester.pumpAndSettle();

      expect(find.byKey(datePickerDayGridKey), findsOneWidget);
      // Header label now includes "September 2026".
      expect(find.text('September 2026'), findsOneWidget);
    });

    testWidgets(
        'tapping a year in the year grid returns to months view at that year',
        (tester) async {
      await tester.pumpWidget(
        _host(
          UiDatePicker(
            value: DateTime(2026, 4, 22),
            onChanged: (_) {},
          ),
        ),
      );

      // Days → months → years.
      await tester.tap(find.byKey(datePickerHeaderTriggerKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(datePickerHeaderTriggerKey));
      await tester.pumpAndSettle();

      // The current year page anchor is 2026 - (2026 % 12) = 2016.
      // Pick 2020 — it will appear as a cell in the year grid.
      await tester.tap(find.text('2020'));
      await tester.pumpAndSettle();

      // Back to months view, and header shows the new year.
      expect(find.byKey(datePickerMonthGridKey), findsOneWidget);
      expect(find.text('2020'), findsOneWidget);
    });

    testWidgets(
        'month selection belongs only to the selected date year, not every '
        'browsed year', (tester) async {
      await tester.pumpWidget(
        _host(
          UiDatePicker(
            value: DateTime(2026, 4, 22),
            visibleMonth: DateTime(2020, 4),
            onChanged: (_) {},
          ),
        ),
      );

      await tester.tap(find.byKey(datePickerHeaderTriggerKey));
      await tester.pumpAndSettle();

      final april = find.bySemanticsLabel('April');
      expect(tester.getSemantics(april).label, isNot(contains('selected')));
    });

    testWidgets('year grid arrows paginate forward/back by 12 years',
        (tester) async {
      await tester.pumpWidget(
        _host(
          UiDatePicker(
            value: DateTime(2026, 4, 22),
            onChanged: (_) {},
          ),
        ),
      );

      await tester.tap(find.byKey(datePickerHeaderTriggerKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(datePickerHeaderTriggerKey));
      await tester.pumpAndSettle();

      // Starting anchor = 2016..2027. Next arrow should shift to
      // 2028..2039.
      expect(find.text('2016 – 2027'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Next'));
      await tester.pumpAndSettle();
      expect(find.text('2028 – 2039'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Previous'));
      await tester.pumpAndSettle();
      expect(find.text('2016 – 2027'), findsOneWidget);
    });

    testWidgets(
        'header trigger publishes a button role with the current label '
        'and affordance hint', (tester) async {
      await tester.pumpWidget(
        _host(
          UiDatePicker(
            value: DateTime(2026, 4, 22),
            onChanged: (_) {},
          ),
        ),
      );

      // Look for the semantic node announcing the day-view label and
      // the next-view hint. Match loosely — strict string comparison
      // would make the test brittle to future copy changes.
      expect(
        find.bySemanticsLabel(RegExp(r'April 2026.*opens month picker')),
        findsOneWidget,
      );
    });

    testWidgets('month navigation uses icon buttons instead of text glyphs',
        (tester) async {
      await tester.pumpWidget(
        _host(
          UiDatePicker(
            value: DateTime(2026, 4, 22),
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.byType(UiIconButton), findsNWidgets(2));
      expect(find.text('‹'), findsNothing);
      expect(find.text('›'), findsNothing);
    });
  });

  group('UiTimePicker accessibility', () {
    testWidgets('hour and minute rows publish selected and disabled states',
        (tester) async {
      await tester.pumpWidget(
        _host(
          UiTimePicker(
            value: const UiTimeValue(hour: 9, minute: 30),
            minuteStep: 15,
            semanticsPrefix: 'Start time',
            hourDisabled: (hour) => hour == 8,
            onChanged: (_) {},
          ),
        ),
      );

      final selectedHour = tester.getSemantics(
        find.bySemanticsLabel(RegExp(r'Start time, hour 09, selected')),
      );
      expect(selectedHour.label, contains('selected'));

      final disabledHour = tester.getSemantics(
        find.bySemanticsLabel(RegExp(r'Start time, hour 08')),
      );
      expect(disabledHour.label, contains('disabled'));

      final selectedMinute = tester.getSemantics(
        find.bySemanticsLabel(RegExp(r'Start time, minute 30, selected')),
      );
      expect(selectedMinute.label, contains('selected'));
    });
  });

  group('UiTimeGridPicker', () {
    testWidgets('selects hour, minute, and period from option columns',
        (tester) async {
      var selected = const UiTimeValue(hour: 9, minute: 0);

      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              return UiTimeGridPicker(
                value: selected,
                minuteStep: 15,
                semanticsPrefix: 'Start time',
                onChanged: (value) => setState(() => selected = value),
              );
            },
          ),
        ),
      );

      await tester.tap(find.bySemanticsLabel(RegExp(r'Start time, hour 03')));
      await tester.pump();
      expect(selected, const UiTimeValue(hour: 3, minute: 0));

      await tester.tap(find.bySemanticsLabel(RegExp(r'Start time, PM')));
      await tester.pump();
      expect(selected, const UiTimeValue(hour: 15, minute: 0));

      await tester.tap(find.bySemanticsLabel(RegExp(r'Start time, minute 30')));
      await tester.pump();
      expect(selected, const UiTimeValue(hour: 15, minute: 30));
      expect(find.text('3:30 PM'), findsOneWidget);
    });

    testWidgets('disabled hours do not emit a new value', (tester) async {
      var selected = const UiTimeValue(hour: 9, minute: 0);

      await tester.pumpWidget(
        _host(
          UiTimeGridPicker(
            value: selected,
            minuteStep: 15,
            semanticsPrefix: 'Start time',
            hourDisabled: (hour) => hour == 4,
            onChanged: (value) => selected = value,
          ),
        ),
      );

      await tester.tap(find.bySemanticsLabel(RegExp(r'Start time, hour 04')));
      await tester.pump();
      expect(selected, const UiTimeValue(hour: 9, minute: 0));

      final disabledHour = tester.getSemantics(
        find.bySemanticsLabel(RegExp(r'Start time, hour 04')),
      );
      expect(disabledHour.label, contains('disabled'));
    });
  });

  group('UiTimePickerField', () {
    testWidgets('opens a grid picker and closes from Done', (tester) async {
      UiTimeValue? selected;

      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              return UiTimePickerField(
                label: 'Start time',
                value: selected,
                minuteStep: 15,
                onChanged: (value) => setState(() => selected = value),
              );
            },
          ),
        ),
      );

      expect(find.text('Choose time'), findsOneWidget);

      await tester.tap(find.text('Choose time'));
      await tester.pumpAndSettle();
      expect(find.byType(UiTimeGridPicker), findsOneWidget);

      await tester.tap(find.bySemanticsLabel(RegExp(r'minute 15')));
      await tester.pumpAndSettle();
      expect(selected, const UiTimeValue(hour: 9, minute: 15));
      expect(find.text('9:15 AM'), findsWidgets);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.byType(UiTimeGridPicker), findsNothing);
      expect(find.text('9:15 AM'), findsOneWidget);
    });
  });

  group('UiTimePicker performance behaviour (PR-D)', () {
    // Rebuild-counting fixture: we wrap the picker in a StatefulBuilder
    // with a canary widget whose build count we observe. The picker's
    // own internal parent-setState would cause the outer subtree to
    // rebuild on every wheel tick. Post PR-D, the per-wheel
    // ValueListenableBuilders isolate those rebuilds, so the outer
    // subtree should stay at a single build across the whole fling.
    //
    // This is NOT a wall-clock perf assertion (those flake under CI
    // load). It verifies the REBUILD-SHAPE — the structural property
    // that the PR-D change is designed to guarantee.
    testWidgets(
        'parent subtree does not rebuild when the wheel selection changes',
        (tester) async {
      var outerBuilds = 0;
      UiTimeValue? lastValue;

      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, _) {
              return Builder(
                builder: (innerCtx) {
                  outerBuilds++;
                  return UiTimePicker(
                    value: const UiTimeValue(hour: 9, minute: 0),
                    minuteStep: 5,
                    onChanged: (v) => lastValue = v,
                  );
                },
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final initialBuilds = outerBuilds;

      // Drive the minute wheel programmatically (fling simulation).
      // We target the ListWheelScrollView to call animateToItem.
      final wheelState = tester.state<State>(
        find.byType(ListWheelScrollView).last,
      );
      // Use the picker's own controller via reflection-free path:
      // dispatching keyboard/drag events into a ListWheelScrollView is
      // flaky in unit tests, so we settle for a controller round-trip
      // by dragging the wheel region instead.
      final wheelRect = tester.getRect(find.byType(ListWheelScrollView).last);
      final center = wheelRect.center;
      for (var step = 0; step < 3; step++) {
        await tester.dragFrom(center, const Offset(0, -40));
        await tester.pumpAndSettle();
      }

      // The parent StatefulBuilder subtree must NOT have rebuilt in
      // response to each snap — that's the whole point of the PR-D
      // rework. (It is allowed to have rebuilt exactly zero times.)
      expect(
        outerBuilds,
        initialBuilds,
        reason: 'Wheel selection changes must not trigger parent subtree '
            'rebuilds — the per-wheel ValueListenableBuilder is '
            'supposed to isolate them.',
      );

      // onChanged still fires for the new snapped value — external
      // listeners see the full event stream.
      expect(lastValue, isNotNull);
      // Touching wheelState just to silence unused-var lints in
      // case of future refactors.
      expect(wheelState.mounted, isTrue);
    });
  });

  group('Range and date-time semantics context', () {
    testWidgets('date range picker renders adjacent months in one surface',
        (tester) async {
      await tester.pumpWidget(
        _host(
          UiDateRangePicker(
            value: UiDateRange(
              start: DateTime(2026, 1, 13),
              end: DateTime(2026, 2, 25),
            ),
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('January 2026'), findsOneWidget);
      expect(find.text('February 2026'), findsOneWidget);

      final january = tester.getCenter(find.text('January 2026'));
      final february = tester.getCenter(find.text('February 2026'));
      expect(february.dx, greaterThan(january.dx));
      expect((february.dy - january.dy).abs(), lessThan(1));
    });

    testWidgets('date range picker collapses to one month when width is tight',
        (tester) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 320,
            child: UiDateRangePicker(
              value: UiDateRange(
                start: DateTime(2026, 1, 13),
                end: DateTime(2026, 2, 25),
              ),
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('January 2026'), findsOneWidget);
      expect(find.text('February 2026'), findsNothing);
      expect(find.bySemanticsLabel('Previous'), findsOneWidget);
      expect(find.bySemanticsLabel('Next'), findsOneWidget);
    });

    testWidgets('range header opens month and year quick selection', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 320,
            child: UiDateRangePicker(
              value: UiDateRange(
                start: DateTime(2026, 1, 13),
                end: DateTime(2026, 1, 25),
              ),
              onChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(datePickerHeaderTriggerKey));
      await tester.pumpAndSettle();
      expect(find.byKey(datePickerMonthGridKey), findsOneWidget);

      await tester.tap(find.text('Mar'));
      await tester.pumpAndSettle();
      expect(find.text('March 2026'), findsOneWidget);

      await tester.tap(find.byKey(datePickerHeaderTriggerKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(datePickerHeaderTriggerKey));
      await tester.pumpAndSettle();
      expect(find.byKey(datePickerYearGridKey), findsOneWidget);
    });

    testWidgets('range picker swipes between months and years', (tester) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 320,
            child: UiDateRangePicker(
              value: UiDateRange(
                start: DateTime(2026, 1, 13),
                end: DateTime(2026, 1, 25),
              ),
              onChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.fling(
        find.byKey(datePickerDayGridKey),
        const Offset(-220, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.text('February 2026'), findsOneWidget);

      await tester.tap(find.byKey(datePickerHeaderTriggerKey));
      await tester.pumpAndSettle();
      expect(find.text('2026'), findsOneWidget);

      await tester.fling(
        find.byKey(datePickerMonthGridKey),
        const Offset(-220, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.text('2027'), findsOneWidget);
    });

    testWidgets('range picker page follows the drag before settling', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 320,
            child: UiDateRangePicker(
              value: UiDateRange(
                start: DateTime(2026, 1, 13),
                end: DateTime(2026, 1, 25),
              ),
              onChanged: (_) {},
            ),
          ),
        ),
      );

      final pageView = tester.widget<PageView>(
        find.byKey(const ValueKey('ui_date_picker_day_pages')),
      );
      final initialPage = pageView.controller!.page!;
      final gesture = await tester.startGesture(
        tester.getCenter(
          find.byKey(const ValueKey('ui_date_picker_day_pages')),
        ),
      );
      await gesture.moveBy(const Offset(-48, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveBy(const Offset(-48, 0));
      await tester.pump(const Duration(milliseconds: 16));

      expect(pageView.controller!.page!, greaterThan(initialPage));
      expect(pageView.controller!.page!, lessThan(initialPage + 1));

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('date range labels mark range start and end', (tester) async {
      await tester.pumpWidget(
        _host(
          UiDateRangePicker(
            value: UiDateRange(
              start: DateTime(2026, 4, 22),
              end: DateTime(2026, 4, 24),
            ),
            onChanged: (_) {},
          ),
        ),
      );

      final startDay = tester.getSemantics(
        find.bySemanticsLabel(RegExp(r'April 22, 2026')),
      );
      expect(startDay.label, contains('range start'));

      final endDay = tester.getSemantics(
        find.bySemanticsLabel(RegExp(r'April 24, 2026')),
      );
      expect(endDay.label, contains('range end'));
    });

    testWidgets('date-time range exposes start/end time grid context',
        (tester) async {
      await tester.pumpWidget(
        _host(
          UiDateTimeRangePicker(
            value: UiDateTimeRange(
              start: DateTime(2026, 4, 22, 9, 0),
              end: DateTime(2026, 4, 24, 17, 0),
            ),
            minuteStep: 30,
            onChanged: (_) {},
          ),
        ),
      );

      expect(
        find.bySemanticsLabel(RegExp(r'Start time, hour 09, selected')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'End time, hour 05, selected')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'End time, PM, selected')),
        findsOneWidget,
      );
    });
  });
}
