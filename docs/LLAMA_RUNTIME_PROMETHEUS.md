# LLAMA RUNTIME — largeAI NODES

## Overview
The largeAI runtime uses llama.cpp's **router mode** to serve multiple models
on demand from a single systemd service. Models are loaded/unloaded automatically
(LRU eviction) — only one model in memory at a time. Idle models auto-unload
after `sleepIdleSeconds` (default 300s). Configuration is read from
`data/config/largeAI/llm.json`.

## History
The config file was originally `litellm.json` from an earlier architecture that
used LiteLLM as a proxy in front of llama.cpp. LiteLLM was abandoned because:
- It added an unnecessary Python process between clients and llama.cpp.
- llama.cpp's native router mode (`--models-dir`, `--models-max`) replaced all
  proxy functionality: multi-model serving, on-demand loading, LRU eviction.
- The proxy layer complicated debugging and added latency without benefit.
The file was renamed to `llm.json` (2026-03-28) to reflect the direct
llama.cpp architecture.

## Architecture
- **Config**: `data/config/largeAI/llm.json` — single source of truth for models, presets, pi agent settings.
- **LLM module**: `nix/mkCriomOS/llm.nix` — generates one systemd router service + models-dir + presets.ini.
- **Home module**: `nix/homeModule/min/default.nix` — derives Pi agent config from the same JSON and delegates state generation to `pi-mentci`.
- **Gate**: `(typeIs.largeAI or false) || (typeIs."largeAI-router" or false)` in `default.nix`.
- **Package**: `nix/llama-cpp-prometheus.nix` — Vulkan-enabled llama.cpp override (b8470+).

## Build target
```
nix build github:Criome/CriomOS/main#crioZones.maisiliym.prometheus.os
```

## Current deployment (March 2026)
- **Default model**: Qwen3.5-122B-A10B Q4_K_M — 76.5GB, 10B active MoE, 128K context
- **Available models**: 7 models (5GB–76.5GB), swappable on demand
- **Backend**: Vulkan (RADV) on AMD Strix Halo gfx1151
- **Port**: 11434 (single router port for all models)
- **Runtime user**: `llama` (system user, groups: video, render)
- **State**: `/var/lib/llama`
- **Memory limits**: MemoryMax=110G, MemoryHigh=100G (protects system services)

## Router mode
llama-server runs with `--models-dir` (nix-built directory of symlinked GGUFs)
and `--models-preset` (INI file with per-model ctx-size, flags). Key behavior:

- `--models-max 1` — only one model loaded at a time
- First request for a model auto-loads it (evicts the current model via LRU)
- Each model runs as a child process — killed on swap, memory fully freed
- `POST /models/load {"model":"qwen3.5-122b-a10b"}` — explicit load
- `POST /models/unload {"model":"qwen3.5-122b-a10b"}` — explicit unload
- `GET /v1/models` — list all available models and their load status

## GPU memory — Strix Halo unified memory
Vulkan sees only ~64GB by default on 128GB Strix Halo APUs. Kernel params expand this:
```
ttm.page_pool_size=27787264   # 5/6 of 128GB in 4KB pages
ttm.pages_limit=27787264
```
Set in `nix/mkCriomOS/metal/default.nix` for `behavesAs.center` nodes.

Additionally:
- `hardware.graphics.enable = true` — required for Vulkan ICD (Mesa RADV). Without it, llama-server falls back to CPU.
- `fit = off` — bypasses llama.cpp's memory check that rejects models >64GB on unified memory APUs.
- `HSA_OVERRIDE_GFX_VERSION=11.5.1` — process-scoped ROCm enumeration override for gfx1151.

## Service name
Single service per node: `${nodeName}-llama-router`

For prometheus: `prometheus-llama-router`.

## Verification
```bash
# Service status
systemctl status prometheus-llama-router

# List available models
curl -s http://prometheus.maisiliym.criome:11434/v1/models \
  -H "Authorization: Bearer sk-no-key-required" | jq

# Load a specific model
curl -s http://prometheus.maisiliym.criome:11434/models/load \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-no-key-required" \
  -d '{"model":"qwen3.5-122b-a10b"}'

# Quick inference test (auto-loads if not loaded)
curl -s http://prometheus.maisiliym.criome:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-no-key-required" \
  -d '{"model":"qwen3.5-122b-a10b","messages":[{"role":"user","content":"hi"}],"max_tokens":8}' \
  | jq '.timings.predicted_per_second'

# Swap to a different model (auto-unloads current)
curl -s http://prometheus.maisiliym.criome:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-no-key-required" \
  -d '{"model":"qwen3-8b","messages":[{"role":"user","content":"hi"}],"max_tokens":8}'

# Memory usage
free -h
```

## Available models
| Model | Size | Context | Style |
|-------|------|---------|-------|
| qwen3.5-122b-a10b | 76.5 GB | 128K | MoE reasoning (default) |
| gpt-oss-120b | 63 GB | 64K | General + coding |
| nemotron-3-super-120b-a12b | 63 GB | 32K | MoE reasoning |
| glm-4.7-flash | 32 GB | 128K | Fast general |
| nemotron-3-nano-30b-a3b | 17 GB | 128K | Fast MoE |
| qwen3.5-27b | 17 GB | 128K | Dense reasoning |
| qwen3-8b | 5 GB | 32K | Fast reasoning |

## Model prefetch (FOD pattern)
```bash
# Prefetch on target node
ssh root@prometheus.maisiliym.criome \
  'nix-prefetch-url <url> --type sha256'

# Convert hash to SRI
nix hash to-sri --type sha256 <nix32-hash>

# Create GC root
ssh root@prometheus.maisiliym.criome \
  'nix-store --add-root /nix/var/nix/gcroots/llm-<name> -r /nix/store/<path>'
```

## Implementation references
- Router service: `nix/mkCriomOS/llm.nix`
- Binary package: `nix/llama-cpp-prometheus.nix`
- Model config: `data/config/largeAI/llm.json`
- GPU/TTM setup: `nix/mkCriomOS/metal/default.nix`
- Home agent config: `nix/homeModule/min/default.nix`
