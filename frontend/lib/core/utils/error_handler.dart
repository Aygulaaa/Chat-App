class ErrorHandler {
  static String getReadableErrorMessage(dynamic error) {
    final msg = error.toString();
    
    if (msg.contains('SocketException') || msg.contains('Network') || msg.contains('Failed host lookup')) {
      return 'Please check your internet connection and try again.';
    } else if (msg.contains('Timeout') || msg.contains('time out')) {
      return 'The request took too long. Please try again.';
    } else if (msg.contains('Permission')) {
      return 'Permission denied. Please check your settings.';
    } else if (msg.contains('500') || msg.contains('Internal Server Error')) {
      return 'Server error occurred. Please try again later.';
    } else if (msg.contains('404')) {
      return 'Requested resource not found.';
    }
    
    // Clean up generic Exception prefix if it still exists
    return msg.replaceAll('Exception: ', '').trim();
  }
}
