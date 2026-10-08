import 'dart:math' as math;

import 'package:collection/collection.dart';

import '../core/db/database.dart';
import '../core/format/dates.dart';
import 'enums.dart';
import 'recurrence.dart';

/// Ein noch nicht gebuchter Posten: eine gespeicherte geplante Buchung oder ein
/// berechneter Termin eines Dauerauftrags. Verändert keinen Kontostand.
class PlannedItem {
  const PlannedItem({
    required this.date,
    required this.type,
    required this.amount,
    required this.accountId,
    required this.title,
    this.toAccountId,
    this.categoryId,
    this.booking,
    this.rule,
    this.occurrenceDate,
  });

  factory PlannedItem.fromBooking(Booking b, RecurringRule? rule) => PlannedItem(
    date: b.date,
    type: b.type,
    amount: b.amount,
    accountId: b.accountId,
    toAccountId: b.toAccountId,
    categoryId: b.categoryId,
    title: b.title,
    booking: b,
    rule: rule,
    occurrenceDate: b.occurrenceDate,
  );

  factory PlannedItem.fromRule(RecurringRule r, DateTime occurrence) => PlannedItem(
    date: occurrence,
    type: r.type,
    amount: r.amount,
    accountId: r.accountId,
    toAccountId: r.toAccountId,
    categoryId: r.categoryId,
    title: r.title,
    rule: r,
    occurrenceDate: occurrence,
  );

  final DateTime date;
  final BookingType type;
  final int amount;
  final int accountId;
  final int? toAccountId;
  final int? categoryId;
  final String title;

  /// Gespeicherte geplante Buchung (null bei berechnetem Termin).
  final Booking? booking;

  /// Dauerauftrag, aus dem der Posten stammt.
  final RecurringRule? rule;
  final DateTime? occurrenceDate;

  bool get isVirtual => booking == null;
  bool get isRecurring => rule != null;

  /// Stabiler Schlüssel für Listen.
  String get key => booking != null ? 'b${booking!.id}' : 'r${rule!.id}-${Dates.dayKey(occurrenceDate!)}';
}

/// Einnahmen und Ausgaben eines Zeitraums – Umbuchungen zählen nie dazu.
class FlowSummary {
  const FlowSummary({
    required this.income,
    required this.expenses,
    required this.expenseByCategory,
    required this.incomeByCategory,
    required this.bookings,
  });

  final int income;
  final int expenses;

  /// Kategorie-ID (null = ohne Kategorie) → Summe.
  final Map<int?, int> expenseByCategory;
  final Map<int?, int> incomeByCategory;

  /// Alle gebuchten Buchungen des Zeitraums (inkl. Umbuchungen), neueste zuerst.
  final List<Booking> bookings;

  int get saved => income - expenses;

  /// Anteil des Einkommens, der übrig blieb (null ohne Einkommen).
  double? get savingsRate => income > 0 ? saved / income : null;

  Iterable<Booking> get expenseBookings => bookings.where((b) => b.type == BookingType.expense);
  Iterable<Booking> get incomeBookings => bookings.where((b) => b.type == BookingType.income);
}

class MonthSummary {
  const MonthSummary({required this.month, required this.flow, required this.pending});

  final YearMonth month;
  final FlowSummary flow;

  /// Noch offene Posten mit Datum in diesem Monat (auch überfällige).
  final List<PlannedItem> pending;

  int get income => flow.income;
  int get expenses => flow.expenses;
  int get saved => flow.saved;

  int get plannedIncome => pending.where((p) => p.type == BookingType.income).fold(0, (s, p) => s + p.amount);
  int get plannedExpenses => pending.where((p) => p.type == BookingType.expense).fold(0, (s, p) => s + p.amount);

  /// Was am Monatsende voraussichtlich übrig bleibt, wenn alles Geplante eintritt.
  int get projectedSaved => income + plannedIncome - expenses - plannedExpenses;

