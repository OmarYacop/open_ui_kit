import 'package:flutter/widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() => runApp(const UiApp(home: BottomNavigationExample()));

/// Canonical navigation example: no overflow-mode or geometry overrides.
class BottomNavigationExample extends StatefulWidget {
  const BottomNavigationExample({super.key});
  @override
  State<BottomNavigationExample> createState() =>
      _BottomNavigationExampleState();
}

class _BottomNavigationExampleState extends State<BottomNavigationExample> {
  final _order = UiBottomTabDrawerController();
  final _query = TextEditingController();
  int _selected = 0;
  bool _searching = false;
  static const _items = [
    UiBottomTabItem(id: 'home', label: 'Home', icon: Icon(LucideIcons.house)),
    UiBottomTabItem(
      id: 'classes',
      label: 'Classes',
      icon: Icon(LucideIcons.calendar),
    ),
    UiBottomTabItem(
      id: 'chat',
      label: 'Chat',
      icon: Icon(LucideIcons.messageCircle),
      badge: 3,
    ),
    UiBottomTabItem(
      id: 'account',
      label: 'Account',
      icon: Icon(LucideIcons.user),
    ),
    UiBottomTabItem(
      id: 'alerts',
      label: 'Alerts',
      icon: Icon(LucideIcons.megaphone),
    ),
    UiBottomTabItem(
      id: 'notifications',
      label: 'Notifications',
      icon: Icon(LucideIcons.bell),
    ),
    UiBottomTabItem(
      id: 'requests',
      label: 'Requests',
      icon: Icon(LucideIcons.calendarX),
    ),
    UiBottomTabItem(
      id: 'library',
      label: 'Library',
      icon: Icon(LucideIcons.library),
    ),
  ];
  @override
  void dispose() {
    _order.dispose();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UiBottomTabScaffold(
    items: _items,
    currentIndex: _selected,
    drawerController: _order,
    onChanged: (index) => setState(() {
      _selected = index;
      _searching = false;
    }),
    pages: [
      for (final item in _items)
        Center(child: UiText(item.label, variant: UiTextVariant.heading)),
    ],
    bottomAccessory: _selected == 2 || _selected == 7
        ? UiBottomTabAccessory(
            expanded: _searching,
            height: 48,
            collapsedWidth: 48,
            leadingItem: const UiBottomTabItem(
              label: 'Close search',
              icon: Icon(LucideIcons.x),
            ),
            onLeadingPressed: () => setState(() => _searching = false),
            child: _searching
                ? UiInput(
                    controller: _query,
                    hint: 'Search ${_items[_selected].label.toLowerCase()}',
                  )
                : UiIconButton(
                    icon: const Icon(LucideIcons.search),
                    semanticsLabel: 'Search',
                    onPressed: () => setState(() => _searching = true),
                  ),
          )
        : null,
  );
}
