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
import '../../domain/ledger.dart';

/// Eine offene (oder erledigte) Schuld als Karte.
class DebtTile extends StatelessWidget {
  const DebtTile({super.key, required this.status});

  final DebtStatus status;

  @override
  Widget build(BuildContext context) {
    final d = status.debt;
    final iOwe = d.direction == DebtDirection.iOwe;
    final color = iOwe ? ZColors.warning : ZColors.positive;
    final pastel = ZColors.pastels[d.person.hashCode.abs() % ZColors.pastels.length];
    final subtitle = status.isSettled
        ? 'erledigt'
        : [
            iOwe ? 'du schuldest' : 'schuldet dir',
            if (d.dueDate != null)
              status.isOverdue ? 'überfällig seit ${Dates.short(d.dueDate!)}' : 'bis ${Dates.short(d.dueDate!)}',
            if (status.isPartial) '${Money.format(status.paid, compact: true)} bezahlt',
          ].join(' · ');
    return ZCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 18, 14),
      onTap: () => context.push('/debt/${d.id}'),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: pastel, shape: BoxShape.circle),
                child: Text(d.person.characters.first.toUpperCase(), style: ZText.sectionTitle),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.person, style: ZText.itemTitle),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: ZText.secondary.copyWith(
                        fontSize: 13,
                        color: status.isOverdue ? ZColors.negative : ZColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                Money.format(status.isSettled ? d.amount : status.remaining, compact: true),
                style: ZText.amountList.copyWith(color: status.isSettled ? ZColors.textTertiary : color),
              ),
            ],
          ),
          if (status.isPartial) ...[
            const SizedBox(height: 12),
            ZProgressBar(value: status.ratio, color: color, background: ZColors.accentSoft, height: 6),
          ],
        ],
      ),
    );
  }
}