  int plannedExpensesFor(int? categoryId) =>
      pending.where((p) => p.type == BookingType.expense && p.categoryId == categoryId).fold(0, (s, p) => s + p.amount);
}

/// Erwartetes verfügbares Guthaben zu einem Stichtag.
class Forecast {
  const Forecast({required this.start, required this.until, required this.items, required this.deltas});

  final int start;
  final DateTime until;
  final List<PlannedItem> items;

  /// Wirkung jedes Postens auf das verfügbare Guthaben (gleiche Reihenfolge).
  final List<int> deltas;

  int get incoming => deltas.where((d) => d > 0).fold(0, (s, d) => s + d);
  int get outgoing => -deltas.where((d) => d < 0).fold(0, (s, d) => s + d);
  int get end => start + incoming - outgoing;
}

class GoalProgress {
  const GoalProgress({required this.goal, required this.saved, required this.today});

  final SavingsGoal goal;
  final int saved;
  final DateTime today;

  int get target => goal.targetAmount;
  int get remaining => math.max(0, target - saved);
  double get ratio => target <= 0 ? 0 : (saved / target).clamp(0.0, 1.0);
  bool get reached => saved >= target;
  bool get completed => goal.completedAt != null;

  /// Volle Monate bis zum Zieldatum (mind. 1), null ohne Zieldatum.
  int? get monthsLeft {
    final d = goal.targetDate;
    if (d == null) return null;
    final months = (d.year - today.year) * 12 + (d.month - today.month);
    return math.max(1, months);
  }

  /// Was pro Monat zurückgelegt werden müsste, um das Zieldatum zu schaffen.
  int? get monthlyNeeded {
    final m = monthsLeft;
    if (m == null || reached) return null;
    return (remaining / m).ceil();
  }
}

class DebtStatus {
  const DebtStatus({required this.debt, required this.payments, required this.today});

  final Debt debt;
  final List<DebtPayment> payments;
  final DateTime today;

  int get paid => payments.fold(0, (s, p) => s + p.amount);
  int get remaining => math.max(0, debt.amount - paid);
  bool get isSettled => remaining == 0 || debt.closedAt != null;
  bool get isPartial => paid > 0 && !isSettled;
  bool get isOverdue =>
      !isSettled && debt.dueDate != null && Dates.dateOnly(debt.dueDate!).isBefore(Dates.dateOnly(today));
  double get ratio => (paid / debt.amount).clamp(0.0, 1.0);
}

/// Die zentrale Finanzlogik. Rein und ohne Datenbankzugriff: bekommt alle
/// Datensätze und rechnet daraus Kontostände, Monatsbilanzen, Planungen und
/// Prognosen. Die Regeln, die doppeltes Zählen verhindern:
///
/// * Nur **gebuchte** Buchungen verändern Kontostände. Geplante Buchungen und
///   Termine von Daueraufträgen erscheinen nur in Planung und Prognose.
/// * **Umbuchungen** verschieben Geld zwischen Konten, sind aber weder Einnahme
///   noch Ausgabe.
/// * Buchungen **vor dem Startdatum eines Kontos** sind im Startsaldo schon
///   enthalten: Sie zählen für Statistiken, nicht für den Kontostand.
/// * **Sparziele** reservieren Geld, statt es auszugeben. Liegt das reservierte
///   Geld auf einem „verfügbaren“ Konto, sinkt das verfügbare Guthaben.
/// * **Schulden** sind reine Notizen, bis eine Zahlung als Buchung erfasst wird.
/// * Ein Termin eines Dauerauftrags gilt als erledigt, sobald es zu
///   (Regel, Termin) irgendeine Buchung gibt – egal ob gebucht, geplant oder
///   übersprungen. Er wird dann nicht mehr berechnet.
class Ledger {
  Ledger({
    required List<Account> accounts,
    required List<Booking> bookings,
    required List<RecurringRule> rules,
    List<SavingsGoal> goals = const [],
    List<GoalContribution> contributions = const [],
    required this.now,
  }) : accounts = List.unmodifiable(accounts),
       bookings = List.unmodifiable(bookings),
       rules = List.unmodifiable(rules),
       goals = List.unmodifiable(goals),
       contributions = List.unmodifiable(contributions),
       today = Dates.dateOnly(now) {
    _accountById = {for (final a in accounts) a.id: a};
    _ruleById = {for (final r in rules) r.id: r};
    for (final b in bookings) {
      if (b.recurringId != null && b.occurrenceDate != null) {
        (_handled[b.recurringId!] ??= <int>{}).add(Dates.dayKey(b.occurrenceDate!));
      }
    }
  }

