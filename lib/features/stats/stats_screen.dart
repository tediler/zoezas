import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/shell.dart';
import '../../core/db/database.dart';
import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/charts.dart';
import '../../data/providers.dart';
import '../../domain/ledger.dart';
import '../bookings/booking_tile.dart';

/// Farbfolge für Diagramme – nach Rang statt nach Kategorie, damit
/// benachbarte Segmente immer gut unterscheidbar sind.
const chartPalette = <Color>[
  Color(0xFFD989BE),
  Color(0xFFA99BE0),
  Color(0xFF7FB8E6),
  Color(0xFF79C7A1),
  Color(0xFFF2B07E),
  Color(0xFFE8CF6F),
  Color(0xFFE58C8C),
  Color(0xFF8FC9C7),
];
const chartRest = Color(0xFFDCCFD6);

enum StatsPeriod {
  thisMonth('Dieser Monat'),
  lastMonth('Letzter Monat'),
  thisYear('Dieses Jahr'),
  last12('12 Monate'),
  lastYear('Letztes Jahr');

  const StatsPeriod(this.label);
  final String label;
}

/// Zeitraum mit Vergleichszeitraum und den Monaten für den Verlauf.
class PeriodRange {
  PeriodRange(this.period, DateTime today) {
    final m = YearMonth.of(today);
    switch (period) {
      case StatsPeriod.thisMonth:
        from = m.firstDay;
        to = m.end;
        // Vergleich bis zum gleichen Tag im Vormonat – fair für einen halben Monat.
        final p = m.previous;
        prevFrom = p.firstDay;
        prevTo = DateTime(p.year, p.month, math.min(today.day, p.daysInMonth) + 1);
        compareLabel = 'als bis zum ${today.day}. ${p.monthName}';
        trend = [for (var i = 5; i >= 0; i--) m.add(-i)];
        title = m.label;
      case StatsPeriod.lastMonth:
        final l = m.previous;
        from = l.firstDay;
        to = l.end;
        prevFrom = l.previous.firstDay;
        prevTo = l.firstDay;
        compareLabel = 'als im ${l.previous.monthName}';
        trend = [for (var i = 5; i >= 0; i--) l.add(-i)];
        title = l.label;
      case StatsPeriod.thisYear:
        from = DateTime(today.year);
        to = DateTime(today.year + 1);
        prevFrom = DateTime(today.year - 1);
        prevTo = DateTime(today.year - 1, today.month, today.day + 1);
        compareLabel = 'als im Vorjahr bis heute';
        trend = [for (var i = 1; i <= 12; i++) YearMonth(today.year, i)];
        title = '${today.year}';
      case StatsPeriod.last12:
        from = m.add(-11).firstDay;
        to = m.end;
        prevFrom = m.add(-23).firstDay;
        prevTo = m.add(-11).firstDay;
        compareLabel = 'als in den 12 Monaten davor';
        trend = [for (var i = 11; i >= 0; i--) m.add(-i)];
        title = '${m.add(-11).shortName} ${m.add(-11).year} – ${m.shortName} ${m.year}';
      case StatsPeriod.lastYear:
        from = DateTime(today.year - 1);
        to = DateTime(today.year);
        prevFrom = DateTime(today.year - 2);
        prevTo = DateTime(today.year - 1);
        compareLabel = 'als ${today.year - 2}';
        trend = [for (var i = 1; i <= 12; i++) YearMonth(today.year - 1, i)];
        title = '${today.year - 1}';
    }
    current = m;
  }

  final StatsPeriod period;
  late final DateTime from;
  late final DateTime to;
  late final DateTime prevFrom;
  late final DateTime prevTo;
  late final String compareLabel;
  late final List<YearMonth> trend;
  late final String title;
  late final YearMonth current;
}

final _periodProvider = NotifierProvider<_PeriodNotifier, StatsPeriod>(_PeriodNotifier.new);

