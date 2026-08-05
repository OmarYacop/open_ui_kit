import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: child)),
  );
}

void main() {
  group('selection primitives', () {
    testWidgets('checkbox toggles, supports focus, and renders error/disabled',
        (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      var value = false;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  UiCheckbox(
                    label: 'Allow submissions',
                    value: value,
                    focusNode: focusNode,
                    onChanged: (next) => setState(() => value = next),
                  ),
                  const UiCheckbox(
                    label: 'Archived',
                    value: true,
                    enabled: false,
                    errorText: 'Cannot change archived state',
                  ),
                ],
              );
            },
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(value, isTrue);
      expect(find.text('Cannot change archived state'), findsOneWidget);
    });

    testWidgets('radio and switch change state; switch loading blocks input',
        (tester) async {
      var selected = 'student';
      var notifications = false;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  UiRadio<String>(
                    value: 'student',
                    groupValue: selected,
                    label: 'Student',
                    onChanged: (next) => setState(() => selected = next),
                  ),
                  UiRadio<String>(
                    value: 'teacher',
                    groupValue: selected,
                    label: 'Teacher',
                    onChanged: (next) => setState(() => selected = next),
                  ),
                  UiSwitch(
                    value: notifications,
                    label: 'Notifications',
                    onChanged: (next) => setState(() => notifications = next),
                  ),
                  const UiSwitch(
                    value: true,
                    label: 'Syncing',
                    loading: true,
                    onChanged: null,
                  ),
                ],
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Teacher'));
      await tester.pump();
      expect(selected, 'teacher');

      await tester.tap(find.text('Notifications'));
      await tester.pump();
      expect(notifications, isTrue);

      final loadingNode = tester.getSemantics(find.text('Syncing'));
      expect(loadingNode.hint, contains('loading'));
    });

    testWidgets('radio group selects options and exposes helper and error text',
        (tester) async {
      var selected = 'student';
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              return UiRadioGroup<String>(
                label: 'Account type',
                value: selected,
                helper: 'Choose the closest role.',
                errorText:
                    selected == 'guardian' ? 'Guardian is unavailable' : null,
                options: const [
                  UiRadioGroupOption(
                    value: 'student',
                    label: 'Student',
                    helper: 'Learner access',
                  ),
                  UiRadioGroupOption(
                    value: 'teacher',
                    label: 'Teacher',
                  ),
                  UiRadioGroupOption(
                    value: 'guardian',
                    label: 'Guardian',
                  ),
                ],
                onChanged: (next) => setState(() => selected = next),
              );
            },
          ),
        ),
      );

      expect(find.text('Choose the closest role.'), findsOneWidget);
      expect(find.text('Learner access'), findsOneWidget);

      await tester.tap(find.text('Teacher'));
      await tester.pump();
      expect(selected, 'teacher');

      await tester.tap(find.text('Guardian'));
      await tester.pump();
      expect(selected, 'guardian');
      expect(find.text('Guardian is unavailable'), findsOneWidget);
      expect(find.text('Choose the closest role.'), findsNothing);
    });

    testWidgets('radio group disables group and individual options',
        (tester) async {
      var selected = 'student';
      await tester.pumpWidget(
        _host(
          UiRadioGroup<String>(
            value: selected,
            options: const [
              UiRadioGroupOption(value: 'student', label: 'Student'),
              UiRadioGroupOption(
                value: 'teacher',
                label: 'Teacher',
                enabled: false,
              ),
            ],
            onChanged: (next) => selected = next,
          ),
        ),
      );

      await tester.tap(find.text('Teacher'));
      await tester.pump();
      expect(selected, 'student');

      await tester.pumpWidget(
        _host(
          UiRadioGroup<String>(
            value: selected,
            enabled: false,
            options: const [
              UiRadioGroupOption(value: 'student', label: 'Student'),
              UiRadioGroupOption(value: 'teacher', label: 'Teacher'),
            ],
            onChanged: (next) => selected = next,
          ),
        ),
      );

      await tester.tap(find.text('Teacher'));
      await tester.pump();
      expect(selected, 'student');
    });
  });

  group('pagination + data table', () {
    testWidgets('skeleton components render card, bars, circles, and text',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const UiCardSkeleton(
            width: 240,
            height: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    UiSkeletonBar.circle(size: 32),
                    SizedBox(width: 12),
                    Expanded(
                      child: UiSkeletonText(
                        lines: 2,
                        widths: [120.0, 80.0],
                      ),
                    ),
                  ],
                ),
                Spacer(),
                UiSkeletonBar(width: 96, height: 20),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(UiCardSkeleton), findsOneWidget);
      expect(find.byType(UiSkeletonBar), findsNWidgets(4));
      expect(find.byType(UiSkeletonText), findsOneWidget);
    });

    testWidgets('pagination navigates and exposes loading state',
        (tester) async {
      var page = 2;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UiPagination(
                    currentPage: page,
                    totalPages: 8,
                    onPageChanged: (next) => setState(() => page = next),
                  ),
                  const UiPagination(
                    currentPage: 1,
                    totalPages: 3,
                    loading: true,
                  ),
                ],
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Next').first);
      await tester.pump();
      expect(page, 3);
      expect(find.text('Loading…'), findsOneWidget);
    });

    testWidgets('data table supports default, empty, loading, and error states',
        (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        _host(
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UiDataTable(
                  columns: const [
                    UiDataColumn(label: 'Learner'),
                    UiDataColumn(label: 'Score', numeric: true),
                  ],
                  rows: [
                    UiDataRow(
                      cells: const [Text('Amina'), Text('96')],
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const UiDataTable(
                  columns: [
                    UiDataColumn(label: 'Learner'),
                    UiDataColumn(label: 'Score', numeric: true),
                  ],
                  rows: [],
                ),
                const SizedBox(height: 12),
                const UiDataTable(
                  columns: [
                    UiDataColumn(label: 'Learner'),
                    UiDataColumn(label: 'Score', numeric: true),
                  ],
                  rows: [],
                  loading: true,
                ),
                const SizedBox(height: 12),
                UiDataTable(
                  columns: const [
                    UiDataColumn(label: 'Learner'),
                    UiDataColumn(label: 'Score', numeric: true),
                  ],
                  rows: const [],
                  errorText: 'Failed to load gradebook.',
                  onRetry: () => retries++,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Amina'), findsOneWidget);
      expect(find.text('No records yet.'), findsOneWidget);
      expect(find.text('Loading table…'), findsOneWidget);
      expect(find.text('Failed to load gradebook.'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(retries, 1);
    });

    testWidgets('lazy data table does not build off-screen rows',
        (tester) async {
      final built = <int>[];

      await tester.pumpWidget(
        _host(
          UiDataTable.lazy(
            columns: const [
              UiDataColumn(label: 'Learner'),
              UiDataColumn(label: 'Score', numeric: true),
            ],
            rowCount: 200,
            rowBuilder: (context, index) {
              built.add(index);
              return UiDataRow(
                cells: [
                  Text('Learner $index'),
                  Text('${index + 1}'),
                ],
              );
            },
          ),
        ),
      );

      expect(find.text('Learner 0'), findsOneWidget);
      expect(find.text('Learner 199'), findsNothing);
      expect(built.length, lessThan(200));
    });

    testWidgets('non-scrollable data table delegates scrolling to its parent',
        (tester) async {
      await tester.pumpWidget(
        _host(
          UiDataTable.lazy(
            columns: const [UiDataColumn(label: 'Learner')],
            rowCount: 3,
            scrollable: false,
            rowBuilder: (context, index) => UiDataRow(
              cells: [Text('Learner $index')],
            ),
          ),
        ),
      );

      final rowsList = tester.widget<ListView>(
        find.descendant(
          of: find.byType(UiDataTable),
          matching: find.byType(ListView),
        ),
      );
      expect(rowsList.shrinkWrap, isTrue);
      expect(rowsList.physics, isA<NeverScrollableScrollPhysics>());
      expect(find.text('Learner 2'), findsOneWidget);
    });

    testWidgets('data table clips rows inside its rounded border',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const UiDataTable(
            columns: [
              UiDataColumn(label: 'Learner', alignment: Alignment.center),
            ],
            rows: [
              UiDataRow(cells: [Text('Amina')]),
              UiDataRow(cells: [Text('Yusuf')]),
            ],
          ),
        ),
      );

      final roundedClip = tester.widget<ClipRRect>(
        find.descendant(
          of: find.byType(UiDataTable),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(roundedClip.clipBehavior, Clip.antiAlias);
      expect(
        find.ancestor(
          of: find.text('Learner'),
          matching: find.byWidgetPredicate(
            (widget) => widget is Align && widget.alignment == Alignment.center,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.text('Amina'),
          matching: find.byWidgetPredicate(
            (widget) => widget is Align && widget.alignment == Alignment.center,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(UiDataTable),
          matching: find.byWidgetPredicate((widget) {
            if (widget case UiBox(border: final Border border)) {
              return border.top.style != BorderStyle.none &&
                  border.left.style == BorderStyle.none &&
                  border.right.style == BorderStyle.none &&
                  border.bottom.style == BorderStyle.none;
            }
            return false;
          }),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(UiDataTable),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Padding && widget.padding == const EdgeInsets.all(1),
          ),
        ),
        findsOneWidget,
      );
    });
  });
}
