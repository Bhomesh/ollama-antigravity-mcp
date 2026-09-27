# 🤖 Ollama + DeepSeek-R1:7b → Antigravity MCP Integration

> Run a **local reasoning LLM** (DeepSeek-R1:7b) on your own hardware and wire it into [Antigravity](https://antigravity.dev) as a fully functional MCP server — so your AI agent can offload tasks to a free, private, on-device model.

## ✨ What This Does

- Installs **[Ollama](https://ollama.com)** — a lightweight local LLM runtime
- Pulls **DeepSeek-R1:7b** (~4.7 GB, Q4_K_M quant, 7.6B params with chain-of-thought reasoning)
- Installs `@truealter/mcp-ollama` — an MCP server that wraps Ollama's API
- Registers it as `ollama-local` in Antigravity via `agy mcp add`
- Exposes **10 MCP tools** directly to your Antigravity agent

## 🛠️ MCP Tools Available

| Tool | Description |
|------|-------------|
| `local_generate` | Free-form text generation |
| `local_summarize` | Summarise long documents |
| `local_analyze` | Classification, extraction, tagging, sentiment |
| `local_draft` | Commit messages, PR descriptions, changelogs |
| `local_code` | Docstrings, test stubs, type hints, code review |
| `local_diff` | Analyse git diffs, generate commit messages |
| `local_transform` | Code format conversions, syntax migrations |
| `local_models` | List available Ollama models |
| `local_pull` | Pull new models from Ollama registry |
| `local_vision` | Multimodal image analysis (needs a vision model) |

## 📋 Requirements

- **OS:** Linux (tested on Manjaro / Arch-based)
- **RAM:** 8 GB minimum (14 GB+ recommended for 7B models)
- **Disk:** ~6 GB free for the model
- **Node.js:** v18+
- **Antigravity CLI (`agy`):** Optional — for automatic MCP registration

## 🚀 Quick Start

```bash
git clone https://github.com/Bhomesh/ollama-antigravity-mcp.git
cd ollama-antigravity-mcp
chmod +x setup.sh
./setup.sh
```

The script will:
1. Install Ollama (if not already installed)
2. Configure stable CPU inference (bypasses AMD Vulkan driver crash)
3. Pull `deepseek-r1:7b`
4. Install the MCP server
5. Register it with Antigravity
6. Run a smoke test

## 🎛️ Configuration

You can override the default model via environment variable:

```bash
OLLAMA_MODEL=qwen2.5:7b ./setup.sh
```

Other models that work great:

| Model | Size | Best For |
|-------|------|----------|
| `deepseek-r1:7b` | 4.7 GB | Reasoning, code (default) |
| `qwen2.5:7b` | 4.5 GB | General purpose, fast |
| `mistral:7b` | 4.1 GB | Well-rounded |
| `llama3.2:3b` | 2.0 GB | Very fast, low RAM |
| `deepseek-r1:1.5b` | 1.1 GB | Minimal resources |

## 🔧 Manual Setup

If you prefer step-by-step:

```bash
# 1. Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# 2. Pull the model
ollama pull deepseek-r1:7b

# 3. Install MCP server
npm install -g @truealter/mcp-ollama --prefix ~/.local

# 4. Register with Antigravity
agy mcp add \
  --env OLLAMA_HOST=http://localhost:11434 \
  --env OLLAMA_MODEL=deepseek-r1:7b \
  ollama-local ~/.local/bin/mcp-ollama

# 5. Verify
agy mcp list
```

## ⚠️ AMD GPU / Vulkan Note

Some AMD iGPU/APU setups (e.g., Ryzen 5000 series with Radeon Graphics) crash the Ollama Vulkan backend. The setup script automatically applies a systemd override to force **CPU inference**:

```
/etc/systemd/system/ollama.service.d/cpu.conf
→ Environment=OLLAMA_GPU_LAYERS=0
```

This is stable and works fine with 14 GB RAM. To re-enable GPU after updating ROCm/Vulkan drivers:

```bash
sudo rm /etc/systemd/system/ollama.service.d/cpu.conf
sudo systemctl daemon-reload && sudo systemctl restart ollama
```

## 🧪 Test It

After setup, test the MCP integration directly:

```bash
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}\n{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"local_generate","arguments":{"prompt":"What is 2+2?","model":"deepseek-r1:7b"}}}\n' \
  | OLLAMA_HOST=http://localhost:11434 ~/.local/bin/mcp-ollama
```

Or just chat with the model directly:

```bash
ollama run deepseek-r1:7b
```

## 📁 Project Structure

```
ollama-antigravity-mcp/
├── setup.sh        # One-command automated setup
└── README.md       # This file
```

## 🙏 Credits

- [Ollama](https://ollama.com) — local LLM runtime
- [DeepSeek-R1](https://huggingface.co/deepseek-ai/DeepSeek-R1) — reasoning model by DeepSeek
- [@truealter/mcp-ollama](https://www.npmjs.com/package/@truealter/mcp-ollama) — MCP server wrapping Ollama
- [Antigravity](https://antigravity.dev) — AI coding agent

## 📄 License

MIT
