import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/format/dates.dart';
import '../features/home/home_screen.dart';
import '../features/months/month_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/savings/debt_screens.dart';
import '../features/savings/goal_detail_screen.dart';
import '../features/savings/savings_screen.dart';
import '../features/settings/accounts_screen.dart';
import '../features/settings/budgets_screen.dart';
import '../features/settings/categories_screen.dart';
import '../features/settings/data_screen.dart';
import '../features/settings/profile_screen.dart';
import '../features/settings/recurring_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/stats/category_detail_screen.dart';
import '../features/stats/stats_screen.dart';
import 'shell.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter buildRouter(String initialLocation) => GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: initialLocation,
  routes: [
    GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/stats', builder: (_, _) => const StatsScreen())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/savings', builder: (_, _) => const SavingsScreen())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen())],
        ),
      ],
    ),
    GoRoute(
      path: '/month/:key',
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, s) => MonthScreen(initial: YearMonth.fromKey(int.parse(s.pathParameters['key']!))),
    ),
    GoRoute(
      path: '/category/:id',
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, s) => CategoryDetailScreen(categoryId: int.parse(s.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/goal/:id',
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, s) => GoalDetailScreen(goalId: int.parse(s.pathParameters['id']!)),
    ),
    GoRoute(path: '/debts', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const DebtsScreen()),
    GoRoute(
      path: '/debt/:id',
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, s) => DebtDetailScreen(debtId: int.parse(s.pathParameters['id']!)),
    ),
    GoRoute(path: '/accounts', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const AccountsScreen()),
    GoRoute(
      path: '/account/:id',
      parentNavigatorKey: rootNavigatorKey,
      builder: (_, s) => AccountDetailScreen(accountId: int.parse(s.pathParameters['id']!)),
    ),
    GoRoute(path: '/categories', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const CategoriesScreen()),
    GoRoute(path: '/budgets', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const BudgetsScreen()),
    GoRoute(path: '/recurring', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const RecurringScreen()),
    GoRoute(path: '/profile', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const ProfileScreen()),
    GoRoute(path: '/data', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const DataScreen()),
  ],
);
