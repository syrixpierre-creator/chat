#!/usr/bin/env bash
# Applique des correctifs connus sur des packages tiers dans le cache pub,
# necessaires car ces packages n'ont pas encore ete mis a jour en amont.
# A lancer apres chaque "flutter pub get" (build_release.sh le fait
# automatiquement).
set -e

echo "Application des patchs connus post flutter pub get..."

# gallery_saver_plus fige compileSdkVersion a 31 dans son propre
# build.gradle. C'est incompatible avec les androidx modernes tires par
# livekit_client / flutter_webrtc / mobile_scanner (qui exigent compileSdk
# 34+), ce qui fait echouer "checkReleaseAarMetadata" a la compilation.
GSP_DIR=$(find "$HOME/.pub-cache/hosted/pub.dev" -maxdepth 1 -name "gallery_saver_plus-*" 2>/dev/null | sort -V | tail -1)
if [ -n "$GSP_DIR" ] && [ -f "$GSP_DIR/android/build.gradle" ]; then
  sed -i 's/compileSdkVersion [0-9]*/compileSdkVersion 36/' "$GSP_DIR/android/build.gradle"
  echo "  - gallery_saver_plus patche ($GSP_DIR)"
else
  echo "  - gallery_saver_plus introuvable dans le cache (deja a jour ou pas encore telecharge)."
fi

echo "Patchs termines."
