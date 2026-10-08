# Roadmap

## Stand 07.10.2026 – Version 0.1.0

Auf dem Emulator `Medium_Phone_API_35_3` durchgespielt:

- Onboarding ohne Konto: Name, Tonfall, Schwerpunkt, Kontostände, Gehalt mit
  Zahltag (inkl. „ist das Gehalt diesen Monat schon da?“)
- Startbildschirm: Begrüßung, verfügbares Guthaben mit 🔥-Serie, Prognose bis
  Monatsende (aufklappbar), Fina-Kommentar mit Figur, Überblick, Tipp-Karte,
  „Wartet auf dich“, Budgets, „Demnächst“, Ausgabenliste mit Sortierung
- Schnelleingabe über das Plus: eigener Ziffernblock, Vorschläge aus früheren
  Titeln, „Eis 3,50“-Erkennung, Kategorie anlegen, geplant, wiederholen, Notiz
- Daueraufträge (automatisch oder mit Bestätigung), Überspringen, einzelnen
  Termin ändern
- Statistik: Zeiträume, Kategorien-Ring, Verlauf, Gespart pro Monat, Woher,
  größte Ausgaben, Kategorie-Details
- Sparen: Monatsersparnis mit Vergleich, Ziele mit Fortschritt, Zurücklegen mit
  optionaler Umbuchung, Ziel abschließen (optional mit Ausgabe)
- Schulden in beide Richtungen mit Teilzahlungen
- Einstellungen: Profil, Konten (korrigieren, archivieren), Kategorien
  (sortieren, archivieren), Budgets, Daueraufträge, Export/Import (JSON),
  Zurücksetzen
- Android-Homescreen-Widget (anheften aus der App, „+ Ausgabe“ öffnet die
  Schnelleingabe), App-Shortcuts
- 37 Tests (Finanzlogik, Termine, Budgets, Parser, Datenbank, Backup)

**Nicht geprüft:** iOS-Build und iOS-Widget (kein Mac), echtes Android-Gerät,
Import einer Sicherung über den Dateiauswahldialog, sehr große Datenmengen.

## Als Nächstes (Vorschläge)

1. **iOS einrichten** nach [IOS_WIDGET.md](IOS_WIDGET.md), sobald ein Mac verfügbar ist.
2. **Eine Woche echt benutzen** und Finas Texte sowie die Prognose an der
   eigenen Realität prüfen.
3. **Erinnerungen** (lokale Benachrichtigungen): fällige Zahlungen, Budget fast
   aufgebraucht, abends „schon alles eingetragen?“
4. **App-Sperre** mit Fingerabdruck/Face ID – es sind Finanzdaten.
5. **Suche** über alle Buchungen und Filter nach Konto.
6. **CSV-Export** für Tabellenkalkulation (zusätzlich zum JSON-Backup).
7. Schrift für Beträge überdenken (siehe offene Frage zu Fraunces).
8. Widget-Varianten: kleines 2×1-„Plus“-Widget, responsive Layouts ab Android 12.
