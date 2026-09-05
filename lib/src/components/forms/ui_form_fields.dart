import 'package:flutter/widgets.dart';

import '../../foundation/intl/ui_localizations.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import 'button.dart';
import 'input.dart';
import 'internal/ui_field_frame.dart';
import 'ui_form_controller.dart';

/// Field presentation for custom controls. Bind the child's value, onChanged,
/// and focus node to [field]; leave its own label/helper/error slots empty.
class UiFormFieldView<T> extends StatelessWidget {
  const UiFormFieldView({
    super.key,
    required this.field,
    required this.builder,
    this.helper,
    this.enabled = true,
  });
  final UiFormFieldController<T> field;
  final Widget Function(BuildContext, UiFormFieldController<T>) builder;
  final String? helper;
  final bool enabled;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: field,
    builder: (context, _) => Focus(
      canRequestFocus: false,
      onFocusChange: (focused) {
        if (!focused) field.markTouched();
      },
      child: UiFieldFrame(
        label: field.label,
        helper: helper,
        errorText: field.visibleError,
        enabled: enabled,
        child: builder(context, field),
      ),
    ),
  );
}

/// Text adapter that synchronizes edits and form resets without recreating focus.
class UiFormTextField extends StatefulWidget {
  const UiFormTextField({
    super.key,
    required this.field,
    this.hint,
    this.helper,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
  });
  final UiFormFieldController<String> field;
  final String? hint;
  final String? helper;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  @override
  State<UiFormTextField> createState() => _UiFormTextFieldState();
}

class _UiFormTextFieldState extends State<UiFormTextField> {
  late final _text = TextEditingController(text: widget.field.value);
  @override
  void initState() {
    super.initState();
    widget.field.addListener(_sync);
  }

  void _sync() {
    if (_text.text != widget.field.value) {
      _text.value = TextEditingValue(
        text: widget.field.value,
        selection: TextSelection.collapsed(offset: widget.field.value.length),
      );
    }
  }

  @override
  void didUpdateWidget(covariant UiFormTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.field != widget.field) {
      oldWidget.field.removeListener(_sync);
      widget.field.addListener(_sync);
      _sync();
    }
  }

  @override
  Widget build(BuildContext context) => UiFormFieldView<String>(
    field: widget.field,
    helper: widget.helper,
    enabled: widget.enabled,
    builder: (context, field) => UiInput(
      controller: _text,
      focusNode: field.focusNode,
      onChanged: field.setValue,
      enabled: widget.enabled,
      hint: widget.hint,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
    ),
  );
  @override
  void dispose() {
    widget.field.removeListener(_sync);
    _text.dispose();
    super.dispose();
  }
}

/// Visible validation errors with actions that focus the corresponding field.
class UiFormErrorSummary extends StatelessWidget {
  const UiFormErrorSummary({super.key, required this.controller, this.title});
  final UiFormController controller;
  final String? title;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final fields = controller.fields
          .where((field) => field.visibleError != null)
          .toList();
      if (fields.isEmpty) return const SizedBox.shrink();
      final tokens = UiThemeTokens.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: UiText(
              title ?? UiLocalizations.of(context).formErrors,
              variant: UiTextVariant.label,
            ),
          ),
          SizedBox(height: tokens.spacing.x1),
          for (final field in fields)
            UiButton(
              label: '${field.label}: ${field.visibleError}',
              intent: UiIntent.neutral,
              showBorder: false,
              onPressed: field.focusNode.requestFocus,
            ),
        ],
      );
    },
  );
}
