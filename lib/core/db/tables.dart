// drift-Check-Constraints verweisen bewusst auf die eigene Spalte.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

import '../../domain/enums.dart';

// Geldbeträge sind immer ganze Cent (int), Beträge in Buchungen immer positiv –
// die Richtung ergibt sich aus dem Buchungstyp.

@DataClassName('Account')
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get emoji => text().withDefault(const Constant('💳'))();
  IntColumn get color => integer()();
  TextColumn get type => textEnum<AccountType>()();

  /// Kontostand zum [openingDate]. Buchungen vor diesem Tag sind darin schon
  /// enthalten: Sie zählen für Statistiken, verändern den Kontostand aber nicht.
  IntColumn get openingBalance => integer().withDefault(const Constant(0))();
  DateTimeColumn get openingDate => dateTime()();

  /// Zählt das Konto zum frei verfügbaren Geld auf dem Startbildschirm?
  BoolColumn get includeInAvailable => boolean().withDefault(const Constant(true))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@DataClassName('Category')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  TextColumn get emoji => text()();
  IntColumn get color => integer()();
  TextColumn get kind => textEnum<CategoryKind>()();

  /// Schlüssel der mitgelieferten Kategorien (für Fina-Texte), sonst null.
  TextColumn get builtInKey => text().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@DataClassName('RecurringRule')
class RecurringRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => textEnum<BookingType>()();
  IntColumn get amount => integer().check(amount.isBiggerThanValue(0))();
  IntColumn get accountId => integer().references(Accounts, #id)();
  @ReferenceName('incomingRecurringRules')
  IntColumn get toAccountId => integer().nullable().references(Accounts, #id)();
  IntColumn get categoryId => integer().nullable().references(Categories, #id, onDelete: KeyAction.setNull)();
  TextColumn get title => text()();
  TextColumn get note => text().nullable()();
  TextColumn get frequency => textEnum<Frequency>()();

  /// Erster Termin der Reihe; alle weiteren werden davon abgeleitet.
  DateTimeColumn get startDate => dateTime()();

  /// Fester Tag im Monat für monatliche Rhythmen (31 = immer Monatsende).
  /// null = Tag des Startdatums.
  IntColumn get dayOfMonth => integer().nullable()();
  DateTimeColumn get endDate => dateTime().nullable()();

  /// true: fällige Termine werden automatisch gebucht. false: Termine
  /// erscheinen als „fällig“ und werden bestätigt oder übersprungen.
  BoolColumn get autoBook => boolean().withDefault(const Constant(true))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Booking')
class Bookings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => textEnum<BookingType>()();
  TextColumn get status => textEnum<BookingStatus>()();
  IntColumn get amount => integer().check(amount.isBiggerThanValue(0))();
  IntColumn get accountId => integer().references(Accounts, #id)();

  /// Nur bei Umbuchungen: Zielkonto.
  @ReferenceName('incomingBookings')
  IntColumn get toAccountId => integer().nullable().references(Accounts, #id)();
  IntColumn get categoryId => integer().nullable().references(Categories, #id, onDelete: KeyAction.setNull)();
  TextColumn get title => text()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get date => dateTime()();

  /// Stammt die Buchung aus einem Dauerauftrag, verweist sie auf die Regel und
  /// den Termin. Die Kombination ist eindeutig – so wird kein Termin doppelt
  /// gebucht.
  IntColumn get recurringId => integer().nullable().references(RecurringRules, #id, onDelete: KeyAction.setNull)();
  DateTimeColumn get occurrenceDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {recurringId, occurrenceDate},
  ];
}

/// Monatsbudget je Kategorie (categoryId) oder für alle Ausgaben (null).
/// Gültig ab [validFrom] (JJJJMM) bis zum nächsten Eintrag derselben Kategorie –
/// so behalten vergangene Monate ihr damaliges Budget. amount 0 = kein Budget.
@DataClassName('Budget')
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().nullable().references(Categories, #id, onDelete: KeyAction.cascade)();
  IntColumn get amount => integer()();
  IntColumn get validFrom => integer()();
}

@DataClassName('SavingsGoal')
class SavingsGoals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get emoji => text()();
  IntColumn get color => integer()();
  IntColumn get targetAmount => integer().check(targetAmount.isBiggerThanValue(0))();
  DateTimeColumn get targetDate => dateTime().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Gesetzt, sobald das Ziel abgeschlossen ist – dann ist kein Geld mehr
  /// dafür reserviert.
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// Geld, das für ein Sparziel zurückgelegt (positiv) oder wieder entnommen
/// (negativ) wurde. Das ist eine Reservierung, keine Einnahme oder Ausgabe.
@DataClassName('GoalContribution')
class GoalContributions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get goalId => integer().references(SavingsGoals, #id, onDelete: KeyAction.cascade)();
  IntColumn get amount => integer()();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();

  /// Auf welchem Konto das Geld liegt. Liegt es auf einem „verfügbaren“ Konto,
  /// wird es vom verfügbaren Guthaben abgezogen.
  IntColumn get heldInAccountId => integer().nullable().references(Accounts, #id, onDelete: KeyAction.setNull)();

  /// Optional: die Umbuchung, mit der das Geld verschoben wurde.
  IntColumn get bookingId => integer().nullable().references(Bookings, #id, onDelete: KeyAction.cascade)();
}

@DataClassName('Debt')
class Debts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get person => text().withLength(min: 1, max: 60)();
  TextColumn get direction => textEnum<DebtDirection>()();
  IntColumn get amount => integer().check(amount.isBiggerThanValue(0))();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Manuell erledigt (z. B. erlassen), auch wenn noch ein Rest offen ist.
  DateTimeColumn get closedAt => dateTime().nullable()();
}

/// Teil- oder Vollzahlung einer Schuld. Erst die (optional verknüpfte) Buchung
/// verändert einen Kontostand.
@DataClassName('DebtPayment')
class DebtPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get debtId => integer().references(Debts, #id, onDelete: KeyAction.cascade)();
  IntColumn get amount => integer().check(amount.isBiggerThanValue(0))();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();
  IntColumn get bookingId => integer().nullable().references(Bookings, #id, onDelete: KeyAction.cascade)();
}

/// Einfache Schlüssel-Wert-Ablage für Profil und Einstellungen.
@DataClassName('SettingEntry')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Tage, an denen die App benutzt wurde (für die 🔥-Serie). JJJJMMTT.
@DataClassName('ActivityDay')
class ActivityDays extends Table {
  IntColumn get day => integer()();

  @override
  Set<Column> get primaryKey => {day};
}
