import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  testWidgets('semantic overlay layers paint in their declared order', (
    tester,
  ) async {
    var floatingTaps = 0;
    var chromeTaps = 0;
    var feedbackTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: UiLayeredOverlayHost(
          child: _LayerEntries(
            onFloatingTap: () => floatingTaps++,
            onChromeTap: () => chromeTaps++,
            onFeedbackTap: () => feedbackTaps++,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tapAt(const Offset(400, 300));

    expect(floatingTaps, 0);
    expect(chromeTaps, 0);
    expect(feedbackTaps, 1);
  });

  testWidgets('portal lifts one interactive child into the requested layer', (
    tester,
  ) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: UiLayeredOverlayHost(
          child: Center(
            child: SizedBox(
              width: 120,
              height: 48,
              child: UiLayeredOverlayPortal(
                layer: UiOverlayLayer.navigationChrome,
                child: GestureDetector(
                  key: const Key('lifted-child'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps++,
                  child: const Text('Chrome'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('lifted-child')), findsOneWidget);
    await tester.tap(find.byKey(const Key('lifted-child')));
    expect(taps, 1);
  });
}

class _LayerEntries extends StatefulWidget {
  const _LayerEntries({
    required this.onFloatingTap,
    required this.onChromeTap,
    required this.onFeedbackTap,
  });

  final VoidCallback onFloatingTap;
  final VoidCallback onChromeTap;
  final VoidCallback onFeedbackTap;

  @override
  State<_LayerEntries> createState() => _LayerEntriesState();
}

class _LayerEntriesState extends State<_LayerEntries> {
  final _entries = <OverlayEntry>[];
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _insert(UiOverlayLayer.floating, widget.onFloatingTap);
      _insert(UiOverlayLayer.navigationChrome, widget.onChromeTap);
      _insert(UiOverlayLayer.systemFeedback, widget.onFeedbackTap);
    });
  }

  void _insert(UiOverlayLayer layer, VoidCallback onTap) {
    final entry = OverlayEntry(
      builder: (_) => Center(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: const SizedBox(width: 200, height: 200),
        ),
      ),
    );
    _entries.add(entry);
    UiLayeredOverlay.of(context, layer).insert(entry);
  }

  @override
  void dispose() {
    for (final entry in _entries) {
      entry.remove();
      entry.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
