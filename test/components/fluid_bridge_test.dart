import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';
import 'package:open_ui_kit/src/components/surfaces/fluid_bridge_path.dart';

void main() {
  test('shared border has one connected contour, then separates cleanly', () {
    final source = UiFluidGeometry(const Rect.fromLTWH(0, 60, 180, 48), 24);
    final origin = UiFluidGeometry(const Rect.fromLTWH(132, 60, 48, 48), 24);
    final target = UiFluidGeometry(const Rect.fromLTWH(132, 5, 48, 48), 24);
    for (final continuous in [false, true]) {
      final joined = fluidUnionOutline(
        surfaces: [source, target],
        connections: [(origin, target, 1)],
        continuous: continuous,
      );
      expect(joined.contains(const Offset(156, 56)), isTrue);
      expect(joined.computeMetrics().length, 1);
      final split = fluidUnionOutline(
        surfaces: [source, target],
        connections: [(origin, target, 0)],
        continuous: continuous,
      );
      expect(split.contains(const Offset(156, 56)), isFalse);
      expect(split.computeMetrics().length, 2);
    }
  });

  const source = UiFluidGeometry(Rect.fromLTWH(0, 0, 48, 48), 24);
  test(
    'disconnected lobes remain beyond surface edges without spanning the gap',
    () {
      const target = UiFluidGeometry(Rect.fromLTWH(84, 0, 48, 48), 24);
      expect(
        fluidBridgePath(source, target, 1).contains(const Offset(66, 24)),
        isFalse,
      );
      final separated = fluidBridgePath(source, target, .7);
      expect(separated.contains(const Offset(54, 24)), isTrue);
      expect(separated.contains(const Offset(78, 24)), isTrue);
      expect(separated.contains(const Offset(66, 24)), isFalse);
      expect(fluidBridgePath(source, target, 0).computeMetrics(), isEmpty);
      const near = UiFluidGeometry(Rect.fromLTWH(60, 0, 48, 48), 24);
      expect(
        fluidBridgePath(source, near, 1).contains(const Offset(54, 24)),
        isTrue,
      );
    },
  );
  test('pinch has no discontinuous contour jump', () {
    final before = fluidBridgePath(
      source,
      const UiFluidGeometry(Rect.fromLTWH(83.99, 0, 48, 48), 24),
      1,
    );
    final after = fluidBridgePath(
      source,
      const UiFluidGeometry(Rect.fromLTWH(84.01, 0, 48, 48), 24),
      1,
    );
    var changed = 0;
    for (var x = 40; x < 92; x++) {
      for (var y = 0; y < 48; y++) {
        final point = Offset(x + .5, y + .5);
        if (before.contains(point) != after.contains(point)) changed++;
      }
    }
    expect(changed, lessThan(12));
  });
  test('late deformation is absorbed before its paint is removed', () {
    const target = UiFluidGeometry(Rect.fromLTWH(60, 0, 48, 48), 24);
    final surfaceA = RRect.fromRectAndRadius(
      source.rect,
      const Radius.circular(24),
    );
    final surfaceB = RRect.fromRectAndRadius(
      target.rect,
      const Radius.circular(24),
    );
    int exposed(double progress) {
      final path = fluidBridgePath(
        source,
        target,
        fluidBridgeStrength(progress),
      );
      var pixels = 0;
      for (var x = 40.125; x < 68; x += .25) {
        for (var y = .125; y < 48; y += .25) {
          final point = Offset(x, y);
          if (path.contains(point) &&
              !surfaceA.contains(point) &&
              !surfaceB.contains(point)) {
            pixels++;
          }
        }
      }
      return pixels;
    }

    final samples = [
      .62,
      .66,
      .70,
      .74,
      .78,
      .82,
      .86,
      .9,
    ].map(exposed).toList();
    expect(samples.first, greaterThan(100));
    for (var i = 1; i < samples.length; i++) {
      expect(samples[i], lessThanOrEqualTo(samples[i - 1]));
    }
    expect(
      samples[5],
      0,
      reason: 'No visible remnant may survive until the cutoff',
    );
  });
}
