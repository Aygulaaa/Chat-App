class TimeUtils {
  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static String formatLastSeen(DateTime? dt, {String? fuzzy}) {
    if (dt == null) {
      if (fuzzy == 'recently') return 'last seen recently';
      if (fuzzy == 'within_a_week') return 'last seen within a week';
      if (fuzzy == 'within_a_month') return 'last seen within a month';
      if (fuzzy == 'long_time_ago') return 'last seen a long time ago';
      return 'last seen recently';
    }

    final now = DateTime.now();
    final localDt = dt.toLocal();
    final diff = now.difference(localDt);

    if (diff.inMinutes < 1) {
      return 'last seen just now';
    }
    if (diff.inMinutes >= 1 && diff.inMinutes < 60) {
      return 'last seen ${diff.inMinutes}m ago';
    }
    
    // Check if it's today
    if (now.year == localDt.year && now.month == localDt.month && now.day == localDt.day) {
      final hour = localDt.hour.toString().padLeft(2, '0');
      final minute = localDt.minute.toString().padLeft(2, '0');
      return 'last seen today at $hour:$minute';
    }

    // Check if it's yesterday
    final yesterday = now.subtract(const Duration(days: 1));
    if (yesterday.year == localDt.year && yesterday.month == localDt.month && yesterday.day == localDt.day) {
      final hour = localDt.hour.toString().padLeft(2, '0');
      final minute = localDt.minute.toString().padLeft(2, '0');
      return 'last seen yesterday at $hour:$minute';
    }
    
    // Otherwise return day and month (e.g. "10 April")
    final monthName = _months[localDt.month - 1];
    if (now.year == localDt.year) {
      return 'last seen ${localDt.day} $monthName';
    }

    return 'last seen ${localDt.day} $monthName ${localDt.year}';
  }
}