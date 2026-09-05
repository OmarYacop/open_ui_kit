# Showcase assets

The PNG files in this directory are documentation captures of
`example/lib/showcase.dart` and `example/lib/component_previews.dart`. They are
generated from real Open UI Kit widgets, not design mockups or regression
golden baselines.

From the `example/` directory on macOS, run:

```bash
flutter test tool/capture_showcase_test.dart
```

The capture produces a light and dark overview plus focused actions, forms,
data display, chat, feedback, navigation, and picker scenes. The tool loads the
local system font only while rendering readable documentation screenshots. The
font is not copied into the repository or distributed with the package. It also
loads Lucide's bundled icon font so the capture matches the runnable example.

Before committing refreshed images, inspect every affected light and dark file
and run the responsive showcase and component-preview tests:

```bash
flutter test test/showcase_test.dart
flutter test test/component_previews_test.dart
```
