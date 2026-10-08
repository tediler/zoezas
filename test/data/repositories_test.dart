import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoezas/core/db/database.dart';
import 'package:zoezas/core/format/dates.dart';
import 'package:zoezas/data/backup.dart';
import 'package:zoezas/data/repositories.dart';
import 'package:zoezas/domain/enums.dart';
import 'package:zoezas/domain/ledger.dart';

// Tests gegen eine echte SQLite-Datenbank im Speicher.

void main() {
  late AppDatabase db;
  late AccountsRepository accounts;
  late BookingsRepository bookings;
  late RecurringRepository rules;
  late GoalsRepository goals;
  late DebtsRepository debts;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    accounts = AccountsRepository(db);
    bookings = BookingsRepository(db);
    rules = RecurringRepository(db);
    goals = GoalsRepository(db);
    debts = DebtsRepository(db);
  });

  tearDown(() => db.close());

  Future<Ledger> ledger(DateTime now) async => Ledger(
    accounts: await db.select(db.accounts).get(),
    bookings: await db.select(db.bookings).get(),
    rules: await db.select(db.recurringRules).get(),
    goals: await db.select(db.savingsGoals).get(),
    contributions: await db.select(db.goalContributions).get(),
    now: now,
  );

  test('Standard-Kategorien werden angelegt', () async {
    final cats = await db.select(db.categories).get();
    expect(cats.where((c) => c.builtInKey == 'food'), hasLength(1));
    expect(cats.where((c) => c.kind == CategoryKind.income), isNotEmpty);
  });

  test('Automatisches Buchen von Daueraufträgen ist idempotent', () async {
    final giro = await accounts.add(
      name: 'Giro',
      type: AccountType.checking,
      emoji: '💳',
      color: 0,
      openingBalance: 100000,
      openingDate: DateTime(2026, 9, 1),
    );
    await rules.add(
      type: BookingType.expense,
      amount: 1299,
      accountId: giro,
      title: 'Streaming',
      frequency: Frequency.monthly,
      startDate: DateTime(2026, 9, 10),
    );
    final now = DateTime(2026, 10, 15);
    final due = (await ledger(now)).autoBookDue;
    expect(due, hasLength(2));

    // Zweimal (z. B. durch zwei Listener) – es darf trotzdem nur zwei Buchungen geben.
    await bookings.autoBook(due);
    await bookings.autoBook(due);
    final all = await db.select(db.bookings).get();
    expect(all, hasLength(2));
    final l = await ledger(now);
    expect(l.autoBookDue, isEmpty);
    expect(l.balanceOf(giro), 100000 - 2 * 1299);
  });

  test('Übersprungener Termin taucht nicht mehr auf, nächster schon', () async {
    final giro = await accounts.add(name: 'Giro', type: AccountType.checking, emoji: '💳', color: 0, openingBalance: 0);
    await rules.add(
      type: BookingType.expense,
      amount: 2990,
      accountId: giro,
      title: 'Fitness',
      frequency: Frequency.monthly,
      startDate: DateTime(2026, 10, 1),
      autoBook: false,
    );
    final now = DateTime(2026, 10, 5);
    final item = (await ledger(now)).dueItems.single;
    await bookings.skipOccurrence(item);
    final l = await ledger(now);
    expect(l.dueItems, isEmpty);
    expect(l.nextOccurrence(l.rules.single), DateTime(2026, 11, 1));
  });

  test('Bestätigen einer geplanten Buchung verändert den Kontostand genau einmal', () async {
    final giro = await accounts.add(
      name: 'Giro',
      type: AccountType.checking,
      emoji: '💳',
      color: 0,
      openingBalance: 50000,
    );
    final id = await bookings.add(
      type: BookingType.expense,
      status: BookingStatus.planned,
      amount: 4500,
      accountId: giro,
      title: 'Geschenk',
      date: DateTime.now(),
    );
    expect((await ledger(DateTime.now())).balanceOf(giro), 50000);
    final acc = (await db.select(db.accounts).get()).single;
    await bookings.confirmPlanned(await bookings.byId(id), account: acc);
    final l = await ledger(DateTime.now());
    expect(l.balanceOf(giro), 45500);
    expect(l.dueItems, isEmpty);
  });

  test('Sparziel mit Umbuchung und Schuldzahlung mit Buchung', () async {
    final now = DateTime.now();
    final giro = await accounts.add(
      name: 'Giro',
      type: AccountType.checking,
      emoji: '💳',
      color: 0,
      openingBalance: 100000,
    );
    final spar = await accounts.add(name: 'Spar', type: AccountType.savings, emoji: '🐷', color: 0, openingBalance: 0);
    await goals.addGoal(name: 'Urlaub', emoji: '🌴', color: 0, target: 150000);
    final goal = (await db.select(db.savingsGoals).get()).single;
    await goals.contribute(goal: goal, amount: 20000, heldInAccountId: spar, moveFrom: giro, moveTo: spar);

    final debtId = await debts.add(person: 'Lisa', direction: DebtDirection.iOwe, amount: 5000);
    var l = await ledger(now);
    expect(l.available, 80000, reason: 'Offene Schuld zählt nicht als Ausgabe');
    final debt = (await db.select(db.debts).get()).single;
    await debts.addPayment(debt: debt, amount: 5000, date: now, accountId: giro);

    l = await ledger(now);
    expect(l.balanceOf(giro), 75000);
    expect(l.balanceOf(spar), 20000);
    expect(l.goalProgress(goal).saved, 20000);
    final month = l.month(YearMonth.of(now));
    expect(month.expenses, 5000, reason: 'Nur die Schuldzahlung ist eine Ausgabe, die Umbuchung nicht');
    expect(debtId, isPositive);
  });

  test('Export und Import sind verlustfrei', () async {
    final giro = await accounts.add(
      name: 'Giro',
      type: AccountType.checking,
      emoji: '💳',
      color: 7,
      openingBalance: 12345,
    );
    await bookings.add(
      type: BookingType.expense,
      status: BookingStatus.booked,
      amount: 999,
      accountId: giro,
      title: 'Eis',
      note: 'mit Streuseln',
      date: DateTime(2026, 10, 3, 15, 30),
    );
    await rules.add(
      type: BookingType.income,
      amount: 180000,
      accountId: giro,
      title: 'Gehalt',
      frequency: Frequency.monthly,
      startDate: DateTime(2026, 11, 30),
      dayOfMonth: 31,
    );
    final service = BackupService(db);
    final json = await service.exportJson();
    final before = await db.select(db.bookings).get();

    await service.resetAll();
    expect(await db.select(db.bookings).get(), isEmpty);

    await service.importJson(json);
    final after = await db.select(db.bookings).get();
    expect(after, before);
    expect((await db.select(db.recurringRules).get()).single.dayOfMonth, 31);
    expect(after.single.date, DateTime(2026, 10, 3, 15, 30));
  });

  test('Fremde Dateien werden abgelehnt', () {
    final service = BackupService(db);
    expect(() => service.inspect('{"hello": 1}'), throwsA(isA<BackupFormatException>()));
    expect(() => service.inspect('kein json'), throwsA(isA<BackupFormatException>()));
  });
}
