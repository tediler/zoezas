import '../core/db/database.dart';
import '../core/format/dates.dart';
import 'ledger.dart';

enum BudgetLevel { relaxed, almost, over }

/// Stand eines Budgets in einem Monat. Verbraucht zählt nur Gebuchtes,
/// Geplantes wird getrennt ausgewiesen.
class BudgetStatus {
  const BudgetStatus({required this.category, required this.limit, required this.spent, required this.planned});

  /// null = Gesamtbudget über alle Ausgaben.
  final Category? category;
  final int limit;
  final int spent;
  final int planned;

  bool get isTotal => category == null;
  int get remaining => limit - spent;
  double get ratio => limit <= 0 ? 0 : spent / limit;
  double get plannedRatio => limit <= 0 ? 0 : (spent + planned) / limit;

  BudgetLevel get level {
    if (spent > limit) return BudgetLevel.over;
    if (ratio >= 0.8) return BudgetLevel.almost;
    return BudgetLevel.relaxed;
  }

  /// Würde das Budget mit dem Geplanten überschritten?
  bool get plannedWillExceed => spent <= limit && spent + planned > limit;
}

abstract final class BudgetLogic {
  /// Gültiges Budget einer Kategorie (null = gesamt) im Monat [m]:
  /// der jüngste Eintrag mit validFrom ≤ m. 0 oder kein Eintrag = kein Budget.
  static int? effectiveLimit(List<Budget> rows, int? categoryId, YearMonth m) {
    Budget? best;
    for (final r in rows) {
      if (r.categoryId != categoryId || r.validFrom > m.key) continue;
      if (best == null || r.validFrom > best.validFrom) best = r;
    }
    if (best == null || best.amount <= 0) return null;
    return best.amount;
  }

  /// Alle Budgets eines Monats: zuerst das Gesamtbudget, dann nach Auslastung.
  static List<BudgetStatus> statusFor({
    required YearMonth month,
    required List<Budget> rows,
    required MonthSummary summary,
    required Map<int, Category> categories,
  }) {
    final result = <BudgetStatus>[];
    final total = effectiveLimit(rows, null, month);
    if (total != null) {
      result.add(BudgetStatus(category: null, limit: total, spent: summary.expenses, planned: summary.plannedExpenses));
    }
    final catIds = rows.map((r) => r.categoryId).whereType<int>().toSet();
    final perCat = <BudgetStatus>[];
    for (final id in catIds) {
      final cat = categories[id];
      if (cat == null) continue;
      final limit = effectiveLimit(rows, id, month);
      if (limit == null) continue;
      perCat.add(
        BudgetStatus(
          category: cat,
          limit: limit,
          spent: summary.flow.expenseByCategory[id] ?? 0,
          planned: summary.plannedExpensesFor(id),
        ),
      );
    }
    perCat.sort((a, b) => b.ratio.compareTo(a.ratio));
    return result..addAll(perCat);
  }
}
