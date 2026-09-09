import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  for (final style in [UiCornerStyle.circular, UiCornerStyle.continuous]) {
    testWidgets(
      'fluid stroke matches an unclipped stroke at fractional bounds $style',
      (tester) async {
        final actualKey = GlobalKey();
        final referenceKey = GlobalKey();
        const rect = Rect.fromLTWH(8.25, 8.25, 60.5, 60.5);
        const border = BorderSide(color: Color(0xFFFF0000), width: 1.25);
        const corners = BorderRadius.all(Radius.circular(18));
        await tester.pumpWidget(
          UiApp(
            lightTokens: UiThemeData.light(
              radius: UiRadiusTokens.standard.copyWith(cornerStyle: style),
            ),
            home: Center(
              child: Builder(
                builder: (context) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: RepaintBoundary(
                        key: actualKey,
                        child: const Stack(
                          children: [
                            UiFluidSurface(
                              geometry: UiFluidGeometry(rect, 18),
                              contentSize: Size(60.5, 60.5),
                              color: Color(0x00000000),
                              border: border,
                              child: SizedBox(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: RepaintBoundary(
                        key: referenceKey,
                        child: Stack(
                          children: [
                            Positioned.fromRect(
                              rect: rect,
                              child: DecoratedBox(
                                decoration: UiThemeTokens.radiusOf(context)
                                    .decoration(
                                      borderRadius: corners,
                                      border: Border.fromBorderSide(border),
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final differences = await tester.runAsync(() async {
          final actual =
              await (actualKey.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final reference =
              await (referenceKey.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final a = (await actual.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          final b = (await reference.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          var count = 0;
          for (var i = 0; i < a.length; i++) {
            if (a[i] != b[i]) count++;
          }
          actual.dispose();
          reference.dispose();
          return count;
        });
        expect(
          differences,
          0,
          reason: 'The outline must not be antialiased a second time by the content clip.',
        );
      },
    );
  }
}
