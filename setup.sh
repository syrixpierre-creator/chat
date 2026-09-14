#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

if [ ! -f apps/api/.env ]; then
  cp apps/api/.env.example apps/api/.env
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker introuvable. Installe Docker d'abord (curl -fsSL https://get.docker.com | sh)."
  exit 1
fi

echo "Demarrage PostgreSQL + MongoDB + Redis + LiveKit + Ollama..."
docker compose up -d postgres mongo redis livekit ollama

echo "Attente de PostgreSQL..."
until docker exec syrix-postgres pg_isready -U syrix -d syrix_chat >/dev/null 2>&1; do
  sleep 1
done

echo "Telechargement du modele IA local (peut prendre plusieurs minutes la premiere fois)..."
docker exec syrix-ollama ollama pull llama3.2:3b || echo "Ollama pas encore pret, relance 'docker exec syrix-ollama ollama pull llama3.2:3b' dans une minute."

cd apps/api
npm install

echo "Creation des tables PostgreSQL (Prisma)..."
npx prisma generate
npx prisma db push

cd "$ROOT_DIR"
echo "Bases de donnees pretes: PostgreSQL, MongoDB, Redis."

if ! command -v pm2 >/dev/null 2>&1; then
  echo "Installation de pm2 (garde l'API en vie meme si tu fermes ce terminal)..."
  npm install -g pm2
fi

echo "Demarrage de l'API avec pm2..."
cd apps/api
pm2 delete syrix-api >/dev/null 2>&1 || true
pm2 start npm --name syrix-api -- run dev
pm2 save
cd "$ROOT_DIR"

echo ""
echo "=================================================="
echo "L'API tourne en arriere-plan avec pm2 (survit a la fermeture du terminal)."
echo "Voir les logs en direct : pm2 logs syrix-api"
echo "Etat                    : pm2 status"
echo "Redemarrer              : pm2 restart syrix-api"
echo "Arreter                 : pm2 stop syrix-api"
echo "=================================================="
