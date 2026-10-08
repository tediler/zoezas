import 'package:intl/intl.dart';

/// Formatieren und Einlesen von Geldbeträgen. Intern immer ganze Cent.
abstract final class Money {
  static final _withCents = NumberFormat.currency(locale: 'de_DE', symbol: '€', decimalDigits: 2);
  static final _noCents = NumberFormat.currency(locale: 'de_DE', symbol: '€', decimalDigits: 0);
  static final _group = NumberFormat.decimalPattern('de_DE');

  /// „1.750,00 €“. Mit [signed] bekommt ein positiver Betrag ein „+“.
  /// Mit [compact] fallen „,00“-Cents weg („1.750 €“).
  static String format(int cents, {bool signed = false, bool compact = false}) {
    final value = cents / 100;
    final f = compact && cents % 100 == 0 ? _noCents : _withCents;
    final text = f.format(value.abs());
    if (cents < 0) return '−$text';
    if (signed && cents > 0) return '+$text';
    return text;
  }

  /// Betrag mit Vorzeichen nach Buchungsrichtung: „−12,50 €“ / „+1.800 €“.
  static String formatFlow(int cents, {required bool isOutflow, bool compact = true}) {
    final text = format(cents.abs(), compact: compact);
    return isOutflow ? '−$text' : '+$text';
  }

  /// Ganzzahliger Teil mit Tausenderpunkten, ohne Vorzeichen („1.750“).
  static String wholePart(int cents) => _group.format(cents.abs() ~/ 100);

  /// Nachkommastellen mit Komma („,05“).
  static String centsPart(int cents) => ',${(cents.abs() % 100).toString().padLeft(2, '0')}';

  /// Liest „12,5“, „1.234,56“, „12.50“ oder „12“ als Cent. null bei Unsinn.
  static int? parse(String input) {
    var s = input.trim().replaceAll('€', '').replaceAll(' ', '').replaceAll(' ', '');
    if (s.isEmpty) return null;
    final negative = s.startsWith('-') || s.startsWith('−');
    if (negative) s = s.substring(1);
    final lastComma = s.lastIndexOf(',');
    final lastDot = s.lastIndexOf('.');
    String normalized;
    if (lastComma >= 0 && lastDot >= 0) {
      // Das letzte Trennzeichen ist das Dezimaltrennzeichen.
      normalized = lastComma > lastDot ? s.replaceAll('.', '').replaceAll(',', '.') : s.replaceAll(',', '');
    } else if (lastComma >= 0) {
      normalized = s.replaceAll(',', '.');
    } else if (lastDot >= 0) {
      // „1.234“ (drei Ziffern nach dem Punkt, mehrere Gruppen) = Tausender.
      final parts = s.split('.');
      final looksLikeThousands = parts.length > 2 || (parts.length == 2 && parts[1].length == 3);
      normalized = looksLikeThousands ? s.replaceAll('.', '') : s;
    } else {
      normalized = s;
    }
    if (!RegExp(r'^\d+(\.\d{0,2})?$').hasMatch(normalized)) return null;
    final parts = normalized.split('.');
    final euros = int.parse(parts[0]);
    final cents = parts.length > 1 && parts[1].isNotEmpty ? int.parse(parts[1].padRight(2, '0')) : 0;
    final result = euros * 100 + cents;
    return negative ? -result : result;
  }
}
