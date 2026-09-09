# Page edge clearance

`UiPageScaffold` paints fades over the scrolling body. System safe areas alone
are insufficient: Android often has less bottom padding than the 48px fade.
The scaffold now publishes the larger of each consumed system safe inset and
its active fade extent through `UiPageBodyInsets`. Default clearance is 128px
at the top (72px on wide viewports) and 48px at the bottom. Disabled edges add
no fade clearance. Hardware clearance remains in effect.

Use `scrollFadeTopClearance` and `scrollFadeBottomClearance` on the scaffold to
customize resting clearance. Null follows the corresponding fade extent;
zero keeps only the consumed system safe inset. Existing
`scrollFadeUsesSafeArea: false` opts out of this content-inset policy.

Form and collection page patterns consume these insets automatically.
`UiContentPage` subtracts the space already occupied by its sliver header from
the required top clearance. For custom scrollables, read the insets inside the
scaffold body and add them to content padding, not outside the scroll view:

```dart
UiPageScaffold(
  scrollFadeBottomClearance: 64,
  body: Builder(
    builder: (context) => ListView(
      padding: UiPageBodyInsets.of(context) +
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: children,
    ),
  ),
)
```

When a custom scroll view has a sliver header, subtract that header's resting
extent from the top clearance so it is not counted twice. Keep fixed actions
in `bottomBar`, outside the faded body. An arbitrary non-scrollable body can
apply the published insets with `Padding`; the scaffold cannot inject padding
inside an application-owned scrollable automatically.

`UiChatHeader` uses equal square back and avatar slots: `controlExtent` defaults
to 44 and follows the same capped chrome scale as the navigation back button.
The trailing avatar is fitted to its slot, including its generated Wavatar.
Use an accessible avatar action and a chevron-only `UiNavigationBackButton`.
Titles remain centered when they fit; long titles use the measured space
between controls before truncating. This also applies to compact sliver titles.

Sliver navigation also reserves internal bottom clearance: 12px below the
expanded title/subtitle/action group and 8px below compact controls. Titles and
title-following actions share a vertical anchor. The height budget grows when enlarged text or chrome needs more room.

Expanded sliver headers reserve the subtitle line even when it is absent, so
title-only pages and pages with subtitles/actions share the same title position.
For title-only headers with title-following actions, unused subtitle space is
removed from the sliver layout height while the title anchor stays unchanged.
This brings the following content closer without shifting the title or action.
Reclaimed space is limited by the active scaffold top-fade clearance.

When fade clearance enlarges a title-only action header beyond its natural
height, the shared title/action anchor moves down by the added height. This
retains 12px below the row rather than collecting clearance in a blank band
between the heading and the first item (especially with Android status insets).
The fade extent and content start remain unchanged.
