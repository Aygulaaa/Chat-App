abstract class ChatSocketDatasource {
  void connect(String token);
  void disconnect();
  void requestOnlineUsers();

  Future<void> joinChat(int chatId);

  /// The chat currently on screen (null when none). Drives push suppression
  /// on the server and the auto "mark as read" here.
  void setActiveChat(int? chatId);
  int? get activeChatId;

  /// Whether the app is in the foreground. A backgrounded app keeps its
  /// socket, so the server must be told — otherwise the chat still counts as
  /// "open" and no notification is sent for it.
  void setAppForeground(bool foreground);
  bool get appInForeground;

  Future<void> sendMessage(dynamic message);
  Future<void> sendTypingEvent(int chatId, bool isTyping, int userId);
  Future<void> markChatAsRead(int chatId);
  Future<void> leaveChat(int chatId);
  void emitMessageReceived(int messageId);

  Stream<Map<String, dynamic>> onMessage();
  Stream<Map<String, dynamic>> onUserTyping();
  Stream<Map<String, dynamic>> onUserStatusChanged();
  Stream<Map<String, dynamic>> onMessagesRead();
  Stream<Map<String, dynamic>> onChatRead();
  Stream<Map<String, dynamic>> onMessagesDelivered();
  Stream<List<int>> onInitialOnlineUsers();
  Stream<int> onGroupDeleted();
  Stream<Map<String, dynamic>> onMessageDeleted();
  Stream<Map<String, dynamic>> onMessageReaction();
  Stream<void> onSessionsUpdated();
  Stream<void> onSessionRevoked();
}
