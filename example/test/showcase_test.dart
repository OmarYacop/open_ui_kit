import 'package:contour_example/showcase.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  Future<void> pumpShowcase(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(
      const UiApp(
        mode: UiThemeMode.light,
        debugShowCheckedModeBanner: false,
        localizationsDelegates: [DefaultWidgetsLocalizations.delegate],
        home: OpenUiKitShowcase(),
      ),
    );
    await tester.pump();
  }

  tearDown(() async {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .clearAllTestValues();
  });

  testWidgets('showcase lays out on wide screens', (tester) async {
    await pumpShowcase(tester, const Size(1440, 1024));

    expect(find.text('Open UI Kit'), findsOneWidget);
    expect(find.text('Compose a release'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Recent releases'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('showcase remains usable on narrow screens', (tester) async {
    await pumpShowcase(tester, const Size(390, 844));

    expect(find.text('Open UI Kit'), findsOneWidget);
    expect(find.text('Compose a release'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
