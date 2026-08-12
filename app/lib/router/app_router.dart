import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../core/supabase_service.dart';
import '../screens/auth/login_screen.dart';
import '../screens/home/home_shell.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/products/products_screen.dart';
import '../screens/sales/pos_screen.dart';
import '../screens/sales/sales_history_screen.dart';
import '../screens/cash/cash_screen.dart';
import '../screens/debtors/debtors_screen.dart';
import '../screens/debtors/debtor_detail_screen.dart';
import '../screens/settings/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _AuthRefresh(ref),
    redirect: (context, state) {
      final loggedIn = sb.auth.currentSession != null;
      final loggingIn = state.matchedLocation == '/login';
      if (!loggedIn && !loggingIn) return '/login';
      if (loggedIn && loggingIn) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => HomeShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (c, s) => const DashboardScreen()),
          GoRoute(path: '/pos', builder: (c, s) => const PosScreen()),
          GoRoute(
              path: '/sales-history',
              builder: (c, s) => const SalesHistoryScreen()),
          GoRoute(path: '/products', builder: (c, s) => const ProductsScreen()),
          GoRoute(path: '/cash', builder: (c, s) => const CashScreen()),
          GoRoute(path: '/debtors', builder: (c, s) => const DebtorsScreen()),
          GoRoute(
            path: '/debtors/:id',
            builder: (c, s) => DebtorDetailScreen(
              customerId: int.parse(s.pathParameters['id']!),
            ),
          ),
          GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
        ],
      ),
    ],
  );
});

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
  }
}
