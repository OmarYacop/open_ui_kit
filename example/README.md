# Open UI Kit examples

This package contains two runnable example entry points.

## Visual showcase

The showcase is the fastest way to explore the kit's visual language and major
component families. It uses only the public `open_ui_kit.dart` API and adapts
from a two-column workspace to a single-column mobile layout.

```bash
flutter run -t lib/showcase.dart
```

Use the appearance button in the header to switch between the package's light
and dark token sets.

## Contour motion demo

The default entry point focuses on Contour motion, bottom-tab accessories,
crossfades, RTL behavior, and reduced motion.

```bash
flutter run
```

## Refreshing README images

The repository's README images are rendered from the real showcase widgets on
macOS. This is separate from the package's regression golden tests and does not
modify their baselines.

```bash
flutter test tool/capture_showcase_test.dart
```

The command writes light and dark overview images plus focused component-family
previews for actions, forms, data display, chat, feedback, navigation, and
pickers. Review every affected file in `../doc/assets/showcase/` before
committing it. Do not regenerate these images for unrelated code changes.
