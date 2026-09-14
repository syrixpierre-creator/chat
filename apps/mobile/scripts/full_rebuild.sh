#!/usr/bin/env bash
# Enchaine tout ce qu'il faut pour repartir de zero (nouveau clone, nouveau
# VPS, ou apres un "flutter clean"). Suppose que generate_keystore.sh a
# deja ete lance au moins une fois (android/key.properties doit exister).
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [ ! -d android ]; then
  echo "=== flutter create . (genere android/, ios/, etc.) ==="
  flutter create .
fi

if [ ! -f .env.build ] && [ -f .env.build.example ]; then
  echo "=== Cree .env.build depuis l'exemple - PENSE A LE REMPLIR avec ton IP/domaine ==="
  cp .env.build.example .env.build
fi

echo "=== Dependances ==="
flutter pub get

echo "=== Permissions / manifest ==="
bash scripts/post_create_setup.sh

if [ ! -f android/key.properties ]; then
  echo ""
  echo "android/key.properties introuvable : lance d'abord scripts/generate_keystore.sh"
  echo "(voir README.md, section signature) puis relance ce script."
  exit 1
fi

echo "=== Build ==="
bash scripts/build_release.sh

echo ""
echo "=== Termine. Fichiers dans dist/ : ==="
ls -la dist/
