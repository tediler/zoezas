import 'package:drift/drift.dart';

import '../core/db/database.dart';
import '../core/format/dates.dart';
import '../domain/enums.dart';
import '../domain/ledger.dart';

// Alle Schreibzugriffe laufen über diese Repositories. Screens lesen über
// Provider (lib/data/providers.dart) und rufen hier nur Methoden auf.

class AccountsRepository {
  AccountsRepository(this.db);
  final AppDatabase db;

  Stream<List<Account>> watchAll() => (db.select(
    db.accounts,
  )..orderBy([(a) => OrderingTerm(expression: a.sortOrder), (a) => OrderingTerm(expression: a.id)])).watch();

  Future<int> add({
    required String name,
    required AccountType type,
    required String emoji,
    required int color,
    required int openingBalance,
    bool? includeInAvailable,
    DateTime? openingDate,
  }) async {
    final count = await db.accounts.count().getSingle();
    return db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            name: name,
            type: type,
            emoji: Value(emoji),
            color: color,
            openingBalance: Value(openingBalance),
            openingDate: openingDate ?? DateTime.now(),
            includeInAvailable: Value(includeInAvailable ?? type.defaultIncludeInAvailable),
            sortOrder: Value(count),
          ),
        );
  }

  Future<void> updateAccount(Account a) => db.update(db.accounts).replace(a);

  /// Setzt den aktuellen Kontostand auf [newBalance], ohne eine Einnahme oder
  /// Ausgabe zu erzeugen: Der Startsaldo wird um die Differenz verschoben.
  Future<void> correctBalance(Account a, {required int currentBalance, required int newBalance}) =>
      (db.update(db.accounts)..where((t) => t.id.equals(a.id))).write(
        AccountsCompanion(openingBalance: Value(a.openingBalance + newBalance - currentBalance)),
      );

  Future<bool> isUsed(int accountId) async {
    final b =
        await (db.select(db.bookings)
              ..where((t) => t.accountId.equals(accountId) | t.toAccountId.equals(accountId))
              ..limit(1))
            .get();
    if (b.isNotEmpty) return true;
    final r =
        await (db.select(db.recurringRules)
              ..where((t) => t.accountId.equals(accountId) | t.toAccountId.equals(accountId))
              ..limit(1))
            .get();
    return r.isNotEmpty;
  }

  Future<void> delete(int id) => (db.delete(db.accounts)..where((t) => t.id.equals(id))).go();

  Future<void> reorder(List<Account> ordered) => db.batch((b) {
    for (var i = 0; i < ordered.length; i++) {
      b.update(db.accounts, AccountsCompanion(sortOrder: Value(i)), where: (t) => t.id.equals(ordered[i].id));
    }
  });
}

class CategoriesRepository {
  CategoriesRepository(this.db);
  final AppDatabase db;

  Stream<List<Category>> watchAll() => (db.select(
    db.categories,
  )..orderBy([(c) => OrderingTerm(expression: c.sortOrder), (c) => OrderingTerm(expression: c.id)])).watch();

  Future<int> add({required String name, required String emoji, required int color, required CategoryKind kind}) async {
    final count = await db.categories.count().getSingle();
    return db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(name: name, emoji: emoji, color: color, kind: kind, sortOrder: Value(count)),
        );
  }

  Future<void> updateCategory(Category c) => db.update(db.categories).replace(c);

  Future<bool> isUsed(int id) async {
    final b =
        await (db.select(db.bookings)
              ..where((t) => t.categoryId.equals(id))
              ..limit(1))
            .get();
    final r =
        await (db.select(db.recurringRules)
              ..where((t) => t.categoryId.equals(id))
              ..limit(1))
            .get();
    return b.isNotEmpty || r.isNotEmpty;
  }

  /// Benutzte Kategorien werden nur archiviert, damit die Statistik stimmt.
  Future<void> removeOrArchive(Category c) async {
    if (await isUsed(c.id)) {
      await updateCategory(c.copyWith(archived: true));
    } else {
      await (db.delete(db.categories)..where((t) => t.id.equals(c.id))).go();
    }
  }

  Future<void> reorder(List<Category> ordered) => db.batch((b) {
    for (var i = 0; i < ordered.length; i++) {
      b.update(db.categories, CategoriesCompanion(sortOrder: Value(i)), where: (t) => t.id.equals(ordered[i].id));
    }
  });
}

