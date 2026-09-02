import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:my_chat_app/core/auth/auth_gate.dart';
import 'package:my_chat_app/core/common/entities/user_entity.dart';
import 'package:my_chat_app/features/auth/data/models/user_model.dart';
import 'package:my_chat_app/features/auth/presentation/pages/auth_page.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/chat/presentation/pages/chat_screen.dart';
import 'package:my_chat_app/features/chat/presentation/pages/group_profile_screen.dart';
import 'package:my_chat_app/features/chat/presentation/pages/home_page.dart';
import 'package:my_chat_app/features/contacts/presentation/pages/contacts_screen.dart';
import 'package:my_chat_app/features/profile/presentation/pages/edit_profile_screen.dart';
import 'package:my_chat_app/features/profile/presentation/pages/profile_screen.dart';
import 'package:my_chat_app/features/settings/presentation/pages/settings_screen.dart';
import 'package:my_chat_app/features/settings/presentation/widgets/blocked_contacts.dart';

// ── Router Notifier ─────────────────────────────────────────────────────────

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen(authProvider, (_, __) {
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

      if (authState.isLoading) return null;

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
      GoRoute(
        path: '/blocked-contacts',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const BlockedContactsPage(),
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
          UserEntity? user;

          if (extra is UserEntity) {
            user = extra;
          } else if (extra is UserModel) {
            user = extra;
          }

          return ProfileScreen(user: user);
        },
      ),
    ],
  );
});