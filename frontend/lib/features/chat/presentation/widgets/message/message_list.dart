import 'package:flutter/material.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/utils/date_formatter.dart';
import 'package:my_chat_app/features/auth/data/models/user_model.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/chat/date_divider.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/message_bubble.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/typing_indicator.dart';
import 'package:my_chat_app/features/profile/presentation/pages/profile_screen.dart';
import 'package:collection/collection.dart';

class MessageList extends StatelessWidget {
  final List<Message> messages;
  final int? userId;
  final bool isTyping;
  final int? typingUserId;
  final bool isGroup;
  final List<UserModel> participants;

  const MessageList({
    super.key,
    required this.messages,
    required this.userId,
    required this.isTyping,
    this.typingUserId,
    this.isGroup = false,
    this.participants = const [],
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty && !isTyping) {
      return const Center(
        child: Text(
          'No messages yet',
          style: TextStyle(color: AppColors.darkTextTertiary),
        ),
      );
    }

    final itemCount = messages.length + (isTyping ? 1 : 0);

    return ListView.builder(
      reverse: true,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (isTyping && index == 0) {
          final typist = participants.firstWhereOrNull((p) => p.id == typingUserId);
          return TypingIndicator(
            avatarUrl: isGroup ? typist?.avatar : null,
          );
        }

        final msgIndex = isTyping ? index - 1 : index;
        final msg = messages[msgIndex];
        
        final sender = participants.firstWhereOrNull((p) => p.id == msg.senderId);

        final showDateHeader =
            msgIndex == messages.length - 1 ||
            msg.createdAt.day != messages[msgIndex + 1].createdAt.day;

        return Column(
          children: [
            if (showDateHeader)
              DateDivider(text: DateFormatter.formatHeaderDate(msg.createdAt)),
            MessageBubble(
              message: msg,
              isMe: msg.senderId == userId,
              time: DateFormatter.formatTime(msg.createdAt),
              isGroup: isGroup,
              senderAvatar: sender?.avatar,
              onAvatarTap: sender != null
                  ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(user: sender),
                        ),
                      )
                  : null,
            ),
          ],
        );
      },
    );
  }
}