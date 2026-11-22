#!/usr/bin/env bash
# Builds the release APK pointing to the API on this Mac (or to the URL given).
#   ./scripts/build-apk.sh                               uses this Mac's WiFi IP
#   ./scripts/build-apk.sh https://api.miski.pe/api/v1   uses a server
set -euo pipefail
cd "$(dirname "$0")/.."
IP=$(ipconfig getifaddr en0 || ipconfig getifaddr en1 || echo 127.0.0.1)
URL="${1:-http://$IP:8000/api/v1}"
flutter build apk --release --dart-define=MISKI_API_URL="$URL"
cp build/app/outputs/flutter-apk/app-release.apk ~/Desktop/Miski.apk
echo "APK listo en ~/Desktop/Miski.apk (API: $URL)"
