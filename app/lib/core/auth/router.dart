import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_provider.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/transactions/transactions_screen.dart';
import '../../features/accounts/accounts_screen.dart';
import '../../features/categories/categories_screen.dart';
import '../../features/recurring/recurring_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../shell/main_shell.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/verify_email_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/reset_password_screen.dart';

Page<void> _fadePage(LocalKey key, Widget child) => CustomTransitionPage(
      key: key,
      child: child,
      transitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    );

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ValueNotifier<AuthState>(ref.read(authProvider));
  ref.listen<AuthState>(authProvider, (_, next) => authNotifier.value = next);
  ref.onDispose(authNotifier.dispose);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final auth = authNotifier.value;
      final loggedIn = auth.isAuthenticated;
      final verified = auth.isVerified;
      final loc = state.matchedLocation;

      final onVerifyEmail = loc == '/verify-email';
      final onPublicScreen = loc == '/login' || loc == '/register' ||
          loc == '/forgot-password' || loc == '/reset-password';

      if (!loggedIn && !onPublicScreen && !onVerifyEmail) return '/login';
      if (loggedIn && !verified && !onVerifyEmail) return '/verify-email';
      if (loggedIn && verified && (onPublicScreen || onVerifyEmail)) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (_, state) => _fadePage(state.pageKey, const LoginScreen()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (_, state) => _fadePage(state.pageKey, const RegisterScreen()),
      ),
      GoRoute(
        path: '/verify-email',
        pageBuilder: (_, state) {
          final email = (state.extra as String?) ??
              (state.uri.queryParameters['email'] ?? '');
          return _fadePage(state.pageKey, VerifyEmailScreen(email: email));
        },
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (_, state) => _fadePage(state.pageKey, const ForgotPasswordScreen()),
      ),
      GoRoute(
        path: '/reset-password',
        pageBuilder: (_, state) {
          final email = (state.extra as String?) ?? '';
          return _fadePage(state.pageKey, ResetPasswordScreen(email: email));
        },
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (_, state) => _fadePage(state.pageKey, const SettingsScreen()),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/dashboard',    pageBuilder: (_, state) => _fadePage(state.pageKey, const DashboardScreen())),
          GoRoute(path: '/transactions', pageBuilder: (_, state) => _fadePage(state.pageKey, const TransactionsScreen())),
          GoRoute(path: '/accounts',     pageBuilder: (_, state) => _fadePage(state.pageKey, const AccountsScreen())),
          GoRoute(path: '/categories',   pageBuilder: (_, state) => _fadePage(state.pageKey, const CategoriesScreen())),
          GoRoute(path: '/recurring',    pageBuilder: (_, state) => _fadePage(state.pageKey, const RecurringScreen())),
          GoRoute(path: '/reports',      pageBuilder: (_, state) => _fadePage(state.pageKey, const ReportsScreen())),
          GoRoute(path: '/chat',         pageBuilder: (_, state) => _fadePage(state.pageKey, const ChatScreen())),
        ],
      ),
    ],
  );
});