  final List<Account> accounts;
  final List<Booking> bookings;
  final List<RecurringRule> rules;
  final List<SavingsGoal> goals;
  final List<GoalContribution> contributions;
  final DateTime now;
  final DateTime today;

  late final Map<int, Account> _accountById;
  late final Map<int, RecurringRule> _ruleById;
  final Map<int, Set<int>> _handled = {};

  Account? account(int id) => _accountById[id];
  RecurringRule? rule(int id) => _ruleById[id];

  // ---------------------------------------------------------------------------
  // Kontostände
  // ---------------------------------------------------------------------------

  /// Verändert die Buchung den Stand von [accountId]?
  bool affectsBalance(Booking b, int accountId) {
    if (b.status != BookingStatus.booked) return false;
    final acc = _accountById[accountId];
    if (acc == null) return false;
    return !Dates.dateOnly(b.date).isBefore(Dates.dateOnly(acc.openingDate));
  }

  /// Wirkung einer gebuchten Buchung auf ein Konto (positiv = mehr Geld).
  int effectOn(Booking b, int accountId) {
    if (!affectsBalance(b, accountId)) return 0;
    switch (b.type) {
      case BookingType.expense:
        return b.accountId == accountId ? -b.amount : 0;
      case BookingType.income:
        return b.accountId == accountId ? b.amount : 0;
      case BookingType.transfer:
        var e = 0;
        if (b.accountId == accountId) e -= b.amount;
        if (b.toAccountId == accountId) e += b.amount;
        return e;
    }
  }

  late final Map<int, int> balances = () {
    final map = {for (final a in accounts) a.id: a.openingBalance};
    for (final b in bookings) {
      if (b.status != BookingStatus.booked) continue;
      if (map.containsKey(b.accountId)) map[b.accountId] = map[b.accountId]! + effectOn(b, b.accountId);
      final to = b.toAccountId;
      if (b.type == BookingType.transfer && to != null && to != b.accountId && map.containsKey(to)) {
        map[to] = map[to]! + effectOn(b, to);
      }
    }
    return map;
  }();

  int balanceOf(int accountId) => balances[accountId] ?? 0;

  bool isSpendable(int accountId) {
    final a = _accountById[accountId];
    return a != null && a.includeInAvailable && !a.archived;
  }

  int get totalBalance => balances.values.fold(0, (s, v) => s + v);

  int get spendableBalance => accounts.where((a) => isSpendable(a.id)).fold(0, (s, a) => s + balanceOf(a.id));

  int get savingsAccountsBalance =>
      accounts.where((a) => a.type == AccountType.savings).fold(0, (s, a) => s + balanceOf(a.id));

  // ---------------------------------------------------------------------------
  // Sparziele & Reservierungen
  // ---------------------------------------------------------------------------

  Set<int> get _activeGoalIds => goals.where((g) => g.completedAt == null).map((g) => g.id).toSet();

