import 'package:my_chat_app/features/chat/domain/entities/message.dart';

class MessageState {
  final List<Message> messages;
  final bool isLoading;
  final String? error;
  final String? typingStatus;
  final int? typingUserId;

  /// The message the user is currently composing a reply to (shown as a bar
  /// above the input). Null when not replying.
  final Message? replyingTo;

  /// Pagination of older history.
  final bool isLoadingMore;
  final bool hasMore;

  const MessageState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.typingStatus,
    this.typingUserId,
    this.replyingTo,
    this.isLoadingMore = false,
    this.hasMore = true,
  });

  MessageState copyWith({
    List<Message>? messages,
    bool? isLoading,
    String? error,
    bool clearError = false,      
    String? typingStatus,
    int? typingUserId,
    bool clearTyping = false,    
    Message? replyingTo,
    bool clearReply = false,
    bool? isLoadingMore,
    bool? hasMore,
  }) {
    return MessageState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,   
      error: clearError ? null : error ?? this.error,
      typingStatus: clearTyping ? null : typingStatus ?? this.typingStatus,
      typingUserId: clearTyping ? null : typingUserId ?? this.typingUserId,
      replyingTo: clearReply ? null : replyingTo ?? this.replyingTo,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}
