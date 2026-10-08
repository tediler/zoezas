#!/usr/bin/env bash
# Baut die Web-App (PWA) nach build/web.
#
#   bash tool/build_web.sh            # für eine eigene Domain oder Netlify/Cloudflare (Pfad „/“)
#   bash tool/build_web.sh /zoezas/   # für einen Unterpfad, z. B. GitHub Pages ohne Actions
#
# Den Ordner build/web kann man danach z. B. auf https://app.netlify.com/drop ziehen.
# Lokal ansehen: python -m http.server 8099 --directory build/web
set -euo pipefail
# Git Bash unter Windows würde „/zoezas/“ sonst in einen Windows-Pfad umwandeln.
export MSYS_NO_PATHCONV=1
cd "$(dirname "$0")/.."

base_href="${1:-/}"
flutter build web --release --no-web-resources-cdn --base-href "$base_href"
echo
echo "Fertig: build/web (Basis-Pfad $base_href)"
