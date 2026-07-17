import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

/// Predicate the picker consults before accepting a date — return
/// `true` for dates that should be non-selectable (e.g. weekends).
typedef UiDatePredicate = bool Function(DateTime date);

/// Which sub-view the calendar surface is showing.
///
/// Exposed as public test hooks via keys (see [datePickerMonthGridKey]
/// / [datePickerYearGridKey]) so integration tests can assert the
/// correct view is active without reflecting into private state.
enum _DateView { days, months, years }

/// Test-only keys for the calendar sub-grids. `@visibleForTesting` is
/// intentionally omitted so call sites in the test package don't need
/// to import meta — the keys are harmless if read in production.
const ValueKey<String> datePickerDayGridKey =
    ValueKey('ui_date_picker_day_grid');
const ValueKey<String> datePickerMonthGridKey =
    ValueKey('ui_date_picker_month_grid');
const ValueKey<String> datePickerYearGridKey =
    ValueKey('ui_date_picker_year_grid');
const ValueKey<String> datePickerHeaderTriggerKey =
    ValueKey('ui_date_picker_header_trigger');

/// Month-grid calendar with forward/back navigation and direct
/// month/year selection.
///
/// Tapping the header label cycles the visible sub-view:
/// `days → months → years → days`. Selecting a month or year
/// returns to the day grid with the new visible period applied.
///
/// Fully token-driven visuals — selected day uses `primary`, disabled
/// days mute via `textMuted`, today is outlined with `borderStrong`.
class UiDatePicker extends StatefulWidget {
  const UiDatePicker({
    super.key,
    this.value,
    this.rangeStart,
    this.rangeEnd,
    this.min,
    this.max,
    this.disabled,
    this.onChanged,
    this.weekdayLabels = const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'],
    this.monthLabels = const [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ],
    this.monthShortLabels = const [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ],
    this.firstDayOfWeek = DateTime.monday,
    this.daySemanticsPrefix,
  });

  final DateTime? value;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final DateTime? min;
  final DateTime? max;
  final UiDatePredicate? disabled;
  final ValueChanged<DateTime>? onChanged;

  /// 7 weekday labels, starting at [firstDayOfWeek].
  final List<String> weekdayLabels;

  /// Month names (January..December).
  final List<String> monthLabels;

  /// Short month names (Jan..Dec) used in the month grid for density.
  final List<String> monthShortLabels;

  /// `DateTime.monday` (1) or `DateTime.sunday` (7).
  final int firstDayOfWeek;

  /// Optional spoken prefix added ahead of each day-cell semantics label.
  ///
  /// Useful for composite pickers to clarify context (e.g. "Start date").
  final String? daySemanticsPrefix;

  @override
  State<UiDatePicker> createState() => _UiDatePickerState();
}

class _UiDatePickerState extends State<UiDatePicker> {
  late DateTime _visibleMonth;
  _DateView _view = _DateView.days;

  // Anchor for the year grid: a 12-year window whose first cell is
  // `_yearPageAnchor`. Re-anchored whenever the visible month year
  // changes so the selected year sits inside the currently-shown page.
  late int _yearPageAnchor;

  @override
  void initState() {
    super.initState();
    final seed = widget.value ?? DateTime.now();
    _visibleMonth = DateTime(seed.year, seed.month);
    _yearPageAnchor = _pageAnchorFor(seed.year);
  }

  static int _pageAnchorFor(int year) => year - (year % 12);

  void _shiftMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  void _shiftYearPage(int delta) {
    setState(() {
      _yearPageAnchor += delta * 12;
    });
  }

  void _cycleView() {
    setState(() {
      switch (_view) {
        case _DateView.days:
          _view = _DateView.months;
          break;
        case _DateView.months:
          _view = _DateView.years;
          break;
        case _DateView.years:
          _view = _DateView.days;
          break;
      }
    });
  }

