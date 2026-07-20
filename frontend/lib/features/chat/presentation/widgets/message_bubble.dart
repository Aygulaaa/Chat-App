import 'package:flutter/material.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message_content.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message_status_tick.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/reaction_row.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final String? time;
  final List<String> reactions;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.time,
    this.reactions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            _BubbleBody(
              message: message,
              isMe: isMe,
              time: time,
            ),
            if (reactions.isNotEmpty) ...[
              const SizedBox(height: 4),
              ReactionRow(reactions: reactions),
            ],
          ],
        ),
      ),
    );
  }
}

class _BubbleBody extends StatelessWidget {
  final Message message;
  final bool isMe;
  final String? time;

  const _BubbleBody({
    required this.message,
    required this.isMe,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        gradient: isMe
            ? const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isMe ? null : const Color(0xFF1E2A3A),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMe ? 18 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 18),
        ),
        border: isMe
            ? null
            : Border.all(color: Colors.white.withOpacity(0.07)),
        boxShadow: [
          BoxShadow(
            color: isMe
                ? const Color(0xFF6366F1).withOpacity(0.30)
                : Colors.black.withOpacity(0.15),
            blurRadius: isMe ? 16 : 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          MessageContent(message: message, isMe:isMe),
          if (time != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time!,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 3),
                  MessageStatusTick(status: message.status),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}