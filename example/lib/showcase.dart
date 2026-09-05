import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  runApp(const OpenUiKitShowcaseApp());
}

/// A visual tour built entirely from the public Open UI Kit API.
///
/// Run it with `flutter run -t lib/showcase.dart` from the example directory.
class OpenUiKitShowcaseApp extends StatefulWidget {
  const OpenUiKitShowcaseApp({super.key});

  @override
  State<OpenUiKitShowcaseApp> createState() => _OpenUiKitShowcaseAppState();
}

class _OpenUiKitShowcaseAppState extends State<OpenUiKitShowcaseApp> {
  UiThemeMode _mode = UiThemeMode.light;

  @override
  Widget build(BuildContext context) {
    final isDark = _mode == UiThemeMode.dark;
    return UiApp(
      title: 'Open UI Kit showcase',
      mode: _mode,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [DefaultWidgetsLocalizations.delegate],
      home: OpenUiKitShowcase(
        appearanceLabel: isDark ? 'Light mode' : 'Dark mode',
        appearanceIcon: isDark ? LucideIcons.sun : LucideIcons.moon,
        onAppearancePressed: () => setState(
          () => _mode = isDark ? UiThemeMode.light : UiThemeMode.dark,
        ),
      ),
    );
  }
}

/// Responsive showcase surface used by the runnable example and docs captures.
class OpenUiKitShowcase extends StatefulWidget {
  const OpenUiKitShowcase({
    super.key,
    this.appearanceLabel,
    this.appearanceIcon,
    this.onAppearancePressed,
  });

  final String? appearanceLabel;
  final IconData? appearanceIcon;
  final VoidCallback? onAppearancePressed;

  @override
  State<OpenUiKitShowcase> createState() => _OpenUiKitShowcaseState();
}

class _OpenUiKitShowcaseState extends State<OpenUiKitShowcase> {
  late DateTime _selectedDate;
  bool _notifyTeam = true;
  bool _installCommandCopied = false;
  String _channel = 'Stable';
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(2026, 9, 18);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return ColoredBox(
      color: tokens.colors.background,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            final horizontalPadding = constraints.maxWidth >= 720 ? 48.0 : 20.0;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                36,
                horizontalPadding,
                48,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1240),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ShowcaseHeader(
                        compact: !wide,
                        installCommandCopied: _installCommandCopied,
                        onCopyInstallCommand: _copyInstallCommand,
                        appearanceLabel: widget.appearanceLabel,
                        appearanceIcon: widget.appearanceIcon,
                        onAppearancePressed: widget.onAppearancePressed,
                      ),
                      SizedBox(height: tokens.spacing.x8),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 6,
                              child: _ReleaseComposer(
                                channel: _channel,
                                notifyTeam: _notifyTeam,
                                onChannelChanged: (value) =>
                                    setState(() => _channel = value),
                                onNotifyChanged: (value) =>
                                    setState(() => _notifyTeam = value),
                              ),
                            ),
                            SizedBox(width: tokens.spacing.x5),
                            Expanded(
                              flex: 5,
                              child: _SchedulePanel(
                                selectedDate: _selectedDate,
                                onDateChanged: (value) =>
                                    setState(() => _selectedDate = value),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _ReleaseComposer(
                          channel: _channel,
                          notifyTeam: _notifyTeam,
                          onChannelChanged: (value) =>
                              setState(() => _channel = value),
                          onNotifyChanged: (value) =>
                              setState(() => _notifyTeam = value),
                        ),
                        SizedBox(height: tokens.spacing.x5),
                        _SchedulePanel(
                          selectedDate: _selectedDate,
                          onDateChanged: (value) =>
                              setState(() => _selectedDate = value),
                        ),
                      ],
                      SizedBox(height: tokens.spacing.x5),
                      _ReleaseTable(
                        page: _page,
                        onPageChanged: (value) => setState(() => _page = value),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _copyInstallCommand() {
    Clipboard.setData(const ClipboardData(text: 'flutter pub add open_ui_kit'));
    setState(() => _installCommandCopied = true);
  }
}

class _ShowcaseHeader extends StatelessWidget {
  const _ShowcaseHeader({
    required this.compact,
    required this.installCommandCopied,
    required this.onCopyInstallCommand,
    this.appearanceLabel,
    this.appearanceIcon,
    this.onAppearancePressed,
  });

  final bool compact;
  final bool installCommandCopied;
  final VoidCallback onCopyInstallCommand;
  final String? appearanceLabel;
  final IconData? appearanceIcon;
  final VoidCallback? onAppearancePressed;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final title = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        UiBox(
          width: 46,
          height: 46,
          background: tokens.colors.primary,
          borderRadius: tokens.radius.lgAll,
          alignment: Alignment.center,
          child: Icon(
            LucideIcons.sparkles,
            size: 22,
            color: tokens.colors.onPrimary,
          ),
        ),
        SizedBox(width: tokens.spacing.x3),
        const Flexible(
          child: UiText(
            'Open UI Kit',
            variant: UiTextVariant.displayLg,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    final actions = Wrap(
      spacing: tokens.spacing.x2,
      runSpacing: tokens.spacing.x2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const UiBadge(
          label: 'Illustrative workspace',
          intent: UiIntent.neutral,
        ),
        const UiBadge(
          label: 'Flutter',
          intent: UiIntent.neutral,
          leading: Icon(LucideIcons.package, size: 13),
        ),
        const UiBadge(label: 'Token driven', intent: UiIntent.secondary),
        UiButton(
          label: installCommandCopied ? 'Copied' : 'Copy install command',
          intent: UiIntent.neutral,
          size: UiSize.sm,
          leading: Icon(
            installCommandCopied ? LucideIcons.copyCheck : LucideIcons.copy,
          ),
          onPressed: onCopyInstallCommand,
        ),
        if (onAppearancePressed != null)
          UiButton(
            label: appearanceLabel ?? 'Toggle appearance',
            intent: UiIntent.neutral,
            size: UiSize.sm,
            leading: Icon(appearanceIcon ?? LucideIcons.sun),
            onPressed: onAppearancePressed,
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (compact) ...[
          title,
          SizedBox(height: tokens.spacing.x4),
          const UiText(
            'Composable Flutter primitives with neutral defaults, adaptive '
            'behavior, and motion that belongs to the system.',
            variant: UiTextVariant.bodyLg,
            tone: UiTextTone.muted,
          ),
          SizedBox(height: tokens.spacing.x4),
          actions,
        ] else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    SizedBox(height: tokens.spacing.x3),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 700),
                      child: const UiText(
                        'Composable Flutter primitives with neutral defaults, '
                        'adaptive behavior, and motion that belongs to the system.',
                        variant: UiTextVariant.bodyLg,
                        tone: UiTextTone.muted,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: tokens.spacing.x6),
              actions,
            ],
          ),
        ],
      ],
    );
  }
}

