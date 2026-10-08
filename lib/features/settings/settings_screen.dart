import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/shell.dart';
import '../../core/format/money.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/sheets.dart';
import '../../data/providers.dart';
import '../../domain/enums.dart';
import '../../domain/recurrence.dart';
import '../../platform/platform_integration.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final ledger = ref.watch(ledgerProvider);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final budgets = ref.watch(budgetsProvider).value ?? const [];
    final goals = ref.watch(goalProgressProvider);
    final debts = ref.watch(debtStatusesProvider);
    if (profile == null || ledger == null) return const SizedBox();

    final accounts = ledger.accounts.where((a) => !a.archived).toList();
    final activeRules = ledger.rules.where((r) => r.active).toList();
    final fixedCosts = activeRules
        .where((r) => r.type == BookingType.expense)
        .fold(0, (s, r) => s + Recurrence.monthlyEquivalent(r.amount, r.frequency));
    final budgetCount = budgets.where((b) => b.amount > 0).map((b) => b.categoryId).toSet().length;

    return CustomScrollView(
      slivers: [
        SliverSafeArea(
          bottom: false,
          sliver: SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            sliver: SliverList.list(
              children: [
                const Text('Einstellungen', style: ZText.screenTitle),
                const SizedBox(height: 20),
                ZCard(
                  onTap: () => context.push('/profile'),
                  gradient: const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFFBEAF4)]),
                  child: Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(gradient: ZColors.accentGradient, shape: BoxShape.circle),
                        child: Text(
                          profile.name.trim().isEmpty ? '✿' : profile.name.trim().characters.first.toUpperCase(),
                          style: ZText.screenTitle.copyWith(color: Colors.white, fontSize: 24),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(profile.name.trim().isEmpty ? 'Dein Profil' : profile.name, style: ZText.sectionTitle),
                            const SizedBox(height: 2),
                            Text(
                              'Fina spricht ${profile.tone.label.toLowerCase()} ${profile.tone.emoji}',
                              style: ZText.secondary,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: ZColors.textTertiary),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                const _GroupTitle('Deine Finanzen'),
                ZCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Column(
                    children: [
                      _Row(
                        emoji: '💳',
                        title: 'Konten',
                        subtitle:
                            '${accounts.length} ${accounts.length == 1 ? 'Konto' : 'Konten'} · ${Money.format(ledger.totalBalance, compact: true)}',
                        onTap: () => context.push('/accounts'),
                      ),
                      _Row(
                        emoji: '🏷️',
                        title: 'Kategorien',
                        subtitle: '${categories.where((c) => !c.archived).length} Kategorien',
                        onTap: () => context.push('/categories'),
                      ),
                      _Row(
                        emoji: '🎯',
                        title: 'Budgets',
                        subtitle: budgetCount == 0
                            ? 'Noch keine'
                            : '$budgetCount ${budgetCount == 1 ? 'Budget' : 'Budgets'} aktiv',
                        onTap: () => context.push('/budgets'),
                      ),
                      _Row(
                        emoji: '🔁',
                        title: 'Daueraufträge',
                        subtitle: activeRules.isEmpty
                            ? 'Noch keine'
                            : fixedCosts == 0
                            ? '${activeRules.length} aktiv'
                            : '${activeRules.length} aktiv · ${Money.format(fixedCosts, compact: true)} Fixkosten im Monat',
                        onTap: () => context.push('/recurring'),
                      ),
                      _Row(
                        emoji: '🐷',
                        title: 'Sparziele',
                        subtitle: goals.isEmpty ? 'Noch keine' : '${goals.where((g) => !g.completed).length} aktiv',
                        onTap: () => context.go('/savings'),
                      ),
                      _Row(
                        emoji: '🤝',
                        title: 'Schulden',
                        subtitle: debts.where((d) => !d.isSettled).isEmpty
                            ? 'Alles ausgeglichen'
                            : '${debts.where((d) => !d.isSettled).length} offen',
                        onTap: () => context.push('/debts'),
                        last: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                const _GroupTitle('Homescreen'),
                ZCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Column(
                    children: [
                      _Row(
                        emoji: '🧩',
                        title: 'Widget hinzufügen',
                        subtitle: 'Verfügbares Guthaben + „Ausgabe“ direkt auf dem Homescreen',
                        onTap: () => _addWidget(context, ref),
                      ),
                      const _Row(
                        emoji: '⚡',
                        title: 'Schnellaktionen',
                        subtitle: 'App-Icon gedrückt halten → „Ausgabe hinzufügen“',
                        last: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                const _GroupTitle('Deine Daten'),
                ZCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: _Row(
                    emoji: '🔐',
                    title: 'Export, Import & Zurücksetzen',
                    subtitle: 'Alles bleibt auf deinem Gerät – du entscheidest, wohin es geht',
                    onTap: () => context.push('/data'),
                    last: true,
                  ),
                ),
                const SizedBox(height: 30),
                Center(
                  child: Column(
                    children: [
                      Text('Zoëzas', style: ZText.amountSmall.copyWith(color: ZColors.textSecondary)),
                      const SizedBox(height: 2),
                      Text('Version 0.1.0 · ohne Konto, ohne Cloud 🔒', style: ZText.small),
                    ],
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

  Future<void> _addWidget(BuildContext context, WidgetRef ref) async {
    final pinned = await ref.read(platformIntegrationProvider).requestPinWidget();
    if (pinned || !context.mounted) return;
    await showZSheet(
      context,
      builder: (ctx) => SheetScaffold(
        title: 'Widget hinzufügen',
        primaryLabel: 'Alles klar',
        onPrimary: () => Navigator.pop(ctx),
        children: [
          Text(
            Platform.isIOS
                ? '1. Auf dem Homescreen lange auf eine freie Stelle drücken.\n'
                      '2. Oben links auf „+“ tippen.\n'
                      '3. „Zoëzas“ suchen und das Widget hinzufügen.'
                : '1. Auf dem Homescreen lange auf eine freie Stelle drücken.\n'
                      '2. „Widgets“ wählen.\n'
                      '3. „Zoëzas“ suchen und auf den Homescreen ziehen.',
            style: ZText.body.copyWith(height: 1.7),
          ),
          const SizedBox(height: 12),
          Text('Ein Tipp auf „+ Ausgabe“ öffnet direkt die Schnelleingabe.', style: ZText.secondary),
        ],
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 6, bottom: 10),
    child: Text(text.toUpperCase(), style: ZText.overline),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.emoji, required this.title, this.subtitle, this.onTap, this.last = false});

  final String emoji;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ZListRow(
          leading: EmojiTile(emoji: emoji, color: ZColors.accentSoft, size: 40),
          title: title,
          subtitle: subtitle,
          trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded, color: ZColors.textTertiary),
          onTap: onTap,
        ),
        if (!last) const Padding(padding: EdgeInsets.only(left: 58), child: Divider()),
      ],
    );
  }
}
