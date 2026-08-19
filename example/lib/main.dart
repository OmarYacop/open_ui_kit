import 'package:flutter/widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  runApp(const _ContourDemoApp());
}

class _ContourDemoApp extends StatelessWidget {
  const _ContourDemoApp();

  @override
  Widget build(BuildContext context) {
    return UiApp(
      title: 'Contour demo',
      localizationsDelegates: const [DefaultWidgetsLocalizations.delegate],
      home: const _ContourDemoPage(),
    );
  }
}

class _ContourDemoPage extends StatefulWidget {
  const _ContourDemoPage();

  @override
  State<_ContourDemoPage> createState() => _ContourDemoPageState();
}

class _ContourDemoPageState extends State<_ContourDemoPage> {
  String _status = 'No action taken yet.';

  void _handle(String action) {
    setState(
      () => _status =
          '$action at ${DateTime.now().toIso8601String().substring(11, 19)}',
    );
  }

  List<UiContourReleaseAction> _actions({bool archiveDisabled = false}) {
    return [
      UiContourReleaseAction(
        icon: const Icon(LucideIcons.reply),
        semanticsLabel: 'Reply',
        onPressed: () => _handle('Replied'),
      ),
      UiContourReleaseAction(
        icon: const Icon(LucideIcons.archive),
        semanticsLabel: 'Archive',
        onPressed: archiveDisabled ? null : () => _handle('Archived'),
      ),
      UiContourReleaseAction(
        icon: const Icon(LucideIcons.star),
        semanticsLabel: 'Favorite',
        onPressed: () => _handle('Favorited'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(color: tokens.colors.background),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const UiText('Message toolbar', variant: UiTextVariant.heading),
              const SizedBox(height: 8),
              UiText(_status, variant: UiTextVariant.caption),
              const SizedBox(height: 16),
              _ToolCard(
                child: UiContourRelease(
                  label: 'More',
                  intent: UiIntent.neutral,
                  actions: _actions(),
                ),
              ),
              const SizedBox(height: 32),
              const UiText(
                'One action disabled',
                variant: UiTextVariant.subheading,
              ),
              const SizedBox(height: 12),
              _ToolCard(
                child: UiContourRelease(
                  label: 'More',
                  intent: UiIntent.neutral,
                  actions: _actions(archiveDisabled: true),
                ),
              ),
              const SizedBox(height: 32),
              const UiText('RTL', variant: UiTextVariant.subheading),
              const SizedBox(height: 12),
              _ToolCard(
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: UiContourRelease(
                    label: 'المزيد',
                    intent: UiIntent.neutral,
                    actions: _actions(),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const UiText('Reduced motion', variant: UiTextVariant.subheading),
              const SizedBox(height: 12),
              _ToolCard(
                child: MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(disableAnimations: true),
                  child: UiContourRelease(
                    label: 'More',
                    intent: UiIntent.neutral,
                    actions: _actions(),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              const UiText(
                'Bottom nav → search accessory',
                variant: UiTextVariant.heading,
              ),
              const SizedBox(height: 8),
              const UiText(
                'Two independent surfaces sharing one progress timeline: the '
                'bar recedes by exactly the width the search accessory '
                'claims, which grows from the search icon\'s position with a '
                'bounded backdrop blur — not a shared capsule.',
                variant: UiTextVariant.body,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 360,
                child: UiContourAccessoryRelease(
                  intent: UiIntent.neutral,
                  items: [
                    UiContourBarItem(
                      icon: const Icon(LucideIcons.house),
                      semanticsLabel: 'Home',
                      onPressed: () {},
                    ),
                    UiContourBarItem(
                      icon: const Icon(LucideIcons.messageSquare),
                      semanticsLabel: 'Messages',
                      onPressed: () {},
                    ),
                    UiContourBarItem(
                      icon: const Icon(LucideIcons.user),
                      semanticsLabel: 'Profile',
                      onPressed: () {},
                    ),
                  ],
                  accessoryChild: const UiText(
                    'Search messages…',
                    variant: UiTextVariant.body,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              const UiText(
                'The real UiBottomTabBar already has this',
                variant: UiTextVariant.heading,
              ),
              const SizedBox(height: 8),
              const UiText(
                'UiBottomTabBar ships its own UiBottomTabAccessory: tapping '
                'search shrinks the selected tab into its own island and the '
                'accessory takes the freed width — the production dock, '
                'blur, and shadow, unmodified. Home has no accessory at all, '
                'so switching to/from it exercises presence (the accessory '
                'shell itself growing/shrinking away). Switching directly '
                'between Messages and Profile instead exercises the '
                'crossfade layer: the accessory shell stays put and only its '
                'icon + placeholder cross-dissolve.',
                variant: UiTextVariant.body,
              ),
              const SizedBox(height: 16),
              const RepaintBoundary(
                key: ValueKey('real-bottom-tab-accessory-demo'),
                child: _RealBottomTabAccessoryDemo(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A bounded "device frame" hosting the kit's real, unmodified
/// [UiBottomTabScaffold] + [UiBottomTabAccessory] so the existing production
/// mechanism can be previewed the same way the Contour prototypes above
/// are — nothing here is a copy or a reimplementation.
///
/// This deliberately goes through [UiBottomTabScaffold], not raw
/// [UiBottomTabBar] directly — [UiBottomTabBar] is documented as a
/// low-level, caller-driven primitive whose `accessoryPresence` the caller
/// must animate itself (analogous to `UiContourController` needing a
/// caller to drive it). `UiBottomTabScaffold` is the integration point that
/// actually owns that animation (via `UiContourPresenceController`); using
/// the bar directly, as an earlier revision of this demo did, bypasses it
/// entirely and made the accessory appear to snap in with no transition.
class _RealBottomTabAccessoryDemo extends StatefulWidget {
  const _RealBottomTabAccessoryDemo();

  @override
  State<_RealBottomTabAccessoryDemo> createState() =>
      _RealBottomTabAccessoryDemoState();
}

class _RealBottomTabAccessoryDemoState
    extends State<_RealBottomTabAccessoryDemo> {
  int _currentIndex = 0;
  bool _searchExpanded = false;

  static const _items = [
    UiBottomTabItem(label: 'Home', icon: Icon(LucideIcons.house)),
    UiBottomTabItem(label: 'Messages', icon: Icon(LucideIcons.messageSquare)),
    UiBottomTabItem(label: 'Profile', icon: Icon(LucideIcons.user)),
  ];

  IconData _searchIconFor(int index) => switch (index) {
    1 => LucideIcons.mail,
    2 => LucideIcons.userSearch,
    _ => LucideIcons.search,
  };

  String _searchPlaceholderFor(int index) => switch (index) {
    1 => 'Search messages…',
    2 => 'Search people…',
    _ => 'Search…',
  };

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    // Captured here, once per real build of *this* state — not inside any
    // nested builder closure. A closure that instead read `_currentIndex`
    // directly would only evaluate when its own Element later rebuilds,
    // which happens after `_currentIndex` has already moved on — so the
    // *retained* (fading-out) accessory instance would end up rendering the
    // *new* tab's icon too, defeating the cross-dissolve. Plain locals
    // closed over here are fixed the moment this build runs.
    final searchIcon = _searchIconFor(_currentIndex);
    final searchPlaceholder = _searchPlaceholderFor(_currentIndex);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.surfaceMuted,
        border: Border.all(color: tokens.colors.border),
        borderRadius: tokens.radius.mdAll,
      ),
      child: ClipRRect(
        borderRadius: tokens.radius.mdAll,
        child: SizedBox(
          width: 360,
          height: 280,
          child: UiBottomTabScaffold(
            items: _items,
            currentIndex: _currentIndex,
            onChanged: (i) => setState(() {
              _currentIndex = i;
              // Home has no search accessory; switching to it must not
              // leave a stale expanded search behind.
              if (i == 0) _searchExpanded = false;
            }),
            // One page per tab — the scaffold owns page preservation and
            // the floating-dock layout around whichever page is showing.
            pages: [
              for (final item in _items)
                Center(
                  child: UiText(
                    '${item.label} page content behind the dock',
                    variant: UiTextVariant.caption,
                    tone: UiTextTone.muted,
                  ),
                ),
            ],
            // Only Messages/Profile offer search — Home does not. Home
            // tests presence (existence appearing/disappearing). Messages
            // <-> Profile tests the *other* case: the accessory shell stays
            // in place the whole time and only its content — a different
            // icon and placeholder per tab — cross-dissolves. Using the
            // exact same content on both tabs would make that transition
            // invisible even if it were firing correctly.
            bottomAccessory: _currentIndex == 0
                ? null
                : UiBottomTabAccessory(
                    expanded: _searchExpanded,
                    leadingItem: _items[_currentIndex],
                    onLeadingPressed: () =>
                        setState(() => _searchExpanded = false),
                    child: _searchExpanded
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Icon(searchIcon, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: UiText(
                                    searchPlaceholder,
                                    variant: UiTextVariant.body,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : UiPressable(
                            onPressed: () =>
                                setState(() => _searchExpanded = true),
                            semanticsLabel: 'Search',
                            builder: (context, state, _) =>
                                Center(child: Icon(searchIcon, size: 18)),
                          ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// A stable-width card: it does not shrink-wrap [child], so the card itself
/// never grows or shrinks as the Contour control inside it expands and
/// collapses — only the control's own hairline-bordered surface should
/// visibly change shape. Trailing placeholder content makes the available
/// space, and the control's origin/destination within it, legible.
class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.child});

  final Widget child;

  static const _width = 360.0;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.surface,
        border: Border.all(color: tokens.colors.border),
        borderRadius: tokens.radius.mdAll,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: _width,
          child: Row(
            children: [
              child,
              const Spacer(),
              Container(
                width: 96,
                height: 12,
                decoration: BoxDecoration(
                  color: tokens.colors.surfaceMuted,
                  borderRadius: tokens.radius.smAll,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
