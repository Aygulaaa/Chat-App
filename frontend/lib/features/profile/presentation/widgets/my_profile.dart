import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:my_chat_app/core/common/entities/user_entity.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/features/profile/presentation/widgets/action.dart'; 
import 'package:my_chat_app/features/profile/presentation/widgets/info_card.dart';
import 'package:my_chat_app/features/profile/presentation/widgets/profile_delegate.dart';

class MyProfile extends StatelessWidget {
  final UserEntity user;
  const MyProfile({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final maxHeaderHeight = 320.h;
    final minHeaderHeight = kToolbarHeight + topPadding;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: context.appBgGradient),
        child: CustomScrollView(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: ProfileHeaderDelegate(
                user: user,
                isMe: true,
                maxExtentHeight: maxHeaderHeight,
                minExtentHeight: minHeaderHeight,
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  SizedBox(height: 20.h),
                  InfoCard(user: user),
                  SizedBox(height: 16.h),
                  ActionCard(user: user),
                  SizedBox(height: 100.h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}