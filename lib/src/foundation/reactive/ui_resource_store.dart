import 'ui_collection_patch.dart';
import 'ui_store.dart';

/// A list-shaped store for feature resources such as sessions, invoices,
/// notifications, or any other UI collection with stable ids.
class UiResourceStore<T, TId> extends UiStore<List<T>> {
  UiResourceStore({
    required this.getId,
    Iterable<T> initialItems = const [],
  }) : super(List<T>.of(initialItems, growable: false));

  final UiItemId<T, TId> getId;

  List<T> get items => state;

  T? byId(TId id) {
    for (final item in state) {
      if (getId(item) == id) return item;
    }
    return null;
  }

  bool containsId(TId id) => byId(id) != null;

  void replaceAll(Iterable<T> items) {
    setState(List<T>.of(items, growable: false));
  }

  void updateWhere(UiItemPredicate<T> test, UiItemUpdater<T> update) {
    setState(UiCollectionPatch.replaceWhere(state, test, update));
  }

  void updateById(TId id, UiItemUpdater<T> update) {
    updateWhere((item) => getId(item) == id, update);
  }

  void removeWhere(UiItemPredicate<T> test) {
    setState(UiCollectionPatch.removeWhere(state, test));
  }

  void removeById(TId id) {
    removeWhere((item) => getId(item) == id);
  }

  void upsert(T item, {bool append = true}) {
    setState(
      UiCollectionPatch.upsertBy(
        state,
        item,
        getId: getId,
        append: append,
      ),
    );
  }

  void upsertAll(Iterable<T> items, {bool append = true}) {
    setState(
      UiCollectionPatch.upsertAllBy(
        state,
        items,
        getId: getId,
        append: append,
      ),
    );
  }
}