class _PeriodNotifier extends Notifier<StatsPeriod> {
  @override
  StatsPeriod build() => StatsPeriod.thisMonth;
  void set(StatsPeriod p) => state = p;
}

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerProvider);
    if (ledger == null) return const SizedBox();
    final period = ref.watch(_periodProvider);
    final range = PeriodRange(period, ledger.today);
    final flow = ledger.flow(range.from, range.to);
    final prev = ledger.flow(range.prevFrom, range.prevTo);
    final categories = ref.watch(categoriesByIdProvider);

    return CustomScrollView(
      slivers: [
        SliverSafeArea(
          bottom: false,
          sliver: SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            sliver: SliverList.list(
              children: [
                const Text('Statistik', style: ZText.screenTitle),
                const SizedBox(height: 4),
                Text('Wohin dein Geld geht – und was bleibt.', style: ZText.secondary),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 42,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: StatsPeriod.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final p = StatsPeriod.values[i];
                return ZPill(
                  label: p.label,
                  selected: p == period,
                  onTap: () => ref.read(_periodProvider.notifier).set(p),
                );
              },
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          sliver: SliverList.list(
            children: [
              _SummaryCard(flow: flow, prev: prev, range: range),
              const SizedBox(height: 14),
              _CategoryCard(flow: flow, categories: categories),
              const SizedBox(height: 14),
              _TrendCard(ledger: ledger, range: range),
              const SizedBox(height: 14),
              _SavingsCard(ledger: ledger, range: range),
              if (flow.incomeByCategory.isNotEmpty) ...[
                const SizedBox(height: 14),
                _IncomeCard(flow: flow, categories: categories),
              ],
              if (flow.expenseBookings.isNotEmpty) ...[
                const SizedBox(height: 26),
                const SectionHeader(title: 'Größte Ausgaben'),
                for (final b in (flow.expenseBookings.toList()..sort((a, b) => b.amount.compareTo(a.amount))).take(
                  5,
                )) ...[BookingTile(booking: b, showDate: true), const SizedBox(height: 10)],
              ],
            ],
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: bottomContentPadding(context))),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.flow, required this.prev, required this.range});

  final FlowSummary flow;
  final FlowSummary prev;
  final PeriodRange range;

  @override
  Widget build(BuildContext context) {
    final diff = flow.expenses - prev.expenses;
    String? compare;
    if (prev.expenses > 0 && flow.expenses > 0) {
      final pct = (diff.abs() / prev.expenses * 100).round();
      compare = diff <= 0
          ? '🌿 $pct % weniger ausgegeben ${range.compareLabel}'
          : '☁️ $pct % mehr ausgegeben ${range.compareLabel}';
    }
    final rate = flow.savingsRate;
    return ZCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(range.title.toUpperCase(), style: ZText.overline),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Figure(label: 'Einnahmen', amount: flow.income, color: ZColors.positive),
              ),
              Expanded(
                child: _Figure(label: 'Ausgaben', amount: flow.expenses),
              ),
              Expanded(
                child: _Figure(
                  label: 'Gespart',
                  amount: flow.saved,
                  color: flow.saved < 0 ? ZColors.negative : ZColors.accentDeep,
                ),
              ),
            ],
          ),
          if (rate != null) ...[
            const SizedBox(height: 16),
            ZProgressBar(value: rate.clamp(0, 1).toDouble(), gradient: ZColors.accentGradient, height: 8),
            const SizedBox(height: 8),
            Text(
              rate >= 0 ? 'Sparquote ${(rate * 100).round()} %' : 'Mehr ausgegeben als eingenommen',
              style: ZText.small,
            ),
          ],
          if (compare != null) ...[
            const SizedBox(height: 12),
            Text(compare, style: ZText.secondary.copyWith(color: ZColors.text)),
          ],
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.amount, this.color});

  final String label;
  final int amount;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: ZText.small),
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: MoneyText(amount, style: ZText.amountSmall.copyWith(fontSize: 21), color: color, showCents: false),
      ),
    ],
  );
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.flow, required this.categories});

  final FlowSummary flow;
  final Map<int, Category> categories;

  @override
  Widget build(BuildContext context) {
    final entries = flow.expenseByCategory.entries.sortedBy<num>((e) => -e.value).toList();
    final total = flow.expenses;
    if (total == 0) {
      return const ZCard(
        child: EmptyState(
          emoji: '🫧',
          title: 'Keine Ausgaben in diesem Zeitraum',
          text: 'Sobald du etwas einträgst, siehst du hier, wohin dein Geld fließt.',
        ),
      );
    }
    const maxSlices = 6;
    final top = entries.take(maxSlices).toList();
    final rest = entries.skip(maxSlices).fold(0, (s, e) => s + e.value);
    final biggest = categories[top.first.key];

    return ZCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Wofür', style: ZText.sectionTitle),
          if (biggest != null) ...[
            const SizedBox(height: 4),
            Text(
              '${biggest.emoji} ${biggest.name} macht ${(top.first.value / total * 100).round()} % deiner Ausgaben aus.',
              style: ZText.secondary,
            ),
          ],
          const SizedBox(height: 20),
          Center(
            child: DonutChart(
              segments: [
                for (var i = 0; i < top.length; i++)
                  DonutSegment(top[i].value.toDouble(), chartPalette[i % chartPalette.length]),
                if (rest > 0) DonutSegment(rest.toDouble(), chartRest),
              ],
              size: 196,
              thickness: 24,
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Ausgaben', style: ZText.small),
                  MoneyText(total, style: ZText.amountMedium, showCents: false),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < top.length; i++)
            _CategoryLegendRow(
              category: categories[top[i].key],
              amount: top[i].value,
              total: total,
              color: chartPalette[i % chartPalette.length],
            ),
          if (rest > 0)
            _CategoryLegendRow(category: null, label: 'Weitere', amount: rest, total: total, color: chartRest),
        ],
      ),
    );
  }
}

