# Zoëzas

Deine persönliche Finanz-Begleiterin – eine Lifestyle-App, in der zufällig sehr
gute Finanzfunktionen stecken. Flutter, primär für iOS gedacht, entwickelt und
getestet auf Android.

- **Verfügbares Guthaben** als Mittelpunkt, getrennt von Planung und Prognose
- **Schnelleingabe** über das große Plus, das Homescreen-Widget oder App-Shortcuts
- **Daueraufträge, Budgets, Sparziele, Schulden** – ohne Doppelzählungen
- **Fina**, eine kleine Figur mit Persönlichkeit (frech, lieb oder sachlich)
- **Alles lokal:** kein Konto, keine Cloud; Export/Import als lesbare JSON-Datei

## Starten

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Voraussetzung: Flutter 3.35 (Dart 3.9). iOS-Widget einrichten:
[docs/IOS_WIDGET.md](docs/IOS_WIDGET.md).

## Dokumentation

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) – Aufbau, Datenmodell, die Finanzregeln
- [docs/DECISIONS.md](docs/DECISIONS.md) – technische Entscheidungen mit Begründung
- [docs/ROADMAP.md](docs/ROADMAP.md) – Stand und nächste Schritte
- [CLAUDE.md](CLAUDE.md) – Arbeitsnotizen für die Entwicklung mit Claude Code

## Lizenzen

Schriften: Work Sans, Eczar, Merriweather – SIL Open Font License
([assets/fonts/OFL.txt](assets/fonts/OFL.txt)).
