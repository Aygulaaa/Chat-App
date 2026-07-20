import 'package:flutter/material.dart';
import 'package:my_chat_app/core/utils/date_formatter.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/date_divider.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message_bubble.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/typing_indicator.dart';

class MessageList extends StatelessWidget {
  final List<Message> messages;
  final int? userId;
  final bool isTyping;

  const MessageList({
    super.key,
    required this.messages,
    required this.userId,
    required this.isTyping,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty && !isTyping) {
      return const Center(
        child: Text('No messages yet', style: TextStyle(color: Colors.white38)),
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
          return const TypingIndicator();
        }

        final msgIndex = isTyping ? index - 1 : index;
        final msg = messages[msgIndex];

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
            ),
          ],
        );
      },
    );
  }
}
