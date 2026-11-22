#!/usr/bin/env bash
# Starts MySQL and the Miski API on this Mac so a phone on the same WiFi can use it.
#   ./scripts/dev.sh           start (creates the database the first time)
#   ./scripts/dev.sh --fresh   wipe the database and load the demo data again
set -euo pipefail
cd "$(dirname "$0")/../backend"

brew services start mysql >/dev/null
for _ in {1..20}; do mysqladmin -uroot ping >/dev/null 2>&1 && break; sleep 1; done
mysql -uroot -e "CREATE DATABASE IF NOT EXISTS miski CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

[ -f .env ] || { cp .env.example .env; php artisan key:generate; }
[ -d vendor ] || composer install
[ -L public/storage ] || php artisan storage:link

if [ "${1:-}" = "--fresh" ]; then
  php artisan migrate:fresh --seed --force
else
  php artisan migrate --force
  php artisan db:seed --force
fi

IP=$(ipconfig getifaddr en0 || ipconfig getifaddr en1 || echo 127.0.0.1)
echo
echo "API:   http://$IP:8000/api/v1"
echo "App:   flutter run --dart-define=MISKI_API_URL=http://$IP:8000/api/v1"
echo "APK:   ./scripts/build-apk.sh"
echo "Demo:  paul@miski.test / miski1234 (también carlosm, mariaq, luciar, diegot)"
echo
php artisan serve --host=0.0.0.0 --port=8000
