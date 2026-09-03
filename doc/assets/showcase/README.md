# Showcase assets

The PNG files in this directory are documentation captures of
`example/lib/showcase.dart`. They are generated from real Open UI Kit widgets,
not design mockups or regression golden baselines.

From the `example/` directory on macOS, run:

```bash
flutter test tool/capture_showcase_test.dart
```

The capture tool loads the local system font only while rendering readable
documentation screenshots. The font is not copied into the repository or
distributed with the package. It also loads Lucide's bundled icon font so the
capture matches the runnable example.

Before committing refreshed images, inspect both light and dark files and run
the responsive showcase test:

```bash
flutter test test/showcase_test.dart
```
