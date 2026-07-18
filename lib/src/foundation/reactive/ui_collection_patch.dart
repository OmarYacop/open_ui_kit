typedef UiItemPredicate<T> = bool Function(T item);
typedef UiItemUpdater<T> = T Function(T item);
typedef UiItemId<T, TId> = TId Function(T item);

/// Immutable list patch helpers for resource-oriented UI state.
class UiCollectionPatch {
  const UiCollectionPatch._();

  static List<T> replaceWhere<T>(
    Iterable<T> items,
    UiItemPredicate<T> test,
    UiItemUpdater<T> update, {
    bool growable = false,
  }) {
    var changed = false;
    final next = <T>[];

    for (final item in items) {
      if (!test(item)) {
        next.add(item);
        continue;
      }
      final updated = update(item);
      changed = true;
      next.add(updated);
    }

    if (!changed && items is List<T>) {
      return List<T>.of(items, growable: growable);
    }
    return List<T>.of(next, growable: growable);
  }

  static List<T> removeWhere<T>(
    Iterable<T> items,
    UiItemPredicate<T> test, {
    bool growable = false,
  }) {
    return items.where((item) => !test(item)).toList(growable: growable);
  }

  static List<T> upsertBy<T, TId>(
    Iterable<T> items,
    T item, {
    required UiItemId<T, TId> getId,
    bool append = true,
    bool growable = false,
  }) {
    final id = getId(item);
    var replaced = false;
    final next = <T>[];

    for (final existing in items) {
      if (getId(existing) == id) {
        next.add(item);
        replaced = true;
      } else {
        next.add(existing);
      }
    }

    if (!replaced) {
      if (append) {
        next.add(item);
      } else {
        next.insert(0, item);
      }
    }

    return List<T>.of(next, growable: growable);
  }

  static List<T> upsertAllBy<T, TId>(
    Iterable<T> items,
    Iterable<T> updatedItems, {
    required UiItemId<T, TId> getId,
    bool append = true,
    bool growable = false,
  }) {
    var next = items.toList(growable: true);
    for (final item in updatedItems) {
      next = upsertBy<T, TId>(
        next,
        item,
        getId: getId,
        append: append,
        growable: true,
      );
    }
    return List<T>.of(next, growable: growable);
  }
}
