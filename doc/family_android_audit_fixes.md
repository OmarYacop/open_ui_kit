# Family Android audit implementation

Tracking: [OMA-68](https://linear.app/omar-yacop/issue/OMA-68) (Open UI Kit),
[OMA-69](https://linear.app/omar-yacop/issue/OMA-69) (LMS Mobile), based on
[OMA-67](https://linear.app/omar-yacop/issue/OMA-67). Local changes await review.

| Report / request | Implementation |
| --- | --- |
| Header/status legibility | `UiScrollEdgeFade.topProtectionExtent` protects fixed chrome with a translucent material (never forced opaque) before tapering. Page scaffolds use the renderer capability gate; conversation history remains full-bleed. LMS no longer disables chat fades on Android. |
| Navigation mid-word breaks | Expanded columns retain the compact slot count. Single-line labels ellipsize; long localized words do not add rows. |
| Summary truncation | LMS statistics use fewer columns at narrow/scaled widths; child summaries measure labels and adapt columns, with wrapping when a label exceeds a full-width cell. |
| Notification filter clipping | LMS moves horizontal insets inside the scroll viewport. |
| Inconsistent heading origins | Extra fade clearance no longer shifts the expanded title/action anchor on custom sliver pages. |
| Duplicate voice timestamp | The outer message receipt owns the timestamp; voice content retains playback duration. |
| Library date truncation | Horizontal cards separate category and date, reduce compact preview width, and grow height with text scale. |
| Successful-empty requests | Remove error-like Retry from successful empty results; error Retry remains. |
| Recording latency / abrupt mode | LMS presents a pending deck immediately, disables Finish until native capture starts, and serializes cancellation/disposal with startup. The kit reuses input/deck widgets during geometry frames and retains the closing control through reversal. |
| Back/menu polish | Larger back chevron and labeled-back typography, larger LMS chat menu glyphs, 17px compact titles. Menu labels use body-small, 17px icons, 8px vertical / 10px horizontal row padding. |
| Latest / @ controls | Matching 34px visual heights with compact label text and padding, growing together for larger text settings. Separate 44px minimum hit targets prevent the @ surface from stretching. Count changes do not restart entrance animation; reduced motion skips transitions. |
| Reply preview / return stack | Nearby reveals scroll to a measured clear position. Unknown variable-height targets fade out, seek without displaying estimates, and fade in once positioned. New navigation and touch interrupt safely. Already-visible messages stay put. |

## Verification and limits

Focused tests cover distant variable-height replies, interrupted navigation,
nested LMS return stacks, 360px/1.15 navigation in LTR/RTL, 1.15x/2x library
years and child labels, pending recorder presentation, denied permission, and
disposal during native startup. Existing compatibility APIs remain available.

`chat.voice.start` profile timeline markers separate permission resolution,
file-location lookup and native recorder readiness. No real-device microphone
startup duration is claimed: the Android device disconnected before the separate
synthetic profile preview could be installed. The preview APK built successfully;
local Flutter-rendered synthetic images are layout evidence, not live Android
or iOS parity evidence.

The required `./scripts/ci changed` and LMS analysis/tests are run and recorded
on the linked issues. Golden differences must be reviewed; no golden baselines,
release tags, or deployed apps are changed by this work. The working trees also
contain unrelated concurrent changes, so their full-suite results are recorded
separately from the targeted regression results.

Follow-up: search keyboard avoidance keeps a stable page subtree, preserving scroll/header state. Phone fade/clearance is restored to 128px, with a gentler smoothstep blur ramp on Apple. Back/menu visual surfaces are smaller with retained tap targets; back chevrons receive a mirrored optical offset. Conversation titles are single-line with unread counts on the title row. LMS learner setup is a Security tile and a canonical navigation/radio-selection page.

September 9 correction: progressive blur remains enabled on Apple platforms; Android uses its historical surface gradient without blur. The header protection plateau is removed. Sender identity in LMS previews takes width before message text. Icon surfaces keep their declared visual size even within tight chat slots. Android exit history recorded a foreground LOW_MEMORY termination at 08:02:53 on September 9; it does not attribute the heat or memory pressure to blur.

Latest sizing/blur follow-up: medium icon buttons use fixed 40px visual surfaces and 22px icons independently of system text scale. Back chevrons stay 30px with 5px inset; touch targets stay at least 44px. Android progressive top blur is re-enabled alongside Apple, with bounded sampling and explicit opt-out retained. Device text settings are unchanged.

Latest control refinement: medium icon surfaces are now 44px, with 32px back chevrons and 6px inset. Navigation menu actions inherit the same 44px surface; class-card menus match their primary action's painted height at 100% and 115% text scale.

Header-gap correction: live Chats screenshots showed approximately 72 logical pixels from title glyph bottom to first card on Android versus 40 on iPhone. The shared header/content page forced resting content below an absolute 128px fade boundary, adding excess empty space when the status-bar inset was smaller. Navigation now owns title-to-content spacing without that extra floor; header geometry reserves the actual fixed 44px actions. Fade painting and the 128px phone fade extent are retained. Regression coverage compares safe-top 24/59 and text scales 1/1.15 on iOS and Android.
