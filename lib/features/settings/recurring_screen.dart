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
import '../../domain/recurrence.dart';

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerProvider);
    if (ledger == null) return const Scaffold();
    final rules = ledger.rules;
    int monthly(BookingType t) => rules
        .where((r) => r.active && r.type == t)
        .fold(0, (s, r) => s + Recurrence.monthlyEquivalent(r.amount, r.frequency));
    final fixed = monthly(BookingType.expense);
    final incoming = monthly(BookingType.income);
    final groups = [
      ('Einnahmen', rules.where((r) => r.type == BookingType.income).toList()),
      ('Ausgaben', rules.where((r) => r.type == BookingType.expense).toList()),
      ('Umbuchungen', rules.where((r) => r.type == BookingType.transfer).toList()),
    ];

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
                onPressed: () => showRecurringEditor(context),
                tooltip: 'Neuer Dauerauftrag',
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('Daueraufträge', style: ZText.screenTitle),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('Was regelmäßig kommt und geht – automatisch in deiner Planung.', style: ZText.secondary),
          ),
          const SizedBox(height: 18),
          ZCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: _Fig(label: 'Fixkosten / Monat', amount: fixed),
                ),
                Expanded(
                  child: _Fig(label: 'Feste Einnahmen', amount: incoming, color: ZColors.positive),
                ),
              ],
            ),
          ),
          if (incoming > 0) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                'Nach Fixkosten bleiben dir rechnerisch ${Money.format(incoming - fixed, compact: true)} im Monat.',
                style: ZText.small,
              ),
            ),
          ],
          if (rules.isEmpty) ...[
            const SizedBox(height: 18),
            ZCard(
              onTap: () => showRecurringEditor(context),
              child: const EmptyState(
                emoji: '🔁',
                title: 'Noch keine Daueraufträge',
                text: 'Miete, Abos, Fitnessstudio, Gehalt – einmal anlegen, nie wieder vergessen.',
              ),
            ),
          ],
          for (final (title, list) in groups)
            if (list.isNotEmpty) ...[
              const SizedBox(height: 22),
              SectionHeader(title: title),
              for (final r in list) ...[_RuleCard(rule: r, ledger: ledger), const SizedBox(height: 10)],
            ],
        ],
      ),
    );
  }
}

class _Fig extends StatelessWidget {
  const _Fig({required this.label, required this.amount, this.color});
  final String label;
  final int amount;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: ZText.small),
      const SizedBox(height: 4),
      MoneyText(amount, style: ZText.amountMedium, color: color, showCents: false),
    ],
  );
}

class _RuleCard extends ConsumerWidget {
  const _RuleCard({required this.rule, required this.ledger});

  final RecurringRule rule;
  final Ledger ledger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = rule;
    final category = ref.watch(categoriesByIdProvider)[r.categoryId];
    final accounts = ref.watch(accountsByIdProvider);
    final next = ledger.nextOccurrence(r);
    final emoji = r.type == BookingType.transfer ? '↔️' : (category?.emoji ?? '🔁');
    final color = r.type == BookingType.transfer
        ? ZColors.pastels[2]
        : (category != null ? Color(category.color) : ZColors.pastels[1]);
    final details = [
      r.dayOfMonth == 31 ? '${r.frequency.label} · Monatsende' : r.frequency.label,
      if (!r.active) 'pausiert' else if (next != null) 'nächster ${Dates.short(next)}' else 'beendet',
      if (r.type == BookingType.transfer) '${accounts[r.accountId]?.name} → ${accounts[r.toAccountId]?.name}',
      if (!r.autoBook) 'mit Bestätigung',
    ].join(' · ');
    return Opacity(
      opacity: r.active ? 1 : 0.55,
      child: ZCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 18, 14),
        onTap: () => showRecurringEditor(context, existing: r),
        child: Row(
          children: [
            EmojiTile(emoji: emoji, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.title, style: ZText.itemTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(details, style: ZText.secondary.copyWith(fontSize: 12.5), maxLines: 2),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(switch (r.type) {
              BookingType.expense => Money.formatFlow(r.amount, isOutflow: true),
              BookingType.income => Money.formatFlow(r.amount, isOutflow: false),
              BookingType.transfer => Money.format(r.amount, compact: true),
            }, style: ZText.amountList.copyWith(color: r.type == BookingType.income ? ZColors.positive : ZColors.text)),
          ],
        ),
      ),
    );
  }
}

/// Dauerauftrag anlegen oder bearbeiten.
Future<void> showRecurringEditor(BuildContext context, {RecurringRule? existing}) {
  return showZSheet(context, expand: true, builder: (_) => _RecurringEditor(existing: existing));
}

class _RecurringEditor extends ConsumerStatefulWidget {
  const _RecurringEditor({this.existing});
  final RecurringRule? existing;

  @override
  ConsumerState<_RecurringEditor> createState() => _RecurringEditorState();
}

