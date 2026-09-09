import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

/// Tab pages share the shell's single route. Only the active tab may publish
/// its title to the back-history stack, and a page that suppresses its large
/// title still contributes its compact title.
void main() {
  testWidgets(
    'history behind a page pushed from a tab names that tab, not a sibling',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var index = 0;
      await tester.pumpWidget(
        UiApp(
          lightTokens: UiThemeTokens.light,
          localizationsDelegates: const [DefaultWidgetsLocalizations.delegate],
          home: StatefulBuilder(
            builder: (context, setState) => UiBottomTabScaffold(
              items: const [
                UiBottomTabItem(label: 'Classes', icon: Icon(Icons.school)),
                UiBottomTabItem(label: 'Account', icon: Icon(Icons.person)),
              ],
              currentIndex: index,
              onChanged: (value) => setState(() => index = value),
              pages: [
                const CustomScrollView(
                  slivers: [
                    UiSliverNavigationBar(
                      spec: UiNavigationSpec(title: 'Classes'),
                    ),
                    SliverFillRemaining(child: Text('classes body')),
                  ],
                ),
                Builder(
                  builder: (context) => CustomScrollView(
                    slivers: [
                      const UiSliverNavigationBar(
                        spec: UiNavigationSpec(
                          title: '',
                          compactTitle: 'Account',
                        ),
                      ),
                      SliverFillRemaining(
                        child: Center(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (context) => CustomScrollView(
                                  slivers: [
                                    UiSliverNavigationBar(
                                      spec: UiNavigationSpec(
                                        title: 'Security',
                                        back: UiNavigationBackConfig(
                                          onPressed: () =>
                                              Navigator.maybePop(context),
                                        ),
                                      ),
                                    ),
                                    const SliverFillRemaining(
                                      child: Text('security body'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            child: const Text('open security'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Visit Classes first so its title is the stale candidate.
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(
              of: find.byType(UiExpandingBottomTabBar),
              matching: find.bySemanticsLabel('Account'),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open security'));
      await tester.pumpAndSettle();

      // The back button is labelled with the page behind it.
      expect(find.bySemanticsLabel('Classes'), findsNothing);
      await tester.longPress(find.bySemanticsLabel('Account'));
      await tester.pumpAndSettle();

      expect(find.text('Account'), findsWidgets);
      expect(find.text('Classes'), findsNothing);
    },
  );
}
