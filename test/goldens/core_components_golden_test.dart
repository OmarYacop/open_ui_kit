import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

import 'golden_test_host.dart';

void main() {
  group('core component goldens', skip: !isSupportedGoldenHost, () {
    testWidgets('checkbox, radio, and switch controls', (tester) async {
      await pumpGoldenFrame(
        tester,
        brightness: Brightness.light,
        size: const Size(360, 220),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              UiCheckbox(
                label: 'Allow late submissions',
                value: true,
                helper: 'Applied to all learners',
              ),
              SizedBox(height: 12),
              UiRadio<String>(
                value: 'student',
                groupValue: 'student',
                label: 'Student view',
              ),
              SizedBox(height: 12),
              UiSwitch(
                label: 'Notifications',
                value: true,
              ),
            ],
          ),
        ),
      );

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/selection_controls_light.png'),
      );
    });

    testWidgets('pagination controls', (tester) async {
      await pumpGoldenFrame(
        tester,
        brightness: Brightness.light,
        size: const Size(360, 120),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: UiPagination(
            currentPage: 3,
            totalPages: 12,
          ),
        ),
      );

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/pagination_light.png'),
      );
    });

    testWidgets('data table baseline', (tester) async {
      await pumpGoldenFrame(
        tester,
        brightness: Brightness.light,
        size: const Size(360, 220),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: UiDataTable(
            columns: const [
              UiDataColumn(label: 'Learner'),
              UiDataColumn(label: 'Assignment'),
              UiDataColumn(label: 'Score', numeric: true),
            ],
            rows: const [
              UiDataRow(cells: [Text('Amina'), Text('Quiz 1'), Text('96')]),
              UiDataRow(cells: [Text('Noah'), Text('Quiz 1'), Text('88')]),
            ],
          ),
        ),
      );

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/data_table_light.png'),
      );
    });
  });
}
