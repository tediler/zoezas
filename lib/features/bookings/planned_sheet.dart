import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/sheets.dart';
import '../../data/providers.dart';
import '../../domain/enums.dart';
import '../../domain/ledger.dart';
import '../settings/recurring_screen.dart';
import 'booking_editor.dart';

/// Aktionen für einen offenen Posten: buchen (auch mit anderem Betrag),
/// überspringen, nur diesen Termin ändern oder den Dauerauftrag bearbeiten.
Future<void> showPlannedSheet(BuildContext context, PlannedItem item) {
  return showZSheet(context, builder: (_) => _PlannedSheet(item: item));
}

class _PlannedSheet extends ConsumerStatefulWidget {
  const _PlannedSheet({required this.item});
  final PlannedItem item;

  @override
  ConsumerState<_PlannedSheet> createState() => _PlannedSheetState();
}

class _PlannedSheetState extends ConsumerState<_PlannedSheet> {
  late final _amount = TextEditingController(text: AmountField.textFor(widget.item.amount));

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  PlannedItem get item => widget.item;

  Future<void> _confirm() async {
    final amount = AmountField.valueOf(_amount);
    if (amount == null || amount <= 0) return;
    final account = ref.read(accountsByIdProvider)[item.accountId];
    if (account == null) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(bookingsRepoProvider)
        .confirmOccurrence(item, amount: amount == item.amount ? null : amount, account: account);
    if (!mounted) return;
    Navigator.pop(context);
    messenger.showSnackBar(const SnackBar(content: Text('Gebucht ✓')));
  }

  Future<void> _skip() async {
    final ok = await confirm(
      context,
      title: 'Diesen Termin überspringen?',
      message:
          '„${item.title}“ am ${Dates.numeric(item.date)} wird ausgelassen. Der Dauerauftrag läuft danach normal weiter.',
      confirmLabel: 'Überspringen',
    );
    if (!ok || !mounted) return;
    await ref.read(bookingsRepoProvider).skipOccurrence(item);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _editThisOnly() async {
    final repo = ref.read(bookingsRepoProvider);
    final nav = Navigator.of(context);
    final rootContext = nav.context;
    final booking = item.booking ?? await repo.byId(await repo.materializeAsPlanned(item));
    nav.pop();
    if (rootContext.mounted) await showBookingEditor(rootContext, existing: booking);
  }

  Future<void> _editRule() async {
    final nav = Navigator.of(context);
    final rootContext = nav.context;
    nav.pop();
    if (item.rule != null && rootContext.mounted) await showRecurringEditor(rootContext, existing: item.rule);
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final due = !Dates.dateOnly(item.date).isAfter(today);
    final account = ref.watch(accountsByIdProvider)[item.accountId];
    final category = ref.watch(categoriesByIdProvider)[item.categoryId];
    final verb = switch (item.type) {
      BookingType.expense => 'Ausgabe',
      BookingType.income => 'Einnahme',
      BookingType.transfer => 'Umbuchung',
    };

    return SheetScaffold(
      title: item.title,
      subtitle: [
        verb,
        if (category != null) '${category.emoji} ${category.name}',
        if (account != null) account.name,
        if (item.rule != null) item.rule!.frequency.label,
      ].join(' · '),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: ZColors.accentSoft, borderRadius: BorderRadius.circular(20)),
          child: Row(
            children: [
              const Text('🗓️', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  due
                      ? 'Fällig am ${Dates.numeric(item.date)}. Ist das Geld schon geflossen?'
                      : 'Geplant für ${Dates.longDay(item.date)} (${Dates.distance(item.date, now: today)}).',
                  style: ZText.body,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const FieldLabel('Betrag'),
        AmountField(controller: _amount),
        const SizedBox(height: 22),
        PrimaryButton(label: due ? 'Ja, buchen' : 'Jetzt schon buchen', icon: Icons.check_rounded, onPressed: _confirm),
        const SizedBox(height: 10),
        Row(
          children: [
            if (item.isRecurring) ...[
              Expanded(
                child: SoftButton(label: 'Überspringen', onPressed: _skip),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: SoftButton(label: item.isRecurring ? 'Nur diesen ändern' : 'Bearbeiten', onPressed: _editThisOnly),
            ),
          ],
        ),
        if (item.rule != null) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _editRule,
              child: Text(
                'Dauerauftrag bearbeiten · ${Money.format(item.rule!.amount, compact: true)} ${item.rule!.frequency.phrase}',
              ),
            ),
          ),
        ],
      ],
    );
  }
}
