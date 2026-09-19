import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';

class DateDivider extends StatelessWidget {
  final String text;

  const DateDivider({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Row(
        children: [
          const Expanded(
            child: Divider(color: AppColors.darkCard, thickness: 1),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.darkTextTertiary,
                fontSize: 11.sp,
              ),
            ),
          ),
          const Expanded(
            child: Divider(color: AppColors.darkCard, thickness: 1),
          ),
        ],
      ),
    );
  }
}
