# Visual-effects budgets

Open UI Kit resolves costly visual effects through `UiEffectsTokens`.

## Resolution order

1. `OPEN_UI_EFFECTS_LEVEL=full|reduced` selects a build-wide level when set.
2. Otherwise, the theme's `UiEffectsTokens.level` is used.
3. `adaptive` resolves to `full` on iOS/macOS and `reduced` elsewhere.
4. Reduced-motion or accessible-navigation preferences reduce the result.
5. `OPEN_UI_ENABLE_BACKDROP_FILTERS=false` disables every kit-owned backdrop
   filter regardless of the runtime or theme selection.

The theme is an upper budget, not a request to add blur everywhere. A component
must still opt into its own effect through properties such as `blurred` or
`blurBackdrop`.

## Container transforms

`UiOpenContainer` uses `UiContainerBackdropSpec` for its iOS-style route:

```dart
UiOpenContainer(
  backdrop: const UiContainerBackdropSpec(), // adaptive
  pathMotion: UiContainerPathMotion.centerPull,
  centerPullStrength: 0.65,
  // ...
)
```

Adaptive mode uses a capped blur plus tint when the resolved effects budget is
full. It falls back to tint-only separation when backdrop filters or animated
blur are unavailable. Both treatments are removed at the animation endpoints,
so an invisible backdrop filter is not retained while the destination page is
settled.

Callers can explicitly choose `UiContainerBackdropSpec.blur`,
`UiContainerBackdropSpec.tint`, or `UiContainerBackdropSpec.none`. The tint
path is a simple alpha-blended color fill and is the preferred fallback for
constrained devices.

## Theme configuration

```dart
final androidFriendlyTheme = UiThemeData.light(
  effects: const UiEffectsTokens(
    level: UiEffectsLevel.reduced,
    enableBackdropBlur: false,
    blurScale: 0.25,
    animateBlur: false,
  ),
);
```

For `UiApp`, pass tokens containing the desired effects budget through
`lightTokens` and `darkTokens`.

## Build configuration

```bash
flutter build appbundle \
  --dart-define=OPEN_UI_EFFECTS_LEVEL=reduced \
  --dart-define=OPEN_UI_ENABLE_BACKDROP_FILTERS=false \
  --dart-define=OPEN_UI_BLUR_SCALE_PERCENT=25

flutter build ipa \
  --dart-define=OPEN_UI_EFFECTS_LEVEL=full \
  --dart-define=OPEN_UI_ENABLE_BACKDROP_FILTERS=true \
  --dart-define=OPEN_UI_BLUR_SCALE_PERCENT=100
```

Keep the same declarations in local run configurations, CI, and release
automation so profiling matches shipped builds.
