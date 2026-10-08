# Hilfsfunktionen zum Testen auf dem Emulator (Git Bash).
#
#   source tool/emulator.sh
#   start_emulator          # startet den AVD im Hintergrund
#   wait_boot               # wartet, bis Android hochgefahren ist
#   deploy                  # Debug-APK bauen, installieren, starten
#   shot home               # Screenshot nach build/screens/home.png
#   tap 450 1860            # Koordinaten im 900x2000-Raster der Screenshots
#   text "Eis"; key KEYCODE_ENTER; logs
#
# Git Bash wandelt /sdcard-Pfade sonst in Windows-Pfade um:
export MSYS_NO_PATHCONV=1
SDK="${ANDROID_HOME:-/c/Users/hilse/AppData/Local/Android/Sdk}"
AVD="${ZOEZAS_AVD:-Medium_Phone_API_35_3}"
ADB="$SDK/platform-tools/adb -s ${ZOEZAS_DEVICE:-emulator-5554}"
PKG="de.hilsenbeck.zoezas"
SCREENS="build/screens"
mkdir -p "$SCREENS"

start_emulator() { "$SDK/emulator/emulator" -avd "$AVD" -no-boot-anim -netdelay none -netspeed full >/dev/null 2>&1 & }
wait_boot() { until [ "$($ADB shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do sleep 2; done; }
deploy() {
  flutter build apk --debug && \
  $ADB install -r build/app/outputs/flutter-apk/app-debug.apk && \
  $ADB shell am start -n $PKG/.MainActivity
}
restart() { $ADB shell am force-stop $PKG; $ADB shell am start -n $PKG/.MainActivity >/dev/null; }
# App-Daten löschen (zurück zum Onboarding).
wipe() { $ADB shell pm clear $PKG; }
# Screenshots werden in 900x2000 angezeigt; das Gerät hat 1080x2400 (Faktor 1,2).
tap() { $ADB shell input tap $(( $1 * 6 / 5 )) $(( $2 * 6 / 5 )); }
swipe() { $ADB shell input swipe $(( $1 * 6 / 5 )) $(( $2 * 6 / 5 )) $(( $3 * 6 / 5 )) $(( $4 * 6 / 5 )) ${5:-300}; }
text() { $ADB shell input text "$1"; }
key() { $ADB shell input keyevent "$1"; }
shot() { sleep ${2:-1.5}; $ADB exec-out screencap -p > "$SCREENS/$1.png"; echo "$SCREENS/$1.png"; }
logs() { $ADB logcat -d -t 400 | grep -E " (E|W) flutter|flutter :|Exception|FATAL" | tail -${1:-30}; }
# Deep Link wie aus dem Widget auslösen.
deeplink() { $ADB shell am start -a es.antonborri.home_widget.action.LAUNCH -d "zoezas://add?type=${1:-expense}" -n $PKG/.MainActivity; }
# Datenbank der App zum Untersuchen herunterladen (nur Debug-Build).
pull_db() { $ADB exec-out run-as $PKG cat app_flutter/zoezas.sqlite > "${1:-build/zoezas.sqlite}"; }
