import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';

/// One recipient's status for one message (group "Message Info").
class MessageReceipt {
  final int userId;
  final String username;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  const MessageReceipt({
    required this.userId,
    required this.username,
    this.deliveredAt,
    this.readAt,
  });

  factory MessageReceipt.fromJson(Map<String, dynamic> json) => MessageReceipt(
    userId: int.tryParse(json['userId'].toString()) ?? 0,
    username: json['username']?.toString() ?? 'Unknown',
    deliveredAt: DateTime.tryParse(
      json['deliveredAt']?.toString() ?? '',
    )?.toLocal(),
    readAt: DateTime.tryParse(json['readAt']?.toString() ?? '')?.toLocal(),
  );
}

typedef ReceiptsLoader = Future<List<MessageReceipt>> Function();

class MessageInfoPanel extends StatefulWidget {
  final bool isMe;
  final Message message;
  final String Function(DateTime?) formatTime;

  /// Set for my own messages in a group: fetches who received / read it.
  final ReceiptsLoader? loadReceipts;

  const MessageInfoPanel({
    super.key,
    required this.isMe,
    required this.message,
    required this.formatTime,
    this.loadReceipts,
  });

  @override
  State<MessageInfoPanel> createState() => _MessageInfoPanelState();
}

class _MessageInfoPanelState extends State<MessageInfoPanel> {
  Future<List<MessageReceipt>>? _receipts;

  @override
  void initState() {
    super.initState();
    _receipts = widget.loadReceipts?.call();
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final status = message.status;
    final perPerson = _receipts != null;

    return Container(
      constraints: BoxConstraints(maxWidth: 250.w),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        // Opaque: this floats over a blurred chat and must stay readable
        color: context.modalBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: context.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16.r,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _InfoRow(
            icon: Icons.check_rounded,
            iconColor: context.textTertiary,
            label: 'Sent',
            time: widget.formatTime(message.createdAt),
          ),
          if (!perPerson &&
              (status == MessageStatus.delivered ||
                  status == MessageStatus.read)) ...[
            SizedBox(height: 6.h),
            _InfoRow(
              icon: Icons.done_all_rounded,
              iconColor: context.textTertiary,
              label: 'Delivered',
              time: widget.formatTime(message.deliveredAt),
            ),
          ],
          if (!perPerson && status == MessageStatus.read) ...[
            SizedBox(height: 6.h),
            _InfoRow(
              icon: Icons.done_all_rounded,
              iconColor: const Color(0xFF60A5FA),
              label: 'Read',
              time: widget.formatTime(message.readAt),
            ),
          ],
          if (perPerson) ...[
            SizedBox(height: 8.h),
            Divider(height: 1, color: context.border),
            SizedBox(height: 8.h),
            FutureBuilder<List<MessageReceipt>>(
              future: _receipts,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.h),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.6,
                        color: context.textTertiary,
                      ),
                    ),
                  );
                }
                final rows = snapshot.data;
                if (snapshot.hasError || rows == null) {
                  return Text(
                    "Couldn't load who has seen this",
                    style: TextStyle(
                      color: context.textTertiary,
                      fontSize: 12.sp,
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final r in rows.take(12))
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 3.h),
                        child: _PersonRow(
                          receipt: r,
                          formatTime: widget.formatTime,
                        ),
                      ),
                    if (rows.length > 12)
                      Text(
                        '+${rows.length - 12} more',
                        style: TextStyle(
                          color: context.textTertiary,
                          fontSize: 11.5.sp,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  final MessageReceipt receipt;
  final String Function(DateTime?) formatTime;

  const _PersonRow({required this.receipt, required this.formatTime});

  @override
  Widget build(BuildContext context) {
    final read = receipt.readAt != null;
    final delivered = receipt.deliveredAt != null;
    final label = read
        ? 'Read ${formatTime(receipt.readAt)}'
        : delivered
        ? 'Delivered ${formatTime(receipt.deliveredAt)}'
        : 'Not delivered yet';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          delivered ? Icons.done_all_rounded : Icons.check_rounded,
          size: 14.sp,
          color: read ? const Color(0xFF60A5FA) : context.textTertiary,
        ),
        SizedBox(width: 8.w),
        Flexible(
          child: Text(
            receipt.username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(width: 10.w),
        Text(
          label,
          style: TextStyle(color: context.textTertiary, fontSize: 11.5.sp),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String time;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14.sp, color: iconColor),
        SizedBox(width: 8.w),
        Text(
          label,
          style: TextStyle(color: context.textSecondary, fontSize: 12.sp),
        ),
        SizedBox(width: 12.w),
        if (time.isNotEmpty)
          Text(
            time,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}
