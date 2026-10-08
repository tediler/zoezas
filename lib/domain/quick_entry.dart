import '../core/format/money.dart';

/// Ergebnis der Schnelleingabe „Eis 3,50“ → Titel „Eis“, 350 Cent.
class QuickEntry {
  const QuickEntry({required this.title, this.amount});

  final String title;
  final int? amount;
}

abstract final class QuickEntryParser {
  static final _amountAtEnd = RegExp(
    r'^(.*?)\s*(\d{1,3}(?:\.\d{3})*(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?)\s*(?:€|eur|euro)?$',
    caseSensitive: false,
  );
  static final _amountAtStart = RegExp(
    r'^(?:€\s*)?(\d+(?:[.,]\d{1,2})?)\s*(?:€|eur|euro)?\s+(.+)$',
    caseSensitive: false,
  );

  /// Erkennt einen Betrag am Ende („Eis 3,50“, „Kino 12 €“) oder am Anfang
  /// („3,50 Eis“). Ohne Betrag bleibt der ganze Text der Titel.
  static QuickEntry parse(String input) {
    final text = input.trim();
    if (text.isEmpty) return const QuickEntry(title: '');
    final end = _amountAtEnd.firstMatch(text);
    if (end != null && end.group(1)!.trim().isNotEmpty) {
      final amount = Money.parse(end.group(2)!);
      if (amount != null && amount > 0) return QuickEntry(title: end.group(1)!.trim(), amount: amount);
    }
    final start = _amountAtStart.firstMatch(text);
    if (start != null) {
      final amount = Money.parse(start.group(1)!);
      if (amount != null && amount > 0) return QuickEntry(title: start.group(2)!.trim(), amount: amount);
    }
    return QuickEntry(title: text);
  }
}
