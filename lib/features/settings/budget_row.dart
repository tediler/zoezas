import 'package:flutter/material.dart';

import '../../core/format/money.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/basics.dart';
import '../../domain/budgets.dart';
import '../../domain/enums.dart';
import '../../domain/fina.dart';

/// Eine Budgetzeile: Emoji, Name, Fortschritt (Geplantes heller) und Finas
/// freundlicher Stups.
class BudgetRow extends StatelessWidget {
  const BudgetRow({super.key, required this.status, required this.tone, this.onTap});

  final BudgetStatus status;
  final FinaTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = status;
    final color = switch (s.level) {
      BudgetLevel.relaxed => s.isTotal ? ZColors.accent : ZColors.strongFor(Color(s.category!.color)),
      BudgetLevel.almost => ZColors.warning,
      BudgetLevel.over => ZColors.negative,
    };
    final bg = switch (s.level) {
      BudgetLevel.relaxed => ZColors.accentSoft,
      BudgetLevel.almost => ZColors.warningLight,
      BudgetLevel.over => ZColors.negativeLight,
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                EmojiTile(
                  emoji: s.isTotal ? '🌸' : s.category!.emoji,
                  color: s.isTotal ? ZColors.accentLight : Color(s.category!.color),
                  size: 36,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.isTotal ? 'Monatsbudget' : s.category!.name,
                        style: ZText.itemTitle.copyWith(fontSize: 14.5),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        Fina.budgetNudge(s, tone),
                        style: ZText.small.copyWith(
                          color: s.level == BudgetLevel.relaxed ? ZColors.textSecondary : color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: Money.format(s.spent, compact: true), style: ZText.label),
                      TextSpan(text: ' / ${Money.format(s.limit, compact: true)}', style: ZText.small),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ZProgressBar(value: s.ratio, planned: s.plannedRatio, color: color, background: bg, height: 8),
          ],
        ),
      ),
    );
  }
}
