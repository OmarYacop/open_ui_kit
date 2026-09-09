# OTP input

`UiOtpInput` renders one editable verification code as slots, using the same
field frame, typography, surfaces, borders and focus rings as `UiInput`.
It is inspired by the [official shadcn Input OTP](https://ui.shadcn.com/docs/components/aria/input-otp).

```dart
import 'package:open_ui_kit/open_ui_kit.dart';

UiOtpInput(
  label: 'Verification code',
  helper: 'Enter the six-digit code.',
  length: 6,
  groupLength: 3,
  onChanged: (code) {},
  onCompleted: (code) {},
)
```

Omit `groupLength` for one joined group. Set `length: 4` for a PIN or use
`type: UiOtpInputType.alphanumeric` for ASCII letters and digits. User input
filters other characters, including spaces and hyphens in pasted codes, and
stops at `length`. Platform one-time-code autofill is requested; availability
depends on the OS and application setup.

Use `controller` or `initialValue`, never both. External controllers and focus
nodes remain caller-owned. Programmatic values must satisfy the configured
length and character mode; input formatters apply only to user edits.
`onCompleted` runs when a user edit produces a complete value, including a
replacement; it does not submit, unfocus, or authenticate automatically.
Selection changes and controller assignments do not invoke change/completion
callbacks. `onSubmitted` handles the keyboard's Done action separately.

Tap a filled slot to replace it. Standard keyboard selection, copy, paste,
and deletion operate on the single value. Long-press opens the editing menu.
`readOnly` permits focus/copy; `enabled: false` locks interaction. Use
`errorText` for the shared live error announcement and `semanticLabel` to
override the field's spoken label. Code order stays LTR within RTL forms;
labels and helper text follow the surrounding direction. Slots retain their
control size and scroll horizontally when space is tight; text scaling grows
the slot height. Use `UiFormFieldView<String>` for typed form integration.
