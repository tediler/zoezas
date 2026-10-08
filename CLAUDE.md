# Zoëzas – Arbeitsnotizen für Claude

Persönliche Finanz- und Budget-App (Flutter): native App für Android, Web-App
(PWA) fürs iPhone (D-015 – keine native iOS-App, kein Apple-Konto). Lifestyle statt Banking: rosé Pastell, große Serifen-
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
dart format $(find lib test -name '*.dart' ! -name '*.g.dart')   # Breite 120, generierte Dateien nicht anfassen
flutter build apk --debug
python tool/make_icons.py                                  # App-, Web- und Favicon-Icons neu erzeugen
bash tool/build_web.sh [/basis-pfad/]                      # Web-App nach build/web (PWA)
```

Web-App lokal ansehen: Launch-Konfiguration `zoezas-web` in `.claude/launch.json`
(Python-Server auf Port 8099 für `build/web`) per `preview_start`, Ansicht „mobile“.
Nach drift-Updates `web/drift_worker.js` neu kompilieren (siehe `tool/web/drift_worker.dart`)
und prüfen, ob `web/sqlite3.wasm` noch passt (D-016).

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
- iPhone: Web-App (docs/WEB.md), gehostet über GitHub Pages (`.github/workflows/web.yml`).
  Der native iOS-Teil (`ios/`, `docs/IOS_WIDGET.md`) ist zurückgestellt.
- Zeilenenden LF (`.gitattributes`). Python unter Windows: `open(p, 'w', newline='\n')`.
- Git-Repository auf `main` (seit 08.10.2026), noch ohne Remote. Committen nur nach Rückfrage.

## Konventionen

- UI-Texte deutsch, Code-Bezeichner englisch, Kommentare deutsch.
- Geld immer **Cent (int)**; Beträge in Buchungen positiv, Richtung über `BookingType`.
- Finanzlogik gehört in `lib/domain/` (rein, getestet), nicht in Widgets.
- Schreiben nur über Repositories (`lib/data/repositories.dart`), Lesen über Provider.
- UI-Dateien importieren drift nur als `import 'package:drift/drift.dart' show Value;`.
- Farben/Typo nur über `ZColors`/`ZText`; Karten über `ZCard`, Beträge über `MoneyText`.
- Sheets mit `showZSheet` bzw. `useRootNavigator: true` (über der Navigationsleiste).
- **Alles muss auch im Browser laufen:** kein `dart:io` (`Platform`, `File`) in App-Code –
  `kIsWeb`/`defaultTargetPlatform` nutzen, Browser-APIs nur über `lib/platform/web_support.dart`.
  Nach größeren Änderungen auch `flutter build web` prüfen.
- `package:flutter/foundation.dart` nur mit `show …` importieren (sonst Namenskonflikt mit `Category`).
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
- Web: Emojis kommen beim ersten Gebrauch als Schrift von `fonts.gstatic.com` (offene Frage, ob mitliefern).
