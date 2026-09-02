class ApiEndpoints {
  static const auth = '/api/auth';

  static const login = '$auth/login';
  static const register = '$auth/register';
  static const currentUser = '$auth/me';
  static const logout = '$auth/logout';
  static const changePassword = '$auth/password';
  static const verifyPassword = '$auth/verify-password';
  
  static const getSessions = '$auth/sessions';
  static const terminateOtherSessions = '$auth/sessions/others';
  static String revokeSession(int sessionId) => '$auth/sessions/$sessionId';

  static const chats = '/api/chats';

  static String chat(int chatId) => '$chats/$chatId';
  static String createChat(int contactId) => '$chats/create/$contactId';
  static String messages(int chatId) => '$chats/$chatId/messages';
  static String markMessagesRead(int chatId) => '$chats/$chatId/messages/read'; // Added
  static String fileMessage(int chatId) => '$chats/$chatId/messages/file';
  static const createGroupChat = '$chats/group';
  static String addMember(int chatId) => '$chats/$chatId/members';
  static String removeMember(int chatId, int userId) =>
      '$chats/$chatId/members/$userId';
  static String groupInfo(int chatId) => '$chats/$chatId/group';
  static String deleteChat(int chatId) => '$chats/$chatId';
  static String deleteGroup(int chatId) => '$chats/$chatId/group';
  static String deleteMessage(int chatId, int messageId) => '$chats/$chatId/messages/$messageId';

  static const users = '/api/users';

  static const me = '$users/me';
  static const uploadAvatar = '$users/avatar';
  static String userById(int userId) => '$users/user/$userId';
  static String sendFcmToken() => '$users/fcm-token';

  static const contacts = '/api/contacts';

  static const blocked = '$contacts/blocked';
  static String search(String query) => '$contacts/search?q=$query';
  static String contactAction(int contactId) => '$contacts/$contactId';
  static String blockAction(int contactId) => '$contacts/$contactId/block';

  static const settings = '/api/settings';
}