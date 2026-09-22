import 'package:my_chat_app/core/utils/error_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/core/utils/date_formatter.dart';
import 'package:my_chat_app/core/utils/dialog_utils.dart';
import 'package:my_chat_app/core/utils/snackbar_utils.dart';
import 'package:my_chat_app/features/auth/domain/entity/user_session.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/settings/presentation/providers/sessions_provider.dart';
import 'package:my_chat_app/features/settings/presentation/widgets/settings_scaffold.dart';

class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});

  Future<void> _handleRevokeSession(
    BuildContext context,
    WidgetRef ref,
    int sessionId,
    bool isCurrent,
  ) async {
    final confirmed = await DialogUtils.showConfirmDialog(
      context: context,
      title: isCurrent ? 'Sign Out Current Device' : 'Revoke Session',
      message: isCurrent
          ? 'Are you sure you want to sign out from THIS device?'
          : 'Are you sure you want to sign out this device?',
      confirmLabel: 'Sign Out',
      confirmColor: Colors.redAccent,
    );
    if (!confirmed) return;

    if (isCurrent) {
      await ref.read(authProvider.notifier).logout();
      return;
    }

    try {
      await ref.read(sessionsProvider.notifier).revokeSession(sessionId);
      if (context.mounted) {
        SnackBarUtils.showSnack(context, 'Session revoked successfully.');
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showSnack(context, 'Failed to revoke session.', isError: true);
      }
    }
  }

  Future<void> _handleTerminateOthers(BuildContext context, WidgetRef ref) async {
    final confirmed = await DialogUtils.showConfirmDialog(
      context: context,
      title: 'Sign Out All Other Devices',
      message: 'This will sign you out from all other devices. Continue?',
      confirmLabel: 'Sign Out Others',
      confirmColor: Colors.deepOrangeAccent,
    );
    if (!confirmed) return;

    try {
      await ref.read(sessionsProvider.notifier).terminateOtherSessions();
      if (context.mounted) {
        SnackBarUtils.showSnack(context, 'All other sessions terminated.');
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showSnack(context, 'Failed to terminate sessions.', isError: true);
      }
    }
  }

  IconData _getDeviceIcon(String deviceName) {
    final lower = deviceName.toLowerCase();
    if (lower.contains('iphone') || lower.contains('ipad') || lower.contains('ios')) {
      return Icons.phone_iphone_rounded;
    }
    if (lower.contains('android') || lower.contains('mobile') || lower.contains('pixel')) {
      return Icons.phone_android_rounded;
    }
    if (lower.contains('mac') || (lower.contains('safari') && lower.contains('desktop'))) {
      return Icons.laptop_mac_rounded;
    }
    if (lower.contains('windows') || lower.contains('chrome') || lower.contains('firefox')) {
      return Icons.computer_rounded;
    }
    return Icons.devices_rounded;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsProvider);

    return SettingsScaffold(
      title: 'Devices',
      actions: [
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: AppColors.primary),
          tooltip: 'Refresh',
          onPressed: () => ref.read(sessionsProvider.notifier).refresh(),
        ),
      ],
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildError(
          context,
          ref,
          ErrorHandler.getReadableErrorMessage(e),
        ),
        data: (sessions) {
          final currentSessions = sessions.where((s) => s.isCurrentDevice).toList();
          final otherSessions = sessions.where((s) => !s.isCurrentDevice).toList();

          return RefreshIndicator(
            onRefresh: () => ref.read(sessionsProvider.notifier).refresh(),
            color: AppColors.primary,
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              children: [
                const _InfoBanner(),
                SizedBox(height: 20.h),
                if (currentSessions.isNotEmpty) ...[
                  const _SectionLabel(label: 'THIS DEVICE'),
                  SizedBox(height: 8.h),
                  ...currentSessions.map(
                    (s) => _SessionCard(
                      session: s,
                      isCurrent: true,
                      timeAgo: DateFormatter.formatTime(s.lastActiveAt),
                      deviceIcon: _getDeviceIcon(s.deviceName),
                      onRevoke: () => _handleRevokeSession(context, ref, s.id, true),
                    ),
                  ),
                  SizedBox(height: 20.h),
                ],
                if (otherSessions.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const _SectionLabel(label: 'OTHER DEVICES'),
                      TextButton.icon(
                        onPressed: () => _handleTerminateOthers(context, ref),
                        icon: const Icon(Icons.logout_rounded, size: 14, color: Colors.redAccent),
                        label: Text(
                          'Sign out all',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  ...otherSessions.map(
                    (s) => _SessionCard(
                      session: s,
                      isCurrent: false,
                      timeAgo: DateFormatter.formatTime(s.lastActiveAt),
                      deviceIcon: _getDeviceIcon(s.deviceName),
                      onRevoke: () => _handleRevokeSession(context, ref, s.id, false),
                    ),
                  ),
                  SizedBox(height: 20.h),
                ],
                if (sessions.isEmpty)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 60.h),
                      child: Column(
                        children: [
                          Icon(Icons.devices_other_rounded, size: 56, color: context.textTertiary),
                          SizedBox(height: 12.h),
                          Text(
                            'No active sessions found',
                            style: TextStyle(color: context.textTertiary, fontSize: 14.sp),
                          ),
                        ],
                      ),
                    ),
                  ),
                SizedBox(height: 40.h),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, String errorStr) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
            SizedBox(height: 12.h),
            Text(
              errorStr,
              style: TextStyle(color: Colors.redAccent, fontSize: 13.sp),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20.h),
            ElevatedButton.icon(
              onPressed: () => ref.read(sessionsProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'These are all the devices currently logged into your account. '
              'If you see a device you don\'t recognise, revoke it immediately.',
              style: TextStyle(color: AppColors.primary, fontSize: 12.sp, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: context.textTertiary,
        fontSize: 11.sp,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final UserSessionEntity session;
  final bool isCurrent;
  final String timeAgo;
  final IconData deviceIcon;
  final VoidCallback? onRevoke;

  const _SessionCard({
    required this.session,
    required this.isCurrent,
    required this.timeAgo,
    required this.deviceIcon,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: context.glassCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent ? AppColors.primary.withValues(alpha: 0.35) : context.glassBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: (isCurrent ? AppColors.primary : context.textTertiary).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              deviceIcon,
              color: isCurrent ? AppColors.primary : context.textTertiary,
              size: 22,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        session.deviceName,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.sp,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrent) ...[
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'This device',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 11, color: context.textTertiary),
                    SizedBox(width: 4.w),
                    Text(
                      'Active $timeAgo',
                      style: TextStyle(color: context.textTertiary, fontSize: 11.sp),
                    ),
                  ],
                ),
                if (session.ipAddress != null) ...[
                  SizedBox(height: 2.h),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 11, color: context.textTertiary),
                      SizedBox(width: 4.w),
                      Flexible(
                        child: Text(
                          session.ipAddress!,
                          style: TextStyle(color: context.textTertiary, fontSize: 11.sp),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (onRevoke != null) ...[
            SizedBox(width: 8.w),
            GestureDetector(
              onTap: onRevoke,
              child: Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
              ),
            ),
          ],
        ],
      ),
    );
  }
}