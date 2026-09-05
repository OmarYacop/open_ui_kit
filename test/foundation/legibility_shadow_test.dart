import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  testWidgets('UiLegibilityShadow preserves size and expands paint bounds', (
    tester,
  ) async {
    await tester.pumpWidget(
      UiApp(
        home: Center(
          child: UiLegibilityShadow(
            child: Semantics(
              label: 'Floating title',
              child: const Text('Classes'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Classes'), findsOneWidget);
    expect(
      tester.getSize(find.byType(UiLegibilityShadow)),
      tester.getSize(find.text('Classes')),
    );
    final renderObject = tester.renderObject<RenderUiLegibilityShadow>(
      find.byType(UiLegibilityShadow),
    );
    expect(
      renderObject.paintBounds.contains(renderObject.semanticBounds.topLeft),
      isTrue,
    );
    expect(
      renderObject.paintBounds.contains(
        renderObject.semanticBounds.bottomRight,
      ),
      isTrue,
    );
    expect(renderObject.paintBounds, isNot(renderObject.semanticBounds));
    final widget = tester.widget<UiLegibilityShadow>(
      find.byType(UiLegibilityShadow),
    );
    expect(widget.spreadRadius, 0.5);
  });

  testWidgets('spread paints one shadow silhouette and one foreground child', (
    tester,
  ) async {
    await tester.pumpWidget(
      const UiApp(
        home: Center(
          child: UiLegibilityShadow(
            spreadRadius: 8,
            child: _PaintCountingBox(),
          ),
        ),
      ),
    );

    final child = tester.renderObject<_RenderPaintCountingBox>(
      find.byType(_PaintCountingBox),
    );
    expect(child.paintCount, 2);
  });
}

class _PaintCountingBox extends LeafRenderObjectWidget {
  const _PaintCountingBox();

  @override
  _RenderPaintCountingBox createRenderObject(BuildContext context) =>
      _RenderPaintCountingBox();
}

class _RenderPaintCountingBox extends RenderBox {
  var paintCount = 0;

  @override
  void performLayout() {
    size = constraints.constrain(const Size.square(24));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    paintCount += 1;
    context.canvas.drawRect(
      offset & size,
      Paint()..color = const Color(0xFFFFFFFF),
    );
  }
}
