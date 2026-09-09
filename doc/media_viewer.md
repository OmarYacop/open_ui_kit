# Media viewer pages

Use `UiMediaViewerPage` from `patterns/layout.dart` as the route root for images,
video and document viewers. Media fills the entire viewport, including the area
behind system insets. Canonical navigation, metadata and footer actions overlay
that canvas and keep their controls inside safe insets. Chrome uses a dark media
palette in either app theme; the media child retains the application's tokens.

Tap the media to hide or reveal chrome without resizing or remounting the media.
Child controls keep their own gestures. Screen-reader navigation keeps controls
visible. Back and Escape dismiss the route (or call `onDismiss`). Hidden chrome
is excluded from pointer, focus and semantics traversal. Reduced motion is honored.

```dart
void dismiss() => Navigator.maybePop(context);

UiMediaViewerPage(
  title: fileName,
  dismissLabel: localizedBackLabel,
  subtitle: description,
  onDismiss: dismiss,
  actions: [detailsButton],
  footer: downloadButton,
  child: UiMediaGallery(
    dismissLabel: localizedBackLabel,
    showChrome: false,
    onDismiss: dismiss,
    items: [
      UiMediaGalleryItem(
        builder: (_) => Image(image: imageProvider, fit: BoxFit.contain),
      ),
    ],
  ),
)
```

Use `BoxFit.contain` to see the whole image without cropping. A full-screen
canvas can still have letterboxing when the media and screen have different
aspect ratios. The gallery supplies pinch/double-tap zoom and paging. Forward
custom dismissal to both widgets so gallery swipes and navigation agree.

The application owns loading, authentication, errors, saving and playback.
Do not add another scaffold or safe area around this page. Keep player controls
inside the media child. For multiple gallery items, use the gallery's built-in
chrome until page-level selection metadata is managed by the caller. Existing
standalone `UiMediaGallery` behavior remains unchanged. Fullscreen here means
using the route viewport; the page does not change global OS system-UI mode.

## UX reference

WhatsApp's [media help](https://faq.whatsapp.com/1096027074615511/?cms_platform=web)
describes fullscreen in-app previews. The design lesson applied here is to keep
viewing in the media context and let controls overlay the content. This is not a
copy of WhatsApp's visual UI or a claim of identical gestures across its clients.

Pass `caption` for text that belongs to the media. It sits above `footer` on a
legibility scrim, with a bounded scroll region for long captions; no caption
means no empty caption panel. The media bounds stay unchanged. Applications
can supply formatted text and its content direction. Keep playback controls in
`footer` when captions are present so neither overlaps the other.

For video players, bind `chromeVisible` and `onChromeVisibilityChanged` to the
player's control state. Timer-driven hiding and media taps then coordinate the
navigation, caption and playback controls. Keep chrome visible while an action
menu is open and honor screen-reader accessibility in the player's own timer.