class _RecurringEditorState extends ConsumerState<_RecurringEditor> {
  RecurringRule? get r => widget.existing;
  late BookingType _type = r?.type ?? BookingType.expense;
  late final _title = TextEditingController(text: r?.title ?? '');
  late final _amount = TextEditingController(text: AmountField.textFor(r?.amount));
  late int? _categoryId = r?.categoryId;
  late int? _accountId = r?.accountId;
  late int? _toAccountId = r?.toAccountId;
  late Frequency _frequency = r?.frequency ?? Frequency.monthly;
  late bool _monthEnd = r?.dayOfMonth == 31;
  late bool _autoBook = r?.autoBook ?? true;
  late bool _active = r?.active ?? true;
  late DateTime? _end = r?.endDate;
  late DateTime _next;
  late final DateTime _originalNext;
  DateTime? _minDate;

  @override
  void initState() {
    super.initState();
    final ledger = ref.read(ledgerProvider);
    final today = ref.read(todayProvider);
    if (r != null && ledger != null) {
      _next = ledger.nextOccurrence(r!) ?? today;
      final last = ledger.lastHandledOccurrence(r!.id);
      if (last != null) _minDate = last.add(const Duration(days: 1));
    } else {
      _next = today;
    }
    _originalNext = _next;
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  bool get _monthly => _frequency != Frequency.weekly && _frequency != Frequency.biweekly;

  Future<void> _save() async {
    final amount = AmountField.valueOf(_amount);
    final title = _title.text.trim();
    if (amount == null || amount <= 0 || title.isEmpty) {
      showToast(context, 'Name und Betrag bitte 🙂');
      return;
    }
    final accounts = (ref.read(accountsProvider).value ?? const <Account>[]).where((a) => !a.archived).toList();
    final accountId =
        _accountId ?? accounts.firstWhereOrNull((a) => a.includeInAvailable)?.id ?? accounts.firstOrNull?.id;
    if (accountId == null) return;
    if (_type == BookingType.transfer && (_toAccountId == null || _toAccountId == accountId)) {
      showToast(context, 'Wähle zwei verschiedene Konten.');
      return;
    }
    final dayOfMonth = _monthly && _monthEnd ? 31 : null;
    final start = dayOfMonth == null ? _next : Recurrence.firstMonthlyOnOrAfter(_next, 31);
    final repo = ref.read(recurringRepoProvider);
    if (r == null) {
      await repo.add(
        type: _type,
        amount: amount,
        accountId: accountId,
        toAccountId: _toAccountId,
        categoryId: _categoryId,
        title: title,
        frequency: _frequency,
        startDate: start,
        endDate: _end,
        dayOfMonth: dayOfMonth,
        autoBook: _autoBook,
      );
    } else {
      final scheduleChanged =
          _frequency != r!.frequency || !Dates.sameDay(_next, _originalNext) || dayOfMonth != r!.dayOfMonth;
      await repo.updateRule(
        r!.copyWith(
          type: _type,
          amount: amount,
          accountId: accountId,
          toAccountId: Value(_toAccountId),
          categoryId: Value(_categoryId),
          title: title,
          frequency: _frequency,
          endDate: Value(_end),
          dayOfMonth: Value(dayOfMonth),
          autoBook: _autoBook,
          active: _active,
        ),
        nextDate: scheduleChanged ? start : null,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Dauerauftrag löschen?',
      message: 'Künftige Termine verschwinden aus der Planung. Bereits gebuchte Zahlungen bleiben erhalten.',
      confirmLabel: 'Löschen',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(recurringRepoProvider).delete(r!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accounts = (ref.watch(accountsProvider).value ?? const <Account>[]).where((a) => !a.archived).toList();
    final kind = _type == BookingType.income ? CategoryKind.income : CategoryKind.expense;
    final categories = (ref.watch(categoriesProvider).value ?? const <Category>[])
        .where((c) => c.kind == kind && !c.archived)
        .toList();
    _accountId ??= accounts.firstWhereOrNull((a) => a.includeInAvailable)?.id ?? accounts.firstOrNull?.id;
    if (_type == BookingType.transfer) {
      _toAccountId ??=
          accounts.firstWhereOrNull((a) => a.id != _accountId && a.type == AccountType.savings)?.id ??
          accounts.firstWhereOrNull((a) => a.id != _accountId)?.id;
    }
    final today = ref.watch(todayProvider);

    return SheetScaffold(
      title: r == null ? 'Neuer Dauerauftrag' : 'Dauerauftrag bearbeiten',
      subtitle: r == null ? null : 'Änderungen gelten ab dem nächsten Termin. Gebuchtes bleibt, wie es ist.',
      primaryLabel: 'Speichern',
      onPrimary: _save,
      secondary: r == null
          ? null
          : TextButton(
              onPressed: _delete,
              child: const Text('Löschen', style: TextStyle(color: ZColors.negative)),
            ),
      children: [
        Row(
          children: [
            for (final t in BookingType.values) ...[
              Expanded(
                child: ZPill(
                  dense: true,
                  label: t.label,
                  color: ZColors.accentSoft,
                  selected: _type == t,
                  onTap: () => setState(() {
                    if (_type != t) _categoryId = null;
                    _type = t;
                  }),
                ),
              ),
              if (t != BookingType.transfer) const SizedBox(width: 6),
            ],
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _title,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: switch (_type) {
              BookingType.expense => 'z. B. Miete, Netflix, Fitnessstudio',
              BookingType.income => 'z. B. Gehalt',
              BookingType.transfer => 'z. B. Sparplan',
            },
          ),
        ),
        const SizedBox(height: 12),
        AmountField(controller: _amount),
        if (_type != BookingType.transfer) ...[
          const SizedBox(height: 16),
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
        const SizedBox(height: 16),
        FieldLabel(_type == BookingType.transfer ? 'Von' : 'Konto'),
        _AccountWrap(accounts: accounts, selected: _accountId, onSelect: (id) => setState(() => _accountId = id)),
        if (_type == BookingType.transfer) ...[
          const SizedBox(height: 12),
          const FieldLabel('Nach'),
          _AccountWrap(
            accounts: accounts,
            selected: _toAccountId,
            disabled: _accountId,
            onSelect: (id) => setState(() => _toAccountId = id),
          ),
        ],
        const SizedBox(height: 16),
        const FieldLabel('Rhythmus'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in Frequency.values)
              ZPill(
                dense: true,
                label: f.label,
                color: ZColors.accentSoft,
                selected: _frequency == f,
                onTap: () => setState(() => _frequency = f),
              ),
          ],
        ),
        const SizedBox(height: 16),
        FieldLabel(r == null ? 'Erster Termin' : 'Nächster Termin'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ZPill(
              color: ZColors.accentSoft,
              leading: const Text('📅'),
              label: _monthly && _monthEnd ? 'Monatsende ab ${YearMonth.of(_next).monthName}' : Dates.relative(_next),
              onTap: () async {
                final d = await pickDate(context, initial: _next, first: _minDate);
                if (d != null) setState(() => _next = d);
              },
            ),
            if (_monthly)
              ZPill(
                dense: true,
                color: ZColors.accentSoft,
                selected: _monthEnd,
                label: 'Immer am Monatsende',
                onTap: () => setState(() => _monthEnd = !_monthEnd),
              ),
          ],
        ),
        if (r == null && _next.isBefore(today)) ...[
          const SizedBox(height: 8),
          Text(
            _autoBook
                ? 'Termine in der Vergangenheit werden sofort gebucht. Liegen sie vor dem Start eines Kontos, zählen sie nur für die Statistik.'
                : 'Termine in der Vergangenheit erscheinen als „fällig“.',
            style: ZText.small,
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            ZPill(
              dense: true,
              color: ZColors.accentSoft,
              leading: const Text('🏁'),
              label: _end == null ? 'Ohne Enddatum' : 'Endet ${Dates.short(_end!)}',
              onTap: () async {
                final d = await pickDate(
                  context,
                  initial: _end ?? DateTime(_next.year + 1, _next.month, _next.day),
                  first: _next,
                );
                if (d != null) setState(() => _end = d);
              },
            ),
            if (_end != null) TextButton(onPressed: () => setState(() => _end = null), child: const Text('Entfernen')),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          value: _autoBook,
          onChanged: (v) => setState(() => _autoBook = v),
          title: Text('Automatisch buchen', style: ZText.itemTitle.copyWith(fontSize: 14.5)),
          subtitle: Text(
            _autoBook ? 'Am Fälligkeitstag wird automatisch gebucht.' : 'Fina fragt am Fälligkeitstag kurz nach.',
            style: ZText.small,
          ),
        ),
        if (r != null)
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
            title: Text('Aktiv', style: ZText.itemTitle.copyWith(fontSize: 14.5)),
            subtitle: Text(
              _active ? 'Termine erscheinen in der Planung.' : 'Pausiert – keine neuen Termine.',
              style: ZText.small,
            ),
          ),
      ],
    );
  }
}

class _AccountWrap extends StatelessWidget {
  const _AccountWrap({required this.accounts, required this.selected, required this.onSelect, this.disabled});

  final List<Account> accounts;
  final int? selected;
  final int? disabled;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final a in accounts)
          Opacity(
            opacity: a.id == disabled ? 0.35 : 1,
            child: ZPill(
              dense: true,
              label: a.name,
              leading: Text(a.emoji),
              color: ZColors.accentSoft,
              selected: selected == a.id,
              onTap: a.id == disabled ? null : () => onSelect(a.id),
            ),
          ),
      ],
    );
  }
}
