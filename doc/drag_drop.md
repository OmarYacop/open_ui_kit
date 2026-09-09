# Drag and drop

Import `package:open_ui_kit/open_ui_kit.dart`, or the focused
`package:open_ui_kit/components/drag_drop.dart` barrel.

The suite supports in-app payload transfer and vertical sorting. The application
owns data; pickup and hover do not mutate it. Commit changes in `onAccept` or
`onReorder`. Native file drops, multi-item selection, grid sorting and cross-list
insertion are outside this first version.

## Opt-in table sorting

Tables retain their existing rendering path when `onReorder` is null. There are
no drag handles, reorder controllers or drop targets added to ordinary tables.
Providing `onReorder` enables sorting; `reorderEnabled: false` temporarily locks
it while retaining the handle column and its alignment.

```dart
UiDataTable(
  columns: const [UiDataColumn(label: 'Task')],
  rows: [
    for (final task in tasks)
      UiDataRow(
        key: ValueKey(task.id),
        semanticLabel: task.title,
        cells: [UiText(task.title)],
      ),
  ],
  onReorder: (from, to) => setState(() {
    tasks.insert(to, tasks.removeAt(from));
  }),
)
```

Indices are **final positions after removal**. Do not decrement `to` for a
downward move. Update the backing collection synchronously in `onReorder`.
Keys must be unique, immutable identities, never current indices
or editable titles. Keep sorted/paginated data coherent in the application:
indices refer to the supplied visible collection, not a remote dataset.

`UiDataTable.lazy` accepts `rowKeyBuilder` (required when reordering) and
`rowLabelBuilder`. These read cheap metadata independently of `rowBuilder`, so
cells stay lazy. Use bounded scrolling for large datasets. `scrollable: false`
expands every row to participate in an ancestor scroll view and is for small
collections. `UiSliverDataTable` has no sorting API in this version.

Sortable table rows use a fixed extent of `max(44, rowExtent)` logical pixels;
the minimum preserves the handle's 44px target. Increase `rowExtent` for taller
content, and check text fitting at the application's supported text scales.
With `scrollable: true`, `maxBodyHeight` caps the body viewport. The opt-in path
uses the reorderable list regardless of `lazyRowThreshold`.

In the lazy sorting path, keys are snapshotted once at pickup and compared before
commit or when the parent updates during a drag. That is O(n) metadata work;
with bounded scrolling, row construction uses the viewport and its cache rather
than eagerly building every cell. This is an implementation constraint, not a
frame-rate guarantee; profile representative content on target devices. Debug
builds additionally validate uniqueness. An external order/identity change cancels the active drag
rather than applying stale indices. Immutable payload updates that keep identity
and order stable do not cancel it.

## Custom sortable content

`UiReorderableList<T>` supplies a wired `handle` to the item builder. Place it in
any row, card or custom composition. Only the handle captures drag gestures; child
buttons and editors retain their own gestures.

```dart
UiReorderableList<Task>(
  items: tasks,
  itemKey: (task) => ValueKey(task.id),
  itemLabel: (task) => task.title,
  onReorder: (from, to) => setState(() {
    tasks.insert(to, tasks.removeAt(from));
  }),
  itemBuilder: (context, task, index, handle) => Row(
    children: [handle, Expanded(child: UiText(task.title))],
  ),
)
```

Use `.builder(itemCount: ..., itemAt: ...)` for lazy data access. Builders need a
bounded height unless `shrinkWrap` is explicitly enabled. A dedicated 44px handle
starts immediately on touch and mouse. The rest of the row remains available for
scrolling. Keyboard users focus a handle and use Up/Down; focus follows the moved
item. Screen readers receive corresponding custom move actions. Override
`moveUpLabel`, `moveDownLabel` and item labels for the application's locale.

## Typed transfer

Wrap custom content in `UiDraggable<T>` and a destination in `UiDropRegion<T>`.
Only matching types are eligible. `canAccept` can reject a compatible payload;
acceptance is rechecked at release because permissions or application state may
have changed since hover.

```dart
UiDraggable<Task>(
  data: task,
  semanticLabel: task.title,
  feedbackBuilder: (_) => TaskPreview(task: task),
  child: TaskTile(task: task),
)

UiDropRegion<Task>(
  semanticLabel: 'Ready for review',
  canAccept: (task) => task.canReview,
  onAccept: moveToReady,
  builder: (context, state) => Padding(
    padding: EdgeInsets.all(UiThemeTokens.of(context).spacing.x5),
    child: UiText(switch (state) {
      UiDropState.accepting => 'Release to move here',
      UiDropState.rejecting => 'This task cannot move here',
      UiDropState.disabled => 'Review queue unavailable',
      UiDropState.idle => 'Ready for review',
    }),
  ),
)
```

Build a separate, non-interactive feedback widget: a live editor or globally keyed
subtree must not be duplicated in the overlay. The preview retains source size
and theme. Keep its title and distinguishing content recognizable as the source;
`feedbackBuilder` owns that content, so the kit cannot enforce visual identity.
Its source remains visible at reduced opacity to preserve spatial
context. `activation` defaults to adaptive: mouse pickup is immediate; touch and
stylus wait for a long press to preserve scrolling. Explicit immediate and
long-press policies are also available. `enabled: false` prevents new drags.

Dropping outside a compatible destination has no data effect. `onDragEnd` reports
Flutter's gesture result, **not a successful business operation**; never remove a
source based only on its `wasAccepted` value. The receiving `onAccept` callback is
the commit point, including when last-moment validation rejects a hovered item.

Always offer an equivalent button/menu command for transfers. A semantic label
alone does not make spatial dragging operable with a keyboard or screen reader.
The example provides a “Move to Ready” button using exactly the same operation.

## Motion and appearance

The existing kit identity remains authoritative: neutral surfaces, token radii,
precise boundaries, and elevation only for the item lifted into the overlay.
There is no decorative rotation, bounce, or scaling of text.

- Pickup interpolates the preview's shadow using the theme's fast duration and
  standard curve. Custom feedback remains source-sized.
- Destinations interpolate their border and tonal fill with fast theme timing.
  Accepting uses the primary token; rejecting uses the destructive token. Provide
  distinct builder copy so acceptance does not depend on color alone.
- Sortable rows use Flutter's widgets-layer `ReorderableList`: neighbors open a
  gap, edge proximity scrolls the list, and release returns the proxy into place.
  The shared proxy shadow follows that same pickup/drop animation.
- Theme/platform reduced-motion tokens remove suite-owned boundary, hover and
  pickup interpolation. Flutter owns the list's gap and return timing (250ms in
  the supported SDK) and its system accessibility reduction. A MediaQuery-only
  override does not retime those framework controllers.

## Example and verification

The entry point is `example/lib/drag_drop_main.dart`. The repository example has
no checked-in macOS or iOS runner. Configure a platform host before attempting a
native launch; the command below assumes a macOS runner has already been added
to your local example host. From that host's directory, run:

```sh
flutter run -d macos -t lib/drag_drop_main.dart
```

The workbench includes table sorting with a lock control, custom checklist rows,
and a typed transfer with an equivalent button. All content is illustrative.
For a separate preview host, copy the workbench and entry point into its `lib/`
directory and add a local path dependency on this package.

Behavior coverage lives in `test/components/drag_drop_test.dart`; responsive
example coverage is in `example/test/drag_drop_workbench_test.dart`. Existing
golden baselines must not be updated as part of this feature.

Tracked by [OMA-54](https://linear.app/omar-yacop/issue/OMA-54/composable-drag-and-drop-suite-for-rows-and-custom-components).
