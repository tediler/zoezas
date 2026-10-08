import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format/money.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';
import '../theme/typography.dart';

/// Weiche, weiße Karte – der Grundbaustein fast jeder Fläche.
class ZCard extends StatelessWidget {
  const ZCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.color = ZColors.card,
    this.radius = ZRadius.card,
    this.shadow = true,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final double radius;
  final bool shadow;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: shape,
        boxShadow: shadow
            ? const [BoxShadow(color: ZColors.shadow, blurRadius: 24, offset: Offset(0, 8), spreadRadius: -6)]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: shape,
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          splashColor: ZColors.accentLight.withValues(alpha: 0.35),
          highlightColor: ZColors.accentSoft.withValues(alpha: 0.5),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Emoji in einem pastellfarbenen, abgerundeten Quadrat.
class EmojiTile extends StatelessWidget {
  const EmojiTile({super.key, required this.emoji, required this.color, this.size = 46});

  final String emoji;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(size * 0.32)),
      child: Text(emoji, style: TextStyle(fontSize: size * 0.46, height: 1.1)),
    );
  }
}

/// Geldbetrag in der Serifenschrift; Cent etwas kleiner und heller.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.cents, {
    super.key,
    this.style = ZText.amountMedium,
    this.color,
    this.showCents = true,
    this.signed = false,
    this.centsScale = 0.55,
  });

  final int cents;
  final TextStyle style;
  final Color? color;
  final bool showCents;
  final bool signed;
  final double centsScale;

  @override
  Widget build(BuildContext context) {
    final c = color ?? style.color ?? ZColors.text;
    // Ohne Cent-Anzeige kaufmännisch auf ganze Euro runden statt abschneiden.
    final value = showCents ? cents : (cents / 100).round() * 100;
    final sign = value < 0 ? '−' : (signed && value > 0 ? '+' : '');
    final small = style.copyWith(
      fontSize: (style.fontSize ?? 20) * centsScale,
      color: c.withValues(alpha: 0.55),
      letterSpacing: 0,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$sign${Money.wholePart(value)}',
            style: style.copyWith(color: c),
          ),
          if (showCents) TextSpan(text: Money.centsPart(value), style: small),
          TextSpan(text: ' €', style: small),
        ],
      ),
      maxLines: 1,
      softWrap: false,
    );
  }
}

/// Runde Pill, optional auswählbar.
class ZPill extends StatelessWidget {
  const ZPill({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.leading,
    this.trailing,
    this.color,
    this.selectedColor,
    this.dense = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? leading;
  final Widget? trailing;
  final Color? color;
  final Color? selectedColor;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? (selectedColor ?? ZColors.text) : (color ?? ZColors.card);
    final fg = selected ? Colors.white : ZColors.text;
    return Material(
      color: bg,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(horizontal: dense ? 12 : 16, vertical: dense ? 7 : 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 6)],
              Text(
                label,
                style: ZText.label.copyWith(color: fg, fontSize: dense ? 12.5 : 13.5),
              ),
              if (trailing != null) ...[const SizedBox(width: 4), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Kleiner Status-Chip, z. B. „🔥 3 Tage“.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.text,
    this.color = ZColors.card,
    this.textColor = ZColors.text,
    this.onTap,
  });

  final String text;
  final Color color;
  final Color textColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            text,
            style: ZText.small.copyWith(color: textColor, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

/// Dicker, runder Fortschrittsbalken mit optionalem Planungsanteil.
class ZProgressBar extends StatelessWidget {
  const ZProgressBar({
    super.key,
    required this.value,
    this.planned,
    this.color = ZColors.accent,
    this.background = ZColors.accentSoft,
    this.height = 10,
    this.gradient,
  });

  /// 0..1 (darf > 1 sein, wird gekappt).
  final double value;

  /// Wert inkl. Geplantem (heller dargestellt).
  final double? planned;
  final Color color;
  final Color background;
  final double height;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final v = value.clamp(0.0, 1.0);
        final p = (planned ?? 0).clamp(0.0, 1.0);
        // Volle Breite erzwingen – sonst schrumpft der Stack auf den gefüllten Teil.
        return Container(
          width: w,
          height: height,
          decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(height)),
          child: Stack(
            children: [
              if (planned != null && p > v)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  width: w * p,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(height),
                  ),
                ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                width: v == 0 ? 0 : (w * v).clamp(height, w),
                decoration: BoxDecoration(
                  color: gradient == null ? color : null,
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.subtitle, this.trailing, this.padding});

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ZText.sectionTitle),
                if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: ZText.secondary)],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Großer, runder Hauptbutton mit Akzentverlauf.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.icon, this.expand = true});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final child = AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled ? 1 : 0.45,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: ZColors.accentGradient,
          borderRadius: BorderRadius.circular(ZRadius.pill),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: ZColors.accent.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                    spreadRadius: -6,
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: enabled
                ? () {
                    HapticFeedback.lightImpact();
                    onPressed!();
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 17),
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8)],
                  Text(label, style: ZText.label.copyWith(color: Colors.white, fontSize: 15.5)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return child;
  }
}

/// Dezenter Zweitbutton.
class SoftButton extends StatelessWidget {
  const SoftButton({super.key, required this.label, required this.onPressed, this.icon, this.color, this.textColor});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final fg = (textColor ?? ZColors.accentDeep).withValues(alpha: onPressed == null ? 0.4 : 1);
    return Material(
      color: color ?? ZColors.accentSoft,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, color: fg, size: 18), const SizedBox(width: 6)],
              Flexible(
                child: Text(
                  label,
                  style: ZText.label.copyWith(color: fg),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Runder Icon-Button in Weiß.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 44,
    this.color = ZColors.card,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: size * 0.45, color: ZColors.text),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.emoji, required this.title, this.text, this.action});

  final String emoji;
  final String title;
  final String? text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(title, style: ZText.itemTitle, textAlign: TextAlign.center),
          if (text != null) ...[
            const SizedBox(height: 6),
            Text(text!, style: ZText.secondary, textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

/// Einfache Zeile in Einstellungslisten.
class ZListRow extends StatelessWidget {
  const ZListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.titleStyle,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 14)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: titleStyle ?? ZText.itemTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: ZText.secondary, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          ],
        ),
      ),
    );
  }
}