  void _pickMonth(int month) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, month);
      _view = _DateView.days;
    });
  }

  void _pickYear(int year) {
    setState(() {
      _visibleMonth = DateTime(year, _visibleMonth.month);
      _yearPageAnchor = _pageAnchorFor(year);
      _view = _DateView.months;
    });
  }

  bool _isDisabled(DateTime day) {
    if (widget.min != null && day.isBefore(_dateOnly(widget.min!))) {
      return true;
    }
    if (widget.max != null && day.isAfter(_dateOnly(widget.max!))) {
      return true;
    }
    return widget.disabled?.call(day) ?? false;
  }

  bool _isSelected(DateTime day) {
    final v = widget.value;
    if (v == null) return false;
    return _dateOnly(v) == _dateOnly(day);
  }

  bool _isRangeEndpoint(DateTime day) {
    final d = _dateOnly(day);
    final start = widget.rangeStart;
    final end = widget.rangeEnd;
    final startHit = start != null && d == _dateOnly(start);
    final endHit = end != null && d == _dateOnly(end);
    return startHit || endHit;
  }

  bool _isInRange(DateTime day) {
    final start = widget.rangeStart;
    final end = widget.rangeEnd;
    if (start == null || end == null) return false;
    final a = _dateOnly(start);
    final b = _dateOnly(end);
    final from = a.isBefore(b) ? a : b;
    final to = b.isAfter(a) ? b : a;
    final d = _dateOnly(day);
    return d.isAfter(from) && d.isBefore(to);
  }

  bool _isToday(DateTime day) => _dateOnly(day) == _dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;

    // Tighter outer padding (shadcn-leaning: x2 was x3, row gap x1 was x2).
    return UiBox(
      background: c.surface,
      border: Border.all(color: c.border),
      borderRadius: tokens.radius.lgAll,
      padding: EdgeInsets.all(tokens.spacing.x2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Header(
            label: _headerLabelFor(_view),
            onPrev: _view == _DateView.years ? _shiftYearPage.bind(-1) : null,
            onNext: _view == _DateView.years ? _shiftYearPage.bind(1) : null,
            onPrevMonth: _view == _DateView.days ? () => _shiftMonth(-1) : null,
            onNextMonth: _view == _DateView.days ? () => _shiftMonth(1) : null,
            onLabelTap: _cycleView,
            view: _view,
          ),
          SizedBox(height: tokens.spacing.x1),
          if (_view == _DateView.days) ..._buildDaysView(tokens),
          if (_view == _DateView.months) _buildMonthsView(tokens),
          if (_view == _DateView.years) _buildYearsView(tokens),
        ],
      ),
    );
  }

  String _headerLabelFor(_DateView view) {
    switch (view) {
      case _DateView.days:
        return '${widget.monthLabels[_visibleMonth.month - 1]} '
            '${_visibleMonth.year}';
      case _DateView.months:
        return '${_visibleMonth.year}';
      case _DateView.years:
        return '$_yearPageAnchor – ${_yearPageAnchor + 11}';
    }
  }

  List<Widget> _buildDaysView(UiThemeTokens tokens) {
    final month = _visibleMonth;
    final monthStart = DateTime(month.year, month.month, 1);
    final nextMonthStart = DateTime(month.year, month.month + 1, 1);
    final daysInMonth = nextMonthStart.difference(monthStart).inDays;
    final leadingBlanks = (monthStart.weekday - widget.firstDayOfWeek) % 7;
    final totalCells = ((leadingBlanks + daysInMonth) / 7).ceil() * 7;

    return [
      _WeekdayRow(labels: widget.weekdayLabels),
      SizedBox(height: tokens.spacing.x1 / 2),
      _DayGrid(
        key: datePickerDayGridKey,
        totalCells: totalCells,
        leadingBlanks: leadingBlanks,
        daysInMonth: daysInMonth,
        dayBuilder: (dayIdx) {
          final day = DateTime(month.year, month.month, dayIdx + 1);
          final selected = _isSelected(day);
          final endpoint = _isRangeEndpoint(day);
          final inRange = _isInRange(day);
          final disabled = _isDisabled(day);
          final today = _isToday(day);
          return _DayCell(
            day: day,
            selected: selected || endpoint,
            inRange: inRange,
            disabled: disabled,
            today: today,
            rangeStart: widget.rangeStart,
            rangeEnd: widget.rangeEnd,
            semanticsPrefix: widget.daySemanticsPrefix,
            onTap: disabled ? null : () => widget.onChanged?.call(day),
          );
        },
      ),
    ];
  }

  Widget _buildMonthsView(UiThemeTokens tokens) {
    return _GridView(
      key: datePickerMonthGridKey,
      rows: 4,
      cols: 3,
      itemBuilder: (index) {
        final month = index + 1;
        final isSelected = _visibleMonth.month == month;
        return _GridCell(
          label: widget.monthShortLabels[index],
          selected: isSelected,
          onTap: () => _pickMonth(month),
          semanticsLabel: widget.monthLabels[index],
        );
      },
    );
  }

  Widget _buildYearsView(UiThemeTokens tokens) {
    return _GridView(
      key: datePickerYearGridKey,
      rows: 4,
      cols: 3,
      itemBuilder: (index) {
        final year = _yearPageAnchor + index;
        final isSelected = _visibleMonth.year == year;
        return _GridCell(
          label: '$year',
          selected: isSelected,
          onTap: () => _pickYear(year),
          semanticsLabel: '$year',
        );
      },
    );
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

// Tiny ergonomic helper so the _Header wiring reads cleanly.
extension _BindVoidCallback on void Function(int) {
  VoidCallback bind(int v) => () => this(v);
}

class _Header extends StatelessWidget {
  const _Header({
    required this.label,
    required this.view,
    required this.onLabelTap,
    this.onPrev,
    this.onNext,
    this.onPrevMonth,
    this.onNextMonth,
  });

  final String label;
  final _DateView view;
  final VoidCallback onLabelTap;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback? onPrevMonth;
  final VoidCallback? onNextMonth;

  @override
  Widget build(BuildContext context) {
    // Day view uses month-step arrows; year view uses 12-year page
    // arrows; month view hides arrows (its own grid owns navigation
    // via year-cycle).
    final prev = onPrevMonth ?? onPrev;
    final next = onNextMonth ?? onNext;
    return Row(
      children: [
        if (prev != null) _NavArrow(onPressed: prev, glyph: '‹') else
          const SizedBox(width: 32),
        Expanded(
          child: Center(
            child: _HeaderLabelTrigger(
              label: label,
              view: view,
              onTap: onLabelTap,
            ),
          ),
        ),
        if (next != null) _NavArrow(onPressed: next, glyph: '›') else
          const SizedBox(width: 32),
      ],
    );
  }
}

class _HeaderLabelTrigger extends StatelessWidget {
  const _HeaderLabelTrigger({
    required this.label,
    required this.view,
    required this.onTap,
  });

  final String label;
  final _DateView view;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    return Semantics(
      button: true,
      label: _semanticsLabel(),
      onTap: onTap,
      child: UiPressable(
        key: datePickerHeaderTriggerKey,
        onPressed: onTap,
        excludeFromSemantics: true,
        minTapSize: 32,
        builder: (context, state, _) => UiBox(
          background: state.hovered
              ? c.surfaceMuted
              : const Color(0x00000000),
          borderRadius: tokens.radius.smAll,
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.x2,
            vertical: tokens.spacing.x1,
          ),
          child: UiText(label, variant: UiTextVariant.subheading),
        ),
      ),
    );
  }

  String _semanticsLabel() {
    final next = switch (view) {
      _DateView.days => 'opens month picker',
      _DateView.months => 'opens year picker',
      _DateView.years => 'back to month grid',
    };
    return '$label, $next';
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.onPressed, required this.glyph});
  final VoidCallback onPressed;
  final String glyph;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return UiPressable(
      onPressed: onPressed,
      minTapSize: 32,
      builder: (context, state, _) => UiBox(
        background: state.hovered
            ? tokens.colors.surfaceMuted
            : const Color(0x00000000),
        borderRadius: tokens.radius.smAll,
        padding: EdgeInsets.all(tokens.spacing.x1),
        child: UiText(glyph, variant: UiTextVariant.subheading),
      ),
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow({required this.labels});
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final l in labels)
          Expanded(
            child: Center(
              child: UiText(
                l,
                variant: UiTextVariant.caption,
                tone: UiTextTone.muted,
              ),
            ),
          ),
      ],
    );
  }
}

