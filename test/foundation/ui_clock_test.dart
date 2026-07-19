import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget _host(Widget child) {
  return UiApp(
    home: Center(child: child),
    debugShowCheckedModeBanner: false,
  );
}

void main() {
  testWidgets('fallback clock does not leave a pending timer', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: UiNowBuilder(
          builder: _FallbackClockText.new,
        ),
      ),
    );

    expect(find.text('fallback'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('UiNowBuilder rebuilds from an injected controller', (
    tester,
  ) async {
    final controller = UiClockController(
      tickMode: UiClockTickMode.manual,
      initialNow: DateTime(2026, 7, 19, 11, 59),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        UiClockScope(
          controller: controller,
          child: UiNowBuilder(
            builder: (context, now) => Text('${now.hour}:${now.minute}'),
          ),
        ),
      ),
    );

    expect(find.text('11:59'), findsOneWidget);

    controller.setNow(DateTime(2026, 7, 19, 12));
    await tester.pump();

    expect(find.text('12:0'), findsOneWidget);
  });

  testWidgets('UiNowBuilder wakes at registered watch times', (tester) async {
    var now = DateTime(2026, 7, 19, 11, 59);
    final controller = UiClockController(
      tickMode: UiClockTickMode.manual,
      initialNow: now,
      nowProvider: () => now,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        UiNowBuilder(
          controller: controller,
          watchTimes: [DateTime(2026, 7, 19, 12)],
          builder: (context, current) =>
              Text(current.isBefore(DateTime(2026, 7, 19, 12)) ? 'wait' : 'go'),
        ),
      ),
    );

    expect(find.text('wait'), findsOneWidget);

    now = DateTime(2026, 7, 19, 12);
    await tester.pump(const Duration(minutes: 1));

    expect(find.text('go'), findsOneWidget);
  });

  testWidgets('UiTimeGate switches content at time boundaries', (tester) async {
    final controller = UiClockController(
      tickMode: UiClockTickMode.manual,
      initialNow: DateTime(2026, 7, 19, 11, 59),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        UiTimeGate(
          controller: controller,
          visibleFrom: DateTime(2026, 7, 19, 12),
          visibleUntil: DateTime(2026, 7, 19, 13),
          transition: UiTimeGateTransition.none,
          placeholder: (_) => const Text('closed'),
          builder: (_) => const Text('open'),
        ),
      ),
    );

    expect(find.text('closed'), findsOneWidget);

    controller.setNow(DateTime(2026, 7, 19, 12));
    await tester.pump();

    expect(find.text('open'), findsOneWidget);

    controller.setNow(DateTime(2026, 7, 19, 13));
    await tester.pump();

    expect(find.text('closed'), findsOneWidget);
  });
}

class _FallbackClockText extends StatelessWidget {
  const _FallbackClockText(this.context, this.now);

  final BuildContext context;
  final DateTime now;

  @override
  Widget build(BuildContext context) => const Text('fallback');
}
