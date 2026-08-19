import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

const _checkpoints = [0.0, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.92, 0.99, 1.0];

UiContourAccessoryGeometryInput _input(
  double progress, {
  Size barSize = const Size(320, 48),
  Rect sourceRect = const Rect.fromLTWH(280, 4, 40, 40),
  Size accessorySize = const Size(140, 40),
}) {
  return UiContourAccessoryGeometryInput(
    barSize: barSize,
    sourceRect: sourceRect,
    accessorySize: accessorySize,
    progress: progress,
  );
}

void main() {
  group('endpoints', () {
    test('progress 0: bar is full size, accessory sits at its source rect', () {
      final g = UiContourAccessoryGeometrySolver.solve(_input(0));
      expect(g.barRect, const Rect.fromLTWH(0, 0, 320, 48));
      expect(g.accessoryRect, const Rect.fromLTWH(280, 4, 40, 40));
      expect(g.accessoryVisibility, 0);
      expect(g.accessoryInteractive, isFalse);
    });

    test(
        'progress 1: bar recedes by exactly the accessory width; accessory reaches full size at the freed edge',
        () {
      final g = UiContourAccessoryGeometrySolver.solve(_input(1));
      expect(g.barRect, const Rect.fromLTWH(0, 0, 180, 48));
      expect(g.accessoryRect, const Rect.fromLTWH(180, 4, 140, 40));
      expect(g.accessoryVisibility, 1);
      expect(g.accessoryInteractive, isTrue);
    });

    test('the two surfaces never overlap at rest', () {
      final g = UiContourAccessoryGeometrySolver.solve(_input(1));
      expect(g.barRect.right, lessThanOrEqualTo(g.accessoryRect.left + 0.001));
    });
  });

  group('monotonicity (no snap, no recoil)', () {
    test('bar width is monotonically non-increasing across checkpoints', () {
      double? previous;
      for (final t in _checkpoints) {
        final width =
            UiContourAccessoryGeometrySolver.solve(_input(t)).barRect.width;
        if (previous != null) {
          expect(width, lessThanOrEqualTo(previous + 0.001),
              reason: 'bar regrew at t=$t');
        }
        previous = width;
      }
    });

    test(
        'accessory right edge is monotonically non-decreasing across checkpoints',
        () {
      double? previous;
      for (final t in _checkpoints) {
        final right = UiContourAccessoryGeometrySolver.solve(_input(t))
            .accessoryRect
            .right;
        if (previous != null) {
          expect(right, greaterThanOrEqualTo(previous - 0.001),
              reason: 'at t=$t');
        }
        previous = right;
      }
    });

    test(
        'reverse traversal mirrors forward traversal exactly (same function of t)',
        () {
      final forward = [
        for (final t in _checkpoints)
          UiContourAccessoryGeometrySolver.solve(_input(t))
      ];
      final reversed = [
        for (final t in _checkpoints.reversed)
          UiContourAccessoryGeometrySolver.solve(_input(t)),
      ].reversed.toList();
      for (var i = 0; i < forward.length; i++) {
        expect(forward[i].barRect, reversed[i].barRect);
        expect(forward[i].accessoryRect, reversed[i].accessoryRect);
      }
    });
  });

  group('finiteness and bounds', () {
    test('no negative sizes and all rects finite at every checkpoint', () {
      for (final t in _checkpoints) {
        final g = UiContourAccessoryGeometrySolver.solve(_input(t));
        expect(g.barRect.width.isFinite, isTrue);
        expect(g.barRect.width, greaterThanOrEqualTo(0));
        expect(g.accessoryRect.width.isFinite, isTrue);
        expect(g.accessoryRect.width, greaterThanOrEqualTo(0));
      }
    });

    test('progress outside [0,1] is clamped, not extrapolated', () {
      final over = UiContourAccessoryGeometrySolver.solve(_input(1.5));
      final atOne = UiContourAccessoryGeometrySolver.solve(_input(1));
      expect(over.barRect, atOne.barRect);
      expect(over.accessoryRect, atOne.accessoryRect);
    });

    test('accessory width never exceeds its natural size', () {
      for (final t in _checkpoints) {
        final g = UiContourAccessoryGeometrySolver.solve(_input(t));
        expect(g.accessoryRect.width, lessThanOrEqualTo(140.0001));
      }
    });

    test(
        'bar width never goes negative even if accessory is wider than the bar',
        () {
      final g = UiContourAccessoryGeometrySolver.solve(
        _input(1,
            barSize: const Size(100, 48), accessorySize: const Size(140, 40)),
      );
      expect(g.barRect.width, 0);
    });
  });

  group('activation threshold', () {
    test('accessory becomes interactive only at/after 0.92', () {
      expect(
          UiContourAccessoryGeometrySolver.solve(_input(0.91))
              .accessoryInteractive,
          isFalse);
      expect(
          UiContourAccessoryGeometrySolver.solve(_input(0.92))
              .accessoryInteractive,
          isTrue);
    });
  });

  group('bar content visibility', () {
    test('fades out over the first half of the transition and stays at 0 after',
        () {
      expect(
          UiContourAccessoryGeometrySolver.solve(_input(0))
              .barContentVisibility,
          1);
      expect(
          UiContourAccessoryGeometrySolver.solve(_input(0.5))
              .barContentVisibility,
          0);
      expect(
          UiContourAccessoryGeometrySolver.solve(_input(0.75))
              .barContentVisibility,
          0);
    });
  });
}
