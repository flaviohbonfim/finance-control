import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _tabs = [
    (icon: Icons.dashboard_outlined, active: Icons.dashboard, label: 'Dashboard', path: '/dashboard'),
    (icon: Icons.swap_vert_outlined, active: Icons.swap_vert, label: 'Transações', path: '/transactions'),
    (icon: Icons.account_balance_wallet_outlined, active: Icons.account_balance_wallet, label: 'Contas', path: '/accounts'),
    (icon: Icons.bar_chart_outlined, active: Icons.bar_chart, label: 'Relatórios', path: '/reports'),
    (icon: Icons.smart_toy_outlined, active: Icons.smart_toy, label: 'IA', path: '/chat'),
  ];

  int _currentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    final idx = _tabs.indexWhere((t) => loc.startsWith(t.path));
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
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
    );
  }
}