class BookingsRepository {
  BookingsRepository(this.db);
  final AppDatabase db;

  Stream<List<Booking>> watchAll() => db.select(db.bookings).watch();

  Future<Booking> byId(int id) => (db.select(db.bookings)..where((t) => t.id.equals(id))).getSingle();

  Future<int> add({
    required BookingType type,
    required BookingStatus status,
    required int amount,
    required int accountId,
    int? toAccountId,
    int? categoryId,
    required String title,
    String? note,
    required DateTime date,
    int? recurringId,
    DateTime? occurrenceDate,
  }) {
    assert(amount > 0);
    assert(type != BookingType.transfer || (toAccountId != null && toAccountId != accountId));
    return db
        .into(db.bookings)
        .insert(
          BookingsCompanion.insert(
            type: type,
            status: status,
            amount: amount,
            accountId: accountId,
            toAccountId: Value(type == BookingType.transfer ? toAccountId : null),
            categoryId: Value(type == BookingType.transfer ? null : categoryId),
            title: title,
            note: Value(note),
            date: date,
            recurringId: Value(recurringId),
            occurrenceDate: Value(occurrenceDate == null ? null : Dates.dateOnly(occurrenceDate)),
          ),
        );
  }

  Future<void> updateBooking(Booking b) => db
      .update(db.bookings)
      .replace(
        b.copyWith(
          toAccountId: Value(b.type == BookingType.transfer ? b.toAccountId : null),
          categoryId: Value(b.type == BookingType.transfer ? null : b.categoryId),
        ),
      );

  Future<void> delete(int id) => (db.delete(db.bookings)..where((t) => t.id.equals(id))).go();

  /// Geplante Buchung wird gebucht. Lag der Termin vor dem Startdatum des
  /// Kontos, wird auf heute gebucht – sonst würde sie den Kontostand nicht
  /// verändern, obwohl das Geld erst jetzt fließt.
  Future<void> confirmPlanned(Booking b, {required Account account, DateTime? now}) {
    final today = now ?? DateTime.now();
    var date = b.date.isAfter(today) ? today : b.date;
    if (Dates.dateOnly(date).isBefore(Dates.dateOnly(account.openingDate))) date = today;
    return (db.update(db.bookings)..where((t) => t.id.equals(b.id))).write(
      BookingsCompanion(status: const Value(BookingStatus.booked), date: Value(date)),
    );
  }

