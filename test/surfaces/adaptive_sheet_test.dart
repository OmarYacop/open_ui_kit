import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget _host(Size size, WidgetBuilder builder) {
  return UiApp(
    mode: UiThemeMode.light,
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Builder(builder: builder),
    ),
  );
}

void main() {
  testWidgets('uses the canonical sheet surface on phones', (tester) async {
    await tester.pumpWidget(
      _host(
        const Size(390, 844),
        (context) => GestureDetector(
          key: const ValueKey('open'),
          onTap: () => UiAdaptiveSheetScope.show<void>(
            context,
            builder: (_) => const SizedBox(height: 120),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();

    expect(find.byType(UiSheet), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ui_adaptive_floating_surface')),
      findsNothing,
    );
  });

  testWidgets('uses a constrained floating surface on larger viewports', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const Size(1024, 768),
        (context) => GestureDetector(
          key: const ValueKey('open'),
          onTap: () => UiAdaptiveSheetScope.show<void>(
            context,
            maxWidth: 520,
            builder: (_) => const SizedBox(width: 900, height: 200),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();

    final surface = find.byKey(const ValueKey('ui_adaptive_floating_surface'));
    expect(surface, findsOneWidget);
    expect(tester.getSize(surface).width, 520);
    expect(find.byType(UiSheet), findsNothing);
  });
}
