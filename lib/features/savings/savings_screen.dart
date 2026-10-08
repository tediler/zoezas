import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/shell.dart';
import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/fina_avatar.dart';
import '../../data/providers.dart';
import '../../domain/enums.dart';
import '../../domain/fina.dart';
import 'debt_screens.dart';
import 'goal_widgets.dart';

class SavingsScreen extends ConsumerWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerProvider);
    final profile = ref.watch(profileProvider);
    if (ledger == null || profile == null) return const SizedBox();
    final month = YearMonth.of(ledger.today);
    final recent = ledger.recentMonths(month, 6);
    final thisMonth = recent.last;
    final lastMonth = recent[recent.length - 2];
    final goals = ref.watch(goalProgressProvider);
    final active = goals.where((g) => !g.completed).toList();
    final done = goals.where((g) => g.completed).toList();
    final debts = ref.watch(debtStatusesProvider);
    final open = debts.where((d) => !d.isSettled).toList();
    final iOwe = open.where((d) => d.debt.direction == DebtDirection.iOwe).fold(0, (s, d) => s + d.remaining);
    final owedToMe = open.where((d) => d.debt.direction == DebtDirection.owedToMe).fold(0, (s, d) => s + d.remaining);
    final reservedTotal = active.fold(0, (s, g) => s + g.saved);

    return CustomScrollView(
      slivers: [
        SliverSafeArea(
          bottom: false,
          sliver: SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            sliver: SliverList.list(
              children: [
                const Text('Sparen', style: ZText.screenTitle),
                const SizedBox(height: 4),
                Text('Kleine Schritte, große Träume.', style: ZText.secondary),
                const SizedBox(height: 20),
                ZCard(
                  padding: const EdgeInsets.all(22),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFFFFF), Color(0xFFFCEAF4)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('IM ${month.monthName.toUpperCase()} GESPART', style: ZText.overline),
                                const SizedBox(height: 8),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: MoneyText(
                                    thisMonth.saved,
                                    style: ZText.amountLarge.copyWith(fontSize: 46),
                                    color: thisMonth.saved < 0 ? ZColors.negative : ZColors.text,
                                    showCents: false,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  lastMonth.flow.bookings.isEmpty
                                      ? 'Dein erster Monat mit Zoëzas'
                                      : 'Letzten Monat: ${Money.format(lastMonth.saved, compact: true)}',
                                  style: ZText.secondary,
                                ),
                              ],
                            ),
                          ),
                          FinaAvatar(
                            mood: thisMonth.saved > lastMonth.saved ? FinaMood.proud : FinaMood.happy,
                            size: 58,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        Fina.savingsMessage(
                          thisMonth: thisMonth.saved,
                          lastMonth: lastMonth.saved,
                          tone: profile.tone,
                          hasHistory: lastMonth.flow.bookings.isNotEmpty,
                        ),
                        style: ZText.fina,
                      ),
                      const SizedBox(height: 18),
                      BarChart(
                        height: 90,
                        groups: [
                          for (final s in recent)
                            BarGroup(label: s.month.shortName, values: [s.saved], highlight: s.month == month),
                        ],
                        colors: const [ZColors.positive],
                        negativeColor: ZColors.negative.withValues(alpha: 0.7),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Gespart = Einnahmen minus Ausgaben. Umbuchungen aufs Sparkonto zählen nicht doppelt.',
                        style: ZText.small.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                SectionHeader(
                  title: 'Deine Ziele',
                  subtitle: reservedTotal > 0 ? '${Money.format(reservedTotal, compact: true)} zurückgelegt' : null,
                  trailing: TextButton.icon(
                    onPressed: () => showGoalEditor(context),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Neues Ziel'),
                  ),
                ),
                if (active.isEmpty)
                  ZCard(
                    onTap: () => showGoalEditor(context),
                    child: const EmptyState(
                      emoji: '🎯',
                      title: 'Worauf freust du dich?',
                      text: 'Urlaub, Auto, ein neues Handy – leg ein Ziel an und sieh zu, wie es wächst.',
                    ),
                  ),
                for (final g in active) ...[GoalCard(progress: g, tone: profile.tone), const SizedBox(height: 14)],
                if (done.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: Text('Erreicht (${done.length}) 🎉', style: ZText.label),
                    children: [
                      for (final g in done)
                        ZListRow(
                          leading: Text(g.goal.emoji, style: const TextStyle(fontSize: 22)),
                          title: g.goal.name,
                          subtitle:
                              '${Money.format(g.saved, compact: true)} · abgeschlossen ${Dates.short(g.goal.completedAt!)}',
                          onTap: () => context.push('/goal/${g.goal.id}'),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 26),
                SectionHeader(
                  title: 'Geld zwischen Menschen',
                  subtitle: 'Offenes verändert deinen Kontostand erst, wenn gezahlt wird.',
                  trailing: TextButton.icon(
                    onPressed: () => showDebtEditor(context),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Neu'),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _DebtSummary(emoji: '🫶', label: 'Du schuldest', amount: iOwe, color: ZColors.warning),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DebtSummary(
                        emoji: '🤝',
                        label: 'Dir schuldet man',
                        amount: owedToMe,
                        color: ZColors.positive,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final d in open.take(4)) ...[DebtTile(status: d), const SizedBox(height: 10)],
                if (debts.isNotEmpty)
                  Center(
                    child: TextButton(
                      onPressed: () => context.push('/debts'),
                      child: Text(
                        debts.length > open.length || open.length > 4 ? 'Alle anzeigen (${debts.length})' : 'Verwalten',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: bottomContentPadding(context))),
      ],
    );
  }
}

class _DebtSummary extends StatelessWidget {
  const _DebtSummary({required this.emoji, required this.label, required this.amount, required this.color});

  final String emoji;
  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ZCard(
      padding: const EdgeInsets.all(16),
      onTap: () => context.push('/debts'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$emoji  $label', style: ZText.small),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: MoneyText(
              amount,
              style: ZText.amountMedium,
              color: amount == 0 ? ZColors.textSecondary : color,
              showCents: false,
            ),
          ),
        ],
      ),
    );
  }
}