  /// Termin eines Dauerauftrags bestätigen (optional mit anderem Betrag).
  Future<void> confirmOccurrence(PlannedItem p, {int? amount, required Account account, DateTime? now}) async {
    final today = now ?? DateTime.now();
    if (p.booking != null) {
      final b = amount == null ? p.booking! : p.booking!.copyWith(amount: amount);
      if (amount != null) await updateBooking(b);
      return confirmPlanned(b, account: account, now: today);
    }
    var date = p.date.isAfter(today) ? today : p.date;
    if (Dates.dateOnly(date).isBefore(Dates.dateOnly(account.openingDate))) date = today;
    await db
        .into(db.bookings)
        .insert(
          _fromRule(p.rule!, p.occurrenceDate!, BookingStatus.booked, date: date, amount: amount),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> skipOccurrence(PlannedItem p) async {
    if (p.booking != null) {
      await (db.update(
        db.bookings,
      )..where((t) => t.id.equals(p.booking!.id))).write(const BookingsCompanion(status: Value(BookingStatus.skipped)));
      return;
    }
    await db
        .into(db.bookings)
        .insert(_fromRule(p.rule!, p.occurrenceDate!, BookingStatus.skipped), mode: InsertMode.insertOrIgnore);
  }

  /// Einen berechneten Termin in eine bearbeitbare geplante Buchung umwandeln.
  Future<int> materializeAsPlanned(PlannedItem p) =>
      db.into(db.bookings).insert(_fromRule(p.rule!, p.occurrenceDate!, BookingStatus.planned));

  /// Fällige Termine automatisch gebuchter Daueraufträge eintragen. Dank des
  /// eindeutigen Schlüssels (Regel, Termin) ist das beliebig oft wiederholbar.
  Future<int> autoBook(List<PlannedItem> due) async {
    if (due.isEmpty) return 0;
    await db.batch((b) {
      for (final p in due) {
        b.insert(
          db.bookings,
          _fromRule(p.rule!, p.occurrenceDate!, BookingStatus.booked),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
    return due.length;
  }

  BookingsCompanion _fromRule(
    RecurringRule r,
    DateTime occurrence,
    BookingStatus status, {
    DateTime? date,
    int? amount,
  }) {
    final d = date ?? DateTime(occurrence.year, occurrence.month, occurrence.day, 8);
    return BookingsCompanion.insert(
      type: r.type,
      status: status,
      amount: amount ?? r.amount,
      accountId: r.accountId,
      toAccountId: Value(r.type == BookingType.transfer ? r.toAccountId : null),
      categoryId: Value(r.type == BookingType.transfer ? null : r.categoryId),
      title: r.title,
      note: Value(r.note),
      date: d,
      recurringId: Value(r.id),
      occurrenceDate: Value(Dates.dateOnly(occurrence)),
    );
  }

  /// Zuletzt benutzte Titel mit Kategorie und Konto (für Vorschläge).
  Future<List<Booking>> recentDistinctTitles({required BookingType type, int limit = 40}) async {
    final rows =
        await (db.select(db.bookings)
              ..where((t) => t.type.equalsValue(type) & t.status.equalsValue(BookingStatus.booked))
              ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)])
              ..limit(400))
            .get();
    final seen = <String>{};
    final result = <Booking>[];
    for (final r in rows) {
      if (seen.add(r.title.toLowerCase())) result.add(r);
      if (result.length >= limit) break;
    }
    return result;
  }
}

class RecurringRepository {
  RecurringRepository(this.db);
  final AppDatabase db;

  Stream<List<RecurringRule>> watchAll() =>
      (db.select(db.recurringRules)..orderBy([(r) => OrderingTerm(expression: r.startDate)])).watch();

  Future<int> add({
    required BookingType type,
    required int amount,
    required int accountId,
    int? toAccountId,
    int? categoryId,
    required String title,
    String? note,
    required Frequency frequency,
    required DateTime startDate,
    DateTime? endDate,
    int? dayOfMonth,
    bool autoBook = true,
  }) => db
      .into(db.recurringRules)
      .insert(
        RecurringRulesCompanion.insert(
          type: type,
          amount: amount,
          accountId: accountId,
          toAccountId: Value(type == BookingType.transfer ? toAccountId : null),
          categoryId: Value(type == BookingType.transfer ? null : categoryId),
          title: title,
          note: Value(note),
          frequency: frequency,
          startDate: Dates.dateOnly(startDate),
          endDate: Value(endDate == null ? null : Dates.dateOnly(endDate)),
          dayOfMonth: Value(dayOfMonth),
          autoBook: Value(autoBook),
        ),
      );

  /// Änderungen gelten nur für künftige Termine. Wurde der Rhythmus oder der
  /// nächste Termin geändert, beginnt die Reihe neu ab [nextDate] – schon
  /// erledigte Termine bleiben unberührt, es entstehen keine Doppelbuchungen.
  Future<void> updateRule(RecurringRule r, {DateTime? nextDate}) async {
    var updated = r.copyWith(
      toAccountId: Value(r.type == BookingType.transfer ? r.toAccountId : null),
      categoryId: Value(r.type == BookingType.transfer ? null : r.categoryId),
    );
    if (nextDate != null) updated = updated.copyWith(startDate: Dates.dateOnly(nextDate));
    await db.update(db.recurringRules).replace(updated);
  }

  Future<void> setActive(RecurringRule r, bool active) => (db.update(
    db.recurringRules,
  )..where((t) => t.id.equals(r.id))).write(RecurringRulesCompanion(active: Value(active)));

  /// Löscht die Regel. Gebuchte Termine bleiben als normale Buchungen erhalten,
  /// geplante und übersprungene verschwinden mit der Regel.
  Future<void> delete(RecurringRule r) => db.transaction(() async {
    await (db.delete(
      db.bookings,
    )..where((t) => t.recurringId.equals(r.id) & t.status.equalsValue(BookingStatus.booked).not())).go();
    await (db.update(db.bookings)..where((t) => t.recurringId.equals(r.id))).write(
      const BookingsCompanion(recurringId: Value(null), occurrenceDate: Value(null)),
    );
    await (db.delete(db.recurringRules)..where((t) => t.id.equals(r.id))).go();
  });
}

class BudgetsRepository {
  BudgetsRepository(this.db);
  final AppDatabase db;

  Stream<List<Budget>> watchAll() => db.select(db.budgets).watch();

  /// Budget ab Monat [from] setzen (0 = ab dann kein Budget). Ein Eintrag für
  /// denselben Monat wird ersetzt, spätere Einträge bleiben bestehen.
  Future<void> setBudget({required int? categoryId, required int amount, required YearMonth from}) =>
      db.transaction(() async {
        await (db.delete(db.budgets)..where(
              (t) =>
                  (categoryId == null ? t.categoryId.isNull() : t.categoryId.equals(categoryId)) &
                  t.validFrom.equals(from.key),
            ))
            .go();
        await db
            .into(db.budgets)
            .insert(BudgetsCompanion.insert(categoryId: Value(categoryId), amount: amount, validFrom: from.key));
      });
}

class GoalsRepository {
  GoalsRepository(this.db);
  final AppDatabase db;

  Stream<List<SavingsGoal>> watchGoals() => (db.select(
    db.savingsGoals,
  )..orderBy([(g) => OrderingTerm(expression: g.sortOrder), (g) => OrderingTerm(expression: g.id)])).watch();

  Stream<List<GoalContribution>> watchContributions() => (db.select(
    db.goalContributions,
  )..orderBy([(c) => OrderingTerm(expression: c.date, mode: OrderingMode.desc)])).watch();

  Future<int> addGoal({
    required String name,
    required String emoji,
    required int color,
    required int target,
    DateTime? targetDate,
    String? note,
  }) async {
    final count = await db.savingsGoals.count().getSingle();
    return db
        .into(db.savingsGoals)
        .insert(
          SavingsGoalsCompanion.insert(
            name: name,
            emoji: emoji,
            color: color,
            targetAmount: target,
            targetDate: Value(targetDate),
            note: Value(note),
            sortOrder: Value(count),
          ),
        );
  }

  Future<void> updateGoal(SavingsGoal g) => db.update(db.savingsGoals).replace(g);

  Future<void> deleteGoal(int id) => (db.delete(db.savingsGoals)..where((t) => t.id.equals(id))).go();

  Future<void> setCompleted(SavingsGoal g, bool completed) =>
      (db.update(db.savingsGoals)..where((t) => t.id.equals(g.id))).write(
        SavingsGoalsCompanion(completedAt: Value(completed ? DateTime.now() : null)),
      );

  /// Geld für ein Ziel zurücklegen ([amount] > 0) oder entnehmen (< 0).
  /// Mit [moveFrom] und [moveTo] wird zusätzlich eine Umbuchung erzeugt
  /// (z. B. Giro → Sparkonto); das Geld liegt dann auf [moveTo].
  Future<void> contribute({
    required SavingsGoal goal,
    required int amount,
    required int? heldInAccountId,
    int? moveFrom,
    int? moveTo,
    String? note,
    DateTime? date,
  }) => db.transaction(() async {
    final when = date ?? DateTime.now();
    int? bookingId;
    if (moveFrom != null && moveTo != null && moveFrom != moveTo) {
      final positive = amount > 0;
      bookingId = await db
          .into(db.bookings)
          .insert(
            BookingsCompanion.insert(
              type: BookingType.transfer,
              status: BookingStatus.booked,
              amount: amount.abs(),
              accountId: positive ? moveFrom : moveTo,
              toAccountId: Value(positive ? moveTo : moveFrom),
              title: positive ? 'Für ${goal.name} ${goal.emoji}' : 'Aus ${goal.name} ${goal.emoji}',
              date: when,
            ),
          );
    }
    await db
        .into(db.goalContributions)
        .insert(
          GoalContributionsCompanion.insert(
            goalId: goal.id,
            amount: amount,
            date: when,
            note: Value(note),
            heldInAccountId: Value(heldInAccountId),
            bookingId: Value(bookingId),
          ),
        );
  });

  Future<void> deleteContribution(GoalContribution c) => db.transaction(() async {
    await (db.delete(db.goalContributions)..where((t) => t.id.equals(c.id))).go();
    if (c.bookingId != null) await (db.delete(db.bookings)..where((t) => t.id.equals(c.bookingId!))).go();
  });
}

class DebtsRepository {
  DebtsRepository(this.db);
  final AppDatabase db;

  Stream<List<Debt>> watchDebts() =>
      (db.select(db.debts)..orderBy([(d) => OrderingTerm(expression: d.createdAt, mode: OrderingMode.desc)])).watch();

  Stream<List<DebtPayment>> watchPayments() =>
      (db.select(db.debtPayments)..orderBy([(p) => OrderingTerm(expression: p.date, mode: OrderingMode.desc)])).watch();

  Future<int> add({
    required String person,
    required DebtDirection direction,
    required int amount,
    DateTime? dueDate,
    String? note,
  }) => db
      .into(db.debts)
      .insert(
        DebtsCompanion.insert(
          person: person,
          direction: direction,
          amount: amount,
          dueDate: Value(dueDate),
          note: Value(note),
        ),
      );

  Future<void> updateDebt(Debt d) => db.update(db.debts).replace(d);

  Future<void> setClosed(Debt d, bool closed) => (db.update(
    db.debts,
  )..where((t) => t.id.equals(d.id))).write(DebtsCompanion(closedAt: Value(closed ? DateTime.now() : null)));

  /// Löscht die Schuld samt Zahlungen. Verknüpfte Buchungen bleiben erhalten –
  /// das Geld ist ja tatsächlich geflossen.
  Future<void> delete(Debt d) => (db.delete(db.debts)..where((t) => t.id.equals(d.id))).go();

  /// Zahlung erfassen. Mit [accountId] entsteht zugleich eine echte Buchung:
  /// „Ich schulde“ → Ausgabe, „Mir wird geschuldet“ → Einnahme.
  Future<void> addPayment({
    required Debt debt,
    required int amount,
    required DateTime date,
    String? note,
    int? accountId,
    int? categoryId,
  }) => db.transaction(() async {
    int? bookingId;
    if (accountId != null) {
      final iOwe = debt.direction == DebtDirection.iOwe;
      bookingId = await db
          .into(db.bookings)
          .insert(
            BookingsCompanion.insert(
              type: iOwe ? BookingType.expense : BookingType.income,
              status: BookingStatus.booked,
              amount: amount,
              accountId: accountId,
              categoryId: Value(categoryId),
              title: iOwe ? 'An ${debt.person} zurück' : 'Von ${debt.person} zurück',
              note: Value(note),
              date: date,
            ),
          );
    }
    await db
        .into(db.debtPayments)
        .insert(
          DebtPaymentsCompanion.insert(
            debtId: debt.id,
            amount: amount,
            date: date,
            note: Value(note),
            bookingId: Value(bookingId),
          ),
        );
  });

  Future<void> deletePayment(DebtPayment p) => db.transaction(() async {
    await (db.delete(db.debtPayments)..where((t) => t.id.equals(p.id))).go();
    if (p.bookingId != null) await (db.delete(db.bookings)..where((t) => t.id.equals(p.bookingId!))).go();
  });
}

/// Profil und Einstellungen als Schlüssel-Wert-Paare.
class SettingsRepository {
  SettingsRepository(this.db);
  final AppDatabase db;

  Stream<Map<String, String>> watchAll() =>
      db.select(db.settings).watch().map((rows) => {for (final r in rows) r.key: r.value});

  Future<void> set(String key, String value) =>
      db.into(db.settings).insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

  Future<void> setAll(Map<String, String> values) => db.batch((b) {
    for (final e in values.entries) {
      b.insert(
        db.settings,
        SettingsCompanion.insert(key: e.key, value: e.value),
        onConflict: DoUpdate((_) => SettingsCompanion(value: Value(e.value))),
      );
    }
  });

  Stream<Set<int>> watchActivityDays() =>
      db.select(db.activityDays).watch().map((rows) => rows.map((r) => r.day).toSet());

  Future<void> markActive(DateTime day) => db
      .into(db.activityDays)
      .insert(ActivityDaysCompanion.insert(day: Value(Dates.dayKey(day))), mode: InsertMode.insertOrIgnore);
}