/// Alle Schulden: offen und erledigt.
class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {
  bool _showSettled = false;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(debtStatusesProvider);
    final list = all.where((d) => d.isSettled == _showSettled).toList();
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              sliver: SliverList.list(
                children: [
                  Row(
                    children: [
                      RoundIconButton(icon: Icons.arrow_back_rounded, onPressed: () => context.pop()),
                      const Spacer(),
                      RoundIconButton(
                        icon: Icons.add_rounded,
                        onPressed: () => showDebtEditor(context),
                        tooltip: 'Neu',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('Schulden', style: ZText.screenTitle),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Wer wem was schuldet. Erst eine Zahlung verändert deinen Kontostand.',
                      style: ZText.secondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ZPill(label: 'Offen', selected: !_showSettled, onTap: () => setState(() => _showSettled = false)),
                      const SizedBox(width: 8),
                      ZPill(
                        label: 'Erledigt',
                        selected: _showSettled,
                        onTap: () => setState(() => _showSettled = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (list.isEmpty)
                    ZCard(
                      child: EmptyState(
                        emoji: _showSettled ? '🕊️' : '🤝',
                        title: _showSettled ? 'Noch nichts erledigt' : 'Alles ausgeglichen',
                        text: _showSettled ? null : 'Niemand schuldet hier irgendwem etwas. Schön!',
                      ),
                    ),
                  for (final d in list) ...[DebtTile(status: d), const SizedBox(height: 10)],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DebtDetailScreen extends ConsumerWidget {
  const DebtDetailScreen({super.key, required this.debtId});

  final int debtId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(debtStatusesProvider).firstWhereOrNull((d) => d.debt.id == debtId);
    if (status == null) return const Scaffold();
    final d = status.debt;
    final iOwe = d.direction == DebtDirection.iOwe;
    final color = iOwe ? ZColors.warning : ZColors.positive;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 10, 16, 40),
        children: [
          Row(
            children: [
              RoundIconButton(icon: Icons.arrow_back_rounded, onPressed: () => context.pop()),
              const Spacer(),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  final repo = ref.read(debtsRepoProvider);
                  switch (v) {
                    case 'edit':
                      await showDebtEditor(context, existing: d);
                    case 'close':
                      await repo.setClosed(d, d.closedAt == null);
                    case 'delete':
                      final ok = await confirm(
                        context,
                        title: 'Eintrag löschen?',
                        message:
                            'Die Schuld und ihre Zahlungen werden entfernt. Bereits erfasste Buchungen bleiben in deiner Übersicht.',
                        confirmLabel: 'Löschen',
                        destructive: true,
                      );
                      if (ok) {
                        await repo.delete(d);
                        if (context.mounted) context.pop();
                      }
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
                  PopupMenuItem(
                    value: 'close',
                    child: Text(d.closedAt == null ? 'Als erledigt markieren' : 'Wieder öffnen'),
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
          const SizedBox(height: 18),
          ZCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  iOwe ? 'DU SCHULDEST ${d.person.toUpperCase()}' : '${d.person.toUpperCase()} SCHULDET DIR',
                  style: ZText.overline,
                ),
                const SizedBox(height: 10),
                MoneyText(
                  status.isSettled ? 0 : status.remaining,
                  style: ZText.amountLarge.copyWith(fontSize: 44),
                  color: status.isSettled ? ZColors.textSecondary : color,
                ),
                const SizedBox(height: 6),
                Text(
                  status.isSettled
                      ? 'Erledigt ✓ – ursprünglich ${Money.format(d.amount)}'
                      : status.isPartial
                      ? '${Money.format(status.paid)} von ${Money.format(d.amount)} bezahlt'
                      : 'Noch nichts bezahlt',
                  style: ZText.secondary,
                ),
                if (status.isPartial) ...[
                  const SizedBox(height: 14),
                  ZProgressBar(value: status.ratio, color: color, height: 10),
                ],
                if (d.dueDate != null || (d.note ?? '').isNotEmpty) const Divider(height: 30),
                if (d.dueDate != null)
                  Text(
                    '📅  Fällig ${Dates.relative(d.dueDate!)}${status.isOverdue ? ' – überfällig' : ''}',
                    style: ZText.body.copyWith(color: status.isOverdue ? ZColors.negative : ZColors.text),
                  ),
                if ((d.note ?? '').isNotEmpty) ...[const SizedBox(height: 8), Text('📝  ${d.note}', style: ZText.body)],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!status.isSettled)
            PrimaryButton(
              label: iOwe ? 'Zahlung an ${d.person} erfassen' : 'Zahlung von ${d.person} erfassen',
              icon: Icons.payments_outlined,
              onPressed: () => showDebtPaymentSheet(context, status),
            ),
          const SizedBox(height: 26),
          SectionHeader(title: 'Zahlungen', subtitle: status.payments.isEmpty ? 'Noch keine' : null),
          for (final p in status.payments)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ZCard(
                padding: const EdgeInsets.fromLTRB(16, 12, 18, 12),
                onTap: () async {
                  final ok = await confirm(
                    context,
                    title: 'Zahlung entfernen?',
                    message: p.bookingId != null
                        ? 'Die zugehörige Buchung wird ebenfalls entfernt.'
                        : 'Nur der Eintrag wird entfernt.',
                    confirmLabel: 'Entfernen',
                    destructive: true,
                  );
                  if (ok) await ref.read(debtsRepoProvider).deletePayment(p);
                },
                child: Row(
                  children: [
                    EmojiTile(emoji: '💸', color: ZColors.accentSoft, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(Dates.relative(p.date), style: ZText.itemTitle.copyWith(fontSize: 14.5)),
                          Text(p.bookingId != null ? 'als Buchung erfasst' : 'ohne Buchung', style: ZText.small),
                        ],
                      ),
                    ),
                    Text(Money.format(p.amount), style: ZText.amountList),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Schuld anlegen oder bearbeiten.
Future<void> showDebtEditor(BuildContext context, {Debt? existing}) {
  return showZSheet(context, builder: (_) => _DebtEditor(existing: existing));
}

class _DebtEditor extends ConsumerStatefulWidget {
  const _DebtEditor({this.existing});
  final Debt? existing;

  @override
  ConsumerState<_DebtEditor> createState() => _DebtEditorState();
}

class _DebtEditorState extends ConsumerState<_DebtEditor> {
  late DebtDirection _direction = widget.existing?.direction ?? DebtDirection.iOwe;
  late final _person = TextEditingController(text: widget.existing?.person ?? '');
  late final _amount = TextEditingController(text: AmountField.textFor(widget.existing?.amount));
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late DateTime? _due = widget.existing?.dueDate;

  @override
  void dispose() {
    _person.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final person = _person.text.trim();
    final amount = AmountField.valueOf(_amount);
    if (person.isEmpty || amount == null || amount <= 0) {
      showToast(context, 'Person und Betrag bitte 🙂');
      return;
    }
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final repo = ref.read(debtsRepoProvider);
    if (widget.existing == null) {
      await repo.add(person: person, direction: _direction, amount: amount, dueDate: _due, note: note);
    } else {
      await repo.updateDebt(
        widget.existing!.copyWith(
          person: person,
          direction: _direction,
          amount: amount,
          dueDate: Value(_due),
          note: Value(note),
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: widget.existing == null ? 'Neuer Eintrag' : 'Eintrag bearbeiten',
      subtitle: 'Wird nicht als Ausgabe gezählt, solange noch kein Geld geflossen ist.',
      primaryLabel: 'Speichern',
      onPrimary: _save,
      children: [
        Row(
          children: [
            for (final d in DebtDirection.values) ...[
              Expanded(
                child: ZPill(
                  label: d == DebtDirection.iOwe ? 'Ich schulde 🫶' : 'Mir schuldet man 🤝',
                  selected: _direction == d,
                  color: ZColors.accentSoft,
                  dense: true,
                  onTap: () => setState(() => _direction = d),
                ),
              ),
              if (d == DebtDirection.iOwe) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _person,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Wer? z. B. Lisa'),
        ),
        const SizedBox(height: 12),
        AmountField(controller: _amount),
        const SizedBox(height: 12),
        Row(
          children: [
            ZPill(
              color: ZColors.accentSoft,
              leading: const Text('📅'),
              label: _due == null ? 'Ohne Fälligkeit' : 'Fällig ${Dates.short(_due!)}',
              onTap: () async {
                final d = await pickDate(context, initial: _due ?? DateTime.now().add(const Duration(days: 14)));
                if (d != null) setState(() => _due = d);
              },
            ),
            if (_due != null) TextButton(onPressed: () => setState(() => _due = null), child: const Text('Entfernen')),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          decoration: const InputDecoration(hintText: 'Notiz, z. B. „Konzertkarte“'),
        ),
      ],
    );
  }
}

/// Zahlung zu einer Schuld erfassen – optional mit echter Buchung.
Future<void> showDebtPaymentSheet(BuildContext context, DebtStatus status) {
  return showZSheet(context, builder: (_) => _PaymentSheet(status: status));
}

class _PaymentSheet extends ConsumerStatefulWidget {
  const _PaymentSheet({required this.status});
  final DebtStatus status;

  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  late final _amount = TextEditingController(text: AmountField.textFor(widget.status.remaining));
  DateTime _date = DateTime.now();
  bool _book = true;
  int? _accountId;
  int? _categoryId;

  bool get _iOwe => widget.status.debt.direction == DebtDirection.iOwe;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = AmountField.valueOf(_amount);
    if (amount == null || amount <= 0) return;
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    await ref
        .read(debtsRepoProvider)
        .addPayment(
          debt: widget.status.debt,
          amount: amount,
          date: Dates.sameDay(_date, now) ? now : DateTime(_date.year, _date.month, _date.day, 12),
          accountId: _book ? _accountId : null,
          categoryId: _book ? _categoryId : null,
        );
    if (!mounted) return;
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          amount >= widget.status.remaining ? 'Ausgeglichen – fühlt sich gut an, oder? ✨' : 'Zahlung notiert ✓',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accounts = (ref.watch(accountsProvider).value ?? const <Account>[]).where((a) => !a.archived).toList();
    final kind = _iOwe ? CategoryKind.expense : CategoryKind.income;
    final categories = (ref.watch(categoriesProvider).value ?? const <Category>[])
        .where((c) => c.kind == kind && !c.archived)
        .toList();
    _accountId ??= (accounts.firstWhereOrNull((a) => a.includeInAvailable) ?? accounts.firstOrNull)?.id;
    _categoryId ??= categories.firstWhereOrNull((c) => c.builtInKey == (_iOwe ? 'misc' : 'refund'))?.id;

    return SheetScaffold(
      title: _iOwe ? 'An ${widget.status.debt.person} gezahlt' : 'Von ${widget.status.debt.person} bekommen',
      subtitle: 'Offen: ${Money.format(widget.status.remaining)}',
      primaryLabel: 'Speichern',
      onPrimary: _save,
      children: [
        AmountField(controller: _amount),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: ZPill(
            color: ZColors.accentSoft,
            leading: const Text('📅'),
            label: Dates.relative(_date),
            onTap: () async {
              final d = await pickDate(context, initial: _date, last: DateTime.now());
              if (d != null) setState(() => _date = d);
            },
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          value: _book,
          onChanged: (v) => setState(() => _book = v),
          title: Text('Als Buchung erfassen', style: ZText.itemTitle.copyWith(fontSize: 14.5)),
          subtitle: Text(
            _iOwe
                ? 'Erscheint als Ausgabe und verringert deinen Kontostand.'
                : 'Erscheint als Einnahme und erhöht deinen Kontostand.',
            style: ZText.small,
          ),
        ),
        if (_book) ...[
          const FieldLabel('Konto'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in accounts)
                ZPill(
                  dense: true,
                  label: a.name,
                  leading: Text(a.emoji),
                  color: ZColors.accentSoft,
                  selected: _accountId == a.id,
                  onTap: () => setState(() => _accountId = a.id),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const FieldLabel('Kategorie'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in categories)
                ZPill(
                  dense: true,
                  label: c.name,
                  leading: Text(c.emoji),
                  color: ZColors.accentSoft,
                  selected: _categoryId == c.id,
                  onTap: () => setState(() => _categoryId = c.id),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
