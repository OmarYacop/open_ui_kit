# Progressive scroll-edge blur

Android and Apple platforms use their original continuous, two-pass progressive top blur
by default: sigma 14, a 12% tint hold, and tint opacity capped at .84. The bottom
edge mirrors the tint without blur. `enableProgressiveBlur: false` disables
blur while preserving the tint.

Android now uses the same progressive top blur as Apple platforms, including the
bounded sampling optimization. Other platforms retain supplied-surface gradients.
The explicit blur opt-out remains available. The header protection plateau remains removed.
The reported phone heat is not attributed to blur; Android recorded a low-memory
termination but did not identify its source.

Shader readiness preserves the existing page subtree, including form, focus and scroll state. Shader-load failure leaves the child and tint visible. Existing reduced-effects,
accessibility and build-time blur controls still apply on Android and Apple platforms.

The strength ramp uses smoothstep easing for a gentle onset and settling at
maximum blur; maximum sigma stays 14. Phone pages use the original 128px fade
region (wide pages remain 72px). Kernel, sampling resolution and tint are unchanged.
The capture region covers: the top extent plus a three-sigma sampling apron. The
rest of the child paints normally, clipped away from the filtered strip so
translucent pixels are not composited twice. At 390 × 844 logical pixels, DPR 3,
and a 128-point top fade, intermediate capture height is 142 instead of 844
points: about 83% fewer captured pixels. This is a workload/memory calculation,
not a measured FPS improvement.

`test/effects/progressive_blur_equivalence_test.dart` compares the cropped result
against the previous full-page pipeline using a patterned translucent scene.
The initial DPR-2 comparison differs by at most 1/255 per channel, with mean
absolute difference 0.028/255. The reference pipeline lives only in the test.
Temporary scenes/images/pictures are disposed; concurrent shader loads share
one future. Navigation also isolates its repainting and avoids allocating
zero-blur filters or redundant split controller listeners.

Physical Android profile validation remains required for frame-time claims.
The user is using the connected phone, so device testing was stopped. iOS
simulator inspection verifies appearance, not Android GPU performance. Do not
reduce sigma, kernel radius, resolution, or animation timing to meet a benchmark.

Flutter documents the renderer capability signal in
[ImageFilter.shader](https://api.flutter.dev/flutter/dart-ui/ImageFilter/ImageFilter.shader.html)
and advises profile-mode measurement in
[rendering performance](https://docs.flutter.dev/perf/rendering-performance).
