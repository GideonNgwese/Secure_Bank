enum ReportRangePreset {
  today,
  thisWeek,
  thisMonth,
  lastMonth,
  thisYear,
  custom
}

extension ReportRangePresetLabel on ReportRangePreset {
  String get label => switch (this) {
        ReportRangePreset.today => 'Today',
        ReportRangePreset.thisWeek => 'This week',
        ReportRangePreset.thisMonth => 'This month',
        ReportRangePreset.lastMonth => 'Last month',
        ReportRangePreset.thisYear => 'This year',
        ReportRangePreset.custom => 'Custom range',
      };
}

/// A resolved [start, end] window plus the preceding period of equal length
/// (used for growth/comparison figures) — computed once so every chart and
/// stat in the Reports module reads from the exact same window.
class ReportDateRange {
  final ReportRangePreset preset;
  final DateTime start;
  final DateTime end;

  const ReportDateRange(
      {required this.preset, required this.start, required this.end});

  factory ReportDateRange.resolve(ReportRangePreset preset, DateTime now,
      {DateTime? customStart, DateTime? customEnd}) {
    DateTime s, e;
    switch (preset) {
      case ReportRangePreset.today:
        s = DateTime(now.year, now.month, now.day);
        e = s.add(const Duration(hours: 23, minutes: 59, seconds: 59));
      case ReportRangePreset.thisWeek:
        s = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        e = s.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      case ReportRangePreset.thisMonth:
        s = DateTime(now.year, now.month, 1);
        e = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      case ReportRangePreset.lastMonth:
        s = DateTime(now.year, now.month - 1, 1);
        e = DateTime(now.year, now.month, 0, 23, 59, 59);
      case ReportRangePreset.thisYear:
        s = DateTime(now.year, 1, 1);
        e = DateTime(now.year, 12, 31, 23, 59, 59);
      case ReportRangePreset.custom:
        s = customStart ?? DateTime(now.year, now.month, 1);
        e = customEnd ?? now;
    }
    return ReportDateRange(preset: preset, start: s, end: e);
  }

  /// The immediately-preceding window of the same length — e.g. "this
  /// month" compares against "last month", "this week" against "last week".
  ReportDateRange get previousPeriod {
    final length = end.difference(start);
    final prevEnd = start.subtract(const Duration(seconds: 1));
    final prevStart = prevEnd.subtract(length);
    return ReportDateRange(preset: preset, start: prevStart, end: prevEnd);
  }

  bool contains(DateTime date) => !date.isBefore(start) && !date.isAfter(end);

  int get days => end.difference(start).inDays + 1;
}
