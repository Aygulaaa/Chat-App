class TimeUtils {
  static String formatLastSeen(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return 'last seen just now';
    }
    if (diff.inMinutes >= 1 && diff.inMinutes < 60) {
      return 'last seen ${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return 'last seen ${diff.inHours}h ago';
    }
    if (diff.inDays == 1) {
      return 'last seen yesterday';
    }
    
    return 'last seen ${dt.toLocal().day}/${dt.toLocal().month}/${dt.toLocal().year}'; 
  }
}