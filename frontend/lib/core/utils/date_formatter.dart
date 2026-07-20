import 'package:intl/intl.dart';

class DateFormatter {
  static String formatHeaderDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return "Today";
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return "Yesterday";
    }
    return DateFormat('MMMM d').format(date); // e.g., April 15
  }

  static String formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date.toLocal()); // 24-hour time
  }
}