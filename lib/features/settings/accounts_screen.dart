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
import '../../core/widgets/sheets.dart';
import '../../data/providers.dart';
import '../../domain/enums.dart';
import '../../domain/ledger.dart';
import '../bookings/booking_editor.dart';
import '../bookings/booking_tile.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerProvider);
    if (ledger == null) return const Scaffold();
    final active = ledger.accounts.where((a) => !a.archived).toList();
    final archived = ledger.accounts.where((a) => a.archived).toList();

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
                onPressed: () => showAccountEditor(context),
                tooltip: 'Konto hinzufügen',
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('Konten', style: ZText.screenTitle),
          ),
          const SizedBox(height: 16),
          ZCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: _Fig(label: 'Insgesamt', amount: ledger.totalBalance),
                ),
                Expanded(
                  child: _Fig(label: 'Davon verfügbar', amount: ledger.available, color: ZColors.accentDeep),
                ),
              ],
            ),
          ),
          if (ledger.reservedInSpendable > 0) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '${Money.format(ledger.reservedInSpendable, compact: true)} liegen auf Ausgabenkonten, sind aber für Sparziele reserviert.',
                style: ZText.small,
              ),
            ),
          ],
          const SizedBox(height: 18),
          for (final a in active) ...[_AccountCard(account: a, ledger: ledger), const SizedBox(height: 10)],
          const SizedBox(height: 6),
          SoftButton(label: 'Konto hinzufügen', icon: Icons.add_rounded, onPressed: () => showAccountEditor(context)),
          if (archived.isNotEmpty) ...[
            const SizedBox(height: 26),
            const SectionHeader(title: 'Archiviert'),
            for (final a in archived) ...[
              Opacity(
                opacity: 0.6,
                child: _AccountCard(account: a, ledger: ledger),
              ),
              const SizedBox(height: 10),
            ],
          ],
          const SizedBox(height: 18),
          Text(
            'Konten, die zum Verfügbaren zählen (z. B. Girokonto, Bargeld), bilden dein verfügbares Guthaben. '
            'Sparkonten zählen zum Gesamtvermögen, aber nicht zum Verfügbaren.',
            style: ZText.small,
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account, required this.ledger});

  final Account account;
  final Ledger ledger;

  @override
  Widget build(BuildContext context) {
    final a = account;
    final balance = ledger.balanceOf(a.id);
    final reserved = ledger.reservedByAccount[a.id] ?? 0;
    return ZCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 18, 14),
      onTap: () => context.push('/account/${a.id}'),
      child: Row(
        children: [
          EmojiTile(emoji: a.emoji, color: Color(a.color), size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.name, style: ZText.itemTitle),
                const SizedBox(height: 2),
                Text(
                  [
                    a.type.label,
                    if (a.includeInAvailable) 'zählt zum Verfügbaren',
                    if (reserved > 0) '${Money.format(reserved, compact: true)} für Ziele',
                  ].join(' · '),
                  style: ZText.small,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          MoneyText(balance, style: ZText.amountSmall, color: balance < 0 ? ZColors.negative : null),
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
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: MoneyText(amount, style: ZText.amountMedium, color: color),
      ),
    ],
  );
}

