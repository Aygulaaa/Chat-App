import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/utils/date_formatter.dart';
import 'package:my_chat_app/features/auth/data/models/user_model.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/chat/date_divider.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/message_bubble.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/typing_indicator.dart';
import 'package:collection/collection.dart';

class MessageList extends StatelessWidget {
  final List<Message> messages;
  final int? userId;
  final bool isTyping;
  final int? typingUserId;
  final bool isGroup;
  final List<UserModel> participants;
  final void Function(Message message)? onDelete;
  final void Function(String emoji)? onStickerSend;

  const MessageList({
    super.key,
    required this.messages,
    required this.userId,
    required this.isTyping,
    this.typingUserId,
    this.isGroup = false,
    this.participants = const [],
    this.onDelete,
    this.onStickerSend,
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
      padding: const EdgeInsets.symmetric(vertical: 8),
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

        final isLastOfList = msgIndex == messages.length - 1;
        final nextMsg = isLastOfList ? null : messages[msgIndex + 1];
        final prevMsg = msgIndex == 0 ? null : messages[msgIndex - 1];

        final showDateHeader =
            isLastOfList || msg.createdAt.day != nextMsg!.createdAt.day;

        // Telegram tucks consecutive messages from the same sender close
        // together and only opens up extra space where the sender changes
        // (or a day boundary/typing indicator breaks the run).
        final isSameSenderAsNext = !isLastOfList &&
            !showDateHeader &&
            nextMsg.senderId == msg.senderId;
        final isSameSenderAsPrev = prevMsg != null &&
            prevMsg.senderId == msg.senderId &&
            prevMsg.createdAt.day == msg.createdAt.day;

        final showAvatarOnThisRow = !isSameSenderAsNext;

        return Column(
          key: ValueKey(msg.id),
          children: [
            if (showDateHeader)
              DateDivider(text: DateFormatter.formatHeaderDate(msg.createdAt)),
            Padding(
              padding: EdgeInsets.only(top: isSameSenderAsPrev ? 0 : 6),
              child: MessageBubble(
                message: msg,
                isMe: msg.senderId == userId,
                time: DateFormatter.formatTime(msg.createdAt),
                isGroup: isGroup,
                showAvatar: showAvatarOnThisRow,
                senderAvatar: sender?.avatar,
                onAvatarTap: sender != null
                    ? () => context.push(
                          '/user-profile',
                          extra: sender,
                        )
                    : null,
                onDelete: msg.senderId == userId
                    ? () => onDelete?.call(msg)
                    : null,
                onStickerSend: onStickerSend,
              ),
            ),
          ],
        );
      },
    );
  }
}