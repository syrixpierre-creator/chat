#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

MANIFEST="android/app/src/main/AndroidManifest.xml"

if [ ! -f "$MANIFEST" ]; then
  echo "$MANIFEST introuvable."
  echo "Lance d'abord: flutter create ."
  exit 1
fi

python3 << PYEOF
path = "$MANIFEST"
with open(path, "r") as f:
    content = f.read()

changed = False

permissions = [
    "android.permission.INTERNET",
    "android.permission.CAMERA",
    "android.permission.RECORD_AUDIO",
    "android.permission.MODIFY_AUDIO_SETTINGS",
    "android.permission.BLUETOOTH",
    "android.permission.BLUETOOTH_CONNECT",
]

manifest_open = '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
if manifest_open in content:
    missing = [p for p in permissions if p not in content]
    if missing:
        lines = "\\n".join(f'    <uses-permission android:name="{p}" />' for p in missing)
        content = content.replace(manifest_open, manifest_open + "\\n" + lines, 1)
        changed = True

if "android:usesCleartextTraffic" not in content:
    content = content.replace(
        "<application",
        '<application\\n        android:usesCleartextTraffic="true"',
        1
    )
    changed = True

if changed:
    with open(path, "w") as f:
        f.write(content)
    print("AndroidManifest.xml mis a jour (permissions + cleartext traffic).")
else:
    print("AndroidManifest.xml deja a jour, rien a faire.")
PYEOF

echo ""
echo "IMPORTANT: android:usesCleartextTraffic=\"true\" autorise le HTTP non"
echo "chiffre (necessaire tant que ton API tourne en http://). Une fois"
echo "deploy.sh lance avec un vrai domaine HTTPS, tu peux retirer cette ligne"
echo "de $MANIFEST et recompiler pour plus de securite."
echo ""
echo "Etape suivante: verifie/edite lib/services/api_client.dart"
echo "(baseUrl et wsUrl doivent pointer vers l'IP ou le domaine de ton VPS,"
echo "pas vers localhost, sinon l'app ne pourra jamais se connecter depuis"
echo "un vrai telephone)."
