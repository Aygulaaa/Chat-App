import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/core/utils/date_formatter.dart';
import 'package:my_chat_app/features/auth/data/models/user_model.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/chat/date_divider.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/message_bubble.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/message_info.panel.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/typing_indicator.dart';

class MessageList extends StatefulWidget {
  final List<Message> messages;
  final int? userId;
  final bool isTyping;
  final int? typingUserId;
  final bool isGroup;
  final List<UserModel> participants;
  final void Function(Message message)? onDelete;
  /// Put / swap / remove my emoji reaction on a message.
  final void Function(Message message, String emoji)? onReact;
  final void Function(Message message)? onReply;
  final void Function(Message message)? onRetry;
  final void Function(Message message)? onCancelSend;

  /// Per-recipient status for one of my messages (group Message Info).
  final Future<List<MessageReceipt>> Function(Message message)? onLoadReceipts;

  /// Asked for when the user scrolls close to the oldest loaded message.
  final VoidCallback? onLoadMore;
  final bool isLoadingMore;

  /// Quotes written by these users are hidden (blocked contacts).
  final Set<int> hiddenQuoteAuthorIds;

  const MessageList({
    super.key,
    required this.messages,
    required this.userId,
    required this.isTyping,
    this.typingUserId,
    this.isGroup = false,
    this.participants = const [],
    this.onDelete,
    this.onReact,
    this.onReply,
    this.onRetry,
    this.onCancelSend,
    this.onLoadReceipts,
    this.onLoadMore,
    this.isLoadingMore = false,
    this.hiddenQuoteAuthorIds = const {},
  });

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  final ScrollController _scroll = ScrollController();

  /// One key per built row so a quote tap can find and reveal its original.
  final Map<int, GlobalKey> _rowKeys = {};

  /// Rows that were already on screen (or arrived in bulk) never animate in;
  /// only messages that arrive one at a time while the chat is open do.
  late Set<int> _knownKeys;
  final Set<int> _animateIn = {};

  int? _highlightedId;
  Timer? _highlightTimer;
  bool _showJumpToBottom = false;

  @override
  void initState() {
    super.initState();
    _knownKeys = widget.messages.map((m) => m.viewKey).toSet();
    _scroll.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);

    final current = widget.messages.map((m) => m.viewKey).toSet();
    final fresh = current.difference(_knownKeys);

    // A page of history (or the first load) is many rows at once → no
    // animation. One or two new rows at the bottom is a live message.
    if (fresh.isNotEmpty && fresh.length <= 2 && _knownKeys.isNotEmpty) {
      final newestKeys = widget.messages
          .take(fresh.length)
          .map((m) => m.viewKey);
      if (newestKeys.every(fresh.contains)) _animateIn.addAll(fresh);
    }
    _knownKeys = current;
    _rowKeys.removeWhere((key, _) => !current.contains(key));
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;

    // reverse: true → offset 0 is the newest message, maxScrollExtent the oldest
    if (position.pixels >= position.maxScrollExtent - 400) {
      widget.onLoadMore?.call();
    }

