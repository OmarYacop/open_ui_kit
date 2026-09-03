import 'package:contour_example/component_previews.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  testWidgets('all component documentation previews render without overflow', (
    tester,
  ) async {
    for (final kind in ComponentPreviewKind.values) {
      await tester.binding.setSurfaceSize(_previewSize(kind));
      await tester.pumpWidget(
        UiApp(
          mode: UiThemeMode.light,
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [DefaultWidgetsLocalizations.delegate],
          home: OpenUiKitComponentPreview(kind: kind),
        ),
      );
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: '${kind.name} preview should fit its capture surface',
      );
    }
  });

  tearDown(() async {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .clearAllTestValues();
  });
}

Size _previewSize(ComponentPreviewKind kind) => switch (kind) {
  ComponentPreviewKind.actions => const Size(900, 340),
  ComponentPreviewKind.forms => const Size(900, 450),
  ComponentPreviewKind.dataDisplay => const Size(900, 420),
  ComponentPreviewKind.chat => const Size(900, 580),
  ComponentPreviewKind.feedback => const Size(980, 400),
  ComponentPreviewKind.navigation => const Size(900, 388),
  ComponentPreviewKind.pickers => const Size(980, 560),
};
