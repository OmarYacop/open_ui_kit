import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  group('UiStore', () {
    test('updates state and notifies listeners only when value changes', () {
      final store = UiStore<int>(0);
      var notifications = 0;
      store.addListener(() => notifications++);

      store.setState(0);
      expect(notifications, 0);

      store.update((state) => state + 1);
      expect(store.state, 1);
      expect(store.value, 1);
      expect(notifications, 1);
    });

    testWidgets('UiSelector rebuilds when selected slice changes',
        (tester) async {
      final store = UiStore<_CounterState>(
        const _CounterState(count: 0, label: 'initial'),
      );
      var countBuilds = 0;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: UiStoreScope<_CounterState>(
            store: store,
            child: UiSelector<_CounterState, int>(
              selector: (state) => state.count,
              builder: (context, count, child) {
                countBuilds++;
                return Text('$count');
              },
            ),
          ),
        ),
      );

      expect(find.text('0'), findsOneWidget);
      expect(countBuilds, 1);

      store.update((state) => state.copyWith(label: 'changed'));
      await tester.pump();
      expect(countBuilds, 1);

      store.update((state) => state.copyWith(count: 1));
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
      expect(countBuilds, 2);
    });
  });

  group('UiCollectionPatch', () {
    test('replaces, removes, and upserts by id', () {
      const items = [
        _Item(id: 'a', label: 'A'),
        _Item(id: 'b', label: 'B'),
      ];

      final replaced = UiCollectionPatch.replaceWhere<_Item>(
        items,
        (item) => item.id == 'a',
        (item) => item.copyWith(label: 'AA'),
      );
      expect(replaced, const [
        _Item(id: 'a', label: 'AA'),
        _Item(id: 'b', label: 'B'),
      ]);

      final removed = UiCollectionPatch.removeWhere<_Item>(
        replaced,
        (item) => item.id == 'b',
      );
      expect(removed, const [_Item(id: 'a', label: 'AA')]);

      final upserted = UiCollectionPatch.upsertBy<_Item, String>(
        removed,
        const _Item(id: 'c', label: 'C'),
        getId: (item) => item.id,
      );
      expect(upserted, const [
        _Item(id: 'a', label: 'AA'),
        _Item(id: 'c', label: 'C'),
      ]);
    });
  });

  group('UiResourceStore', () {
    test('patches resource lists through stable ids', () {
      final store = UiResourceStore<_Item, String>(
        getId: (item) => item.id,
        initialItems: const [
          _Item(id: 'a', label: 'A'),
          _Item(id: 'b', label: 'B'),
        ],
      );

      store.updateById('a', (item) => item.copyWith(label: 'AA'));
      store.removeById('b');
      store.upsert(const _Item(id: 'c', label: 'C'));

      expect(store.items, const [
        _Item(id: 'a', label: 'AA'),
        _Item(id: 'c', label: 'C'),
      ]);
      expect(store.byId('c'), const _Item(id: 'c', label: 'C'));
    });
  });

  group('UiMutationController', () {
    test('tracks pending and success states', () async {
      final controller = UiMutationController();
      final statuses = <UiMutationStatus>[];
      controller.addListener(() => statuses.add(controller.state.status));

      final value = await controller.run(() async => 42);

      expect(value, 42);
      expect(statuses, [
        UiMutationStatus.pending,
        UiMutationStatus.success,
      ]);
      expect(controller.state.isSuccess, isTrue);
    });

    test('tracks failures and rethrows', () async {
      final controller = UiMutationController();

      await expectLater(
        controller.run<void>(() async => throw StateError('failed')),
        throwsStateError,
      );

      expect(controller.state.isFailure, isTrue);
      expect(controller.state.error, isA<StateError>());
    });
  });
}

class _CounterState {
  const _CounterState({required this.count, required this.label});

  final int count;
  final String label;

  _CounterState copyWith({int? count, String? label}) {
    return _CounterState(
      count: count ?? this.count,
      label: label ?? this.label,
    );
  }
}

class _Item {
  const _Item({required this.id, required this.label});

  final String id;
  final String label;

  _Item copyWith({String? label}) {
    return _Item(id: id, label: label ?? this.label);
  }

  @override
  bool operator ==(Object other) {
    return other is _Item && other.id == id && other.label == label;
  }

  @override
  int get hashCode => Object.hash(id, label);

  @override
  String toString() => '_Item($id, $label)';
}
