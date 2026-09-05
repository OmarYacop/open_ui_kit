import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/components/feedback.dart';
import 'package:open_ui_kit/foundation.dart';
import 'package:open_ui_kit/patterns/layout.dart';

Widget _host(Widget child) => UiApp(
  lightTokens: UiThemeTokens.light,
  mode: UiThemeMode.light,
  home: Align(alignment: Alignment.topLeft, child: child),
);

void main() {
  testWidgets('UiContentPage lays out titled, spaced content', (tester) async {
    await tester.pumpWidget(
      _host(
        const SizedBox(
          width: 390,
          height: 700,
          child: UiContentPage(
            title: 'Dashboard',
            children: [Text('First'), Text('Second')],
          ),
        ),
      ),
    );

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Second')).dy,
      greaterThan(tester.getBottomLeft(find.text('First')).dy),
    );
  });

  testWidgets('UiContentPage delegates refresh feedback to its scaffold', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 390,
          height: 700,
          child: UiContentPage(
            title: 'Refreshable',
            onRefresh: () async {},
            children: const [Text('Body')],
          ),
        ),
      ),
    );

    final scaffold = tester.widget<UiPageScaffold>(find.byType(UiPageScaffold));
    expect(scaffold.onRefresh, isNotNull);
    expect(find.byType(UiRefresher), findsOneWidget);
  });
}
