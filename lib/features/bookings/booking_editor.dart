import 'package:collection/collection.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/sheets.dart';
import '../../data/providers.dart';
import '../../domain/enums.dart';
import '../../domain/quick_entry.dart';
import '../settings/categories_screen.dart';

/// Öffnet die Schnelleingabe für eine neue (oder bestehende) Buchung.
Future<void> showBookingEditor(
  BuildContext context, {
  Booking? existing,
  BookingType type = BookingType.expense,
  String? title,
  int? amount,
  DateTime? date,
  bool planned = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: ZColors.card,
    barrierColor: ZColors.text.withValues(alpha: 0.28),
    builder: (_) => BookingEditor(
      existing: existing,
      initialType: existing?.type ?? type,
      initialTitle: existing?.title ?? title,
      initialAmount: existing?.amount ?? amount,
      initialDate: existing?.date ?? date,
      initialPlanned: existing != null ? existing.status == BookingStatus.planned : planned,
    ),
  );
}

class BookingEditor extends ConsumerStatefulWidget {
  const BookingEditor({
    super.key,
    this.existing,
    required this.initialType,
    this.initialTitle,
    this.initialAmount,
    this.initialDate,
    this.initialPlanned = false,
  });

  final Booking? existing;
  final BookingType initialType;
  final String? initialTitle;
  final int? initialAmount;
  final DateTime? initialDate;
  final bool initialPlanned;

  @override
  ConsumerState<BookingEditor> createState() => _BookingEditorState();
}

class _BookingEditorState extends ConsumerState<BookingEditor> {
  late BookingType _type = widget.initialType;
  late String _amountText = AmountField.textFor(widget.initialAmount);
  late final TextEditingController _title = TextEditingController(text: widget.initialTitle ?? '');
  late String _note = widget.existing?.note ?? '';
  final _titleFocus = FocusNode();
  late int? _categoryId = widget.existing?.categoryId;
  late int? _accountId = widget.existing?.accountId;
  late int? _toAccountId = widget.existing?.toAccountId;
  late DateTime _date = widget.initialDate ?? DateTime.now();
  late bool _planned = widget.initialPlanned;
  Frequency? _repeat;
  bool _autoBook = true;
  List<Booking> _recent = const [];
  bool _saving = false;

  bool get _isEdit => widget.existing != null;
  int get _amount => Money.parse(_amountText) ?? 0;
  bool get _isFuture => Dates.dateOnly(_date).isAfter(Dates.dateOnly(DateTime.now()));
  bool get _effectivePlanned => _planned || _isFuture;

  @override
  void initState() {
    super.initState();
    _titleFocus.addListener(() => setState(() {}));
    _title.addListener(() => setState(() {}));
    _loadRecent();
  }

  @override
  void dispose() {
    _title.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    if (_type == BookingType.transfer) {
      setState(() => _recent = const []);
      return;
    }
    final list = await ref.read(bookingsRepoProvider).recentDistinctTitles(type: _type);
    if (mounted) setState(() => _recent = list);
  }

  // ---------------------------------------------------------------------------
  // Ziffernblock
  // ---------------------------------------------------------------------------

  void _press(String key) {
    HapticFeedback.selectionClick();
    setState(() {
      if (key == '⌫') {
        if (_amountText.isNotEmpty) _amountText = _amountText.substring(0, _amountText.length - 1);
        return;
      }
      if (key == ',') {
        if (_amountText.contains(',')) return;
        _amountText = _amountText.isEmpty ? '0,' : '$_amountText,';
        return;
      }
      final parts = _amountText.split(',');
      if (parts.length == 2 && parts[1].length >= 2) return;
      if (parts.length == 1 && parts[0].replaceAll('0', '').isEmpty && key == '0' && _amountText.isNotEmpty) return;
      if (parts.length == 1 && parts[0].length >= 7) return;
      _amountText = (_amountText == '0' ? '' : _amountText) + key;
    });
  }

