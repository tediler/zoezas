// Fachliche Aufzählungen. Die Namen landen als Text in der Datenbank und im
// Export – deshalb niemals umbenennen, nur neue Werte ergänzen.

enum AccountType {
  checking('Girokonto', '💳'),
  savings('Sparkonto', '🐷'),
  cash('Bargeld', '👛'),
  other('Sonstiges', '🗂️');

  const AccountType(this.label, this.emoji);
  final String label;
  final String emoji;

  /// Zählt ein Konto dieses Typs standardmäßig zum frei verfügbaren Geld?
  bool get defaultIncludeInAvailable => this != AccountType.savings;
}

enum BookingType {
  expense('Ausgabe'),
  income('Einnahme'),
  transfer('Umbuchung');

  const BookingType(this.label);
  final String label;
}

/// Gebucht = Geld ist wirklich geflossen. Geplant = kommt noch, verändert keinen
/// Kontostand. Übersprungen = ein Termin eines Dauerauftrags, der bewusst
/// ausgelassen wurde (zählt nirgends, verhindert nur, dass er erneut auftaucht).
enum BookingStatus { booked, planned, skipped }

enum CategoryKind { expense, income }

enum Frequency {
  weekly('Wöchentlich', 'jede Woche'),
  biweekly('Alle 2 Wochen', 'alle zwei Wochen'),
  monthly('Monatlich', 'jeden Monat'),
  quarterly('Vierteljährlich', 'alle drei Monate'),
  halfYearly('Halbjährlich', 'alle sechs Monate'),
  yearly('Jährlich', 'jedes Jahr');

  const Frequency(this.label, this.phrase);
  final String label;
  final String phrase;
}

enum DebtDirection {
  iOwe('Ich schulde'),
  owedToMe('Mir wird geschuldet');

  const DebtDirection(this.label);
  final String label;
}

/// Wie Fina mit der Person spricht (Frage im Onboarding).
enum FinaTone {
  cheeky('Frech & verspielt', '😜'),
  warm('Lieb & ermutigend', '🌸'),
  calm('Kurz & klar', '✍️');

  const FinaTone(this.label, this.emoji);
  final String label;
  final String emoji;
}

/// Worauf die Person gerade Wert legt (Frage im Onboarding).
enum MoneyFocus {
  save('Mehr sparen', '🐷'),
  overview('Überblick behalten', '🧭'),
  debts('Schulden loswerden', '🧾'),
  bigGoal('Auf etwas Großes hinsparen', '🎯');

  const MoneyFocus(this.label, this.emoji);
  final String label;
  final String emoji;
}
