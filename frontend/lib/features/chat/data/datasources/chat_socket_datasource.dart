abstract class ChatSocketDatasource {
  void connect(String token);
  void disconnect();
  void requestOnlineUsers();

  Future<void> joinChat(int chatId);
  Future<void> sendMessage(dynamic message);
  Future<void> sendTypingEvent(int chatId, bool isTyping, int userId);
  Future<void> markChatAsRead(int chatId);
  Future<void> leaveChat(int chatId);

  Stream<Map<String, dynamic>> onMessage();
  Stream<Map<String, dynamic>> onUserTyping();
  Stream<Map<String, dynamic>> onUserStatusChanged();
  Stream<Map<String, dynamic>> onMessagesRead();
  Stream<Map<String, dynamic>> onChatRead();
  Stream<Map<String, dynamic>> onMessagesDelivered();
  Stream<List<int>> onInitialOnlineUsers();
}