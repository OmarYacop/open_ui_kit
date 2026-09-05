import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  testWidgets('tooltip respects overlay insets removed below the overlay', (
    tester,
  ) async {
    final focus = FocusNode();
    await tester.pumpWidget(
      UiApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(padding: const EdgeInsets.only(top: 100)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 120),
                child: UiTooltip(
                  message: 'Safe help',
                  side: UiTooltipSide.top,
                  child: UiButton(
                    label: 'Help',
                    focusNode: focus,
                    onPressed: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Safe help')).dy,
      greaterThanOrEqualTo(108),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    focus.dispose();
  });

  testWidgets('long tooltip fits a narrow overlay and Escape dismisses', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(180, 300));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final focus = FocusNode();
    const message = 'A long description that needs the available width';
    await tester.pumpWidget(
      UiApp(
        home: Center(
          child: UiTooltip(
            message: message,
            child: UiButton(label: 'Help', focusNode: focus, onPressed: () {}),
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final rect = tester.getRect(find.text(message));
    expect(rect.left, greaterThanOrEqualTo(8));
    expect(rect.right, lessThanOrEqualTo(172));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text(message), findsNothing);
    await tester.pumpWidget(const SizedBox());
    focus.dispose();
  });

  testWidgets('tooltip follows scrolling without a permanent frame loop', (
    tester,
  ) async {
    final focus = FocusNode();
    final scroll = ScrollController();
    await tester.pumpWidget(
      UiApp(
        home: ListView(
          controller: scroll,
          children: [
            const SizedBox(height: 250),
            UiTooltip(
              message: 'Attached help',
              side: UiTooltipSide.bottom,
              child: UiButton(
                label: 'Help',
                focusNode: focus,
                onPressed: () {},
              ),
            ),
            const SizedBox(height: 1000),
          ],
        ),
      ),
    );
    focus.requestFocus();
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(find.text('Attached help'));
    scroll.jumpTo(70);
    await tester.pumpAndSettle();
    final after = tester.getTopLeft(find.text('Attached help'));
    expect(after.dy, closeTo(before.dy - 70, .1));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
    focus.dispose();
    scroll.dispose();
  });
}
