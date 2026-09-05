import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('groups and sorts events by UTC day', (tester) async {
    await tester.pumpWidget(
      _host(
        UiTimeline(
          now: DateTime.utc(2026, 8, 3, 12),
          timeLabelBuilder: (date) => 'T${date.hour}',
          events: [
            UiTimelineEvent(
              id: 1,
              at: DateTime.utc(2026, 8, 2, 9),
              title: 'Older event',
            ),
            UiTimelineEvent(
              id: 2,
              at: DateTime.utc(2026, 8, 3, 14),
              title: 'Newest event',
            ),
            UiTimelineEvent(
              id: 3,
              at: DateTime.utc(2026, 8, 3, 10),
              title: 'Earlier today',
            ),
          ],
        ),
      ),
    );

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('T14'), findsOneWidget);

    final newestY = tester.getTopLeft(find.text('Newest event')).dy;
    final earlierY = tester.getTopLeft(find.text('Earlier today')).dy;
    final olderY = tester.getTopLeft(find.text('Older event')).dy;
    expect(newestY, lessThan(earlierY));
    expect(earlierY, lessThan(olderY));
  });

  testWidgets('renders actor, changes, tags, message, and description', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        UiTimeline(
          dateLabelBuilder: (_) => 'Activity day',
          timeLabelBuilder: (_) => '09:30',
          events: [
            UiTimelineEvent(
              id: 'updated',
              at: DateTime.utc(2026, 8, 3, 9, 30),
              title: 'Amina Hassan changed the status',
              actor: const UiTimelineActor(
                name: 'Amina Hassan',
                initials: 'AH',
              ),
              changes: const [UiTimelineChange(from: 'Open', to: 'Resolved')],
              tags: const [UiTimelineTag(label: 'Support')],
              messageTitle: 'Customer note',
              messageBody: 'Everything is working again.',
              description: 'Updated from the ticket workspace.',
            ),
          ],
        ),
      ),
    );

    expect(find.text('Amina Hassan'), findsOneWidget);
    expect(find.text('changed the status'), findsOneWidget);
    expect(find.text('Amina Hassan changed the status'), findsNothing);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Resolved'), findsOneWidget);
    expect(find.text('Support'), findsOneWidget);
    expect(find.text('Customer note'), findsOneWidget);
    expect(find.text('Everything is working again.'), findsOneWidget);
    expect(find.text('Updated from the ticket workspace.'), findsOneWidget);
  });

  testWidgets('loads remaining events for the selected UTC day', (
    tester,
  ) async {
    String? requestedDay;
    await tester.pumpWidget(
      _host(
        UiTimeline(
          dateLabelBuilder: (_) => 'Day',
          events: [
            UiTimelineEvent(
              id: 1,
              at: DateTime.utc(2026, 8, 3, 23),
              title: 'Visible event',
            ),
          ],
          dayTotals: const {'2026-08-03': 4},
          loadMoreLabelBuilder: (remaining) => 'Show $remaining older events',
          onLoadMore: (day) => requestedDay = day,
        ),
      ),
    );

    expect(find.text('Show 3 older events'), findsOneWidget);
    await tester.tap(find.text('Show 3 older events'));
    await tester.pump();
    expect(requestedDay, '2026-08-03');
  });

  testWidgets('renders an accessible empty state', (tester) async {
    await tester.pumpWidget(
      _host(const UiTimeline(events: [], emptyText: 'Nothing happened yet.')),
    );

    expect(find.text('Nothing happened yet.'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(UiTimeline)),
      matchesSemantics(
        label: 'Nothing happened yet.',
        textDirection: TextDirection.ltr,
      ),
    );
  });

  testWidgets('adapts to narrow RTL layouts with large text', (tester) async {
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 240,
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: UiTimeline(
                dateLabelBuilder: (_) => 'اليوم',
                timeLabelBuilder: (_) => '09:30',
                defaultMessageTitle: 'رسالة',
                events: [
                  UiTimelineEvent(
                    id: 1,
                    at: DateTime.utc(2026, 8, 3, 9, 30),
                    title: 'تم تحديث حالة الطلب إلى مكتمل',
                    messageBody: 'تمت معالجة الطلب بنجاح.',
                    changes: const [
                      UiTimelineChange(from: 'مفتوح', to: 'مكتمل'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('رسالة'), findsOneWidget);
    expect(find.text('09:30'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading a day disables its load-more action', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _host(
        UiTimeline(
          dateLabelBuilder: (_) => 'Day',
          events: [
            UiTimelineEvent(
              id: 1,
              at: DateTime.utc(2026, 8, 3),
              title: 'Event',
            ),
          ],
          dayTotals: const {'2026-08-03': 2},
          loadingDay: '2026-08-03',
          onLoadMore: (_) => calls += 1,
        ),
      ),
    );

    await tester.tap(find.byType(UiButton));
    await tester.pump();
    expect(calls, 0);
  });

  testWidgets('aligns multi-field changes and renders missing values', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 400,
          child: UiTimeline(
            dateLabelBuilder: (_) => 'Jul 29, 2026',
            timeLabelBuilder: (_) => '10:12 AM',
            events: [
              UiTimelineEvent(
                id: 'created',
                at: DateTime.utc(2026, 7, 29, 10, 12),
                title: 'Created',
                changes: const [
                  UiTimelineChange(label: 'Student Date', to: '2026-08-03'),
                  UiTimelineChange(label: 'Teacher Date', to: '2026-08-03'),
                  UiTimelineChange(label: 'Duration', to: '45'),
                  UiTimelineChange(label: 'Summary'),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    final firstValueX = tester.getTopLeft(find.text('2026-08-03').first).dx;
    final secondValueX = tester.getTopLeft(find.text('2026-08-03').last).dx;
    expect(firstValueX, secondValueX);
    expect(find.text('—'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'stacks labelled changes and aligns load-more on compact widths',
    (tester) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 260,
            child: UiTimeline(
              dateLabelBuilder: (_) => 'Today',
              events: [
                UiTimelineEvent(
                  id: 1,
                  at: DateTime.utc(2026, 8, 3),
                  title: 'Created',
                  changes: const [
                    UiTimelineChange(
                      label: 'A very long localized field label',
                      to: 'Value',
                    ),
                  ],
                ),
              ],
              dayTotals: const {'2026-08-03': 2},
              onLoadMore: (_) {},
            ),
          ),
        ),
      );

      final labelY = tester
          .getTopLeft(find.text('A very long localized field label'))
          .dy;
      final valueY = tester.getTopLeft(find.text('Value')).dy;
      expect(valueY, greaterThan(labelY));
      expect(tester.getTopLeft(find.text('1 more')).dx, lessThan(150));
      expect(tester.takeException(), isNull);
    },
  );
}
