import 'package:flutter/widgets.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

/// A runnable composition of typed form state, multi-select, and error recovery.
class FormWorkflowExample extends StatefulWidget {
  const FormWorkflowExample({super.key, this.onSave});
  final Future<void> Function(Map<String, Object?> values)? onSave;
  @override
  State<FormWorkflowExample> createState() => _FormWorkflowExampleState();
}

class _FormWorkflowExampleState extends State<FormWorkflowExample> {
  final _form = UiFormController();
  late final _name = _form.registerField<String>(
    'name',
    label: 'Full name',
    initialValue: '',
    validator: (value) => value.trim().isEmpty ? 'Enter a name' : null,
  );
  late final _teams = _form.registerField<Set<String>>(
    'teams',
    label: 'Teams',
    initialValue: const {},
    validator: (value) => value.isEmpty ? 'Choose at least one team' : null,
  );
  bool _saved = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _name;
    _teams;
  }

  Future<void> _save() async {
    setState(() {
      _saveError = null;
      _saved = false;
    });
    try {
      final saved = await _form.submit((values) async {
        await widget.onSave?.call(values);
      });
      if (mounted) setState(() => _saved = saved);
    } catch (_) {
      if (mounted) setState(() => _saveError = 'Could not save. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return UiPageLayout(
      title: 'Team settings',
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: EdgeInsets.all(tokens.spacing.x5),
              child: ListenableBuilder(
                listenable: _form,
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const UiText(
                      'Add a teammate',
                      variant: UiTextVariant.heading,
                    ),
                    SizedBox(height: tokens.spacing.x2),
                    const UiText(
                      'Choose the teams this person will work with.',
                      tone: UiTextTone.muted,
                    ),
                    SizedBox(height: tokens.spacing.x6),
                    UiFormErrorSummary(controller: _form),
                    UiFormTextField(
                      field: _name,
                      hint: 'e.g. Ada Lovelace',
                      enabled: !_form.isSubmitting,
                    ),
                    SizedBox(height: tokens.spacing.x5),
                    UiFormFieldView<Set<String>>(
                      field: _teams,
                      enabled: !_form.isSubmitting,
                      helper: 'You can choose more than one team.',
                      builder: (context, field) => UiMultiSelect<String>(
                        options: const [
                          UiSelectOption(value: 'design', label: 'Design'),
                          UiSelectOption(
                            value: 'engineering',
                            label: 'Engineering',
                          ),
                          UiSelectOption(value: 'support', label: 'Support'),
                        ],
                        value: field.value,
                        onChanged: field.setValue,
                        focusNode: field.focusNode,
                        enabled: !_form.isSubmitting,
                      ),
                    ),
                    SizedBox(height: tokens.spacing.x6),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: UiButton(
                        label: 'Save teammate',
                        loading: _form.isSubmitting,
                        onPressed: _form.canSubmit ? _save : null,
                      ),
                    ),
                    if (_saved || _saveError != null) ...[
                      SizedBox(height: tokens.spacing.x5),
                      UiAlert(
                        title: _saveError == null
                            ? 'Teammate saved'
                            : 'Save failed',
                        description:
                            _saveError ??
                            'Details are held in this demo session.',
                        intent: _saveError == null
                            ? UiAlertIntent.success
                            : UiAlertIntent.destructive,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }
}
