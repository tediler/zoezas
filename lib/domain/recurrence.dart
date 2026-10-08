import 'dart:math' as math;

import '../core/format/dates.dart';
import 'enums.dart';

/// Terminberechnung für Daueraufträge. Jeder Termin wird direkt aus dem
/// Startdatum abgeleitet (nicht aus dem Vortermin) – so wird aus dem 31. im
/// Februar zwar der 28., im März aber wieder der 31.
abstract final class Recurrence {
  /// Der [n]-te Termin (n ≥ 0) einer Reihe ab [start]. [dayOfMonth] legt bei
  /// monatlichen Rhythmen den Tag fest (31 = Monatsende), sonst gilt der Tag
  /// des Startdatums.
  static DateTime nth(DateTime start, Frequency frequency, int n, {int? dayOfMonth}) {
    final s = Dates.dateOnly(start);
    final day = dayOfMonth ?? s.day;
    return switch (frequency) {
      Frequency.weekly => DateTime(s.year, s.month, s.day + 7 * n),
      Frequency.biweekly => DateTime(s.year, s.month, s.day + 14 * n),
      Frequency.monthly => addMonthsClamped(s, n, day: day),
      Frequency.quarterly => addMonthsClamped(s, 3 * n, day: day),
      Frequency.halfYearly => addMonthsClamped(s, 6 * n, day: day),
      Frequency.yearly => addMonthsClamped(s, 12 * n, day: day),
    };
  }

  static DateTime addMonthsClamped(DateTime d, int months, {int? day}) {
    final total = d.year * 12 + (d.month - 1) + months;
    final y = total ~/ 12;
    final m = total % 12 + 1;
    final lastDay = DateTime(y, m + 1, 0).day;
    return DateTime(y, m, math.min(day ?? d.day, lastDay));
  }

  /// Startdatum für einen monatlichen Termin am Tag [day] (31 = Monatsende):
  /// der erste solche Termin am oder nach [from].
  static DateTime firstMonthlyOnOrAfter(DateTime from, int day) {
    final f = Dates.dateOnly(from);
    final thisMonth = addMonthsClamped(DateTime(f.year, f.month, 1), 0, day: day);
    return thisMonth.isBefore(f) ? addMonthsClamped(DateTime(f.year, f.month, 1), 1, day: day) : thisMonth;
  }

  /// Alle Termine zwischen [from] und [to] (beide inklusive, nach Kalendertag),
  /// höchstens bis [endDate].
  static List<DateTime> between({
    required DateTime start,
    required Frequency frequency,
    required DateTime from,
    required DateTime to,
    DateTime? endDate,
    int? dayOfMonth,
  }) {
    final s = Dates.dateOnly(start);
    var lo = Dates.dateOnly(from);
    var hi = Dates.dateOnly(to);
    if (endDate != null && Dates.dateOnly(endDate).isBefore(hi)) hi = Dates.dateOnly(endDate);
    if (lo.isBefore(s)) lo = s;
    if (hi.isBefore(lo)) return const [];

    // Grob vorspulen, damit lange Reihen nicht ab dem Start durchlaufen werden.
    var n = math.max(0, _estimateIndex(s, frequency, lo) - 1);
    final result = <DateTime>[];
    while (true) {
      final d = nth(s, frequency, n, dayOfMonth: dayOfMonth);
      if (d.isAfter(hi)) break;
      if (!d.isBefore(lo)) result.add(d);
      n++;
    }
    return result;
  }

  /// Erster Termin am oder nach [day].
  static DateTime? nextOnOrAfter({
    required DateTime start,
    required Frequency frequency,
    required DateTime day,
    DateTime? endDate,
    int? dayOfMonth,
  }) {
    final s = Dates.dateOnly(start);
    final target = Dates.dateOnly(day);
    var n = math.max(0, _estimateIndex(s, frequency, target) - 1);
    while (true) {
      final d = nth(s, frequency, n, dayOfMonth: dayOfMonth);
      if (endDate != null && d.isAfter(Dates.dateOnly(endDate))) return null;
      if (!d.isBefore(target)) return d;
      n++;
    }
  }

  static int _estimateIndex(DateTime start, Frequency f, DateTime target) {
    if (!target.isAfter(start)) return 0;
    final days = Dates.daysBetween(start, target);
    final months = (target.year - start.year) * 12 + (target.month - start.month);
    return switch (f) {
      Frequency.weekly => days ~/ 7,
      Frequency.biweekly => days ~/ 14,
      Frequency.monthly => months,
      Frequency.quarterly => months ~/ 3,
      Frequency.halfYearly => months ~/ 6,
      Frequency.yearly => months ~/ 12,
    };
  }

  /// Ungefährer Monatsbetrag eines Rhythmus (für „pro Monat“-Hinweise).
  static int monthlyEquivalent(int amount, Frequency f) => switch (f) {
    Frequency.weekly => (amount * 52 / 12).round(),
    Frequency.biweekly => (amount * 26 / 12).round(),
    Frequency.monthly => amount,
    Frequency.quarterly => (amount / 3).round(),
    Frequency.halfYearly => (amount / 6).round(),
    Frequency.yearly => (amount / 12).round(),
  };
}
