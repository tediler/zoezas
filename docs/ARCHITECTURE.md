# Architektur

## Überblick

```
lib/
  main.dart                 Start: Datenbank öffnen, Onboarding-Status lesen, App starten
  app/                      App, Router (go_router), Shell mit Navigationsleiste + Plus
  core/
    db/                     drift: tables.dart, database.dart (+ .g.dart), seed.dart
    format/                 Money (Cent ⇄ Text), YearMonth & Dates
    theme/                  ZColors, ZText (Typografie), Theme
    widgets/                ZCard, MoneyText, Pills, Fortschritt, Sheets, Diagramme, FinaAvatar
  domain/                   reine Logik ohne Flutter/Datenbank-Zugriff (testbar)
    ledger.dart             Kontostände, Monatsbilanz, Planung, Prognose, Ziele, Schulden
    recurrence.dart         Termine von Daueraufträgen
    budgets.dart            gültige Budgets je Monat, Auslastung
    fina.dart               Finas Stimme: Begrüßung, Kommentare, Tipps, Beschreibungen
    quick_entry.dart        „Eis 3,50“ → Titel + Betrag
    streak.dart, enums.dart
  data/
    repositories.dart       alle Schreibzugriffe (je Bereich ein Repository)
    providers.dart          Riverpod: Streams aus drift → Ledger und abgeleitete Werte
    backup.dart             Export/Import als JSON, Zurücksetzen
  features/                 Oberfläche je Bereich
    home/ bookings/ months/ stats/ savings/ settings/ onboarding/
  platform/
    platform_integration.dart  Homescreen-Widget, App-Shortcuts, Deep Links, Web-Start
    web_support*.dart          Browser-Hilfen (bedingter Import)
android/app/src/main/       ZoezasWidgetProvider.kt, res/layout/zoezas_widget.xml, …
ios/ZoezasWidget/           WidgetKit-Erweiterung (Swift) – zurückgestellt, iPhone nutzt die PWA
web/                        index.html, manifest.json, Icons, sqlite3.wasm, drift_worker.js
.github/workflows/web.yml   baut und veröffentlicht die PWA auf GitHub Pages
test/                       domain/ (reine Logik), data/ (gegen SQLite im Speicher)
tool/                       emulator.sh, make_icons.py, build_web.sh, web/drift_worker.dart
```

**Datenfluss:** drift liefert jede Tabelle als Stream → `StreamProvider` →
`ledgerProvider` baut daraus bei jeder Änderung einen neuen `Ledger` → Screens
lesen abgeleitete Werte (`ref.watch`) und schreiben über Repositories
(`ref.read(...Repo).methode()`). Es gibt keinen zweiten, gecachten Zustand, der
auseinanderlaufen könnte.

## Datenmodell

| Tabelle | Zweck |
| --- | --- |
| `accounts` | Konten mit Typ, **Startsaldo + Startdatum**, „zählt zum Verfügbaren“ |
| `categories` | Ausgaben-/Einnahmen-Kategorien; mitgelieferte tragen `builtInKey` |
| `bookings` | Buchungen: Typ (Ausgabe/Einnahme/Umbuchung), **Status** (gebucht/geplant/übersprungen), optional Verweis auf Dauerauftrag + Termin |
| `recurring_rules` | Daueraufträge: Rhythmus, Startdatum, optional fester Monatstag (31 = Monatsende), Enddatum, automatisch buchen ja/nein |
| `budgets` | Budget je Kategorie (null = gesamt), gültig ab Monat (`validFrom` JJJJMM) |
| `savings_goals`, `goal_contributions` | Sparziele und Einzahlungen/Entnahmen (= Reservierungen), optional mit Umbuchung |
| `debts`, `debt_payments` | Schulden in beide Richtungen und Zahlungen, optional mit Buchung |
| `settings`, `activity_days` | Profil (Name, Tonfall, Schwerpunkt), Einstellungen, Tage für die 🔥-Serie |

Geld ist immer `int` in Cent, Beträge in Buchungen sind positiv; die Richtung
ergibt sich aus dem Typ. Datumswerte werden als lokaler ISO-Text gespeichert
(`build.yaml`), damit ein Kalendertag beim Zeitzonenwechsel derselbe bleibt.

## Die Finanzregeln (in `Ledger`)

Diese Regeln verhindern, dass etwas doppelt oder falsch gezählt wird. Sie sind
in `test/domain/ledger_test.dart` und `test/data/repositories_test.dart` belegt.

1. **Kontostand** = Startsaldo + Wirkung aller *gebuchten* Buchungen ab dem
   Startdatum des Kontos. Geplantes und Übersprungenes zählt nie.
2. **Buchungen vor dem Startdatum** sind im Startsaldo schon enthalten: Sie zählen
   für Monatsbilanz und Statistik, verändern den Kontostand aber nicht. (Beispiel:
   App am 7. eingerichtet, Gehalt kam am 1. → zählt als Oktober-Einnahme, der
   eingegebene Kontostand bleibt richtig.)
3. **Umbuchungen** verändern zwei Konten gegenläufig, sind aber weder Einnahme
   noch Ausgabe.
