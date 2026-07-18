# Motion Contract

Open UI Kit motion is part of the design-token contract. Components should
resolve timing and easing through `UiThemeTokens.of(context).motion` instead
of hardcoding durations or curves for structural UI transitions.

## Tokens

- `instant` is for no-transition state changes.
- `fast` is for direct interaction feedback and small affordance changes.
- `standard` is for component entrance, exit, expansion, collapse, and route-like transitions.
- `slow` is for larger layout or navigation chrome changes where users need to track position.
- `standardCurve` is the default easing for structural UI motion.
- `emphasizedCurve` is reserved for deliberate, small emphasized feedback.
- `linearCurve` is for progress, deterministic reduced motion, and non-eased values.

## Reduced Motion

`UiThemeTokens.of(context)` respects `MediaQuery.disableAnimations`. When that
preference is enabled, resolved motion tokens use zero durations and linear
curves. Components that use `tokens.motion` inherit the behavior automatically.

Custom component code should not read `MediaQuery.disableAnimations` directly
unless it is implementing a behavior that cannot be expressed with duration
and curve tokens. Prefer:

```dart
final motion = UiThemeTokens.of(context).motion;

AnimatedContainer(
  duration: motion.standard,
  curve: motion.standardCurve,
  // ...
)
```

## Component Guidance

- Animate changes that clarify cause and effect: press feedback, menus, dialogs,
  sheets, drawers, tabs, collapsible regions, and navigation changes.
- Use `UiFadeScaleTransition` for in-place structural entrances such as
  dialogs, popovers, and anchored menus.
- Use `UiSlideFadeTransition` for directional structural entrances such as
  sheets, tab changes, and navigation chrome. Fractional offsets match
  `SlideTransition`; logical-pixel offsets are available for compact overlay
  reveals.
- `UiApp` route fades must visually collapse under reduced motion. Route
  settling can still be owned by Flutter's route lifecycle, but the transition
  should not interpolate opacity when motion is reduced.
- Avoid decorative motion that does not explain state, hierarchy, or continuity.
- Do not use token durations for timers, debounce windows, network timeouts, or
  cache lifetimes. Those are product or infrastructure timings, not UI motion.
- Loading spinners and progress indicators are continuous feedback. Keep their
  loop timing local until the kit defines a dedicated loading-indicator policy.
- When adding a new structural animation, include a reduced-motion test that
  verifies it reaches its final state without waiting for elapsed time.

## Existing Exceptions

`UiStackedMotion` keeps shared geometry and default timings for stacked overlay
surfaces such as drawers. Components using it must still collapse those timings
to zero when resolved motion tokens are reduced.

Interactive back-swipe motion is gesture-driven. Drag progress follows pointer
movement directly; only settle/cancel animations should resolve token durations
and curves.
