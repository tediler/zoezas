import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/sheets.dart';
import '../../data/providers.dart';
import '../../domain/fina.dart';
import '../bookings/booking_editor.dart';
import 'goal_widgets.dart';

class GoalDetailScreen extends ConsumerWidget {
  const GoalDetailScreen({super.key, required this.goalId});

  final int goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerProvider);
    final profile = ref.watch(profileProvider);
    final goal = ledger?.goals.firstWhereOrNull((g) => g.id == goalId);
    if (ledger == null || profile == null || goal == null) return const Scaffold();
    final progress = ledger.goalProgress(goal);
    final contributions = ledger.contributions.where((c) => c.goalId == goalId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final accounts = ref.watch(accountsByIdProvider);
    final color = Color(goal.color);
    final strong = ZColors.strongFor(color);

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
                    PopupMenuButton<String>(
                      onSelected: (v) => _onMenu(context, ref, v, goal, progress.saved),
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
                        PopupMenuItem(
                          value: 'complete',
                          child: Text(progress.completed ? 'Wieder aktivieren' : 'Abschließen'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Löschen', style: TextStyle(color: ZColors.negative)),
                        ),
                      ],
                      child: const RoundIconButton(icon: Icons.more_horiz_rounded, onPressed: null),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            sliver: SliverList.list(
              children: [
                Center(
                  child: DonutChart(
                    size: 210,
                    thickness: 16,
                    segments: [
                      DonutSegment(progress.ratio, strong),
                      DonutSegment(1 - progress.ratio, Colors.transparent),
                    ],
                    center: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(goal.emoji, style: const TextStyle(fontSize: 46)),
                        const SizedBox(height: 4),
                        Text('${(progress.ratio * 100).floor()} %', style: ZText.amountSmall.copyWith(color: strong)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(goal.name, style: ZText.screenTitle, textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(
                  Fina.goalMessage(progress, profile.tone),
                  style: ZText.body.copyWith(color: ZColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                ZCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _Fig(
                              label: 'Zurückgelegt',
                              child: MoneyText(progress.saved, style: ZText.amountMedium, showCents: false),
                            ),
                          ),
                          Expanded(
                            child: _Fig(
                              label: 'Ziel',
                              child: MoneyText(progress.target, style: ZText.amountMedium, showCents: false),
                            ),
                          ),
                          Expanded(
                            child: _Fig(
                              label: 'Fehlt noch',
                              child: MoneyText(
                                progress.remaining,
                                style: ZText.amountMedium,
                                showCents: false,
                                color: strong,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (goal.targetDate != null) ...[
                        const Divider(height: 28),
                        Row(
                          children: [
                            const Text('📅', style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                progress.monthlyNeeded == null
                                    ? 'Zieldatum: ${DateFormatX.monthYear(goal.targetDate!)}'
                                    : 'Bis ${DateFormatX.monthYear(goal.targetDate!)}: ≈ ${Money.format(progress.monthlyNeeded!, compact: true)} pro Monat',
                                style: ZText.body,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (!progress.completed) ...[
                  PrimaryButton(
                    label: 'Zurücklegen',
                    icon: Icons.add_rounded,
                    onPressed: () => showContributionSheet(context, goal),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: SoftButton(
                          label: 'Entnehmen',
                          onPressed: progress.saved > 0
                              ? () => showContributionSheet(context, goal, withdraw: true)
                              : null,
                        ),
                      ),
                      if (progress.reached) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: SoftButton(
                            label: 'Geschafft 🎉',
                            color: ZColors.positiveLight,
                            textColor: ZColors.positive,
                            onPressed: () => _complete(context, ref, goal, progress.saved),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: 26),
                SectionHeader(title: 'Verlauf', subtitle: contributions.isEmpty ? 'Noch nichts zurückgelegt' : null),
                for (final c in contributions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ZCard(
                      padding: const EdgeInsets.fromLTRB(16, 12, 18, 12),
                      onTap: () => _deleteContribution(context, ref, c),
                      child: Row(
                        children: [
                          EmojiTile(
                            emoji: c.amount >= 0 ? '🌱' : '🍂',
                            color: c.amount >= 0 ? ZColors.positiveLight : ZColors.warningLight,
                            size: 40,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.note ?? (c.amount >= 0 ? 'Zurückgelegt' : 'Entnommen'),
                                  style: ZText.itemTitle.copyWith(fontSize: 14.5),
                                ),
                                Text(contributionLabel(c, accounts), style: ZText.small),
                              ],
                            ),
                          ),
                          Text(
                            Money.format(c.amount, signed: true, compact: true),
                            style: ZText.amountList.copyWith(color: c.amount >= 0 ? ZColors.positive : ZColors.text),
                          ),
                        ],
                      ),
                    ),
                  ),
                SizedBox(height: 40 + MediaQuery.paddingOf(context).bottom),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onMenu(BuildContext context, WidgetRef ref, String action, SavingsGoal goal, int saved) async {
    switch (action) {
      case 'edit':
        await showGoalEditor(context, existing: goal);
      case 'complete':
        if (goal.completedAt != null) {
          await ref.read(goalsRepoProvider).setCompleted(goal, false);
        } else {
          await _complete(context, ref, goal, saved);
        }
      case 'delete':
        final ok = await confirm(
          context,
          title: 'Ziel löschen?',
          message:
              '„${goal.name}“ und der Verlauf werden entfernt. Umbuchungen, die dafür gemacht wurden, verschwinden ebenfalls.',
          confirmLabel: 'Löschen',
          destructive: true,
        );
        if (ok && context.mounted) {
          final repo = ref.read(goalsRepoProvider);
          final contributions = ref.read(contributionsProvider).value ?? const [];
          for (final c in contributions.where((c) => c.goalId == goal.id)) {
            await repo.deleteContribution(c);
          }
          await repo.deleteGoal(goal.id);
          if (context.mounted) context.pop();
        }
    }
  }

  Future<void> _complete(BuildContext context, WidgetRef ref, SavingsGoal goal, int saved) async {
    final result = await showZSheet<String>(
      context,
      builder: (ctx) => SheetScaffold(
        title: 'Ziel abschließen 🎉',
        subtitle:
            'Die ${Money.format(saved, compact: true)} sind dann nicht mehr reserviert. Hast du dir „${goal.name}“ schon gegönnt?',
        children: [
          PrimaryButton(label: 'Ja – Kauf als Ausgabe eintragen', onPressed: () => Navigator.pop(ctx, 'expense')),
          const SizedBox(height: 10),
          SoftButton(label: 'Nur abschließen', onPressed: () => Navigator.pop(ctx, 'done')),
        ],
      ),
    );
    if (result == null || !context.mounted) return;
    await ref.read(goalsRepoProvider).setCompleted(goal, true);
    if (result == 'expense' && context.mounted) {
      await showBookingEditor(context, title: goal.name, amount: saved);
    }
  }

  Future<void> _deleteContribution(BuildContext context, WidgetRef ref, GoalContribution c) async {
    final ok = await confirm(
      context,
      title: 'Eintrag entfernen?',
      message:
          '${Money.format(c.amount, signed: true)} vom ${Dates.numeric(c.date)}${c.bookingId != null ? ' – die zugehörige Umbuchung wird ebenfalls entfernt' : ''}.',
      confirmLabel: 'Entfernen',
      destructive: true,
    );
    if (ok) await ref.read(goalsRepoProvider).deleteContribution(c);
  }
}

class _Fig extends StatelessWidget {
  const _Fig({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: ZText.small),
      const SizedBox(height: 4),
      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: child),
    ],
  );
}
