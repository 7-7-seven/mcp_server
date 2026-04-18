#!/bin/bash
# =============================================================================
# Odoo MCP Server — Setup Script for macOS / Linux
# Usage: bash setup.sh
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.json"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Odoo MCP Server — Setup Wizard       ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo ""

# ── Step 1: Check Python ──────────────────────────────────────────
echo -e "${YELLOW}[1/5] Checking Python...${NC}"
PYTHON=$(which python3 2>/dev/null || which python 2>/dev/null)
if [ -z "$PYTHON" ]; then
    echo -e "${RED}✗ Python 3 not found.${NC}"
    echo "  macOS  : brew install python3"
    echo "  Ubuntu : sudo apt install python3 python3-pip"
    exit 1
fi
echo -e "${GREEN}✓ $($PYTHON --version) at $PYTHON${NC}"

# ── Step 2: Install dependencies ─────────────────────────────────
echo ""
echo -e "${YELLOW}[2/5] Installing Python dependencies...${NC}"
$PYTHON -m pip install --quiet --upgrade mcp requests
echo -e "${GREEN}✓ mcp, requests installed${NC}"

# ── Step 3: Collect Odoo connection details ───────────────────────
echo ""
echo -e "${YELLOW}[3/5] Odoo connection details${NC}"
echo -e "    (Press Enter to keep the default shown in brackets)"
echo ""

read -p "  Odoo URL          [http://localhost:8069]: " ODOO_URL
ODOO_URL="${ODOO_URL:-http://localhost:8069}"

read -p "  Database name     : " ODOO_DB
while [ -z "$ODOO_DB" ]; do
    echo -e "  ${RED}Database name is required.${NC}"
    read -p "  Database name     : " ODOO_DB
done

read -p "  API Token (Bearer): " ODOO_TOKEN
while [ -z "$ODOO_TOKEN" ]; do
    echo -e "  ${RED}Token is required. Generate one in Odoo → MCP Server → Configurations.${NC}"
    read -p "  API Token (Bearer): " ODOO_TOKEN
done

# ── Step 4: Test connection ───────────────────────────────────────
echo ""
echo -e "${YELLOW}[4/5] Testing Odoo connection...${NC}"
HTTP_STATUS=$(curl -s -o /tmp/mcp_health.json -w "%{http_code}" \
    "$ODOO_URL/mcp/health" \
    -H "X-Odoo-Database: $ODOO_DB" 2>/dev/null || echo "000")

if [ "$HTTP_STATUS" = "200" ]; then
    echo -e "${GREEN}✓ Connected! $(cat /tmp/mcp_health.json)${NC}"
else
    echo -e "${YELLOW}⚠ Could not reach Odoo (HTTP $HTTP_STATUS). Is Odoo running?${NC}"
    read -p "  Continue anyway? [y/N]: " CONTINUE
    [[ "$CONTINUE" =~ ^[Yy]$ ]] || exit 1
fi

# ── Step 5: Write config.json ─────────────────────────────────────
cat > "$CONFIG_FILE" <<EOF
{
  "odoo_url":   "$ODOO_URL",
  "odoo_db":    "$ODOO_DB",
  "odoo_token": "$ODOO_TOKEN"
}
EOF
echo ""
echo -e "${YELLOW}[5/5] Writing Claude Desktop config...${NC}"

# Detect Claude config path (macOS vs Linux)
if [[ "$OSTYPE" == "darwin"* ]]; then
    CLAUDE_CONFIG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
else
    CLAUDE_CONFIG="$HOME/.config/Claude/claude_desktop_config.json"
fi

mkdir -p "$(dirname "$CLAUDE_CONFIG")"

$PYTHON - <<PYEOF
import json, os

config_path = """$CLAUDE_CONFIG"""
python_bin  = """$PYTHON"""
server_path = """$SCRIPT_DIR/server.py"""

cfg = {}
if os.path.exists(config_path):
    with open(config_path) as f:
        try:
            cfg = json.load(f)
        except json.JSONDecodeError:
            cfg = {}

cfg.setdefault('mcpServers', {})['odoo'] = {
    'command': python_bin,
    'args': [server_path],
}

with open(config_path, 'w') as f:
    json.dump(cfg, f, indent=2)

print(f'✓ Saved: {config_path}')
PYEOF

# ── Done ──────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           Setup complete!                ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo "  Next steps:"
echo "  1. Restart Claude Desktop"
echo "  2. Look for the 🔨 hammer icon in the chat input"
echo "  3. Ask Claude: 'Search for partners in Odoo'"
echo ""
