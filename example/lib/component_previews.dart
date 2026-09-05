import 'package:flutter/widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

/// Focused component families rendered by the documentation capture tool.
enum ComponentPreviewKind {
  actions,
  forms,
  dataDisplay,
  chat,
  feedback,
  navigation,
  pickers,
}

/// Small, deterministic usage scenes for component-level documentation.
class OpenUiKitComponentPreview extends StatefulWidget {
  const OpenUiKitComponentPreview({super.key, required this.kind});

  final ComponentPreviewKind kind;

  @override
  State<OpenUiKitComponentPreview> createState() =>
      _OpenUiKitComponentPreviewState();
}

class _OpenUiKitComponentPreviewState extends State<OpenUiKitComponentPreview> {
  bool _checked = true;
  bool _enabled = true;
  String _role = 'Designer';
  DateTime _date = DateTime(2026, 9, 18);
  UiTimeValue _time = const UiTimeValue(hour: 10, minute: 30);
  int _tab = 1;
  int _page = 2;
  late final TextEditingController _composer;

  @override
  void initState() {
    super.initState();
    _composer = TextEditingController(text: 'Can we ship this today?');
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return ColoredBox(
      color: tokens.colors.background,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.x6),
          child: switch (widget.kind) {
            ComponentPreviewKind.actions => _actions(context),
            ComponentPreviewKind.forms => _forms(context),
            ComponentPreviewKind.dataDisplay => _dataDisplay(),
            ComponentPreviewKind.chat => _chat(context),
            ComponentPreviewKind.feedback => _feedback(context),
            ComponentPreviewKind.navigation => _navigation(context),
            ComponentPreviewKind.pickers => _pickers(context),
          },
        ),
      ),
    );
  }

  Widget _actions(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return _PreviewSurface(
      title: 'Actions communicate hierarchy and state',
      description: 'Intent, loading, disabled, and icon-only controls share one interaction model.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: tokens.spacing.x3,
            runSpacing: tokens.spacing.x3,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              UiButton(
                label: 'Save changes',
                leading: const Icon(LucideIcons.check),
                onPressed: () {},
              ),
              UiButton(
                label: 'Cancel',
                intent: UiIntent.neutral,
                onPressed: () {},
              ),
              UiButton(
                label: 'Delete',
                intent: UiIntent.danger,
                leading: const Icon(LucideIcons.trash2),
                onPressed: () {},
              ),
              UiButton(
                label: 'Learn more',
                intent: UiIntent.ghost,
                trailing: const Icon(LucideIcons.arrowRight),
                onPressed: () {},
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.x5),
          Wrap(
            spacing: tokens.spacing.x3,
            runSpacing: tokens.spacing.x3,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const UiButton(label: 'Saving', loading: true),
              const UiButton(label: 'Unavailable', onPressed: null),
              UiIconButton(
                icon: const Icon(LucideIcons.moreHorizontal),
                semanticsLabel: 'More actions',
                onPressed: () {},
              ),
              const UiBadge(
                label: 'Keyboard ready',
                intent: UiIntent.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _forms(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return _PreviewSurface(
      title: 'Forms keep labels, validation, and choices together',
      description: 'Visible labels and stateful controls remain readable from touch to keyboard.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: UiInput(
                  label: 'Email',
                  initialValue: 'ada@example.com',
                  helper: 'We never share this.',
                  leading: Icon(LucideIcons.mail),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: UiInput(
                  label: 'Team slug',
                  initialValue: 'open ui kit',
                  errorText: 'Use letters, numbers, or dashes.',
                  leading: Icon(LucideIcons.users),
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.x5),
          Wrap(
            spacing: tokens.spacing.x4,
            runSpacing: tokens.spacing.x3,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              UiCheckbox(
                label: 'Weekly summary',
                value: _checked,
                onChanged: (value) => setState(() => _checked = value),
              ),
              UiSwitch(
                label: 'Notifications',
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
              for (final role in const ['Designer', 'Developer', 'Reviewer'])
                UiFilterChip(
                  label: role,
                  selected: _role == role,
                  onSelected: (_) => setState(() => _role = role),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dataDisplay() {
    return UiCard(
      variant: UiCardVariant.elevated,
      header: const UiCardHeader(
        title: 'Weekly summary',
        subtitle: 'Cards compose identity, status, and structured data',
        trailing: UiBadge(label: 'Healthy', intent: UiIntent.secondary),
      ),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const UiAvatarGroup(
            items: [
              UiAvatarEntry(name: 'Ada Lovelace'),
              UiAvatarEntry(name: 'Grace Hopper'),
              UiAvatarEntry(name: 'Katherine Johnson'),
              UiAvatarEntry(name: 'Margaret Hamilton'),
            ],
          ),
          UiPagination(
            currentPage: _page,
            totalPages: 4,
            maxVisiblePages: 3,
            onPageChanged: (value) => setState(() => _page = value),
          ),
        ],
      ),
      child: UiDataTable(
        columns: const [
          UiDataColumn(label: 'Component', flex: 3),
          UiDataColumn(label: 'Status', flex: 2),
          UiDataColumn(label: 'Coverage', numeric: true, flex: 2),
        ],
        rows: const [
          UiDataRow(
            cells: [
              UiText('Inputs', variant: UiTextVariant.label),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: UiBadge(label: 'Stable', intent: UiIntent.secondary),
              ),
              UiText('96%', textAlign: TextAlign.right),
            ],
          ),
          UiDataRow(
            cells: [
              UiText('Navigation', variant: UiTextVariant.label),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: UiBadge(label: 'Preview'),
              ),
              UiText('88%', textAlign: TextAlign.right),
            ],
          ),
        ],
        scrollable: false,
      ),
    );
  }

  Widget _chat(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return _PreviewSurface(
      title: 'Chat primitives preserve conversational rhythm',
      description: 'Incoming, outgoing, pending, failed, typing, and composing states share one surface.',
      child: SizedBox(
        height: 360,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const UiMessageBubble(
              author: UiMessageAuthor.incoming,
              text: 'The component gallery is ready for review.',
              timestamp: '10:24',
              leading: UiAvatar(name: 'Ada Lovelace', size: 32),
            ),
            SizedBox(height: tokens.spacing.x2),
            const UiMessageBubble(
              author: UiMessageAuthor.outgoing,
              text: 'Perfect — I will check the responsive states.',
              timestamp: '10:25',
            ),
            const UiTypingIndicator(
              users: [
                UiTypingUser(id: 'ada', name: 'Ada Lovelace'),
                UiTypingUser(id: 'grace', name: 'Grace Hopper'),
              ],
            ),
            const Spacer(),
            UiChatComposer(
              controller: _composer,
              compactSendAction: true,
              onSend: (_) {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _feedback(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const UiAlert(
                title: 'Changes published',
                description: 'The documentation is now available.',
                intent: UiAlertIntent.success,
                leading: Icon(LucideIcons.checkCircle2),
              ),
              SizedBox(height: tokens.spacing.x4),
              UiToast(
                title: 'Saved',
                message: 'Your draft is safe.',
                intent: UiIntent.primary,
                leading: const Icon(LucideIcons.check),
                action: UiToastAction(label: 'Undo', onPressed: () {}),
              ),
            ],
          ),
        ),
        SizedBox(width: tokens.spacing.x6),
        Expanded(
          child: UiAlertDialog(
            title: 'Delete this draft?',
            description:
                'The draft will be removed for everyone on the project.',
            confirmLabel: 'Delete draft',
            intent: UiAlertDialogIntent.destructive,
            onConfirm: () {},
            onCancel: () {},
          ),
        ),
      ],
    );
  }

  Widget _navigation(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return SizedBox(
      height: 340,
      child: ClipRRect(
        borderRadius: tokens.radius.xlAll,
        child: UiBox(
          background: tokens.colors.surfaceMuted,
          border: Border.all(color: tokens.colors.border),
          borderRadius: tokens.radius.xlAll,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UiSidebar(
                width: 220,
                header: const Padding(
                  padding: EdgeInsets.all(16),
                  child: UiText('Workspace', variant: UiTextVariant.subheading),
                ),
                items: [
                  UiSidebarGroup(
                    label: 'Main',
                    items: [
                      UiSidebarItem(
                        label: 'Inbox',
                        icon: const Icon(LucideIcons.inbox),
                        active: true,
                        badge: const UiBadge(label: '3'),
                        onPressed: () {},
                      ),
                      UiSidebarItem(
                        label: 'Calendar',
                        icon: const Icon(LucideIcons.calendarDays),
                        onPressed: () {},
                      ),
                      UiSidebarItem(
                        label: 'Archive',
                        icon: const Icon(LucideIcons.archive),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
              Expanded(
                child: Column(
                  children: [
                    const Expanded(
                      child: Center(
                        child: UiText(
                          'The same destinations adapt from sidebar to bottom dock.',
                          variant: UiTextVariant.bodyLg,
                          tone: UiTextTone.muted,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    UiBottomTabBar(
                      items: const [
                        UiBottomTabItem(
                          label: 'Home',
                          icon: Icon(LucideIcons.house),
                        ),
                        UiBottomTabItem(
                          label: 'Inbox',
                          icon: Icon(LucideIcons.inbox),
                          badge: 3,
                        ),
                        UiBottomTabItem(
                          label: 'Me',
                          icon: Icon(LucideIcons.user),
                        ),
                      ],
                      currentIndex: _tab,
                      blurred: false,
                      onChanged: (value) => setState(() => _tab = value),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pickers(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: UiCard(
            header: const UiCardHeader(
              title: 'Choose a date',
              subtitle: 'Direct month navigation',
            ),
            child: Center(
              child: UiDatePicker(
                value: _date,
                visibleMonth: DateTime(2026, 9),
                enableHeaderModeSelection: false,
                showBorder: false,
                chromePadding: EdgeInsets.zero,
                onChanged: (value) => setState(() => _date = value),
              ),
            ),
          ),
        ),
        SizedBox(width: tokens.spacing.x5),
        Expanded(
          child: UiCard(
            header: const UiCardHeader(
              title: 'Choose a time',
              subtitle: 'Grid options for embedded surfaces',
            ),
            child: UiTimeGridPicker(
              value: _time,
              minuteStep: 15,
              showBorder: false,
              chromePadding: EdgeInsets.zero,
              onChanged: (value) => setState(() => _time = value),
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewSurface extends StatelessWidget {
  const _PreviewSurface({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return UiCard(
      variant: UiCardVariant.elevated,
      header: UiCardHeader(title: title, subtitle: description),
      child: child,
    );
  }
}
