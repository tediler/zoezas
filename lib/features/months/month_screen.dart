import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/basics.dart';
import '../../data/providers.dart';
import '../../domain/enums.dart';
import '../../domain/ledger.dart';
import '../bookings/booking_editor.dart';
import '../bookings/booking_tile.dart';
import '../settings/budget_row.dart';

enum _Filter {
  all('Alle'),
  expense('Ausgaben'),
  income('Einnahmen'),
  transfer('Umbuchungen');

  const _Filter(this.label);
  final String label;
}

/// Monatsübersicht: vergangene, aktuelle und kommende Monate mit eigener
/// Bilanz, Budgets, Planung und allen Buchungen.
class MonthScreen extends ConsumerStatefulWidget {
  const MonthScreen({super.key, required this.initial});

  final YearMonth initial;

  @override
  ConsumerState<MonthScreen> createState() => _MonthScreenState();
}

class _MonthScreenState extends ConsumerState<MonthScreen> {
  late YearMonth _month = widget.initial;
  _Filter _filter = _Filter.all;

  void _shift(int delta) {
    HapticFeedback.selectionClick();
    setState(() => _month = _month.add(delta));
  }

  @override
  Widget build(BuildContext context) {
    final ledger = ref.watch(ledgerProvider);
    final profile = ref.watch(profileProvider);
    if (ledger == null || profile == null) return const Scaffold();
    final summary = ledger.month(_month);
    final budgets = ref.watch(budgetStatusProvider(_month));
    final current = YearMonth.of(ledger.today);

    final bookings = summary.flow.bookings.where(
      (b) => switch (_filter) {
        _Filter.all => true,
        _Filter.expense => b.type == BookingType.expense,
        _Filter.income => b.type == BookingType.income,
        _Filter.transfer => b.type == BookingType.transfer,
      },
    );
    final byDay = groupBy(bookings, (Booking b) => Dates.dateOnly(b.date));
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      body: GestureDetector(
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v > 400) _shift(-1);
          if (v < -400) _shift(1);
        },
        child: CustomScrollView(
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
                        icon: Icons.chevron_left_rounded,
                        color: Colors.transparent,
                        onPressed: () => _shift(-1),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: SizedBox(
                          key: ValueKey(_month),
                          width: 150,
                          child: Column(
                            children: [
                              Text(_month.label, style: ZText.sectionTitle, textAlign: TextAlign.center),
                              Text(
                                _month == current
                                    ? 'dieser Monat'
                                    : _month.isBefore(current)
                                    ? 'vergangen'
                                    : 'in Planung',
                                style: ZText.small,
                              ),
                            ],
                          ),
                        ),
                      ),
                      RoundIconButton(
                        icon: Icons.chevron_right_rounded,
                        color: Colors.transparent,
                        onPressed: () => _shift(1),
                      ),
                      const Spacer(),
                      if (_month != current)
                        RoundIconButton(
                          icon: Icons.today_rounded,
                          onPressed: () => setState(() => _month = current),
                          tooltip: 'Heute',
                        )
                      else
                        const SizedBox(width: 44),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverList.list(
                children: [
                  _SummaryCard(summary: summary, current: current),
                  if (budgets.isNotEmpty) ...[
                    const SizedBox(height: 26),
                    SectionHeader(
                      title: 'Budgets',
                      trailing: TextButton(onPressed: () => context.push('/budgets'), child: const Text('Bearbeiten')),
                    ),
                    ZCard(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                      child: Column(
                        children: [for (final s in budgets) BudgetRow(status: s, tone: profile.tone)],
                      ),
                    ),
                  ],
                  if (summary.pending.isNotEmpty) ...[
                    const SizedBox(height: 26),
                    SectionHeader(title: 'Geplant & offen', subtitle: 'Zählt erst, wenn es gebucht ist'),
                    for (final p in summary.pending) ...[
                      PlannedTile(item: p, compact: true),
                      const SizedBox(height: 10),
                    ],
                  ],
                  const SizedBox(height: 26),
                  SectionHeader(
                    title: 'Buchungen',
                    subtitle: summary.flow.bookings.isEmpty
                        ? null
                        : '${summary.flow.bookings.length} im ${_month.monthName}',
                  ),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final f in _Filter.values) ...[
                          ZPill(
                            label: f.label,
                            dense: true,
                            selected: _filter == f,
                            onTap: () => setState(() => _filter = f),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (days.isEmpty)
                    ZCard(
                      child: EmptyState(
                        emoji: _month.isAfter(current) ? '🗓️' : '🍃',
                        title: _month.isAfter(current) ? 'Noch nichts gebucht' : 'Keine Buchungen',
                        text: _month.isAfter(current)
                            ? 'Geplantes für diesen Monat kannst du schon jetzt eintragen.'
                            : 'In diesem Monat ist nichts passiert – oder es wurde noch nicht eingetragen.',
                        action: _month.isAfter(current)
                            ? SoftButton(
                                label: 'Etwas einplanen',
                                icon: Icons.add_rounded,
                                onPressed: () => showBookingEditor(context, date: _month.firstDay, planned: true),
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.builder(
                itemCount: days.length,
                itemBuilder: (_, i) {
                  final day = days[i];
                  final list = byDay[day]!;
                  final spent = list.where((b) => b.type == BookingType.expense).fold(0, (s, b) => s + b.amount);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                Dates.longDay(day),
                                style: ZText.label.copyWith(color: ZColors.textSecondary),
                              ),
                            ),
                            if (spent > 0) Text('−${Money.format(spent, compact: true)}', style: ZText.small),
                          ],
                        ),
                      ),
                      for (final b in list) ...[BookingTile(booking: b), const SizedBox(height: 10)],
                    ],
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 60)),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, required this.current});

  final MonthSummary summary;
  final YearMonth current;

  @override
  Widget build(BuildContext context) {
    final m = summary.month;
    final isPast = m.isBefore(current);
    final isFuture = m.isAfter(current);
    final main = isFuture ? summary.projectedSaved : summary.saved;
    final label = isPast
        ? 'IM ${m.monthName.toUpperCase()} GESPART'
        : isFuture
        ? 'VORAUSSICHTLICH ÜBRIG'
        : 'BISHER ÜBRIG';
    final rate = summary.flow.savingsRate;

    return ZCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: ZText.overline),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: MoneyText(
              main,
              style: ZText.amountLarge.copyWith(fontSize: 44),
              color: main < 0 ? ZColors.negative : ZColors.text,
              signed: main > 0,
            ),
          ),
          if (rate != null && !isFuture) ...[
            const SizedBox(height: 4),
            Text(
              rate >= 0
                  ? '${(rate * 100).round()} % deines Einkommens ${isPast ? 'sind übrig geblieben' : 'sind bisher übrig'}'
                  : 'Mehr ausgegeben als eingenommen',
              style: ZText.secondary,
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _Figure(
                  label: 'Einnahmen',
                  amount: summary.income,
                  planned: summary.plannedIncome,
                  color: ZColors.positive,
                ),
              ),
              Container(width: 1, height: 44, color: ZColors.line),
              const SizedBox(width: 16),
              Expanded(
                child: _Figure(label: 'Ausgaben', amount: summary.expenses, planned: summary.plannedExpenses),
              ),
            ],
          ),
          if (summary.pending.isNotEmpty && !isFuture) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(color: ZColors.accentSoft, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  const Text('🔮 ', style: TextStyle(fontSize: 14)),
                  Expanded(
                    child: Text('Mit allem Geplanten', style: ZText.secondary.copyWith(color: ZColors.text)),
                  ),
                  Text(
                    Money.format(summary.projectedSaved, signed: true, compact: true),
                    style: ZText.label.copyWith(
                      color: summary.projectedSaved >= 0 ? ZColors.positive : ZColors.negative,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.amount, required this.planned, this.color});

  final String label;
  final int amount;
  final int planned;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ZText.small),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: MoneyText(amount, style: ZText.amountSmall.copyWith(fontSize: 21), color: color, showCents: false),
        ),
        if (planned > 0)
          Text('+ ${Money.format(planned, compact: true)} geplant', style: ZText.small.copyWith(fontSize: 11.5)),
      ],
    );
  }
}
