import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/format/dates.dart';
import '../../core/format/money.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/basics.dart';
import '../../data/providers.dart';
import '../../domain/enums.dart';
import '../../domain/fina.dart';
import '../../domain/ledger.dart';
import 'booking_editor.dart';
import 'planned_sheet.dart';

/// Eine Buchung als weiche, weiße Karte: Emoji-Kachel, Name, kleine
/// Beschreibung, Betrag.
class BookingTile extends ConsumerWidget {
  const BookingTile({super.key, required this.booking, this.showDate = false});

  final Booking booking;
  final bool showDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesByIdProvider);
    final accounts = ref.watch(accountsByIdProvider);
    final rule = booking.recurringId == null ? null : ref.watch(ledgerProvider)?.rule(booking.recurringId!);
    final category = categories[booking.categoryId];
    final b = booking;

    final (emoji, tileColor) = switch (b.type) {
      BookingType.transfer => ('↔️', ZColors.pastels[2]),
      _ => (
        category?.emoji ?? (b.type == BookingType.income ? '💰' : '✨'),
        category != null ? Color(category.color) : ZColors.pastels[0],
      ),
    };

    String subtitle;
    if (b.type == BookingType.transfer) {
      subtitle = '${accounts[b.accountId]?.name ?? '?'} → ${accounts[b.toAccountId]?.name ?? '?'}';
    } else {
      subtitle = Fina.describe(b, category, recurring: rule?.frequency);
    }
    if (showDate) subtitle = '${Dates.relative(b.date)} · $subtitle';

    final planned = b.status == BookingStatus.planned;
    final amountText = switch (b.type) {
      BookingType.expense => Money.formatFlow(b.amount, isOutflow: true),
      BookingType.income => Money.formatFlow(b.amount, isOutflow: false),
      BookingType.transfer => Money.format(b.amount, compact: true),
    };
    final amountColor = planned
        ? ZColors.textSecondary
        : switch (b.type) {
            BookingType.income => ZColors.positive,
            BookingType.transfer => ZColors.textSecondary,
            BookingType.expense => ZColors.text,
          };

    return ZCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 18, 14),
      onTap: () => planned && b.recurringId != null
          ? showPlannedSheet(context, PlannedItem.fromBooking(b, rule))
          : showBookingEditor(context, existing: b),
      child: Row(
        children: [
          EmojiTile(emoji: emoji, color: tileColor),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(b.title, style: ZText.itemTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (planned) ...[const SizedBox(width: 6), const _Tag('geplant')],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: ZText.secondary.copyWith(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(amountText, style: ZText.amountList.copyWith(color: amountColor)),
        ],
      ),
    );
  }
}

/// Ein offener Posten (geplant oder Termin eines Dauerauftrags).
class PlannedTile extends ConsumerWidget {
  const PlannedTile({super.key, required this.item, this.compact = false});

  final PlannedItem item;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesByIdProvider);
    final accounts = ref.watch(accountsByIdProvider);
    final category = categories[item.categoryId];
    final today = ref.watch(todayProvider);
    final due = !Dates.dateOnly(item.date).isAfter(today);
    final emoji = item.type == BookingType.transfer ? '↔️' : (category?.emoji ?? '🗓️');
    final color = item.type == BookingType.transfer
        ? ZColors.pastels[2]
        : (category != null ? Color(category.color) : ZColors.pastels[1]);
    final when = due
        ? (Dates.sameDay(item.date, today) ? 'heute fällig' : 'fällig seit ${Dates.short(item.date)}')
        : '${Dates.relative(item.date)} · ${Dates.distance(item.date, now: today)}';
    final detail = item.type == BookingType.transfer
        ? '${accounts[item.accountId]?.name ?? '?'} → ${accounts[item.toAccountId]?.name ?? '?'}'
        : (item.rule != null ? item.rule!.frequency.label : 'geplant');
    final amountText = switch (item.type) {
      BookingType.expense => Money.formatFlow(item.amount, isOutflow: true),
      BookingType.income => Money.formatFlow(item.amount, isOutflow: false),
      BookingType.transfer => Money.format(item.amount, compact: true),
    };

    return ZCard(
      padding: EdgeInsets.fromLTRB(14, compact ? 12 : 14, 18, compact ? 12 : 14),
      onTap: () => item.isRecurring || due
          ? showPlannedSheet(context, item)
          : showBookingEditor(context, existing: item.booking),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Opacity(
                opacity: 0.85,
                child: EmojiTile(emoji: emoji, color: color, size: compact ? 40 : 46),
              ),
              if (item.isRecurring)
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: const BoxDecoration(color: ZColors.card, shape: BoxShape.circle),
                    child: const Icon(Icons.autorenew_rounded, size: 13, color: ZColors.accentDeep),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: ZText.itemTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(
                  '$when · $detail',
                  style: ZText.secondary.copyWith(
                    fontSize: 13,
                    color: due ? ZColors.accentDeep : ZColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(amountText, style: ZText.amountList.copyWith(color: ZColors.textSecondary)),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: ZColors.accentSoft, borderRadius: BorderRadius.circular(99)),
    child: Text(
      text,
      style: ZText.small.copyWith(fontSize: 10.5, color: ZColors.accentDeep, fontWeight: FontWeight.w600),
    ),
  );
}
