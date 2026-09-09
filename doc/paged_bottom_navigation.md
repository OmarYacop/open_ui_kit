# Paged bottom navigation

`UiBottomTabScaffold` can expose many destinations through small sets in its
floating dock. It preserves the existing dock surfaces and uses fluid split/merge motion
to release separate previous/next arrow accessories. Browsing a set leaves the
current page and its state untouched; only selecting a destination calls
`onChanged`.

```dart
UiBottomTabScaffold(
  items: destinations,
  pages: pages,
  currentIndex: selectedIndex,
  onChanged: selectPage,
  overflowBehavior: UiBottomTabOverflowBehavior.paged,
  maxVisibleBottomItems: 3,
  navigationIndicatorIdleDuration: const Duration(milliseconds: 1200),
  bottomAccessory: searchAccessoryForSelectedPage,
)
```

The default overflow behavior remains `UiBottomTabOverflowBehavior.drawer`.
Explicit `bottomItems`, `bottomCurrentIndex`, or `onBottomChanged` keep their
existing manual behavior. Rails still receive every canonical destination.
Paged mode always uses floating chrome, regardless of `tabBarLayout`.

For an application-owned shell, use `UiPagedBottomTabBar` directly. It owns set
browsing, accessory retention, fluid timelines, and the idle indicator. Pass
it the selected index; it reveals that index's set when external selection
changes. The shell must reserve its height and keep its actual bounds above
the keyboard. Prefer the scaffold when those responsibilities are not already
owned by the application.

## Sets and arrow accessories

- Three destinations per set by default, including LMS. Applications can opt
  into four-slot end sets; intermediate sets reserve space for both arrows.
  Ordered ranges remain stable while browsing. `maxVisibleBottomItems` is an upper
  bound; the dock reduces capacity on unusually narrow viewports to retain
  44px destination targets. At 320px with default margins, three still fit.
- Sets are ordered, do not wrap, and may end with fewer destinations.
- No previous arrow on the first set, no next arrow on the last, and no arrows
  for a single set. An absent arrow retracts into the adjacent dock edge rather
  than occupying a disabled slot.
- The composition fills the available width, up to its configured maximum.
  The dock contracts as arrow surfaces separate. Dock edges and arrow bridges
  share a sampled `UiFluidController` spring, including interrupted transitions.
- The small position indicator appears when browsing or selecting a destination
  and fades after the idle delay. More than five sets use a compact fraction
  instead of an unbounded row of dots. The indicator reserves a fixed vertical
  slot, so hiding it never moves the navigation.

## Contextual search

Released arrows and search use the theme's medium elevation shadows for
contrast. Their shadows fade as the surfaces merge back into the dock.
The dock and accessories share one token-colored outer border. It follows the
union of their actual shapes and fluid bridges, so joining edges have no seams.

Use the existing `UiBottomTabAccessory` configuration. In paged mode its
collapsed control sits above the trailing edge of the navigation area; expansion
uses that row's available width without consuming destination slots. The
accessory's content and search controller remain application-owned.

When the selected page gains an accessory, it releases from the currently
visible next-chevron surface. If there is no next chevron, it releases from the
dock's trailing edge. Both origins share the same horizontal center, so compact
release and retraction travel vertically. The upper row sits 8px above the dock.

Browsing navigation sets does not change search scope or replay its release.
Switching between two searchable pages keeps the surface present and dissolves
its content with the existing Contour crossfade. When the selected page no
longer supplies an accessory, its last content remains mounted through the
exit. Presence uses `UiFluidSplit` with a connecting bridge; expansion shares
fluid spring geometry. Field contents retain their full layout width under the
animated outline clip. On close, field content fades early before the surface
contracts around the compact icon. Reversals retain current geometry and opacity.


A typical collapsed child is `UiIconButton`. Expanded content can be an embedded
`UiInput` and a close button. The application should close search and unfocus its
input when changing pages, and label the input with its scope. The scaffold
positions expanded accessory chrome above the reported keyboard inset in its
real layout bounds, preserving hit testing.

## Accessibility and verification

Arrow icons and layout mirror in RTL. Arrow labels and set announcements flow
through `UiLocalizations.previousDestinations`, `nextDestinations`, and
`destinationSet`. These have concrete English defaults so existing custom
localization subclasses remain source-compatible.

Only sufficiently emerged surfaces receive focus, pointer events, or semantics.
Fully retracted arrows are offstage. Focus moves back to the dock when a focused
arrow disappears. Reduced motion resolves through the existing kit motion
contract. Text height follows the text scaler; compact labels retain ellipsis.

The LMS example uses illustrative data and real local search:

```bash
cd example
flutter run -t lib/paged_navigation_main.dart
```

Use its destination-count button to try one, two, and three sets. Calendar and
Grades have no search accessory. Courses and Inbox exercise release from the
next-chevron and dock origins respectively. The example's search filters only
the selected page's entries.

Focused regression tests are in `test/components/paged_bottom_navigation_test.dart`.
No golden baselines are changed by this feature.
