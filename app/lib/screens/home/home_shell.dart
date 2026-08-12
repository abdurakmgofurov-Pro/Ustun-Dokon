import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

class _NavItem {
  final String path;
  final IconData icon;
  final String label;
  final bool adminOnly;
  const _NavItem(this.path, this.icon, this.label, {this.adminOnly = false});
}

const _navItems = [
  _NavItem('/', Icons.dashboard_outlined, 'Bosh sahifa'),
  _NavItem('/pos', Icons.point_of_sale_outlined, 'Savdo'),
  _NavItem('/sales-history', Icons.receipt_long_outlined, 'Cheklar'),
  _NavItem('/products', Icons.inventory_2_outlined, 'Tovarlar'),
  _NavItem('/debtors', Icons.people_outline, 'Qarzdorlar'),
  _NavItem('/cash', Icons.account_balance_wallet_outlined, 'Kassa',
      adminOnly: true),
  _NavItem('/settings', Icons.settings_outlined, 'Sozlamalar',
      adminOnly: true),
];

class HomeShell extends ConsumerWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final items = _navItems.where((i) => !i.adminOnly || isAdmin).toList();

    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex = items.indexWhere((i) => i.path == location);
    final safeIndex = selectedIndex < 0 ? 0 : selectedIndex;

    final isWide = MediaQuery.of(context).size.width >= 800;

    final body = child;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: safeIndex,
              onDestinationSelected: (i) => context.go(items[i].path),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 22,
                      child: Icon(Icons.storefront),
                    ),
                    const SizedBox(height: 8),
                    Text(profile?.fullName ?? '',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      children: [
                        const _ThemeToggleButton(),
                        IconButton(
                          tooltip: 'Chiqish',
                          icon: const Icon(Icons.logout),
                          onPressed: () =>
                              ref.read(authControllerProvider).signOut(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              destinations: [
                for (final item in items)
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    label: Text(item.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(items[safeIndex].label),
        actions: [
          const _ThemeToggleButton(),
          IconButton(
            tooltip: 'Chiqish',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider).signOut(),
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (i) => context.go(items[i].path),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: [
          for (final item in items)
            NavigationDestination(icon: Icon(item.icon), label: item.label),
        ],
      ),
    );
  }
}

class _ThemeToggleButton extends ConsumerWidget {
  const _ThemeToggleButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final platformBrightness = MediaQuery.of(context).platformBrightness;
    final isDark = mode == ThemeMode.dark ||
        (mode == ThemeMode.system && platformBrightness == Brightness.dark);
    return IconButton(
      tooltip: isDark ? 'Yorug\' rejim' : 'Qorong\'i rejim',
      icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      onPressed: () =>
          ref.read(themeModeProvider.notifier).toggle(platformBrightness),
    );
  }
}
