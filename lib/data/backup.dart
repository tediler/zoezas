import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db/database.dart';
import 'providers.dart';

final backupServiceProvider = Provider((ref) => BackupService(ref.watch(databaseProvider)));

class BackupFormatException implements Exception {
  BackupFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Export und Import aller Daten als lesbare JSON-Datei. Die Datenhoheit
/// bleibt bei der Person: Die Datei lässt sich jederzeit sichern, prüfen und
/// auf einem anderen Gerät wieder einspielen.
class BackupService {
  BackupService(this.db);
  final AppDatabase db;

  static const format = 'zoezas-backup';
  static const version = 1;

  // Datumswerte als ISO-Text, damit die Datei lesbar und zeitzonenstabil ist.
  static const _serializer = ValueSerializer.defaults(serializeDateTimeValuesAsString: true);

  Future<String> exportJson() async {
    List<Map<String, dynamic>> rows<T extends DataClass>(List<T> list) => [
      for (final r in list) r.toJson(serializer: _serializer),
    ];

    final data = <String, dynamic>{
      'format': format,
      'version': version,
      'schema': db.schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'accounts': rows(await db.select(db.accounts).get()),
      'categories': rows(await db.select(db.categories).get()),
      'recurringRules': rows(await db.select(db.recurringRules).get()),
      'bookings': rows(await db.select(db.bookings).get()),
      'budgets': rows(await db.select(db.budgets).get()),
      'savingsGoals': rows(await db.select(db.savingsGoals).get()),
      'goalContributions': rows(await db.select(db.goalContributions).get()),
      'debts': rows(await db.select(db.debts).get()),
      'debtPayments': rows(await db.select(db.debtPayments).get()),
      'settings': rows(await db.select(db.settings).get()),
      'activityDays': rows(await db.select(db.activityDays).get()),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Kurze Zusammenfassung einer Sicherung, bevor sie eingespielt wird.
  BackupSummary inspect(String json) {
    final data = _decode(json);
    int count(String key) => (data[key] as List?)?.length ?? 0;
    return BackupSummary(
      exportedAt: DateTime.tryParse(data['exportedAt'] as String? ?? ''),
      accounts: count('accounts'),
      bookings: count('bookings'),
      goals: count('savingsGoals'),
      debts: count('debts'),
    );
  }

  /// Ersetzt alle vorhandenen Daten durch die Sicherung (in einer Transaktion:
  /// schlägt etwas fehl, bleibt alles beim Alten).
  Future<void> importJson(String json) async {
    final data = _decode(json);
    List<Map<String, dynamic>> list(String key) => ((data[key] as List?) ?? const []).cast<Map<String, dynamic>>();

    await db.transaction(() async {
      await _deleteAll();
      await db.batch((b) {
        b.insertAll(db.accounts, [for (final j in list('accounts')) Account.fromJson(j, serializer: _serializer)]);
        b.insertAll(db.categories, [for (final j in list('categories')) Category.fromJson(j, serializer: _serializer)]);
        b.insertAll(db.recurringRules, [
          for (final j in list('recurringRules')) RecurringRule.fromJson(j, serializer: _serializer),
        ]);
        b.insertAll(db.bookings, [for (final j in list('bookings')) Booking.fromJson(j, serializer: _serializer)]);
        b.insertAll(db.budgets, [for (final j in list('budgets')) Budget.fromJson(j, serializer: _serializer)]);
        b.insertAll(db.savingsGoals, [
          for (final j in list('savingsGoals')) SavingsGoal.fromJson(j, serializer: _serializer),
        ]);
        b.insertAll(db.goalContributions, [
          for (final j in list('goalContributions')) GoalContribution.fromJson(j, serializer: _serializer),
        ]);
        b.insertAll(db.debts, [for (final j in list('debts')) Debt.fromJson(j, serializer: _serializer)]);
        b.insertAll(db.debtPayments, [
          for (final j in list('debtPayments')) DebtPayment.fromJson(j, serializer: _serializer),
        ]);
        b.insertAll(db.settings, [for (final j in list('settings')) SettingEntry.fromJson(j, serializer: _serializer)]);
        b.insertAll(db.activityDays, [
          for (final j in list('activityDays')) ActivityDay.fromJson(j, serializer: _serializer),
        ]);
      });
    });
  }

  /// Alles löschen und mit den Standard-Kategorien neu beginnen.
  Future<void> resetAll() => db.transaction(() async {
    await _deleteAll();
    await db.seedDefaults();
  });

  Future<void> _deleteAll() async {
    // Reihenfolge beachtet die Fremdschlüssel.
    await db.delete(db.debtPayments).go();
    await db.delete(db.goalContributions).go();
    await db.delete(db.debts).go();
    await db.delete(db.savingsGoals).go();
    await db.delete(db.budgets).go();
    await db.delete(db.bookings).go();
    await db.delete(db.recurringRules).go();
    await db.delete(db.categories).go();
    await db.delete(db.accounts).go();
    await db.delete(db.settings).go();
    await db.delete(db.activityDays).go();
  }

  Map<String, dynamic> _decode(String json) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      throw BackupFormatException('Die Datei ist kein gültiges JSON.');
    }
    if (decoded is! Map<String, dynamic> || decoded['format'] != format) {
      throw BackupFormatException('Das ist keine Zoëzas-Sicherung.');
    }
    final v = decoded['version'];
    if (v is! int || v > version) {
      throw BackupFormatException('Die Sicherung stammt aus einer neueren App-Version.');
    }
    return decoded;
  }
}

class BackupSummary {
  const BackupSummary({
    required this.exportedAt,
    required this.accounts,
    required this.bookings,
    required this.goals,
    required this.debts,
  });

  final DateTime? exportedAt;
  final int accounts;
  final int bookings;
  final int goals;
  final int debts;
}
