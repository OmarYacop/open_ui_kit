# Open UI Kit Quality Policy

## Test Matrix

Run from the repository root:

```bash
flutter analyze --no-pub
flutter test --no-pub
flutter test test/goldens/async_states_golden_test.dart --no-pub
flutter test test/goldens/core_components_golden_test.dart --no-pub
```

CI parity:

- `quality` job (Ubuntu): `flutter analyze --no-pub` + `flutter test --no-pub`
- `goldens` job (macOS 14): both golden suites with fixed host

## Golden Policy

- Goldens are authoritative UI snapshots for token-driven components.
- Golden host is fixed and deterministic:
  - OS: `macos-14` in CI
  - Locale: `en_US`
  - DPR: `1.0`
  - Platform override: `TargetPlatform.macOS`
- Golden tests must use `test/goldens/golden_test_host.dart`.

## Update Protocol

Use this protocol when UI changes are intentional:

1. Update widgets/tests.
2. Regenerate only impacted baselines:

   ```bash
   flutter test test/goldens/async_states_golden_test.dart --update-goldens
   flutter test test/goldens/core_components_golden_test.dart --update-goldens
   ```

3. Re-run full parity commands (analyze + test + both golden suites).
4. Include before/after rationale in PR notes.

## Flake Handling Rules

- Treat every flaky failure as a bug until proven environmental.
- First retry once on the same commit.
- If retry passes, still capture suspicion in PR notes.
- If retry fails:
  - reduce animation timing sensitivity in test,
  - remove implicit timing assumptions (`pumpAndSettle`/explicit durations),
  - isolate host-dependent behavior under golden host helpers.
- Do not merge while an unexplained flaky test remains.

## Deterministic-test patterns

These patterns keep tests deterministic without sacrificing coverage and
should be used for new tests in the kit.

### Platform overrides must be cleared inside the test body

`debugDefaultTargetPlatformOverride` is a foundation debug var;
Flutter's `debugAssertAllFoundationVarsUnset` runs **before**
`addTearDown` callbacks fire, so a late `tearDown(() { ... = null; })`
is too late — the test is reported as having leaked state and
fails the invariants check.

Use a `runWith` wrapper that clears inside a `try/finally`:

```dart
Future<T> runWith<T>(
  TargetPlatform p,
  Future<T> Function() body,
) async {
  debugDefaultTargetPlatformOverride = p;
  try {
    return await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

testWidgets('iOS-only affordance', (tester) async {
  await runWith(TargetPlatform.iOS, () async {
    // ... body
  });
});
```

Canonical usage: `test/patterns/navigation_edge_swipe_test.dart`,
`test/patterns/navigation_edge_swipe_interactive_test.dart`.

### Viewport sizing must be hermetic

When a test needs a specific form factor or a non-default viewport,
set `tester.view.physicalSize` + `devicePixelRatio = 1` and register
`addTearDown(tester.view.reset)` immediately. Wrapping a subtree in
`MediaQuery(data: MediaQueryData(size: ...))` **only** affects
descendants that read `MediaQuery.sizeOf`; anything that pushes a
route onto the root navigator (e.g. `UiSheetScope.show`) sees the
view's physical size, so an inner MediaQuery override silently
fails there.

```dart
void useViewSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
```

Canonical usage: `test/surfaces/sheet_responsive_test.dart`.

### Scroll-arbitration tests: prefer `ClampingScrollPhysics`

`BouncingScrollPhysics` reports exponentially-damped overscroll via
`OverscrollNotification` — the raw pixels the finger traveled are
NOT the pixels your handler sees. That makes threshold-based
assertions brittle and creates false failures after unrelated
physics changes in upstream Flutter.

`ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics())`
reports the full past-boundary delta, so fixture drags map 1-for-1
to drive adjustments and failures point at real bugs instead of
physics damping:

```dart
ListView.builder(
  physics: const ClampingScrollPhysics(
    parent: AlwaysScrollableScrollPhysics(),
  ),
  // ...
)
```

