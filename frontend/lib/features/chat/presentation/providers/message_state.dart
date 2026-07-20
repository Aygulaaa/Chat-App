import 'package:my_chat_app/features/chat/domain/entities/message.dart';

class MessageState {
  final List<Message> messages;
  final bool isLoading;
  final String? error;
  final String? typingStatus;

  const MessageState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.typingStatus,
  });

  MessageState copyWith({
    List<Message>? messages,
    bool? isLoading,
    String? error,
    bool clearError = false,      
    String? typingStatus,
    bool clearTyping = false,    
  }) {
    return MessageState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,   
      error: clearError ? null : error ?? this.error,
      typingStatus: clearTyping ? null : typingStatus ?? this.typingStatus,
    );
  }
}