#!/usr/bin/env bash
set -e

if [ "$(id -u)" -ne 0 ]; then
  echo "Ce script doit etre lance avec sudo/root."
  echo "Usage: sudo bash deploy.sh <domaine> <email-letsencrypt>"
  exit 1
fi

DOMAIN="$1"
EMAIL="$2"
API_PORT="${3:-4000}"

if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
  echo "Usage: sudo bash deploy.sh <domaine> <email-letsencrypt> [port-api]"
  echo "Exemple: sudo bash deploy.sh chat.example.com toi@example.com"
  echo "Exemple (port personnalise): sudo bash deploy.sh chat.example.com toi@example.com 3000"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

REAL_USER="${SUDO_USER:-$(whoami)}"
LETSENCRYPT_DIR="/etc/letsencrypt/live/${DOMAIN}"

echo "=== 1/9 Docker ==="
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
fi

echo "=== 2/9 Node.js 20 ==="
if ! command -v node >/dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
fi

echo "=== 3/9 Nginx + Certbot ==="
apt-get update -y
apt-get install -y nginx certbot python3-certbot-nginx

echo "=== 4/9 Cles de production LiveKit ==="
if [ ! -f apps/api/.env ]; then
  cp apps/api/.env.example apps/api/.env
fi

LIVEKIT_API_KEY=$(openssl rand -hex 8)
LIVEKIT_API_SECRET=$(openssl rand -hex 24)

sed \
  -e "s#__LIVEKIT_API_KEY__#${LIVEKIT_API_KEY}#g" \
  -e "s#__LIVEKIT_API_SECRET__#${LIVEKIT_API_SECRET}#g" \
  -e "s#__DOMAIN__#${DOMAIN}#g" \
  deploy/livekit-prod.yaml.template > deploy/livekit-prod.yaml

sed \
  -e "s#__LETSENCRYPT_DIR__#${LETSENCRYPT_DIR}#g" \
  deploy/docker-compose.prod.yml.template > docker-compose.prod.yml

echo "=== 5/9 Bases de donnees + IA (PostgreSQL, MongoDB, Redis, Ollama) ==="
docker compose -f docker-compose.prod.yml up -d postgres mongo redis ollama

echo "Attente de PostgreSQL..."
until docker exec syrix-postgres pg_isready -U syrix -d syrix_chat >/dev/null 2>&1; do
  sleep 1
done

echo "Telechargement du modele IA local (peut prendre plusieurs minutes)..."
docker exec syrix-ollama ollama pull llama3.2:3b || echo "Ollama pas encore pret, relance manuellement: docker exec syrix-ollama ollama pull llama3.2:3b"

echo "=== 6/9 Configuration production (.env) ==="
sed -i "s#^APP_DOMAIN=.*#APP_DOMAIN=https://${DOMAIN}#" apps/api/.env
sed -i "s#^PUBLIC_API_URL=.*#PUBLIC_API_URL=https://${DOMAIN}#" apps/api/.env
sed -i "s#^PORT=.*#PORT=${API_PORT}#" apps/api/.env
sed -i "s#^LIVEKIT_URL=.*#LIVEKIT_URL=wss://${DOMAIN}/livekit#" apps/api/.env
sed -i "s#^LIVEKIT_API_KEY=.*#LIVEKIT_API_KEY=${LIVEKIT_API_KEY}#" apps/api/.env
sed -i "s#^LIVEKIT_API_SECRET=.*#LIVEKIT_API_SECRET=${LIVEKIT_API_SECRET}#" apps/api/.env

echo "!!! Verifie aussi apps/api/.env : STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET,"
echo "    JWT_SECRET, GMAIL_USER / GMAIL_APP_PASSWORD doivent etre renseignes"
echo "    pour un fonctionnement complet en production."

echo "=== 7/9 Build de l'API ==="
cd apps/api
npm ci
npx prisma generate
npx prisma db push
npm run build
cd "$ROOT_DIR"

echo "=== 8/9 Service systemd ==="
sed \
  -e "s#__PROJECT_DIR__#${ROOT_DIR}#g" \
  -e "s#__SERVICE_USER__#${REAL_USER}#g" \
  deploy/syrix-api.service.template > /etc/systemd/system/syrix-api.service

systemctl daemon-reload
systemctl enable syrix-api
systemctl restart syrix-api

echo "=== 9/9 Nginx + HTTPS (Let's Encrypt), puis LiveKit (TURN/TLS) ==="
sed \
  -e "s#__DOMAIN__#${DOMAIN}#g" \
  -e "s#__API_PORT__#${API_PORT}#g" \
  deploy/nginx.conf.template > /etc/nginx/sites-available/syrix-chat
ln -sf /etc/nginx/sites-available/syrix-chat /etc/nginx/sites-enabled/syrix-chat
nginx -t
systemctl reload nginx

certbot --nginx -d "${DOMAIN}" -m "${EMAIL}" --agree-tos --redirect --non-interactive || \
  echo "Certbot a echoue — verifie que ${DOMAIN} pointe bien vers ce serveur (DNS A record) puis relance : certbot --nginx -d ${DOMAIN}"

if [ -f "${LETSENCRYPT_DIR}/fullchain.pem" ]; then
  docker compose -f docker-compose.prod.yml up -d livekit
  echo "LiveKit demarre avec TURN/TLS sur le port 3010 (certificat trouve)."
else
  echo "Certificat introuvable pour ${DOMAIN} — LiveKit n'a pas ete demarre."
  echo "Une fois le certificat obtenu (certbot --nginx -d ${DOMAIN}), relance:"
  echo "  docker compose -f docker-compose.prod.yml up -d livekit"
fi

echo ""
echo "=================================================="
echo "Deploiement termine."
echo "Site / API      : https://${DOMAIN} (API interne sur le port ${API_PORT},"
echo "                  jamais expose directement — tout passe par Nginx)"
echo "Panneau admin   : https://${DOMAIN}/admin"
echo "Live (LiveKit)  : wss://${DOMAIN}/livekit (signaling), port 3010 (TURN/TLS media)"
echo "Ouvre le port 3010 (TCP) dans ton pare-feu/panneau VPS si ce n'est pas deja fait."
echo "Logs API        : journalctl -u syrix-api -f"
echo "Redemarrer API  : systemctl restart syrix-api"
echo "=================================================="
