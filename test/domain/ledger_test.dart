import 'package:flutter_test/flutter_test.dart';
import 'package:zoezas/core/db/database.dart';
import 'package:zoezas/core/format/dates.dart';
import 'package:zoezas/domain/enums.dart';
import 'package:zoezas/domain/ledger.dart';

import '../helpers/fixtures.dart';

void main() {
  final now = DateTime(2026, 10, 15, 14);
  final oct = YearMonth(2026, 10);

  group('Kontostand und verfügbares Guthaben', () {
    test('Ausgabe zieht sofort ab, Einnahme erhöht (1.800 € − 50 € = 1.750 €)', () {
      final giro = account(opening: 0, openingDate: DateTime(2026, 10, 1));
      final ledger = Ledger(
        accounts: [giro],
        bookings: [
          income(180000, giro.id, DateTime(2026, 10, 1, 9)),
          expense(5000, giro.id, DateTime(2026, 10, 3, 12)),
        ],
        rules: const [],
        now: now,
      );
      expect(ledger.balanceOf(giro.id), 175000);
      expect(ledger.available, 175000);
      expect(ledger.month(oct).saved, 175000);
    });

    test('Geplante Ausgaben verändern den Kontostand nicht, aber die Prognose', () {
      final giro = account(opening: 100000);
      final ledger = Ledger(
        accounts: [giro],
        bookings: [expense(38000, giro.id, DateTime(2026, 10, 20), status: BookingStatus.planned)],
        rules: const [],
        now: now,
      );
      expect(ledger.available, 100000);
      final f = ledger.forecastMonthEnd;
      expect(f.outgoing, 38000);
      expect(f.end, 62000);
    });

    test('Umbuchung ändert die Verteilung, aber weder Einnahmen noch Ausgaben', () {
      final giro = account(opening: 200000);
      final spar = account(name: 'Sparkonto', type: AccountType.savings, opening: 50000);
      final ledger = Ledger(
        accounts: [giro, spar],
        bookings: [transfer(30000, giro.id, spar.id, DateTime(2026, 10, 5))],
        rules: const [],
        now: now,
      );
      expect(ledger.balanceOf(giro.id), 170000);
      expect(ledger.balanceOf(spar.id), 80000);
      expect(ledger.totalBalance, 250000);
      expect(ledger.available, 170000, reason: 'Sparkonto zählt nicht zum Verfügbaren');
      final m = ledger.month(oct);
      expect(m.income, 0);
      expect(m.expenses, 0);
    });

    test('Buchungen vor dem Startdatum zählen für die Statistik, nicht für den Kontostand', () {
      // Gehalt kam am 1., App am 7. eingerichtet mit aktuellem Stand 1.500 €.
      final giro = account(opening: 150000, openingDate: DateTime(2026, 10, 7, 10));
      final ledger = Ledger(
        accounts: [giro],
        bookings: [
          income(180000, giro.id, DateTime(2026, 10, 1, 8)),
          expense(1200, giro.id, DateTime(2026, 10, 7, 18)),
        ],
        rules: const [],
        now: now,
      );
      expect(ledger.balanceOf(giro.id), 148800);
      expect(ledger.month(oct).income, 180000);
      expect(ledger.month(oct).expenses, 1200);
    });

    test('Sparziel-Reservierung auf dem Girokonto senkt das Verfügbare, nicht den Kontostand', () {
      final giro = account(opening: 175000);
      final spar = account(type: AccountType.savings, opening: 300000);
      final urlaub = goal(target: 150000);
      final ledger = Ledger(
        accounts: [giro, spar],
        bookings: const [],
        rules: const [],
        goals: [urlaub],
        contributions: [
          contribution(urlaub.id, 80000, heldIn: spar.id),
          contribution(urlaub.id, 10000, heldIn: giro.id),
        ],
        now: now,
      );
      expect(ledger.balanceOf(giro.id), 175000);
      expect(ledger.totalBalance, 475000);
      expect(ledger.available, 165000);
      expect(ledger.goalProgress(urlaub).saved, 90000);
      expect(ledger.goalProgress(urlaub).remaining, 60000);
      expect(ledger.month(oct).expenses, 0);
    });

    test('Abgeschlossene Ziele reservieren nichts mehr', () {
      final giro = account(opening: 100000);
      final handy = goal(target: 50000, completedAt: DateTime(2026, 10, 10));
      final ledger = Ledger(
        accounts: [giro],
        bookings: const [],
        rules: const [],
        goals: [handy],
        contributions: [contribution(handy.id, 50000, heldIn: giro.id)],
        now: now,
      );
      expect(ledger.available, 100000);
    });
  });

  group('Daueraufträge', () {
    test('Künftige Termine erscheinen in der Planung, nicht im Kontostand', () {
      final giro = account(opening: 200000);
      final miete = rule(amount: 79000, accountId: giro.id, start: DateTime(2026, 11, 1));
      final ledger = Ledger(accounts: [giro], bookings: const [], rules: [miete], now: now);
      expect(ledger.available, 200000);
      final nov = ledger.month(YearMonth(2026, 11));
      expect(nov.plannedExpenses, 79000);
      expect(nov.expenses, 0);
      expect(ledger.nextOccurrence(miete), DateTime(2026, 11, 1));
    });

    test('Ein gebuchter Termin wird nicht zusätzlich als geplant gezählt', () {
      final giro = account(opening: 200000);
      final abo = rule(amount: 1299, accountId: giro.id, start: DateTime(2026, 9, 10));
      final ledger = Ledger(
        accounts: [giro],
        bookings: [
          expense(1299, giro.id, DateTime(2026, 9, 10), recurringId: abo.id, occurrenceDate: DateTime(2026, 9, 10)),
          expense(1299, giro.id, DateTime(2026, 10, 10), recurringId: abo.id, occurrenceDate: DateTime(2026, 10, 10)),
        ],
        rules: [abo],
        now: now,
      );
      expect(ledger.month(oct).expenses, 1299);
      expect(ledger.month(oct).plannedExpenses, 0);
      expect(ledger.dueItems, isEmpty);
      expect(ledger.nextOccurrence(abo), DateTime(2026, 11, 10));
    });

    test('Übersprungene Termine zählen nirgends', () {
      final giro = account(opening: 100000);
      final gym = rule(amount: 2990, accountId: giro.id, start: DateTime(2026, 10, 1), autoBook: false);
      final ledger = Ledger(
        accounts: [giro],
        bookings: [
          expense(
            2990,
            giro.id,
            DateTime(2026, 10, 1),
            status: BookingStatus.skipped,
            recurringId: gym.id,
            occurrenceDate: DateTime(2026, 10, 1),
          ),
        ],
        rules: [gym],
        now: now,
      );
      expect(ledger.available, 100000);
      expect(ledger.month(oct).expenses, 0);
      expect(ledger.month(oct).plannedExpenses, 0);
      expect(ledger.dueItems, isEmpty);
    });

    test('Fällige, nicht bestätigte Termine stehen in dueItems und in der Prognose', () {
      final giro = account(opening: 100000);
      final gym = rule(amount: 2990, accountId: giro.id, start: DateTime(2026, 10, 1), autoBook: false);
      final ledger = Ledger(accounts: [giro], bookings: const [], rules: [gym], now: now);
      expect(ledger.dueItems.map((p) => p.date), [DateTime(2026, 10, 1)]);
      expect(ledger.forecastMonthEnd.end, 100000 - 2990);
      expect(ledger.autoBookDue, isEmpty);
    });

    test('Wiederkehrende Einnahme auf das Girokonto erhöht die Prognose', () {
      final giro = account(opening: 50000);
      final gehalt = rule(type: BookingType.income, amount: 180000, accountId: giro.id, start: DateTime(2026, 10, 28));
      final ledger = Ledger(accounts: [giro], bookings: const [], rules: [gehalt], now: now);
      expect(ledger.forecastMonthEnd.end, 230000);
      expect(ledger.month(oct).projectedSaved, 180000);
    });

    test('Geplante Umbuchung aufs Sparkonto senkt die Prognose, ist aber keine Ausgabe', () {
      final giro = account(opening: 100000);
      final spar = account(type: AccountType.savings);
      final sparplan = rule(
        type: BookingType.transfer,
        amount: 20000,
        accountId: giro.id,
        toAccountId: spar.id,
        start: DateTime(2026, 10, 30),
      );
      final ledger = Ledger(accounts: [giro, spar], bookings: const [], rules: [sparplan], now: now);
      expect(ledger.forecastMonthEnd.end, 80000);
      expect(ledger.month(oct).plannedExpenses, 0);
    });

    test('Pausierte Regeln erzeugen keine Termine', () {
      final giro = account(opening: 100000);
      final r = rule(amount: 1000, accountId: giro.id, start: DateTime(2026, 10, 20), active: false);
      final ledger = Ledger(accounts: [giro], bookings: const [], rules: [r], now: now);
      expect(ledger.forecastMonthEnd.end, 100000);
    });
  });

  group('Monate', () {
    test('Jeder Monat hat seine eigene Bilanz, das Geld bleibt auf dem Konto', () {
      final giro = account(opening: 0, openingDate: DateTime(2026, 9, 1));
      final ledger = Ledger(
        accounts: [giro],
        bookings: [
          income(180000, giro.id, DateTime(2026, 9, 1)),
          expense(139000, giro.id, DateTime(2026, 9, 12)),
          income(180000, giro.id, DateTime(2026, 10, 1)),
          expense(118000, giro.id, DateTime(2026, 10, 9)),
        ],
        rules: const [],
        now: now,
      );
      expect(ledger.month(YearMonth(2026, 9)).saved, 41000);
      expect(ledger.month(oct).saved, 62000);
      expect(ledger.balanceOf(giro.id), 103000);
      final recent = ledger.recentMonths(oct, 2);
      expect(recent.map((m) => m.saved), [41000, 62000]);
    });

    test('Ausgaben nach Kategorie', () {
      final giro = account(opening: 0);
      final ledger = Ledger(
        accounts: [giro],
        bookings: [
          expense(2000, giro.id, DateTime(2026, 10, 2), categoryId: 1),
          expense(3000, giro.id, DateTime(2026, 10, 3), categoryId: 1),
          expense(1500, giro.id, DateTime(2026, 10, 4), categoryId: 2),
          expense(9999, giro.id, DateTime(2026, 9, 4), categoryId: 2),
        ],
        rules: const [],
        now: now,
      );
      expect(ledger.month(oct).flow.expenseByCategory, {1: 5000, 2: 1500});
    });
  });

  group('Schulden', () {
    test('Restbetrag und Status', () {
      final d = DebtStatus(
        debt: _debt(5000, due: DateTime(2026, 10, 10)),
        payments: [_payment(2000)],
        today: now,
      );
      expect(d.remaining, 3000);
      expect(d.isPartial, isTrue);
      expect(d.isOverdue, isTrue);
      final settled = DebtStatus(debt: _debt(5000), payments: [_payment(5000)], today: now);
      expect(settled.isSettled, isTrue);
    });
  });
}

Debt _debt(int amount, {DateTime? due}) => Debt(
  id: 1,
  person: 'Lisa',
  direction: DebtDirection.iOwe,
  amount: amount,
  dueDate: due,
  note: null,
  createdAt: DateTime(2026, 10, 1),
  closedAt: null,
);

DebtPayment _payment(int amount) =>
    DebtPayment(id: nextId(), debtId: 1, amount: amount, date: DateTime(2026, 10, 5), note: null, bookingId: null);
