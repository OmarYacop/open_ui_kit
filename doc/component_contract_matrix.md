# Component contract coverage

This matrix names executable evidence, not blanket accessibility certification.
`Covered` means a focused regression exists for the listed contract. Unlisted states
remain follow-up work. Tests run through `./scripts/ci quality` and `examples`.

| Surface | Covered contracts | Evidence | Still to exercise |
| --- | --- | --- | --- |
| Shared fields: input, slider, rating | One live error announcement; error replaces helper; visible label | `test/components/field_frame_test.dart` | Hardware screen-reader navigation |
| Slider | RTL pointer/keyboard mapping; final value callbacks | `test/components/audit_regressions_test.dart` | Preference changes during drag |
| Rating | 48px targets; RTL half fill | `test/components/audit_regressions_test.dart` | Very large counts in constrained parents |
| Tooltip | Narrow overlay; moving anchor; Escape; keyboard focus | `test/components/tooltip_placement_test.dart`, `accessibility_audit_test.dart` | Nested platform overlays |
| Date picker | Arabic date, navigation and mode announcements; keyboard traversal | `test/components/localized_feedback_test.dart`, `test/pickers/pickers_test.dart` | Physical VoiceOver/TalkBack traversal |
| Gallery | Shrinking/empty lists; zoom limits | `test/components/audit_regressions_test.dart` | Gesture interruption on hardware |
| Showcase | Light/dark, 390/600/1024px, 1x/2x text | `example/test/showcase_adaptive_test.dart` | 3x text; landscape keyboard |
| Layer boundaries | Foundation → components → patterns; exact UiApp exceptions; no Material/Cupertino imports | `test/architecture/layer_boundaries_test.dart` | Review any new exception with an ADR |

For every new public input, require empty/disabled/error states, keyboard and
semantics behavior, RTL, long labels, and dynamic data tests. Reuse fixtures where
they express the same contract. Do not create nominal tests just to fill a cell.
Golden baselines require explicit authorization; behavioral assertions do not.
