import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/sheets.dart';
import '../../data/providers.dart';
import '../../domain/budgets.dart';
import '../../domain/enums.dart';
import 'budget_row.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final month = YearMonth.of(today);
    final statuses = ref.watch(budgetStatusProvider(month));
    final profile = ref.watch(profileProvider);
    if (profile == null) return const Scaffold();
    final total = statuses.where((s) => s.isTotal).firstOrNull;
    final perCategory = statuses.where((s) => !s.isTotal).toList();
    final categoriesTotal = perCategory.fold(0, (s, b) => s + b.limit);

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 10, 16, 40),
        children: [
          Row(
            children: [
              RoundIconButton(icon: Icons.arrow_back_rounded, onPressed: () => context.pop()),
              const Spacer(),
              RoundIconButton(
                icon: Icons.add_rounded,
                onPressed: () => _pickCategory(context, ref),
                tooltip: 'Budget hinzufügen',
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('Budgets', style: ZText.screenTitle),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Wie viel möchtest du im ${month.monthName} ausgeben? Budgets gelten ab diesem Monat, bis du sie änderst.',
              style: ZText.secondary,
            ),
          ),
          const SizedBox(height: 20),
          ZCard(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
            child: total == null
                ? ZListRow(
                    leading: EmojiTile(emoji: '🌸', color: ZColors.accentLight, size: 40),
                    title: 'Monatsbudget festlegen',
                    subtitle: 'Ein Rahmen für alle Ausgaben zusammen',
                    trailing: const Icon(Icons.chevron_right_rounded, color: ZColors.textTertiary),
                    onTap: () => showBudgetEditor(context, categoryId: null),
                  )
                : BudgetRow(
                    status: total,
                    tone: profile.tone,
                    onTap: () => showBudgetEditor(context, categoryId: null),
                  ),
          ),
          const SizedBox(height: 22),
          SectionHeader(
            title: 'Nach Kategorie',
            subtitle: perCategory.isEmpty ? null : 'Zusammen ${Money.format(categoriesTotal, compact: true)} geplant',
          ),
          if (perCategory.isEmpty)
            ZCard(
              onTap: () => _pickCategory(context, ref),
              child: const EmptyState(
                emoji: '🍓',
                title: 'Noch keine Kategorie-Budgets',
                text: 'Zum Beispiel 250 € für Essen oder 150 € fürs Online-Shopping.',
              ),
            )
          else
            ZCard(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
              child: Column(
                children: [
                  for (final s in perCategory)
                    BudgetRow(
                      status: s,
                      tone: profile.tone,
                      onTap: () => showBudgetEditor(context, categoryId: s.category!.id),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          SoftButton(
            label: 'Budget für Kategorie',
            icon: Icons.add_rounded,
            onPressed: () => _pickCategory(context, ref),
          ),
          const SizedBox(height: 18),
          Text(
            'Der helle Teil des Balkens zeigt Geplantes, das noch kommt. Gezählt wird nur, was wirklich ausgegeben wurde.',
            style: ZText.small,
          ),
        ],
      ),
    );
  }

  Future<void> _pickCategory(BuildContext context, WidgetRef ref) async {
    final categories = (ref.read(categoriesProvider).value ?? const <Category>[])
        .where((c) => c.kind == CategoryKind.expense && !c.archived)
        .toList();
    final id = await showZSheet<int>(
      context,
      builder: (ctx) => SheetScaffold(
        title: 'Für welche Kategorie?',
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in categories)
                ZPill(
                  label: c.name,
                  leading: Text(c.emoji),
                  color: Color(c.color),
                  onTap: () => Navigator.pop(ctx, c.id),
                ),
            ],
          ),
        ],
      ),
    );
    if (id != null && context.mounted) await showBudgetEditor(context, categoryId: id);
  }
}

/// Budget für eine Kategorie (oder das Gesamtbudget bei null) festlegen.
Future<void> showBudgetEditor(BuildContext context, {required int? categoryId}) {
  return showZSheet(context, builder: (_) => _BudgetEditor(categoryId: categoryId));
}

class _BudgetEditor extends ConsumerStatefulWidget {
  const _BudgetEditor({required this.categoryId});
  final int? categoryId;

  @override
  ConsumerState<_BudgetEditor> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends ConsumerState<_BudgetEditor> {
  late final TextEditingController _amount;
  late final YearMonth _month = YearMonth.of(ref.read(todayProvider));
  late final int? _current;

  @override
  void initState() {
    super.initState();
    final rows = ref.read(budgetsProvider).value ?? const <Budget>[];
    _current = BudgetLogic.effectiveLimit(rows, widget.categoryId, _month);
    _amount = TextEditingController(text: AmountField.textFor(_current));
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save(int amount) async {
    await ref.read(budgetsRepoProvider).setBudget(categoryId: widget.categoryId, amount: amount, from: _month);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.categoryId == null ? null : ref.watch(categoriesByIdProvider)[widget.categoryId];
    final summary = ref.watch(monthSummaryProvider(_month));
    final spent = summary == null
        ? 0
        : widget.categoryId == null
        ? summary.expenses
        : summary.flow.expenseByCategory[widget.categoryId] ?? 0;
    final lastMonth = ref.watch(monthSummaryProvider(_month.previous));
    final lastSpent = lastMonth == null
        ? 0
        : widget.categoryId == null
        ? lastMonth.expenses
        : lastMonth.flow.expenseByCategory[widget.categoryId] ?? 0;

    return SheetScaffold(
      title: category == null ? 'Monatsbudget' : '${category.emoji} ${category.name}',
      subtitle: 'Gilt ab ${_month.label}.',
      primaryLabel: 'Speichern',
      onPrimary: () {
        final v = AmountField.valueOf(_amount);
        if (v != null && v > 0) _save(v);
      },
      secondary: _current == null
          ? null
          : TextButton(
              onPressed: () => _save(0),
              child: const Text('Budget entfernen', style: TextStyle(color: ZColors.negative)),
            ),
      children: [
        AmountField(controller: _amount, autofocus: true),
        const SizedBox(height: 12),
        Text(
          'Bisher im ${_month.monthName}: ${Money.format(spent)} · im ${_month.previous.monthName}: ${Money.format(lastSpent)}',
          style: ZText.small,
        ),
        if (lastSpent > 0) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final factor in [0.9, 1.0, 1.1])
                ZPill(
                  dense: true,
                  color: ZColors.accentSoft,
                  label: Money.format(((lastSpent * factor) / 500).round() * 500, compact: true),
                  onTap: () => _amount.text = AmountField.textFor(((lastSpent * factor) / 500).round() * 500),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
