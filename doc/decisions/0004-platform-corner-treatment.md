# ADR 0004: Platform-adaptive corner treatment

- Status: Proposed
- Date: 2026-09-06
- Issue: [OMA-42](https://linear.app/omar-yacop/issue/OMA-42/add-stacked-fluid-nested-menus)

## Context

Apple menu surfaces should use continuous corners while other platforms keep
circular rounded corners. Trigger, moving surface, outline, blur clip and menu
hit regions must agree. Radius magnitude and animation timing remain independent.

## Decision

Add `UiCornerStyle.platform`, `circular` and `continuous` to `UiRadiusTokens`.
The default resolves iOS/macOS to continuous; Android, Windows, Linux and Fuchsia
to circular. Apps can explicitly override it through the existing radius tokens.
Use Flutter's `RoundedSuperellipseBorder` and `ClipRSuperellipse`, with no custom
shader, dependency, Material/Cupertino import or platform channel.

Use `defaultTargetPlatform`, which Flutter's native implementation marks with
`vm:platform-const-if` outside debug mode. Native AOT can fold platform selection;
we do not require custom compiler pragmas, per-client build scripts or defines.
Debug platform overrides still work. Web is a shared browser artifact and must
resolve the host platform at runtime. This is not a promise that the unused shape
implementation is absent from a binary: explicit theme overrides keep both styles
available. No benchmark or binary-size reduction is claimed.

Adopt shared selection in UiBox, focus rings, menu trigger fallback, root/nested
moving surfaces and menu corner clips. Custom app decorations are unchanged.
UiBox nonuniform edge borders retain their existing circular BoxDecoration
behavior because a superellipse outline has one uniform BorderSide. Their clips
use the same fallback. Rectangular minimum button tap targets remain accessible;
menu surface hit clips follow the actual outline.

## Alternatives

A fixed build define would need application-specific build configuration and could
select the wrong shape for web users. A custom squircle path would duplicate
framework rendering and introduce drift between painting and clipping.

## Verification

Test each platform default, explicit overrides, token copying/interpolation, RTL
corner mirroring and surface clip/hit alignment. Preserve existing motion tests
and golden baselines; run changed CI. Visual acceptance remains user-owned.

## References

- [Flutter rounded-superellipse API](https://api.flutter.dev/flutter/painting/RoundedSuperellipseBorder-class.html)
- [Flutter native platform selection](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/foundation/_platform_io.dart)
