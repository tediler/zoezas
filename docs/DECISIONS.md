# Technische Entscheidungen

Von Claude getroffen (Sitzung 07.10.2026), noch nicht von Tobias bestätigt.
Jede Entscheidung mit Begründung und der Alternative, die verworfen wurde.

## D-001 Flutter 3.35.2 bleibt, Pakete sind festgelegt

Das global installierte Flutter (`C:\dev\flutter`) wird wie bei der Koch-App
nicht aktualisiert. Die Pakete sind auf Versionen gesetzt, die mit Dart 3.9
laufen (Riverpod 3.3, go_router 17, drift 2.29, home_widget 0.9, file_picker 11,
share_plus 12). `flutter pub add` ohne Version würde teils inkompatible Versionen
wählen.

## D-002 Riverpod 3 + go_router + drift

Derselbe Stack wie in der Koch-App, damit beide Projekte gleich zu warten sind.
drift statt Hive/Isar: echte relationale Daten (Buchung ↔ Konto ↔ Kategorie ↔
Dauerauftrag), Fremdschlüssel, eindeutige Schlüssel als Schutz vor
Doppelbuchungen, reaktive Streams, Migrationen, läuft auf Android und iOS.

## D-003 Reine Finanzlogik in einem `Ledger`

Alle Rechenregeln stehen an einer Stelle (`lib/domain/ledger.dart`), ohne
Flutter- oder Datenbankabhängigkeit, und sind mit Unit-Tests belegt. Verworfen:
Berechnung verteilt in SQL-Abfragen – schneller, aber schwerer zu prüfen. Für
die erwartete Datenmenge ist die In-Memory-Rechnung schnell genug.

## D-004 Status statt eigener Tabelle für Planung

Geplante und übersprungene Posten sind Buchungen mit Status `planned`/`skipped`.
Bestätigen ist ein Statuswechsel derselben Zeile – es entsteht nie eine Kopie.
Termine von Daueraufträgen werden *berechnet*; gespeichert wird nur, was mit
einem Termin passiert ist (gebucht, einzeln geändert, übersprungen).

## D-005 Startsaldo mit Startdatum je Konto

Wer die App mitten im Monat einrichtet, gibt den aktuellen Kontostand ein. Damit
nachgetragene ältere Buchungen (z. B. das Gehalt vom 1.) diesen Stand nicht
verfälschen, zählen Buchungen vor dem Startdatum nur für die Statistik. Die
Schnelleingabe weist darauf hin. Kontostand korrigieren verschiebt den Startsaldo
– ohne künstliche Einnahme/Ausgabe.

## D-006 „Verfügbares Guthaben“ = Geld auf Ausgabenkonten

Die große Zahl auf dem Startbildschirm ist echtes Geld (Giro + Bargeld, ohne
Sparkonto, minus Reservierungen für Sparziele). Was im Monat übrig ist
(Einnahmen − Ausgaben), steht separat darunter. Verworfen: die große Zahl als
„Monatsbudget“ – sie würde bei Übertrag aus dem Vormonat nicht zum Bankkonto
passen. *Offene Frage, ob er das so möchte.*

## D-007 Sparziele als Reservierungen

Einzahlungen auf ein Ziel sind keine Ausgaben. Sie merken sich, auf welchem
Konto das Geld liegt; optional entsteht zugleich eine Umbuchung (Giro →
Sparkonto). So ist ein Ziel unabhängig vom Konto, und nichts wird doppelt
gezählt.

## D-008 Schulden ohne automatische Buchung

Eine Schuld ist eine Notiz. Erst eine Zahlung erzeugt – wenn gewünscht – eine
Ausgabe bzw. Einnahme. Schulden fließen nicht in die Monatsprognose ein, damit
sie nicht doppelt zählen, falls die Person die Rückzahlung zusätzlich plant.

## D-009 Budgets mit „gültig ab Monat“

Ein Budget gilt ab einem Monat bis zur nächsten Änderung. Vergangene Monate
behalten ihr damaliges Budget, ohne dass man jeden Monat neu planen muss.

## D-010 Fina lokal und regelbasiert

Keine KI, kein Netz. Situation × Tonfall, stabil pro Tag gewählt. Erweiterbar,
indem man in `fina.dart` Situationen oder Formulierungen ergänzt.

## D-011 Schriften lokal aus OFL-Quellen

UI: Work Sans, Beträge: Eczar (beide SIL Open Font License, aus dem
`flutter_gallery_assets`-Paket im lokalen Pub-Cache). Eczar hat eine große
Unterlänge, Abstände unter großen Beträgen sind darauf abgestimmt. Eine
ausdrucksstärkere Serifenschrift (z. B. Fraunces, Instrument Serif) müsste aus
dem Netz geladen werden – siehe offene Fragen.

## D-012 Homescreen-Widget nativ, Daten über home_widget

Android: `AppWidgetProvider` mit `RemoteViews` (Kotlin). iOS: WidgetKit (Swift).
`home_widget` übernimmt nur die Datenübergabe und das Öffnen per Link. Dazu
App-Shortcuts über `quick_actions` (Icon lange drücken), auf beiden Plattformen.

## D-013 🔥-Serie zählt Tage mit App-Nutzung

Ausgabenfreie Tage sind gut und sollen die Serie nicht brechen. Deshalb zählt
jeder Tag, an dem die App geöffnet wurde.

## D-014 Daueraufträge: Änderungen ab dem nächsten Termin

Ändert sich Rhythmus oder Termin, beginnt die Reihe am gewählten nächsten Termin
neu (frühestens nach dem letzten erledigten). Bereits Gebuchtes bleibt
unverändert. „Immer am Monatsende“ speichert den Tag 31, damit ein Gehalt am 31.
nach einem kurzen Monat nicht dauerhaft auf den 30. rutscht.
