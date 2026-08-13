
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:my_chat_app/core/common/entities/user_entity.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/features/profile/presentation/pages/profile_screen.dart';

/// Member List View Section
class MemberListSection extends StatelessWidget {
  final List<UserEntity> participants;
  final int? currentUserId;
  final VoidCallback onAddPressed;
  final Function(int) onRemoveMember;

  const MemberListSection({
    super.key,
    required this.participants,
    required this.currentUserId,
    required this.onAddPressed,
    required this.onRemoveMember,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Members',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: participants.length,
          separatorBuilder: (context, index) => Divider(
            color: context.glassBorder.withValues(alpha: 0.4),
            height: 1,
            indent: 64.w,
            endIndent: 16.w,
          ),
          itemBuilder: (context, index) {
            final member = participants[index];
            final isCurrentUser = member.id == currentUserId;

            return ListTile(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 8.w,
                vertical: 2.h,
              ),
              leading: CircleAvatar(
                radius: 22.r,
                backgroundImage: member.avatar != null
                    ? NetworkImage(member.avatar!)
                    : null,
                backgroundColor: AppColors.primary,
                child: member.avatar == null
                    ? Text(
                        member.username[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              title: Text(
                isCurrentUser ? 'You' : member.username,
                style: TextStyle(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15.sp,
                ),
              ),
              onTap: () {
                if (!isCurrentUser) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(user: member),
                    ),
                  );
                }
              },
              trailing: isCurrentUser
                  ? null
                  : IconButton(
                      icon: Icon(
                        Icons.remove_circle_outline_rounded,
                        color: AppColors.error,
                        size: 22.sp,
                      ),
                      onPressed: () => onRemoveMember(member.id),
                    ),
            );
          },
        ),
      ],
    );
  }
}