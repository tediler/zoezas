# iOS: Homescreen-Widget und App-Shortcuts einrichten

Die Flutter-App läuft auf iOS ohne weitere Schritte. Für das **Homescreen-Widget**
braucht es einmalig Xcode auf einem Mac, weil iOS-Widgets eine eigene
WidgetKit-Erweiterung (eigenes Target) sind. Der Swift-Code liegt fertig in
[`ios/ZoezasWidget/`](../ios/ZoezasWidget/); das Target selbst lässt sich nicht
zuverlässig von Hand in `project.pbxproj` eintragen und wird deshalb in Xcode
angelegt.

## Voraussetzungen

- Mac mit Xcode 15 oder neuer, Apple-Developer-Team (kostenloses Konto reicht
  für das eigene Gerät)
- `flutter build ios --config-only` einmal ausgeführt (erzeugt Pods & Konfiguration)

## Schritte

1. `ios/Runner.xcworkspace` in Xcode öffnen.
2. **Target anlegen:** *File → New → Target… → Widget Extension*
   - Product Name: `ZoezasWidget`
   - „Include Live Activity“ und „Include Configuration App Intent“ **aus**
   - Bundle Identifier: `de.hilsenbeck.zoezas.ZoezasWidget`
   - Die Frage „Activate scheme?“ mit *Cancel* beantworten (Runner bleibt aktiv).
3. Xcode legt Beispieldateien an. Diese **löschen** und stattdessen die Dateien aus
   `ios/ZoezasWidget/` dem Target hinzufügen (`ZoezasWidget.swift`, `Info.plist`).
   Unter *Build Settings → Info.plist File* auf `ZoezasWidget/Info.plist` zeigen.
4. **App Group** für beide Targets (`Runner` und `ZoezasWidget`):
   *Signing & Capabilities → + Capability → App Groups →* `group.de.hilsenbeck.zoezas`
   (muss exakt `PlatformIntegration.appGroup` in Dart entsprechen).
5. **Deployment Target** des Widget-Targets auf iOS 16.0 setzen (Sperrbildschirm-
   Widgets brauchen 16, `containerBackground` wird ab 17 genutzt, darunter gibt es
   einen Fallback).
6. Unter *Build Phases* des Runner-Targets die Phase *Embed Foundation Extensions*
   **vor** *Thin Binary* bzw. *Run Script* schieben (sonst meldet Xcode einen
   „Cycle inside Runner“).
7. Bauen: `flutter build ios` oder direkt aus Xcode auf das Gerät.

## Wie es zusammenspielt

```
Flutter (lib/platform/platform_integration.dart)
  └─ HomeWidget.saveWidgetData('available', …)   → UserDefaults der App Group
  └─ HomeWidget.updateWidget(iOSName: 'ZoezasWidget') → WidgetCenter.reloadTimelines

WidgetKit (ios/ZoezasWidget/ZoezasWidget.swift)
  └─ liest UserDefaults(suiteName: "group.de.hilsenbeck.zoezas")
  └─ Tipp → zoezas://add?type=expense&homeWidget
            └─ home_widget erkennt den Parameter „homeWidget“ und liefert den
               Link an Flutter → Schnelleingabe öffnet sich
```

Das URL-Schema `zoezas` ist bereits in `ios/Runner/Info.plist` eingetragen.

Angeboten werden: klein (Betrag + „+ Ausgabe“), mittel (Betrag + „Ausgabe“ /
„Einnahme“), Sperrbildschirm rund (Plus) und rechteckig (Betrag).

## App-Shortcuts (Icon lange drücken)

Funktionieren ohne Xcode-Schritte über das Paket `quick_actions`. Für eigene
Symbole können später Bilder `ic_shortcut_expense` / `ic_shortcut_income` in
`Runner/Assets.xcassets` ergänzt werden; ohne sie zeigt iOS die Einträge ohne Icon.

## Noch nicht auf echter Hardware geprüft

Der Swift-Code ist nach WidgetKit-API geschrieben, aber mangels Mac nicht
kompiliert. Beim ersten Bauen in Xcode bitte auf Compilerfehler achten.
