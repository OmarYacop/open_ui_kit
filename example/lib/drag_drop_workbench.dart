import 'package:flutter/widgets.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

/// Synthetic release work: table sorting, custom sorting and typed transfer.
class DragDropWorkbench extends StatefulWidget {
  const DragDropWorkbench({super.key});

  @override
  State<DragDropWorkbench> createState() => _DragDropWorkbenchState();
}

class _DragDropWorkbenchState extends State<DragDropWorkbench> {
  final _rows = ['Keyboard navigation', 'Responsive layouts', 'Release notes'];
  final _checks = [
    'Review component examples',
    'Run the verification suite',
    'Prepare the release',
  ];
  final _ready = <String>[];
  bool _locked = false;
  String _status = 'Changes stay in this demo.';

  void _moveReady(String value) {
    if (_ready.contains(value)) return;
    setState(() {
      _ready.add(value);
      _status = '$value moved to Ready.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return UiPageLayout(
      title: 'Release workspace',
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Padding(
              padding: EdgeInsets.all(tokens.spacing.x5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const UiText(
                    'Put the work in order',
                    variant: UiTextVariant.title,
                  ),
                  SizedBox(height: tokens.spacing.x2),
                  const UiText(
                    'Drag a grip to change priority. You can also focus a grip and use the arrow keys.',
                    tone: UiTextTone.muted,
                  ),
                  SizedBox(height: tokens.spacing.x6),
                  Row(
                    children: [
                      const Expanded(
                        child: UiText(
                          'Release queue',
                          variant: UiTextVariant.subheading,
                        ),
                      ),
                      UiButton(
                        label: _locked ? 'Unlock order' : 'Lock order',
                        intent: UiIntent.neutral,
                        onPressed: () => setState(() => _locked = !_locked),
                      ),
                    ],
                  ),
                  SizedBox(height: tokens.spacing.x3),
                  UiDataTable(
                    columns: const [
                      UiDataColumn(label: 'Work item', flex: 3),
                      UiDataColumn(label: 'Priority', numeric: true),
                    ],
                    rows: [
                      for (var i = 0; i < _rows.length; i++)
                        UiDataRow(
                          key: ValueKey(_rows[i]),
                          semanticLabel: _rows[i],
                          cells: [
                            UiText(
                              _rows[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            UiText('${i + 1}'),
                          ],
                        ),
                    ],
                    scrollable: false,
                    reorderEnabled: !_locked,
                    onReorder: (from, to) => setState(() {
                      final item = _rows.removeAt(from);
                      _rows.insert(to, item);
                      _status = '$item is now priority ${to + 1}.';
                    }),
                  ),
                  SizedBox(height: tokens.spacing.x8),
                  const UiText(
                    'Preparation',
                    variant: UiTextVariant.subheading,
                  ),
                  SizedBox(height: tokens.spacing.x2),
                  const UiText(
                    'The same grip works with your own row content.',
                    tone: UiTextTone.muted,
                  ),
                  SizedBox(height: tokens.spacing.x3),
                  UiReorderableList<String>(
                    items: _checks,
                    itemKey: ValueKey.new,
                    itemLabel: (item) => item,
                    enabled: !_locked,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    onReorder: (from, to) => setState(() {
                      final item = _checks.removeAt(from);
                      _checks.insert(to, item);
                      _status = '$item moved to step ${to + 1}.';
                    }),
                    itemBuilder: (context, item, index, handle) => Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: tokens.colors.border),
                        ),
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: tokens.spacing.x2,
                      ),
                      child: Row(
                        children: [
                          handle,
                          Expanded(child: UiText(item)),
                          SizedBox(width: tokens.spacing.x3),
                          UiText('${index + 1}', tone: UiTextTone.muted),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: tokens.spacing.x8),
                  const UiText(
                    'Move work forward',
                    variant: UiTextVariant.subheading,
                  ),
                  SizedBox(height: tokens.spacing.x2),
                  const UiText(
                    'Drag the handoff into Ready, or use its action button. On touch, hold before moving.',
                    tone: UiTextTone.muted,
                  ),
                  SizedBox(height: tokens.spacing.x4),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final source = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          UiDraggable<String>(
                            data: 'Component handoff',
                            semanticLabel: 'Component handoff',
                            enabled: !_ready.contains('Component handoff'),
                            feedbackBuilder: (_) => const _Handoff(),
                            child: const _Handoff(),
                          ),
                          SizedBox(height: tokens.spacing.x3),
                          UiButton(
                            label: _ready.isEmpty
                                ? 'Move to Ready'
                                : 'Moved to Ready',
                            intent: UiIntent.neutral,
                            onPressed: _ready.isEmpty
                                ? () => _moveReady('Component handoff')
                                : null,
                          ),
                        ],
                      );
                      final target = UiDropRegion<String>(
                        semanticLabel: 'Ready for review',
                        canAccept: (value) => !_ready.contains(value),
                        onAccept: _moveReady,
                        builder: (context, state) => Padding(
                          padding: EdgeInsets.all(tokens.spacing.x5),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              UiText(
                                state == UiDropState.accepting
                                    ? 'Release to move here'
                                    : 'Ready for review',
                                variant: UiTextVariant.subheading,
                              ),
                              SizedBox(height: tokens.spacing.x3),
                              UiText(
                                _ready.isEmpty
                                    ? 'Drop the component handoff here.'
                                    : _ready.join(', '),
                                tone: UiTextTone.muted,
                              ),
                              SizedBox(height: tokens.spacing.x4),
                              UiText(
                                '${_ready.length} item${_ready.length == 1 ? '' : 's'}',
                                variant: UiTextVariant.caption,
                                tone: UiTextTone.muted,
                              ),
                            ],
                          ),
                        ),
                      );
                      return constraints.maxWidth < 640
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                source,
                                SizedBox(height: tokens.spacing.x4),
                                target,
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: source),
                                SizedBox(width: tokens.spacing.x6),
                                Expanded(child: target),
                              ],
                            );
                    },
                  ),
                  SizedBox(height: tokens.spacing.x6),
                  Semantics(
                    liveRegion: true,
                    child: UiText(
                      _status,
                      variant: UiTextVariant.caption,
                      tone: UiTextTone.muted,
                    ),
                  ),
                  SizedBox(height: tokens.spacing.x3),
                  const UiText(
                    'Illustrative data · No changes are saved',
                    variant: UiTextVariant.caption,
                    tone: UiTextTone.muted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Handoff extends StatelessWidget {
  const _Handoff();

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return Container(
      padding: EdgeInsets.all(tokens.spacing.x5),
      decoration: BoxDecoration(
        color: tokens.colors.card,
        border: Border.all(color: tokens.colors.border),
        borderRadius: tokens.radius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const UiText('Component handoff', variant: UiTextVariant.subheading),
          SizedBox(height: tokens.spacing.x2),
          const UiText(
            'Examples, interaction notes, and acceptance checks.',
            tone: UiTextTone.muted,
          ),
        ],
      ),
    );
  }
}
