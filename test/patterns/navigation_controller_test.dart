import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';
import 'package:flutter/widgets.dart';

void main() {
  // Shared specs for these tests.
  final home = UiRouteSpec<void, void>(
    id: 'home',
    title: 'Home',
    builder: (_, __) => const SizedBox.shrink(),
  );
  final detail = UiRouteSpec<int, String>(
    id: 'detail',
    title: 'Detail',
    builder: (_, args) => Text('detail-$args'),
  );
  final editor = UiRouteSpec<void, bool>(
    id: 'editor',
    title: 'Editor',
    builder: (_, __) => const SizedBox.shrink(),
  );

  UiNavigationController makeController() =>
      UiNavigationController(routes: [home, detail, editor]);

  test('seeds with the first registered route', () {
    final c = makeController();
    expect(c.current?.id, 'home');
    expect(c.canPop, isFalse);
    c.dispose();
  });

  test('push adds an entry and returns a future that resolves on pop',
      () async {
    final c = makeController();
    final future = c.push(detail, args: 42);
    expect(c.current?.id, 'detail');
    expect(c.current?.args, 42);
    expect(c.canPop, isTrue);

    c.pop<String>('ok');
    final result = await future;
    expect(result, 'ok');
    expect(c.current?.id, 'home');
    c.dispose();
  });

  test('replace swaps the top and resolves the replaced future with null',
      () async {
    final c = makeController();
    final first = c.push(detail, args: 1);
    c.replace(editor);
    expect(await first, isNull);
    expect(c.current?.id, 'editor');
    c.dispose();
  });

  test('popUntil pops repeatedly to the named route', () {
    final c = makeController();
    c.push(detail, args: 1);
    c.push(editor);
    c.push(detail, args: 2);
    c.popUntil('home');
    expect(c.stack.length, 1);
    expect(c.current?.id, 'home');
    c.dispose();
  });

  test('go replaces the entire stack and completes prior futures', () async {
    final c = makeController();
    final pending = c.push(detail, args: 7);
    c.go(editor);
    expect(c.stack.length, 1);
    expect(c.current?.id, 'editor');
    expect(await pending, isNull);
    c.dispose();
  });

  test('pop returns false when there is nothing to pop', () {
    final c = makeController();
    expect(c.pop(), isFalse);
    c.dispose();
  });

  test('historyItems lists prior entries newest-first', () {
    final c = makeController();
    c.push(detail, args: 1);
    c.push(editor);
    final history = c.historyItems();
    expect(history.map((h) => h.title), ['Detail', 'Home']);
    c.dispose();
  });

  test('popTo pops directly to an entry reference', () async {
    final c = makeController();
    final homeEntry = c.current!;
    c.push(detail, args: 1);
    c.push(editor);
    c.popTo(homeEntry);
    expect(c.stack.length, 1);
    expect(c.current, homeEntry);
    c.dispose();
  });

  test(
    'pushing a spec not registered on the controller trips an assertion',
    () {
      final c = UiNavigationController(routes: [home]);
      final unknown = UiRouteSpec<void, void>(
        id: 'unknown',
        builder: (_, __) => const SizedBox.shrink(),
      );
      expect(() => c.push(unknown), throwsA(isA<AssertionError>()));
      c.dispose();
    },
    // Disabled in release/profile (asserts compiled out).
    skip: !_assertsEnabled(),
  );
}

bool _assertsEnabled() {
  var enabled = false;
  assert(() {
    enabled = true;
    return true;
  }());
  return enabled;
}
