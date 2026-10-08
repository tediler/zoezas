import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/shell.dart';
import '../../core/db/database.dart';
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
import '../../domain/ledger.dart';
import '../bookings/booking_editor.dart';
import '../bookings/booking_tile.dart';
import '../bookings/planned_sheet.dart';
import '../bookings/quick_add.dart';
import '../onboarding/install_hint.dart';
import '../settings/budget_row.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerProvider);
    final profile = ref.watch(profileProvider);
    final fina = ref.watch(finaContextProvider);
    if (ledger == null || profile == null || fina == null) {
      return const Center(child: CircularProgressIndicator(color: ZColors.accent));
    }
    final now = ref.watch(clockProvider);
    final month = YearMonth.of(now);
    final summary = ledger.month(month);
    final due = ref.watch(dueItemsProvider);
    final upcoming = ledger.upcoming(14);
    final budgets = ref.watch(budgetStatusProvider(month));

    return CustomScrollView(
      slivers: [
        SliverSafeArea(
          bottom: false,
          sliver: SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            sliver: SliverList.list(
              children: [
                _Greeting(name: profile.displayName, now: now),
                const SizedBox(height: 30),
                _Hero(ledger: ledger, fina: fina),
                const SizedBox(height: 26),
                const SafariInstallHint(padding: EdgeInsets.only(bottom: 14)),
                _Overview(ledger: ledger, summary: summary),
                const SizedBox(height: 14),
                _TipCard(tip: Fina.tip(fina), due: due),
                if (due.isNotEmpty) ...[
                  const SizedBox(height: 26),
                  SectionHeader(
                    title: 'Wartet auf dich',
                    subtitle: due.length == 1 ? 'Ein Posten ist fällig' : '${due.length} Posten sind fällig',
                  ),
                  for (final p in due.take(4)) ...[PlannedTile(item: p), const SizedBox(height: 10)],
                ],
                if (budgets.isNotEmpty) ...[
                  const SizedBox(height: 26),
                  SectionHeader(
                    title: 'Deine Budgets',
                    trailing: TextButton(onPressed: () => context.push('/budgets'), child: const Text('Alle')),
                  ),
                  ZCard(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                    child: Column(
                      children: [
                        for (final s in budgets.take(3))
                          BudgetRow(status: s, tone: profile.tone, onTap: () => context.push('/budgets')),
                      ],
                    ),
                  ),
                ],
                if (upcoming.isNotEmpty) ...[
                  const SizedBox(height: 26),
                  SectionHeader(
                    title: 'Demnächst',
                    subtitle: 'In den nächsten 14 Tagen',
                    trailing: TextButton(
                      onPressed: () => context.push('/month/${month.key}'),
                      child: const Text('Planung'),
                    ),
                  ),
                  for (final p in upcoming.take(4)) ...[
                    PlannedTile(item: p, compact: true),
                    const SizedBox(height: 10),
                  ],
                ],
                const SizedBox(height: 26),
              ],
            ),
          ),
        ),
        _ExpenseList(summary: summary, month: month),
        SliverToBoxAdapter(child: SizedBox(height: bottomContentPadding(context))),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Begrüßung
// -----------------------------------------------------------------------------

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name, required this.now});

  final String name;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final greeting = Fina.greeting(now);
    final emoji = Fina.greetingEmoji(now);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name == 'du' ? '$greeting $emoji' : '$greeting, $name $emoji', style: ZText.greeting, maxLines: 2),
              const SizedBox(height: 4),
              Text(Dates.longDay(now), style: ZText.secondary),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => context.push('/profile'),
          child: Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: const BoxDecoration(gradient: ZColors.accentGradient, shape: BoxShape.circle),
            child: Text(
              name == 'du' ? '✿' : name.characters.first.toUpperCase(),
              style: ZText.sectionTitle.copyWith(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Verfügbares Guthaben + Fina
// -----------------------------------------------------------------------------

class _Hero extends ConsumerWidget {
  const _Hero({required this.ledger, required this.fina});

  final Ledger ledger;
  final FinaContext fina;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider);
    final forecast = ledger.forecastMonthEnd;
    final line = Fina.comment(fina);
    final available = ledger.available;
    final reserved = ledger.reservedInSpendable;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('VERFÜGBARES GUTHABEN', style: ZText.overline),
            const SizedBox(width: 10),
            if (streak > 0)
              StatusChip(text: '🔥 $streak ${streak == 1 ? 'Tag' : 'Tage'}', onTap: () => _showStreak(context, streak)),
          ],
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => context.push('/accounts'),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: available.toDouble()),
            duration: const Duration(milliseconds: 750),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: MoneyText(
                v.round(),
                style: ZText.amountHero,
                color: available < 0 ? ZColors.negative : ZColors.text,
                centsScale: 0.42,
              ),
            ),
          ),
        ),
        // Eczar hat eine große Unterlänge – darunter genügt wenig Abstand.
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (forecast.items.isNotEmpty)
              _HeroPill(
                icon: '🔮',
                text: 'Bis ${Dates.short(forecast.until)} voraussichtlich ${Money.format(forecast.end, compact: true)}',
                onTap: () => _showForecast(context, ref, forecast),
              ),
            if (reserved > 0)
              _HeroPill(
                icon: '🎯',
                text: '${Money.format(reserved, compact: true)} für Ziele zurückgelegt',
                onTap: () => context.go('/savings'),
              ),
          ],
        ),
        SizedBox(height: forecast.items.isNotEmpty || reserved > 0 ? 18 : 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: _SpeechBubble(text: line.text)),
            const SizedBox(width: 8),
            FinaAvatar(mood: line.mood, size: 62),
          ],
        ),
      ],
    );
  }

  void _showStreak(BuildContext context, int streak) {
    showZSheet(
      context,
      builder: (ctx) => SheetScaffold(
        title: '🔥 $streak ${streak == 1 ? 'Tag' : 'Tage'} in Folge',
        subtitle: 'So oft hast du hintereinander bei Zoëzas vorbeigeschaut.',
        primaryLabel: 'Weiter so',
        onPrimary: () => Navigator.pop(ctx),
        children: const [
          Text(
            'Wer regelmäßig reinschaut, behält entspannt den Überblick – auch an Tagen ohne Ausgaben. '
            'Die Serie reißt erst, wenn ein ganzer Tag ausfällt.',
            style: ZText.body,
          ),
        ],
      ),
    );
  }

  void _showForecast(BuildContext context, WidgetRef ref, Forecast f) {
    showZSheet(context, builder: (_) => _ForecastSheet(forecast: f));
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.text, this.onTap});

  final String icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ZColors.card.withValues(alpha: 0.75),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  text,
                  style: ZText.small.copyWith(color: ZColors.text, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: Container(
        key: ValueKey(text),
        padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
        decoration: const BoxDecoration(
          color: ZColors.card,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(22),
            topRight: Radius.circular(22),
            bottomLeft: Radius.circular(22),
            bottomRight: Radius.circular(6),
          ),
          boxShadow: [BoxShadow(color: ZColors.shadow, blurRadius: 18, offset: Offset(0, 6), spreadRadius: -6)],
        ),
        child: Text(text, style: ZText.fina),
      ),
    );
  }
}

