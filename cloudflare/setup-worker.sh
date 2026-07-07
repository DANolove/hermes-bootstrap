#!/usr/bin/env bash
# Hermes Bootstrap — развёртывание Cloudflare Worker прокси
# Использование: bash cloudflare/setup-worker.sh
set -euo pipefail

echo "=== Cloudflare Worker setup ==="
echo "Этот скрипт требует Cloudflare API токен с правами Workers"

read -p "Cloudflare Account ID: " CF_ACCOUNT
read -sp "Cloudflare API Token: " CF_TOKEN
echo ""

WORKER_NAME="hermes-proxy"

# Создание Worker
echo "Деплой Worker..."
curl -s -X PUT \
  "https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT}/workers/scripts/${WORKER_NAME}" \
  -H "Authorization: Bearer ${CF_TOKEN}" \
  -H "Content-Type: application/javascript" \
  --data-binary @cloudflare/worker.js

# Активация
echo "Активация..."
curl -s -X POST \
  "https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT}/workers/scripts/${WORKER_NAME}/subdomain" \
  -H "Authorization: Bearer ${CF_TOKEN}"

echo ""
echo "Worker задеплоен: https://${WORKER_NAME}.${CF_ACCOUNT}.workers.dev"
