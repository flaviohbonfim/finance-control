import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../utils/platform_utils.dart';
import '../theme/app_theme.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _tabs = [
    (icon: Icons.dashboard_outlined,              active: Icons.dashboard,              label: 'Início',      fullLabel: 'Início',       path: '/dashboard'),
    (icon: Icons.swap_vert_outlined,              active: Icons.swap_vert,              label: 'Transações',  fullLabel: 'Transações',   path: '/transactions'),
    (icon: Icons.account_balance_wallet_outlined, active: Icons.account_balance_wallet, label: 'Contas',      fullLabel: 'Contas',       path: '/accounts'),
    (icon: Icons.bar_chart_outlined,              active: Icons.bar_chart,              label: 'Relatórios',  fullLabel: 'Relatórios',   path: '/reports'),
    (icon: Icons.category_outlined,               active: Icons.category,               label: 'Categorias',  fullLabel: 'Categorias',   path: '/categories'),
    (icon: Icons.repeat_outlined,                 active: Icons.repeat,                 label: 'Recorren.',   fullLabel: 'Recorrentes',  path: '/recurring'),
    (icon: Icons.smart_toy_outlined,              active: Icons.smart_toy,              label: 'IA',          fullLabel: 'Assistente IA', path: '/chat'),
  ];

  int _currentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    final idx = _tabs.indexWhere((t) => loc.startsWith(t.path));
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentIndex(context);

    if (isDesktop) {
      return _DesktopShell(current: current, child: child);
    }

    return _MobileShell(current: current, child: child);
  }
}

// ── Mobile shell (bottom navigation bar) ─────────────────────────────────────

class _MobileShell extends StatelessWidget {
  final int current;
  final Widget child;
  const _MobileShell({required this.current, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
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
          onDestinationSelected: (i) => context.go(MainShell._tabs[i].path),
          destinations: MainShell._tabs
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

// ── Desktop shell (sidebar navigation rail) ───────────────────────────────────

class _DesktopShell extends StatelessWidget {
  final int current;
  final Widget child;
  const _DesktopShell({required this.current, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(current: current),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final int current;
  const _Sidebar({required this.current});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Finance',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.primary,
                  ),
                ),
                Text(
                  'Control',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface.withAlpha(120),
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          // Nav items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              children: List.generate(MainShell._tabs.length, (i) {
                final tab = MainShell._tabs[i];
                final selected = i == current;
                return _NavItem(
                  icon: selected ? tab.active : tab.icon,
                  label: tab.fullLabel,
                  selected: selected,
                  onTap: () => context.go(tab.path),
                );
              }),
            ),
          ),
          // Settings at bottom
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: _NavItem(
              icon: Icons.settings_outlined,
              label: 'Configurações',
              selected: false,
              onTap: () => context.push('/settings'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = selected ? colorScheme.primary.withAlpha(25) : Colors.transparent;
    final fg = selected ? colorScheme.primary : AppTheme.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
