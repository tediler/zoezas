import 'package:flutter_test/flutter_test.dart';
import 'package:zoezas/core/format/dates.dart';
import 'package:zoezas/domain/enums.dart';
import 'package:zoezas/domain/fina.dart';
import 'package:zoezas/domain/ledger.dart';

import '../helpers/fixtures.dart';

void main() {
  final now = DateTime(2026, 10, 8, 15);

  FinaContext ctx({int bookings = 0, int? daysSinceBackup, bool inBrowser = false, int due = 0}) {
    final giro = account(opening: 100000);
    final ledger = Ledger(accounts: [giro], bookings: const [], rules: const [], now: now);
    return FinaContext(
      now: now,
      name: 'Annika',
      tone: FinaTone.warm,
      focus: MoneyFocus.overview,
      hasBookings: bookings > 0,
      available: 100000,
      forecastEnd: 100000,
      month: ledger.month(YearMonth.of(now)),
      budgets: const [],
      streak: 1,
      dueCount: due,
      goals: const [],
      frequentSmallExpense: null,
      categoryNames: const {},
      bookingCount: bookings,
      daysSinceBackup: daysSinceBackup,
      inBrowser: inBrowser,
    );
  }

  group('Sicherungs-Erinnerung', () {
    test('noch nie gesichert: erst ab 10 Buchungen', () {
      expect(ctx(bookings: 9).needsBackup, isFalse);
      expect(ctx(bookings: 10).needsBackup, isTrue);
    });

    test('im Browser nach 14 Tagen, in der App nach 30', () {
      expect(ctx(bookings: 50, daysSinceBackup: 13, inBrowser: true).needsBackup, isFalse);
      expect(ctx(bookings: 50, daysSinceBackup: 14, inBrowser: true).needsBackup, isTrue);
      expect(ctx(bookings: 50, daysSinceBackup: 29).needsBackup, isFalse);
      expect(ctx(bookings: 50, daysSinceBackup: 30).needsBackup, isTrue);
    });

    test('Tipp-Karte: fällige Zahlungen gehen vor, dann die Sicherung', () {
      expect(Fina.tip(ctx(bookings: 20, due: 1)).action, FinaTipAction.showDue);
      expect(Fina.tip(ctx(bookings: 20)).action, FinaTipAction.backup);
      expect(Fina.tip(ctx(bookings: 20, daysSinceBackup: 2)).action, isNot(FinaTipAction.backup));
    });
  });
}
