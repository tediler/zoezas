import 'package:zoezas/core/db/database.dart';
import 'package:zoezas/domain/enums.dart';

// Bausteine für Logik-Tests: Datensätze ohne Datenbank.

var _id = 1000;
int nextId() => _id++;

Account account({
  int? id,
  String name = 'Girokonto',
  AccountType type = AccountType.checking,
  int opening = 0,
  DateTime? openingDate,
  bool? includeInAvailable,
  bool archived = false,
}) => Account(
  id: id ?? nextId(),
  name: name,
  emoji: type.emoji,
  color: 0xFFFFFFFF,
  type: type,
  openingBalance: opening,
  openingDate: openingDate ?? DateTime(2026, 1, 1),
  includeInAvailable: includeInAvailable ?? type.defaultIncludeInAvailable,
  archived: archived,
  sortOrder: 0,
);

Booking booking({
  int? id,
  required BookingType type,
  BookingStatus status = BookingStatus.booked,
  required int amount,
  required int accountId,
  int? toAccountId,
  int? categoryId,
  String title = 'Test',
  required DateTime date,
  int? recurringId,
  DateTime? occurrenceDate,
}) => Booking(
  id: id ?? nextId(),
  type: type,
  status: status,
  amount: amount,
  accountId: accountId,
  toAccountId: toAccountId,
  categoryId: categoryId,
  title: title,
  note: null,
  date: date,
  recurringId: recurringId,
  occurrenceDate: occurrenceDate,
  createdAt: date,
);

Booking expense(
  int amount,
  int accountId,
  DateTime date, {
  BookingStatus status = BookingStatus.booked,
  int? categoryId,
  int? recurringId,
  DateTime? occurrenceDate,
}) => booking(
  type: BookingType.expense,
  status: status,
  amount: amount,
  accountId: accountId,
  categoryId: categoryId,
  date: date,
  recurringId: recurringId,
  occurrenceDate: occurrenceDate,
);

Booking income(
  int amount,
  int accountId,
  DateTime date, {
  BookingStatus status = BookingStatus.booked,
  int? categoryId,
}) => booking(
  type: BookingType.income,
  status: status,
  amount: amount,
  accountId: accountId,
  categoryId: categoryId,
  date: date,
);

Booking transfer(int amount, int from, int to, DateTime date, {BookingStatus status = BookingStatus.booked}) =>
    booking(type: BookingType.transfer, status: status, amount: amount, accountId: from, toAccountId: to, date: date);

RecurringRule rule({
  int? id,
  BookingType type = BookingType.expense,
  required int amount,
  required int accountId,
  int? toAccountId,
  int? categoryId,
  String title = 'Dauerauftrag',
  Frequency frequency = Frequency.monthly,
  required DateTime start,
  DateTime? end,
  bool autoBook = true,
  bool active = true,
  int? dayOfMonth,
}) => RecurringRule(
  id: id ?? nextId(),
  type: type,
  amount: amount,
  accountId: accountId,
  toAccountId: toAccountId,
  categoryId: categoryId,
  title: title,
  note: null,
  frequency: frequency,
  startDate: start,
  dayOfMonth: dayOfMonth,
  endDate: end,
  autoBook: autoBook,
  active: active,
  createdAt: start,
);

SavingsGoal goal({int? id, String name = 'Urlaub', required int target, DateTime? targetDate, DateTime? completedAt}) =>
    SavingsGoal(
      id: id ?? nextId(),
      name: name,
      emoji: '🌴',
      color: 0xFFFFFFFF,
      targetAmount: target,
      targetDate: targetDate,
      note: null,
      createdAt: DateTime(2026, 1, 1),
      completedAt: completedAt,
      sortOrder: 0,
    );

GoalContribution contribution(int goalId, int amount, {int? heldIn, DateTime? date}) => GoalContribution(
  id: nextId(),
  goalId: goalId,
  amount: amount,
  date: date ?? DateTime(2026, 10, 1),
  note: null,
  heldInAccountId: heldIn,
  bookingId: null,
);

Category category({int? id, String name = 'Essen', CategoryKind kind = CategoryKind.expense}) => Category(
  id: id ?? nextId(),
  name: name,
  emoji: '🛒',
  color: 0xFFFFFFFF,
  kind: kind,
  builtInKey: null,
  archived: false,
  sortOrder: 0,
);

Budget budget(int? categoryId, int amount, int validFrom) =>
    Budget(id: nextId(), categoryId: categoryId, amount: amount, validFrom: validFrom);
