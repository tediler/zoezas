import 'package:collection/collection.dart';
import 'package:drift/drift.dart' show Value;
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
import '../../domain/enums.dart';
import '../../domain/fina.dart';
import '../../domain/ledger.dart';

/// Große, emotionale Zielkarte.
class GoalCard extends StatelessWidget {
  const GoalCard({super.key, required this.progress, required this.tone});

  final GoalProgress progress;
  final FinaTone tone;

  @override
  Widget build(BuildContext context) {
    final g = progress.goal;
    final color = Color(g.color);
    final strong = ZColors.strongFor(color);
    return ZCard(
      padding: const EdgeInsets.all(20),
      onTap: () => context.push('/goal/${g.id}'),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(color, Colors.white, 0.25)!, Colors.white],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: strong.withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 5)),
                  ],
                ),
                child: Text(g.emoji, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.name, style: ZText.sectionTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      g.targetDate == null ? 'ohne festes Datum' : 'bis ${DateFormatX.monthYear(g.targetDate!)}',
                      style: ZText.small,
                    ),
                  ],
                ),
              ),
              Text(
                '${(progress.ratio * 100).floor()} %',
                style: ZText.amountSmall.copyWith(color: strong, fontSize: 20),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              MoneyText(progress.saved, style: ZText.amountMedium.copyWith(fontSize: 28), showCents: false),
              const SizedBox(width: 6),
              Text('von ${Money.format(progress.target, compact: true)}', style: ZText.secondary),
            ],
          ),
          const SizedBox(height: 12),
          ZProgressBar(
            value: progress.ratio,
            height: 14,
            // Neutrale, leicht dunkle Spur – sichtbar auf jeder Zielfarbe.
            background: ZColors.text.withValues(alpha: 0.07),
            gradient: LinearGradient(colors: [Color.lerp(strong, Colors.white, 0.25)!, strong]),
          ),
          const SizedBox(height: 12),
          Text(Fina.goalMessage(progress, tone), style: ZText.secondary.copyWith(color: ZColors.text)),
          if (progress.monthlyNeeded != null) ...[
            const SizedBox(height: 4),
            Text(
              '≈ ${Money.format(progress.monthlyNeeded!, compact: true)} pro Monat bis zum Ziel',
              style: ZText.small,
            ),
          ],
        ],
      ),
    );
  }
}

abstract final class DateFormatX {
  static String monthYear(DateTime d) => YearMonth.of(d).label;
}

/// Ziel anlegen oder bearbeiten.
Future<void> showGoalEditor(BuildContext context, {SavingsGoal? existing}) {
  return showZSheet(context, builder: (_) => _GoalEditor(existing: existing));
}

class _GoalEditor extends ConsumerStatefulWidget {
  const _GoalEditor({this.existing});
  final SavingsGoal? existing;

  @override
  ConsumerState<_GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends ConsumerState<_GoalEditor> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _target = TextEditingController(text: AmountField.textFor(widget.existing?.targetAmount));
  late String _emoji = widget.existing?.emoji ?? '🌴';
  late int _color = widget.existing?.color ?? ZColors.pastels[3].toARGB32();
  late DateTime? _date = widget.existing?.targetDate;

