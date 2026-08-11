import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/utils/format_last_seen.dart';
import 'package:my_chat_app/features/chat/presentation/providers/message_notifier.dart';
import 'package:my_chat_app/features/chat/presentation/providers/user_status_notifier.dart';

class TypingStatusText extends ConsumerWidget {
  final int chatId;
  final bool isOnline;
  final int otherUserId;

  const TypingStatusText({
    super.key,
    required this.chatId,
    required this.isOnline,
    required this.otherUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typingStatus = ref.watch(
      messageProvider(chatId).select((s) => s.typingStatus),
    );

    // ✅ Single watch — no duplicate
    final lastSeen = ref.watch(userStatusProvider).lastSeen[otherUserId];

    if (typingStatus != null) {
      return const Text(
        'typing...',
        style: TextStyle(fontSize: 12, color: AppColors.accent),
      );
    }

    if (isOnline) {
      return const Text(
        'online',
        style: TextStyle(
          fontSize: 12,
          color: AppColors.online,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    // ✅ Offline — show lastSeen if available, nothing if null (hidden)
    if (lastSeen != null) {
      return Text(
        TimeUtils.formatLastSeen(lastSeen),
        style: const TextStyle(fontSize: 12, color: AppColors.darkTextTertiary),
      );
    }

    // ✅ null = hideLastSeen is on — show nothing
    return const SizedBox.shrink();
  }
}