class _DayGrid extends StatelessWidget {
  const _DayGrid({
    super.key,
    required this.totalCells,
    required this.leadingBlanks,
    required this.daysInMonth,
    required this.dayBuilder,
  });

  final int totalCells;
  final int leadingBlanks;
  final int daysInMonth;
  final Widget Function(int dayIdx) dayBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < totalCells ~/ 7; row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(child: _buildCell(row * 7 + col)),
            ],
          ),
      ],
    );
  }

  Widget _buildCell(int i) {
    final dayIdx = i - leadingBlanks;
    if (dayIdx < 0 || dayIdx >= daysInMonth) {
      return const AspectRatio(aspectRatio: 1, child: SizedBox.shrink());
    }
    return AspectRatio(aspectRatio: 1, child: dayBuilder(dayIdx));
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.inRange,
    required this.disabled,
    required this.today,
    required this.rangeStart,
    required this.rangeEnd,
    required this.semanticsPrefix,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool inRange;
  final bool disabled;
  final bool today;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final String? semanticsPrefix;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    return Semantics(
      container: true,
      button: true,
      enabled: !disabled,
      selected: selected,
      label: _semanticLabel(),
      onTap: disabled ? null : onTap,
      child: UiPressable(
        onPressed: onTap,
        enabled: onTap != null,
        excludeFromSemantics: true,
        minTapSize: 32,
        builder: (context, state, _) {
          final bg = selected
              ? c.primary
              : inRange
                  ? c.primary.withValues(alpha: 0.2)
                  : state.hovered
                      ? c.surfaceMuted
                      : const Color(0x00000000);
          final fg = selected
              ? c.onPrimary
              : disabled
                  ? c.textMuted
                  : c.textPrimary;
          // Cell inset is 1pt so the colored tile fills nearly the
          // whole AspectRatio box. Radius bumped to `mdAll` (8pt) for
          // a softer, more modern look; at this tile size `smAll`
          // (4pt) reads as almost-square.
          return Padding(
            padding: const EdgeInsets.all(1),
            child: UiBox(
              background: bg,
              borderRadius: tokens.radius.mdAll,
              border: !selected && !inRange && today
                  ? Border.all(color: c.borderStrong)
                  : null,
              alignment: Alignment.center,
              child: ExcludeSemantics(
                child: UiText(
                  '${day.day}',
                  variant: UiTextVariant.bodySm,
                  style: TextStyle(
                    color: fg,
                    fontWeight:
                        selected || today ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _semanticLabel() {
    final parts = <String>[
      if (semanticsPrefix != null && semanticsPrefix!.trim().isNotEmpty)
        semanticsPrefix!.trim(),
      _spokenDate(day),
      if (_isSameDay(day, rangeStart)) 'range start',
      if (_isSameDay(day, rangeEnd)) 'range end',
      if (inRange && !_isSameDay(day, rangeStart) && !_isSameDay(day, rangeEnd))
        'inside range',
      if (today) 'today',
      if (disabled) 'disabled',
      if (selected) 'selected',
    ];
    return parts.join(', ');
  }

  bool _isSameDay(DateTime day, DateTime? other) {
    if (other == null) return false;
    return day.year == other.year &&
        day.month == other.month &&
        day.day == other.day;
  }

  String _spokenDate(DateTime d) {
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const weekdays = <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

class _GridView extends StatelessWidget {
  const _GridView({
    super.key,
    required this.rows,
    required this.cols,
    required this.itemBuilder,
  });

  final int rows;
  final int cols;
  final Widget Function(int index) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var col = 0; col < cols; col++)
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1.6,
                    child: itemBuilder(r * cols + col),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _GridCell extends StatelessWidget {
  const _GridCell({
    required this.label,
    required this.selected,
    required this.semanticsLabel,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: '$semanticsLabel${selected ? ', selected' : ''}',
      onTap: onTap,
      child: UiPressable(
        onPressed: onTap,
        excludeFromSemantics: true,
        minTapSize: 32,
        builder: (context, state, _) {
          final bg = selected
              ? c.primary
              : state.hovered
                  ? c.surfaceMuted
                  : const Color(0x00000000);
          final fg = selected ? c.onPrimary : c.textPrimary;
          return Padding(
            padding: const EdgeInsets.all(2),
            child: UiBox(
              background: bg,
              borderRadius: tokens.radius.mdAll,
              alignment: Alignment.center,
              child: ExcludeSemantics(
                child: UiText(
                  label,
                  variant: UiTextVariant.bodySm,
                  style: TextStyle(
                    color: fg,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
