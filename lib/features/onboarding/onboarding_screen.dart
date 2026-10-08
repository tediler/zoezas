import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/fina_avatar.dart';
import '../../core/widgets/sheets.dart';
import '../../data/providers.dart';
import '../../domain/enums.dart';
import '../../domain/fina.dart';
import '../../domain/recurrence.dart';

/// Kennenlernen: Name, Tonfall, Schwerpunkt, Konten und Einkommen. Alles
/// bleibt lokal – kein Konto, keine E-Mail.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _page = PageController();
  int _step = 0;
  static const _steps = 7;

  final _name = TextEditingController();
  FinaTone _tone = FinaTone.warm;
  MoneyFocus _focus = MoneyFocus.overview;
  final _giro = TextEditingController();
  final _savings = TextEditingController();
  final _cash = TextEditingController();
  bool _hasSavings = true;
  bool _hasCash = false;
  final _income = TextEditingController();
  int _payday = 1;
  bool _receivedThisMonth = true;
  bool _saving = false;

  @override
  void dispose() {
    _page.dispose();
    for (final c in [_name, _giro, _savings, _cash, _income]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _displayName => _name.text.trim().isEmpty ? 'du' : _name.text.trim();

  void _next() {
    FocusScope.of(context).unfocus();
    if (_step == _steps - 1) {
      _finish();
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _step++);
    _page.animateToPage(_step, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
  }

  void _back() {
    if (_step == 0) return;
    FocusScope.of(context).unfocus();
    setState(() => _step--);
    _page.animateToPage(_step, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
  }

  bool get _paydayPassed => DateTime.now().day >= _paydayThisMonth.day;

  DateTime get _paydayThisMonth {
    final now = DateTime.now();
    return Recurrence.addMonthsClamped(DateTime(now.year, now.month, 1), 0, day: _payday);
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    final accounts = ref.read(accountsRepoProvider);
    final now = DateTime.now();

    final giroId = await accounts.add(
      name: 'Girokonto',
      type: AccountType.checking,
      emoji: '💳',
      color: ZColors.pastels[2].toARGB32(),
      openingBalance: Money.parse(_giro.text) ?? 0,
      openingDate: now,
    );
    if (_hasSavings) {
      await accounts.add(
        name: 'Sparkonto',
        type: AccountType.savings,
        emoji: '🐷',
        color: ZColors.pastels[0].toARGB32(),
        openingBalance: Money.parse(_savings.text) ?? 0,
        openingDate: now,
      );
    }
    if (_hasCash) {
      await accounts.add(
        name: 'Bargeld',
        type: AccountType.cash,
        emoji: '👛',
        color: ZColors.pastels[5].toARGB32(),
        openingBalance: Money.parse(_cash.text) ?? 0,
        openingDate: now,
      );
    }

    final income = Money.parse(_income.text) ?? 0;
    if (income > 0) {
      final categories = await ref.read(databaseProvider).select(ref.read(databaseProvider).categories).get();
      final salary = categories.firstWhereOrNull((c) => c.builtInKey == 'salary');
      final thisMonth = _paydayThisMonth;
      DateTime start;
      if (_paydayPassed) {
        if (_receivedThisMonth) {
          // Das Gehalt dieses Monats ist schon im Kontostand enthalten: als
          // Buchung vor dem Startdatum zählt es für die Monatsstatistik, ohne
          // den Kontostand ein zweites Mal zu erhöhen.
          await ref
              .read(bookingsRepoProvider)
              .add(
                type: BookingType.income,
                status: BookingStatus.booked,
                amount: income,
                accountId: giroId,
                categoryId: salary?.id,
                title: 'Gehalt',
                date: DateTime(thisMonth.year, thisMonth.month, thisMonth.day, 6),
              );
        } else {
          // Noch nicht da: als fälliger Posten, den die Person bestätigt.
          await ref
              .read(bookingsRepoProvider)
              .add(
                type: BookingType.income,
                status: BookingStatus.planned,
                amount: income,
                accountId: giroId,
                categoryId: salary?.id,
                title: 'Gehalt',
                date: now,
              );
        }
        start = Recurrence.addMonthsClamped(DateTime(now.year, now.month, 1), 1, day: _payday);
      } else {
        start = thisMonth;
      }
      await ref
          .read(recurringRepoProvider)
          .add(
            type: BookingType.income,
            amount: income,
            accountId: giroId,
            categoryId: salary?.id,
            title: 'Gehalt',
            frequency: Frequency.monthly,
            startDate: start,
            dayOfMonth: _payday,
          );
    }

    await ref.read(settingsRepoProvider).setAll({
      SettingKeys.name: _name.text.trim(),
      SettingKeys.tone: _tone.name,
      SettingKeys.focus: _focus.name,
      SettingKeys.onboarded: 'true',
    });
    await ref.read(settingsRepoProvider).markActive(now);
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    // Zurück-Geste führt zum vorherigen Schritt statt aus der App heraus.
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: _buildScaffold(),
    );
  }

  Widget _buildScaffold() {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
              child: Row(
                children: [
                  AnimatedOpacity(
                    opacity: _step == 0 ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: IconButton(onPressed: _back, icon: const Icon(Icons.arrow_back_rounded)),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        for (var i = 0; i < _steps; i++)
                          Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: i <= _step ? ZColors.accent : ZColors.accentLight.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _page,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _welcome(),
                  _nameStep(),
                  _toneStep(),
                  _focusStep(),
                  _accountsStep(),
                  _incomeStep(),
                  _doneStep(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: PrimaryButton(
                label: switch (_step) {
                  0 => 'Los geht’s',
                  6 => _saving ? 'Einen Moment…' : 'Zu meinem Zuhause',
                  _ => 'Weiter',
                },
                onPressed: _saving ? null : _next,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepLayout({required FinaMood mood, required String title, String? text, required List<Widget> children}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FinaAvatar(mood: mood, size: 70),
        ),
        const SizedBox(height: 18),
        Text(title, style: ZText.screenTitle.copyWith(fontSize: 26, height: 1.2)),
        if (text != null) ...[
          const SizedBox(height: 10),
          Text(text, style: ZText.body.copyWith(color: ZColors.textSecondary)),
        ],
        const SizedBox(height: 26),
        ...children,
      ],
    );
  }

  Widget _welcome() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      children: [
        const Center(child: FinaAvatar(mood: FinaMood.proud, size: 120)),
        const SizedBox(height: 30),
        Text('Hi, ich bin Fina 👋', style: ZText.screenTitle.copyWith(fontSize: 30), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(
          'Ich helfe dir zu sehen, wohin dein Geld geht, was dir noch bleibt und wie du deine Ziele erreichst – ganz entspannt.',
          style: ZText.body.copyWith(color: ZColors.textSecondary, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 30),
        ZCard(
          child: Row(
            children: [
              const Text('🔒', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Alles bleibt auf deinem Handy. Kein Konto, keine E-Mail, keine Cloud.',
                  style: ZText.body.copyWith(fontSize: 14.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _nameStep() => _stepLayout(
    mood: FinaMood.happy,
    title: 'Wie darf ich dich nennen?',
    text: 'Damit ich dich richtig begrüßen kann.',
    children: [
      TextField(
        controller: _name,
        autofocus: false,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        onSubmitted: (_) => _next(),
        onChanged: (_) => setState(() {}),
        style: ZText.sectionTitle,
        decoration: const InputDecoration(hintText: 'Dein Vorname'),
      ),
    ],
  );

  Widget _toneStep() => _stepLayout(
    mood: FinaMood.happy,
    title: 'Wie soll ich mit dir reden, $_displayName?',
    text: 'Du kannst das später jederzeit ändern.',
    children: [
      for (final t in FinaTone.values) ...[
        _ChoiceCard(
          emoji: t.emoji,
          title: t.label,
          text: switch (t) {
            FinaTone.cheeky => '„Upsi, Online-Shopping hat das Budget gesprengt 😅“',
            FinaTone.warm => '„Du machst das gut – noch 40 € für diese Woche 🌸“',
            FinaTone.calm => '„Online Shopping: 20 € über Budget.“',
          },
          selected: _tone == t,
          onTap: () => setState(() => _tone = t),
        ),
        const SizedBox(height: 10),
      ],
    ],
  );

  Widget _focusStep() => _stepLayout(
    mood: FinaMood.calm,
    title: 'Was ist dir gerade am wichtigsten?',
    text: 'Danach richte ich meine Tipps aus.',
    children: [
      for (final f in MoneyFocus.values) ...[
        _ChoiceCard(emoji: f.emoji, title: f.label, selected: _focus == f, onTap: () => setState(() => _focus = f)),
        const SizedBox(height: 10),
      ],
    ],
  );

  Widget _accountsStep() => _stepLayout(
    mood: FinaMood.happy,
    title: 'Wie viel Geld hast du gerade?',
    text: 'Ungefähr reicht völlig. Du kannst Kontostände jederzeit korrigieren.',
    children: [
      const FieldLabel('💳  Girokonto'),
      AmountField(controller: _giro),
      const SizedBox(height: 18),
      _ToggleRow(
        emoji: '🐷',
        label: 'Ich habe ein Sparkonto',
        value: _hasSavings,
        onChanged: (v) => setState(() => _hasSavings = v),
      ),
      if (_hasSavings) ...[const SizedBox(height: 8), AmountField(controller: _savings)],
      const SizedBox(height: 14),
      _ToggleRow(
        emoji: '👛',
        label: 'Ich habe Bargeld dabei',
        value: _hasCash,
        onChanged: (v) => setState(() => _hasCash = v),
      ),
      if (_hasCash) ...[const SizedBox(height: 8), AmountField(controller: _cash)],
      const SizedBox(height: 16),
      Text(
        'Das Sparkonto zählt nicht zu deinem verfügbaren Guthaben – so siehst du immer, was du wirklich ausgeben kannst.',
        style: ZText.small,
      ),
    ],
  );

  Widget _incomeStep() {
    final thisMonth = _paydayThisMonth;
    return _stepLayout(
      mood: FinaMood.proud,
      title: 'Wie viel kommt monatlich rein?',
      text: 'Dein Netto-Einkommen. Ich trage es als Dauerauftrag ein – leer lassen geht auch.',
      children: [
        AmountField(controller: _income, onChanged: (_) => setState(() {})),
        const SizedBox(height: 20),
        const FieldLabel('Wann kommt es?'),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 31,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final d = i + 1;
              return ZPill(
                label: d == 31 ? 'Monatsende' : '$d.',
                selected: _payday == d,
                onTap: () => setState(() => _payday = d),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _payday > 28 && _payday < 31
              ? 'In kürzeren Monaten rechne ich mit dem letzten Tag.'
              : 'Nächster Termin: ${Dates.longDay(Recurrence.firstMonthlyOnOrAfter(DateTime.now(), _payday))}',
          style: ZText.small,
        ),
        if (_paydayPassed && (Money.parse(_income.text) ?? 0) > 0) ...[
          const SizedBox(height: 18),
          _ToggleRow(
            emoji: '✅',
            label: 'Das Geld vom ${Dates.short(thisMonth)} ist schon da',
            value: _receivedThisMonth,
            onChanged: (v) => setState(() => _receivedThisMonth = v),
          ),
          const SizedBox(height: 6),
          Text(
            _receivedThisMonth
                ? 'Dann zählt es für deine Monatsübersicht – dein Kontostand von eben bleibt, wie er ist.'
                : 'Dann plane ich es als fällig ein, bis du es bestätigst.',
            style: ZText.small,
          ),
        ],
      ],
    );
  }

  Widget _doneStep() => ListView(
    padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
    children: [
      const Center(child: FinaAvatar(mood: FinaMood.proud, size: 110)),
      const SizedBox(height: 28),
      Text(
        _displayName == 'du' ? 'Schön, dich kennenzulernen!' : 'Schön, dich kennenzulernen, $_displayName!',
        style: ZText.screenTitle.copyWith(fontSize: 27),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      Text(
        switch (_tone) {
          FinaTone.cheeky => 'Ich hab ab jetzt ein Auge auf dein Geld. Keine Sorge, ich petze nicht 😏',
          FinaTone.warm => 'Ab jetzt sind wir ein Team. Ich freu mich auf alles, was du erreichst 💗',
          FinaTone.calm => 'Alles eingerichtet. Neue Buchungen über das Plus unten.',
        },
        style: ZText.body.copyWith(color: ZColors.textSecondary, fontSize: 16),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 28),
      const ZCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kleiner Tipp ✨', style: ZText.itemTitle),
            SizedBox(height: 6),
            Text(
              'Leg dir das Zoëzas-Widget auf den Homescreen – dann ist eine Ausgabe in zwei Sekunden notiert.',
              style: ZText.secondary,
            ),
          ],
        ),
      ),
    ],
  );
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({required this.emoji, required this.title, this.text, required this.selected, required this.onTap});

  final String emoji;
  final String title;
  final String? text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: selected ? ZColors.accent : Colors.transparent, width: 2),
      ),
      child: ZCard(
        onTap: onTap,
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: ZText.itemTitle),
                  if (text != null) ...[const SizedBox(height: 4), Text(text!, style: ZText.secondary)],
                ],
              ),
            ),
            AnimatedOpacity(
              opacity: selected ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.check_circle_rounded, color: ZColors.accent),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.emoji, required this.label, required this.value, required this.onChanged});

  final String emoji;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: ZText.label)),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}
