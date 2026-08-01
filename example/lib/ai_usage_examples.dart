import 'package:flutter/widgets.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

/// Canonical snippets for developers and AI coding agents.
///
/// Keep examples small and stateful so generated app code can copy the shape:
/// controlled values live in the screen, Open UI Kit owns visual chrome, and
/// callers only pass callbacks plus app-specific labels.
void main() {
  runApp(const OpenUiKitAgentExamplesApp());
}

class OpenUiKitAgentExamplesApp extends StatelessWidget {
  const OpenUiKitAgentExamplesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return UiApp(
      lightTokens: UiThemeData.light(),
      darkTokens: UiThemeData.dark(),
      home: const _ExamplesScreen(),
    );
  }
}

class _ExamplesScreen extends StatefulWidget {
  const _ExamplesScreen();

  @override
  State<_ExamplesScreen> createState() => _ExamplesScreenState();
}

class _ExamplesScreenState extends State<_ExamplesScreen> {
  String cadence = 'monthly';
  UiTimeValue startsAt = const UiTimeValue(hour: 9, minute: 0);
  DateTime dueDate = DateTime(2026, 7, 22);

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);

    return UiPageScaffold(
      body: CustomScrollView(
        slivers: [
          UiSliverNavigationBar(
            spec: UiNavigationSpec(
              title: 'Open UI Kit examples',
              subtitle: 'Canonical component usage',
              back: UiNavigationBackConfig(
                label: 'Docs',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              actions: [
                UiButton(
                  label: 'Save',
                  size: UiSize.sm,
                  onPressed: _save,
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.all(tokens.spacing.x4),
            sliver: SliverList.list(
              children: [
                _section(
                  context,
                  title: 'Actions',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: tokens.spacing.x2,
                        runSpacing: tokens.spacing.x2,
                        children: [
                          UiButton(
                            label: 'Save changes',
                            onPressed: _save,
                          ),
                          UiButton(
                            label: 'Cancel',
                            intent: UiIntent.neutral,
                            onPressed: _cancel,
                          ),
                          UiButton(
                            label: 'Floating secondary',
                            intent: UiIntent.secondary,
                            showBorder: false,
                            boxShadow: tokens.shadows.sm,
                            onPressed: _save,
                          ),
                        ],
                      ),
                      SizedBox(height: tokens.spacing.x3),
                      UiConfirmActionGroup(
                        actionLabel: 'Save changes',
                        confirmLabel: 'Confirm save',
                        secondaryLabel: 'Cancel',
                        cancelLabel: 'Keep editing',
                        onConfirm: _save,
                        onSecondaryPressed: _cancel,
                      ),
                      SizedBox(height: tokens.spacing.x3),
                      UiSmartActionGroup(
                        collapseOnAction: true,
                        actions: [
                          UiSmartActionGroupAction(
                            id: 'enter',
                            label: 'Enter',
                            onPressed: _save,
                          ),
                          UiSmartActionGroupAction(
                            id: 'end',
                            label: 'End class',
                            intent: UiIntent.danger,
                            onPressed: _cancel,
                          ),
                          UiSmartActionGroupAction(
                            id: 'absent',
                            label: 'Mark absent',
                            intent: UiIntent.neutral,
                            onPressed: _cancel,
                          ),
                        ],
                        collapseLabel: 'Close',
                      ),
                    ],
                  ),
                ),
                _section(
                  context,
                  title: 'Grouped choices',
                  child: UiRadioGroup<String>(
                    label: 'Billing cadence',
                    value: cadence,
                    onChanged: (value) => setState(() => cadence = value),
                    options: const [
                      UiRadioGroupOption(
                        value: 'monthly',
                        label: 'Monthly',
                        helper: 'Best for short trials.',
                      ),
                      UiRadioGroupOption(
                        value: 'yearly',
                        label: 'Yearly',
                        helper: 'Best for committed plans.',
                      ),
                    ],
                  ),
                ),
                _section(
                  context,
                  title: 'Form time picker',
                  child: UiTimePickerField(
                    label: 'Starts at',
                    value: startsAt,
                    minuteStep: 15,
                    onChanged: (value) => setState(() => startsAt = value),
                  ),
                ),
                _section(
                  context,
                  title: 'Embedded pickers',
                  child: UiBox(
                    background: tokens.colors.surface,
                    border: Border.all(color: tokens.colors.border),
                    borderRadius: tokens.radius.lgAll,
                    padding: EdgeInsets.all(tokens.spacing.x3),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        UiDatePicker(
                          value: dueDate,
                          onChanged: (value) => setState(() => dueDate = value),
                          showBorder: false,
                          chromePadding: EdgeInsets.zero,
                        ),
                        SizedBox(height: tokens.spacing.x4),
                        UiTimeGridPicker(
                          value: startsAt,
                          minuteStep: 15,
                          onChanged: (value) =>
                              setState(() => startsAt = value),
                          showBorder: false,
                          chromePadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    final tokens = UiThemeTokens.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UiText(title, variant: UiTextVariant.heading),
          SizedBox(height: tokens.spacing.x3),
          child,
        ],
      ),
    );
  }

  void _save() {}

  void _cancel() {}
}