  // ---------------------------------------------------------------------------
  // Speichern
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    if (_saving) return;
    final accounts = (ref.read(accountsProvider).value ?? const <Account>[]).where((a) => !a.archived).toList();
    final categories = ref.read(categoriesProvider).value ?? const <Category>[];

    var amount = _amount;
    var title = _title.text.trim();
    if (amount == 0 && title.isNotEmpty) {
      final q = QuickEntryParser.parse(title);
      if (q.amount != null) {
        amount = q.amount!;
        title = q.title;
      }
    }
    if (amount <= 0) return _hint('Wie viel denn? Tipp einfach den Betrag ein 🙂');

    final accountId = _accountId ?? _defaultAccount(accounts)?.id;
    if (accountId == null) return _hint('Leg zuerst ein Konto an.');
    if (_type == BookingType.transfer) {
      if (_toAccountId == null || _toAccountId == accountId) return _hint('Wähle zwei verschiedene Konten.');
    }

    int? categoryId = _type == BookingType.transfer ? null : _categoryId;
    if (_type != BookingType.transfer && categoryId == null) {
      final key = _type == BookingType.expense ? 'misc' : 'other_income';
      categoryId =
          categories.firstWhereOrNull((c) => c.builtInKey == key && !c.archived)?.id ??
          categories
              .firstWhereOrNull(
                (c) => c.kind == (_type == BookingType.expense ? CategoryKind.expense : CategoryKind.income),
              )
              ?.id;
    }
    if (title.isEmpty) {
      title = _type == BookingType.transfer
          ? 'Umbuchung'
          : categories.firstWhereOrNull((c) => c.id == categoryId)?.name ?? _type.label;
    }

