import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db/database.dart';
import '../core/format/dates.dart';
import '../domain/budgets.dart';
import '../domain/enums.dart';
import '../domain/fina.dart';
import '../domain/ledger.dart';
import '../domain/streak.dart';
import 'repositories.dart';

// ---------------------------------------------------------------------------
// Datenbank & Repositories
// ---------------------------------------------------------------------------

/// Wird in main.dart mit der geöffneten Datenbank überschrieben.
final databaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError('databaseProvider überschreiben'));

final accountsRepoProvider = Provider((ref) => AccountsRepository(ref.watch(databaseProvider)));
final categoriesRepoProvider = Provider((ref) => CategoriesRepository(ref.watch(databaseProvider)));
final bookingsRepoProvider = Provider((ref) => BookingsRepository(ref.watch(databaseProvider)));
final recurringRepoProvider = Provider((ref) => RecurringRepository(ref.watch(databaseProvider)));
final budgetsRepoProvider = Provider((ref) => BudgetsRepository(ref.watch(databaseProvider)));
final goalsRepoProvider = Provider((ref) => GoalsRepository(ref.watch(databaseProvider)));
final debtsRepoProvider = Provider((ref) => DebtsRepository(ref.watch(databaseProvider)));
final settingsRepoProvider = Provider((ref) => SettingsRepository(ref.watch(databaseProvider)));

// ---------------------------------------------------------------------------
// Rohdaten (Streams aus drift)
// ---------------------------------------------------------------------------

final accountsProvider = StreamProvider<List<Account>>((ref) => ref.watch(accountsRepoProvider).watchAll());
final categoriesProvider = StreamProvider<List<Category>>((ref) => ref.watch(categoriesRepoProvider).watchAll());
final bookingsProvider = StreamProvider<List<Booking>>((ref) => ref.watch(bookingsRepoProvider).watchAll());
final rulesProvider = StreamProvider<List<RecurringRule>>((ref) => ref.watch(recurringRepoProvider).watchAll());
final budgetsProvider = StreamProvider<List<Budget>>((ref) => ref.watch(budgetsRepoProvider).watchAll());
final goalsProvider = StreamProvider<List<SavingsGoal>>((ref) => ref.watch(goalsRepoProvider).watchGoals());
final contributionsProvider = StreamProvider<List<GoalContribution>>(
  (ref) => ref.watch(goalsRepoProvider).watchContributions(),
);
final debtsProvider = StreamProvider<List<Debt>>((ref) => ref.watch(debtsRepoProvider).watchDebts());
final debtPaymentsProvider = StreamProvider<List<DebtPayment>>((ref) => ref.watch(debtsRepoProvider).watchPayments());
final settingsProvider = StreamProvider<Map<String, String>>((ref) => ref.watch(settingsRepoProvider).watchAll());
final activityDaysProvider = StreamProvider<Set<int>>((ref) => ref.watch(settingsRepoProvider).watchActivityDays());

final categoriesByIdProvider = Provider<Map<int, Category>>((ref) {
  final list = ref.watch(categoriesProvider).value ?? const <Category>[];
  return {for (final c in list) c.id: c};
});

final accountsByIdProvider = Provider<Map<int, Account>>((ref) {
  final list = ref.watch(accountsProvider).value ?? const <Account>[];
  return {for (final a in list) a.id: a};
});

// ---------------------------------------------------------------------------
// Zeit
// ---------------------------------------------------------------------------

/// Aktuelle Uhrzeit, minütlich und beim Zurückkehren in die App aktualisiert.
final clockProvider = NotifierProvider<ClockNotifier, DateTime>(ClockNotifier.new);

class ClockNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final timer = Timer.periodic(const Duration(minutes: 1), (_) => state = DateTime.now());
    ref.onDispose(timer.cancel);
    return DateTime.now();
  }

  void refresh() => state = DateTime.now();
}

/// Heutiges Datum – ändert sich nur einmal am Tag.
final todayProvider = Provider<DateTime>((ref) => Dates.dateOnly(ref.watch(clockProvider)));

// ---------------------------------------------------------------------------
// Profil
// ---------------------------------------------------------------------------

abstract final class SettingKeys {
  static const name = 'profile.name';
  static const tone = 'profile.tone';
  static const focus = 'profile.focus';
  static const onboarded = 'onboarding.done';
  static const homeSort = 'pref.homeSort';
  static const lastBackup = 'backup.last';
}

class Profile {
  const Profile({required this.name, required this.tone, required this.focus, required this.onboarded});

  factory Profile.fromSettings(Map<String, String> s) => Profile(
    name: s[SettingKeys.name] ?? '',
    tone: FinaTone.values.firstWhereOrNull((t) => t.name == s[SettingKeys.tone]) ?? FinaTone.warm,
    focus: MoneyFocus.values.firstWhereOrNull((f) => f.name == s[SettingKeys.focus]) ?? MoneyFocus.overview,
    onboarded: s[SettingKeys.onboarded] == 'true',
  );

  final String name;
  final FinaTone tone;
  final MoneyFocus focus;
  final bool onboarded;

  String get displayName => name.trim().isEmpty ? 'du' : name.trim();
}

final profileProvider = Provider<Profile?>((ref) {
  final s = ref.watch(settingsProvider).value;
  return s == null ? null : Profile.fromSettings(s);
});

