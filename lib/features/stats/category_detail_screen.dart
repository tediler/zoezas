import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/charts.dart';
import '../../data/providers.dart';
import '../../domain/budgets.dart';
import '../../domain/enums.dart';
import '../bookings/booking_tile.dart';
import '../settings/budgets_screen.dart';
import '../settings/categories_screen.dart';

/// Eine Kategorie über die Zeit: diesen Monat, letzten Monat, dieses Jahr,
/// Verlauf und alle Buchungen.
class CategoryDetailScreen extends ConsumerWidget {
  const CategoryDetailScreen({super.key, required this.categoryId});

  final int categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerProvider);
    final category = ref.watch(categoriesByIdProvider)[categoryId];
    if (ledger == null || category == null) return const Scaffold();
    final isExpense = category.kind == CategoryKind.expense;
    final today = ledger.today;
    final m = YearMonth.of(today);

    int sumIn(DateTime from, DateTime to) {
      final f = ledger.flow(from, to);
      return (isExpense ? f.expenseByCategory : f.incomeByCategory)[categoryId] ?? 0;
    }

    final thisMonth = sumIn(m.firstDay, m.end);
    final lastMonth = sumIn(m.previous.firstDay, m.previous.end);
    final thisYear = sumIn(DateTime(today.year), DateTime(today.year + 1));
    final months = [for (var i = 11; i >= 0; i--) m.add(-i)];
    final perMonth = [for (final x in months) sumIn(x.firstDay, x.end)];
    final active = perMonth.where((v) => v > 0).toList();
    final avg = active.isEmpty ? 0 : (active.reduce((a, b) => a + b) / active.length).round();

    final bookings =
        ledger.bookings.where((b) => b.categoryId == categoryId && b.status == BookingStatus.booked).toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    final budgetRows = ref.watch(budgetsProvider).value ?? const [];
    final limit = isExpense ? BudgetLogic.effectiveLimit(budgetRows, categoryId, m) : null;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    RoundIconButton(icon: Icons.arrow_back_rounded, onPressed: () => context.pop()),
                    const Spacer(),
                    RoundIconButton(
                      icon: Icons.edit_outlined,
                      onPressed: () => showCategoryEditor(context, existing: category, kind: category.kind),
                      tooltip: 'Bearbeiten',
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            sliver: SliverList.list(
              children: [
                Row(
                  children: [
                    EmojiTile(emoji: category.emoji, color: Color(category.color), size: 60),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(category.name, style: ZText.screenTitle.copyWith(fontSize: 26)),
                          Text(isExpense ? 'Ausgaben-Kategorie' : 'Einnahmen-Kategorie', style: ZText.secondary),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                ZCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _Fig(label: 'Diesen Monat', amount: thisMonth),
                          ),
                          Expanded(
                            child: _Fig(label: 'Letzten Monat', amount: lastMonth),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _Fig(label: 'Dieses Jahr', amount: thisYear),
                          ),
                          Expanded(
                            child: _Fig(label: 'Ø pro Monat', amount: avg),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ZCard(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Letzte 12 Monate', style: ZText.sectionTitle),
                      const SizedBox(height: 18),
                      BarChart(
                        height: 130,
                        groups: [
                          for (var i = 0; i < months.length; i++)
                            BarGroup(
                              label: months[i].shortName.substring(0, 1),
                              values: [perMonth[i]],
                              highlight: months[i] == m,
                            ),
                        ],
                        colors: [ZColors.strongFor(Color(category.color))],
                      ),
                    ],
                  ),
                ),
                if (isExpense) ...[
                  const SizedBox(height: 14),
                  ZCard(
                    onTap: () => showBudgetEditor(context, categoryId: categoryId),
                    child: Row(
                      children: [
                        const Text('🎯', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                limit == null
                                    ? 'Budget festlegen'
                                    : 'Budget: ${Money.format(limit, compact: true)} im Monat',
                                style: ZText.itemTitle,
                              ),
                              Text(
                                limit == null
                                    ? 'Fina erinnert dich sanft, wenn es knapp wird.'
                                    : 'Noch ${Money.format(limit - thisMonth, compact: true)} im ${m.monthName}',
                                style: ZText.secondary,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: ZColors.textTertiary),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 26),
                SectionHeader(
                  title: 'Buchungen',
                  subtitle: bookings.isEmpty ? 'Noch keine' : '${bookings.length} insgesamt',
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.builder(
              itemCount: bookings.length.clamp(0, 100),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: BookingTile(booking: bookings[i], showDate: true),
              ),
            ),
          ),
          if (bookings.length > 100)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Ältere Buchungen findest du in der Monatsübersicht.',
                  style: ZText.small,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          SliverToBoxAdapter(child: SizedBox(height: 40 + MediaQuery.paddingOf(context).bottom)),
        ],
      ),
    );
  }
}

class _Fig extends StatelessWidget {
  const _Fig({required this.label, required this.amount});
  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: ZText.small),
      const SizedBox(height: 4),
      MoneyText(amount, style: ZText.amountSmall.copyWith(fontSize: 22), showCents: false),
    ],
  );
}