    final show = position.pixels > 500;
    if (show != _showJumpToBottom) setState(() => _showJumpToBottom = show);
  }

  void _jumpToBottom() {
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  /// Scrolls the quoted original into view and flashes it.
  ///
  /// Rows of a lazy list only exist while they're near the viewport, so when
  /// the target isn't built yet we page upward (the original is always OLDER
  /// than its reply) until it is.
  Future<void> _revealMessage(int messageId) async {
    final target = widget.messages.firstWhereOrNull((m) => m.id == messageId);
    if (target == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('That message is further back in the chat'),
            duration: Duration(seconds: 2),
          ),
        );
      widget.onLoadMore?.call();
      return;
    }

    for (var attempt = 0; attempt < 60; attempt++) {
      if (!mounted) return;
      final rowContext = _rowKeys[target.viewKey]?.currentContext;
      if (rowContext != null && rowContext.mounted) {
        await Scrollable.ensureVisible(
          rowContext,
          alignment: 0.5,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
        if (!mounted) return;
        _flash(messageId);
        return;
      }

      final position = _scroll.position;
      final next = (position.pixels + position.viewportDimension * 0.85).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (next == position.pixels) return; // reached the top, nothing to find
      _scroll.jumpTo(next);
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  void _flash(int messageId) {
    HapticFeedback.selectionClick();
    _highlightTimer?.cancel();
    setState(() => _highlightedId = messageId);
    _highlightTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _highlightedId = null);
    });
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final messages = widget.messages;

    if (messages.isEmpty && !widget.isTyping) {
      return const _EmptyConversation();
    }

    final typingRows = widget.isTyping ? 1 : 0;
    final loaderRows = widget.isLoadingMore ? 1 : 0;
    final itemCount = messages.length + typingRows + loaderRows;

    return Stack(
      children: [
        ListView.builder(
          controller: _scroll,
          reverse: true,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: itemCount,
          // Without this, inserting a message at index 0 makes Flutter match
          // old row states to the wrong messages.
          findChildIndexCallback: (key) {
            if (key is! ValueKey<int>) return null;
            final index = messages.indexWhere((m) => m.viewKey == key.value);
            return index == -1 ? null : index + typingRows;
          },
          itemBuilder: (context, index) {
            if (widget.isTyping && index == 0) {
              final typist = widget.participants.firstWhereOrNull(
                (p) => p.id == widget.typingUserId,
              );
              return TypingIndicator(
                avatarUrl: widget.isGroup ? typist?.avatar : null,
              );
            }

            final msgIndex = index - typingRows;
            if (msgIndex >= messages.length) {
              return const _HistoryLoader();
            }

            return _buildRow(context, msgIndex);
          },
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: _JumpToBottomButton(
            visible: _showJumpToBottom,
            onTap: _jumpToBottom,
          ),
        ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, int msgIndex) {
    final messages = widget.messages;
    final userId = widget.userId;
    final msg = messages[msgIndex];

    final sender = widget.participants.firstWhereOrNull(
      (p) => p.id == msg.senderId,
    );

    final isLastOfList = msgIndex == messages.length - 1;
    final nextMsg = isLastOfList ? null : messages[msgIndex + 1];
    final prevMsg = msgIndex == 0 ? null : messages[msgIndex - 1];

    // Compare the full date. Comparing only `.day` treated e.g. 5 Jan and
    // 5 Feb as the same day and swallowed the divider between them.
    final showDateHeader =
        nextMsg == null || !_sameDay(msg.createdAt, nextMsg.createdAt);

    // Telegram tucks consecutive messages from the same sender close
    // together and only opens up extra space where the sender changes
    // (or a day boundary/typing indicator breaks the run).
    final isSameSenderAsNext =
        nextMsg != null && !showDateHeader && nextMsg.senderId == msg.senderId;
    final isSameSenderAsPrev =
        prevMsg != null &&
        prevMsg.senderId == msg.senderId &&
        _sameDay(prevMsg.createdAt, msg.createdAt);

    final quoteHidden =
        msg.replyTo != null &&
        widget.hiddenQuoteAuthorIds.contains(msg.replyTo!.senderId);
    final shown = quoteHidden ? msg.copyWith(clearReplyTo: true) : msg;

    final rowKey = _rowKeys.putIfAbsent(msg.viewKey, () => GlobalKey());

    return _AppearOnce(
      key: ValueKey<int>(msg.viewKey),
      // Consumed on first build; _AppearOnce only reads it in initState
      animate: _animateIn.remove(msg.viewKey),
      fromRight: msg.senderId == userId,
      child: Column(
        key: rowKey,
        children: [
          if (showDateHeader)
            DateDivider(text: DateFormatter.formatHeaderDate(msg.createdAt)),
          Padding(
            padding: EdgeInsets.only(top: isSameSenderAsPrev ? 0 : 6),
            child: MessageBubble(
              message: shown,
              isMe: msg.senderId == userId,
              currentUserId: userId,
              time: DateFormatter.formatTime(msg.createdAt),
              isGroup: widget.isGroup,
              showAvatar: !isSameSenderAsNext,
              senderAvatar: sender?.avatar,
              highlighted: _highlightedId == msg.id,
              onAvatarTap: sender != null
                  ? () => context.push('/user-profile', extra: sender)
                  : null,
              onDelete: msg.senderId == userId
                  ? () => widget.onDelete?.call(msg)
                  : null,
              onReact: widget.onReact == null
                  ? null
                  : (emoji) => widget.onReact!(msg, emoji),
              onReply: widget.onReply == null
                  ? null
                  : () => widget.onReply!(msg),
              onRetry: widget.onRetry == null
                  ? null
                  : () => widget.onRetry!(msg),
              onCancelSend: widget.onCancelSend == null || !msg.isPending
                  ? null
                  : () => widget.onCancelSend!(msg),
              onQuoteTap: _revealMessage,
              loadReceipts: widget.onLoadReceipts == null
                  ? null
                  : () => widget.onLoadReceipts!(msg),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fades + slides a row in the first time it is built, if asked to. Always
/// present in the tree (animating or not) so a finished animation never
/// changes the widget structure and resets the bubble's state.
class _AppearOnce extends StatefulWidget {
  final bool animate;
  final bool fromRight;
  final Widget child;

  const _AppearOnce({
    super.key,
    required this.animate,
    required this.fromRight,
    required this.child,
  });

  @override
  State<_AppearOnce> createState() => _AppearOnceState();
}

class _AppearOnceState extends State<_AppearOnce>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 260),
      )..forward();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return widget.child;

    final curve = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(widget.fromRight ? 0.06 : -0.06, 0.25),
          end: Offset.zero,
        ).animate(curve),
        child: widget.child,
      ),
    );
  }
}

class _HistoryLoader extends StatelessWidget {
  const _HistoryLoader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: context.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _JumpToBottomButton extends StatelessWidget {
  final bool visible;
  final VoidCallback onTap;

  const _JumpToBottomButton({required this.visible, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedScale(
        scale: visible ? 1 : 0.6,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: Material(
            color: context.modalSurface,
            shape: CircleBorder(side: BorderSide(color: context.glassBorder)),
            elevation: 3,
            shadowColor: Colors.black.withValues(alpha: 0.4),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 24,
                  color: context.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.cardBg,
              border: Border.all(color: context.glassBorder),
            ),
            child: Icon(
              Icons.waving_hand_rounded,
              size: 28,
              color: context.accentColor,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No messages yet',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Say hello to start the conversation',
            style: TextStyle(color: context.textTertiary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
