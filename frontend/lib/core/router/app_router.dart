import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:my_chat_app/core/auth/auth_gate.dart';
import 'package:my_chat_app/core/auth/local_auth_provider.dart';
import 'package:my_chat_app/core/common/entities/user_entity.dart';
import 'package:my_chat_app/features/auth/data/models/user_model.dart';
import 'package:my_chat_app/features/auth/presentation/pages/auth_page.dart';
import 'package:my_chat_app/features/auth/presentation/pages/lock_screen.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/chat/presentation/pages/chat_screen.dart';
import 'package:my_chat_app/features/chat/presentation/pages/group_profile_screen.dart';
import 'package:my_chat_app/features/chat/presentation/pages/home_page.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/fullscreen_image_viewer.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/fullscreen_video_player.dart';
import 'package:my_chat_app/features/contacts/presentation/pages/contacts_screen.dart';
import 'package:my_chat_app/features/profile/presentation/pages/edit_profile_screen.dart';
import 'package:my_chat_app/features/profile/presentation/pages/profile_screen.dart';
import 'package:my_chat_app/features/settings/presentation/pages/app_lock_screen.dart';
import 'package:my_chat_app/features/settings/presentation/pages/appearance_settings_screen.dart';
import 'package:my_chat_app/features/settings/presentation/pages/change_password_screen.dart';
import 'package:my_chat_app/features/settings/presentation/pages/notifications_settings_screen.dart';
import 'package:my_chat_app/features/settings/presentation/pages/privacy_settings_screen.dart';
import 'package:my_chat_app/features/settings/presentation/pages/settings_screen.dart';
import 'package:my_chat_app/features/settings/presentation/widgets/blocked_contacts.dart';
import 'package:my_chat_app/features/settings/presentation/pages/sessions_screen.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen(authProvider, (_, __) {
      notifyListeners();
    });
    _ref.listen(localAuthProvider, (_, __) {
      notifyListeners();
    });
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

// ── Root Key & Router Provider ──────────────────────────────────────────────

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/auth',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final localAuthState = ref.read(localAuthProvider);

      if (authState.isLoading) return null;

      final isLockRoute = state.matchedLocation == '/lock-screen';

      // Handle app lock first
      if (localAuthState.isLocked) {
        return isLockRoute ? null : '/lock-screen';
      }
      // If unlocked but trying to access lock screen, redirect to auth to let normal flow take over
      if (!localAuthState.isLocked && isLockRoute) {
        return '/auth';
      }

      final hasToken = authState.token != null && authState.token!.isNotEmpty;
      final isAuthRoute = state.matchedLocation == '/auth';

      if (!hasToken && !isAuthRoute) return '/auth';
      if (hasToken && isAuthRoute) return '/home';

      return null;
    },
    routes: [
      GoRoute(
        path: '/auth',
        builder: (context, state) {
          final authState = ref.watch(authProvider);
          if (authState.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return const AuthPage();
        },
      ),

      GoRoute(
        path: '/lock-screen',
        builder: (context, state) => const LockScreen(),
      ),

      // ── Stateful Navigation Shell (Bottom Nav Tabs) ───────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AuthGate(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/contact',
                builder: (context, state) => const ContactsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── Full-Screen Routes (Hides Bottom Nav) ─────────────────────────────
      GoRoute(
        path: '/chat/conversation/:chatId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final chatId = int.parse(state.pathParameters['chatId']!);
          final username = state.extra as String? ?? '';
          return ChatScreen(chatId: chatId, username: username);
        },
      ),

      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),
      // Deliberately flat, not nested under /settings: these are opened with
      // context.push(), and pushing a NESTED route also builds a second copy
      // of its parent underneath — so Back would land on a duplicate page.
      GoRoute(
        path: '/settings/notifications',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationsSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/privacy',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PrivacySettingsScreen(),
      ),
      GoRoute(
        path: '/settings/appearance',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AppearanceSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/change-password',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/settings/app-lock',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AppLockScreen(),
      ),
      GoRoute(
        path: '/blocked-contacts',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const BlockedContactsPage(),
      ),
      GoRoute(
        path: '/sessions',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SessionsScreen(),
      ),
      GoRoute(
        path: '/edit-profile',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final user = state.extra as UserEntity;
          return EditProfileScreen(user: user);
        },
      ),
      GoRoute(
        path: '/group-profile/:chatId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final chatId = int.parse(state.pathParameters['chatId']!);
          return GroupProfileScreen(chatId: chatId);
        },
      ),
      GoRoute(
        path: '/user-profile',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra;
          debugPrint(
            '[/user-profile] extra runtimeType: ${extra.runtimeType}, value: $extra',
          );

          UserEntity? user;

          if (extra == null) {
            debugPrint(
              '[/user-profile] extra is NULL — route was likely opened via '
              'deep link, refresh, or restart, where extra does not survive.',
            );
          } else if (extra is UserEntity) {
            user = extra;
          } else if (extra is Map<String, dynamic>) {
            try {
              user = UserModel.fromJson(extra);
            } catch (e, st) {
              debugPrint('[/user-profile] UserModel.fromJson failed: $e\n$st');
            }
          } else {
            debugPrint(
              '[/user-profile] Unexpected extra type: ${extra.runtimeType}',
            );
          }

          if (user == null) {
            // don't silently render a broken screen — make the failure visible
            return const Scaffold(
              body: Center(
                child: Text('No profile data — this route needs a userId.'),
              ),
            );
          }

          return ProfileScreen(user: user);
        },
      ),
      GoRoute(
        path: '/image-viewer',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final url = extra['url'] as String? ?? '';
          final title = extra['title'] as String?;

          // Saving is opt-in per call site: chat photos yes, someone else's
          // profile photo no.
          final canDownload = extra['canDownload'] == true;

          return FullscreenImageViewer(
            url: url,
            title: title,
            canDownload: canDownload,
          );
        },
      ),
      GoRoute(
        path: '/video-player',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final url = extra['url'] as String? ?? '';
          final title = extra['title'] as String?;

          return FullscreenVideoPlayer(url: url, title: title);
        },
      ),
    ],
  );
});
