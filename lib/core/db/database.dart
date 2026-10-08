import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../domain/enums.dart';
import 'seed.dart';
import 'tables.dart';

export 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    RecurringRules,
    Bookings,
    Budgets,
    SavingsGoals,
    GoalContributions,
    Debts,
    DebtPayments,
    Settings,
    ActivityDays,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  /// Für Tests: In-Memory-Datenbank.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await seedDefaults();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Legt die mitgelieferten Kategorien an (bei Neuinstallation und nach
  /// „Alles zurücksetzen“).
  Future<void> seedDefaults() async {
    await batch((b) {
      var order = 0;
      for (final c in seedCategories) {
        b.insert(
          categories,
          CategoriesCompanion.insert(
            name: c.name,
            emoji: c.emoji,
            color: c.color,
            kind: c.kind,
            builtInKey: Value(c.key),
            sortOrder: Value(order++),
          ),
        );
      }
    });
  }

  static QueryExecutor _openConnection() => driftDatabase(name: 'zoezas');
}

/// Kurzform für die Kategorien-Art in Abfragen.
extension CategoryKindX on Category {
  bool get isExpense => kind == CategoryKind.expense;
}
