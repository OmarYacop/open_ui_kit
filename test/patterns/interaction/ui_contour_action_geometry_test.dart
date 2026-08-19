import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

const _checkpoints = [
  0.0,
  0.01,
  0.1,
  0.25,
  0.5,
  0.75,
  0.9,
  0.92, // activation threshold
  0.99,
  1.0,
];

UiContourActionGeometryInput _input(
  double progress, {
  Size triggerSize = const Size(80, 40),
  List<Size> actionSizes = const [Size(40, 40), Size(40, 40)],
  double spacing = 8,
}) {
  return UiContourActionGeometryInput(
    triggerSize: triggerSize,
    actionSizes: actionSizes,
    spacing: spacing,
    progress: progress,
  );
}

void main() {
  group('endpoints', () {
    test(
        'progress 0: outer size equals trigger size, actions are zero-size at its trailing edge',
        () {
      final g = UiContourActionGeometrySolver.solve(_input(0));
      expect(g.outerSize.width, 80);
      expect(g.triggerRect, const Rect.fromLTWH(0, 0, 80, 40));
      for (final rect in g.actionRects) {
        expect(rect.width, 0);
        expect(rect.height, 0);
        expect(rect.center, const Offset(80, 20)); // trigger trailing edge
      }
      expect(g.actionVisibility, everyElement(0));
      expect(g.actionInteractive, everyElement(isFalse));
    });

    test('progress 1: actions reach natural size at final laid-out positions',
        () {
      final g = UiContourActionGeometrySolver.solve(_input(1));
      // trigger(80) + spacing(8) + action0(40) + spacing(8) + action1(40)
      expect(g.outerSize.width, 176);
      expect(g.actionRects[0], const Rect.fromLTWH(88, 0, 40, 40));
      expect(g.actionRects[1], const Rect.fromLTWH(136, 0, 40, 40));
      expect(g.actionVisibility, everyElement(1));
      expect(g.actionInteractive, everyElement(isTrue));
    });

    test('trigger rect never changes across progress', () {
      const expected = Rect.fromLTWH(0, 0, 80, 40);
      for (final t in _checkpoints) {
        final g = UiContourActionGeometrySolver.solve(_input(t));
        expect(g.triggerRect, expected, reason: 'at t=$t');
      }
    });
  });

  group('monotonicity (no snap, no recoil)', () {
    test('outer width is monotonically non-decreasing across checkpoints', () {
      double? previous;
      for (final t in _checkpoints) {
        final width =
            UiContourActionGeometrySolver.solve(_input(t)).outerSize.width;
        if (previous != null) {
          expect(
            width,
            greaterThanOrEqualTo(previous),
            reason: 'width regressed at t=$t (recoil)',
          );
        }
        previous = width;
      }
    });

    test('each action rect right edge is monotonically non-decreasing', () {
      final previous = List<double?>.filled(2, null);
      for (final t in _checkpoints) {
        final g = UiContourActionGeometrySolver.solve(_input(t));
        for (var i = 0; i < g.actionRects.length; i++) {
          final right = g.actionRects[i].right;
          if (previous[i] != null) {
            expect(right, greaterThanOrEqualTo(previous[i]!),
                reason: 'action $i at t=$t');
          }
          previous[i] = right;
        }
      }
    });

    test(
        'reverse traversal mirrors forward traversal exactly (same function of t)',
        () {
      final forward = [
        for (final t in _checkpoints)
          UiContourActionGeometrySolver.solve(_input(t))
      ];
      final reversed = [
        for (final t in _checkpoints.reversed)
          UiContourActionGeometrySolver.solve(_input(t)),
      ].reversed.toList();
      for (var i = 0; i < forward.length; i++) {
        expect(forward[i].outerSize, reversed[i].outerSize);
        expect(forward[i].actionRects, reversed[i].actionRects);
      }
    });

    test(
        'no width recoil at the specific 24-30ms-equivalent low-progress region',
        () {
      final low =
          UiContourActionGeometrySolver.solve(_input(0.1)).outerSize.width;
      final mid =
          UiContourActionGeometrySolver.solve(_input(0.15)).outerSize.width;
      expect(mid, greaterThan(low));
    });
  });

  group('finiteness and bounds', () {
    test('no negative sizes and all rects finite at every checkpoint', () {
      for (final t in _checkpoints) {
        final g = UiContourActionGeometrySolver.solve(_input(t));
        expect(g.outerSize.width.isFinite, isTrue);
        expect(g.outerSize.height.isFinite, isTrue);
        expect(g.outerSize.width, greaterThanOrEqualTo(0));
        for (final rect in g.actionRects) {
          expect(rect.width.isFinite, isTrue);
          expect(rect.height.isFinite, isTrue);
          expect(rect.width, greaterThanOrEqualTo(0));
          expect(rect.height, greaterThanOrEqualTo(0));
        }
      }
    });

    test('progress outside [0,1] is clamped, not extrapolated', () {
      final over = UiContourActionGeometrySolver.solve(_input(1.4));
      final atOne = UiContourActionGeometrySolver.solve(_input(1));
      expect(over.outerSize, atOne.outerSize);

      final under = UiContourActionGeometrySolver.solve(_input(-0.4));
      final atZero = UiContourActionGeometrySolver.solve(_input(0));
      expect(under.outerSize, atZero.outerSize);
    });

    test('no action rect ever exceeds its natural size', () {
      for (final t in _checkpoints) {
        final g = UiContourActionGeometrySolver.solve(_input(t));
        for (var i = 0; i < g.actionRects.length; i++) {
          expect(g.actionRects[i].width, lessThanOrEqualTo(40.0001));
          expect(g.actionRects[i].height, lessThanOrEqualTo(40.0001));
        }
      }
    });
  });

  group('activation threshold', () {
    test('actions become interactive only at/after the threshold', () {
      final below = UiContourActionGeometrySolver.solve(_input(0.91));
      final at = UiContourActionGeometrySolver.solve(_input(0.92));
      expect(below.actionInteractive, everyElement(isFalse));
      expect(at.actionInteractive, everyElement(isTrue));
    });
  });

  group('responsive: action count', () {
    test('zero actions collapses outer size to the trigger alone', () {
      final g = UiContourActionGeometrySolver.solve(
        _input(1, actionSizes: const []),
      );
      expect(g.outerSize.width, 80);
      expect(g.actionRects, isEmpty);
    });

    test('single action lays out correctly', () {
      final g = UiContourActionGeometrySolver.solve(
        _input(1, actionSizes: const [Size(44, 44)]),
      );
      expect(g.outerSize.width, 80 + 8 + 44);
      expect(g.actionRects.single.left, 88);
    });

    test('four actions all resolve to distinct, ordered, non-overlapping rects',
        () {
      final g = UiContourActionGeometrySolver.solve(
        _input(
          1,
          actionSizes: const [
            Size(36, 36),
            Size(36, 36),
            Size(36, 36),
            Size(36, 36)
          ],
        ),
      );
      for (var i = 1; i < g.actionRects.length; i++) {
        expect(
          g.actionRects[i].left,
          greaterThanOrEqualTo(g.actionRects[i - 1].right),
        );
      }
    });
  });

  group('varying spacing and sizes', () {
    test('larger spacing increases outer width proportionally at rest', () {
      final tight = UiContourActionGeometrySolver.solve(_input(1, spacing: 4));
      final loose = UiContourActionGeometrySolver.solve(_input(1, spacing: 16));
      expect(loose.outerSize.width, greaterThan(tight.outerSize.width));
    });

    test('taller action increases row height, actions vertically centered', () {
      final g = UiContourActionGeometrySolver.solve(
        _input(1, actionSizes: const [Size(40, 60), Size(40, 40)]),
      );
      expect(g.outerSize.height, 60);
      expect(g.actionRects[0].top, 0);
      expect(g.actionRects[1].top, 10);
      expect(g.triggerRect.top, 10);
    });
  });
}
