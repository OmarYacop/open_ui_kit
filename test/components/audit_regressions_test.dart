import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget host(
  Widget child, {
  TextDirection direction = TextDirection.ltr,
  double scale = 1,
}) => Directionality(
  textDirection: direction,
  child: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: UiTheme(
      tokens: UiThemeTokens.light,
      child: DefaultTextStyle(
        style: const TextStyle(fontSize: 14),
        child: Center(child: SizedBox(width: 320, child: child)),
      ),
    ),
  ),
);

void main() {
  testWidgets('slider tap end reports the changed value', (tester) async {
    double? changed, ended;
    await tester.pumpWidget(
      host(
        UiSlider(
          value: .2,
          onChanged: (v) => changed = v,
          onChangeEnd: (v) => ended = v,
        ),
      ),
    );
    final box = tester.getRect(find.byType(UiSlider));
    await tester.tapAt(Offset(box.right - 15, box.center.dy));
    await tester.pump();
    expect(ended, changed);
  });
  testWidgets('RTL slider left end represents the maximum', (tester) async {
    double? changed;
    await tester.pumpWidget(
      host(
        UiSlider(value: .5, onChanged: (v) => changed = v),
        direction: TextDirection.rtl,
      ),
    );
    final box = tester.getRect(find.byType(UiSlider));
    await tester.tapAt(Offset(box.left + 9, box.center.dy));
    await tester.pump();
    expect(changed, 1);
  });
  testWidgets('gallery handles its items shrinking after paging', (
    tester,
  ) async {
    final two = List.generate(
      2,
      (i) => UiMediaGalleryItem(
        title: '$i',
        zoomable: false,
        builder: (_) => Text('media $i'),
      ),
    );
    Widget gallery(List<UiMediaGalleryItem> items) => host(
      SizedBox(
        height: 400,
        child: UiMediaGallery(
          key: const ValueKey('gallery'),
          items: items,
          initialIndex: 0,
          dismissLabel: 'Close',
        ),
      ),
    );
    await tester.pumpWidget(gallery(two));
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.pumpWidget(gallery([two.first]));
    final error = tester.takeException();
    expect(error, isNull);
  });
  testWidgets('gallery double tap respects maxScale', (tester) async {
    await tester.pumpWidget(
      host(
        SizedBox(
          height: 400,
          child: UiMediaGallery(
            items: [
              UiMediaGalleryItem(
                builder: (_) => const ColoredBox(color: Color(0xff123456)),
              ),
            ],
            dismissLabel: 'Close',
            maxScale: 2,
          ),
        ),
      ),
    );
    final center = tester.getCenter(find.byType(InteractiveViewer));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 350));
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    final scale = viewer.transformationController!.value.getMaxScaleOnAxis();
    expect(scale, 2);
  });

  testWidgets('slider drag end reports final value without parent rebuild', (
    tester,
  ) async {
    double? changed, ended;
    await tester.pumpWidget(
      host(
        UiSlider(
          value: .2,
          onChanged: (v) => changed = v,
          onChangeEnd: (v) => ended = v,
        ),
      ),
    );
    await tester.drag(find.byType(UiSlider), const Offset(90, 0));
    expect(changed, isNotNull);
    expect(ended, changed);
  });

  testWidgets('RTL slider left arrow increases its value', (tester) async {
    double? changed;
    final focus = FocusNode();
    await tester.pumpWidget(
      host(
        UiSlider(value: .5, focusNode: focus, onChanged: (v) => changed = v),
        direction: TextDirection.rtl,
      ),
    );
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    expect(changed, greaterThan(.5));
    await tester.pumpWidget(const SizedBox());
    focus.dispose();
  });

  testWidgets('gallery remains dismissible after the final item is removed', (
    tester,
  ) async {
    var dismissed = false;
    Widget gallery(List<UiMediaGalleryItem> items) => host(
      SizedBox(
        height: 400,
        child: UiMediaGallery(
          items: items,
          dismissLabel: 'Close',
          onDismiss: () => dismissed = true,
        ),
      ),
    );
    await tester.pumpWidget(
      gallery([UiMediaGalleryItem(builder: (_) => const Text('Media'))]),
    );
    await tester.pumpWidget(gallery([]));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.bySemanticsLabel('Close'));
    expect(dismissed, isTrue);
  });

  testWidgets('gallery reconciles initial transform to configured minimum', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        SizedBox(
          height: 400,
          child: UiMediaGallery(
            minScale: 1.5,
            maxScale: 2,
            items: [UiMediaGalleryItem(builder: (_) => const Text('Media'))],
            dismissLabel: 'Close',
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!
          .value
          .getMaxScaleOnAxis(),
      1.5,
    );
  });

  for (final direction in TextDirection.values) {
    testWidgets(
      'rating uses full targets and mirrors half fill in $direction',
      (tester) async {
        double? changed;
        await tester.pumpWidget(
          host(
            UiRating(
              value: .5,
              allowHalfRating: true,
              onChanged: (value) => changed = value,
            ),
            direction: direction,
          ),
        );
        final target = find
            .descendant(
              of: find.byType(UiRating),
              matching: find.byType(UiPressable),
            )
            .first;
        final rect = tester.getRect(target);
        expect(rect.size, const Size(48, 48));
        final x = direction == TextDirection.ltr
            ? rect.left + 8
            : rect.right - 8;
        await tester.tapAt(Offset(x, rect.center.dy));
        // Select a different value so controlled inputs emit a callback.
        await tester.tapAt(
          Offset(
            direction == TextDirection.ltr ? rect.right - 8 : rect.left + 8,
            rect.center.dy,
          ),
        );
        expect(changed, 1);
        final clip = tester
            .widget<ClipRect>(
              find
                  .descendant(
                    of: find.byType(UiRating),
                    matching: find.byType(ClipRect),
                  )
                  .first,
            )
            .clipper!;
        expect(
          clip.getClip(const Size(24, 24)).left,
          direction == TextDirection.rtl ? 12 : 0,
        );
      },
    );
  }
}