class _ForecastSheet extends ConsumerWidget {
  const _ForecastSheet({required this.forecast});
  final Forecast forecast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = forecast;
    final today = ref.watch(todayProvider);
    return SheetScaffold(
      title: 'Vorschau bis ${Dates.short(f.until)}',
      subtitle: 'Was voraussichtlich noch kommt. Dein Kontostand ändert sich erst, wenn wirklich gebucht wird.',
      children: [
        _ForecastRow(label: 'Jetzt verfügbar', amount: f.start, bold: true),
        const Divider(height: 22),
        for (var i = 0; i < f.items.length; i++)
          _ForecastRow(
            label: f.items[i].title,
            detail: !Dates.dateOnly(f.items[i].date).isAfter(today) ? 'fällig' : Dates.short(f.items[i].date),
            amount: f.deltas[i],
            signed: true,
          ),
        const Divider(height: 22),
        _ForecastRow(label: 'Voraussichtlich übrig', amount: f.end, bold: true, highlight: true),
      ],
    );
  }
}

class _ForecastRow extends StatelessWidget {
  const _ForecastRow({
    required this.label,
    required this.amount,
    this.detail,
    this.bold = false,
    this.signed = false,
    this.highlight = false,
  });

  final String label;
  final String? detail;
  final int amount;
  final bool bold;
  final bool signed;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight
        ? (amount < 0 ? ZColors.negative : ZColors.positive)
        : signed
        ? (amount > 0 ? ZColors.positive : ZColors.text)
        : ZColors.text;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: label, style: bold ? ZText.itemTitle : ZText.body),
                  if (detail != null) TextSpan(text: '  $detail', style: ZText.small),
                ],
              ),
            ),
          ),
          Text(
            Money.format(amount, signed: signed),
            style: (bold ? ZText.amountSmall : ZText.amountList).copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Überblick
// -----------------------------------------------------------------------------

class _Overview extends StatelessWidget {
  const _Overview({required this.ledger, required this.summary});

  final Ledger ledger;
  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final hasSavings = ledger.accounts.any((a) => a.type == AccountType.savings && !a.archived);
    final monthName = summary.month.shortName;
    return ZCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      onTap: () => context.push('/month/${summary.month.key}'),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _Stat(emoji: '👛', label: 'Insgesamt', amount: ledger.totalBalance),
              ),
              Expanded(
                child: hasSavings
                    ? _Stat(emoji: '🐷', label: 'Sparkonto', amount: ledger.savingsAccountsBalance)
                    : _Stat(emoji: '🎯', label: 'Für Ziele', amount: ledger.reservedInSpendable),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  emoji: '🌱',
                  label: 'Einnahmen $monthName',
                  amount: summary.income,
                  color: ZColors.positive,
                ),
              ),
              Expanded(
                child: _Stat(emoji: '🛍️', label: 'Ausgaben $monthName', amount: summary.expenses),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(color: ZColors.accentSoft, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Im ${summary.month.monthName} bisher übrig',
                    style: ZText.secondary.copyWith(color: ZColors.text),
                  ),
                ),
                Text(
                  Money.format(summary.saved, signed: true, compact: true),
                  style: ZText.label.copyWith(color: summary.saved >= 0 ? ZColors.positive : ZColors.negative),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, size: 18, color: ZColors.textSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.emoji, required this.label, required this.amount, this.color});

  final String emoji;
  final String label;
  final int amount;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$emoji  $label', style: ZText.small, maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: MoneyText(amount, style: ZText.amountMedium, color: color, showCents: false),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Tipp-Karte