  /// Reserviertes Geld je Konto (nur aktive Ziele; je Ziel und Konto nie negativ).
  late final Map<int, int> reservedByAccount = () {
    final active = _activeGoalIds;
    final perGoalAccount = <(int, int), int>{};
    for (final c in contributions) {
      final acc = c.heldInAccountId;
      if (acc == null || !active.contains(c.goalId)) continue;
      perGoalAccount[(c.goalId, acc)] = (perGoalAccount[(c.goalId, acc)] ?? 0) + c.amount;
    }
    final result = <int, int>{};
    perGoalAccount.forEach((k, v) {
      if (v > 0) result[k.$2] = (result[k.$2] ?? 0) + v;
    });
    return result;
  }();

  int get reservedInSpendable =>
      reservedByAccount.entries.where((e) => isSpendable(e.key)).fold(0, (s, e) => s + e.value);

  /// Das Herzstück des Startbildschirms: Geld auf „verfügbaren“ Konten,
  /// abzüglich dessen, was dort für Sparziele zurückgelegt ist.
  int get available => spendableBalance - reservedInSpendable;

  int savedForGoal(int goalId) =>
      math.max(0, contributions.where((c) => c.goalId == goalId).fold(0, (s, c) => s + c.amount));

  GoalProgress goalProgress(SavingsGoal g) => GoalProgress(goal: g, saved: savedForGoal(g.id), today: today);

  // ---------------------------------------------------------------------------
  // Einnahmen & Ausgaben
  // ---------------------------------------------------------------------------

  /// Gebuchte Einnahmen/Ausgaben im Zeitraum [from, toExclusive).
  FlowSummary flow(DateTime from, DateTime toExclusive) {
    var income = 0;
    var expenses = 0;
    final byCat = <int?, int>{};
    final incByCat = <int?, int>{};
    final list = <Booking>[];
    for (final b in bookings) {
      if (b.status != BookingStatus.booked) continue;
      if (b.date.isBefore(from) || !b.date.isBefore(toExclusive)) continue;
      list.add(b);
      switch (b.type) {
        case BookingType.expense:
          expenses += b.amount;
          byCat[b.categoryId] = (byCat[b.categoryId] ?? 0) + b.amount;
        case BookingType.income:
          income += b.amount;
          incByCat[b.categoryId] = (incByCat[b.categoryId] ?? 0) + b.amount;
        case BookingType.transfer:
          break;
      }
    }
    list.sort(_newestFirst);
    return FlowSummary(
      income: income,
      expenses: expenses,
      expenseByCategory: byCat,
      incomeByCategory: incByCat,
      bookings: list,
    );
  }

  MonthSummary month(YearMonth m) =>
      MonthSummary(month: m, flow: flow(m.firstDay, m.end), pending: pendingBetween(m.firstDay, m.lastDay));

  /// Gespart (Einnahmen − Ausgaben) für die letzten [count] Monate bis [last].
  List<MonthSummary> recentMonths(YearMonth last, int count) => [
    for (var i = count - 1; i >= 0; i--) month(last.add(-i)),
  ];

  // ---------------------------------------------------------------------------
  // Planung
  // ---------------------------------------------------------------------------

  /// Alle offenen Posten mit Datum zwischen [from] und [to] (inklusive).
  List<PlannedItem> pendingBetween(DateTime from, DateTime to) {
    final lo = Dates.dateOnly(from);
    final hi = Dates.dateOnly(to);
    final items = <PlannedItem>[];
    for (final b in bookings) {
      if (b.status != BookingStatus.planned) continue;
      final d = Dates.dateOnly(b.date);
      if (d.isBefore(lo) || d.isAfter(hi)) continue;
      items.add(PlannedItem.fromBooking(b, b.recurringId == null ? null : _ruleById[b.recurringId]));
    }
    for (final r in rules) {
      if (!r.active) continue;
      final handled = _handled[r.id] ?? const <int>{};
      for (final d in Recurrence.between(
        start: r.startDate,
        frequency: r.frequency,
        from: lo,
        to: hi,
        endDate: r.endDate,
        dayOfMonth: r.dayOfMonth,
      )) {
        if (!handled.contains(Dates.dayKey(d))) items.add(PlannedItem.fromRule(r, d));
      }
    }
    items.sort((a, b) => a.date.compareTo(b.date));
    return items;
  }

