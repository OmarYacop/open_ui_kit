import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/components/calendar.dart';
import 'package:open_ui_kit/foundation.dart';

void main() {
  Widget host(Widget child) => Directionality(
    textDirection: TextDirection.ltr,
    child: UiTheme(tokens: UiThemeTokens.light, child: child),
  );

  testWidgets('lays overlapping events into separate columns', (tester) async {
    final day = DateTime(2026, 8, 2);
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 430,
          child: UiCalendarTimeGrid(
            days: [day],
            startHour: 12,
            endHour: 16,
            now: DateTime(2026, 8, 2, 15, 2),
            timeLabelBuilder: (hour) => '$hour:00',
            dayHeaderBuilder: (_, day, __) => Text('${day.day}'),
            events: [
              UiCalendarEvent(
                id: 'a',
                title: 'Arabic',
                startAt: DateTime(2026, 8, 2, 13),
                endAt: DateTime(2026, 8, 2, 14),
              ),
              UiCalendarEvent(
                id: 'b',
                title: 'Quran',
                startAt: DateTime(2026, 8, 2, 13, 15),
                endAt: DateTime(2026, 8, 2, 14, 15),
              ),
            ],
          ),
        ),
      ),
    );

    final arabic = find.text('Arabic');
    final quran = find.text('Quran');
    expect(arabic, findsOneWidget);
    expect(quran, findsOneWidget);
    expect(tester.getTopLeft(arabic).dx, isNot(tester.getTopLeft(quran).dx));
    expect(find.text('3:02'), findsOneWidget);
  });

  testWidgets('reports event selection through the public component', (
    tester,
  ) async {
    UiCalendarEvent? selected;
    final event = UiCalendarEvent(
      id: 'course-1',
      title: 'Tajweed',
      startAt: DateTime(2026, 8, 2, 13),
      endAt: DateTime(2026, 8, 2, 14),
    );
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 430,
          child: UiCalendarTimeGrid(
            days: [DateTime(2026, 8, 2)],
            events: [event],
            startHour: 12,
            endHour: 15,
            timeLabelBuilder: (hour) => '$hour:00',
            dayHeaderBuilder: (_, day, __) => Text('${day.day}'),
            onEventPressed: (event) => selected = event,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Tajweed'));
    expect(selected, same(event));
  });
}
