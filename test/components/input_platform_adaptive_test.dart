import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget _host(Widget child) => UiApp(
  lightTokens: UiThemeTokens.light,
  mode: UiThemeMode.light,
  home: ColoredBox(color: const Color(0x00000000), child: child),
);

Future<void> _withPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  group('UiInput selection controls adapt per platform', () {
    for (final platform in TargetPlatform.values) {
      testWidgets('mixes in TextSelectionHandleControls on $platform', (
        tester,
      ) async {
        await _withPlatform(platform, () async {
          final controller = TextEditingController(text: 'hello');
          addTearDown(controller.dispose);
          await tester.pumpWidget(_host(UiInput(controller: controller)));

          final editable = tester.widget<EditableText>(
            find.byType(EditableText),
          );
          // Required for EditableText to defer to contextMenuBuilder instead
          // of this class's deprecated buildToolbar.
          expect(
            editable.selectionControls,
            isA<TextSelectionHandleControls>(),
          );
        });
      });
    }

    testWidgets('desktop platforms render no visible handle', (tester) async {
      await _withPlatform(TargetPlatform.macOS, () async {
        final controller = TextEditingController(text: 'hello');
        addTearDown(controller.dispose);
        await tester.pumpWidget(_host(UiInput(controller: controller)));

        final controls = tester
            .widget<EditableText>(find.byType(EditableText))
            .selectionControls!;
        expect(controls.getHandleSize(20), Size.zero);
      });
    });

    testWidgets('iOS and Android render a sized handle', (tester) async {
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        await _withPlatform(platform, () async {
          final controller = TextEditingController(text: 'hello');
          addTearDown(controller.dispose);
          await tester.pumpWidget(_host(UiInput(controller: controller)));

          final controls = tester
              .widget<EditableText>(find.byType(EditableText))
              .selectionControls!;
          expect(
            controls.getHandleSize(20),
            isNot(Size.zero),
            reason: '$platform should show a visible selection handle',
          );
        });
      }
    });
  });
}
