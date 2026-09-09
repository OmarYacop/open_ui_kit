import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  for (final platform in TargetPlatform.values) {
    test('automatic corner style on $platform and explicit override', () {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final apple =
          platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
      expect(UiRadiusTokens.standard.isContinuous, apple);
      expect(
        UiRadiusTokens.standard
            .copyWith(cornerStyle: UiCornerStyle.circular)
            .isContinuous,
        false,
      );
      expect(
        UiRadiusTokens.standard
            .copyWith(cornerStyle: UiCornerStyle.continuous)
            .isContinuous,
        true,
      );
    });
  }

  test('corner style survives theme copying and interpolation', () {
    final circular = UiRadiusTokens.standard.copyWith(
      cornerStyle: UiCornerStyle.circular,
    );
    final continuous = circular.copyWith(cornerStyle: UiCornerStyle.continuous);
    expect(
      continuous.copyWith(lg: const Radius.circular(28)).cornerStyle,
      UiCornerStyle.continuous,
    );
    expect(
      UiRadiusTokens.lerp(circular, continuous, 1).cornerStyle,
      UiCornerStyle.continuous,
    );
    final theme = UiThemeData.light(radius: continuous);
    expect(theme.copyWith().radius.cornerStyle, UiCornerStyle.continuous);
    expect(
      theme.lerp(UiThemeData.dark(radius: circular), 1).radius.cornerStyle,
      UiCornerStyle.circular,
    );
  });

  for (final style in [UiCornerStyle.circular, UiCornerStyle.continuous]) {
    testWidgets('surface paint, clipping and hit region agree for $style', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        UiApp(
          lightTokens: UiThemeData.light(
            radius: UiRadiusTokens.standard.copyWith(cornerStyle: style),
          ),
          home: Stack(
            children: [
              UiFluidSurface(
                geometry: const UiFluidGeometry(
                  Rect.fromLTWH(40, 40, 180, 100),
                  32,
                ),
                contentSize: const Size(180, 100),
                color: const Color(0xffcccccc),
                backdropBlurSigma: 16,
                border: const BorderSide(color: Color(0xff000000)),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps++,
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      );
      final surface = find.byType(UiFluidSurface);
      if (style == UiCornerStyle.continuous) {
        expect(
          find.descendant(
            of: surface,
            matching: find.byType(ClipRSuperellipse),
          ),
          findsOneWidget,
        );
        final decorations = tester.widgetList<DecoratedBox>(
          find.descendant(of: surface, matching: find.byType(DecoratedBox)),
        );
        for (final decoration in decorations) {
          expect(
            (decoration.decoration as ShapeDecoration).shape,
            isA<RoundedSuperellipseBorder>(),
          );
        }
      } else {
        expect(
          find.descendant(of: surface, matching: find.byType(ClipRRect)),
          findsOneWidget,
        );
      }
      final clip = find.descendant(
        of: surface,
        matching: find.byWidgetPredicate(
          (w) => w is ClipRRect || w is ClipRSuperellipse,
        ),
      );
      final clipRect = tester.getRect(clip);
      await tester.tapAt(clipRect.topLeft + const Offset(1, 1));
      expect(taps, 0);
      await tester.tapAt(clipRect.center);
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    });
  }

  test('continuous directional corners mirror in RTL', () {
    final shape = UiRadiusTokens.standard
        .copyWith(cornerStyle: UiCornerStyle.continuous)
        .shape(
          borderRadius: const BorderRadiusDirectional.only(
            topStart: Radius.circular(40),
            bottomEnd: Radius.circular(12),
          ),
        );
    const rect = Rect.fromLTWH(0, 0, 180, 100);
    final ltr = shape.getOuterPath(rect, textDirection: TextDirection.ltr);
    final rtl = shape.getOuterPath(rect, textDirection: TextDirection.rtl);
    for (var x = 2.0; x < 180; x += 7) {
      for (var y = 2.0; y < 100; y += 7) {
        expect(ltr.contains(Offset(x, y)), rtl.contains(Offset(180 - x, y)));
      }
    }
  });
}
