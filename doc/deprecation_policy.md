# Deprecation policy

Open UI Kit announces public API migrations before removing compatibility
paths. Every new deprecation must identify its replacement and removal release
in `CHANGELOG.md`.

## Lifecycle

1. The release that introduces a replacement documents the canonical API and
   marks the old API or import path as deprecated.
2. Deprecated APIs remain available for the rest of the current major release
   line. During the pre-1.0 period, APIs with an announced `1.0.0` removal stay
   available through all `0.x` releases.
3. Removal happens only in the announced breaking release. The removal entry
   must appear under a **Removed** or **Breaking** heading in `CHANGELOG.md`.
4. Before removal, maintainers search supported downstream packages for the old
   API and provide the documented replacement.

When Dart supports `@Deprecated`, use it and include the replacement and removal
version in the message:

```dart
@Deprecated('Use NewApi instead. Scheduled for removal in 1.0.0.')
```

Dart cannot deprecate an `export` directive independently. For compatibility
exports, document the migration in the export's source comment and changelog,
and keep a test that imports the legacy path until its scheduled removal.

## Current scheduled removals

| Removed in | Deprecated API or path | Replacement |
| --- | --- | --- |
| `1.0.0` | `UiIntent` and `UiIntentPalette` through `components/forms.dart` or `button.dart` | Import them from `foundation.dart` or `open_ui_kit.dart` |

