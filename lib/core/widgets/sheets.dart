import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format/money.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'basics.dart';

/// Bottom-Sheet im Zoëzas-Stil (über der Navigationsleiste, mit Griff).
Future<T?> showZSheet<T>(BuildContext context, {required WidgetBuilder builder, bool expand = false}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: ZColors.card,
    barrierColor: ZColors.text.withValues(alpha: 0.28),
    builder: (ctx) {
      final content = Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: builder(ctx),
      );
      return expand ? SizedBox(height: MediaQuery.sizeOf(ctx).height * 0.92, child: content) : content;
    },
  );
}

/// Grundgerüst für Formulare in Sheets: Griff, Titel, Inhalt, Aktionen.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.primaryLabel,
    this.onPrimary,
    this.secondary,
    this.headerTrailing,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final Widget? secondary;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: ZText.sectionTitle.copyWith(fontSize: 21)),
                      if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: ZText.secondary)],
                    ],
                  ),
                ),
                ?headerTrailing,
              ],
            ),
            const SizedBox(height: 18),
            ...children,
            if (primaryLabel != null) ...[
              const SizedBox(height: 22),
              PrimaryButton(label: primaryLabel!, onPressed: onPrimary),
            ],
            if (secondary != null) ...[const SizedBox(height: 10), Center(child: secondary!)],
          ],
        ),
      ),
    );
  }
}

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 40,
      height: 5,
      decoration: BoxDecoration(color: ZColors.line, borderRadius: BorderRadius.circular(3)),
    ),
  );
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Ja',
  String cancelLabel = 'Abbrechen',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message, style: ZText.body.copyWith(color: ZColors.textSecondary)),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel, style: ZText.label.copyWith(color: ZColors.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            confirmLabel,
            style: ZText.label.copyWith(color: destructive ? ZColors.negative : ZColors.accentDeep),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
}

/// Label über einem Feld.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
    child: Text(text, style: ZText.small.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.2)),
  );
}

/// Eingabefeld für Geldbeträge („12,50“).
class AmountField extends StatelessWidget {
  const AmountField({super.key, required this.controller, this.hint = '0,00', this.autofocus = false, this.onChanged});

  final TextEditingController controller;
  final String hint;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      style: ZText.amountMedium,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: ZText.amountMedium.copyWith(color: ZColors.textTertiary),
        suffixText: '€',
        suffixStyle: ZText.amountSmall.copyWith(color: ZColors.textSecondary),
      ),
    );
  }

  static int? valueOf(TextEditingController c) => Money.parse(c.text);

  static String textFor(int? cents) {
    if (cents == null || cents == 0) return '';
    final euros = cents ~/ 100;
    final rest = cents % 100;
    return rest == 0 ? '$euros' : '$euros,${rest.toString().padLeft(2, '0')}';
  }
}

/// Auswahl einer Pastellfarbe.
class PastelPicker extends StatelessWidget {
  const PastelPicker({super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final c in ZColors.pastels)
          GestureDetector(
            onTap: () => onChanged(c.toARGB32()),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(color: c.toARGB32() == value ? ZColors.accentDeep : Colors.transparent, width: 2.5),
              ),
            ),
          ),
      ],
    );
  }
}

const _emojiChoices = [
  '🛒',
  '☕',
  '🍝',
  '🍕',
  '🥐',
  '🍣',
  '🍷',
  '🏠',
  '💡',
  '📦',
  '🧴',
  '💄',
  '💇',
  '🚲',
  '🚗',
  '🚆',
  '⛽',
  '🎡',
  '🎬',
  '🎮',
  '🎵',
  '📚',
  '💻',
  '📱',
  '🎧',
  '👗',
  '👟',
  '📺',
  '💊',
  '🏋️',
  '🧘',
  '🎁',
  '✈️',
  '🌴',
  '🏖️',
  '🛡️',
  '🐶',
  '🐱',
  '👶',
  '🌿',
  '🪴',
  '🧹',
  '🔧',
  '🎓',
  '💼',
  '🌱',
  '🎀',
  '💰',
  '📈',
  '↩️',
  '🐷',
  '🎯',
  '💍',
  '🚘',
  '🏡',
  '🎉',
  '✨',
  '❤️',
  '⭐',
  '🍦',
];

/// Emoji-Auswahl: kuratierte Liste plus freie Eingabe.
Future<String?> pickEmoji(BuildContext context, {String? current}) {
  final controller = TextEditingController();
  return showZSheet<String>(
    context,
    builder: (ctx) => SheetScaffold(
      title: 'Emoji wählen',
      children: [
        GridView.count(
          crossAxisCount: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: [
            for (final e in _emojiChoices)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.pop(ctx, e),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: e == current ? ZColors.accentLight : ZColors.accentSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(e, style: const TextStyle(fontSize: 22)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Eigenes Emoji eintippen'),
          onSubmitted: (v) {
            final t = v.trim();
            if (t.isNotEmpty) Navigator.pop(ctx, t.characters.first);
          },
        ),
      ],
    ),
  );
}

Future<DateTime?> pickDate(BuildContext context, {required DateTime initial, DateTime? first, DateTime? last}) {
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first ?? DateTime(2000),
    lastDate: last ?? DateTime(2100),
    locale: const Locale('de', 'DE'),
  );
}