class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({super.key, required this.accountId});

  final int accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerProvider);
    final account = ledger?.account(accountId);
    if (ledger == null || account == null) return const Scaffold();
    final balance = ledger.balanceOf(accountId);
    final bookings = ledger.bookings
        .where((b) => b.status == BookingStatus.booked && (b.accountId == accountId || b.toAccountId == accountId))
        .sorted((a, b) => b.date.compareTo(a.date));

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
                        icon: Icons.edit_outlined,
                        onPressed: () => showAccountEditor(context, existing: account),
                        tooltip: 'Bearbeiten',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      EmojiTile(emoji: account.emoji, color: Color(account.color), size: 56),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(account.name, style: ZText.screenTitle.copyWith(fontSize: 25)),
                            Text(account.type.label, style: ZText.secondary),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ZCard(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('KONTOSTAND', style: ZText.overline),
                        const SizedBox(height: 8),
                        MoneyText(
                          balance,
                          style: ZText.amountLarge.copyWith(fontSize: 42),
                          color: balance < 0 ? ZColors.negative : null,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Start: ${Money.format(account.openingBalance)} am ${Dates.numeric(account.openingDate)}',
                          style: ZText.small,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: SoftButton(
                                label: 'Korrigieren',
                                icon: Icons.tune_rounded,
                                onPressed: () => showCorrectBalanceSheet(context, account, balance),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SoftButton(
                                label: 'Umbuchen',
                                icon: Icons.swap_horiz_rounded,
                                onPressed: () => showBookingEditor(context, type: BookingType.transfer),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  SectionHeader(
                    title: 'Buchungen',
                    subtitle: bookings.isEmpty ? 'Noch keine' : '${bookings.length} insgesamt',
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.builder(
              itemCount: bookings.length.clamp(0, 150),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: BookingTile(booking: bookings[i], showDate: true),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

/// Kontostand korrigieren, ohne Einnahme oder Ausgabe zu erzeugen.
Future<void> showCorrectBalanceSheet(BuildContext context, Account account, int current) {
  final controller = TextEditingController(text: AmountField.textFor(current.abs()));
  return showZSheet(
    context,
    builder: (ctx) => Consumer(
      builder: (ctx, ref, _) => SheetScaffold(
        title: 'Kontostand korrigieren',
        subtitle:
            'Weicht Zoëzas von deiner Bank ab? Trag den echten Stand ein. '
            'Es entsteht keine Einnahme oder Ausgabe – nur der Startwert wird angepasst.',
        primaryLabel: 'Übernehmen',
        onPrimary: () async {
          final value = Money.parse(controller.text);
          if (value == null) return;
          await ref.read(accountsRepoProvider).correctBalance(account, currentBalance: current, newBalance: value);
          if (ctx.mounted) Navigator.pop(ctx);
        },
        children: [
          Text('Aktuell in Zoëzas: ${Money.format(current)}', style: ZText.secondary),
          const SizedBox(height: 12),
          AmountField(controller: controller, autofocus: true),
          const SizedBox(height: 8),
          Text(
            'Für einen negativen Stand ein Minus voranstellen nicht nötig – nutze dafür „-“ in der Tastatur.',
            style: ZText.small,
          ),
        ],
      ),
    ),
  );
}

/// Konto anlegen oder bearbeiten.
Future<void> showAccountEditor(BuildContext context, {Account? existing}) {
  return showZSheet(context, builder: (_) => _AccountEditor(existing: existing));
}

class _AccountEditor extends ConsumerStatefulWidget {
  const _AccountEditor({this.existing});
  final Account? existing;

  @override
  ConsumerState<_AccountEditor> createState() => _AccountEditorState();
}

class _AccountEditorState extends ConsumerState<_AccountEditor> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _opening = TextEditingController();
  late AccountType _type = widget.existing?.type ?? AccountType.checking;
  late String _emoji = widget.existing?.emoji ?? _type.emoji;
  late int _color = widget.existing?.color ?? ZColors.pastels[2].toARGB32();
  late bool _available = widget.existing?.includeInAvailable ?? _type.defaultIncludeInAvailable;

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim().isEmpty ? _type.label : _name.text.trim();
    final repo = ref.read(accountsRepoProvider);
    if (widget.existing == null) {
      await repo.add(
        name: name,
        type: _type,
        emoji: _emoji,
        color: _color,
        openingBalance: Money.parse(_opening.text) ?? 0,
        includeInAvailable: _available,
      );
    } else {
      await repo.updateAccount(
        widget.existing!.copyWith(
          name: name,
          type: _type,
          emoji: _emoji,
          color: _color,
          includeInAvailable: _available,
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _archiveOrDelete() async {
    final a = widget.existing!;
    final repo = ref.read(accountsRepoProvider);
    final used = await repo.isUsed(a.id);
    if (!mounted) return;
    if (used) {
      final ok = await confirm(
        context,
        title: a.archived ? 'Wieder aktivieren?' : 'Konto archivieren?',
        message: a.archived
            ? '„${a.name}“ erscheint wieder in der Auswahl.'
            : '„${a.name}“ hat Buchungen und bleibt deshalb für die Statistik erhalten, verschwindet aber aus der Auswahl und dem Verfügbaren.',
        confirmLabel: a.archived ? 'Aktivieren' : 'Archivieren',
      );
      if (ok) await repo.updateAccount(a.copyWith(archived: !a.archived));
    } else {
      final ok = await confirm(
        context,
        title: 'Konto löschen?',
        message: '„${a.name}“ wird entfernt.',
        confirmLabel: 'Löschen',
        destructive: true,
      );
      if (ok) await repo.delete(a.id);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return SheetScaffold(
      title: isNew ? 'Neues Konto' : 'Konto bearbeiten',
      primaryLabel: 'Speichern',
      onPrimary: _save,
      secondary: isNew
          ? null
          : TextButton(
              onPressed: _archiveOrDelete,
              child: Text(
                widget.existing!.archived ? 'Wieder aktivieren' : 'Archivieren oder löschen',
                style: const TextStyle(color: ZColors.negative),
              ),
            ),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in AccountType.values)
              ZPill(
                label: t.label,
                leading: Text(t.emoji),
                color: ZColors.accentSoft,
                selected: _type == t,
                onTap: () => setState(() {
                  if (_emoji == _type.emoji) _emoji = t.emoji;
                  if (isNew) _available = t.defaultIncludeInAvailable;
                  _type = t;
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
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
                decoration: InputDecoration(hintText: _type.label),
              ),
            ),
          ],
        ),
        if (isNew) ...[
          const SizedBox(height: 16),
          const FieldLabel('Aktueller Kontostand'),
          AmountField(controller: _opening),
        ],
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          value: _available,
          onChanged: (v) => setState(() => _available = v),
          title: Text('Zählt zum verfügbaren Guthaben', style: ZText.itemTitle.copyWith(fontSize: 14.5)),
          subtitle: Text('Aus für Sparkonten und Rücklagen.', style: ZText.small),
        ),
        const SizedBox(height: 6),
        const FieldLabel('Farbe'),
        PastelPicker(value: _color, onChanged: (c) => setState(() => _color = c)),
      ],
    );
  }
}