Canonical usage: `test/surfaces/persistent_sheet_scroll_test.dart`.

### Semantics queries inside widget tests

`find.bySemanticsLabel` requires the rendered semantics tree,
which needs a `tester.ensureSemantics()` handle — and that handle
leaks `SemanticsHandle` at end-of-test, failing the invariants
check. For kit-internal tests, prefer the widget-tree predicate:

```dart
expect(
  find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == 'Sheet',
  ),
  findsOneWidget,
);
```

This reads the declarative `Semantics` widget properties without
enabling the rendered semantics tree — no leak, still reports label
mismatches cleanly. See `test/surfaces/surfaces_test.dart` and
`test/foundation/l10n_migration_test.dart`.

### Locale switching without `GlobalMaterialLocalizations`

The kit's package tests deliberately avoid depending on
`flutter_localizations`'s `GlobalMaterialLocalizations` (keeps the
package test surface small). To test components under an alternate
locale, use `Localizations.override` with an inline delegate that
returns a concrete `UiLocalizations` subclass:

```dart
class _InlineUiLocalizationsDelegate
    extends LocalizationsDelegate<UiLocalizations> {
  _InlineUiLocalizationsDelegate(this.value);
  final UiLocalizations value;
  @override bool isSupported(Locale _) => true;
  @override Future<UiLocalizations> load(Locale _) async => value;
  @override bool shouldReload(_InlineUiLocalizationsDelegate old) => false;
}

Widget hostWithStrings(Widget child, UiLocalizations strings) {
  return MaterialApp(
    theme: UiThemeData.light(),
    home: Builder(
      builder: (ctx) => Localizations.override(
        context: ctx,
        delegates: [
          _InlineUiLocalizationsDelegate(strings),
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        child: child,
      ),
    ),
  );
}
```

Canonical usage: `test/foundation/l10n_migration_test.dart`.

### RTL tests: use `Directionality` instead of a Locale

An RTL layout test does not need an Arabic locale or
`GlobalMaterialLocalizations`. Wrap the subtree in
`Directionality(textDirection: TextDirection.rtl)` — every
kit-internal component reads the ambient `Directionality` rather
than branching on the locale. This avoids the "locale not supported
by material delegates" warning that Flutter emits when the
configured locale lacks a material localization, which the test
framework reports as an unexpected exception.

### Sliver widgets need a box reference for `getRect`

A `SliverPersistentHeader` (or any sliver) doesn't have a
`RenderBox`, so `tester.getRect(find.byType(UiSliverNavigationBar))`
throws. Measure against the enclosing `CustomScrollView`'s box
instead, which gives the viewport bounds:

```dart
final viewport = tester.getRect(find.byType(CustomScrollView));
expect(titleBox.left, lessThan(viewport.center.dx));
```

### Rebuild-shape tests (prefer over frame-time assertions)

Wall-clock frame-time assertions are unreliable in CI. For
performance work, prefer **rebuild-shape assertions**: verify the
structural property that a perf change is supposed to guarantee.

Example: `UiTimePicker`'s ValueNotifier-based rebuild isolation is
validated by wrapping the picker in a build-counting canary and
asserting the canary's count is unchanged across a fling. See
`test/pickers/pickers_test.dart > UiTimePicker performance
behaviour`.

## Repeatability checks

Before a release, run analysis, the full test suite, and both golden suites
multiple times from a clean checkout. Any intermittent failure should be
treated as a flake and resolved using the deterministic-test patterns above.

## When a new test fails the CI matrix

1. **Reproduce locally** from a fresh checkout + `flutter clean` to
   rule out stale build artifacts.
2. **Run the failing test 5× in a row**. If it passes some of the
   time, it's a flake — apply the "Deterministic-test patterns"
   checklist above.
3. **If the failure is deterministic**, run
   `flutter test --plain-name "<test name>"` to isolate the
   stack trace, and attach it to the PR description.
4. **Do not disable tests** to unblock a PR. Add a `skip:` entry
   only with an explicit doc-comment referencing a tracked issue
   and an owner.
