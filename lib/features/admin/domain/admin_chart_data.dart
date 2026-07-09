import '../../../features/auth/domain/auth_user.dart';
import '../../fraud_detection/domain/chart_data.dart' show MonthPoint;

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Pure chart-data builders for the Admin Dashboard/Analytics screens —
/// mirrors the pattern already established by
/// `fraud_detection/domain/chart_data.dart` (pre-aggregate once, dumb chart
/// widgets after), reusing its [MonthPoint] shape rather than a parallel one.
class AdminChartData {
  AdminChartData._();

  /// New registrations per month, last 6 months.
  static List<MonthPoint> monthlyRegistrations(
      List<AuthUser> users, DateTime now) {
    return [
      for (var i = 5; i >= 0; i--)
        () {
          final m = DateTime(now.year, now.month - i);
          final count = users
              .where((u) =>
                  u.createdAt.year == m.year && u.createdAt.month == m.month)
              .length;
          return MonthPoint(_months[m.month - 1], count.toDouble());
        }(),
    ];
  }

  /// Cumulative user growth (running total), last 6 months.
  static List<MonthPoint> userGrowth(List<AuthUser> users, DateTime now) {
    final monthly = monthlyRegistrations(users, now);
    // Users created before the 6-month window still count toward the
    // running total's starting point.
    final windowStart = DateTime(now.year, now.month - 5);
    var running =
        users.where((u) => u.createdAt.isBefore(windowStart)).length;
    return [
      for (final m in monthly)
        () {
          running += m.value.toInt();
          return MonthPoint(m.label, running.toDouble());
        }(),
    ];
  }

  /// Distinct users active (by lastLogin) within each of the last 8 weekly
  /// windows — the Analytics screen's "Weekly Active Users" trend, distinct
  /// from the Dashboard's day-by-day [dailyActiveUsers].
  static List<MonthPoint> weeklyActiveUsers(List<AuthUser> users, DateTime now) {
    return [
      for (var i = 7; i >= 0; i--)
        () {
          final weekStart =
              now.subtract(Duration(days: now.weekday - 1 + i * 7));
          final weekEnd = weekStart.add(const Duration(days: 7));
          final count = users
              .where((u) =>
                  u.lastLogin != null &&
                  !u.lastLogin!.isBefore(weekStart) &&
                  u.lastLogin!.isBefore(weekEnd))
              .length;
          return MonthPoint('${weekStart.day}/${weekStart.month}', count.toDouble());
        }(),
    ];
  }

  /// Users whose last login fell on each of the last 7 days — the closest
  /// signal to "Daily Active Users" available without a separate session
  /// log (this app has no session-tracking infra beyond `lastLogin`).
  static List<MonthPoint> dailyActiveUsers(
      List<AuthUser> users, DateTime now) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return [
      for (var i = 6; i >= 0; i--)
        () {
          final day = DateTime(now.year, now.month, now.day - i);
          final count = users
              .where((u) =>
                  u.lastLogin != null &&
                  u.lastLogin!.year == day.year &&
                  u.lastLogin!.month == day.month &&
                  u.lastLogin!.day == day.day)
              .length;
          return MonthPoint(days[day.weekday - 1], count.toDouble());
        }(),
    ];
  }
}
