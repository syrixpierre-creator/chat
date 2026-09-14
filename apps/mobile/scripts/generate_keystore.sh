#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [ ! -d android ]; then
  echo "Le dossier android/ n'existe pas encore."
  echo "Lance d'abord: flutter create ."
  exit 1
fi

: "${SYRIX_KEY_ALIAS:?Definis SYRIX_KEY_ALIAS (ex: syrix-upload)}"
: "${SYRIX_KEYSTORE_PASSWORD:?Definis SYRIX_KEYSTORE_PASSWORD}"
: "${SYRIX_KEY_PASSWORD:?Definis SYRIX_KEY_PASSWORD}"

KEYSTORE_PATH="android/app/syrix-upload-keystore.jks"

if [ -f "$KEYSTORE_PATH" ]; then
  echo "Un keystore existe deja a ${KEYSTORE_PATH}. Rien a faire."
  echo "Supprime-le manuellement si tu veux en regenerer un (attention: perdre"
  echo "ce fichier empeche de publier des mises a jour sur un .apk/.aab deja"
  echo "publie sur le Play Store)."
  exit 0
fi

keytool -genkeypair -v \
  -keystore "$KEYSTORE_PATH" \
  -alias "$SYRIX_KEY_ALIAS" \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass "$SYRIX_KEYSTORE_PASSWORD" \
  -keypass "$SYRIX_KEY_PASSWORD" \
  -dname "CN=SYRIX CHAT, OU=Syrix Vision, O=Syrix Vision, L=, S=, C=US"

cat > android/key.properties << EOF
storePassword=${SYRIX_KEYSTORE_PASSWORD}
keyPassword=${SYRIX_KEY_PASSWORD}
keyAlias=${SYRIX_KEY_ALIAS}
storeFile=syrix-upload-keystore.jks
EOF

echo "Keystore cree: ${KEYSTORE_PATH}"
echo "android/key.properties genere."
echo ""
echo "IMPORTANT: sauvegarde ${KEYSTORE_PATH} et les mots de passe utilises"
echo "en lieu sur, hors du depot Git (ajoute-les a .gitignore). Si tu perds"
echo "ce keystore, tu ne pourras plus publier de mise a jour pour une app"
echo "deja presente sur le Play Store sous le meme package name."
echo ""
echo "Etape suivante: branche la signature dans android/app/build.gradle"
echo "(voir README.md, section 'Build .apk/.aab signes'), puis lance"
echo "apps/mobile/scripts/build_release.sh"
