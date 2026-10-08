# Web-App (PWA): kostenlos hosten und aufs iPhone bringen

Auf dem iPhone läuft Zoëzas als **Progressive Web App**: eine Webseite, die man
auf den Home-Bildschirm legt und die sich dann wie eine App verhält – ohne App
Store, ohne Apple-Entwicklerkonto, ohne Kosten. Auf Android bleibt die native
App (mit Homescreen-Widget) der Weg; die Web-App funktioniert dort aber auch.

## Was anders ist als in der Android-App

| | Android-App | Web-App (iPhone) |
| --- | --- | --- |
| Alle Finanzfunktionen | ✓ | ✓ |
| Offline nutzbar | ✓ | ✓ (nach dem ersten Öffnen) |
| Homescreen-Widget | ✓ | – (geht im Web nicht) |
| Shortcuts am App-Symbol | ✓ | nur Android-Chrome, nicht iOS |
| Daten liegen | in der App | im Speicher der Home-Bildschirm-App |

**Die Daten sind getrennt.** Android-App und Web-App haben jeweils ihren eigenen
Speicher. Umziehen geht über *Einstellungen → Deine Daten → Exportieren* und auf
der anderen Seite *Importieren*.

## Kostenlos hosten

Gehostet werden nur die App-Dateien (HTML, JavaScript, Schriften). Deine
Finanzdaten verlassen das Handy nie – der Server sieht sie nicht.

### Weg A: GitHub Pages (empfohlen, aktualisiert sich selbst)

Kostet nichts, braucht ein kostenloses GitHub-Konto. Das Repository muss
**öffentlich** sein (bei kostenlosen Konten); sichtbar ist dann der Quellcode,
nicht deine Daten. Im Code stehen keine Passwörter oder persönlichen Angaben.

1. Auf <https://github.com> ein Konto anlegen.
2. Ein neues, leeres Repository anlegen, z. B. `zoezas` (öffentlich, ohne README).
3. Im Projektordner:
   ```bash
   git remote add origin https://github.com/<dein-name>/zoezas.git
   git push -u origin main
   ```
4. Auf GitHub im Repository: *Settings → Pages → Build and deployment → Source:
   „GitHub Actions“*.
5. Unter *Actions* läuft „Web-App veröffentlichen“ (Tests, Build, Upload; ca. 5
   Minuten). Danach ist die App erreichbar unter
   `https://<dein-name>.github.io/zoezas/`.

Jeder weitere `git push` auf `main` baut und veröffentlicht automatisch neu
(`.github/workflows/web.yml`). Schlagen die Tests fehl, wird nichts veröffentlicht.

### Weg B: Netlify Drop (Repository bleibt privat)

Ohne Git-Remote, per Drag & Drop. Kostenlos, ein Netlify-Konto braucht man, damit
die Seite dauerhaft bleibt.

1. `bash tool/build_web.sh` – erzeugt `build/web`.
2. <https://app.netlify.com/drop> öffnen und den Ordner `build/web` hineinziehen.
3. Netlify zeigt eine Adresse wie `https://irgendwas.netlify.app` (umbenennbar).

Für Updates: neu bauen und den Ordner in der Netlify-Übersicht der Seite unter
*Deploys* erneut hineinziehen. Cloudflare Pages funktioniert genauso
(*Workers & Pages → Create → Pages → Upload assets*).

## Aufs iPhone

1. Die Adresse in **Safari** öffnen (nicht Chrome – nur Safari kann auf den
   Home-Bildschirm installieren).
2. Unten auf **Teilen** (Quadrat mit Pfeil) → **Zum Home-Bildschirm** → *Hinzufügen*.
3. Zoëzas **vom Home-Bildschirm** starten und erst dort das Kennenlernen machen.

Wichtig: Safari-Tab und Home-Bildschirm-App haben **getrennte Speicher**. Was im
Tab eingetragen wurde, ist in der installierten App nicht da – die App weist im
Safari-Tab selbst darauf hin.

## Daten sicher halten

- Die App bittet den Browser um dauerhaften Speicher. Für installierte Apps gilt
  Safaris 7-Tage-Löschregel nicht; trotzdem gilt: **Wird das Symbol vom
  Home-Bildschirm gelöscht, sind die Daten darin weg.**
- Fina erinnert in der Web-App nach 14 Tagen ohne Sicherung an einen Export
  (auf dem iPhone: *Teilen → In Dateien sichern*, z. B. in iCloud Drive).

## Updates

Die App speichert sich für den Offline-Betrieb im Browser. Nach einem neuen
Deployment holt sie sich die neue Version beim nächsten Öffnen im Hintergrund;
spätestens beim übernächsten Start ist sie aktiv.

## Technik in Kürze

- Flutter Web (CanvasKit), gebaut mit `--no-web-resources-cdn`: Die Grafik-Engine
  kommt vom eigenen Server, nicht von Googles CDN.
- Datenbank: dieselbe drift/SQLite-Datenbank wie auf Android, im Browser als
  WebAssembly (`web/sqlite3.wasm`) in einem Web Worker (`web/drift_worker.js`,
  Quelle `tool/web/drift_worker.dart`), gespeichert in IndexedDB.
- Bekannte Einschränkung: Emojis und einzelne Sonderzeichen lädt Flutter beim
  ersten Gebrauch als Schrift von `fonts.gstatic.com` nach (keine Nutzerdaten,
  aber eine Verbindung zu Google; danach aus dem Cache). Bis sie da sind, stehen
  kurz Platzhalter □ da. Abhilfe wäre, die Emoji-Schrift mitzuliefern.
- Lokal testen: `bash tool/build_web.sh` und
  `python -m http.server 8099 --directory build/web`, dann <http://localhost:8099>.
