import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  test(
    'tracks touched errors and preserves dirty baselines when fields register',
    () {
      final form = UiFormController();
      final name = form.registerField(
        'name',
        initialValue: '',
        validator: (value) => value.isEmpty ? 'Required' : null,
      );
      expect(name.visibleError, isNull);
      name.markTouched();
      expect(name.visibleError, 'Required');
      name.setValue('Ada');
      form.registerField('notify', initialValue: true);
      expect(form.isDirty, isTrue);
      expect(form.canSubmit, isTrue);
      form.reset();
      expect(name.value, '');
      expect(name.touched, isFalse);
      expect(form.isDirty, isFalse);
      form.dispose();
    },
  );
  test('stale async validation cannot replace an edited value', () async {
    final form = UiFormController();
    final result = Completer<String?>();
    final field = form.registerField(
      'name',
      initialValue: 'old',
      asyncValidator: (_) => result.future,
    );
    final validation = field.validate();
    field.setValue('new');
    result.complete('Taken');
    expect(await validation, isFalse);
    expect(field.error, isNull);
    expect(field.isValidating, isFalse);
    form.dispose();
  });
  test(
    'editing an already validated field invalidates an aggregate attempt',
    () async {
      final form = UiFormController();
      final first = form.registerField('first', initialValue: 'first');
      final result = Completer<String?>();
      form.registerField(
        'second',
        initialValue: 'second',
        asyncValidator: (_) => result.future,
      );
      final validation = form.validate();
      first.setValue('changed');
      result.complete(null);
      expect(await validation, isFalse);
      form.dispose();
    },
  );
  test(
    'duplicate submits are rejected and edits during save stay dirty',
    () async {
      final form = UiFormController();
      final field = form.registerField('name', initialValue: 'initial');
      field.setValue('saved');
      final saving = Completer<void>();
      Map<String, Object?>? submitted;
      final submit = form.submit((values) {
        submitted = values;
        return saving.future;
      });
      await Future<void>.delayed(Duration.zero);
      expect(await form.submit((_) async {}), isFalse);
      field.setValue('edited during save');
      saving.complete();
      expect(await submit, isTrue);
      expect(submitted!['name'], 'saved');
      expect(form.isDirty, isTrue);
      expect(form.isSubmitting, isFalse);
      form.dispose();
    },
  );
  test('successful submit marks only unchanged state clean', () async {
    final form = UiFormController();
    form.registerField('name', initialValue: '').setValue('Ada');
    expect(await form.submit((_) async {}), isTrue);
    expect(form.isDirty, isFalse);
    form.dispose();
  });
  test('validator and submit exceptions clear pending state', () async {
    final form = UiFormController();
    final field = form.registerField(
      'name',
      initialValue: '',
      asyncValidator: (_) async => throw StateError('offline'),
    );
    field.setValue('Ada');
    await expectLater(form.submit((_) async {}), throwsStateError);
    expect(form.isSubmitting, isFalse);
    expect(form.isValidating, isFalse);
    form.unregisterField('name');
    form.registerField('other', initialValue: '').setValue('value');
    await expectLater(
      form.submit((_) async => throw StateError('save failed')),
      throwsStateError,
    );
    expect(form.isSubmitting, isFalse);
    expect(form.isDirty, isTrue);
    form.dispose();
  });
  test('disposing during validation ignores late completion', () async {
    final form = UiFormController();
    final pending = Completer<String?>();
    final field = form.registerField(
      'name',
      initialValue: 'name',
      asyncValidator: (_) => pending.future,
    );
    final validation = field.validate();
    form.dispose();
    pending.complete('late');
    expect(await validation, isFalse);
  });
  testWidgets(
    'text adapter resets content and summary focuses the invalid field',
    (tester) async {
      final form = UiFormController();
      final field = form.registerField(
        'name',
        label: 'Name',
        initialValue: '',
        validator: (value) => value.isEmpty ? 'Required' : null,
      );
      await tester.pumpWidget(
        UiApp(
          home: Center(
            child: SizedBox(
              width: 320,
              child: Column(
                children: [
                  UiFormErrorSummary(controller: form),
                  UiFormTextField(field: field),
                ],
              ),
            ),
          ),
        ),
      );
      await form.validate();
      await tester.pumpAndSettle();
      expect(field.focusNode.hasFocus, isTrue);
      expect(find.text('Name: Required'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'Ada');
      expect(field.value, 'Ada');
      form.reset();
      await tester.pump();
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '',
      );
      await tester.pumpWidget(const SizedBox());
      form.dispose();
    },
  );
}