    final now = DateTime.now();
    final date = Dates.sameDay(_date, now)
        ? now
        : (widget.existing != null && Dates.sameDay(widget.existing!.date, _date)
              ? widget.existing!.date
              : DateTime(_date.year, _date.month, _date.day, 12));
    final note = _note.trim().isEmpty ? null : _note.trim();
    final status = _effectivePlanned ? BookingStatus.planned : BookingStatus.booked;

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    String message;
    try {
      if (_isEdit) {
        await ref
            .read(bookingsRepoProvider)
            .updateBooking(
              widget.existing!.copyWith(
                type: _type,
                status: status,
                amount: amount,
                accountId: accountId,
                toAccountId: Value(_toAccountId),
                categoryId: Value(categoryId),
                title: title,
                note: Value(note),
                date: date,
              ),
            );
        message = 'Gespeichert ✨';
      } else if (_repeat != null) {
        await ref
            .read(recurringRepoProvider)
            .add(
              type: _type,
              amount: amount,
              accountId: accountId,
              toAccountId: _toAccountId,
              categoryId: categoryId,
              title: title,
              note: note,
              frequency: _repeat!,
              startDate: date,
              autoBook: _autoBook,
            );
        message = 'Dauerauftrag angelegt 🔁';
      } else {
        await ref
            .read(bookingsRepoProvider)
            .add(
              type: _type,
              status: status,
              amount: amount,
              accountId: accountId,
              toAccountId: _toAccountId,
              categoryId: categoryId,
              title: title,
              note: note,
              date: date,
            );
        message = status == BookingStatus.planned
            ? 'Eingeplant 🗓️'
            : switch (_type) {
                BookingType.expense => 'Notiert ✨',
                BookingType.income => 'Schön, ein Plus! 💚',
                BookingType.transfer => 'Umgebucht ↔️',
              };
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    HapticFeedback.mediumImpact();
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(milliseconds: 1600)));
  }

  void _hint(String text) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Account? _defaultAccount(List<Account> accounts) =>
      accounts.firstWhereOrNull((a) => a.includeInAvailable && a.type == AccountType.checking) ??
      accounts.firstWhereOrNull((a) => a.includeInAvailable) ??
      accounts.firstOrNull;

  Future<void> _delete() async {
    final b = widget.existing!;
    final ok = await confirm(
      context,
      title: 'Buchung löschen?',
      message:
          '„${b.title}“ über ${Money.format(b.amount)} wird entfernt. Gehört sie zu einem Sparziel oder einer Schuld, verschwindet auch der Eintrag dort.',
      confirmLabel: 'Löschen',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await ref.read(bookingsRepoProvider).delete(b.id);
    if (mounted) Navigator.pop(context);
  }

  // ---------------------------------------------------------------------------
  // Optionen
  // ---------------------------------------------------------------------------

  Future<void> _pickDate() async {
    final d = await pickDate(context, initial: _date);
    if (d != null) setState(() => _date = d);
  }

  Future<void> _editNote() async {
    final controller = TextEditingController(text: _note);
    final result = await showZSheet<String>(
      context,
      builder: (ctx) => SheetScaffold(
        title: 'Notiz',
        subtitle: 'Erscheint statt Finas Beschreibung in der Liste.',
        primaryLabel: 'Übernehmen',
        onPrimary: () => Navigator.pop(ctx, controller.text),
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'z. B. „mit Lena im Kino“'),
          ),
        ],
      ),
    );
    if (result != null) setState(() => _note = result);
  }

  Future<void> _pickRepeat() async {
    Frequency? selected = _repeat;
    var auto = _autoBook;
    final result = await showZSheet<(Frequency?, bool)>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SheetScaffold(
          title: 'Wiederholen',
          subtitle: 'Daraus wird ein Dauerauftrag. Künftige Termine erscheinen in deiner Planung.',
          primaryLabel: 'Übernehmen',
          onPrimary: () => Navigator.pop(ctx, (selected, auto)),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ZPill(
                  label: 'Einmalig',
                  selected: selected == null,
                  color: ZColors.accentSoft,
                  onTap: () => setSheet(() => selected = null),
                ),
                for (final f in Frequency.values)
                  ZPill(
                    label: f.label,
                    selected: selected == f,
                    color: ZColors.accentSoft,
                    onTap: () => setSheet(() => selected = f),
                  ),
              ],
            ),
            if (selected != null) ...[
              const SizedBox(height: 18),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                value: auto,
                onChanged: (v) => setSheet(() => auto = v),
                title: const Text('Automatisch buchen', style: ZText.itemTitle),
                subtitle: Text(
                  auto ? 'Am Fälligkeitstag wird automatisch gebucht.' : 'Am Fälligkeitstag fragt Fina kurz nach.',
                  style: ZText.secondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _repeat = result.$1;
        _autoBook = result.$2;
      });
    }
  }

  Future<void> _newCategory() async {
    final kind = _type == BookingType.income ? CategoryKind.income : CategoryKind.expense;
    final id = await showCategoryEditor(context, kind: kind);
    if (id != null) setState(() => _categoryId = id);
  }

  void _applySuggestion(Booking b) {
    HapticFeedback.selectionClick();
    setState(() {
      _title.text = b.title;
      _title.selection = TextSelection.collapsed(offset: b.title.length);
      _categoryId = b.categoryId;
      _accountId = b.accountId;
    });
  }

  void _onTitleSubmitted(String text) {
    final q = QuickEntryParser.parse(text);
    if (q.amount != null && _amount == 0) {
      setState(() {
        _amountText = AmountField.textFor(q.amount);
        _title.text = q.title;
      });
    }
    _titleFocus.unfocus();
  }

  // ---------------------------------------------------------------------------
  // Aufbau
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final accounts = (ref.watch(accountsProvider).value ?? const <Account>[])
        .where((a) => !a.archived || a.id == _accountId || a.id == _toAccountId)
        .toList();
    final categories = (ref.watch(categoriesProvider).value ?? const <Category>[])
        .where((c) => !c.archived || c.id == _categoryId)
        .where((c) => _type == BookingType.income ? c.kind == CategoryKind.income : c.kind == CategoryKind.expense)
        .toList();
    _accountId ??= _defaultAccount(accounts)?.id;
    if (_type == BookingType.transfer && _toAccountId == null) {
      _toAccountId =
          accounts.firstWhereOrNull((a) => a.id != _accountId && a.type == AccountType.savings)?.id ??
          accounts.firstWhereOrNull((a) => a.id != _accountId)?.id;
    }

    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final height = MediaQuery.sizeOf(context).height * 0.93;
    final account = accounts.firstWhereOrNull((a) => a.id == _accountId);
    final beforeOpening =
        account != null && !_effectivePlanned && Dates.dateOnly(_date).isBefore(Dates.dateOnly(account.openingDate));

    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          children: [
            const SizedBox(height: 10),
            const SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _TypeSwitch(value: _type, onChanged: _changeType),
                  ),
                  const SizedBox(width: 8),
                  if (_isEdit)
                    RoundIconButton(
                      icon: Icons.delete_outline_rounded,
                      color: ZColors.accentSoft,
                      onPressed: _delete,
                      tooltip: 'Löschen',
                    )
                  else
                    RoundIconButton(
                      icon: Icons.close_rounded,
                      color: ZColors.accentSoft,
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Schließen',
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      onTap: () => _titleFocus.unfocus(),
                      child: _AmountDisplay(text: _amountText, type: _type, active: !_titleFocus.hasFocus),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _title,
                      focusNode: _titleFocus,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      onSubmitted: _onTitleSubmitted,
                      style: ZText.body.copyWith(fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: switch (_type) {
                          BookingType.expense => 'Wofür? z. B. „Eis 3,50“',
                          BookingType.income => 'Woher? z. B. Gehalt',
                          BookingType.transfer => 'Notiz zur Umbuchung (optional)',
                        },
                        prefixIcon: const Icon(Icons.edit_outlined, size: 20, color: ZColors.textTertiary),
                      ),
                    ),
                    _Suggestions(recent: _recent, query: _title.text, onPick: _applySuggestion, categories: categories),
                    const SizedBox(height: 14),
                    if (_type == BookingType.transfer) ...[
                      const FieldLabel('Von'),
                      _AccountChips(
                        accounts: accounts,
                        selected: _accountId,
                        onSelect: (id) => setState(() => _accountId = id),
                      ),
                      const SizedBox(height: 12),
                      const FieldLabel('Nach'),
                      _AccountChips(
                        accounts: accounts,
                        selected: _toAccountId,
                        disabled: _accountId,
                        onSelect: (id) => setState(() => _toAccountId = id),
                      ),
                    ] else ...[
                      const FieldLabel('Kategorie'),
                      _CategoryChips(
                        categories: categories,
                        selected: _categoryId,
                        onSelect: (id) => setState(() => _categoryId = id),
                        onAdd: _newCategory,
                      ),
                      const SizedBox(height: 12),
                      FieldLabel(_type == BookingType.expense ? 'Bezahlt mit' : 'Auf Konto'),
                      _AccountChips(
                        accounts: accounts,
                        selected: _accountId,
                        onSelect: (id) => setState(() => _accountId = id),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      child: Row(
                        spacing: 8,
                        children: [
                          ZPill(
                            dense: true,
                            color: ZColors.accentSoft,
                            leading: const Text('📅', style: TextStyle(fontSize: 13)),
                            label: Dates.relative(_date),
                            onTap: _pickDate,
                          ),
                          ZPill(
                            dense: true,
                            color: ZColors.accentSoft,
                            selectedColor: ZColors.accentDeep,
                            selected: _effectivePlanned,
                            leading: const Text('⏳', style: TextStyle(fontSize: 13)),
                            label: _effectivePlanned ? 'Geplant' : 'Schon bezahlt',
                            onTap: _isFuture ? null : () => setState(() => _planned = !_planned),
                          ),
                          if (!_isEdit)
                            ZPill(
                              dense: true,
                              color: ZColors.accentSoft,
                              selectedColor: ZColors.accentDeep,
                              selected: _repeat != null,
                              leading: const Text('🔁', style: TextStyle(fontSize: 13)),
                              label: _repeat?.label ?? 'Einmalig',
                              onTap: _pickRepeat,
                            ),
                          ZPill(
                            dense: true,
                            color: ZColors.accentSoft,
                            selectedColor: ZColors.accentDeep,
                            selected: _note.trim().isNotEmpty,
                            leading: const Text('📝', style: TextStyle(fontSize: 13)),
                            label: _note.trim().isEmpty ? 'Notiz' : 'Notiz ✓',
                            onTap: _editNote,
                          ),
                        ],
                      ),
                    ),
                    if (_effectivePlanned) ...[
                      const SizedBox(height: 10),
                      const _InfoLine(
                        'Geplantes verändert deinen Kontostand noch nicht – es erscheint in der Vorschau.',
                      ),
                    ],
                    if (beforeOpening) ...[
                      const SizedBox(height: 10),
                      _InfoLine(
                        'Liegt vor dem Start von „${account.name}“ (${Dates.numeric(account.openingDate)}). '
                        'Zählt in der Statistik, ändert den Kontostand aber nicht – er ist darin schon enthalten.',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: keyboardOpen || _titleFocus.hasFocus
                  ? const SizedBox(width: double.infinity)
                  : _Keypad(onKey: _press),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                child: keyboardOpen || _titleFocus.hasFocus
                    ? SoftButton(
                        label: 'Weiter zum Betrag',
                        icon: Icons.keyboard_hide_rounded,
                        onPressed: () => _onTitleSubmitted(_title.text),
                      )
                    : PrimaryButton(
                        label: _isEdit
                            ? 'Speichern'
                            : _repeat != null
                            ? 'Dauerauftrag anlegen'
                            : _effectivePlanned
                            ? 'Einplanen'
                            : 'Hinzufügen',
                        onPressed: _saving ? null : _save,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _changeType(BookingType t) {
    if (t == _type) return;
    setState(() {
      _type = t;
      _categoryId = null;
      if (t != BookingType.transfer) _toAccountId = null;
    });
    _loadRecent();
  }
}

// -----------------------------------------------------------------------------
// Bausteine
// -----------------------------------------------------------------------------

class _TypeSwitch extends StatelessWidget {
  const _TypeSwitch({required this.value, required this.onChanged});

  final BookingType value;
  final ValueChanged<BookingType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: ZColors.accentSoft, borderRadius: BorderRadius.circular(999)),
      child: Row(
        children: [
          for (final t in BookingType.values)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(t);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: t == value ? ZColors.card : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: t == value
                        ? const [BoxShadow(color: ZColors.shadow, blurRadius: 10, offset: Offset(0, 3))]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    t.label,
                    style: ZText.label.copyWith(fontSize: 13, color: t == value ? ZColors.text : ZColors.textSecondary),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AmountDisplay extends StatelessWidget {
  const _AmountDisplay({required this.text, required this.type, required this.active});

  final String text;
  final BookingType type;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final empty = text.isEmpty;
    final parts = (empty ? '0' : text).split(',');
    final whole = Money.wholePart((int.tryParse(parts[0]) ?? 0) * 100);
    final decimals = parts.length > 1 ? ',${parts[1]}' : '';
    final sign = switch (type) {
      BookingType.expense => '−',
      BookingType.income => '+',
      BookingType.transfer => '',
    };
    final color = empty
        ? ZColors.textTertiary
        : type == BookingType.income
        ? ZColors.positive
        : ZColors.text;
    final style = ZText.amountHero.copyWith(fontSize: 58, color: color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Text(switch (type) {
            BookingType.expense => 'AUSGABE',
            BookingType.income => 'EINNAHME',
            BookingType.transfer => 'UMBUCHUNG',
          }, style: ZText.overline),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                if (!empty && sign.isNotEmpty) Text(sign, style: style.copyWith(fontSize: 40)),
                Text(whole, style: style),
                Text(decimals, style: style.copyWith(fontSize: 34)),
                _Caret(visible: active),
                Text(' €', style: style.copyWith(fontSize: 30, color: color.withValues(alpha: 0.5))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Caret extends StatefulWidget {
  const _Caret({required this.visible});
  final bool visible;

  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox(width: 3);
    return FadeTransition(
      opacity: _c,
      child: Container(
        width: 2.5,
        height: 40,
        margin: const EdgeInsets.only(left: 2),
        decoration: BoxDecoration(color: ZColors.accent, borderRadius: BorderRadius.circular(2)),
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.recent, required this.query, required this.onPick, required this.categories});

  final List<Booking> recent;
  final String query;
  final ValueChanged<Booking> onPick;
  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final list = recent
        .where((b) => q.isEmpty || (b.title.toLowerCase().contains(q) && b.title.toLowerCase() != q))
        .take(8)
        .toList();
    if (list.isEmpty) return const SizedBox(height: 4);
    final byId = {for (final c in categories) c.id: c};
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final b = list[i];
            final emoji = byId[b.categoryId]?.emoji;
            return ZPill(
              dense: true,
              color: ZColors.card,
              label: b.title,
              leading: emoji == null ? null : Text(emoji, style: const TextStyle(fontSize: 13)),
              onTap: () => onPick(b),
            ).withOutline();
          },
        ),
      ),
    );
  }
}

extension on ZPill {
  Widget withOutline() => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: ZColors.line, width: 1.2),
    ),
    child: this,
  );
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.categories, required this.selected, required this.onSelect, required this.onAdd});

  final List<Category> categories;
  final int? selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i == categories.length) {
            return _CategoryChip(emoji: '＋', label: 'Neu', color: ZColors.accentSoft, selected: false, onTap: onAdd);
          }
          final c = categories[i];
          return _CategoryChip(
            emoji: c.emoji,
            label: c.name,
            color: Color(c.color),
            selected: c.id == selected,
            onTap: () => onSelect(c.id),
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.emoji,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: selected ? ZColors.accentDeep : Colors.transparent, width: 2.2),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 23)),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ZText.small.copyWith(
                fontSize: 11.5,
                color: selected ? ZColors.text : ZColors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountChips extends StatelessWidget {
  const _AccountChips({required this.accounts, required this.selected, required this.onSelect, this.disabled});

  final List<Account> accounts;
  final int? selected;
  final int? disabled;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: accounts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final a = accounts[i];
          final off = a.id == disabled;
          return Opacity(
            opacity: off ? 0.35 : 1,
            child: ZPill(
              label: a.name,
              selected: a.id == selected,
              color: ZColors.accentSoft,
              leading: Text(a.emoji, style: const TextStyle(fontSize: 14)),
              onTap: off ? null : () => onSelect(a.id),
            ),
          );
        },
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: ZColors.accentSoft, borderRadius: BorderRadius.circular(16)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('💡 ', style: TextStyle(fontSize: 13)),
        Expanded(
          child: Text(text, style: ZText.small.copyWith(color: ZColors.text)),
        ),
      ],
    ),
  );
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onKey});
  final ValueChanged<String> onKey;

  static const _keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', ',', '0', '⌫'];

  @override
  Widget build(BuildContext context) {
    // Je kleiner der Bildschirm, desto flacher die Tasten – die Optionen darüber
    // sollen sichtbar bleiben (iPhone als Web-App: ~750–850 px Höhe).
    final h = MediaQuery.sizeOf(context).height;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: h < 700 ? 3.2 : (h < 860 ? 2.9 : 2.45),
        padding: EdgeInsets.zero,
        children: [
          for (final k in _keys)
            InkResponse(
              onTap: () => onKey(k),
              onLongPress: k == '⌫'
                  ? () {
                      for (var i = 0; i < 12; i++) {
                        onKey('⌫');
                      }
                    }
                  : null,
              radius: 34,
              splashColor: ZColors.accentLight.withValues(alpha: 0.6),
              highlightColor: ZColors.accentSoft,
              child: Center(
                child: k == '⌫'
                    ? const Icon(Icons.backspace_outlined, color: ZColors.text, size: 24)
                    : Text(k, style: ZText.amountMedium.copyWith(fontSize: 28)),
              ),
            ),
        ],
      ),
    );
  }
}