// -----------------------------------------------------------------------------

class _TipCard extends ConsumerWidget {
  const _TipCard({required this.tip, required this.due});

  final FinaTip tip;
  final List<PlannedItem> due;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ZCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
      onTap: () {
        switch (tip.action) {
          case FinaTipAction.quickAdd:
            ref
                .read(quickAddRequestProvider.notifier)
                .request(QuickAddRequest(title: tip.quickTitle, amount: tip.quickAmount));
          case FinaTipAction.showDue:
            if (due.isNotEmpty) showPlannedSheet(context, due.first);
          case FinaTipAction.openBudgets:
            context.push('/budgets');
          case FinaTipAction.openGoals:
            context.go('/savings');
          case FinaTipAction.backup:
            context.push('/data');
          case null:
            break;
        }
      },
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: ZColors.accentSoft, borderRadius: BorderRadius.circular(14)),
            child: Text(tip.emoji, style: const TextStyle(fontSize: 19)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(tip.text, style: ZText.body.copyWith(fontSize: 14.5))),
          const Icon(Icons.chevron_right_rounded, color: ZColors.textTertiary),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Ausgabenliste
// -----------------------------------------------------------------------------

enum _Sort {
  newest('Neueste'),
  largest('Teuerste'),
  oldest('Älteste'),
  category('Kategorie');

  const _Sort(this.label);
  final String label;
}

class _ExpenseList extends ConsumerWidget {
  const _ExpenseList({required this.summary, required this.month});

  final MonthSummary summary;
  final YearMonth month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value ?? const {};
    final sort = _Sort.values.firstWhereOrNull((s) => s.name == settings[SettingKeys.homeSort]) ?? _Sort.newest;
    final categories = ref.watch(categoriesByIdProvider);
    final list = summary.flow.expenseBookings.toList();
    switch (sort) {
      case _Sort.newest:
        break;
      case _Sort.largest:
        list.sort((a, b) => b.amount.compareTo(a.amount));
      case _Sort.oldest:
        list.sort((a, b) => a.date.compareTo(b.date));
      case _Sort.category:
        list.sort((a, b) {
          final c = (categories[a.categoryId]?.name ?? '').compareTo(categories[b.categoryId]?.name ?? '');
          return c != 0 ? c : b.amount.compareTo(a.amount);
        });
    }
    const limit = 12;
    final shown = list.take(limit).toList();

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList.list(
        children: [
          SectionHeader(
            title: 'Deine Ausgaben',
            subtitle: list.isEmpty
                ? 'Noch nichts im ${month.monthName}'
                : '${list.length} ${list.length == 1 ? 'Buchung' : 'Buchungen'} im ${month.monthName}',
            trailing: PopupMenuButton<_Sort>(
              initialValue: sort,
              onSelected: (s) => ref.read(settingsRepoProvider).set(SettingKeys.homeSort, s.name),
              itemBuilder: (_) => [for (final s in _Sort.values) PopupMenuItem(value: s, child: Text(s.label))],
              child: ZPill(
                dense: true,
                label: sort.label,
                trailing: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: ZColors.textSecondary),
              ),
            ),
          ),
          if (list.isEmpty)
            ZCard(
              child: EmptyState(
                emoji: '🌷',
                title: 'Noch ganz frisch hier',
                text: 'Tippe unten auf das Plus und trag deine erste Ausgabe ein.',
                action: SoftButton(
                  label: 'Ausgabe eintragen',
                  icon: Icons.add_rounded,
                  onPressed: () => showBookingEditor(context),
                ),
              ),
            ),
          for (final b in shown) ...[BookingTile(booking: b, showDate: true), const SizedBox(height: 10)],
          if (list.length > limit)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Center(
                child: SoftButton(
                  label: 'Alle ${list.length} im ${month.monthName} ansehen',
                  onPressed: () => context.push('/month/${month.key}'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

extension BookingListX on Iterable<Booking> {
  int get total => fold(0, (s, b) => s + b.amount);
}
