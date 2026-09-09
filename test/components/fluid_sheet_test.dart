import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/components/surfaces.dart' as surfaces;
import 'package:open_ui_kit/open_ui_kit.dart';

Widget _app(Widget home, {bool reduceMotion = false}) => UiApp(
  home: reduceMotion
      ? Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: home,
          ),
        )
      : home,
);

Widget _anchor({bool isDismissible = true, ValueChanged<String?>? onResult}) =>
    Center(
      child: UiFluidSheetAnchor<String>(
        isDismissible: isDismissible,
        onResult: onResult,
        builder: (context, open) => UiButton(label: 'Open', onPressed: open),
        sheetBuilder: (context, controller) => UiSheet(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Item'),
              UiButton(
                label: 'Done',
                onPressed: () => controller.dismiss('done'),
              ),
            ],
          ),
        ),
      ),
    );

void main() {
  testWidgets('showUiFluidSheet opens from a key and dismisses by controller', (
    tester,
  ) async {
    final sourceKey = GlobalKey();
    String? result;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Center(
            child: UiButton(
              key: sourceKey,
              label: 'Open',
              onPressed: () async {
                result = await surfaces.showUiFluidSheet<String>(
                  context,
                  sourceKey: sourceKey,
                  builder: (context, controller) => UiSheet(
                    child: UiButton(
                      label: 'Done',
                      onPressed: () => controller.dismiss('done'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Neck and undimmed copy only exist with a source builder.
    expect(find.byKey(const Key('ui_fluid_sheet_source')), findsNothing);
    await tester.pumpAndSettle();
    final size = tester.getSize(find.byType(Navigator));
    final surface = tester.widget<UiFluidSurface>(
      find.byKey(const Key('ui_fluid_sheet_surface')),
    );
    expect(surface.geometry.rect.bottom, closeTo(size.height, .01));
    expect(surface.geometry.rect.width, closeTo(size.width, .01));
    expect(surface.geometry.rect.height, lessThan(size.height));
    expect(surface.opacity, 1);
    expect(find.text('Done'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsNothing);
    expect(result, 'done');
    expect(tester.takeException(), isNull);
  });

  testWidgets('anchor paints the source copy, then a drag down dismisses', (
    tester,
  ) async {
    String? result = 'unset';
    await tester.pumpWidget(_app(_anchor(onResult: (r) => result = r)));
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byKey(const Key('ui_fluid_sheet_source')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ui_fluid_sheet_source')), findsNothing);
    expect(find.text('Item'), findsOneWidget);

    await tester.drag(find.text('Item'), const Offset(0, 320));
    await tester.pumpAndSettle();
    expect(find.text('Item'), findsNothing);
    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a short drag settles back and the barrier tap dismisses', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_anchor()));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Item'), const Offset(0, 40));
    await tester.pumpAndSettle();
    expect(find.text('Item'), findsOneWidget);
    final surface = tester.widget<UiFluidSurface>(
      find.byKey(const Key('ui_fluid_sheet_surface')),
    );
    expect(surface.opacity, 1);

    await tester.tapAt(const Offset(12, 12));
    await tester.pumpAndSettle();
    expect(find.text('Item'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('non-dismissible sheets ignore drags', (tester) async {
    await tester.pumpWidget(_app(_anchor(isDismissible: false)));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Item'), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.text('Item'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Item'), findsNothing);
  });

  testWidgets('reduced motion snaps the sheet open', (tester) async {
    await tester.pumpWidget(_app(_anchor(), reduceMotion: true));
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump();
    final size = tester.getSize(find.byType(Navigator));
    final surface = tester.widget<UiFluidSurface>(
      find.byKey(const Key('ui_fluid_sheet_surface')),
    );
    expect(surface.opacity, 1);
    expect(surface.geometry.rect.bottom, closeTo(size.height, .01));
    expect(find.text('Item'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
