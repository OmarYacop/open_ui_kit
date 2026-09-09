import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  testWidgets('fluid surfaces fit narrow LTR and RTL layouts with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final direction in TextDirection.values) {
      await tester.pumpWidget(
        UiApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 740),
              textScaler: TextScaler.linear(1.5),
            ),
            child: Directionality(
              textDirection: direction,
              child: const _MotionTestHost(),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(UiFluidTrigger));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });
  testWidgets(
    'visible actions reverse immediately and repeated toggles stay continuous',
    (tester) async {
      await tester.pumpWidget(const UiApp(home: _MotionTestHost()));
      final morph = tester.widget<UiFluidMorph>(find.byType(UiFluidMorph));
      Rect rect() => tester
          .widgetList<UiFluidSurface>(
            find.descendant(
              of: find.byType(UiFluidMorph),
              matching: find.byType(UiFluidSurface),
            ),
          )
          .first
          .geometry
          .rect;
      await tester.tap(find.byType(UiFluidTrigger));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(morph.controller.isAnimating, isTrue);
      final before = rect();
      await tester.tap(find.text('Close'));
      expect(morph.controller.target, 0);
      await tester.pump();
      expect(rect(), rectMoreOrLessEquals(before));
      await tester.pump(const Duration(milliseconds: 50));
      expect(rect().width, lessThan(before.width - 10));
      final closing = rect();
      await tester.tap(find.text('Close'));
      expect(morph.controller.target, 1);
      await tester.pump();
      expect(rect(), rectMoreOrLessEquals(closing));
      await tester.pumpAndSettle();
      expect(rect(), morph.destinationGeometry.rect);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Edit'));
      final split = tester.widget<UiFluidSplit>(find.byType(UiFluidSplit));
      await tester.tap(find.text('Edit'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Edit'));
      expect(split.controller.target, 0);
      await tester.pumpAndSettle();
      expect(split.controller.value, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

// Test-only composition for input, layout, and interrupted motion coverage.
class _MotionTestHost extends StatefulWidget {
  const _MotionTestHost();

  @override
  State<_MotionTestHost> createState() => __MotionTestHostState();
}

class __MotionTestHostState extends State<_MotionTestHost>
    with TickerProviderStateMixin {
  late final _morph = UiFluidController(vsync: this);
  late final _split = UiFluidController(vsync: this);

  @override
  void dispose() {
    _morph.dispose();
    _split.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return UiPageLayout(
      title: 'Fluid motion',
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.x5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const UiText('Surface morph', variant: UiTextVariant.heading),
              SizedBox(height: tokens.spacing.x4),
              SizedBox(
                height: 300,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final right = constraints.maxWidth - 12;
                    final source = UiFluidGeometry(
                      Rect.fromLTWH(right - 90, 12, 90, 48),
                      24,
                    );
                    final destination = UiFluidGeometry(
                      Rect.fromLTWH(12, 12, constraints.maxWidth - 24, 240),
                      28,
                    );
                    return Stack(
                      children: [
                        UiFluidMorph(
                          controller: _morph,
                          sourceGeometry: source,
                          destinationGeometry: destination,
                          alignment: Alignment.topRight,
                          color: tokens.colors.surface,
                          source: UiFluidTrigger(
                            controller: _morph,
                            label: 'More',
                            child: const Center(child: UiText('More')),
                          ),
                          destination: Padding(
                            padding: EdgeInsets.all(tokens.spacing.x4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const UiText(
                                  'Actions',
                                  variant: UiTextVariant.heading,
                                ),
                                SizedBox(height: tokens.spacing.x4),
                                UiButton(
                                  label: 'Create item',
                                  onPressed: () => _morph.close(context),
                                ),
                                SizedBox(height: tokens.spacing.x3),
                                UiButton(
                                  label: 'Close',
                                  onPressed: () => _morph.target == 0
                                      ? _morph.open(context)
                                      : _morph.close(context),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const UiText('Surface emergence', variant: UiTextVariant.heading),
              SizedBox(height: tokens.spacing.x4),
              SizedBox(
                height: 100,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final right = constraints.maxWidth - 12;
                    return UiFluidSplit(
                      controller: _split,
                      sourceGeometry: UiFluidGeometry(
                        Rect.fromLTWH(right - 64, 20, 64, 48),
                        24,
                      ),
                      color: tokens.colors.surface,
                      source: _SurfaceAction(
                        label: 'Edit',
                        onPressed: () {
                          if (_split.target == 1) {
                            _split.close(context);
                          } else {
                            _split.open(context);
                          }
                        },
                      ),
                      branches: [
                        UiFluidBranch(
                          geometry: UiFluidGeometry(
                            Rect.fromLTWH(right - 216, 20, 140, 48),
                            24,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _SurfaceAction(
                                  label: 'Find',
                                  onPressed: () => _split.close(context),
                                ),
                              ),
                              Expanded(
                                child: _SurfaceAction(
                                  label: 'Add',
                                  onPressed: () => _split.close(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// The fluid surface owns the fill and rounded outline; actions only own input.
class _SurfaceAction extends StatelessWidget {
  const _SurfaceAction({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => UiPressable(
    semanticsLabel: label,
    onPressed: onPressed,
    builder: (context, state, child) => Opacity(
      opacity: state.pressed ? .65 : 1,
      child: Center(child: UiText(label, maxLines: 1)),
    ),
  );
}
