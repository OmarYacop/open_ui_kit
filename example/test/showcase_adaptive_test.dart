import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

import 'package:contour_example/showcase.dart';

void main() {
  for (final width in [390.0, 600.0, 1024.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final mode in [UiThemeMode.light, UiThemeMode.dark]) {
        testWidgets('showcase width=$width scale=$scale mode=$mode', (
          tester,
        ) async {
          await tester.binding.setSurfaceSize(Size(width, 844));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            UiApp(
              mode: mode,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true,
                ),
                child: child!,
              ),
              home: const OpenUiKitShowcase(),
            ),
          );
          await tester.pump();
          final errors = <String>[];
          Object? error;
          while ((error = tester.takeException()) != null) {
            errors.add(error.toString());
          }
          expect(errors, isEmpty);
        });
      }
    }
  }
}