  static const _ideas = [
    ('🌴', 'Urlaub'),
    ('🚗', 'Auto'),
    ('📱', 'Neues Handy'),
    ('🏡', 'Eigene Wohnung'),
    ('🛟', 'Notgroschen'),
    ('🎓', 'Weiterbildung'),
  ];

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final target = AmountField.valueOf(_target);
    if (name.isEmpty || target == null || target <= 0) {
      showToast(context, 'Name und Zielbetrag bitte 🙂');
      return;
    }
    final repo = ref.read(goalsRepoProvider);
    if (widget.existing == null) {
      await repo.addGoal(name: name, emoji: _emoji, color: _color, target: target, targetDate: _date);
    } else {
      await repo.updateGoal(
        widget.existing!.copyWith(
          name: name,
          emoji: _emoji,
          color: _color,
          targetAmount: target,
          targetDate: Value(_date),
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: widget.existing == null ? 'Neues Sparziel' : 'Ziel bearbeiten',
      subtitle: widget.existing == null ? 'Worauf möchtest du hinsparen?' : null,
      primaryLabel: 'Speichern',
      onPrimary: _save,
      children: [
        if (widget.existing == null) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (e, n) in _ideas)
                ZPill(
                  dense: true,
                  color: ZColors.accentSoft,
                  leading: Text(e),
                  label: n,
                  onTap: () => setState(() {
                    _emoji = e;
                    _name.text = n;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            GestureDetector(
              onTap: () async {
                final e = await pickEmoji(context, current: _emoji);
                if (e != null) setState(() => _emoji = e);
              },
              child: EmojiTile(emoji: _emoji, color: Color(_color), size: 56),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Name des Ziels'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const FieldLabel('Zielbetrag'),
        AmountField(controller: _target),
        const SizedBox(height: 16),
        const FieldLabel('Bis wann? (optional)'),
        Row(
          children: [
            ZPill(
              color: ZColors.accentSoft,
              leading: const Text('📅'),
              label: _date == null ? 'Kein Datum' : DateFormatX.monthYear(_date!),
              onTap: () async {
                final now = DateTime.now();
                final d = await pickDate(context, initial: _date ?? DateTime(now.year, now.month + 6, 1), first: now);
                if (d != null) setState(() => _date = d);
              },
            ),
            if (_date != null) ...[
              const SizedBox(width: 8),
              TextButton(onPressed: () => setState(() => _date = null), child: const Text('Entfernen')),
            ],
          ],
        ),
        const SizedBox(height: 16),
        const FieldLabel('Farbe'),
        PastelPicker(value: _color, onChanged: (c) => setState(() => _color = c)),
      ],
    );
  }
}

/// Geld zurücklegen oder entnehmen.
Future<void> showContributionSheet(BuildContext context, SavingsGoal goal, {bool withdraw = false}) {
  return showZSheet(
    context,
    builder: (_) => _ContributionSheet(goal: goal, withdraw: withdraw),
  );
}

class _ContributionSheet extends ConsumerStatefulWidget {
  const _ContributionSheet({required this.goal, required this.withdraw});
  final SavingsGoal goal;
  final bool withdraw;

  @override
  ConsumerState<_ContributionSheet> createState() => _ContributionSheetState();
}

class _ContributionSheetState extends ConsumerState<_ContributionSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  int? _heldIn;
  int? _spendable;
  bool _move = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = AmountField.valueOf(_amount);
    if (amount == null || amount <= 0) {
      showToast(context, 'Wie viel denn? 🙂');
      return;
    }
    final accounts = ref.read(accountsByIdProvider);
    final held = accounts[_heldIn];
    final doMove = _move && held != null && !held.includeInAvailable && _spendable != null;
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(goalsRepoProvider)
        .contribute(
          goal: widget.goal,
          amount: widget.withdraw ? -amount : amount,
          heldInAccountId: _heldIn,
          moveFrom: doMove ? _spendable : null,
          moveTo: doMove ? _heldIn : null,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        );
    if (!mounted) return;
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          widget.withdraw
              ? 'Entnommen – alles gut 🌷'
              : '${Money.format(amount, compact: true)} für ${widget.goal.name} ${widget.goal.emoji}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accounts = (ref.watch(accountsProvider).value ?? const <Account>[]).where((a) => !a.archived).toList();
    _heldIn ??= (accounts.firstWhereOrNull((a) => a.type == AccountType.savings) ?? accounts.firstOrNull)?.id;
    _spendable ??= accounts.firstWhereOrNull((a) => a.includeInAvailable)?.id;
    final held = accounts.firstWhereOrNull((a) => a.id == _heldIn);
    final canMove = held != null && !held.includeInAvailable && _spendable != null;
    final spendableAccounts = accounts.where((a) => a.includeInAvailable).toList();

    return SheetScaffold(
      title: widget.withdraw ? 'Aus ${widget.goal.name} entnehmen' : 'Für ${widget.goal.name} zurücklegen',
      subtitle: widget.withdraw
          ? 'Passiert. Das Geld ist dann wieder frei verfügbar.'
          : 'Zurückgelegtes ist keine Ausgabe – es ist nur für dein Ziel reserviert.',
      primaryLabel: widget.withdraw ? 'Entnehmen' : 'Zurücklegen',
      onPrimary: _save,
      children: [
        AmountField(controller: _amount, autofocus: true),
        const SizedBox(height: 16),
        FieldLabel(widget.withdraw ? 'Von welchem Konto?' : 'Wo liegt das Geld?'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in accounts)
              ZPill(
                label: a.name,
                leading: Text(a.emoji),
                color: ZColors.accentSoft,
                selected: a.id == _heldIn,
                onTap: () => setState(() => _heldIn = a.id),
              ),
          ],
        ),
        if (held != null && held.includeInAvailable) ...[
          const SizedBox(height: 10),
          Text(
            widget.withdraw
                ? 'Dein verfügbares Guthaben steigt wieder um diesen Betrag.'
                : 'Das Geld bleibt auf „${held.name}“, zählt aber nicht mehr zu deinem verfügbaren Guthaben.',
            style: ZText.small,
          ),
        ],
        if (canMove) ...[
          const SizedBox(height: 14),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            value: _move,
            onChanged: (v) => setState(() => _move = v),
            title: Text(
              widget.withdraw ? 'Zurück auf ein Ausgabenkonto überweisen' : 'Jetzt auch dorthin überweisen',
              style: ZText.itemTitle.copyWith(fontSize: 14.5),
            ),
            subtitle: Text(
              widget.withdraw
                  ? 'Erzeugt eine Umbuchung zurück.'
                  : 'Erzeugt eine Umbuchung – keine Ausgabe, nur eine Verschiebung.',
              style: ZText.small,
            ),
          ),
          if (_move && spendableAccounts.length > 1)
            Wrap(
              spacing: 8,
              children: [
                for (final a in spendableAccounts)
                  ZPill(
                    dense: true,
                    label: '${widget.withdraw ? 'nach' : 'von'} ${a.name}',
                    color: ZColors.accentSoft,
                    selected: a.id == _spendable,
                    onTap: () => setState(() => _spendable = a.id),
                  ),
              ],
            ),
        ],
        const SizedBox(height: 14),
        TextField(
          controller: _note,
          decoration: const InputDecoration(hintText: 'Notiz (optional)'),
        ),
      ],
    );
  }
}

/// Kurze Beschreibung einer Einzahlung für Listen.
String contributionLabel(GoalContribution c, Map<int, Account> accounts) {
  final where = accounts[c.heldInAccountId]?.name;
  final parts = [Dates.relative(c.date), ?where, if (c.bookingId != null) 'mit Umbuchung'];
  return parts.join(' · ');
}