class _ReleaseComposer extends StatelessWidget {
  const _ReleaseComposer({
    required this.channel,
    required this.notifyTeam,
    required this.onChannelChanged,
    required this.onNotifyChanged,
  });

  final String channel;
  final bool notifyTeam;
  final ValueChanged<String> onChannelChanged;
  final ValueChanged<bool> onNotifyChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return UiCard(
      variant: UiCardVariant.elevated,
      header: const UiCardHeader(
        title: 'Compose a release',
        subtitle: 'Forms, choices, status, and actions in one workflow',
        trailing: UiBadge(label: 'Draft', intent: UiIntent.neutral),
      ),
      footer: Wrap(
        alignment: WrapAlignment.end,
        spacing: tokens.spacing.x2,
        runSpacing: tokens.spacing.x2,
        children: [
          UiButton(
            label: 'Save draft',
            intent: UiIntent.neutral,
            onPressed: () {},
          ),
          UiButton(
            label: 'Publish release',
            leading: const Icon(LucideIcons.rocket),
            onPressed: () {},
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const UiInput(
            label: 'Release name',
            initialValue: 'September foundations',
            helper: 'Visible to everyone following the package.',
            leading: Icon(LucideIcons.packageOpen),
          ),
          SizedBox(height: tokens.spacing.x4),
          const UiText('Channel', variant: UiTextVariant.label),
          SizedBox(height: tokens.spacing.x2),
          Wrap(
            spacing: tokens.spacing.x2,
            runSpacing: tokens.spacing.x2,
            children: [
              for (final option in const ['Stable', 'Preview', 'Internal'])
                UiFilterChip(
                  label: option,
                  selected: channel == option,
                  onSelected: (_) => onChannelChanged(option),
                ),
            ],
          ),
          SizedBox(height: tokens.spacing.x4),
          UiAlert(
            title: 'Ready for review',
            description: 'All required checks have completed successfully.',
            intent: UiAlertIntent.success,
            leading: const Icon(LucideIcons.checkCircle2),
            actions: [
              UiButton(
                label: 'View checks',
                intent: UiIntent.ghost,
                size: UiSize.sm,
                onPressed: () {},
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.x4),
          Row(
            children: [
              const Expanded(
                child: UiText(
                  'Notify team',
                  variant: UiTextVariant.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              UiSwitch(
                value: notifyTeam,
                label: 'Notify team',
                showLabel: false,
                onChanged: onNotifyChanged,
              ),
              SizedBox(width: tokens.spacing.x3),
              const UiAvatarGroup(
                items: [
                  UiAvatarEntry(name: 'Mina Saleh'),
                  UiAvatarEntry(name: 'Noah Kim'),
                  UiAvatarEntry(name: 'Rina Patel'),
                  UiAvatarEntry(name: 'Luis Diaz'),
                ],
                size: 32,
                overlap: 20,
                maxVisible: 3,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SchedulePanel extends StatelessWidget {
  const _SchedulePanel({
    required this.selectedDate,
    required this.onDateChanged,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return UiCard(
      header: UiCardHeader(
        title: 'Schedule',
        subtitle: 'A focused picker inside an existing surface',
        trailing: UiIconButton(
          icon: const Icon(LucideIcons.calendarDays),
          semanticsLabel: 'Open schedule',
          onPressed: () {},
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: UiDatePicker(
              value: selectedDate,
              visibleMonth: DateTime(2026, 9),
              onChanged: onDateChanged,
              showBorder: false,
              chromePadding: EdgeInsets.zero,
              enableHeaderModeSelection: false,
            ),
          ),
          SizedBox(height: tokens.spacing.x4),
          UiBox(
            background: tokens.colors.surfaceMuted,
            borderRadius: tokens.radius.mdAll,
            padding: EdgeInsets.all(tokens.spacing.x3),
            child: Row(
              children: [
                UiBox(
                  width: 36,
                  height: 36,
                  background: tokens.colors.primary.withValues(alpha: 0.12),
                  borderRadius: tokens.radius.mdAll,
                  alignment: Alignment.center,
                  child: Icon(
                    LucideIcons.bell,
                    size: 17,
                    color: tokens.colors.primary,
                  ),
                ),
                SizedBox(width: tokens.spacing.x3),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UiText('September 18', variant: UiTextVariant.label),
                      UiText(
                        'Publish at 10:00 UTC',
                        variant: UiTextVariant.caption,
                        tone: UiTextTone.muted,
                      ),
                    ],
                  ),
                ),
                const UiBadge(label: 'Scheduled', intent: UiIntent.secondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReleaseTable extends StatelessWidget {
  const _ReleaseTable({required this.page, required this.onPageChanged});

  final int page;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return UiCard(
      header: const UiCardHeader(
        title: 'Recent releases',
        subtitle: 'Responsive data display with status and ownership',
        trailing: UiBadge(label: '3 releases'),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 640;
          final columns = compact
              ? const [
                  UiDataColumn(label: 'Release', flex: 3),
                  UiDataColumn(label: 'Status', flex: 2),
                ]
              : const [
                  UiDataColumn(label: 'Release', flex: 3),
                  UiDataColumn(label: 'Status', flex: 2),
                  UiDataColumn(label: 'Owner', flex: 2),
                  UiDataColumn(label: 'Published', flex: 2),
                ];
          final releases = [
            ('0.8.0', 'Stable', 'Mina Saleh', 'Sep 03'),
            ('0.7.2', 'Stable', 'Noah Kim', 'Aug 22'),
            ('0.7.0-rc.1', 'Preview', 'Rina Patel', 'Aug 14'),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UiDataTable(
                columns: columns,
                rows: [
                  for (final release in releases)
                    UiDataRow(
                      cells: [
                        Row(
                          children: [
                            Icon(
                              LucideIcons.package,
                              size: 15,
                              color: tokens.colors.textMuted,
                            ),
                            SizedBox(width: tokens.spacing.x2),
                            Flexible(
                              child: UiText(
                                release.$1,
                                variant: UiTextVariant.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: UiBadge(
                            label: release.$2,
                            intent: release.$2 == 'Stable'
                                ? UiIntent.secondary
                                : UiIntent.neutral,
                            size: UiSize.sm,
                          ),
                        ),
                        if (!compact)
                          UiText(
                            release.$3,
                            variant: UiTextVariant.bodySm,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (!compact)
                          UiText(
                            release.$4,
                            variant: UiTextVariant.bodySm,
                            tone: UiTextTone.muted,
                            maxLines: 1,
                          ),
                      ],
                    ),
                ],
                scrollable: false,
              ),
              SizedBox(height: tokens.spacing.x4),
              UiPagination(
                currentPage: page,
                totalPages: 3,
                maxVisiblePages: 3,
                onPageChanged: onPageChanged,
              ),
            ],
          );
        },
      ),
    );
  }
}
