import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  group('UiFormSubmitController', () {
    test('starts clean and valid by default', () {
      final controller = UiFormSubmitController(
        initialValues: {'email': 'a@b.com'},
      );
      addTearDown(controller.dispose);

      expect(controller.isDirty, isFalse);
      expect(controller.isValid, isTrue);
      expect(controller.canSubmit, isFalse);
      expect(controller.value, isFalse);
    });

    test('becomes dirty once a value differs, clean once reverted', () {
      final controller = UiFormSubmitController(
        initialValues: {'email': 'a@b.com'},
      );
      addTearDown(controller.dispose);

      controller.setValue('email', 'b@c.com');
      expect(controller.isDirty, isTrue);

      controller.setValue('email', 'a@b.com');
      expect(controller.isDirty, isFalse);
    });

    test('canSubmit requires both dirty and valid', () {
      final controller = UiFormSubmitController(initialValues: {'name': ''});
      addTearDown(controller.dispose);

      controller.setValid(false);
      controller.setValue('name', 'Ada');
      expect(controller.isDirty, isTrue);
      expect(controller.canSubmit, isFalse);

      controller.setValid(true);
      expect(controller.canSubmit, isTrue);
    });

    test('notifies listeners only when canSubmit actually flips', () {
      final controller = UiFormSubmitController(initialValues: {'name': ''});
      addTearDown(controller.dispose);

      var notifications = 0;
      controller.addListener(() => notifications++);

      // Dirty flips true, but still invalid by default requires explicit
      // setValid(false) to matter; here isValid defaults true so canSubmit
      // flips false -> true.
      controller.setValue('name', 'Ada');
      expect(notifications, 1);

      // Setting the same value again is a no-op, no notification.
      controller.setValue('name', 'Ada');
      expect(notifications, 1);

      // Revert to initial: dirty flips true -> false, canSubmit true -> false.
      controller.setValue('name', '');
      expect(notifications, 2);
    });

    test('markClean rebaselines against current values', () {
      final controller = UiFormSubmitController(initialValues: {'name': ''});
      addTearDown(controller.dispose);

      controller.setValue('name', 'Ada');
      expect(controller.isDirty, isTrue);

      controller.markClean();
      expect(controller.isDirty, isFalse);

      controller.setValue('name', '');
      expect(controller.isDirty, isTrue);
    });

    test('reset replaces both initial and current snapshots', () {
      final controller = UiFormSubmitController(initialValues: {'name': 'A'});
      addTearDown(controller.dispose);

      controller.setValue('name', 'B');
      expect(controller.isDirty, isTrue);

      controller.reset({'name': 'C'});
      expect(controller.isDirty, isFalse);

      controller.setValue('name', 'D');
      expect(controller.isDirty, isTrue);
    });

    test('isFieldDirty reports per-field state', () {
      final controller = UiFormSubmitController(
        initialValues: {'first': 'Ada', 'last': 'Lovelace'},
      );
      addTearDown(controller.dispose);

      expect(controller.isFieldDirty('first'), isFalse);
      expect(controller.isFieldDirty('last'), isFalse);
      // Never reported through setValue: reads as clean.
      expect(controller.isFieldDirty('unknown'), isFalse);

      controller.setValue('last', 'King');
      expect(controller.isFieldDirty('first'), isFalse);
      expect(controller.isFieldDirty('last'), isTrue);
      expect(controller.isDirty, isTrue);

      controller.setValue('last', 'Lovelace');
      expect(controller.isFieldDirty('last'), isFalse);
    });

    test(
        'bindController seeds the baseline from the controller\'s text and '
        'tracks edits', () {
      final controller = UiFormSubmitController();
      addTearDown(controller.dispose);
      final email = TextEditingController(text: 'a@b.com');
      addTearDown(email.dispose);

      controller.bindController('email', email);
      expect(controller.isDirty, isFalse);

      email.text = 'b@c.com';
      expect(controller.isDirty, isTrue);
      expect(controller.isFieldDirty('email'), isTrue);

      email.text = 'a@b.com';
      expect(controller.isDirty, isFalse);
    });

    test('constructor controllers param binds each controller up front', () {
      final email = TextEditingController(text: 'a@b.com');
      final name = TextEditingController(text: 'Ada');
      addTearDown(email.dispose);
      addTearDown(name.dispose);

      final controller = UiFormSubmitController(
        initialValues: {'imagePath': null},
        controllers: [
          UiFormControllerField('email', email),
          UiFormControllerField('name', name),
        ],
      );
      addTearDown(controller.dispose);

      expect(controller.isDirty, isFalse);

      name.text = 'Grace';
      expect(controller.isDirty, isTrue);
      expect(controller.isFieldDirty('name'), isTrue);
      expect(controller.isFieldDirty('email'), isFalse);

      controller.setValue('imagePath', '/tmp/a.png');
      expect(controller.isFieldDirty('imagePath'), isTrue);
    });

    test('bound validator gates isValid/canSubmit as the controller edits', () {
      final email = TextEditingController(text: 'a@b.com');
      addTearDown(email.dispose);

      final controller = UiFormSubmitController(
        controllers: [
          UiFormControllerField(
            'email',
            email,
            validator: (v) => v.contains('@') ? null : 'Enter a valid email',
          ),
        ],
      );
      addTearDown(controller.dispose);

      // Clean and valid: nothing to submit yet.
      expect(controller.isValid, isTrue);
      expect(controller.canSubmit, isFalse);

      email.text = 'not-an-email';
      expect(controller.isDirty, isTrue);
      expect(controller.isValid, isFalse);
      expect(controller.canSubmit, isFalse);

      email.text = 'b@c.com';
      expect(controller.isValid, isTrue);
      expect(controller.canSubmit, isTrue);
    });

    test('isValid combines every bound validator with setValid', () {
      final email = TextEditingController(text: 'a@b.com');
      final name = TextEditingController(text: 'Ada Lovelace');
      addTearDown(email.dispose);
      addTearDown(name.dispose);

      final controller = UiFormSubmitController(
        controllers: [
          UiFormControllerField(
            'email',
            email,
            validator: (v) => v.contains('@') ? null : 'bad email',
          ),
          UiFormControllerField(
            'name',
            name,
            validator: (v) => v.trim().isEmpty ? 'required' : null,
          ),
        ],
      );
      addTearDown(controller.dispose);

      name.text = '';
      expect(controller.isValid, isFalse, reason: 'name validator fails');

      name.text = 'Ada';
      expect(controller.isValid, isTrue);

      controller.setValid(false);
      expect(
        controller.isValid,
        isFalse,
        reason: 'setValid ANDs with bound validators',
      );

      controller.setValid(true);
      expect(controller.isValid, isTrue);
    });

    test('unbindController drops the field\'s validator', () {
      final name = TextEditingController(text: 'Ada');
      addTearDown(name.dispose);

      final controller = UiFormSubmitController(
        controllers: [
          UiFormControllerField(
            'name',
            name,
            validator: (v) => v.trim().isEmpty ? 'required' : null,
          ),
        ],
      );
      addTearDown(controller.dispose);

      name.text = '';
      expect(controller.isValid, isFalse);

      controller.unbindController('name');
      expect(controller.isValid, isTrue);
    });

    test('unbindController stops tracking further edits', () {
      final controller = UiFormSubmitController();
      addTearDown(controller.dispose);
      final name = TextEditingController(text: 'Ada');
      addTearDown(name.dispose);

      controller.bindController('name', name);
      controller.unbindController('name');

      name.text = 'Grace';
      expect(controller.isDirty, isFalse);
    });

    test('dispose removes listeners from bound controllers', () {
      final controller = UiFormSubmitController();
      final name = TextEditingController(text: 'Ada');
      addTearDown(name.dispose);

      controller.bindController('name', name);
      controller.dispose();

      // Would throw "used after being disposed" if the listener survived.
      expect(() => name.text = 'Grace', returnsNormally);
    });

    test('tracks multiple fields independently', () {
      final controller = UiFormSubmitController(
        initialValues: {'first': 'Ada', 'last': 'Lovelace'},
      );
      addTearDown(controller.dispose);

      controller.setValue('first', 'Ada');
      expect(controller.isDirty, isFalse);

      controller.setValue('last', 'King');
      expect(controller.isDirty, isTrue);

      controller.setValue('last', 'Lovelace');
      expect(controller.isDirty, isFalse);
    });
  });
}
