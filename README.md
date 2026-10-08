# Zoëzas

Deine persönliche Finanz-Begleiterin – eine Lifestyle-App, in der zufällig sehr
gute Finanzfunktionen stecken. Flutter: native App für Android, Web-App (PWA)
fürs iPhone.

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

Voraussetzung: Flutter 3.35 (Dart 3.9). Web-App bauen, kostenlos hosten und aufs
iPhone bringen: [docs/WEB.md](docs/WEB.md).

## Dokumentation

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) – Aufbau, Datenmodell, die Finanzregeln
- [docs/DECISIONS.md](docs/DECISIONS.md) – technische Entscheidungen mit Begründung
- [docs/ROADMAP.md](docs/ROADMAP.md) – Stand und nächste Schritte
- [docs/WEB.md](docs/WEB.md) – Web-App: Hosting, iPhone, Datensicherheit
- [CLAUDE.md](CLAUDE.md) – Arbeitsnotizen für die Entwicklung mit Claude Code

## Lizenzen

Schriften: Work Sans, Eczar, Merriweather – SIL Open Font License
([assets/fonts/OFL.txt](assets/fonts/OFL.txt)).
