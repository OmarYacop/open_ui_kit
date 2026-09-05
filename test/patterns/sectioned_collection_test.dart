import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget _host(Size size) {
  return UiApp(
    mode: UiThemeMode.light,
    home: Center(
      child: SizedBox.fromSize(
        size: size,
        child: MediaQuery(
          data: MediaQueryData(size: size),
          child: CustomScrollView(
            slivers: [
              UiSliverCollection<int>(
                items: const [0, 1, 2, 3],
                layout: UiCollectionLayout.adaptiveGrid,
                itemBuilder: (_, item, __) => SizedBox(
                  key: ValueKey('item-$item'),
                  height: 40,
                  child: UiText('$item'),
                ),
                sectionBuilder: (_, item, __) => item.isEven
                    ? UiText('section-$item', key: ValueKey('section-$item'))
                    : null,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('section headers span phone rows and items remain linear', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const Size(390, 844)));

    expect(find.byKey(const ValueKey('section-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('section-2')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('item-0'))).dy,
      isNot(tester.getTopLeft(find.byKey(const ValueKey('item-1'))).dy),
    );
  });

  testWidgets('adaptive grid pairs items without crossing sections', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const Size(1024, 768)));

    final item0 = tester.getTopLeft(find.byKey(const ValueKey('item-0')));
    final item1 = tester.getTopLeft(find.byKey(const ValueKey('item-1')));
    final item2 = tester.getTopLeft(find.byKey(const ValueKey('item-2')));
    expect(item0.dy, item1.dy);
    expect(item0.dx, lessThan(item1.dx));
    expect(item2.dy, greaterThan(item0.dy));
  });
}
