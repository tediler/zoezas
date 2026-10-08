# Zoëzas – Arbeitsnotizen für Claude

Persönliche Finanz- und Budget-App (Flutter, primär iOS, entwickelt und getestet
unter Windows/Android). Lifestyle statt Banking: rosé Pastell, große Serifen-
Beträge, Begleiterin „Fina“. Auftraggeber und Nutzer: Tobias. Kommunikation
**auf Deutsch**, Fachbegriffe englisch. Er will Begründungen statt nur
Ergebnisse und Widerspruch, wenn etwas nicht sinnvoll ist.

**Zuerst lesen:** dieses Dokument → [docs/ROADMAP.md](docs/ROADMAP.md) →
bei Bedarf [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) (inkl. der zehn
Finanzregeln) und [docs/DECISIONS.md](docs/DECISIONS.md).

Projektübergreifender Kontext-Speicher (Obsidian): `C:\Users\hilse\Documents\Claude-Kontext`,
Projekt-Hub `Projekte/Zoëzas/Zoëzas.md`. Dort **kein Git** ausführen.

## Befehle

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # nach Änderungen an Tabellen (drift)
flutter analyze                                            # muss „No issues found!“ liefern
flutter test                                               # Logik + Datenbank (SQLite im Speicher)
dart format lib test                                       # Zeilenbreite 120 (analysis_options.yaml)
flutter build apk --debug
python tool/make_icons.py                                  # App-Icons neu erzeugen
```

Emulator – **AVD `Medium_Phone_API_35_3`** (Koch-App nutzt `_4`):

```bash
source tool/emulator.sh
start_emulator && wait_boot   # hängt er „offline“: Prozess beenden, mit -no-snapshot-load neu starten
deploy                        # bauen, installieren, starten (Debug-Kaltstart braucht ~8 s)
shot home                     # Screenshot nach build/screens/home.png
tap 450 1810                  # Plus-Button; Koordinaten im 900x2000-Raster
deeplink expense              # wie ein Tipp auf „+ Ausgabe“ im Widget
wipe                          # App-Daten löschen → Onboarding
```

Stolperstein beim Testen: `KEYCODE_BACK` bei geschlossener Tastatur verlässt den
Screen. Tastatur lieber über den ✓-Knopf der Tastatur (783,1823) schließen; Taps
während offener Tastatur treffen sonst leicht Tasten.

## Umgebung & Versionen

- Flutter 3.35.2 / Dart 3.9 global (`C:\dev\flutter`), bewusst **nicht** aktualisieren.
  Paketversionen in `pubspec.yaml` sind festgelegt (D-001).
- Android: minSdk 24, applicationId `de.hilsenbeck.zoezas`.
- iOS: Bundle `de.hilsenbeck.zoezas`, App Group `group.de.hilsenbeck.zoezas`,
  URL-Schema `zoezas`. Widget-Target muss in Xcode angelegt werden (docs/IOS_WIDGET.md).
- Zeilenenden LF (`.gitattributes`). Python unter Windows: `open(p, 'w', newline='\n')`.
- **Noch kein Git-Repository** – Commits nur nach Rückfrage.

## Konventionen

- UI-Texte deutsch, Code-Bezeichner englisch, Kommentare deutsch.
- Geld immer **Cent (int)**; Beträge in Buchungen positiv, Richtung über `BookingType`.
- Finanzlogik gehört in `lib/domain/` (rein, getestet), nicht in Widgets.
- Schreiben nur über Repositories (`lib/data/repositories.dart`), Lesen über Provider.
- UI-Dateien importieren drift nur als `import 'package:drift/drift.dart' show Value;`.
- Farben/Typo nur über `ZColors`/`ZText`; Karten über `ZCard`, Beträge über `MoneyText`.
- Sheets mit `showZSheet` bzw. `useRootNavigator: true` (über der Navigationsleiste).
- Enum-Namen stehen in der Datenbank und im Export – **nie umbenennen**.
- Neue reine Logik bekommt Tests in `test/domain/`, Datenbankverhalten in `test/data/`.

## Rezepte

**Neue Spalte/Tabelle:** `lib/core/db/tables.dart` → `schemaVersion` in `database.dart`
erhöhen → Migration in `MigrationStrategy.onUpgrade` → `build_runner` → Export/Import in
`lib/data/backup.dart` ergänzen (sonst fehlt die Tabelle in Sicherungen!).

**Neue Fina-Situation:** in `Fina.comment` an passender Priorität einfügen, je Tonfall
2–3 Formulierungen; ggf. Feld in `FinaContext` + `finaContextProvider`.

**Neue mitgelieferte Kategorie:** `lib/core/db/seed.dart` (nur Neuinstallationen) und
Beschreibungen in `Fina._descriptions` unter demselben `key`.

**Widget-Daten erweitern:** `PlatformIntegration.updateHomeWidget` (Dart) +
`ZoezasWidgetProvider.kt` + `ios/ZoezasWidget/ZoezasWidget.swift`.

## Bekannte Grenzen

- `Ledger` rechnet im Speicher über alle Buchungen (bewusst, D-003).
- Eczar hat eine große Unterlänge – Abstände unter großen Beträgen sind darauf abgestimmt.
- Nur Euro, nur Deutsch, nur helles Design.