// ---------------------------------------------------------------------------
// Finanzlogik
// ---------------------------------------------------------------------------

/// Die zentrale Rechnung über alle Daten. null, solange noch geladen wird.
final ledgerProvider = Provider<Ledger?>((ref) {
  final accounts = ref.watch(accountsProvider).value;
  final bookings = ref.watch(bookingsProvider).value;
  final rules = ref.watch(rulesProvider).value;
  final goals = ref.watch(goalsProvider).value;
  final contributions = ref.watch(contributionsProvider).value;
  if (accounts == null || bookings == null || rules == null || goals == null || contributions == null) return null;
  final now = ref.watch(clockProvider);
  return Ledger(
    accounts: accounts,
    bookings: bookings,
    rules: rules,
    goals: goals,
    contributions: contributions,
    now: now,
  );
});

final monthSummaryProvider = Provider.family<MonthSummary?, YearMonth>((ref, m) => ref.watch(ledgerProvider)?.month(m));

final budgetStatusProvider = Provider.family<List<BudgetStatus>, YearMonth>((ref, m) {
  final summary = ref.watch(monthSummaryProvider(m));
  final rows = ref.watch(budgetsProvider).value;
  if (summary == null || rows == null) return const [];
  return BudgetLogic.statusFor(month: m, rows: rows, summary: summary, categories: ref.watch(categoriesByIdProvider));
});

final debtStatusesProvider = Provider<List<DebtStatus>>((ref) {
  final debts = ref.watch(debtsProvider).value ?? const <Debt>[];
  final payments = ref.watch(debtPaymentsProvider).value ?? const <DebtPayment>[];
  final today = ref.watch(todayProvider);
  final byDebt = groupBy(payments, (DebtPayment p) => p.debtId);
  return [for (final d in debts) DebtStatus(debt: d, payments: byDebt[d.id] ?? const [], today: today)];
});

final goalProgressProvider = Provider<List<GoalProgress>>((ref) {
  final ledger = ref.watch(ledgerProvider);
  if (ledger == null) return const [];
  return [for (final g in ledger.goals) ledger.goalProgress(g)];
});

final streakProvider = Provider<int>((ref) {
  final days = ref.watch(activityDaysProvider).value ?? const <int>{};
  return Streak.current(days, ref.watch(todayProvider));
});

/// Häufigste kleine Ausgabe (≤ 10 €) der letzten 60 Tage für die Tipp-Karte.
final frequentSmallExpenseProvider = Provider<(String, int)?>((ref) {
  final ledger = ref.watch(ledgerProvider);
  if (ledger == null) return null;
  final since = ledger.today.subtract(const Duration(days: 60));
  final counts = <String, List<int>>{};
  final names = <String, String>{};
  for (final b in ledger.bookings) {
    if (b.type != BookingType.expense || b.status != BookingStatus.booked) continue;
    if (b.amount > 1000 || b.date.isBefore(since)) continue;
    final key = b.title.trim().toLowerCase();
    if (key.isEmpty) continue;
    (counts[key] ??= []).add(b.amount);
    names[key] = b.title.trim();
  }
  final best = counts.entries.where((e) => e.value.length >= 2).sortedBy<num>((e) => -e.value.length).firstOrNull;
  if (best == null) return null;
  final amounts = best.value..sort();
  return (names[best.key]!, amounts[amounts.length ~/ 2]);
});

final finaContextProvider = Provider<FinaContext?>((ref) {
  final ledger = ref.watch(ledgerProvider);
  final profile = ref.watch(profileProvider);
  if (ledger == null || profile == null) return null;
  final now = ref.watch(clockProvider);
  final month = YearMonth.of(now);
  final summary = ref.watch(monthSummaryProvider(month));
  if (summary == null) return null;
  return FinaContext(
    now: now,
    name: profile.displayName,
    tone: profile.tone,
    focus: profile.focus,
    hasBookings: ledger.bookings.any((b) => b.status == BookingStatus.booked),
    available: ledger.available,
    forecastEnd: ledger.forecastMonthEnd.end,
    month: summary,
    budgets: ref.watch(budgetStatusProvider(month)),
    streak: ref.watch(streakProvider),
    dueCount: ledger.dueItems.where((p) => !(p.isVirtual && p.rule?.autoBook == true)).length,
    goals: ref.watch(goalProgressProvider),
    frequentSmallExpense: ref.watch(frequentSmallExpenseProvider),
    categoryNames: {for (final c in ref.watch(categoriesByIdProvider).values) c.id: c.name},
    bookingCount: ledger.bookings.where((b) => b.status == BookingStatus.booked).length,
    daysSinceBackup: switch (DateTime.tryParse(ref.watch(settingsProvider).value?[SettingKeys.lastBackup] ?? '')) {
      final last? => Dates.daysBetween(last, now),
      null => null,
    },
    inBrowser: kIsWeb,
  );
});

/// Fällige Posten, die eine Bestätigung brauchen (automatisch gebuchte
/// Daueraufträge erledigt der Abgleich selbst).
final dueItemsProvider = Provider<List<PlannedItem>>((ref) {
  final ledger = ref.watch(ledgerProvider);
  if (ledger == null) return const [];
  return ledger.dueItems.where((p) => !(p.isVirtual && p.rule?.autoBook == true)).toList();
});
