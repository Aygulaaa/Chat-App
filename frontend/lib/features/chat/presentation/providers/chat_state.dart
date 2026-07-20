import 'package:my_chat_app/features/chat/domain/entities/chat.dart';

class ChatState {
  final List<Chat> chats;
  final bool isLoading;
  final String? error;

  const ChatState({
    this.chats = const [],
    this.isLoading = false,
    this.error,
  });

  ChatState copyWith({
    List<Chat>? chats,
    bool? isLoading,
    String? error,
  }) {
    return ChatState(
      chats: chats ?? this.chats,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}