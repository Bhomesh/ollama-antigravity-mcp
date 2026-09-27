#!/usr/bin/env bash
# =============================================================================
# Ollama + DeepSeek-R1:7b + Antigravity MCP Setup Script
# Author: Bhomesh (bhomeshrazdan@gmail.com)
# Description: Installs Ollama, pulls DeepSeek-R1:7b, and wires it into
#              Antigravity via the @truealter/mcp-ollama MCP server.
# =============================================================================

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*"; exit 1; }
header()  { echo -e "\n${BOLD}${CYAN}═══ $* ═══${RESET}\n"; }

# ── Config ───────────────────────────────────────────────────────────────────
MODEL="${OLLAMA_MODEL:-deepseek-r1:7b}"
MCP_PACKAGE="@truealter/mcp-ollama"
MCP_BIN="$HOME/.local/bin/mcp-ollama"
MCP_SERVER_NAME="ollama-local"
OLLAMA_API="http://localhost:11434"

# ── 1. Install Ollama ─────────────────────────────────────────────────────────
header "Step 1: Installing Ollama"

if command -v ollama &>/dev/null; then
    success "Ollama already installed: $(ollama --version 2>/dev/null || echo 'version unknown')"
else
    info "Downloading and installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
    success "Ollama installed successfully"
fi

# ── 2. Configure CPU-only mode (bypass Vulkan crash on some AMD GPUs) ─────────
header "Step 2: Configuring Ollama Service"

OVERRIDE_DIR="/etc/systemd/system/ollama.service.d"
OVERRIDE_FILE="$OVERRIDE_DIR/cpu.conf"

if systemctl is-active --quiet ollama; then
    info "Ollama systemd service is already running"
else
    info "Setting up Ollama systemd override for stable CPU inference..."
    sudo mkdir -p "$OVERRIDE_DIR"
    sudo bash -c "printf '[Service]\nEnvironment=OLLAMA_GPU_LAYERS=0\n' > $OVERRIDE_FILE"
    sudo systemctl daemon-reload
    sudo systemctl enable --now ollama
    success "Ollama service enabled and started"
fi

# Wait for API to be ready
info "Waiting for Ollama API at $OLLAMA_API ..."
for i in $(seq 1 15); do
    if curl -sf "$OLLAMA_API/api/tags" &>/dev/null; then
        success "Ollama API is live"
        break
    fi
    sleep 2
    if [[ $i -eq 15 ]]; then
        error "Ollama API did not become ready in time. Check: journalctl -u ollama -n 50"
    fi
done

# ── 3. Pull the model ─────────────────────────────────────────────────────────
header "Step 3: Pulling Model — $MODEL"

if ollama list 2>/dev/null | grep -q "^${MODEL}"; then
    success "Model '$MODEL' is already available"
else
    info "Pulling '$MODEL' (this may take several minutes)..."
    ollama pull "$MODEL"
    success "Model '$MODEL' pulled successfully"
fi

# ── 4. Install mcp-ollama npm package ────────────────────────────────────────
header "Step 4: Installing MCP Server ($MCP_PACKAGE)"

if [[ -f "$MCP_BIN" ]]; then
    success "mcp-ollama binary already exists at $MCP_BIN"
else
    if ! command -v npm &>/dev/null; then
        error "npm not found. Please install Node.js (v18+): https://nodejs.org"
    fi
    info "Installing $MCP_PACKAGE to $HOME/.local ..."
    npm install -g "$MCP_PACKAGE" --prefix "$HOME/.local"
    success "mcp-ollama installed at $MCP_BIN"
fi

# ── 5. Register MCP server with Antigravity ───────────────────────────────────
header "Step 5: Registering '$MCP_SERVER_NAME' with Antigravity (agy)"

if ! command -v agy &>/dev/null; then
    warn "agy CLI not found — skipping Antigravity registration."
    warn "Once installed, run manually:"
    echo ""
    echo "  agy mcp add \\"
    echo "    --env OLLAMA_HOST=$OLLAMA_API \\"
    echo "    --env OLLAMA_MODEL=$MODEL \\"
    echo "    $MCP_SERVER_NAME $MCP_BIN"
    echo ""
else
    # Remove existing entry if present, then re-add fresh
    agy mcp remove "$MCP_SERVER_NAME" &>/dev/null || true
    agy mcp add \
        --env OLLAMA_HOST="$OLLAMA_API" \
        --env OLLAMA_MODEL="$MODEL" \
        "$MCP_SERVER_NAME" "$MCP_BIN"
    success "MCP server '$MCP_SERVER_NAME' registered in Antigravity"
fi

# ── 6. Smoke test ─────────────────────────────────────────────────────────────
header "Step 6: Smoke Test"

info "Sending a test prompt to $MODEL via MCP..."
RESPONSE=$(printf '%s\n%s\n' \
    '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' \
    '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"local_generate","arguments":{"prompt":"Say hello in one sentence.","model":"'"$MODEL"'"}}}' \
    | OLLAMA_HOST="$OLLAMA_API" OLLAMA_MODEL="$MODEL" "$MCP_BIN" 2>/dev/null \
    | grep '"id":2' \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['result']['content'][0]['text'])" 2>/dev/null || echo "")

if [[ -n "$RESPONSE" ]]; then
    success "Model responded:"
    echo -e "${BOLD}  → $RESPONSE${RESET}"
else
    warn "Smoke test inconclusive (model may need a moment to load). Try manually:"
    echo "  ollama run $MODEL 'Hello!'"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════╗"
echo -e "║  ✅  Setup Complete!                                         ║"
echo -e "╠══════════════════════════════════════════════════════════════╣"
echo -e "║  Ollama API   : $OLLAMA_API                         ║"
echo -e "║  Model        : $MODEL                              ║"
echo -e "║  MCP server   : $MCP_SERVER_NAME (stdio)                  ║"
echo -e "║  MCP tools    : local_generate, local_code, local_analyze, ║"
echo -e "║                 local_draft, local_diff, local_transform,  ║"
echo -e "║                 local_models, local_pull, local_vision     ║"
echo -e "╚══════════════════════════════════════════════════════════════╝${RESET}"
echo ""
info "Run 'agy mcp list' to confirm the MCP server is active."
info "Run 'ollama run $MODEL' to chat with the model directly."