  /// Offene Posten, deren Datum heute oder früher ist: warten auf Bestätigung
  /// (oder bei automatisch gebuchten Daueraufträgen auf den nächsten Lauf).
  List<PlannedItem> get dueItems => pendingBetween(_earliestPendingStart(), today);

  /// Kommende Posten der nächsten [days] Tage (ab morgen).
  List<PlannedItem> upcoming(int days) =>
      pendingBetween(today.add(const Duration(days: 1)), DateTime(today.year, today.month, today.day + days));

  /// Fällige Termine automatisch zu buchender Daueraufträge (für den Abgleich
  /// beim App-Start).
  List<PlannedItem> get autoBookDue =>
      dueItems.where((p) => p.isVirtual && p.rule != null && p.rule!.autoBook).toList();

  DateTime _earliestPendingStart() {
    DateTime earliest = today;
    for (final b in bookings) {
      if (b.status == BookingStatus.planned && b.date.isBefore(earliest)) earliest = Dates.dateOnly(b.date);
    }
    for (final r in rules) {
      if (r.active && r.startDate.isBefore(earliest)) earliest = Dates.dateOnly(r.startDate);
    }
    return earliest;
  }

  /// Wirkung eines offenen Postens auf das verfügbare Guthaben.
  int availableDelta(PlannedItem p) {
    switch (p.type) {
      case BookingType.expense:
        return isSpendable(p.accountId) ? -p.amount : 0;
      case BookingType.income:
        return isSpendable(p.accountId) ? p.amount : 0;
      case BookingType.transfer:
        var d = 0;
        if (isSpendable(p.accountId)) d -= p.amount;
        if (p.toAccountId != null && isSpendable(p.toAccountId!)) d += p.amount;
        return d;
    }
  }

  /// Was nach allen offenen Posten bis [until] voraussichtlich verfügbar ist.
  /// Überfällige, noch nicht bestätigte Posten zählen mit – sie sind ja noch
  /// nicht vom Konto abgegangen.
  Forecast forecastUntil(DateTime until) {
    final items = pendingBetween(_earliestPendingStart(), until).where((p) => availableDelta(p) != 0).toList();
    return Forecast(
      start: available,
      until: Dates.dateOnly(until),
      items: items,
      deltas: [for (final p in items) availableDelta(p)],
    );
  }

  Forecast get forecastMonthEnd => forecastUntil(YearMonth.of(today).lastDay);

  /// Nächster offener Termin eines Dauerauftrags (ab heute).
  DateTime? nextOccurrence(RecurringRule r) {
    if (!r.active) return null;
    final handled = _handled[r.id] ?? const <int>{};
    var day = today;
    for (var guard = 0; guard < 400; guard++) {
      final d = Recurrence.nextOnOrAfter(
        start: r.startDate,
        frequency: r.frequency,
        day: day,
        endDate: r.endDate,
        dayOfMonth: r.dayOfMonth,
      );
      if (d == null) return null;
      if (!handled.contains(Dates.dayKey(d))) return d;
      day = d.add(const Duration(days: 1));
    }
    return null;
  }

  /// Letzter Termin eines Dauerauftrags, zu dem es schon eine Buchung gibt.
  DateTime? lastHandledOccurrence(int ruleId) {
    final keys = _handled[ruleId];
    if (keys == null || keys.isEmpty) return null;
    return Dates.fromDayKey(keys.max);
  }

  // ---------------------------------------------------------------------------
  // Hilfen
  // ---------------------------------------------------------------------------

  static int _newestFirst(Booking a, Booking b) {
    final c = b.date.compareTo(a.date);
    return c != 0 ? c : b.id.compareTo(a.id);
  }
}
