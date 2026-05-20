import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _tabs = [
    (icon: Icons.dashboard_outlined, active: Icons.dashboard, label: 'Início', path: '/dashboard'),
    (icon: Icons.swap_vert_outlined, active: Icons.swap_vert, label: 'Transações', path: '/transactions'),
    (icon: Icons.account_balance_wallet_outlined, active: Icons.account_balance_wallet, label: 'Contas', path: '/accounts'),
    (icon: Icons.bar_chart_outlined, active: Icons.bar_chart, label: 'Relatórios', path: '/reports'),
    (icon: Icons.category_outlined, active: Icons.category, label: 'Categorias', path: '/categories'),
    (icon: Icons.repeat_outlined, active: Icons.repeat, label: 'Recorren.', path: '/recurring'),
    (icon: Icons.smart_toy_outlined, active: Icons.smart_toy, label: 'IA', path: '/chat'),
  ];

  int _currentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    final idx = _tabs.indexWhere((t) => loc.startsWith(t.path));
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = _currentIndex(context);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      body: child,
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'theme_toggle',
        backgroundColor: context.appSurface,
        foregroundColor: AppTheme.primaryColor,
        elevation: 2,
        onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
        child: Icon(
          isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          size: 18,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
                fontSize: 9.5,
                fontWeight: states.contains(WidgetState.selected)
                    ? FontWeight.w600
                    : FontWeight.w400,
                overflow: TextOverflow.ellipsis,
              )),
        ),
        child: NavigationBar(
          selectedIndex: current,
          onDestinationSelected: (i) => context.go(_tabs[i].path),
          destinations: _tabs
              .map((t) => NavigationDestination(
                    icon: Icon(t.icon),
                    selectedIcon: Icon(t.active),
                    label: t.label,
                  ))
              .toList(),
        ),
      ),
    );
  }
}
