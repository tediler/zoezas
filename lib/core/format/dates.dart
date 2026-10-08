import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// Ein Kalendermonat. Grundeinheit für Monatsübersicht, Budgets und Sparen.
@immutable
class YearMonth implements Comparable<YearMonth> {
  const YearMonth(this.year, this.month) : assert(month >= 1 && month <= 12);

  factory YearMonth.of(DateTime d) => YearMonth(d.year, d.month);

  factory YearMonth.fromKey(int key) => YearMonth(key ~/ 100, key % 100);

  final int year;
  final int month;

  /// JJJJMM, z. B. 202610.
  int get key => year * 100 + month;

  DateTime get firstDay => DateTime(year, month);
  DateTime get lastDay => DateTime(year, month + 1, 0);

  /// Exklusives Ende (erster Tag des Folgemonats).
  DateTime get end => DateTime(year, month + 1);

  int get daysInMonth => lastDay.day;

  YearMonth get next => add(1);
  YearMonth get previous => add(-1);

  YearMonth add(int months) {
    final total = year * 12 + (month - 1) + months;
    return YearMonth(total ~/ 12, total % 12 + 1);
  }

  bool contains(DateTime d) => d.year == year && d.month == month;

  bool isBefore(YearMonth other) => key < other.key;
  bool isAfter(YearMonth other) => key > other.key;

  /// „Oktober 2026“
  String get label => DateFormat('MMMM yyyy', 'de_DE').format(firstDay);

  /// „Oktober“
  String get monthName => DateFormat('MMMM', 'de_DE').format(firstDay);

  /// „Okt“
  String get shortName => DateFormat('MMM', 'de_DE').format(firstDay).replaceAll('.', '');

  @override
  int compareTo(YearMonth other) => key.compareTo(other.key);

  @override
  bool operator ==(Object other) => other is YearMonth && other.key == key;

  @override
  int get hashCode => key;

  @override
  String toString() => 'YearMonth($key)';
}

abstract final class Dates {
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  /// JJJJMMTT
  static int dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  static DateTime fromDayKey(int key) => DateTime(key ~/ 10000, (key ~/ 100) % 100, key % 100);

  /// Tagesdifferenz nach Kalendertagen (robust gegenüber Sommerzeit).
  static int daysBetween(DateTime from, DateTime to) =>
      DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

  /// „Heute“, „Gestern“, „Morgen“, sonst „Mi., 7. Okt.“
  static String relative(DateTime d, {DateTime? now}) {
    final today = dateOnly(now ?? DateTime.now());
    final diff = daysBetween(today, d);
    if (diff == 0) return 'Heute';
    if (diff == -1) return 'Gestern';
    if (diff == 1) return 'Morgen';
    if (d.year == today.year) return DateFormat('E, d. MMM', 'de_DE').format(d);
    return DateFormat('d. MMM yyyy', 'de_DE').format(d);
  }

  /// „in 3 Tagen“, „vor 2 Tagen“, „heute“
  static String distance(DateTime d, {DateTime? now}) {
    final diff = daysBetween(now ?? DateTime.now(), d);
    if (diff == 0) return 'heute';
    if (diff == 1) return 'morgen';
    if (diff == -1) return 'gestern';
    if (diff > 1) return 'in $diff Tagen';
    return 'vor ${-diff} Tagen';
  }

  /// „Mittwoch, 7. Oktober“
  static String longDay(DateTime d) => DateFormat('EEEE, d. MMMM', 'de_DE').format(d);

  /// „7. Okt.“
  static String short(DateTime d) => DateFormat('d. MMM', 'de_DE').format(d);

  /// „07.10.2026“
  static String numeric(DateTime d) => DateFormat('dd.MM.yyyy', 'de_DE').format(d);
}
