#!/usr/bin/env bash
# ============================================================================
# Hermes Agent — /HANDOFF Bootstrap
# One-command развёртывание полной конфигурации агента
# Запуск: bash <(curl -fsSL https://hermes.sh) или сохрани и запусти
# ============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
NC='\033[0m'

HERMES_DIR="${HOME}/.hermes"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Hermes Agent — /HANDOFF Bootstrap${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# ── 1. Зависимости ──────────────────────────────────────────────────────
echo -e "\n${YELLOW}[1/5] Зависимости...${NC}"
MISSING=""
for cmd in curl git docker python3; do
    command -v "$cmd" &>/dev/null && echo -e "  ✓ $cmd" || { echo -e "  ✗ $cmd"; MISSING="$MISSING $cmd"; }
done

# ── 2. Установка Hermes ─────────────────────────────────────────────────
echo -e "\n${YELLOW}[2/5] Установка Hermes...${NC}"
if command -v hermes &>/dev/null; then
    echo -e "  ✓ Уже установлен"
else
    echo "  Установка..."
    curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash 2>/dev/null
    echo -e "  ✓ Установлен"
fi

# ── 3. Инфраструктура ───────────────────────────────────────────────────
echo -e "\n${YELLOW}[3/5] Docker инфраструктура...${NC}"
# Qdrant
if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q 'hermes-qdrant'; then
    docker run -d --name hermes-qdrant --restart unless-stopped \
        -p 6333:6333 -p 6334:6334 \
        -v hermes-qdrant-storage:/qdrant/storage \
        qdrant/qdrant:latest
    echo -e "  ✓ Qdrant :6333"
else
    echo -e "  ✓ Qdrant уже есть"
fi

# Dashboard
if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q 'hermes-dashboard'; then
    docker run -d --name hermes-dashboard --restart unless-stopped \
        -p 9090:9090 \
        ghcr.io/nousresearch/hermes-dashboard:latest
    echo -e "  ✓ Dashboard :9090"
else
    echo -e "  ✓ Dashboard уже есть"
fi

# ── 4. Конфигурация ─────────────────────────────────────────────────────
echo -e "\n${YELLOW}[4/5] Настройка...${NC}"
mkdir -p "${HERMES_DIR}"

if [ ! -f "${HERMES_DIR}/.env" ]; then
    cat > "${HERMES_DIR}/.env" << 'EOF'
# Получи ключи:
#   Groq: https://console.groq.com/keys
#   GitHub: https://github.com/settings/tokens (repo, gist)
#   OpenRouter: https://openrouter.ai/keys
GROQ_API_KEY=gsk_your_key
GITHUB_TOKEN=ghp_your_token
OPENROUTER_API_KEY=sk-or-v1_your_key
EOF
    echo -e "  ✓ .env создан (заполни ключи!)"
fi

# ── 5. Верификация ──────────────────────────────────────────────────────
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Верификация...${NC}${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

OK=0; FAIL=0
curl -sf http://localhost:6333/health >/dev/null && \
    { echo -e "  ${GREEN}✓ Qdrant${NC}"; OK=$((OK+1)); } || \
    { echo -e "  ${RED}✗ Qdrant${NC}"; FAIL=$((FAIL+1)); }

curl -sf http://localhost:9090/ >/dev/null && \
    { echo -e "  ${GREEN}✓ Dashboard${NC}"; OK=$((OK+1)); } || \
    { echo -e "  ${YELLOW}⚠ Dashboard пропущен${NC}"; }

hermes --version >/dev/null 2>&1 && \
    { echo -e "  ${GREEN}✓ Hermes CLI${NC}"; OK=$((OK+1)); } || \
    { echo -e "  ${RED}✗ Hermes CLI${NC}"; FAIL=$((FAIL+1)); }

echo ""
if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✅ /HANDOFF готов!${NC}"
    echo -e "  Заполни .env → запусти: hermes"
else
    echo -e "${YELLOW}⚠️ /HANDOFF с $FAIL ошибкой(ами)${NC}"
fi
