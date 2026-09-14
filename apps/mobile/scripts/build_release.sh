#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [ ! -f android/key.properties ]; then
  echo "android/key.properties introuvable."
  echo "Lance d'abord apps/mobile/scripts/generate_keystore.sh, puis branche"
  echo "la signature dans android/app/build.gradle (voir README.md)."
  exit 1
fi

flutter pub get

echo "=== Patchs connus (packages tiers) ==="
bash scripts/patch_known_issues.sh

# Charge API_BASE_URL / WS_URL depuis .env.build s'il existe, pour ne
# jamais avoir a modifier lib/services/api_client.dart a la main.
DART_DEFINES=()
if [ -f ".env.build" ]; then
  echo "=== Config API chargee depuis .env.build ==="
  set -a
  # shellcheck disable=SC1091
  source .env.build
  set +a
  [ -n "$API_BASE_URL" ] && DART_DEFINES+=(--dart-define=API_BASE_URL="$API_BASE_URL")
  [ -n "$WS_URL" ] && DART_DEFINES+=(--dart-define=WS_URL="$WS_URL")
else
  echo "=== Pas de .env.build trouve : copie .env.build.example -> .env.build et remplis-le si besoin. ==="
fi

echo "=== Build .aab (Play Store) ==="
flutter build appbundle --release "${DART_DEFINES[@]}"

echo "=== Build .apk (installation directe / VPS) ==="
flutter build apk --release "${DART_DEFINES[@]}"

mkdir -p dist
cp build/app/outputs/bundle/release/app-release.aab dist/syrix-chat.aab
cp build/app/outputs/flutter-apk/app-release.apk dist/syrix-chat.apk

echo ""
echo "Fichiers prets dans apps/mobile/dist/ :"
echo "  - syrix-chat.aab  (a envoyer sur le Play Store)"
echo "  - syrix-chat.apk  (installation directe, ou a heberger sur le VPS)"
