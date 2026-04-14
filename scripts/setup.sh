#!/bin/bash
# =============================================================================
# n8n Lead Generation Automation - Setup Script
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "============================================="
echo "  n8n Lead Generator - Environment Setup"
echo "============================================="
echo ""

# ---------------------------------------------------
# 1. Check prerequisites
# ---------------------------------------------------
echo -e "${YELLOW}[1/5] Checking prerequisites...${NC}"

check_command() {
    if command -v "$1" &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} $1 found ($(command -v "$1"))"
        return 0
    else
        echo -e "  ${RED}✗${NC} $1 not found"
        return 1
    fi
}

MISSING=0
check_command "node" || MISSING=1
check_command "npm" || MISSING=1
check_command "docker" || MISSING=1

if [ "$MISSING" -eq 1 ]; then
    echo ""
    echo -e "${RED}Missing prerequisites. Please install them before continuing.${NC}"
    echo "  - Node.js 18+: https://nodejs.org"
    echo "  - Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

echo ""

# ---------------------------------------------------
# 2. Start n8n via Docker
# ---------------------------------------------------
echo -e "${YELLOW}[2/5] Starting n8n via Docker...${NC}"

N8N_PORT="${N8N_PORT:-5678}"
N8N_DATA_DIR="${HOME}/.n8n-lead-generator"

mkdir -p "$N8N_DATA_DIR"

if docker ps --format '{{.Names}}' | grep -q "n8n-lead-gen"; then
    echo -e "  ${GREEN}✓${NC} n8n container already running"
else
    docker run -d \
        --name n8n-lead-gen \
        --restart unless-stopped \
        -p "${N8N_PORT}:5678" \
        -v "${N8N_DATA_DIR}:/home/node/.n8n" \
        -e N8N_BASIC_AUTH_ACTIVE=true \
        -e N8N_BASIC_AUTH_USER=admin \
        -e N8N_BASIC_AUTH_PASSWORD=changeme \
        -e GENERIC_TIMEZONE="America/New_York" \
        -e N8N_DIAGNOSTICS_ENABLED=false \
        n8nio/n8n:latest

    echo -e "  ${GREEN}✓${NC} n8n started on port ${N8N_PORT}"
fi

echo ""

# ---------------------------------------------------
# 3. Set up credentials config
# ---------------------------------------------------
echo -e "${YELLOW}[3/5] Setting up configuration...${NC}"

CONFIG_DIR="$(dirname "$0")/../config"
if [ ! -f "${CONFIG_DIR}/credentials.json" ]; then
    cp "${CONFIG_DIR}/credentials.example.json" "${CONFIG_DIR}/credentials.json"
    echo -e "  ${GREEN}✓${NC} Created credentials.json from template"
    echo -e "  ${YELLOW}!${NC} Edit config/credentials.json with your API keys"
else
    echo -e "  ${GREEN}✓${NC} credentials.json already exists"
fi

echo ""

# ---------------------------------------------------
# 4. Import workflows
# ---------------------------------------------------
echo -e "${YELLOW}[4/5] Workflow import instructions...${NC}"
echo ""
echo "  To import workflows into n8n:"
echo "  1. Open n8n at http://localhost:${N8N_PORT}"
echo "  2. Go to Workflows > Import from File"
echo "  3. Import each file from the workflows/ directory:"
echo "     - lead_scraper.json"
echo "     - lead_enrichment.json"
echo "     - notification.json"
echo ""

# ---------------------------------------------------
# 5. Summary
# ---------------------------------------------------
echo -e "${YELLOW}[5/5] Setup complete!${NC}"
echo ""
echo "============================================="
echo "  Setup Summary"
echo "============================================="
echo ""
echo "  n8n URL:    http://localhost:${N8N_PORT}"
echo "  Username:   admin"
echo "  Password:   changeme"
echo "  Data Dir:   ${N8N_DATA_DIR}"
echo ""
echo "  Next steps:"
echo "  1. Open n8n and change the default password"
echo "  2. Configure API credentials (see config/credentials.example.json)"
echo "  3. Import workflows from the workflows/ directory"
echo "  4. Set up Google Sheets connection"
echo "  5. Configure Slack webhook"
echo "  6. Test with sample data (scripts/sample_data.json)"
echo ""
echo -e "${GREEN}Happy automating!${NC}"