class _CategoryLegendRow extends StatelessWidget {
  const _CategoryLegendRow({
    required this.category,
    required this.amount,
    required this.total,
    required this.color,
    this.label,
  });

  final Category? category;
  final String? label;
  final int amount;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final share = total == 0 ? 0.0 : amount / total;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: category == null ? null : () => context.push('/category/${category!.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            EmojiTile(
              emoji: category?.emoji ?? '…',
              color: category != null ? Color(category!.color) : ZColors.accentSoft,
              size: 38,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label ?? category?.name ?? 'Ohne Kategorie',
                          style: ZText.itemTitle.copyWith(fontSize: 14.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(Money.format(amount, compact: true), style: ZText.amountList.copyWith(fontSize: 14.5)),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: ZProgressBar(value: share, color: color, background: ZColors.accentSoft, height: 6),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 36,
                        child: Text('${(share * 100).round()} %', style: ZText.small, textAlign: TextAlign.right),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.ledger, required this.range});

  final Ledger ledger;
  final PeriodRange range;

  @override
  Widget build(BuildContext context) {
    final months = range.trend;
    final summaries = [for (final m in months) ledger.month(m)];
    final avgExpenses = summaries.where((s) => s.expenses > 0).map((s) => s.expenses).average;
    return ZCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Verlauf', style: ZText.sectionTitle),
          const SizedBox(height: 4),
          Text(
            avgExpenses.isNaN
                ? 'Einnahmen und Ausgaben pro Monat'
                : 'Im Schnitt ${Money.format(avgExpenses.round(), compact: true)} Ausgaben pro Monat',
            style: ZText.secondary,
          ),
          const SizedBox(height: 20),
          BarChart(
            groups: [
              for (final s in summaries)
                BarGroup(
                  label: s.month.shortName,
                  values: [s.income, s.expenses],
                  highlight: range.period == StatsPeriod.thisMonth || range.period == StatsPeriod.lastMonth
                      ? s.month == months.last
                      : s.month == range.current,
                ),
            ],
            colors: const [Color(0xFF8FD3B4), ZColors.accent],
          ),
          const SizedBox(height: 12),
          const ChartLegend(items: [('Einnahmen', Color(0xFF8FD3B4)), ('Ausgaben', ZColors.accent)]),
        ],
      ),
    );
  }
}

class _SavingsCard extends StatelessWidget {
  const _SavingsCard({required this.ledger, required this.range});

  final Ledger ledger;
  final PeriodRange range;

  @override
  Widget build(BuildContext context) {
    final summaries = [for (final m in range.trend) ledger.month(m)];
    final total = summaries.fold(0, (s, m) => s + m.saved);
    final best = summaries.where((s) => s.saved > 0).maxBy((s) => s.saved);
    return ZCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Gespart pro Monat', style: ZText.sectionTitle),
          const SizedBox(height: 4),
          Text(
            best == null
                ? 'Was nach allen Ausgaben übrig bleibt.'
                : 'Zusammen ${Money.format(total, compact: true)} · Bester Monat: ${best.month.monthName}',
            style: ZText.secondary,
          ),
          const SizedBox(height: 20),
          BarChart(
            height: 120,
            groups: [
              for (final s in summaries) BarGroup(label: s.month.shortName, values: [s.saved]),
            ],
            colors: const [ZColors.positive],
            negativeColor: ZColors.negative.withValues(alpha: 0.7),
          ),
        ],
      ),
    );
  }
}

class _IncomeCard extends StatelessWidget {
  const _IncomeCard({required this.flow, required this.categories});

  final FlowSummary flow;
  final Map<int, Category> categories;

  @override
  Widget build(BuildContext context) {
    final entries = flow.incomeByCategory.entries.sortedBy<num>((e) => -e.value);
    return ZCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Woher', style: ZText.sectionTitle),
          const SizedBox(height: 12),
          for (final e in entries)
            _CategoryLegendRow(
              category: categories[e.key],
              amount: e.value,
              total: flow.income,
              color: const Color(0xFF8FD3B4),
            ),
        ],
      ),
    );
  }
}

extension on Iterable<MonthSummary> {
  MonthSummary? maxBy(int Function(MonthSummary) f) {
    MonthSummary? best;
    for (final s in this) {
      if (best == null || f(s) > f(best)) best = s;
    }
    return best;
  }
}