4. **Verfügbares Guthaben** = Summe der Konten mit „zählt zum Verfügbaren“ minus
   Geld, das *auf diesen Konten* für aktive Sparziele reserviert ist.
5. **Monatsbilanz** („gespart“/„übrig“) = gebuchte Einnahmen − gebuchte Ausgaben
   des Monats. Jeder Monat steht für sich; das Geld selbst bleibt auf den Konten.
6. **Daueraufträge** erzeugen Termine rechnerisch. Ein Termin gilt als erledigt,
   sobald es eine Buchung mit (Regel, Termin) gibt – egal ob gebucht, geplant
   (= einzeln geändert) oder übersprungen. Die Kombination ist in der Datenbank
   eindeutig; der automatische Abgleich (`autoBook`, `InsertMode.insertOrIgnore`)
   kann daher beliebig oft laufen.
7. **Prognose** bis Monatsende = verfügbares Guthaben + Wirkung aller offenen
   Posten (geplante Buchungen und noch nicht erledigte Termine) auf verfügbare
   Konten – überfällige, unbestätigte Posten eingeschlossen, weil sie noch nicht
   abgegangen sind.
8. **Sparziele** reservieren nur. Erst eine optionale Umbuchung verschiebt Geld.
   Abgeschlossene Ziele reservieren nichts mehr.
9. **Schulden** sind Notizen. Erst eine Zahlung mit „Als Buchung erfassen“
   erzeugt eine Ausgabe (ich schulde) bzw. Einnahme (mir wird geschuldet).
10. **Budgets** gelten ab ihrem Monat, bis ein neuerer Eintrag kommt – vergangene
    Monate behalten ihr damaliges Budget. Verbraucht zählt nur Gebuchtes,
    Geplantes wird heller im Balken gezeigt.

## Automatischer Abgleich

`ZoezasApp` hört auf `ledgerProvider`: Sobald fällige Termine automatisch zu
buchender Daueraufträge existieren (`ledger.autoBookDue`), trägt
`BookingsRepository.autoBook` sie ein. Der Abgleich läuft beim Start, bei jeder
Datenänderung und beim Datumswechsel (minütliche Uhr in `clockProvider`,
Aktualisierung beim Zurückkehren in die App).

## Fina

`domain/fina.dart` wählt zuerst die **Situation** (keine Daten, im Minus,
Prognose negativ, Budget überschritten, Nacht, Ziel fast erreicht, Serie,
Monatsanfang, Tempo, Monatsende, Wochenende, Standard) und dann die
**Formulierung** passend zum Tonfall aus dem Onboarding. Varianten werden pro Tag
stabil gewählt (Seed = Datum), damit der Text nicht bei jedem Neuaufbau springt.
Keine externe KI, keine Netzwerkzugriffe.

## Web-App (PWA)

Dieselbe Codebasis läuft im Browser ([WEB.md](WEB.md)). Unterschiede:

- `AppDatabase._openConnection` gibt drift `DriftWebOptions` mit: SQLite als
  WebAssembly (`web/sqlite3.wasm`) in einem Web Worker (`web/drift_worker.js`),
  Speicher in IndexedDB/OPFS. Alles andere – Tabellen, Repositories, `Ledger` –
  ist identisch.
- `lib/platform/web_support.dart` exportiert per bedingtem Import entweder den
  Stub (Android/iOS) oder `web_support_web.dart` (Installationsstatus, iPhone
  erkennen, dauerhaften Speicher anfordern).
- `PlatformIntegration.init` behandelt im Browser `?add=expense|income` aus den
  Manifest-Shortcuts und fordert dauerhaften Speicher an; Widget und Quick
  Actions sind dort aus.
- `web/index.html` und `web/manifest.json` tragen Farben, Icons, iOS-Angaben und
  einen Ladebildschirm.

## Homescreen-Widget

- **Android:** `ZoezasWidgetProvider` (Kotlin, `RemoteViews`) liest die von
  Flutter geschriebenen Werte und setzt `PendingIntent`s mit
  `zoezas://add?type=expense|income`. Über *Einstellungen → Widget hinzufügen*
  kann die App das Widget direkt anheften (`requestPinWidget`).
- **iOS:** WidgetKit in `ios/ZoezasWidget/`, Einrichtung in [IOS_WIDGET.md](IOS_WIDGET.md).
- **Flutter-Seite:** `PlatformIntegration` schreibt die Werte nur bei Änderung
  und übersetzt Links/Shortcuts in eine `QuickAddRequest`, auf die die Shell mit
  der Schnelleingabe reagiert.

## Bekannte Grenzen

- Der `Ledger` rechnet über alle Buchungen im Speicher. Für ein persönliches
  Haushaltsbuch (einige zehntausend Buchungen) ist das unkritisch; bei Bedarf
  lassen sich Monatswerte später per SQL aggregieren.
- Nur Euro, nur Deutsch, nur helles Design.
- Im Browser lädt Flutter Emoji-Schriften von `fonts.gstatic.com` nach (siehe WEB.md).
