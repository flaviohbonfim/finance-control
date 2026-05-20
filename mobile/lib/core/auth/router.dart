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
import '../shell/main_shell.dart';
import '../../features/auth/login_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final loggedIn = auth.isAuthenticated;
      final onLogin = state.matchedLocation == '/login';
      if (!loggedIn && !onLogin) return '/login';
      if (loggedIn && onLogin) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
          GoRoute(path: '/transactions', builder: (context, state) => const TransactionsScreen()),
          GoRoute(path: '/accounts', builder: (context, state) => const AccountsScreen()),
          GoRoute(path: '/categories', builder: (context, state) => const CategoriesScreen()),
          GoRoute(path: '/recurring', builder: (context, state) => const RecurringScreen()),
          GoRoute(path: '/reports', builder: (context, state) => const ReportsScreen()),
          GoRoute(path: '/chat', builder: (context, state) => const ChatScreen()),
        ],
      ),
    ],
  );
});
