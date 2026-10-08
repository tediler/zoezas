import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zoezas/core/format/dates.dart';
import 'package:zoezas/core/format/money.dart';
import 'package:zoezas/domain/budgets.dart';
import 'package:zoezas/domain/enums.dart';
import 'package:zoezas/domain/ledger.dart';
import 'package:zoezas/domain/quick_entry.dart';
import 'package:zoezas/domain/recurrence.dart';
import 'package:zoezas/domain/streak.dart';

import '../helpers/fixtures.dart';

void main() {
  setUpAll(() => initializeDateFormatting('de_DE'));

  group('Recurrence', () {
    test('Monatsende wird geklemmt, aber nicht verschleppt', () {
      final start = DateTime(2026, 1, 31);
      expect(Recurrence.nth(start, Frequency.monthly, 1), DateTime(2026, 2, 28));
      expect(Recurrence.nth(start, Frequency.monthly, 2), DateTime(2026, 3, 31));
      expect(Recurrence.nth(start, Frequency.monthly, 3), DateTime(2026, 4, 30));
    });

    test('Fester Monatstag 31 = immer Monatsende', () {
      final start = Recurrence.firstMonthlyOnOrAfter(DateTime(2026, 11, 5), 31);
      expect(start, DateTime(2026, 11, 30));
      expect(Recurrence.nth(start, Frequency.monthly, 1, dayOfMonth: 31), DateTime(2026, 12, 31));
      expect(Recurrence.nth(start, Frequency.monthly, 3, dayOfMonth: 31), DateTime(2027, 2, 28));
      expect(Recurrence.firstMonthlyOnOrAfter(DateTime(2026, 10, 7), 1), DateTime(2026, 11, 1));
      expect(Recurrence.firstMonthlyOnOrAfter(DateTime(2026, 10, 7), 7), DateTime(2026, 10, 7));
    });

    test('Termine im Zeitraum', () {
      final dates = Recurrence.between(
        start: DateTime(2026, 9, 3),
        frequency: Frequency.weekly,
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 31),
      );
      expect(dates, [
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 8),
        DateTime(2026, 10, 15),
        DateTime(2026, 10, 22),
        DateTime(2026, 10, 29),
      ]);
    });

    test('Enddatum und Start nach Zeitraum', () {
      expect(
        Recurrence.between(
          start: DateTime(2026, 1, 15),
          frequency: Frequency.monthly,
          from: DateTime(2026, 1, 1),
          to: DateTime(2026, 12, 31),
          endDate: DateTime(2026, 3, 20),
        ),
        [DateTime(2026, 1, 15), DateTime(2026, 2, 15), DateTime(2026, 3, 15)],
      );
      expect(
        Recurrence.between(
          start: DateTime(2027, 1, 1),
          frequency: Frequency.yearly,
          from: DateTime(2026, 1, 1),
          to: DateTime(2026, 12, 31),
        ),
        isEmpty,
      );
    });

    test('Nächster Termin', () {
      expect(
        Recurrence.nextOnOrAfter(
          start: DateTime(2025, 2, 28),
          frequency: Frequency.quarterly,
          day: DateTime(2026, 10, 7),
        ),
        DateTime(2026, 11, 28),
      );
    });
  });

  group('Budgets', () {
    final oct = YearMonth(2026, 10);
    test('Gültiges Budget ist der jüngste Eintrag bis zum Monat', () {
      final rows = [budget(1, 20000, 202601), budget(1, 25000, 202610), budget(1, 30000, 202612)];
      expect(BudgetLogic.effectiveLimit(rows, 1, YearMonth(2026, 9)), 20000);
      expect(BudgetLogic.effectiveLimit(rows, 1, oct), 25000);
      expect(BudgetLogic.effectiveLimit(rows, 1, YearMonth(2026, 11)), 25000);
      expect(BudgetLogic.effectiveLimit(rows, 2, oct), isNull);
    });

    test('0 beendet ein Budget ab diesem Monat', () {
      final rows = [budget(null, 150000, 202601), budget(null, 0, 202610)];
      expect(BudgetLogic.effectiveLimit(rows, null, YearMonth(2026, 9)), 150000);
      expect(BudgetLogic.effectiveLimit(rows, null, oct), isNull);
    });

    test('Status: fast aufgebraucht und überschritten', () {
      final essen = category(id: 1);
      final shopping = category(id: 2, name: 'Online Shopping');
      final giro = account(opening: 100000);
      final ledger = Ledger(
        accounts: [giro],
        bookings: [
          expense(21000, giro.id, DateTime(2026, 10, 5), categoryId: 1),
          expense(16000, giro.id, DateTime(2026, 10, 6), categoryId: 2),
        ],
        rules: const [],
        now: DateTime(2026, 10, 15),
      );
      final status = BudgetLogic.statusFor(
        month: oct,
        rows: [budget(1, 25000, 202610), budget(2, 15000, 202610), budget(null, 100000, 202610)],
        summary: ledger.month(oct),
        categories: {1: essen, 2: shopping},
      );
      expect(status.first.isTotal, isTrue);
      expect(status.first.spent, 37000);
      final byCat = {for (final s in status.skip(1)) s.category!.id: s};
      expect(byCat[1]!.level, BudgetLevel.almost);
      expect(byCat[2]!.level, BudgetLevel.over);
      expect(byCat[2]!.remaining, -1000);
    });
  });

  group('Money', () {
    test('Formatieren', () {
      expect(Money.format(175000), '1.750,00 €');
      expect(Money.format(175000, compact: true), '1.750 €');
      expect(Money.format(-5050), '−50,50 €');
      expect(Money.wholePart(175099), '1.750');
      expect(Money.centsPart(175005), ',05');
    });

    test('Einlesen', () {
      expect(Money.parse('12,5'), 1250);
      expect(Money.parse('1.234,56'), 123456);
      expect(Money.parse('1,234.56'), 123456);
      expect(Money.parse('12.50'), 1250);
      expect(Money.parse('1.234'), 123400);
      expect(Money.parse('3 €'), 300);
      expect(Money.parse('abc'), isNull);
      expect(Money.parse('1,234'), isNull);
    });
  });

  group('Schnelleingabe', () {
    test('Betrag hinten oder vorne', () {
      final a = QuickEntryParser.parse('Eis 3,50');
      expect(a.title, 'Eis');
      expect(a.amount, 350);
      final b = QuickEntryParser.parse('12 € Kino');
      expect(b.title, 'Kino');
      expect(b.amount, 1200);
      final c = QuickEntryParser.parse('Rewe & Lidl 64,20€');
      expect(c.title, 'Rewe & Lidl');
      expect(c.amount, 6420);
    });

    test('Ohne Betrag bleibt der Text Titel', () {
      final a = QuickEntryParser.parse('Geschenk für Mama');
      expect(a.title, 'Geschenk für Mama');
      expect(a.amount, isNull);
    });
  });

  group('Streak', () {
    test('zählt bis heute oder gestern', () {
      final today = DateTime(2026, 10, 7);
      final days = {20261005, 20261006, 20261007};
      expect(Streak.current(days, today), 3);
      expect(Streak.current({20261005, 20261006}, today), 2);
      expect(Streak.current({20261004}, today), 0);
    });
  });

  test('YearMonth', () {
    final m = YearMonth(2026, 12);
    expect(m.next, YearMonth(2027, 1));
    expect(YearMonth(2026, 1).previous, YearMonth(2025, 12));
    expect(m.daysInMonth, 31);
    expect(m.label, 'Dezember 2026');
  });
}
